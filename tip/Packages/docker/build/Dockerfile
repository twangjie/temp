# https://hub.docker.com/_/centos/
#
# docker build -t c7-cm --rm .
# docker build -t c7-cm --rm --build-arg HTTP_PROXY="http://192.168.1.3:8118/" .
#
# docker run -itd --name cm --hostname=cm --privileged=true -v /sys/fs/cgroup:/sys/fs/cgroup:ro -p 7180:7180 c7-cm
# docker exec -it cm bash -c "systemctl status cloudera-scm-server cloudera-scm-agent"
#

FROM c7-systemd:7.2.1511

ENV INST_DIR=/opt/install

RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    echo "Asia/Shanghai" > /etc/timezone; \
    mkdir -p /opt/install /usr/share/java

COPY docker_files/* $INST_DIR/

RUN rm -f /etc/yum.repos.d/*; \
    cp $INST_DIR/cloudera-cdh5.repo /etc/yum.repos.d/cloudera-cdh5.repo; \
    cp $INST_DIR/mysql-connector-java-5.1.34-bin.jar /usr/share/java/mysql-connector-java.jar;

RUN yum --enablerepo=* clean all; \
    yum --enablerepo=* -y install \
    mariadb-server mariadb net-tools zip unzip lrzsz sudo openssh-clients openssh-server \
    telnet wget parted smartmontools bind-utils ntp ntpdate nginx \
    cloudera-manager-server cloudera-manager-agent jdk1.8.0_60.x86_64; \
    yum --enablerepo=* clean all; \
    systemctl enable sshd ntpd; \
    systemctl disable mariadb cloudera-scm-agent nginx postfix cloudera-scm-server

RUN rm -fr $INST_DIR

CMD ["/usr/sbin/init"]
