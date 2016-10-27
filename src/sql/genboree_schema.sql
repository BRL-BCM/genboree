
--
-- Current Database: `genboree`
--
CREATE DATABASE `genboree` DEFAULT CHARACTER SET latin1 DEFAULT COLLATE latin1_general_cs;

USE `genboree`;

--
-- Table structure for table `accountAttributes`
--
CREATE TABLE `accountAttributes` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `accountValues`
--
CREATE TABLE `accountValues` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `value` mediumtext NOT NULL,
  `sha1` char(40) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `sha1` (`sha1`),
  KEY `value` (`value`(255))
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `accounts`
--
CREATE TABLE `accounts` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `code` varchar(255) NOT NULL,
  `primaryContactName` varchar(255) NOT NULL,
  `primaryContactEmail` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `code` (`code`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `accounts2attributeValues`
--
CREATE TABLE `accounts2attributeValues` (
  `account_id` int(10) unsigned NOT NULL,
  `accountAttribute_id` int(10) unsigned NOT NULL,
  `accountValue_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`account_id`,`accountAttribute_id`),
  KEY `accountAttribute_id` (`accountAttribute_id`,`accountValue_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `chromosomeTemplate`
--
CREATE TABLE `chromosomeTemplate` (
  `chromosomeTemplate_id` int(11) NOT NULL AUTO_INCREMENT,
  `chromosomeTemplate_data` text,
  `chromosomeTemplate_length` int(11) DEFAULT NULL,
  `chromosomeTemplate_box_size` int(11) DEFAULT NULL,
  `chromosomeTemplate_symbol_id` varchar(55) DEFAULT NULL,
  `chromosomeTemplate_chrom_name` varchar(55) DEFAULT NULL,
  `chromosomeTemplate_standard_name` varchar(255) DEFAULT NULL,
  `FK_genomeTemplate_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`chromosomeTemplate_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `color`
--
CREATE TABLE `color` (
  `colorId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `value` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`colorId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `database2attributes`
--
CREATE TABLE `database2attributes` (
  `database_id` int(10) unsigned NOT NULL,
  `databaseAttrName_id` int(10) unsigned NOT NULL,
  `databaseAttrValue_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`database_id`,`databaseAttrName_id`),
  KEY `databaseAttrName_id` (`databaseAttrName_id`,`databaseAttrValue_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `database2host`
--
CREATE TABLE `database2host` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `databaseName` varchar(255) NOT NULL,
  `databaseHost` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `dbName` (`databaseName`),
  KEY `dbHost` (`databaseHost`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `databaseAttrNames`
--
CREATE TABLE `databaseAttrNames` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `state` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `databaseAttrValues`
--
CREATE TABLE `databaseAttrValues` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `value` text NOT NULL,
  `sha1` char(40) NOT NULL,
  `state` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `sha1` (`sha1`,`state`),
  KEY `value` (`value`(255),`state`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `databaseResourceList`
--
CREATE TABLE `databaseResourceList` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `url` varchar(32768) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`,`url`(512)),
  KEY `url` (`url`(512))
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `entryPointTemplate`
--
CREATE TABLE `entryPointTemplate` (
  `entryPointTemplateId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `refseqTemplateId` int(10) unsigned NOT NULL DEFAULT '0',
  `fref` varchar(100) DEFAULT NULL,
  `gclass` varchar(100) DEFAULT NULL,
  `length` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`entryPointTemplateId`),
  UNIQUE KEY `refseqTemplateId` (`refseqTemplateId`,`fref`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `externalHostAccess`
--
CREATE TABLE `externalHostAccess` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `userId` int(10) unsigned NOT NULL,
  `host` varchar(255) NOT NULL,
  `canonicalAddress` varchar(255) NOT NULL,
  `login` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `userId` (`userId`,`canonicalAddress`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `ftypeAccess`
--
CREATE TABLE `ftypeAccess` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `userId` int(10) unsigned NOT NULL DEFAULT '1',
  `ftypeid` int(10) unsigned NOT NULL,
  `permissionBits` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `userIdFtypeid` (`ftypeid`,`userId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `genboreegroup`
--
CREATE TABLE `genboreegroup` (
  `groupId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `groupName` varchar(255) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `student` int(1) DEFAULT '0',
  PRIMARY KEY (`groupId`),
  UNIQUE KEY `groupName` (`groupName`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `genboreeuser`
--
CREATE TABLE `genboreeuser` (
  `userId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `firstName` varchar(255) DEFAULT NULL,
  `lastName` varchar(255) DEFAULT NULL,
  `institution` varchar(255) DEFAULT NULL,
  `email` varchar(255) CHARACTER SET latin1 COLLATE latin1_general_ci,
  `phone` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`userId`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `genomeTemplate`
--
CREATE TABLE `genomeTemplate` (
  `genomeTemplate_id` int(11) NOT NULL AUTO_INCREMENT,
  `genomeTemplate_name` varchar(255) DEFAULT NULL,
  `genomeTemplate_species` varchar(255) DEFAULT NULL,
  `genomeTemplate_version` varchar(255) DEFAULT NULL,
  `genomeTemplate_source` varchar(255) DEFAULT NULL,
  `genomeTemplate_release_date` date DEFAULT NULL,
  `genomeTemplate_type` enum('SVG','PNG') NOT NULL DEFAULT 'SVG',
  `genomeTemplate_scale` int(11) DEFAULT NULL,
  `genomeTemplate_description` varchar(255) DEFAULT NULL,
  `genomeTemplate_vgp` enum('Y','N') NOT NULL DEFAULT 'N',
  `genomeTemplate_baseDir` varchar(255) DEFAULT NULL,
  `genomeTemplate_sequenceDir` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`genomeTemplate_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `group2attributes`
--
CREATE TABLE `group2attributes` (
  `group_id` int(10) unsigned NOT NULL,
  `groupAttrName_id` int(10) unsigned NOT NULL,
  `groupAttrValue_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`group_id`,`groupAttrName_id`),
  KEY `groupAttrName_id` (`groupAttrName_id`,`groupAttrValue_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `groupAttrNames`
--
CREATE TABLE `groupAttrNames` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `state` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `groupAttrValues`
--
CREATE TABLE `groupAttrValues` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `value` text NOT NULL,
  `sha1` char(40) NOT NULL,
  `state` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `sha1` (`sha1`,`state`),
  KEY `value` (`value`(255),`state`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `groupResourceList`
--
CREATE TABLE `groupResourceList` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `url` varchar(32768) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`,`url`(512)),
  KEY `url` (`url`(512))
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `grouprefseq`
--
CREATE TABLE `grouprefseq` (
  `groupRefSeqId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `groupId` int(10) unsigned NOT NULL DEFAULT '1',
  `refSeqId` int(10) unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`groupRefSeqId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `image_cache`
--
CREATE TABLE `image_cache` (
  `imageCacheId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `rid` int(10) unsigned NOT NULL DEFAULT '0',
  `fstart` bigint(20) unsigned NOT NULL DEFAULT '0',
  `fstop` bigint(20) unsigned NOT NULL DEFAULT '0',
  `cacheKey` varchar(32) NOT NULL DEFAULT '',
  `fileName` varchar(64) NOT NULL DEFAULT '',
  `currentDate` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `hitCount` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`imageCacheId`),
  UNIQUE KEY `segment` (`rid`,`fstart`,`fstop`,`cacheKey`),
  KEY `currentDate` (`currentDate`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `kb2attributes`
--
CREATE TABLE `kb2attributes` (
  `kb_id` int(10) unsigned NOT NULL,
  `kbAttrName_id` int(10) unsigned NOT NULL,
  `kbAttrValue_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`kb_id`,`kbAttrName_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `kbAttrNames`
--
CREATE TABLE `kbAttrNames` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `state` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `kbAttrValues`
--
CREATE TABLE `kbAttrValues` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `value` text NOT NULL,
  `sha1` char(40) NOT NULL,
  `state` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `sha1` (`sha1`,`state`),
  KEY `value` (`value`(255),`state`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `kbs`
--
CREATE TABLE `kbs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `group_id` int(10) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` text,
  `databaseName` varchar(255) NOT NULL,
  `refseqName` VARCHAR(255),
  `state` bigint(20) NOT NULL DEFAULT '0',
  `public` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `groupId` (`group_id`,`name`),
  UNIQUE KEY `databaseName` (`databaseName`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `newuser`
--
CREATE TABLE `newuser` (
  `newUserId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(40) DEFAULT NULL,
  `regno` varchar(40) DEFAULT NULL,
  `firstName` varchar(40) DEFAULT NULL,
  `lastName` varchar(40) DEFAULT NULL,
  `institution` varchar(40) DEFAULT NULL,
  `email` varchar(80) DEFAULT NULL,
  `phone` varchar(40) DEFAULT NULL,
  `regDate` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `accountCode` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`newUserId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `project2attributes`
--
CREATE TABLE `project2attributes` (
  `project_id` int(10) unsigned NOT NULL,
  `projectAttrName_id` int(10) unsigned NOT NULL,
  `projectAttrValue_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`project_id`,`projectAttrName_id`),
  KEY `projectAttrName_id` (`projectAttrName_id`,`projectAttrValue_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `projectAttrNames`
--
CREATE TABLE `projectAttrNames` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `state` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `projectAttrValues`
--
CREATE TABLE `projectAttrValues` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `value` text NOT NULL,
  `sha1` char(40) NOT NULL,
  `state` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `sha1` (`sha1`,`state`),
  KEY `value` (`value`(255),`state`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `projectResourceList`
--
CREATE TABLE `projectResourceList` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `url` varchar(32768) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`,`url`(512)),
  KEY `url` (`url`(512))
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `projects`
--
CREATE TABLE `projects` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `groupId` int(10) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `state` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `groupId` (`groupId`,`name`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `refSeqId2scid`
--
CREATE TABLE `refSeqId2scid` (
  `refSeqID` int(10) unsigned NOT NULL DEFAULT '0',
  `scid` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`refSeqID`,`scid`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `refseq`
--
CREATE TABLE `refseq` (
  `refSeqId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `userId` int(10) unsigned NOT NULL DEFAULT '1',
  `refseqName` varchar(255) DEFAULT NULL,
  `refseq_species` varchar(255) DEFAULT NULL,
  `refseq_version` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `FK_genomeTemplate_id` int(11) DEFAULT NULL,
  `mapmaster` varchar(255) DEFAULT NULL,
  `databaseName` varchar(255) DEFAULT NULL,
  `fastaDir` varchar(255) DEFAULT NULL,
  `merged` enum('n','y') NOT NULL DEFAULT 'n',
  `useValuePairs` enum('y','n') DEFAULT 'y',
  `public` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`refSeqId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `refseq2account`
--
CREATE TABLE `refseq2account` (
  `refseq_id` int(10) unsigned NOT NULL,
  `account_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`refseq_id`,`account_id`),
  KEY `account_id` (`account_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `refseq2upload`
--
CREATE TABLE `refseq2upload` (
  `refseq2uploadId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `uploadId` int(10) unsigned NOT NULL DEFAULT '1',
  `refSeqId` int(10) unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`refseq2uploadId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `restAuthTokens`
--
CREATE TABLE `restAuthTokens` (
  `token` char(40) NOT NULL,
  `time` bigint(20) NOT NULL,
  `userId` int(11) NOT NULL,
  `remoteAddr` varchar(255) NOT NULL,
  `method` varchar(255) NOT NULL DEFAULT 'get',
  `path` varchar(255) NOT NULL,
  `reqCount` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`token`),
  KEY `time` (`time`,`userId`,`method`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `searchConfig`
--
CREATE TABLE `searchConfig` (
  `scid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ucscOrg` varchar(255) DEFAULT NULL,
  `ucscDbName` varchar(255) DEFAULT NULL,
  `ucscHgsid` varchar(255) DEFAULT NULL,
  `epPrefix` varchar(255) DEFAULT '',
  `epSuffix` varchar(255) DEFAULT '',
  PRIMARY KEY (`scid`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `style`
--
CREATE TABLE `style` (
  `styleId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`styleId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `subscription`
--
CREATE TABLE `subscription` (
  `subscriptionId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `email` varchar(80) NOT NULL DEFAULT '',
  `news` int(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`subscriptionId`),
  KEY `key_email` (`email`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `tasks`
--
CREATE TABLE `tasks` (
  `id` bigint(10) unsigned NOT NULL AUTO_INCREMENT,
  `command` text NOT NULL,
  `timestamp` datetime DEFAULT NULL,
  `state` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `timestamp` (`timestamp`),
  KEY `state` (`state`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `template2scid`
--
CREATE TABLE `template2scid` (
  `templateId` int(10) unsigned NOT NULL DEFAULT '0',
  `scid` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`templateId`,`scid`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `template2upload`
--
CREATE TABLE `template2upload` (
  `template2uploadId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `templateId` int(10) unsigned NOT NULL DEFAULT '0',
  `uploadId` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`template2uploadId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `textDigest`
--
CREATE TABLE `textDigest` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `digest` char(30) NOT NULL,
  `creationTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `value` text NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `digest` (`digest`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `thread`
--
CREATE TABLE `thread` (
  `database_id` int(10) unsigned NOT NULL DEFAULT '0',
  `blockset_id` int(10) unsigned NOT NULL DEFAULT '0',
  `ftypeid` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`database_id`,`blockset_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `unlockedGroupResourceParents`
--
CREATE TABLE `unlockedGroupResourceParents` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `unlockedGroupResource_id` int(10) unsigned NOT NULL,
  `resourceType` varchar(255) NOT NULL,
  `resource_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `unlockedGroupResources`
--
CREATE TABLE `unlockedGroupResources` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `group_id` int(10) unsigned NOT NULL,
  `resourceType` varchar(255) NOT NULL,
  `resource_id` int(10) unsigned,
  `unlockKey` varchar(255) NOT NULL,
  `resourceUriDigest` char(40) NOT NULL,
  `resourceUri` text NOT NULL,
  `public` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `resourceUriDigest` (`resourceUriDigest`),
  KEY `unlockKey` (`unlockKey`),
  KEY `resourceUri` (resourceUri(255))
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `upload`
--
CREATE TABLE `upload` (
  `uploadId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `userId` int(10) unsigned NOT NULL DEFAULT '1',
  `refSeqId` int(10) unsigned NOT NULL DEFAULT '1',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `userDbName` varchar(255) NOT NULL DEFAULT '',
  `databaseName` varchar(60) NOT NULL DEFAULT '',
  `configFileName` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`uploadId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `user2account`
--
CREATE TABLE `user2account` (
  `genboreeUser_id` int(10) unsigned NOT NULL,
  `account_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`genboreeUser_id`,`account_id`),
  KEY `account_id` (`account_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `user2attributes`
--
CREATE TABLE `user2attributes` (
  `user_id` int(10) unsigned NOT NULL,
  `userAttrName_id` int(10) unsigned NOT NULL,
  `userAttrValue_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`user_id`,`userAttrName_id`),
  KEY `userAttrName_id` (`userAttrName_id`,`userAttrValue_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `userAttrNames`
--
CREATE TABLE `userAttrNames` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `state` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `userAttrValues`
--
CREATE TABLE `userAttrValues` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `value` text NOT NULL,
  `sha1` char(40) NOT NULL,
  `state` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `sha1` (`sha1`,`state`),
  KEY `value` (`value`(255),`state`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- Table structure for table `usergroup`
--
CREATE TABLE `usergroup` (
  `userGroupId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `groupId` int(10) unsigned NOT NULL DEFAULT '1',
  `userId` int(10) unsigned NOT NULL DEFAULT '1',
  `userGroupAccess` char(3) NOT NULL DEFAULT 'w',
  `permissionBits` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`userGroupId`),
  UNIQUE KEY `groupId` (`groupId`,`userId`)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/migrations/db/2014-06-11.trackHubResources.migration1.sql
--
CREATE TABLE IF NOT EXISTS hubs (
  id int(10) unsigned NOT NULL AUTO_INCREMENT,
  group_id int(10) unsigned NOT NULL,
  name varchar(255) NOT NULL,
  shortLabel char(17) NOT NULL,
  longLabel varchar(255) NOT NULL,
  email varchar(255) NOT NULL,
  public tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (id),
  UNIQUE KEY group_id (group_id,name)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/migrations/db/2014-06-11.trackHubResources.migration1.sql
--
CREATE TABLE IF NOT EXISTS hubGenomes (
  id int(10) unsigned NOT NULL AUTO_INCREMENT,
  hub_id int(10) unsigned NOT NULL,
  genome varchar(255) NOT NULL,
  description varchar(32767) DEFAULT NULL,
  organism varchar(255) DEFAULT NULL,
  defaultPos varchar(255) DEFAULT NULL,
  orderKey int(10) unsigned NOT NULL DEFAULT '4800',
  PRIMARY KEY (id),
  UNIQUE KEY hub_id (hub_id,genome)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/migrations/db/2014-06-11.trackHubResources.migration1.sql
--
CREATE TABLE IF NOT EXISTS hubTracks (
  id int(10) unsigned NOT NULL AUTO_INCREMENT,
  hubGenome_id int(10) unsigned NOT NULL,
  trkKey varchar(255) NOT NULL,
  type varchar(255) NOT NULL,
  parent_id int(10) unsigned DEFAULT NULL,
  aggTrack varchar(255) DEFAULT NULL,
  trkUrl varchar(1024) DEFAULT NULL,
  dataUrl varchar(16385) DEFAULT NULL,
  shortLabel char(17) DEFAULT NULL,
  longLabel varchar(255) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY hubGenome_id (hubGenome_id,trkKey)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/genboree/2015-01-29.apiRecord
--
CREATE TABLE IF NOT EXISTS apiRecord (
  id int(10) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
  userName VARCHAR(255),
  rsrcType VARCHAR(255),
  rsrcPath VARCHAR(255),
  queryString VARCHAR(65536),
  method VARCHAR(6),
  contentLength FLOAT, /* in kb */
  clientIp VARCHAR(255),
  respCode SMALLINT(3) UNSIGNED, /* tiny int too small for 100-599 */
  reqStartTime TIMESTAMP NULL,
  reqEndTime TIMESTAMP NULL,
  machineName VARCHAR(255),
  thinNum SMALLINT UNSIGNED, /* usually port number, covering TCP standard port range */
  memUsageStart SMALLINT UNSIGNED, /* in MB, up to 65 GB */
  memUsageEnd SMALLINT UNSIGNED, /* in MB, up to 65 GB */
  byteRange VARCHAR(255),
  userAgent VARCHAR(255),
  referer VARCHAR(255)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/migrations/db/2015-09-28.redminePrjs.migration1.sql
--
CREATE TABLE IF NOT EXISTS redminePrjs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  group_id INT,
  project_id VARCHAR(255) UNIQUE KEY,
  url VARCHAR(255)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;

--
-- svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/migrations/db/2016-02-04.redmineMaps.migration1.sql
--
CREATE TABLE IF NOT EXISTS gbToRmMaps (
  id bigint AUTO_INCREMENT NOT NULL,
  gbGroup varchar(255) NOT NULL,
  gbType enum("group", "database", "file", "track", "kbCollection", "kbDoc", "kbDocProp", "kbQuestion", "kbTemplate") NOT NULL, # Genboree RSRC_TYPE constants for supported REST resources; changes here should also be made in API resource handler
  gbRsrc varchar(255) NOT NULL,
  rmType enum("project", "issue", "wiki", "board", "topic") NOT NULL, # Redmine resource names (boards and topics are not available from REST API); changes here should also be made in API resource handler
  rmRsrc varchar(255) NOT NULL,
  PRIMARY KEY (id, gbGroup),
  INDEX gbRsrcIdx (gbRsrc, gbType),
  INDEX rmRsrcIdx (rmRsrc, gbType),
  UNIQUE INDEX mapIdx (gbGroup, gbRsrc, rmRsrc) # @todo valid in create table?
) ENGINE=MyISAM AUTO_INCREMENT=1000001
partition by linear key(gbGroup)
partitions 32 (
  partition gbGroupPart1
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart2
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart3
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart4
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart5
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart6
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart7
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart8
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart9
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart10
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart11
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart12
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart13
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart14
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart15
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart16
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart17
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart18
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart19
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart20
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart21
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart22
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart23
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart24
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart25
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart26
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart27
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart28
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart29
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart30
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart31
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned",
  partition gbGroupPart32
    DATA DIRECTORY = "/usr/local/brl/data/mysql/partitioned"
);
