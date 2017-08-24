-- MySQL Administrator dump 1.4
--
-- ------------------------------------------------------
-- Server version	5.5.44-MariaDB-log


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;


--
-- Create schema tip
--

CREATE DATABASE IF NOT EXISTS tip;
USE tip;

--
-- Definition of table `SCHEMA_VERSION`
--

DROP TABLE IF EXISTS `SCHEMA_VERSION`;
CREATE TABLE `SCHEMA_VERSION` (
  `VERSION` int(11) NOT NULL,
  `OLD_VERSION` int(11) NOT NULL,
  PRIMARY KEY (`VERSION`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `SCHEMA_VERSION`
--

/*!40000 ALTER TABLE `SCHEMA_VERSION` DISABLE KEYS */;
INSERT INTO `SCHEMA_VERSION` (`VERSION`,`OLD_VERSION`) VALUES 
 (1,1);
/*!40000 ALTER TABLE `SCHEMA_VERSION` ENABLE KEYS */;


--
-- Definition of table `config`
--

DROP TABLE IF EXISTS `config`;
CREATE TABLE `config` (
  `key` varchar(255) CHARACTER SET latin1 NOT NULL,
  `val` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  `comment` varchar(255) CHARACTER SET latin1 DEFAULT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `config`
--

/*!40000 ALTER TABLE `config` DISABLE KEYS */;
INSERT INTO `config` (`key`,`val`,`comment`) VALUES 
 ('dccs.reset.config.hbase.zookeeper.property.clientport','2181','hbase service port'),
 ('dccs.reset.config.hbase.zookeeper.quorum','tipslave1,tipslave2,tipslave3','hbase service ip address'),
 ('dccs.reset.config.impala.jdbc.cachetable.expire','600','Query cache expire time'),
 ('dccs.reset.config.impala.jdbc.cachetable.limit','2000000','Query cache limit'),
 ('dccs.reset.config.impala.jdbc.dbname','tip','impala vehicle pass db name'),
 ('dccs.reset.config.impala.jdbc.host','tipslave1','Impala host'),
 ('dccs.reset.config.impala.jdbc.port','21050','Impala port'),
 ('dccs.reset.config.impala.jdbc.tablename','vehicleinfo','impala vehicle pass table name'),
 ('dccs.reset.config.server.port','22345','REST Service Port'),
 ('dccs.reset.config.server.version','RESTServer 1.0',NULL),
  ('dccs.reset.config.monitor.hdfs.capacity.clear.threshold','85',NULL),
  ('dccs.reset.config.monitor.hdfs.capacity.clear.strategy','1',NULL),
 ('debug','false','DEBUG'),
 ('nesf.datasource.impala.dialect','IMPALA',NULL),
 ('nesf.datasource.impala.driverClassName','com.cloudera.impala.jdbc41.Driver',NULL),
 ('nesf.datasource.impala.testOnBorrow','true',NULL),
 ('nesf.datasource.impala.url','jdbc:impala://tipslave1:21050/tip;UseNativeQuery=1;PreparedMetaLimitZero=0',NULL),
 ('nesf.datasource.impala.validationQuery','SELECT 1',NULL),
 ('nesf.datasource.task.dialect','MYSQL',NULL),
 ('nesf.datasource.task.driverClassName','com.mysql.jdbc.Driver',NULL),
 ('nesf.datasource.task.password','tip',NULL),
 ('nesf.datasource.task.testOnBorrow','true',NULL),
 ('nesf.datasource.task.url','jdbc:mysql://tipmanager:3306/tip',NULL),
 ('nesf.datasource.task.username','tip',NULL),
 ('nesf.datasource.task.validationQuery','SELECT 1',NULL),
  ('nesf.service.cacheExpire','600',NULL),
  ('nesf.service.dataLimit','2000000',NULL),
  ('nesf.service.hbaseZkQuorum','tipslave1,tipslave2,tipslave3',NULL),
  ('nesf.service.hbaseZkClientPort','2181',NULL);
/*!40000 ALTER TABLE `config` ENABLE KEYS */;


--
-- Definition of table `lock`
--

DROP TABLE IF EXISTS `lock`;
CREATE TABLE `lock` (
  `version` bigint(100) NOT NULL,
  `updated_time` datetime DEFAULT NULL,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `lock`
--

/*!40000 ALTER TABLE `lock` DISABLE KEYS */;
INSERT INTO `lock` (`version`,`updated_time`) VALUES 
 (14511,'2017-01-20 10:00:00');
/*!40000 ALTER TABLE `lock` ENABLE KEYS */;


--
-- Definition of table `task`
--

DROP TABLE IF EXISTS `task`;
CREATE TABLE `task` (
  `id` varchar(100) NOT NULL,
  `params` longtext,
  `status` varchar(50) DEFAULT NULL,
  `created_time` datetime NOT NULL,
  `update_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `task`
--


--
-- Definition of table `task_history`
--

DROP TABLE IF EXISTS `task_history`;
CREATE TABLE `task_history` (
  `id` varchar(100) NOT NULL,
  `params` longtext,
  `status` varchar(50) DEFAULT NULL,
  `created_time` datetime NOT NULL,
  `update_time` datetime DEFAULT NULL,
  `history_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `task_history`
--

--
-- Definition of procedure `sp_move_task_2_history`
--

DROP PROCEDURE IF EXISTS `sp_move_task_2_history`;

DELIMITER $$

/*!50003 SET @TEMP_SQL_MODE=@@SQL_MODE, SQL_MODE='' */ $$
CREATE PROCEDURE `sp_move_task_2_history`(IN taskid varchar(255))
BEGIN

    IF EXISTS (SELECT `id` FROM `task` WHERE `id` = taskid) THEN
        INSERT INTO task_history(id,params,`status`,created_time,update_time) select id,params,`status`,created_time,update_time from task where `id`=taskid ;
        DELETE FROM task WHERE `id`=taskid ;
    END IF;

END $$
/*!50003 SET SESSION SQL_MODE=@TEMP_SQL_MODE */  $$

DELIMITER ;



/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
