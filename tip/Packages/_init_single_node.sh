#!/bin/bash
#title          : _7_init_single_node.sh
#description    : 初始化docker单节点
#author         : 王杰
#date           : 20170601
#version        : 1.0
#usage          : sh 0_init_single_node.sh
#notes          :
#bash_version   :
#==============================================================================

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'

splitter="=============================================================================="
INSTALLER_ROOT=/opt/dccs/install
INSTALLER_ROOT_DOCKER=/opt/dccs/install/docker
INSTALLER_ROOT_CDH=/opt/dccs/install/cdh

TIP_ROOT=/opt/dccs/tip
DOCKER_CONTAINER_DATA_ROOT=/data/docker

STORAGE_PREFIX=/data/disks
CLOUDERA_ROOT=/opt/cloudera

OS_DOCKER_IMAGE=centos:7.2.1511
CDH_DOCKER_IMAGE=c7-cm

NETWORK_SURFIX=tip-bridge-network
NETWORK_IP_SUBNET=192.168.50.0/24
NETWORK_DOCKER_HOST_IP=192.168.50.1
ROOT_PWD=Dccs12345.
CM_USER=admin
CM_PASSWD=Dccs12345.
CM_BASIC_AUTH_PWD="YWRtaW46RGNjczEyMzQ1Lg=="

TIP_ROOT_VOL_NAME=tiproot

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

function config_external_ip {

    print_title "Config external ip address"

    temp=""
    external_ip=""
    external_netmask="255.255.255.0"
    external_gateway=""
    external_dns=""
    netconf=/etc/sysconfig/network-scripts/ifcfg-bond0
    
    retVal=`cat $netconf |grep IPADDR2 |wc -l`    
    if [ "$retVal" == "1" ]; then
        echo "IPADD2 is exists..."
        return;
    fi
    
    cp $netconf $backupdir/
    
    read -p "Please input the external ip: " temp
    if [ "$temp" != "" ]; then
        external_ip=$temp
        
        temp=""
        read -p "Please input the netmask for this external ip [default: $external_netmask]: " temp
        if [ "$temp" != "" ]; then
            external_netmask=$temp
        fi
        
        temp=""
        read -p "Please input the gateway for this external ip: " temp
        if [ "$temp" != "" ]; then
            external_gateway=$temp
        fi
        
        temp=""
        read -p "Please input the dns for this external ip: " temp
        if [ "$temp" != "" ]; then
            external_dns=$temp
        fi        
    fi
    
    if [[ "$external_ip" != "" ]] && [[ "$external_netmask" != "" ]]; then
        echo "" >> $netconf
        echo "IPADDR2=$external_ip" >> $netconf
        echo "NETMASK2=$external_netmask" >> $netconf
        
        if [ "$external_gateway" != "" ];then
            echo "GATEWAY2=$external_gateway" >> $netconf
        fi
        
        if [ "$external_dns" != "" ];then
            echo "DNS2=$external_dns" >> $netconf
        fi
    fi
    
    systemctl restart network
    systemctl restart docker
}

