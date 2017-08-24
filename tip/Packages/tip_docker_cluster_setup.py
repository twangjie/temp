#! usr/bin/python
#--coding:utf-8--

# Licensed to Cloudera, Inc. under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  Cloudera, Inc. licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from cm_api.api_client import ApiResource
from cm_api.endpoints.clusters import ApiCluster
from cm_api.endpoints.clusters import create_cluster
from cm_api.endpoints.parcels import ApiParcel
from cm_api.endpoints.parcels import get_parcel
from cm_api.endpoints.cms import ClouderaManager
from cm_api.endpoints.services import ApiService, ApiServiceSetupInfo
from cm_api.endpoints.services import create_service
from cm_api.endpoints.types import ApiCommand, ApiRoleConfigGroupRef
from cm_api.endpoints.role_config_groups import get_role_config_group
from cm_api.endpoints.role_config_groups import ApiRoleConfigGroup
from cm_api.endpoints.roles import ApiRole
from time import sleep

import sys
import re

# Configuration
service_types_and_names = {
			   "ZOOKEEPER" : "ZOOKEEPER",
			   "HDFS" : "HDFS",
			   "YARN" : "YARN",
			   "HBASE" : "HBASE",
			   "HIVE" : "HIVE",
			   "IMPALA" : "IMPALA",
			   "FLUME" : "FLUME"}
               
cm_host = "127.0.0.1"
cm_port = 7180
host_list = ['tipmaster', 'tipslave1', 'tipslave2', 'tipslave3']
cluster_name = "TIP"
cdh_version = "CDH5" # also valid: "CDH4"
cdh_version_number = "5" # also valid: 4
hive_metastore_host = "tipmaster"
hive_metastore_name = "metastore"
hive_metastore_password = "hive" # enter password here
hive_metastore_database_type = "mysql"
hive_metastore_database_port = 3306
#reports_manager_host = "host00000"
#reports_manager_name = "reports_manager"
#reports_manager_username = "rman"
#reports_manager_password = "" # enter password here
#reports_manager_database_type = "postgresql"
cm_username = "admin"
cm_password = "Dccs12345."
cm_service_name = "mgmt"
host_username = "root"
host_password = "Dccs12345."
# cm_repo_url =  None
# cm_repo_url = "deb http://archive.cloudera.com/cm5/ubuntu/lucid/amd64/cm/ lucid-cm5 contrib" # OPTIONAL: only if you want to use a specific repo; this is specific to Debian
cm_repo_url="http://192.168.50.1:18880/cm/5/"

def distribution_parcels(api_resource, cluster):
    
    # get and list all available parcels
    print "Available parcels:"
    for cdh_parcel in cluster.get_all_parcels():
        print '\t' + cdh_parcel.product + ' ' + cdh_parcel.version
    
    for cdh_parcel in cluster.get_all_parcels():
        parcel_full_name=cdh_parcel.product + ' ' + cdh_parcel.version
    
        # download the parcel
        print "Downing parcel " + parcel_full_name + ". This might take a while."
        cmd = cdh_parcel.start_download()
        if cmd.success != True:
            print "Parcel " + parcel_full_name + " download failed!"
            exit(0)
            
        # make sure the download finishes
        while cdh_parcel.stage != 'DOWNLOADED':
            sleep(5)
            cdh_parcel = get_parcel(api_resource, cdh_parcel.product, cdh_parcel.version, cluster_name)

        print "Parcel " + parcel_full_name + " downloaded"
        
        # distribute the parcel
        print "Starting distribution parcel " + parcel_full_name + ". This might take a while."
        cmd = cdh_parcel.start_distribution()
        if cmd.success != True:
            print "Parcel " + parcel_full_name + " distribution failed!"
            exit(0)
        
        # make sure the distribution finishes
        while cdh_parcel.stage != "DISTRIBUTED":
            sleep(5)
            cdh_parcel = get_parcel(api_resource, cdh_parcel.product, cdh_parcel.version, cluster_name)

        print "Parcel " + parcel_full_name + " distributed."

        # activate the parcel
        cmd = cdh_parcel.activate()
        if cmd.success != True:
            print "Parcel " + parcel_full_name + " activation failed!"
            exit(0)

        # make sure the activation finishes
        while cdh_parcel.stage != "ACTIVATED":
            cdh_parcel = get_parcel(api_resource, cdh_parcel.product, cdh_parcel.version, cluster_name)

        print "Parcel " + parcel_full_name + " activated"

