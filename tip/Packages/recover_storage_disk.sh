#!/bin/bash
#title      : _recover_storage_disk.sh
#description: 恢复数据盘
#author     : 王杰
#date       : 20170221
#version    : 1.0
#usage      : /bin/bash $instroot/_recover_storage_disk.sh | tee -a $instroot/log/_recover_storage_disk.log
#notes      :
#==============================================================================

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'
clear

instroot=/opt/dccs/install

mkdir -p $instroot/log


/bin/bash $instroot/_recover_storage_disk.sh | tee -a $instroot/log/_recover_storage_disk.log
