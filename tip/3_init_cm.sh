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

# 复制mysql jdbc驱动
mkdir -p /usr/share/java
cp -a mysql-connector-java-5.1.34-bin.jar /usr/share/java/mysql-connector-java.jar

# 初始化tip.repo仓库（CentOS7.2 nginx cm5)

umount -l /media/CentOS

mkdir -p /media/CentOS/

mount -o loop CentOS7-TIP.iso /media/CentOS/

cp -a /etc/yum.repos.d $backupdir/
cp tip.repo /etc/yum.repos.d/

yum clean all

# 配置时间服务器

# 安装JDK
yum -y install jdk1.8.0_60

# 安装Cloudera Manager 5 RPMS
yum -y install cloudera-manager-agent
systemctl enable cloudera-scm-agent

clear
echo $splitter

function init_server(){
    yum -y install cloudera-manager-server nginx mariadb-server
    systemctl enable cloudera-scm-server
    systemctl enable nginx
    systemctl enable mariadb
    
    # 初始化Cloudera Manager MySQL数据库
    
    exit
}

while true; do
    read -p "This node is master(Y/N)?" yn
    case $yn in
        [Yy]* ) init_server break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