def assign_tip_roles(cluster, hosts):

    idx=0
    if len(hosts) > 3:
        idx=1

    service_name=service_types_and_names["ZOOKEEPER"]
    service = cluster.get_service(service_name)    
    for host in hosts:
        hostidx=host.ipAddress.split(".")[3]
        service.create_role(service_name+"-SERVER-"+hostidx,"SERVER", host.hostId)
        print "Create role: "+service_name+"-SERVER-"+hostidx + ", type:SERVER on " + host.hostId
        idx=idx+1
        if idx >=3:
            break

    service_name=service_types_and_names["HDFS"]
    service = cluster.get_service(service_name)
    for host in hosts:
        hostidx=host.ipAddress.split(".")[3]
        service.create_role(service_name+"-DATANODE-" + hostidx, "DATANODE",host.hostId)
        if hostidx == "101":
            service.create_role(service_name+"-NAMENODE-" + hostidx,"NAMENODE",host.hostId)
            service.create_role(service_name+"-SECONDARYNAMENODE-" + hostidx,"SECONDARYNAMENODE",host.hostId)
            service.create_role(service_name+"-BALANCER-" + hostidx,"BALANCER",host.hostId)

    service_name=service_types_and_names["HBASE"]
    service = cluster.get_service(service_name)
    for host in hosts:
        hostidx=host.ipAddress.split(".")[3]
        service.create_role(service_name+"-REGIONSERVER-" + hostidx, "REGIONSERVER",host.hostId)
        if hostidx == "101":
            service.create_role(service_name+"-MASTER-"+hostidx,"MASTER",host.hostId)

    service_name=service_types_and_names["YARN"]
    service = cluster.get_service(service_name)
    for host in hosts:
        hostidx=host.ipAddress.split(".")[3]
        service.create_role(service_name+"-GATEWAY-" + hostidx, "GATEWAY",host.hostId)
        if hostidx == "101":
            service.create_role(service_name+"-NODEMANAGER-"+hostidx,"NODEMANAGER",host.hostId)
        if hostidx == "102":
            service.create_role(service_name+"-RESOURCEMANAGER-"+hostidx,"RESOURCEMANAGER",host.hostId)
        if hostidx == "103":
            service.create_role(service_name+"-JOBHISTORY-"+hostidx,"JOBHISTORY",host.hostId)
            
    service_name=service_types_and_names["HIVE"]
    service = cluster.get_service(service_name)
    for host in hosts:
        hostidx=host.ipAddress.split(".")[3]
        service.create_role(service_name+"-GATEWAY-" + hostidx, "GATEWAY",host.hostId)
        if hostidx == "101":
            service.create_role(service_name+"-HIVEMETASTORE-"+hostidx,"HIVEMETASTORE",host.hostId)
        if hostidx == "102":
            service.create_role(service_name+"-HIVESERVER2-"+hostidx,"HIVESERVER2",host.hostId)
            
    service_name=service_types_and_names["IMPALA"]
    service = cluster.get_service(service_name)
    for host in hosts:
        hostidx=host.ipAddress.split(".")[3]
        service.create_role(service_name+"-IMPALAD-" + hostidx, "IMPALAD",host.hostId)
        if hostidx == "101":
            service.create_role(service_name+"-CATALOGSERVER-"+hostidx,"CATALOGSERVER",host.hostId)
        if hostidx == "102":
            service.create_role(service_name+"-STATESTORE-"+hostidx,"STATESTORE",host.hostId)
            
    service_name=service_types_and_names["FLUME"]
    service = cluster.get_service(service_name)
    for host in hosts:
        hostidx=host.ipAddress.split(".")[3]
        if hostidx != "101":
            service.create_role(service_name+"-AGENT-"+hostidx,"AGENT",host.hostId)

