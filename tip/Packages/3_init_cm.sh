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

# while true; do
    # read -p "This node is the master node?(y/n)?" yn
    # case $yn in
        # [Yy]* ) masterflag="Y"; break;;
        # [Nn]* ) break;;
        # * ) echo "Please answer y or n";;
    # esac
# done

# 直接使用host101作为master
hn=`hostname -s`
if [ $hn == "host101" ]; then
    masterflag="Y"
fi

splitter="=============================================================================="
backupdir=/opt/dccs/bak
instroot=/opt/dccs/install

#复制mysql jdbc驱动
mkdir -p /usr/share/java
cp -a mysql/mysql-connector-java-5.1.34-bin.jar /usr/share/java/mysql-connector-java.jar

if [ ! -d "$instroot/cdh/cm" ]; then  
    pushd $instroot/cdh
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

#cp /etc/fstab $backupdir/fstab
#cp /etc/fstab .
#echo "$instroot/CentOS7-TIP.iso /media/CentOS iso9660 ro,relatime 0 0" >> fstab
#cp fstab /etc/fstab

yum clean all

#yum -y install jdk1.8.0_60
rpm -Uvh jdk-8u60-linux-x64.rpm

# 安装Cloudera Manager 5 RPMS

yum -y remove cloudera-manager-agent
yum -y remove cloudera-manager-server
rm -fr /var/lib/cloudera-*

yum -y install cloudera-manager-agent
systemctl enable cloudera-scm-agent

echo
echo
echo $splitter
cmserver="host101.tip.dccs.com.cn"
temp=""

#sed -i 's/server_host=.*/server_host='$cmserver'/' /etc/cloudera-scm-agent/config.ini

systemctl stop cloudera-scm-agent

echo
# 初始化时间服务
yum -y install ntpdate ntp
systemctl enable ntpd

# 直接使用 Cloudera Manager server节点的ntp服务
ntphost=$cmserver

if [ $masterflag != "Y" ]; then
    cat ntp/ntp-client.conf > /etc/ntp.conf
    #sed -i 's/server .*/server '$ntphost'/' /etc/ntp.conf
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
    
    temp=""
    external_ip=""
    external_netmask="255.255.255.0"
    external_gateway=""
    external_dns=""
    netconf=/etc/sysconfig/network-scripts/ifcfg-bond0
    cp $netconf $backupdir/
    
    read -p "Please input the external ip: " temp
    if [ "$temp" != "" ]; then
        external_ip=$temp
        
        temp=""
        read -p "Please input the netmask for external ip $external_ip[default: $external_netmask]: " temp
        if [ "$temp" != "" ]; then
            external_netmask=$temp
        fi
        
        temp=""
        read -p "Please input the gateway for external ip [$external_ip]: " temp
        if [ "$temp" != "" ]; then
            external_gateway=$temp
        fi
        
        temp=""
        read -p "Please input the dns for external ip [$external_ip]: " temp
        if [ "$temp" != "" ]; then
            external_dns=$temp
        fi        
    fi
    
    if [[ "$external_ip" != "" ]] && [[ "$external_netmask" != "" ]]; then
        echo "IPADDR2=$external_ip" >> $netconf
        echo "NETMASK2=$external_netmask" >> $netconf
        
        if [ "$external_gateway" != "" ];then
            echo "GATEWAY2=$external_gateway" >> $netconf
        fi
        
        if [ "$external_dns" != "" ];then
            echo "DNS2=$external_dns" >> $netconf
        fi
    fi
    
    ntphost="127.0.0.1"
    if [[ "$external_ip" != "" ]] && [[ "$external_netmask" != "" ]]; then
        read -p "Please input the external ntp server ip[default: 127.0.0.1]: " temp
        if [ "$temp" != "" ]; then
            ntphost=$temp
        fi
    fi
        
    cat ntp/ntp-server.conf > /etc/ntp.conf
    sed -i 's/server external/server '$ntphost'/' /etc/ntp.conf
        
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
    cp -a $instroot/cdh/parcel-repo/* /opt/cloudera/parcel-repo/
    echo    
    echo $splitter
    
    # 配置nginx
    rm -fr /etc/nginx/conf.d
    rm -f /etc/nginx/nginx.conf
    cp -a $instroot/nginx/* /etc/nginx
    rm -f /etc/nginx/conf.d/http/flumeproxy.conf
    rm -f /etc/nginx/conf.d/http/tip.conf
    
    echo    
    echo $splitter
    
    cp -a mysql/my.cnf /etc/
    rm -fr /var/lib/mysql/*
    cp -a mysql/mysqldb.tar.gz /var/lib/mysql.tar.gz 
    pushd /var/lib/
    tar -xf mysql.tar.gz
    chown mysql:mysql -R /var/lib/mysql
    popd

    systemctl restart mariadb

    echo $splitter
    
    JAVA_HOME=/usr/java/latest
    
    mysql -uroot -pDccs12345. < mysql/grant.sql
    mysql -uroot -pDccs12345. < mysql/cm.sql
    /usr/share/cmf/schema/scm_prepare_database.sh mysql -h 127.0.0.1 -uroot -pDccs12345. --scm-host 127.0.0.1 scm scm scm --force
    
    mkdir -p /var/lib/cloudera-scm-server
    chown cloudera-scm:cloudera-scm /var/lib/cloudera-scm-server
    
    systemctl restart cloudera-scm-server
    systemctl restart nginx
        
    echo
    echo "Cloudera Manager(Master) initialize finished, Sleep 30 seconds for cloudera-scm-server..."
    sleep 30
}

if [ $masterflag == "Y" ]; then
    init_master    
fi

echo "Cloudera Manager Agent initialize finished..."

