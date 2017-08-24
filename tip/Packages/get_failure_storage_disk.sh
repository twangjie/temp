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

getFailureDisks
