#!/bin/bash
#title      : init_docker_env.sh
#description: 初始化DOCKER
#author     : 王杰
#date       : 20170711
#version    : 1.0
#usage      : first run
#notes      :
#==============================================================================

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'
clear

splitter="=============================================================================="
backupdir=/opt/dccs/bak
instroot=/opt/dccs/install
LOGDIR=$instroot/logs

function print_title {
    echo ""
    echo $splitter
    echo $1
    echo $splitter
}

function print_time {
    currentTime=`date "+%Y-%m-%d %H:%M:%S %Z"`
    msg="Now: "$currentTime
    print_title "$msg"
}

echo ""
print_time

mkdir -p $backupdir
mkdir -p $LOGDIR

print_title "backup rc.local file"
cat /root/rc.local.bak > /etc/rc.d/rc.local

print_title "extend docker thinpool metadata size"
lvextend --poolmetadatasize +100M /dev/vgcentos/thinpool

print_title "change docker thinpool lv profile"
echo 'activation {
  thin_pool_autoextend_threshold=80
  thin_pool_autoextend_percent=20
}' > /etc/lvm/profile/docker-thinpool.profile

lvchange --metadataprofile docker-thinpool vgcentos/thinpool

print_title "list physical volumes"
pvdisplay

print_title "list logical groups"
vgdisplay

print_title "list logical volumes"
lvdisplay

print_title "list logical volumes seg_monitor"
lvs -o+seg_monitor

print_title "partprobe"
partprobe

print_title "lsblk"
lsblk

print_title "update docker daemon configuration"
mkdir -p /etc/docker
echo '{                           
    "storage-driver": "devicemapper",
    "storage-opts": [
        "dm.thinpooldev=/dev/mapper/vgcentos-thinpool",
        "dm.use_deferred_removal=true",
        "dm.fs=xfs",
        "dm.basesize=100G"
    ]
}' > /etc/docker/daemon.json

print_title "enable and start docker service"
systemctl enable docker
systemctl start docker

#print_title "call 2_init_storage.sh"
#/bin/sh $instroot/2_init_storage.sh | /bin/tee /opt/dccs/install/logs/2_init_storage.log

#print_title "call 1_init_os.sh"
#/bin/sh $instroot/1_init_os.sh | /bin/tee /opt/dccs/install/logs/1_init_os.log



