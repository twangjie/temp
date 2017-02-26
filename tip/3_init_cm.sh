#!/bin/bash

# 安装jdk
rpm -ivh jdk-8u60-linux-x64.rpm

#复制mysql jdbc驱动
mkdir /usr/share/java
cp mysql-connector-java-5.1.34-bin.jar /usr/share/java/mysql-connector-java.jar

# 初始化tip.repo仓库（CentOS7.2 nginx cm5)

# 安装nginx

# 安装Cloudera Manager 5 RPMS
