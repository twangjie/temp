#!/bin/bash
#title           : 1_init_os.sh
#description     : 初始化操作系统，用于安装Hadoop
#author		 	 : 王杰
#date            : 20170221
#version         : 1.0
#usage		 	 : sh 1_init_os.sh
#notes           :
#bash_version    :
#==============================================================================

currentTime=`date "+%Y%m%d%H%M%S"`

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'

backupdir=/opt/dccs/bak

mkdir -p $backupdir

# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 禁用selinux
setenforce 0

cp /etc/selinux/config $backupdir/
sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

# 禁用swap
sysctl -w vm.swappiness=10

cp /etc/sysctl.conf $backupdir/
echo "vm.swappiness=10" >> /etc/sysctl.conf

# 禁用透明大页面
cp -r /sys/kernel/mm/transparent_hugepage $backupdir/

echo "echo never > /sys/kernel/mm/transparent_hugepage/defrag " >> /etc/rc.local
echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.local
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled

# 修改文件打开数限制
ulimit -n 1048576
cp /etc/security/limits.conf $backupdir/
echo "*  soft  nproc  1048576" >> /etc/security/limits.conf
echo "*  hard  nproc  1048576" >> /etc/security/limits.conf
echo "*  soft  nofile  1048576" >> /etc/security/limits.conf
echo "*  hard  nofile  1048576" >> /etc/security/limits.conf

bondcfg=/etc/sysconfig/network-scripts/ifcfg-bond0
if [ -f $bondcfg ]; then
    cp $bondcfg $backupdir/
    sed -i 's/BOOTPROTO=.*/BOOTPROTO=static/' $bondcfg 
fi

if false; then

    # 修改网络配置

    # 备份原有网络配置

    pushd /etc/sysconfig/network-scripts
    tar -czf $backupdir/network-scripts-$currentTime.tar.gz .
    popd

    # 网卡列表
    devs=`nmcli dev status |awk 'BEGIN{getline a}{print a;a=$0}' | awk 'NR>1{print $1}'`
    echo $devs

    # 创建bond0
    nmcli conn add type bond con-name bond0 ifname bond0 mode 0

    # 创建slave
    echo $devs | awk '{i=1; while(i <= NF) {print "nmcli conn add type bond-slave con-name bond-slave-"$i" ifname "$i" master bond0";i++}}' > cmd.sh

    sh cmd.sh
    rm -f cmd.sh

    ipaddr=""
    while [ "$ipaddr" == "" ]; do
        echo " *** Please input the IP address: *** "
        read -p "[e.g.: 192.168.36.101]: " ipaddr
    done

    # 修改bond0的网卡地址
    nmcli conn mod bond0 ipv4.addresses "$ipaddr/24" 
    nmcli conn mod bond0 ipv4.method manual
    systemctl restart network

fi

echo "OS initialized, reboot in 10 seconds..."
sleep 10

reboot
