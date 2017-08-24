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
               
cm_host = "127.0.0.1"
cm_port = 7180
cluster_name = "TIP"
cm_username = "admin"
cm_password = "Dccs12345."

def main():
    #print sys.argv[0]
    #for i in range(1, len(sys.argv)):
    #    print "param ", i, sys.argv[i]

    # get a handle on the instance of CM that we have running
    api = ApiResource(cm_host, cm_port, cm_username, cm_password, version=13)

    
    # get the CM instancepython2.7 setuptools
    cm = ClouderaManager(api)

    cluster = api.get_cluster(cluster_name)
    
    # distribution_parcels(api, cluster)
    
    cmd = cluster.first_run()

    while cmd.success == None:
        cmd = cmd.fetch()

    if cmd.success != True:
        print "The first run command failed: " + cmd.resultMessage()
        exit(0)

    print "First run successfully executed. Your cluster has been set up!"


if __name__ == "__main__":
    main()