function init {

    print_title "init"
    
    sed -i '/.*\/opt\/dccs\/tip\/tip.sh/d' /var/spool/cron/root
    
    cd $INSTALLER_ROOT_DOCKER
    ls -lh

    mkdir -p $INSTALLER_ROOT
    mkdir -p $TIP_ROOT
    mkdir -p $INSTALLER_ROOT_DOCKER

    if [ -d $DOCKER_CONTAINER_DATA_ROOT ];then 
        systemctl stop docker
        pushd $DOCKER_CONTAINER_DATA_ROOT
            currentTime=`date "+%Y%m%d%H%M%S"`
            tar -czf /data/docker-$currentTime.tar.gz .
        popd
    fi
    
    rm -fr $DOCKER_CONTAINER_DATA_ROOT/*
    mkdir -p $DOCKER_CONTAINER_DATA_ROOT
    
    mkdir /media/CentOS
    umount /media/CentOS

    retVal=`cat /etc/fstab |grep 'CentOS7-TIP.iso' |wc -l`
    if [ $retVal == 0 ]; then
        echo "/opt/dccs/install/CentOS7-TIP.iso    /media/CentOS    iso9660    ro,relatime    0 0" >> /etc/fstab
    fi
    
    cat /etc/fstab
    
    mount -o loop $INSTALLER_ROOT/CentOS7-TIP.iso /media/CentOS

    if [ ! -d /opt/dccs/install/cdh/cm ];then 
        pushd /opt/dccs/install/cdh
            tar -xf cm*.tar.gz
        popd
    fi
    
    cp -a $INSTALLER_ROOT/python2.7-cmapi.tar.gz /usr/lib/python2.7.tar.gz
    pushd /usr/lib/
    tar -xf python2.7.tar.gz
    popd
    
    python2 -V
}

function init_dog {

    print_title "Init dog..."

    pushd $INSTALLER_ROOT
    
    tar -czf dog.tar.gz dog
    docker exec -i tipworker bash -c "mkdir -p $INSTALLER_ROOT"
    docker cp dog.tar.gz tipworker:$INSTALLER_ROOT
    rm -f dog.tar.gz

    docker exec -i tipworker bash -c "cd $INSTALLER_ROOT; 
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
    cp haspvlib_111426.so /var/hasplm/;
    rm -fr $INSTALLER_ROOT/dog*"
    
    cd $INSTALLER_ROOT/dog
    
    rpm -Uvh --nodeps rpms/nss-softokn-freebl-3.16.2.3-13.el7_1.i686.rpm
    rpm -Uvh --nodeps rpms/glibc-2.17-105.el7.i686.rpm
    tar -xf aksusbd-*.tar.gz
    cd aksusbd-7.51.1-i386
    chmod 755 *
    ./dunst
    ./dinst
    cd ..
    rm -fr aksusbd-7.51.1-i386
    
    cp haspvlib_111426.so /var/hasplm/
    
    popd
}

# 初始化 docker 服务
# 依赖单机版tip安装程序中的docker初始化服务
function init_docker {
    
    print_title "init_docker"
    
    # 安装docker服务
    retVal=`rpm -qa |grep "docker-engine" |wc -l`
    
    if [ $retVal == 0 ]; then
        mkdir /media/CentOS
        mount -o loop /opt/dccs/install/CentOS7-TIP.iso /media/CentOS
        
        pushd /media/CentOS/Packages
        yum -y localinstall docker-engine*
        popd
    fi
    
    docker info

    systemctl enable docker
    systemctl restart docker
    
    sleep 5
    
    systemctl status docker
    
    # 启动nginx文件服务
    if [ -d /etc/nginx ];then 
        pushd /etc
            tar -czf nginx.tar.gz nginx
            yum -y remove nginx-1*
            rm -fr nginx
        popd
    fi

    pushd /media/CentOS/Packages
        yum -y localinstall nginx-1*
    popd

    rm -fr /etc/nginx/conf.d/*

    cat $INSTALLER_ROOT/nginx/conf.d/http/cm.conf > /etc/nginx/conf.d/default.conf
    systemctl restart nginx
    systemctl status nginx
    netstat -anop |grep nginx
    
    pushd $INSTALLER_ROOT_DOCKER

        # 加载centos7.2.1511 docker镜像
        retVal=`docker images |grep centos |grep "7.2.1511" | wc -l`
        if [ $retVal == 0 ]; then
            gunzip -c centos7.2.tar.gz | docker load
        fi
        
        # 创建centos7 systemd基础镜像
        retVal=`docker images |grep c7-systemd |grep "7.2.1511" | wc -l`
        if [ $retVal == 0 ]; then
            pushd $INSTALLER_ROOT_DOCKER/build/c7-systemd
                docker build -t c7-systemd:7.2.1511 --no-cache --force-rm .
            popd
        fi

        # 创建Cloudera Manager镜像
        retVal=`docker images |grep c7-cm |wc -l`
        if [ $retVal == 0 ]; then
                        
            pushd $INSTALLER_ROOT_DOCKER/build/cm
            
                #HOST="172.17.0.1"
                HOST=`ip a |grep docker0 |grep inet |awk -F ' ' 'NR==1{print $2}' |awk -F '/' '{print $1}'`

                sed 's/HOST/'$HOST'/' docker_files/cloudera-cdh5.repo.tp > docker_files/cloudera-cdh5.repo
                cat docker_files/cloudera-cdh5.repo
                
                docker build -t c7-cm --rm .
            
            popd
        fi
    
    popd

    docker images
    
    #docker run -it --rm $CDH_DOCKER_IMAGE bash -c "rpm -qa |grep cloudera"
    CONTAINER_NAME=cmtest
    docker run -itd --name $CONTAINER_NAME --hostname=$CONTAINER_NAME --privileged=true -v /sys/fs/cgroup:/sys/fs/cgroup:ro $CDH_DOCKER_IMAGE
    docker ps -a
    docker exec -it $CONTAINER_NAME bash -c "systemctl status cloudera-scm-server cloudera-scm-agent -l";
    docker rm -f $CONTAINER_NAME
}

function cleanup_docker {

    print_title "cleanup_docker" 
    
    docker ps -a
    docker rm -f $(docker ps -a -q -f name=tip)
}

function init_tip_network {

    print_title "init_tip_network"
    
    # 创建专用桥接网络
    docker network rm $NETWORK_SURFIX
    docker network create -d bridge --subnet $NETWORK_IP_SUBNET $NETWORK_SURFIX
    docker network inspect $NETWORK_SURFIX
}

function init_assign_root_pwd {

    DOCKER_CONTAINER_NAME=$1

    echo "root:$ROOT_PWD" | docker exec -i $DOCKER_CONTAINER_NAME chpasswd
    
    docker cp $INSTALLER_ROOT_DOCKER/passwd $DOCKER_CONTAINER_NAME:/root/passwd
    docker cp $INSTALLER_ROOT_DOCKER/group $DOCKER_CONTAINER_NAME:/root/group
    docker exec $DOCKER_CONTAINER_NAME bash -c "cat /root/passwd >> /etc/passwd"
    docker exec $DOCKER_CONTAINER_NAME bash -c "cat /root/group >> /etc/group"
}

# 添加scm用户
function init_scm_user {
    
    print_title "Initialize scm tip user"
    
    scm_update_sql_file=$INSTALLER_ROOT/tip/scm_update.sql

    echo "use scm;" > $scm_update_sql_file
    echo "delete from USER_ROLES;" >> $scm_update_sql_file
    echo "delete from USERS;" >> $scm_update_sql_file
    cat $scm_update_sql_file
    
    docker cp $scm_update_sql_file tipmanager:/root/
    docker exec tipmanager bash -c "mysql -uscm -pscm -h127.0.0.1 < /root/scm_update.sql"
    
    # 初始化admin账户,cm将自动创建admin账户
    # admin:admin
    curl --request GET --url 'http://127.0.0.1:7180/api/v14/cm/deployment?export_redacted=' --header 'authorization: Basic YWRtaW46YWRtaW4='
    
    echo "use scm;" > $scm_update_sql_file
    
    #echo "INSERT INTO scm.\`USERS\` VALUES(1,'admin', 'bff874ae5f7e76de50a41f3b25ac920f36748916b910058f5a8e50f081cb8956', '4886966597668923524', 1, 1);" >> $scm_update_sql_file
    #echo "INSERT INTO scm.\`USER_ROLES\` VALUES(1,1,'ROLE_ADMIN',0);" >> $scm_update_sql_file
    # admin:Dccs12345.
    echo "update scm.\`USERS\` set PASSWORD_HASH='bff874ae5f7e76de50a41f3b25ac920f36748916b910058f5a8e50f081cb8956', PASSWORD_SALT='4886966597668923524' WHERE USER_NAME='admin';" >> $scm_update_sql_file
    
    # __cloudera_internal_user__TIP:__cloudera_internal_user__TIP
    #echo "INSERT INTO scm.\`USERS\` VALUES(1000,'__cloudera_internal_user__TIP', 'a1edda288e2a4be0a002c594ead6e5da2b9a633a1784a756a66a3db06c907921', '230065777681863511', 1, 1);" >> $scm_update_sql_file
    #echo "INSERT INTO scm.\`USER_ROLES\` VALUES(1000,1000,'ROLE_ADMIN',0);" >> $scm_update_sql_file
    
    # TIP:TIP
    #echo "INSERT INTO scm.\`USERS\` VALUES(2,'TIP', '3cb01fa8eeccff1f2de862a86a53f01e2b6133ac400feaa2931d3a79f5d2d472', '-7058880479751943883', 1, 0);" >> $scm_update_sql_file
    #echo "INSERT INTO scm.\`USER_ROLES\` VALUES(2,2,'ROLE_USER',0);" >> $scm_update_sql_file
    
    cat $scm_update_sql_file
    
    docker cp $scm_update_sql_file tipmanager:/root/
    docker exec tipmanager bash -c "mysql -uscm -pscm -h127.0.0.1 < /root/scm_update.sql"
    
    rm -f $scm_update_sql_file
}

function init_ntp_server {

    DOCKER_CONTAINER_NAME=$1

    cat $INSTALLER_ROOT/ntp/ntp-server.conf > /tmp/ntp.conf
    sed -i 's/server external/server '$NETWORK_DOCKER_HOST_IP'/' /tmp/ntp.conf
    cat /tmp/ntp.conf
    
    cat /tmp/ntp.conf > /etc/ntp.conf
    systemctl enable ntpd; systemctl restart ntpd; sleep 5; ntpdc -np
    
    docker cp /tmp/ntp.conf $DOCKER_CONTAINER_NAME:/etc/ntp.conf    
    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl enable ntpd;systemctl restart ntpd;systemctl status ntpd;sleep 5;ntpdc -np"
}

function init_ntp_client {

    DOCKER_CONTAINER_NAME=$1

    cat $INSTALLER_ROOT/ntp/ntp-client.conf > /tmp/ntp.conf
    sed -i 's/server host101.tip.dccs.com.cn/server '$NETWORK_DOCKER_HOST_IP'/' /tmp/ntp.conf
    cat /tmp/ntp.conf
    
    docker cp /tmp/ntp.conf $DOCKER_CONTAINER_NAME:/etc/ntp.conf
    
    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl enable ntpd;systemctl restart ntpd;systemctl status ntpd"
    sleep 5
    docker exec $DOCKER_CONTAINER_NAME bash -c "ntpdc -np"
}

# 更新容器中路径的权限
function update_privileges {

    DOCKER_CONTAINER_NAME=$1

    print_title "update privileges for "$DOCKER_CONTAINER_NAME
    
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/mariadb; chown -R mysql:mysql /var/log/mariadb"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R mysql:mysql /var/lib/mysql"
    
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R cloudera-scm:cloudera-scm /var/lib/cloudera-*"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R cloudera-scm:cloudera-scm /var/log/cloudera-*"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R cloudera-scm:cloudera-scm /etc/cloudera-*"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R cloudera-scm:cloudera-scm /opt/cloudera/*"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chmod -R 777 /etc/cloudera-*"    
}

function init_log_directories {

    DOCKER_CONTAINER_NAME=$1
    
    print_title "init_log_directories for "$DOCKER_CONTAINER_NAME
    
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/cloudera-scm-agent"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/cloudera-scm-server"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/flume-ng"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/hadoop-0.20-mapreduce"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/hadoop-hdfs"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/hadoop-mapreduce"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/hadoop-yarn"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/hbase"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/hive"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/hcatalog"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/catalogd"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/impala"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/impalad"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/impala-llama"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/impala-minidumps"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/statestore"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/spark"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/zookeeper"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/kudu"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/hue"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/solr"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /var/log/mariadb"

    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R cloudera-scm:cloudera-scm /var/log/cloudera-scm-agent"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R cloudera-scm:cloudera-scm /var/log/cloudera-scm-server"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R impala:impala /var/log/flume-ng"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R root:hadoop /var/log/hadoop-0.20-mapreduce"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R hdfs:hadoop /var/log/hadoop-hdfs"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R mapred:hadoop /var/log/hadoop-mapreduce"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R yarn:hadoop /var/log/hadoop-yarn"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R hbase:hbase /var/log/hbase"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R hive:hive /var/log/hive"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R hive:hive /var/log/hcatalog"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R impala:impala /var/log/catalogd"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R impala:impala /var/log/impala"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R impala:impala /var/log/impalad"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R impala:impala /var/log/impala-llama"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R impala:impala /var/log/impala-minidumps"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R impala:impala /var/log/statestore"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R spark:spark /var/log/spark"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R zookeeper:zookeeper /var/log/zookeeper"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R kudu:kudu /var/log/kudu"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R hue:hue /var/log/hue"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R solr:solr /var/log/solr"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R mysql:mysql /var/log/mariadb"

}

# 初始化tipmanager
function init_tipmanager {

    print_title "init_tipmanager"
    
    DOCKER_CONTAINER_NAME=tipmanager
    DOCKER_CONTAINER_DATA_DIR=$DOCKER_CONTAINER_DATA_ROOT/$DOCKER_CONTAINER_NAME
    
    rm -fr $DOCKER_CONTAINER_DATA_DIR/*
    cp -a $INSTALLER_ROOT_DOCKER/tipmanager-data.tar.gz $DOCKER_CONTAINER_DATA_ROOT/tipmanager.tar.gz

    pushd $DOCKER_CONTAINER_DATA_ROOT
        tar -xf tipmanager.tar.gz
    popd
    
    # docker run -itd --name $DOCKER_CONTAINER_NAME --hostname=$DOCKER_CONTAINER_NAME.$NETWORK_SURFIX --network=$NETWORK_SURFIX --privileged=true \
    # -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /media/CentOS:/media/CentOS:ro \
    # -v $DOCKER_CONTAINER_DATA_DIR/etc/cloudera-scm-server:/etc/cloudera-scm-server \
    # -v $DOCKER_CONTAINER_DATA_DIR/etc/cloudera-scm-agent:/etc/cloudera-scm-agent \
    # -v $DOCKER_CONTAINER_DATA_DIR/var/lib/mysql:/var/lib/mysql \
    # -v $DOCKER_CONTAINER_DATA_DIR/var/lib/cloudera-scm-server:/var/lib/cloudera-scm-server \
    # -v $DOCKER_CONTAINER_DATA_DIR/var/lib/cloudera-scm-agent:/var/lib/cloudera-scm-agent \
    # -v $DOCKER_CONTAINER_DATA_DIR/var/lib/cloudera-scm-eventserver:/var/lib/cloudera-scm-eventserver \
    # -v $DOCKER_CONTAINER_DATA_DIR/var/lib/cloudera-host-monitor:/var/lib/cloudera-host-monitor \
    # -v $DOCKER_CONTAINER_DATA_DIR/var/lib/cloudera-service-monitor:/var/lib/cloudera-service-monitor \
    # -v $DOCKER_CONTAINER_DATA_DIR/var/log:/var/log \
    # -v $DOCKER_CONTAINER_DATA_DIR/opt/cloudera/parcel-cache:$CLOUDERA_ROOT/parcel-cache \
    # -v $DOCKER_CONTAINER_DATA_DIR/opt/cloudera/parcels:$CLOUDERA_ROOT/parcels \
    # -v $DOCKER_CONTAINER_DATA_DIR/opt/cloudera/csd:$CLOUDERA_ROOT/csd \
    # -v $INSTALLER_ROOT_CDH/parcel-repo:$CLOUDERA_ROOT/parcel-repo \
    # -p 7180:7180 \
    # -p 33306:3306 \
    # $CDH_DOCKER_IMAGE
    
    docker run -itd --name $DOCKER_CONTAINER_NAME --hostname=$DOCKER_CONTAINER_NAME.$NETWORK_SURFIX --network=$NETWORK_SURFIX --privileged=true \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /media/CentOS:/media/CentOS:ro \
    -v $DOCKER_CONTAINER_DATA_DIR/etc/cloudera-scm-server:/etc/cloudera-scm-server \
    -v $DOCKER_CONTAINER_DATA_DIR/etc/cloudera-scm-agent:/etc/cloudera-scm-agent \
    -v $DOCKER_CONTAINER_DATA_DIR/var/lib/mysql:/var/lib/mysql \
    -v $INSTALLER_ROOT_CDH/parcel-repo:$CLOUDERA_ROOT/parcel-repo \
    -p 7180:7180 \
    -p 3306:3306 \
    $CDH_DOCKER_IMAGE

    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl stop cloudera-scm-agent cloudera-scm-server"
    
    init_assign_root_pwd $DOCKER_CONTAINER_NAME
    init_log_directories $DOCKER_CONTAINER_NAME
    update_privileges $DOCKER_CONTAINER_NAME
    
    print_title ""
    docker ps -a

    init_ntp_server $DOCKER_CONTAINER_NAME
    
    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl restart mariadb"
    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl enable mariadb"
    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl status mariadb"
    
    sleep 5

    docker exec $DOCKER_CONTAINER_NAME bash -c 'echo "drop database if exists scm; create database scm default charset utf8 collate utf8_general_ci;" | mysql -uroot -pDccs12345.'

    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl enable cloudera-scm-server"
    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl restart cloudera-scm-server"
    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl status cloudera-scm-server"

    # docker exec -i tipmanager bash -c "tailf /var/log/cloudera-scm-server/cloudera-scm-server.log"
    
    # 等待tipmanager初始化
    retVal=1
    while (($retVal!=0))
    do
        # curl http://127.0.0.1:7180
        docker exec -i $DOCKER_CONTAINER_NAME bash -c "curl http://127.0.0.1:7180"

        retVal=$?
        if [ $retVal == 0 ]; then
            break;
        fi
        
        sleep 10
    done
    echo "tipmanager is running..."
    
    init_scm_user
}

function init_disk_volumns {

    find $STORAGE_PREFIX -name docker |xargs rm -fr
    
    diskvol1=()
    diskvol2=()
    diskvol3=()

    for a in $(ls $STORAGE_PREFIX/ | sort -n); do 
        mod=`expr $a % 3`
        div=`expr $a / 3`
        
        TMP="$STORAGE_PREFIX/$a/docker"
        if [ $mod == '1' ]; then
            length=${#diskvol1[@]}

            diskvol1[$length]=$TMP
        elif [ $mod == '2' ]; then
            length=${#diskvol2[@]}

            diskvol2[$length]=$TMP
        else
            length=${#diskvol3[@]}

            diskvol3[$length]=$TMP
        fi
        
        mkdir -p $TMP
    done

    echo ${diskvol1[*]}
    echo ${diskvol2[*]}
    echo ${diskvol3[*]}

    print_title "init tipdiskvol1"
    vols=""
    index=1
    for var in ${diskvol1[@]};
    do
        vols=$vols" -v $var:$STORAGE_PREFIX/$index"
        index=`expr $index + 1`
    done
    echo "vols: "$vols
    docker run -itd --restart=always --name tipdiskvol1 $vols $OS_DOCKER_IMAGE

    print_title "init tipdiskvol2"
    vols=""
    index=1
    for var in ${diskvol2[@]};
    do
        vols=$vols" -v $var:$STORAGE_PREFIX/$index"
        index=`expr $index + 1`
    done
    echo "vols: "$vols
    docker run -itd --restart=always --name tipdiskvol2 $vols $OS_DOCKER_IMAGE

    print_title "init tipdiskvol2"
    vols=""
    index=1
    for var in ${diskvol3[@]};
    do
        vols=$vols" -v $var:$STORAGE_PREFIX/$index"
        index=`expr $index + 1`
    done
    echo "vols: "$vols
    docker run -itd --restart=always --name tipdiskvol3 $vols $OS_DOCKER_IMAGE
    
    print_title "containers list"
    docker ps -a
}

function init_master_node {

    print_title "init_master_node"
    
    DOCKER_CONTAINER_NAME=tipmaster
    DOCKER_CONTAINER_DATA_DIR=$DOCKER_CONTAINER_DATA_ROOT/$DOCKER_CONTAINER_NAME
    
    rm -fr $DOCKER_CONTAINER_DATA_DIR/*
    
    # docker run -itd --network=$NETWORK_SURFIX --name=$DOCKER_CONTAINER_NAME --hostname=$DOCKER_CONTAINER_NAME.$NETWORK_SURFIX --privileged=true \
    # -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /media/CentOS:/media/CentOS:ro \
    # -v $DOCKER_CONTAINER_DATA_DIR/var/log:/var/log \
    # -v $DOCKER_CONTAINER_DATA_DIR/data/dfs:/data/dfs \
    # -v $DOCKER_CONTAINER_DATA_DIR/var/lib/hadoop-hdfs:/var/lib/hadoop-hdfs \
    # -v $DOCKER_CONTAINER_DATA_DIR$CLOUDERA_ROOT:$CLOUDERA_ROOT \
    # $CDH_DOCKER_IMAGE
    
    docker run -itd --network=$NETWORK_SURFIX --name=$DOCKER_CONTAINER_NAME --hostname=$DOCKER_CONTAINER_NAME.$NETWORK_SURFIX --privileged=true \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /media/CentOS:/media/CentOS:ro \
    -v $DOCKER_CONTAINER_DATA_DIR/data/dfs:/data/dfs \
    -v $DOCKER_CONTAINER_DATA_DIR/var/lib/hadoop-hdfs:/var/lib/hadoop-hdfs \
    -p 8020:8020 -p 50070:50070 -p 50090:50090 -p 10002:10002 -p 60010:60010 \
    -p 25020:25020 -p 25010:25010 -p 19888:19888 -p 8088:8088 \
    $CDH_DOCKER_IMAGE
    
    docker ps -a
    
    init_assign_root_pwd $DOCKER_CONTAINER_NAME
    init_log_directories $DOCKER_CONTAINER_NAME
    update_privileges $DOCKER_CONTAINER_NAME

    #docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl enable cloudera-scm-agent;systemctl restart cloudera-scm-agent;systemctl status cloudera-scm-agent"
    
    init_ntp_client $DOCKER_CONTAINER_NAME
}

function init_slave_node {

    msg="init_slave_node "$1
    print_title "$msg"
    
    DOCKER_CONTAINER_NAME=$1
    DOCKER_CONTAINER_DATAVOL_NAME=$2
    DOCKER_CONTAINER_DATA_DIR=$DOCKER_CONTAINER_DATA_ROOT/$DOCKER_CONTAINER_NAME
    
    # rm -fr $DOCKER_CONTAINER_DATA_DIR/*
    
    docker run -itd --network=$NETWORK_SURFIX --name=$DOCKER_CONTAINER_NAME --hostname=$DOCKER_CONTAINER_NAME.$NETWORK_SURFIX --privileged=true \
    --volumes-from $DOCKER_CONTAINER_DATAVOL_NAME \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /media/CentOS:/media/CentOS:ro \
    -v $DOCKER_CONTAINER_DATA_DIR/var/lib/zookeeper:/var/lib/zookeeper \
    $CDH_DOCKER_IMAGE
    
    docker ps -a
    
    init_assign_root_pwd $DOCKER_CONTAINER_NAME
    init_log_directories $DOCKER_CONTAINER_NAME
    update_privileges $DOCKER_CONTAINER_NAME

    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p $TIP_ROOT"
    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p /data/flume"
    
    docker cp $INSTALLER_ROOT/tip/flume-ng.tar.gz $DOCKER_CONTAINER_NAME:$TIP_ROOT
    docker exec $DOCKER_CONTAINER_NAME bash -c "cd $TIP_ROOT; tar -xf flume-ng.tar.gz"
    
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R zookeeper\:zookeeper /var/lib/zookeeper"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R impala\:impala /data/flume"
    docker exec $DOCKER_CONTAINER_NAME bash -c "chown -R impala\:impala /var/log/flume-ng"
    
    init_ntp_client $DOCKER_CONTAINER_NAME
}

function init_worker_node {

    print_title "init_worker_node"
    
    DOCKER_CONTAINER_NAME=tipworker
    DOCKER_CONTAINER_DATA_DIR=$DOCKER_CONTAINER_DATA_ROOT/$DOCKER_CONTAINER_NAME
    
    docker run -itd --network=$NETWORK_SURFIX --name=$DOCKER_CONTAINER_NAME --hostname=$DOCKER_CONTAINER_NAME.$NETWORK_SURFIX --privileged=true \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v /media/CentOS:/media/CentOS:ro \
    -p 2181:2181 -p 21000:21000 -p 21050:21050 -p 25000:25000 -p 8888:8888 -p 11000:11000 -p 11443:11443 \
    -p 60000:60000 -p 60020:60020 -p 60030:60030 -p 18080:18080 -p 18081:18081 -p 18088:18088 \
    -p 38118:38118 -p 39000:39000 -p 22345:22345 -p 58080:58080 \
    -p 80:80 -p 443:443 -p 7777:7777 -p 222:22 \
    $CDH_DOCKER_IMAGE
    
    docker ps -a
    
    init_assign_root_pwd $DOCKER_CONTAINER_NAME
    init_log_directories $DOCKER_CONTAINER_NAME
    update_privileges $DOCKER_CONTAINER_NAME

    docker exec $DOCKER_CONTAINER_NAME bash -c "mkdir -p $TIP_ROOT"

    for file in $INSTALLER_ROOT/tip/*;
    do
        echo "cp $file to $DOCKER_CONTAINER_NAME"
        docker cp $file $DOCKER_CONTAINER_NAME:$TIP_ROOT/
    done

    docker exec $DOCKER_CONTAINER_NAME bash -c "cp -a $TIP_ROOT/tip /etc/init.d/tip"
    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl disable cloudera-scm-agent cloudera-scm-server flume-ng-agent hadoop-hdfs-datanode hadoop-hdfs-namenode hadoop-hdfs-nfs3 hadoop-hdfs-secondarynamenode hadoop-httpfs hadoop-mapreduce-historyserver hadoop-yarn-nodemanager hadoop-yarn-proxyserver hadoop-yarn-resourcemanager hbase-master hbase-regionserver hbase-rest hbase-solr-indexer hbase-thrift hive-metastore hive-server2 hue impala-catalog impala-server impala-state-store oozie solr-server spark-history-server spark-master spark-worker sqoop2-server zookeeper-server"
    docker exec $DOCKER_CONTAINER_NAME bash -c "/sbin/chkconfig tip on"
    
    # 更新nginx配置，启动nginx
    # rm -fr $DOCKER_CONTAINER_DATA_DIR/etc/nginx/conf.d/*
    # cp -a $INSTALLER_ROOT_DOCKER/nginx/* $DOCKER_CONTAINER_DATA_DIR/etc/nginx/
    
    docker exec $DOCKER_CONTAINER_NAME bash -c "rm -fr /etc/nginx/conf.d/*"
    
    pushd $INSTALLER_ROOT_DOCKER
        tar -czf nginx.tar.gz nginx
        docker cp $INSTALLER_ROOT_DOCKER/nginx.tar.gz $DOCKER_CONTAINER_NAME:/etc/
        docker exec $DOCKER_CONTAINER_NAME bash -c "cd /etc; tar -xf nginx.tar.gz; rm -f nginx.tar.gz"
        rm -f nginx.tar.gz
    popd
    
    docker exec $DOCKER_CONTAINER_NAME bash -c "systemctl enable nginx;systemctl restart nginx;systemctl status nginx"
    docker exec $DOCKER_CONTAINER_NAME bash -c "netstat -anop |grep nginx"
    
    init_ntp_client $DOCKER_CONTAINER_NAME
}

function init_nodes {

    print_title "init_nodes"
    
    # 创建TIP程序数据卷
    #docker run -itd --restart=always --name $TIP_ROOT_VOL_NAME --hostname $TIP_ROOT_VOL_NAME -v $TIP_ROOT:$TIP_ROOT $CDH_DOCKER_IMAGE /bin/bash
    
    # 创建数据卷容器
    init_disk_volumns

    # 创建masternode
    init_master_node

    # 创建slavenodes
    init_slave_node tipslave1 tipdiskvol1
    init_slave_node tipslave2 tipdiskvol2
    init_slave_node tipslave3 tipdiskvol3

    # 创建tipworker
    init_worker_node
    
    docker ps -a
    docker network inspect tip-bridge-network
}

function init_starter {

    print_title "init_starter"

    cp $INSTALLER_ROOT_DOCKER/tip.sh $TIP_ROOT/
    chmod 755 $TIP_ROOT/tip.sh
    
    cp $INSTALLER_ROOT_DOCKER/tip.service /usr/lib/systemd/system/
    systemctl daemon-reload
    systemctl enable tip
    systemctl status tip

    chmod +x /etc/rc.d/rc.local
    #cat /etc/rc.d/rc.local
    
    retVal=`crontab -l |grep tip.sh |wc -l`
    if [ $retVal == 0 ]; then
        echo "*/1 * * * * /bin/sh /opt/dccs/tip/tip.sh" >> /var/spool/cron/root
    fi
    
    print_title "crontab list"
    crontab -l
}

