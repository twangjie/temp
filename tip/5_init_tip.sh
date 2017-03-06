#!/bin/bash
#title      : 4_init_tip.sh
#description: 初始化TIP
#author     : 王杰
#date       : 20170221
#version    : 1.0
#usage      : sh 4_init_tip.sh
#notes      :
#==============================================================================

currentTime=`date "+%Y%m%d%H%M%S"`

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'
clear

instroot=/opt/dccs/install

splitter='=============================================================================='


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
cp haspvlib_111426.so /var/hasplm
popd

echo ""
echo $splitter
echo "start mysql server..."
systemctl start mariadb

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

echo ""
echo $splitter
master_ip="127.0.0.1"
temp=""
read -p "Please input the master's ip: " temp

if [ "$temp" != "" ]; then
    master_ip=$temp
fi

# 初始化Mysql tip数据库连接信息
echo ""
echo $splitter
mysql_dbhost="127.0.0.1"
temp=""
read -p "Please input the database host ip for tip restful serivce[default: 127.0.0.1]: " temp

if [ "$temp" != "" ]; then
    mysql_dbhost=$temp
fi

# cloudera manager 增加用户
scm_update_sql_file=$instroot/tip/scm_update.sql

echo "use scm;" > $scm_update_sql_file
echo "INSERT INTO scm.\`USERS\` VALUES(1000,'__cloudera_internal_user__TIP', 'a1edda288e2a4be0a002c594ead6e5da2b9a633a1784a756a66a3db06c907921', '230065777681863511', 1, 1);" >> $scm_update_sql_file
echo "INSERT INTO scm.\`USER_ROLES\` VALUES(1000,1000,'ROLE_ADMIN',0);" >> $scm_update_sql_file

mysql -uscm -pscm -h$mysql_dbhost < $instroot/tip/scm_update.sql

echo ""
echo $splitter

config_file=/opt/dccs/tip/config.properties

echo "nesf.config.driverClassName=com.mysql.jdbc.Driver" >> $config_file
echo "nesf.config.url=jdbc:mysql://$mysql_dbhost:3306/tip" >> $config_file
echo "nesf.config.username=tip" >> $config_file
echo "nesf.config.password=tip" >> $config_file
echo "com.dccs.tip.cm.ip=$master_ip" >> $config_file

echo "com.dccs.tip.cm.ip=$master_ip" >> /opt/dccs/tip/RESTS/config/Server.properties

# 初始化Impala tip数据库连接信息
# Impala IP地址填写为Impala Daemon服务节点的IP地址，如果当前主机有Impala Daemon服务，直接填写127.0.0.1即可
echo ""
echo $splitter
temp=""
impala_dbhost="127.0.0.1"
read -p "Please input the impala host ip for tip restful serivce[default: 127.0.0.1]: " temp
if [ "$temp" != "" ]; then
    impala_dbhost=$temp
fi

temp=""
impala_port="21050"
read -p "Please input the impala deamon port for tip restful serivce[default: 21050]: " temp
if [ "$temp" != "" ]; then
    impala_port=$temp
fi

# 初始化HBASE表
hbase shell < $instroot/tip/hbase-init.cmd

#初始化Impala表
hive -f $instroot/tip/tip-impala-cache.sql
impala-shell -f $instroot/tip/tip-impala.sql
impala-shell -q 'invalidate metadata;'

#初始化flume
sudo -u hdfs hadoop fs mkdir -p  /flume/tip
sudo -u hdfs hadoop fs -chown -R impala:impala /flume/tip

rm -fr /data/flume
mkdir -p /data/flume
chown -R impala:impala /data/flume

rm -fr /var/log/flume-ng
mkdir -p /var/log/flume-ng
chown -R impala:impala /var/log/flume-ng


# 初始化HBase连接信息
# HBase地址填写为Zookeeper服务节点的IP地址，如果当前主机有Zookeeper服务，直接填写127.0.0.1即可
echo ""
echo $splitter
temp=""
zk_host="127.0.0.1"
read -p "Please input the Zookeeper ip for tip restful serivce[default: 127.0.0.1]: " temp
if [ "$temp" != "" ]; then
    zk_host=$temp
fi

# 执行初始化mysql tip数据库脚本
mysql -utip -ptip -h$mysql_dbhost < $instroot/tip/tip.sql

tip_update_sql_file=tip_update.sql

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

cd RESTS

rm -f RESTServer.jar
ln -s RESTServer-1.0.1.jar RESTServer.jar
chmod 755 jsvc
chmod 755 RESTServer.sh
popd

echo ""
echo $splitter
echo "Install the tip serivce..."
cp -a $instroot/tip/tip /etc/init.d/tip
systemctl enable tip

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
temp=""
while [ "$temp" == "" ]; do
    read -p "Please input the flume agents ip,split by \",\" [e.g.: 192.168.36.101,192.168.36.102]: " temp
done

echo "upstream flumeagents {" > $temp_file
echo $temp | awk '{split($0,s,",");{for(i in s)print "server " s[i] ":11111 max_fails=3 fail_timeout=5s weight=4;"}}' >> $temp_file
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
temp=""
while [ "$temp" == "" ]; do
    read -p "Please input the TIP server ip,split by \",\" [e.g.: 192.168.36.101,192.168.36.102]: " temp
done

echo "upstream restmgr {" > $temp_file
echo $temp | awk '{split($0,s,",");{for(i in s)print "    server " s[i] ":22345 max_fails=3 fail_timeout=5s weight=4;"}}' >> $temp_file
echo "    keepalive 10;" >> $temp_file
echo "}" >> $temp_file
echo "" >> $temp_file

echo "upstream rests2 {" >> $temp_file
echo $temp | awk '{split($0,s,",");{for(i in s)print "    server " s[i] ":58080 max_fails=3 fail_timeout=5s weight=4;"}}' >> $temp_file
echo "    keepalive 10;" >> $temp_file
echo "}" >> $temp_file
echo "" >> $temp_file

echo "upstream cm {" >> $temp_file
echo $master_ip | awk '{split($0,s,",");{for(i in s)print "    server " s[i] ":7180 max_fails=3 fail_timeout=5s weight=4;"}}' >> $temp_file
#echo "    server $master_ip:7180 max_fails=3 fail_timeout=5s weight=4;" >> $temp_file
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

echo ""
echo $splitter
echo "Initialize the tip restful serivce finished..."

echo "reboot in 5 seconds..."
sleep 5

reboot