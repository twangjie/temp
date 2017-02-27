#!/bin/bash  
#
# rpm -qa |sort -k1 -n > packages.list
#
#

currentTime=`date "+%Y%m%d%H%M%S"`

LANG="en_US.UTF-8"
LANGUAGE="en_US:en"

alias cp='cp'

DEBUG=1
BUILDER_DIR=/opt/dccs/installer/builder
CentOS_DVD=/opt/dccs/installer/CentOS7
MyOS_DIR=$BUILDER_DIR/CentOS7-TIP
ALL_RPMS_DIR=$CentOS_DVD/Packages #源光盘RPM包存放的目录  
MyOS_RPMS_DIR=$MyOS_DIR/Packages    #精简后RPM包存放的目录  
packages_list=packages.list  #精简后的RPM包列表  

rm -fr $MyOS_DIR/repodata
mkdir -p $MyOS_RPMS_DIR $MyOS_DIR/repodata

#umount -l $CentOS_DVD
#mount /dev/cdrom $CentOS_DVD

echo "Packages" > exclude.list
echo "repodata" >> exclude.list

rsync -a --progress --exclude-from=exclude.list $CentOS_DVD/* $MyOS_DIR
rsync -a --progress $CentOS_DVD/repodata/*-comps.xml $MyOS_DIR/repodata/comps.xml
cp -a $CentOS_DVD/.discinfo $MyOS_DIR/
cp -a $CentOS_DVD/.treeinfo $MyOS_DIR/

number_of_packages=`cat $packages_list | wc -l`  
i=1

while read name; do

    if [ $DEBUG -eq "1" ] ; then  
        ls $ALL_RPMS_DIR/$name.*
        if [ $? -ne 0 ] ; then  
            echo "cp $ALL_RPMS_DIR/$name.* "  
        fi
    fi
    
    echo "cp $ALL_RPMS_DIR/$name.* $MyOS_RPMS_DIR/"  
    cp $ALL_RPMS_DIR/$name.* $MyOS_RPMS_DIR/  
    # in case the copy failed  
    if [ $? -ne 0 ] ; then
        echo "cp $ALL_RPMS_DIR/$name.* $MyOS_RPMS_DIR/"  
        cp $ALL_RPMS_DIR/$name.* $MyOS_RPMS_DIR/  
    fi
        
i=`expr $i + 1`  
done < $packages_list

echo
echo $i "Packages copy finished..."

# cp other packages to $MyOS_RPMS_DIR

cd $MyOS_DIR
createrepo -g repodata/comps.xml .

cd $BUILDER_DIR

mkisofs -r -R -J -T -v -no-emul-boot -boot-load-size 4 -boot-info-table -V "TIP" -p "Wang Jie" -A "CentOS7-TIP" -b isolinux/isolinux.bin -c isolinux/boot.cat -x "lost+found" -o CentOS7-TIP.iso CentOS7-TIP