def assign_cm_roles(cmservice, cm_service_name, hosts):
    for host in hosts:
        hostidx=host.ipAddress.split(".")[3]
        if hostidx == "101":
            cmservice.create_role(cm_service_name+"-HOSTMONITOR-" + hostidx, "HOSTMONITOR",host.hostId)
            cmservice.create_role(cm_service_name+"-SERVICEMONITOR-" + hostidx, "SERVICEMONITOR",host.hostId)
            cmservice.create_role(cm_service_name+"-EVENTSERVER-" + hostidx, "EVENTSERVER",host.hostId)            
            cmservice.create_role(cm_service_name+"-ALERTPUBLISHER-" + hostidx, "ALERTPUBLISHER",host.hostId)
            break
            
def set_up_cluster():
    # get a handle on the instance of CM that we have running
    api = ApiResource(cm_host, cm_port, cm_username, cm_password, version=13)

    # get the CM instancepython2.7 setuptools
    cm = ClouderaManager(api)

    # activate the CM trial license
    #cm.begin_trial()

    cmservice=None
    try:
        cmservice = cm.get_service()
    except Exception,e:   
        print Exception,":",e 

    if cmservice is None:
        # create the management service
        service_setup = ApiServiceSetupInfo(name=cm_service_name, type="MGMT")
        cm.create_mgmt_service(service_setup)

    cmservice = cm.get_service()

    # install hosts on this CM instance
    cmd = cm.host_install(user_name=host_username, host_names=host_list, ssh_port=22, password=host_password, private_key=None, passphrase=None, parallel_install_count=None, cm_repo_url=cm_repo_url,gpg_key_custom_url=None, java_install_strategy=None, unlimited_jce=None)
    print "Installing hosts. This might take a while."
    while cmd.success == None:
        sleep(5)
        cmd = cmd.fetch()

    if cmd.success != True:
        print "cm_host_install failed: " + cmd.resultMessage
        exit(0)

    print "cm_host_install succeeded"
    
    hosts = api.get_all_hosts()
    
    # first auto-assign roles and auto-configure the CM service
    cmroles=cmservice.get_all_roles()
    if len(cmroles) == 0:
        #cm.auto_assign_roles()
        assign_cm_roles(cmservice, cm_service_name, hosts)        
        cm.auto_configure()

    cluster_exists=False
    clusters = api.get_all_clusters()
    for p in api.get_all_clusters():
        if p.displayName == cluster_name:
            cluster_exists=True
        
    if cluster_exists==True:
        cluster = api.get_cluster(cluster_name)
    else:
        # create a cluster on that instance
        cluster = create_cluster(api, cluster_name, cdh_version)
        # add all our hosts to the cluster
        cluster.add_hosts(host_list)
        cluster = api.get_cluster(cluster_name)
        distribution_parcels(api, cluster)
        
    # inspect hosts and print the result
    print "Inspecting hosts. This might take a few minutes."

    cmd = cm.inspect_hosts()
    while cmd.success == None:
        cmd = cmd.fetch()

    if cmd.success != True:
        print "Host inpsection failed!"
        exit(0)

    print "Hosts successfully inspected: \n\t" + cmd.resultMessage

    print "Stop the clusters"
    cluster.stop().wait()
    
    print "Delete all clusters"
    for s in cluster.get_all_services():
        cluster.delete_service(s.name)
    
    print "create tip services"
    # create all the services we want to add; we will only create one instance
    # of each
    for s in service_types_and_names.keys():
        service = cluster.create_service(service_types_and_names[s], s)

    # we will auto-assign roles; you can manually assign roles using the
    # /clusters/{clusterName}/services/{serviceName}/role endpoint or by using
    # ApiService.createRole()
    #cluster.auto_assign_roles()
    
    assign_tip_roles(cluster, hosts)
    
    cluster.auto_configure()

    # this will set up the Hive and the reports manager databases because we
    # can't auto-configure those two things
    hive = cluster.get_service(service_types_and_names["HIVE"])
    hive_config = { "hive_metastore_database_host" : hive_metastore_host, \
                    "hive_metastore_database_name" : hive_metastore_name, \
                    "hive_metastore_database_password" : hive_metastore_password, \
	    	    "hive_metastore_database_port" : hive_metastore_database_port, \
		    "hive_metastore_database_type" : hive_metastore_database_type }
    hive.update_config(hive_config)
    
    flume = cluster.get_service(service_types_and_names["FLUME"])
    flume_config = {"process_groupname":"impala", "process_username":"impala"}
    flume.update_config(flume_config)

    flume_rolegroup_config = {"agent_java_heapsize":"4294967296", \
                    "agent_plugin_dirs":"/usr/lib/flume-ng/plugins.d:/var/lib/flume-ng/plugins.d:/opt/dccs/tip/flume-ng/plugins.d", \
                    "agent_name":"tip_agent", \
                    "flume_agent_java_opts":"--no-reload-conf=true"}

    for role_group_cfg in flume.get_all_role_config_groups():
        role_group_cfg.update_config(flume_rolegroup_config)
        
    #flume_role_config = {"agent_java_heapsize":"255852544", \
    #                "agent_plugin_dirs":"/usr/lib/flume-ng/plugins.d:/var/lib/flume-ng/plugins.d:/opt/dccs/tip/flume-ng/plugins.d", \
    #                "agent_name":"tip_agent", \
    #                "flume_agent_java_opts":"--no-reload-conf=true"}

    #for role in flume.get_all_roles():
    #    role.update_config(flume_role_config)

    # start the management service
    cm_service = cm.get_service()
    cm_service.start().wait()
    
    # this will set the Reports Manager database password
    # first we find the correct role
