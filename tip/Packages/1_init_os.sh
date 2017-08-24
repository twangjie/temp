#!/bin/bash
#title      : 1_init_os.sh
#description: 初始化操作系统，用于安装Hadoop
#author     : 王杰
#date       : 20170221
#version    : 1.0
#usage      : sh 1_init_os.sh
#notes      :
#==============================================================================

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'

temp=""
currentTime=`date "+%Y-%m-%d %H:%M:%S"`
echo "Current Time is $currentTime"
read -p "Please input a new time(format: yyyy-MM-dd hh:mm:ss): " temp
if [ "$temp" != "" ]; then
    echo "$temp"
    date -s "$temp"
    hwclock -w
fi

rm -f /root/anaconda-ks.cfg
rm -fr /var/log/anaconda

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

echo "echo 10 > /proc/sys/vm/swappiness" >> /etc/rc.d/rc.local

# 禁用透明大页面
cp -r /sys/kernel/mm/transparent_hugepage $backupdir/

if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
   echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi

echo "" >> /etc/rc.d/rc.local
echo "if test -f /sys/kernel/mm/transparent_hugepage/enabled; then" >> /etc/rc.d/rc.local
echo "   echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.d/rc.local
echo "fi" >> /etc/rc.d/rc.local
echo "if test -f /sys/kernel/mm/transparent_hugepage/defrag; then" >> /etc/rc.d/rc.local
echo "   echo never > /sys/kernel/mm/transparent_hugepage/defrag" >> /etc/rc.d/rc.local
echo "fi" >> /etc/rc.d/rc.local

chmod +x /etc/rc.d/rc.local

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

# 初始化hosts文件
hostfile=/etc/hosts
#ipprefix=`ip a |grep 192.168 |awk 'split($2,a,"."){print a[1]"."a[2]"."a[3]}'`
ipprefix=`cat ip.txt |awk 'split($0,a,"."){print a[1]"."a[2]"."a[3]}'`

echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" > $hostfile
echo "#::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> $hostfile
for((i=101;i<=200;i++));do echo $ipprefix.$i"    "host$i.tip.dccs.com.cn"    "host$i >> $hostfile; done ;

#sed -i '/.*\/opt\/dccs\/install\/1_init_os.sh.*/d' /etc/rc.d/rc.local

echo "OS initialized, reboot in 5 seconds..."
sleep 5

reboot
