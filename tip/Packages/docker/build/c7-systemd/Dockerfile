# https://hub.docker.com/_/centos/
#
# docker build -t c7-systemd:7.2.1511 --no-cache --force-rm .
# docker run -ti --privileged=true -v /sys/fs/cgroup:/sys/fs/cgroup:ro centos-systemd:7.2.1511
#

FROM centos:7.2.1511

ENV container docker
ENV TZ=Asia/Shanghai

COPY docker_files/*.rpm /root/

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo $TZ > /etc/timezone; \
    rpm -Uvh /root/*.rpm; \
    rm -f /root/*.rpm

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;
VOLUME [ "/sys/fs/cgroup" ]

#RUN yum -y install httpd; yum clean all; systemctl enable httpd.service
#RUN yum clean all
#EXPOSE 80

CMD ["/usr/sbin/init"]

