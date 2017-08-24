#!/bin/bash
#title      : 0_init_single_node.sh
#description: 初始化TIP
#author     : 王杰
#date       : 20170607
#version    : 1.0
#usage      : sh 0_init_single_node.sh
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

#/bin/bash $instroot/init_tip_internal.sh $master_ip  2>&1 | tee -a $instroot/log/5_init_tip.log
/bin/bash $instroot/_init_single_node.sh 2>&1 | tee $LOGDIR/0_init_single_node.log
