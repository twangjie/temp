#!/bin/bash
#title      : reg.sh
#description: 注册加密狗
#author     : 王杰
#date       : 20171027
#version    : 1.0
#usage      : sh reg.sh DOGTYPE /path/to/licfile
#             DOGTYPE ->  1:ActiveTrailDog 2:ActiveSoftDog 3:UpdateHardDog 4:RehostSoftDog
#notes      :
#==============================================================================

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'
clear

splitter="=============================================================================="
INSTALLER_ROOT=/opt/dccs/install

cd $INSTALLER_ROOT

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

clear
print_time

if [ "$1" == "" ]; then
    echo "Please specify the dog type."
    exit 1
fi

if [ "$2" == "" ]; then
    echo "Please specify a license file!"
    exit 1
fi

DOGTYPE=$1
LICFILE=$2

cp $LICFILE $INSTALLER_ROOT/dog/LDKToolsForLinux/licfile
chmod 755 $INSTALLER_ROOT/dog/LDKToolsForLinux/DCCS*

retVal=`docker ps -f name=tipworker | wc -l`
if [ $retVal -eq 2 ]; then 
    print_title "Active single node model"
    
    docker ps -a
    echo $splitter
    
    tar -czf dog.tar.gz dog
    docker exec -i tipworker bash -c "mkdir -p $INSTALLER_ROOT"
    docker cp dog.tar.gz tipworker:$INSTALLER_ROOT/
    rm -f dog.tar.gz
    
    docker exec -i tipworker bash -c "cd $INSTALLER_ROOT/; 
    tar -xf dog.tar.gz;
    cd $INSTALLER_ROOT/dog;
    rpm -Uvh --nodeps rpms/nss-softokn-freebl-3.16.2.3-13.el7_1.i686.rpm;
    rpm -Uvh --nodeps rpms/glibc-2.17-105.el7.i686.rpm;
    tar -xf aksusbd-*.tar.gz;
    cd aksusbd-7.51.1-i386;
    chmod 755 *;
    ./dunst;
    ./dinst;
    cd ..;
    cp haspvlib_111426.so /var/hasplm/"
    
    print_title "Restart tipworker"
    docker restart tipworker
    echo $splitter
    echo "Wait 15 seconds..."
    sleep 15
    
    echo $splitter
    docker exec -i tipworker bash -c "cd $INSTALLER_ROOT/dog/LDKToolsForLinux;
    ./DCCSSoftDogActive $DOGTYPE licfile"
    
else
    print_title "Active cluster model"

    echo ""
    echo "Using the LIC file($LICFILE) to activate."
    echo ""
    echo ""
    pushd $INSTALLER_ROOT/dog/LDKToolsForLinux/
    ./DCCSSoftDogActive $DOGTYPE licfile
    popd
fi

