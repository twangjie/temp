#!/bin/bash
#title      : 3_init_cm.sh
#description: 初始化Cloudera Manager
#author     : 王杰
#date       : 20170221
#version    : 1.0
#usage      : sh 3_init_cm.sh
#notes      :
#==============================================================================

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'

masterflag="N"

while true; do
    read -p "This node is the master node?(y/n)?" yn
    case $yn in
        [Yy]* ) masterflag="Y"; break;;
        [Nn]* ) break;;
        * ) echo "Please answer y or n";;
    esac
done

splitter="=============================================================================="
backupdir=/opt/dccs/bak

#复制mysql jdbc驱动
mkdir -p /usr/share/java
cp -a mysql/mysql-connector-java-5.1.34-bin.jar /usr/share/java/mysql-connector-java.jar

if [ ! -d "/opt/dccs/install/cdh/cm" ]; then  
    pushd /opt/dccs/install/cdh
    tar -xf cm5*-centos7.tar.gz
    popd
fi

# 初始化tip.repo仓库（CentOS7.2 nginx cm5)
umount -l /media/CentOS
mkdir -p /media/CentOS/
mount -o loop CentOS7-TIP.iso /media/CentOS/
cp -a /etc/yum.repos.d $backupdir/
rm -fr /etc/yum.repos.d/*
cp -a yum.repos.d/* /etc/yum.repos.d/

echo "/opt/dccs/install/CentOS7-TIP.iso /media/CentOS iso9660 ro,relatime 0 0" >> /etc/fatab

yum clean all

#yum -y install jdk1.8.0_60
rpm -Uvh jdk-8u60-linux-x64.rpm

# 安装Cloudera Manager 5 RPMS
yum -y install cloudera-manager-agent
systemctl enable cloudera-scm-agent

echo
echo
echo $splitter
cmserver="127.0.0.1"
temp=""
while [ "$temp" == "" ]; do
    if [ $masterflag == "Y" ]; then
        read -p "Please input the external ntp server ip[default: 127.0.0.1]: " temp
    else
        read -p "Please input the Cloudera Manager server ip(Master node): " temp
    fi
done

ntphost=$temp
cmserver=$temp
sed -i 's/server_host=.*/server_host='$cmserver'/' /etc/cloudera-scm-agent/config.ini

systemctl restart cloudera-scm-agent

echo
# 初始化时间服务
yum -y install ntpdate ntp
systemctl enable ntpd

# 直接使用 Cloudera Manager server节点的ntp服务
ntphost=$cmserver

cat ntp/ntp-client.conf > /etc/ntp.conf
sed -i 's/server .*/server '$ntphost'/' /etc/ntp.conf

if [ "$ntphost" != "127.0.0.1" ]; then
    ntpdate -u $ntphost
    hwclock -w
fi

systemctl restart ntpd

#ntpq -p

echo
echo $splitter

function init_master(){
    
    echo
    echo $splitter    
    yum -y install cloudera-manager-agent cloudera-manager-server nginx mariadb-server
    systemctl enable cloudera-scm-server
    systemctl enable nginx
    systemctl enable mariadb
    
    systemctl stop cloudera-scm-server
    systemctl stop mariadb
    
    echo "copy cloudera cdh parcels..."
    mkdir -p /opt/cloudera/parcel-repo/
    cp -a /opt/dccs/install/cdh/parcel-repo/* /opt/cloudera/parcel-repo/
    
    echo
    
    echo $splitter
    
    cp -a mysql/my.cnf /etc/
    rm -fr /var/lib/mysql/*
    cp -a mysql/mysqldb.tar.gz /var/lib/mysql.tar.gz 
    pushd /var/lib/
    tar -xf mysql.tar.gz
    chown mysql:mysql -R /var/lib/mysql
    popd

    systemctl start mariadb

    echo $splitter
    
    JAVA_HOME=/usr/java/latest
    
    mysql -uroot -pDccs12345. < mysql/cm.sql
    /usr/share/cmf/schema/scm_prepare_database.sh mysql -h 127.0.0.1 -uroot -pDccs12345. --scm-host 127.0.0.1 scm scm scm --force
    
    systemctl start cloudera-scm-server
    systemctl start nginx
    
    echo
    echo "Cloudera Manager(Master) initialize finished"
}

if [ $masterflag == "Y" ]; then
    init_master
fi

echo "Cloudera Manager Agent initialize finished..."