function set_cm_host_uuid {
    
    CONTAINER_NAME=$1
    UUID=$2
    
    msg="set_cm_host_uuid for "$CONTAINER_NAME", UUID: "$UUID
    print_title "$msg"
    
    # uuid 后面不能有换行符
    python -c "from __future__ import print_function;print('$2',end='')" > uuid
    
    docker exec $CONTAINER_NAME bash -c "sed -i 's/server_host=.*/server_host='tipmanager'/' /etc/cloudera-scm-agent/config.ini"
    
    docker cp uuid $CONTAINER_NAME:/var/lib/cloudera-scm-agent/uuid
    rm -f uuid
    
    docker exec $CONTAINER_NAME bash -c "cat /var/lib/cloudera-scm-agent/uuid"
    docker exec $CONTAINER_NAME bash -c "systemctl enable cloudera-scm-agent"
    docker exec $CONTAINER_NAME bash -c "systemctl restart cloudera-scm-agent"
}

function init_docker_cdh_cluster {

    print_title "init_docker_cdh_cluster"

    # 从cm配置导入预定义的配置
    CFG_FILE=tip_single_node_docker_cfg.json

    MEM=`free -b |awk -F ' ' 'NR==2{print $2}'`
    if [ $MEM -lt 34359738368 ]; then
        # 内存容量小于32G
        CFG_FILE=tip_single_node_docker_cfg_32g.json
    fi
    
    print_title "import cluster configuration $CFG_FILE"
    
    # admin:Dccs12345.
    curl --request PUT --header "authorization: Basic $CM_BASIC_AUTH_PWD" \
    --header "content-type: application/json" \
    --url http://127.0.0.1:7180/api/v14/cm/deployment \
    -d @$INSTALLER_ROOT_DOCKER/$CFG_FILE
    
    # cm agent uuid 从 tip_single_node_docker_cfg.json 中的 hostId 里面获取
    set_cm_host_uuid tipmanager 317f858e-05bc-4e20-b9c3-a8d67c17da03
    
    # 启动cm服务相关角色
    print_title "Start Cloudera Manager roles"
    python -c 'from cm_api.api_client import ApiResource; \
    ApiResource("127.0.0.1", version=14, username="'$CM_USER'", \
    password="'$CM_PASSWD'").get_cloudera_manager().get_service().restart().wait()'

    set_cm_host_uuid tipmaster fca37cfe-a613-42b9-8ba6-fa4da4a92f4f
    set_cm_host_uuid tipslave1 85d34e4b-a7ad-4d1e-b71e-d7bc4980e712
    set_cm_host_uuid tipslave2 0f418874-d221-4a0a-9eab-42002c341dae
    set_cm_host_uuid tipslave3 5e881dda-3536-46f1-a7a5-4b6411ce2e2b

    sleep 30
    
    # 分配Parcels
    print_title "distribute parcels"    
    python $INSTALLER_ROOT_DOCKER/distribute_parcels.py
}

