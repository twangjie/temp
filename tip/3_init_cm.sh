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

clear

splitter="=============================================================================="
backupdir=/opt/dccs/bak

#复制mysql jdbc驱动
mkdir -p /usr/share/java
cp -a mysql/mysql-connector-java-5.1.34-bin.jar /usr/share/java/mysql-connector-java.jar

# 初始化tip.repo仓库（CentOS7.2 nginx cm5)

umount -l /media/CentOS

mkdir -p /media/CentOS/

mount -o loop CentOS7-TIP.iso /media/CentOS/

cp -a /etc/yum.repos.d $backupdir/
rm -fr /etc/yum.repos.d/*
cp -a yum.repos.d/* /etc/yum.repos.d/

yum clean all

#yum -y install jdk1.8.0_60
rpm -Uvh jdk-8u60-linux-x64.rpm

# 安装Cloudera Manager 5 RPMS
yum -y install cloudera-manager-agent

systemctl enable cloudera-scm-agent

clear
# 初始化时间服务
yum -y install ntpdate ntp
systemctl enable ntpd

ntphost="127.0.0.1"
temp=""
while [ "$temp" == "" ]; do
    read -p "Please input the ntp server ip: " temp
done

ntphost=$temp

sed -i 's/server.*/server '$ntphost'/' ntp/ntp-client.conf
cp -a ntp/ntp-client.conf /etc/ntp.conf
systemctl restart ntpd

clear
echo $splitter

function init_master(){

    cp -a ntp/ntp-server.conf /etc/ntp.conf
    systemctl restart ntpd
    
    echo $splitter    
    yum -y install cloudera-manager-server nginx mariadb-server
    systemctl enable cloudera-scm-server
    systemctl enable nginx
    systemctl enable mariadb
    
    clear
    
    echo $splitter
    systemctl stop mariadb
    
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
    
    exit
}

while true; do
    read -p "This node is master(Y/N)?" yn
    case $yn in
        [Yy]* ) init_master break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
