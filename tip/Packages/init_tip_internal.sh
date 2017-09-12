#!/bin/bash
#title      : 5_init_tip.sh
#description: 初始化TIP
#author     : 王杰
#date       : 20170221
#version    : 1.0
#usage      : sh 5_init_tip.sh
#notes      :
#==============================================================================

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'
clear

splitter="=============================================================================="
instroot=/opt/dccs/install

echo ""
echo $splitter
currentTime=`date "+%Y-%m-%d %H:%M:%S"`
echo "Now: "$currentTime

masterflag="N"

flumenodes_file=$instroot/flumenodes.txt
impaladnodes_file=$instroot/impaladnodes.txt
zookeepernodes_file=$instroot/zookeepernodes.txt
hosts_file=$instroot/hosts.txt

my_ip=`cat $instroot/ip.txt`
master_ip="host101.tip.dccs.com.cn"
temp=$1
while [ "$temp" == "" ]; do
    read -p "Please input the master ip [e.g.: 192.168.36.101 ]: " temp
done
master_ip=$temp
mysql_dbhost=$master_ip

if [ $master_ip == $my_ip ]; then
    masterflag="Y"
fi

echo "master_ip: "$master_ip", master: "$masterflag
echo "Initialize tip components, please wait..."

echo ""
echo $splitter

function init_scm_user {
    echo ""
    echo $splitter
    echo "Initialize MySQL tip datasource"

    systemctl start mariadb

    # cloudera manager 增加用户
    scm_update_sql_file=$instroot/tip/scm_update.sql

    echo "use scm;" > $scm_update_sql_file
    echo "INSERT INTO scm.\`USERS\` VALUES(1000,'__cloudera_internal_user__TIP', 'a1edda288e2a4be0a002c594ead6e5da2b9a633a1784a756a66a3db06c907921', '230065777681863511', 1, 1);" >> $scm_update_sql_file
    echo "INSERT INTO scm.\`USER_ROLES\` VALUES(1000,1000,'ROLE_ADMIN',0);" >> $scm_update_sql_file

    mysql -uscm -pscm -h$mysql_dbhost < $instroot/tip/scm_update.sql
}

if [ $masterflag == "Y" ]; then
   init_scm_user;
fi

function parse_cm_cluster_info {
    curl --request GET --header 'accept: application/json' --header 'authorization: Basic X19jbG91ZGVyYV9pbnRlcm5hbF91c2VyX19USVA6X19jbG91ZGVyYV9pbnRlcm5hbF91c2VyX19USVA=' --url "http://$master_ip:7180/api/v13/clusters?view=EXPORT" > cluster.cfg
    curl --request GET --header 'accept: application/json' --header 'authorization: Basic X19jbG91ZGVyYV9pbnRlcm5hbF91c2VyX19USVA6X19jbG91ZGVyYV9pbnRlcm5hbF91c2VyX19USVA=' --url "http://$master_ip:7180/api/v13/hosts" > hosts.cfg

    # 从CM配置中解析出flume impala zookeeper节点，以及所有主机的IP
    /usr/bin/python $instroot/parseClusterCfg.py

    if [ ! -f $flumenodes_file ]; then
        echo "Error: flume agents not exists!! Please check the hadoop config!"
        exit -1
    fi

    if [ ! -f $impaladnodes_file ]; then
        echo "Error: impala daemons not exists!! Please check the hadoop config!"
        exit -1
    fi

    if [ ! -f $zookeepernodes_file ]; then
        echo "Error: Zookeeper not exists!! Please check the hadoop config!"
        exit -1
    fi

    if [ ! -f $hosts_file ]; then
        echo "Error: Hosts not exists!! Please check the hadoop config!"
        exit -1
    fi

    zk_host=`cat $zookeepernodes_file`
    impala_dbhost=`cat $impaladnodes_file`
    flumeagents=`cat $flumenodes_file`
    hostIpAddrs=`cat $hosts_file`
}

