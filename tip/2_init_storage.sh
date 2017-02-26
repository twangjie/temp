#!/bin/bash
#title          : 2_init_storage.sh
#description    :  初始化除操作系统所在磁盘之外的所有磁盘，并格式化成ext4.
#author         : 王杰
#date           : 20170221
#version        : 1.0
#usage          : sh 2_init_storage.sh
#notes          :
#bash_version   :
#==============================================================================
LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'

clear

splitter="=============================================================================="
backupdir=/opt/dccs/bak

mkdir -p $backupdir
echo 
echo $splitter

# 查找系统磁盘
osdisk=`mount |grep /dev/sd | grep 'on / ' |awk '{print substr($1,1,8)}'`
echo $osdisk > osdisk.txt

# 获取所有大于32GB的磁盘，并按容量升序排列
fdisk -l |grep ' /dev/' | awk -F ' ' '{if($5>32000000000){print $0}}' | sort -k2 -n > disks.txt

echo
echo "Storage disks to initialize..."
echo
while read line; do
    device=`echo $line | awk -F ' ' '{print substr($2,1,8)}'`
    if [ "$device" != "$osdisk" ]; then
        echo $line
    fi
done < disks.txt

temp=""
echo $splitter
echo
read -p "Press enter to confirm to continue..." temp

# 格式化除系统盘以外的存储盘，并挂载
if [ ! -f "$backupdir/fstab.ori" ]; then
    cp /etc/fstab $backupdir/fstab.ori
else
    cp $backupdir/fstab.ori /etc/fstab
fi

i=1
while read line; do 
    device=`echo $line | awk -F ' ' '{print substr($2,1,8)}'`
    if [ "$device" != "$osdisk" ]; then
        echo
        
        umount -l $device
        
        echo "Y" | parted $device mklabel gpt
        echo "y" | mkfs.ext4 -m 0 -O dir_index,extent,sparse_super $device
        tune2fs -m 0 $device
        
        mountpoint=/data/disks/$i
        mkdir -p $mountpoint
        
        mount -o noatime $device $mountpoint
        
        echo "$device    $mountpoint    ext4    defaults,noatime    0 0" >> /etc/fstab
        
        let i=i+1
    fi
done < disks.txt

echo 
echo $splitter

echo "Storage disks were mounted on..."
df -h |awk 'NR==1{print $0}'
df -h |awk 'NR>1{print $0}' | grep '/data/disks'

rm -f osdisk.txt
rm -f disks.txt

echo 
echo "Storage disks initialization finished..."

