
--
-- Current Database: `prequeue`
--
CREATE DATABASE `prequeue` DEFAULT CHARACTER SET latin1 DEFAULT COLLATE latin1_general_ci;

USE `prequeue`;

--
-- Table structure for table `commands`
--
CREATE TABLE `commands` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `preCommands` text,
  `commands` text,
  `postCommands` text,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `contextConfs`
--
CREATE TABLE `contextConfs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `context` text NOT NULL,
  PRIMARY KEY (`id`),
  FULLTEXT KEY `context` (`context`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `inputConfs`
--
CREATE TABLE `inputConfs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `input` mediumtext NOT NULL,
  PRIMARY KEY (`id`),
  FULLTEXT KEY `input` (`input`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `job2config`
--
CREATE TABLE `job2config` (
  `job_id` int(10) unsigned NOT NULL,
  `inputConf_id` int(10) unsigned DEFAULT NULL,
  `outputConf_id` int(10) unsigned DEFAULT NULL,
  `contextConf_id` int(10) unsigned DEFAULT NULL,
  `settingsConf_id` int(10) unsigned DEFAULT NULL,
  `command_id` int(10) unsigned DEFAULT NULL,
  `systemInfo_id` int(10) unsigned NOT NULL,
  `precondition_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`job_id`),
  KEY `systemInfo_id` (`systemInfo_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `jobs`
--
CREATE TABLE `jobs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `user` varchar(255) NOT NULL,
  `toolId` varchar(255) NOT NULL,
  `type` enum('gbToolJob','pipelineJob','utilityJob','gbLocalTaskWrapperJob') NOT NULL,
  `status` enum('entered','submitted','running','completed','failed','wait4deps','partialSuccess','cancelRequested','canceled','killed', 'depsExpired', 'depsFailed') NOT NULL,
  `entryDate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `submitDate` timestamp NOT NULL DEFAULT '1970-01-01 05:00:00',
  `execStartDate` timestamp NOT NULL DEFAULT '1970-01-01 05:00:00',
  `execEndDate` timestamp NOT NULL DEFAULT '1970-01-01 05:00:00',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `user` (`user`),
  KEY `entryDate` (`entryDate`,`status`),
  KEY `execStartDate` (`execStartDate`,`execEndDate`,`status`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `outputConfs`
--
CREATE TABLE `outputConfs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `output` text NOT NULL,
  PRIMARY KEY (`id`),
  FULLTEXT KEY `output` (`output`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `preconditions`
--
CREATE TABLE `preconditions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `count` int(10) unsigned NOT NULL DEFAULT '0',
  `numMet` int(10) unsigned NOT NULL DEFAULT '0',
  `willNeverMatch` tinyint(1) NOT NULL DEFAULT '0',
  `someExpired` tinyint(1) NOT NULL DEFAULT '0',
  `preconditions` mediumtext NOT NULL,
  PRIMARY KEY (`id`),
  FULLTEXT KEY `precondition` (`preconditions`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `settingsConfs`
--
CREATE TABLE `settingsConfs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `settings` text NOT NULL,
  PRIMARY KEY (`id`),
  FULLTEXT KEY `settings` (`settings`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `systemInfos`
--
CREATE TABLE `systemInfos` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `queue` varchar(255) NOT NULL,
  `systemJobId` varchar(255) DEFAULT NULL,
  `directives` text,
  `system_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `queue` (`queue`),
  KEY `systemJobId` (`systemJobId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `systems`
--
CREATE TABLE `systems` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(255) NOT NULL,
  `host` varchar(255) NOT NULL,
  `adminEmails` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `type` (`type`,`host`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;
