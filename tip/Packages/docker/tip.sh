#!/bin/bash

if [ -n "$1" ]; then
    CMD=$1
else
    CMD=start
fi

function start_tip_containers {

    retVal=`docker ps -a -f name=tip |grep Exited |wc -l`

    if [ $retVal > 0 ]; then
        docker start tipdiskvol1 tipdiskvol2 tipdiskvol3 tipmanager tipmaster tipslave1 tipslave2 tipslave3 tipworker

        docker exec -i tipmanager bash -c "systemctl start cloudera-scm-agent"
        docker exec -i tipmanager bash -c "systemctl start cloudera-scm-server"
        docker exec -i tipmaster bash -c "systemctl start cloudera-scm-agent"
        docker exec -i tipslave1 bash -c "systemctl start cloudera-scm-agent"
        docker exec -i tipslave2 bash -c "systemctl start cloudera-scm-agent"
        docker exec -i tipslave3 bash -c "systemctl start cloudera-scm-agent"
    fi
}

function stop_tip_containers {
    #docker stop $(docker ps -q -f name=tip)
    docker stop tipworker tipmaster tipslave1 tipslave2 tipslave3 tipmanager
    docker stop tipdiskvol1 tipdiskvol2 tipdiskvol3
}

function restart_tip_containers {
    stop_tip_containers
    start_tip_containers
}

case $CMD in 
start)
    start_tip_containers
    ;;
    
stop)
    stop_tip_containers
    ;;

restart)
    restart_tip_containers
    ;;
*)
    echo "Usage: tip.sh start | stop | restart .Or use systemctl start | stop | restart  tip.service "
    ;;
esac