#    rm_role = None
#    for r in cm.get_service().get_all_roles():
#        if r.type == "REPORTSMANAGER":
#            rm_role = r

#    if rm_role == None:
#	print "No REPORTSMANAGER role found!"
#       exit(0)

    # then we get the corresponding role config group -- even though there is
    # only once instance of each CM management service, we do this just in case
    # it is not placed in the base group
    #rm_role_group = rm_role.roleConfigGroupRef
    #rm_rcg = get_role_config_group(api, rm_role.type, rm_role_group.roleConfigGroupName, None)

    # update the appropriate fields in the config
#    rm_rcg_config = { "headlamp_database_host" : reports_manager_host, \
#                      "headlamp_database_name" : reports_manager_name, \
#                      "headlamp_database_user" : reports_manager_username, \
#                      "headlamp_database_password" : reports_manager_password, \
# 		      "headlamp_database_type" : reports_manager_database_type }

#    rm_rcg.update_config(rm_rcg_config)


    # restart the management service with new configs
    print "Restart the management service. This might take a while."
    cm_service.restart().wait()

    # execute the first run command
    print "Excuting first run command. This might take a while."
    cmd = cluster.first_run()

    while cmd.success == None:
        cmd = cmd.fetch()

    if cmd.success != True:
        print "The first run command failed: " + cmd.resultMessage
        exit(0)

    print "First run successfully executed. Your cluster has been set up!"
    
    flume.start()

def main():
    #print sys.argv[0]
    #for i in range(1, len(sys.argv)):
    #    print "param ", i, sys.argv[i]
        
    set_up_cluster()

if __name__ == "__main__":
    main()
