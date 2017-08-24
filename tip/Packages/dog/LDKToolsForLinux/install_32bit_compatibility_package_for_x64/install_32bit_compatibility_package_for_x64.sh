#!/bin/bash
# Script: install_32bit_compatibility_package.sh
# 
# This script installs the 32-bit compatibility packages on the 64-bit Linux which
# are required for running Sentinel LDK Runtime Environment on a 64-bit Linux OS.
#
# return codes:
#   0 - Success
#   1 - Missing permissions (must be run as root)
#   2 - Unknown system

echo ""
echo " Script for installing 32-bit compatibility packages for 64-bit Linux."
echo " Copyright (C) 2016, SafeNet, Inc. All rights reserved."
echo ""

SELF=`basename $0`

# Routine for root check
check_root()
{
if [ `id -u` -ne 0 ]; then
    echo "This script must run as root."
    echo "Aborting installation..."
    exit 1
fi
}

# Routine to check Linux OS
check_linux()
{
if [ `uname -s` != "Linux" ]; then
    echo "Not running on Linux."
    echo "Aborting installation..."
    exit 2
fi
}

# Routine to detect hardware platform for x86_64
check_hardware_platform()
{
ARCH=`uname -m`
if [ $ARCH != "x86_64" ]; then
    echo "Not a 64-bit OS."
    echo "Aborting installation..."
    exit 2
fi
}

# Routine to identify Linux Flavor 
identify_linux_flavor()
{
if [ -e /etc/centos-release ] ; then
    FLAVOR="CentOS"
elif [ -e /etc/redhat-release ] ; then
    FLAVOR="Redhat"
elif [ -e /etc/SuSE-release ] ; then
    FLAVOR="SuSe"
elif [ -e /etc/lsb-release ] ; then
    FLAVOR="Ubuntu"
elif [ -e /etc/debian_version ] ; then
    FLAVOR="Debian"
else
    FLAVOR="Unknown"
fi
echo -n "Linux OS Flavor - $FLAVOR!"
echo ""
}

# Routine to execute flavor specific online update command
run_update_command()
{
case $FLAVOR in
Redhat|CentOS)
    echo "Installing 32-bit libraries..."
    echo "Executing command : yum install glibc.i686"
    echo ""        
    yum install glibc.i686
    ;;
Ubuntu|Debian)
    echo "Installing 32-bit libraries..."
    # Adds a new foreign architecture, removing the need to use the --force option
    # when installing the i386 packages in a x86_64 platform
    # In old Ubuntu, like 12.04, this is going to fail, as multiple architectures were not supported.
    # See: https://wiki.debian.org/Multiarch/Implementation
    echo "Executing command : dpkg --add-architecture i386"
    echo ""
    dpkg --add-architecture i386
    if [ $? -eq 0 ] ; then
        # Install the required libc. The RTE doesn't need anything more to run.
        echo "Executing command : apt-get update / apt-get install libc6-i386"
        echo ""
        apt-get update
        apt-get install libc6-i386
    else
        # Use the old way to install 32 bits libraries in old not multiarch distributions
        echo "Executing command : apt-get install ia32-libs"
        echo ""
        apt-get install ia32-libs
    fi
    ;;
SuSe)
    echo "Installing 32-bit libraries..."
    echo "Executing command : zypper install glibc-32bit .."        
    echo ""        
    zypper install glibc-32bit
    ;;
Unknown)
    echo "Unknown flavor of Linux OS identified."
    echo "Aborting installation..."
    exit 2
    ;;
esac
}

# Script execution starting point !

# Check for Linux
check_linux

# Detect hardware platform for x86_64
check_hardware_platform

# Check for root user
check_root

# Identifying Linux OS Flavor
identify_linux_flavor

# Run update command based on the Linux flavor
run_update_command

echo ""
echo "Completed ...!"
echo ""
# End
