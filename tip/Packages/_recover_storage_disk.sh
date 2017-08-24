#!/bin/bash
#title          : recover_storage_disk.sh
#description    : 用于更换数据盘，并格式化成ext4.
#author         : 王杰
#date           : 20170615
#version        : 1.0
#usage          : sh recover_storage_disk.sh
#bash_version   :
#notes          : 换掉故障数据盘之前，不能关机或重启系统！否则，系统将无法启动！
#操作步骤：
#       1、直接拔出全部故障数据盘；
#       2、插入新的硬盘；
#       3、执行此脚本。
#==============================================================================
LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'

splitter="=============================================================================="

failureDataDiskId=()
failureMountPoints=()
failureDevs=()

currentDisks=()
newDisks=()

function print_title {
    echo ""
    echo $splitter
    echo $1
    echo $splitter
}

function press_enter_continue {
    temp=$1
    read -p "Press enter to continue..." temp
}

# 获取新加入系统的磁盘
function getNewDisks {

    # 从fstab获取原来的磁盘
    disksInfstab=()
    while read line; do
        if [[ $line =~ "/data/disks" ]]; then
            ret=`echo $line | awk -F ' ' '{print $1}'`
            #echo $ret
            length=${#disksInfstab[@]}
            disksInfstab[$length]=$ret
        fi
    done < /etc/fstab
    
    print_title "disks in fstab"
    echo ${disksInfstab[*]}
    
    print_title "find os disk"
    # 查找系统磁盘
    osdisk=`mount |grep /dev/sd | grep 'on /boot ' |awk '{print substr($1,1,8)}'`
    echo "Got os disk: $osdisk"
    
    echo $splitter
    # 用fdisk获取当前系统中的数据磁盘
    currentDisks=()
    
    # echo | awk -v osdisk="$osdisk" '{if($0~/sdk/)next}{print osdisk}'
    # fdisk -l |grep ' /dev/sd' | awk -v osdisk="$osdisk" '{if($0~/sdk/)next}{print $0}'
    #osdisk=${osdisk##*/}
    fdisk -l |grep ' /dev/sd' | awk -v osdisk=$osdisk '{if($0~/$osdisk/)next}{print $0}' | sort -k2 -n | awk -F ' ' '{print $2}' |awk -F ':' '{print $1}' > /tmp/currentDisks.txt
    #cat /tmp/currentDisks.txt
    
    while read line; do
        if [ "$line" != "$osdisk" ]; then
            length=${#currentDisks[@]}
            currentDisks[$length]=$line
        fi
    done < /tmp/currentDisks.txt
    
    print_title "currentDisks"
    echo ${currentDisks[*]}
    
    echo $splitter
    # 获取新盘
    newDisks=()
    
    for cdisk in ${currentDisks[@]};
    do
        found=""
        for osdisk in ${disksInfstab[@]};
        do
            if [ "$cdisk" = "$osdisk" ]; then
                found=$osdisk
            fi
        done
        
        if [ "$found" = "" ]; then
            length=${#newDisks[@]}
            newDisks[$length]=$cdisk
        fi
    done
    
    length=${#newDisks[@]}
    if [ $length == "0" ]; then 
        echo "There is no new disk found...exit."; exit;
    fi
    
    print_title "Got new disks "
    echo ${newDisks[*]}
}

# 获取故障的磁盘
function getFailureDisks {

    print_title "getFailureDisks"
    
    failureDataDiskId=()
    failureMountPoints=()
    failureDevs=()

    # 查找损坏磁盘的挂载点
    STORAGE_PREFIX=/data/disks
    for a in $(ls $STORAGE_PREFIX/ | sort -n); do 
        ret=`ls $STORAGE_PREFIX/$a |wc -l`
        if [ $ret == 0 ]; then
            mountpoint=$STORAGE_PREFIX/$a
            
            length=${#failureDataDiskId[@]}
            failureDataDiskId[$length]=$a
            
            length=${#failureMountPoints[@]}
            failureMountPoints[$length]=$mountpoint
        fi
    done
    
    echo $splitter
    echo "failureDataDiskId:"
    echo ${failureDataDiskId[*]}
    
    echo $splitter
    echo "failureMountPoints:"
    echo ${failureMountPoints[*]}
}

# # 在fstab中禁用故障的磁盘
# function disableFailureDisks {

    # print_title "disableFailureDisks"
    
    # # 注释掉/tmp/fstab中包含/data/disks/4的行
    # # cp /etc/fstab /tmp/fstab
    # # sed -i 's/^[^#].*\/data\/disks\/4/#&/' /tmp/fstab
    # #
    
    # cp /etc/fstab /root/fstab
    
    # cp /etc/fstab /tmp/fstab
    # for fid in ${failureDataDiskId[@]};
    # do
        # sed -i 's/^[^#].*\/data\/disks\/'$fid'/#&/' /tmp/fstab
    # done
    
    # cp /tmp/fstab /etc/fstab
    
    # cat /etc/fstab
    
    # echo $splitter
    # mount | grep /data/disks
# }

# 初始化新磁盘
function init_disk {

    device=$1
    
    umount -l $device
    echo "Y" | parted $device mklabel gpt
    echo "y" | mkfs.ext4 -m 0 -O dir_index,extent,sparse_super $device
    tune2fs -m 0 $device
}

# 加入新的磁盘
function addNewDisks {
    
    echo ${failureMountPoints[*]}
    echo ${newDisks[*]}
    
    failureMountPointsCount=${#failureMountPoints[@]}
    newDisksCount=${#newDisks[@]}
    
    loop=$newDisksCount
    if (( $loop > $failureMountPointsCount )); then
        loop=$failureMountPointsCount
    fi
    
    loop=`expr $loop - 1`
    for i in `seq 0 $loop`
    do
        newdisk=${newDisks[i]}
        mountpoint=${failureMountPoints[i]}
        
        msg="init "$newdisk" on "$mountpoint
        print_title "$msg"
        
        init_disk $newdisk
        
        mkdir -p $mountpoint
        
        # 不用挂载，系统重启后会自动使用原来的盘符，并挂载
        #mount -o noatime $newdisk $mountpoint        
        #echo "$newdisk    $mountpoint    ext4    defaults,noatime    0 0" >> /etc/fstab
        
    done
    
    echo $splitter
    mount | grep /data/disks
    
    echo $splitter
    cat /etc/fstab
}

getNewDisks

press_enter_continue

getFailureDisks

press_enter_continue

addNewDisks

print_title "OS will reboot after 10 seconds..."

sleep 10

#reboot