function start_service {
    msg="start service: "$1
    print_title "$msg"
    
    python -c 'from cm_api.api_client import ApiResource; \
    ApiResource("127.0.0.1", version=14, username="'$CM_USER'", \
    password="'$CM_PASSWD'").get_cluster("TIP").get_service("'$1'").start().wait()'
}

function init_flume {

    print_title "init_flume"

    # 创建flume hdfs sink缓存目录(TIP)
    docker exec --user hdfs tipmaster bash -c "hadoop fs -mkdir -p /flume/tip"
    docker exec --user hdfs tipmaster bash -c "hadoop fs -chown -R impala:impala /flume"
    
    start_service "flume"
}

function start_cdh_cluster {
    print_title "start_cdh_cluster"
    
    # 执行 first run
    print_title "execute first run"
    python $INSTALLER_ROOT_DOCKER/first_run.py
    
    # 单独初始化flume
    init_flume
}

function init_tip_components {

    print_title "init_tip_components"
    
    # 初始化tip mysql 数据库
    print_title "init tip mysql db"
    docker cp $INSTALLER_ROOT_DOCKER/tip.sql tipmanager:/tmp/
    docker exec tipmanager bash -c "mysql -htipmanager -utip -ptip < /tmp/tip.sql"
    
    # 初始化tip hbase 表
    print_title "init tip hbase table"
    docker cp $INSTALLER_ROOT/tip/hbase-init.cmd tipslave1:/tmp/
    docker exec tipslave1 bash -c "hbase shell < /tmp/hbase-init.cmd"
    
    # 初始化tip flume
    print_title "init tip flume"
    docker exec --user hdfs tipslave1 bash -c "hadoop fs -mkdir -p /flume/tip"
    docker exec --user hdfs tipslave1 bash -c "hadoop fs -chown -R impala:impala /flume"
    
    # 初始化tip impala 表
    print_title "init tip impala table"
    docker cp $INSTALLER_ROOT/tip/libTipUDFS.1.0.1.so tipslave1:/tmp/
    docker exec --user hdfs tipslave1 bash -c "hadoop fs -mkdir -p /user/impala/tip/so"
    docker exec --user hdfs tipslave1 bash -c "hadoop fs -put /tmp/libTipUDFS.1.0.1.so /user/impala/tip/so/"
    docker exec --user hdfs tipslave1 bash -c "hadoop fs -chown -R impala:impala /user/impala"

    docker cp $INSTALLER_ROOT/tip/tip-impala.sql tipslave1:/tmp/
    docker exec tipslave1 bash -c "impala-shell -f /tmp/tip-impala.sql"
    docker exec tipslave1 bash -c "impala-shell -q 'invalidate metadata;'"
    
    docker cp $INSTALLER_ROOT/tip/tip-impala-cache.sql tipslave1:/tmp/
    docker exec tipslave1 bash -c "hive -f /tmp/tip-impala-cache.sql"
    docker exec tipslave1 bash -c "impala-shell -q 'invalidate metadata;show databases;show tables in tip;'"
    
    # 初始化tip服务
    
    print_title "init tip restful serive"
    docker exec tipworker bash -c "cd $TIP_ROOT; tar -xf RESTS.tar.gz; tar -xf  apache-tomcat-8.5.5.tar.gz"
    
    TIP_CONF_FILE=$INSTALLER_ROOT_DOCKER/config.properties
    
    echo "nesf.config.driverClassName=com.mysql.jdbc.Driver" > $TIP_CONF_FILE
    echo "nesf.config.url=jdbc:mysql://tipmanager:3306/tip" >> $TIP_CONF_FILE
    echo "nesf.config.username=tip" >> $TIP_CONF_FILE
    echo "nesf.config.password=tip" >> $TIP_CONF_FILE
    echo "com.dccs.tip.cm.ip=tipmanager" >> $TIP_CONF_FILE
    cat $TIP_CONF_FILE
    docker cp $TIP_CONF_FILE tipworker:$TIP_ROOT/
    
    print_title "init tip mgmt serive"
    TIP_CONF_FILE=$INSTALLER_ROOT_DOCKER/Server.properties
    echo "dccs.reset.config.db.driverClassName=com.mysql.jdbc.Driver" > $TIP_CONF_FILE
    echo "dccs.reset.config.db.url=jdbc:mysql://tipmanager:3306/tip" >> $TIP_CONF_FILE
    echo "dccs.reset.config.db.username=tip" >> $TIP_CONF_FILE
    echo "dccs.reset.config.db.password=tip" >> $TIP_CONF_FILE
    echo "com.dccs.tip.cm.ip=tipmanager" >> $TIP_CONF_FILE
    cat $TIP_CONF_FILE
    docker cp $TIP_CONF_FILE tipworker:$TIP_ROOT/RESTS/config/Server.properties
    
    docker exec tipworker bash -c "systemctl enable nginx tip;systemctl restart nginx tip;systemctl status nginx tip"
}

config_external_ip
cleanup_docker
init
init_docker
init_tip_network
init_tipmanager
init_nodes
init_docker_cdh_cluster
start_cdh_cluster
init_dog
init_tip_components
init_starter

echo ""
print_time
print_title "All done! "

temp=$1
read -p "Press enter to reboot..." temp
reboot

