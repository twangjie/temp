drop database if exists scm;
grant all on scm.* to 'scm'@'127.0.0.1' identified by 'scm' with grant option;
grant all on scm.* to 'scm'@'localhost' identified by 'scm' with grant option;
grant all on scm.* to 'scm'@'192.168.%.%' identified by 'scm' with grant option;
grant all on tip.* to 'tip'@'127.0.0.1' identified by 'tip' with grant option;
grant all on tip.* to 'tip'@'localhost' identified by 'tip' with grant option;
grant all on tip.* to 'tip'@'192.168.%.%' identified by 'tip' with grant option;
grant all on *.* to 'root'@'192.168.%.%' identified by 'Dccs12345.' with grant option;
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'replication'@'%' IDENTIFIED BY 'replication';

