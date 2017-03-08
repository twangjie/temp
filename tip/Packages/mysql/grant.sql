drop database IF EXISTS `amon`;
create database amon DEFAULT CHARACTER SET utf8;
grant all on amon.* TO 'amon'@'192.168.%.%' IDENTIFIED BY 'amon';

drop database IF EXISTS `rman`;
create database rman DEFAULT CHARACTER SET utf8;
grant all on rman.* TO 'rman'@'192.168.%.%' IDENTIFIED BY 'rman';

drop database IF EXISTS `sentry`;
create database sentry DEFAULT CHARACTER SET utf8;
grant all on sentry.* TO 'sentry'@'192.168.%.%' IDENTIFIED BY 'sentry';

drop database IF EXISTS `nav`;
create database nav DEFAULT CHARACTER SET utf8;
grant all on nav.* TO 'nav'@'192.168.%.%' IDENTIFIED BY 'nav';

drop database IF EXISTS `navms`;
create database navms DEFAULT CHARACTER SET utf8;
grant all on navms.* TO 'navms'@'192.168.%.%' IDENTIFIED BY 'navms';

drop database IF EXISTS `metastore`;
create database metastore DEFAULT CHARACTER SET utf8;
grant all on metastore.* TO 'hive'@'192.168.%.%' IDENTIFIED BY 'hive';

drop database IF EXISTS `oozie_server`;
create database oozie_server DEFAULT CHARACTER SET utf8;
grant all on oozie_server.* TO 'oozie_server'@'192.168.%.%' IDENTIFIED BY 'oozie_server';

drop database IF EXISTS `hue`;
create database hue DEFAULT CHARACTER SET utf8;
grant all on hue.* TO 'hue'@'192.168.%.%' IDENTIFIED BY 'hue';

flush privileges;
