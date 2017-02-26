#!/bin/bash
#title          : 2_init_storage.sh
#description    : 初始化除操作系统所在磁盘之外的所有磁盘，并格式化成ext4.
#author         : 王杰
#date           : 20170221
#version        : 1.0
#usage          : sh 2_init_storage.sh
#notes          :
#==============================================================================
LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'

backupdir=/opt/dccs/bak

mkdir -p $backupdir

# 查找系统磁盘
osdisk=`mount |grep /dev/sd | grep 'on / ' |awk '{print substr($1,1,8)}'`
echo $osdisk > osdisk.txt

# 获取所有大于32GB的磁盘
fdisk -l |grep ' /dev/' | awk -F ' ' '{if($5>32000000000){print substr($2,1,8)}}' > disks.txt
#cat disks.txt
echo "Storage disks to initialize..."
while read line; do 
    if [ "$line" != "$osdisk" ]; then
        echo $line
    fi
done < disks.txt

temp=""
echo
read -p "Press enter to continue..." temp

# 格式化除系统盘以外的存储盘，并挂载
if [ ! -f "$backupdir/fstab.ori" ]; then
    cp /etc/fstab $backupdir/fstab.ori
else
    cp $backupdir/fstab.ori /etc/fstab
fi

i=1
while read line; do 
    if [ "$line" != "$osdisk" ]; then
        echo 
        echo "Y" | parted  $line mklabel gpt
        echo "y" | mkfs.ext4 -m 0 -O dir_index,extent,sparse_super $line
        tune2fs -m 0 $line
        
        mountpoint=/data/disks/$i
        mkdir -p $mountpoint
        
        mount -o noatime $line $mountpoint
        
        echo "$line    $mountpoint    ext4    defaults,noatime    0 0" >> /etc/fstab
        
        let i=i+1
    fi
done < disks.txt

df -h

rm -f osdisk.txt
rm -f disks.txt

echo 
echo "Storage disks initialization finished..."

