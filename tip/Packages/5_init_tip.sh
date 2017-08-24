#!/bin/bash
#title      : 5_init_tip.sh
#description: 初始化TIP
#author     : 王杰
#date       : 20170221
#version    : 1.0
#usage      : sh 5_init_tip.sh
#notes      :
#==============================================================================

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'
clear

instroot=/opt/dccs/install
LOGDIR=$instroot/logs

mkdir -p $LOGDIR

splitter='=============================================================================='
echo ""
echo $splitter
master_ip="host101.tip.dccs.com.cn"
temp=$1
while [ "$temp" == "" ]; do
    read -p "Please input the master ip [e.g.: 192.168.36.101 ]: " temp
done
master_ip=$temp

/bin/bash $instroot/init_tip_internal.sh $master_ip  2>&1 | tee -a $LOGDIR/5_init_tip.log