function init_master {

    echo ""
    echo $splitter

    zookeeper-client -server $zk_host rmr /hbase/table/tip_image
    zookeeper-client -server $zk_host rmr /hbase/table/vehicleinfo_cache
        
    echo ""
    echo $splitter

    # 初始化HBASE表
    hbase shell < $instroot/tip/hbase-init.cmd

    echo ""
    echo $splitter

    #初始化Impala表
    sudo -u hdfs hadoop fs -mkdir -p /user/impala/tip/so/
    sudo -u hdfs hadoop fs -chown -R impala:impala /user/impala
    sudo -u hdfs hadoop fs -rm -f -skipTrash /user/impala/tip/so/libTipUDFS*.so
    sudo -u hdfs hadoop fs -put $instroot/tip/libTipUDFS*.so /user/impala/tip/so/
    sudo -u hdfs hadoop fs -ls /user/impala/tip/so/

    echo ""
    echo $splitter

    hive -f $instroot/tip/tip-impala-cache.sql
    impala-shell -f $instroot/tip/tip-impala.sql
    impala-shell -q "invalidate metadata;show databases;show tables in tip;use tip;select is_privilege_plate('a');"

    sudo -u hdfs hadoop fs -mkdir -p /user/hive/warehouse/cache.db
    sudo -u hdfs hadoop fs -chown impala:hive /user/hive/warehouse/cache.db
    sudo -u hdfs hadoop fs -chmod -R 777 /user/hive/warehouse/cache.db
    
    echo ""
    echo $splitter

    #初始化flume
    sudo -u hdfs hadoop fs -mkdir -p /flume/tip
    sudo -u hdfs hadoop fs -chown -R impala:impala /flume/tip
    
    echo ""
    echo $splitter

    # 执行初始化mysql tip数据库脚本
    impala_port="21050"

    mysql -utip -ptip -h$mysql_dbhost < $instroot/tip/tip.sql

    tip_update_sql_file=$instroot/tip_update.sql

    echo "use tip;" > $tip_update_sql_file
    echo "update config set val='$impala_dbhost' where \`key\`='dccs.reset.config.impala.jdbc.host';" >> $tip_update_sql_file
    echo "update config set val='$impala_port' where \`key\`='dccs.reset.config.impala.jdbc.port';" >> $tip_update_sql_file
    echo "update config set val='jdbc:impala://$impala_dbhost:$impala_port/tip' where \`key\`='nesf.datasource.impala.url';" >> $tip_update_sql_file
    echo "update config set val='$zk_host' where \`key\`='dccs.reset.config.hbase.zookeeper.quorum';" >> $tip_update_sql_file
    echo "update config set val='$zk_host' where \`key\`='nesf.service.hbaseZkQuorum';" >> $tip_update_sql_file
    echo "update config set val='jdbc:mysql://$mysql_dbhost:3306/tip' where \`key\`='nesf.datasource.task.url';" >> $tip_update_sql_file
    echo "update config set val='jdbc:mysql://$mysql_dbhost:3306/tip' where \`key\`='nesf.datasource.task.url';" >> $tip_update_sql_file
    echo "update config set val='tip' where \`key\`='nesf.datasource.task.username';" >> $tip_update_sql_file
    echo "update config set val='tip' where \`key\`='nesf.datasource.task.password';" >> $tip_update_sql_file

    mysql -utip -ptip -h$mysql_dbhost < $tip_update_sql_file
    rm -f $tip_update_sql_file
    
    # 配置nginx
    rm -fr /etc/nginx/conf.d
    rm -f /etc/nginx/nginx.conf
    cp -a $instroot/nginx/* /etc/nginx

    temp_file=$instroot/temp.conf

    # 配置flume agent
    clear
    echo ""
    echo $splitter
    echo "Config the flume proxy..."


    echo "upstream flumeagents {" > $temp_file
    echo $flumeagents | awk '{split($0,s,",");{for(i in s)print "server " s[i] ":11111 max_fails=3 fail_timeout=5s weight=4;"}}' >> $temp_file
    echo "keepalive 10;" >> $temp_file
    echo "}" >> $temp_file
    echo "" >> $temp_file
    cat nginx/conf.d/http/flumeproxy.conf >> $temp_file
    cat $temp_file > /etc/nginx/conf.d/http/flumeproxy.conf
    rm -f $temp_file

    # 配置TIP servie
    clear
    echo ""
    echo $splitter
    echo "Config the TIP server proxy..."

    echo "upstream restmgr {" > $temp_file
    echo $hostIpAddrs | awk '{split($0,s,",");{for(i in s)print "    server " s[i] ":22345 max_fails=3 fail_timeout=5s weight=4;"}}' >> $temp_file
    echo "    keepalive 10;" >> $temp_file
    echo "}" >> $temp_file
    echo "" >> $temp_file

    echo "upstream rests2 {" >> $temp_file
    echo $hostIpAddrs | awk '{split($0,s,",");{for(i in s)print "    server " s[i] ":58080 max_fails=3 fail_timeout=5s weight=4;"}}' >> $temp_file
    echo "    keepalive 10;" >> $temp_file
    echo "}" >> $temp_file
    echo "" >> $temp_file

    echo "upstream cm {" >> $temp_file
    echo $master_ip | awk '{split($0,s,",");{for(i in s)print "    server " s[i] ":7180 max_fails=3 fail_timeout=5s weight=4;"}}' >> $temp_file
    echo "    keepalive 10;" >> $temp_file
    echo "}" >> $temp_file
    echo "" >> $temp_file

    cat $temp_file

    cat nginx/conf.d/http/tip.conf >> $temp_file
    cat $temp_file > /etc/nginx/conf.d/http/tip.conf
    rm -f $temp_file

    systemctl enable nginx
    systemctl restart nginx
    systemctl status nginx
}

parse_cm_cluster_info;

if [ $masterflag == "Y" ]; then
    init_master;
fi

function init_dog {
    echo ""
    echo $splitter
    echo "Init dog..."

    pushd $instroot/dog

    rpm -ivh --nodeps rpms/nss-softokn-freebl-3.16.2.3-13.el7_1.i686.rpm
    rpm -ivh --nodeps rpms/glibc-2.17-105.el7.i686.rpm
    tar -xf aksusbd-*.tar.gz
    cd aksusbd-7.51.1-i386
    chmod 755 *
    ./dunst
    ./dinst
    cd ..
    cp haspvlib_111426.so /var/hasplm/
    popd
}

function init_tip_service {
    echo ""
    echo $splitter
    echo "Initialize the tip packages..."
    rm -fr /opt/dccs/tip/*
    mkdir -p /opt/dccs/tip

    cp tip/*.tar.gz /opt/dccs/tip/
    cp tip/config.properties /opt/dccs/tip/

    pushd /opt/dccs/tip/

    # 初始化tip服务程序
    echo ""
    echo $splitter
    echo "Decompress the tip packages..."
    tar -xf apache-tomcat-8.5.5.tar.gz
    tar -xf flume-ng.tar.gz
    tar -xf RESTS.tar.gz

    cd /opt/dccs/tip/RESTS
    chmod 755 jsvc
    chmod 755 RESTServer.sh

    popd

    # 初始化本地Impala tip数据库连接信息
    echo ""
    echo $splitter
    config_file=/opt/dccs/tip/config.properties

    echo "nesf.config.driverClassName=com.mysql.jdbc.Driver" > $config_file
    echo "nesf.config.url=jdbc:mysql://$mysql_dbhost:3306/tip" >> $config_file
    echo "nesf.config.username=tip" >> $config_file
    echo "nesf.config.password=tip" >> $config_file
    echo "com.dccs.tip.cm.ip=$master_ip" >> $config_file
    cat $config_file

    echo ""
    echo $splitter
    config_file=/opt/dccs/tip/RESTS/config/Server.properties
    echo "dccs.reset.config.db.driverClassName=com.mysql.jdbc.Driver" > $config_file
    echo "dccs.reset.config.db.url=jdbc:mysql://$mysql_dbhost:3306/tip" >> $config_file
    echo "dccs.reset.config.db.username=tip" >> $config_file
    echo "dccs.reset.config.db.password=tip" >> $config_file
    echo "com.dccs.tip.cm.ip=$master_ip" >> $config_file
    cat $config_file

    echo ""
    echo $splitter
    # 初始化本地flume数据存储目录
    rm -fr /data/flume
    mkdir -p /data/flume
    chown -R impala:impala /data/flume

    rm -fr /var/log/flume-ng
    mkdir -p /var/log/flume-ng
    chown -R impala:impala /var/log/flume-ng

    echo ""
    echo $splitter
    echo "Install the tip serivce..."
    systemctl stop tip
    cp -a $instroot/tip/tip /etc/init.d/tip
    systemctl daemon-reload
    systemctl enable tip

    systemctl restart tip
    systemctl status tip
}

function tip_verify {
    echo ""
    echo $splitter

    curl -v --request GET --header 'accept: application/json' http://$my_ip:22345/api/tip/v1/events?debug=1

    echo ""
    echo $splitter
    curl -I --request GET --header 'accept: application/json' http://$my_ip:22345/test.html

    echo ""
    echo $splitter
    echo "Initialize the tip restful serivce finished..."
}

init_dog
init_tip_service

sleep 5
tip_verify

echo ""

