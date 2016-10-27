package org.genboree.dbaccess;

public interface SQLCreateTable {
    public static final String createTableFtype2gclass =
            "CREATE TABLE `ftype2gclass` (\n"+
            "`ftypeid` int(10) unsigned NOT NULL default '0',\n"+
            "`gid` int(10) unsigned NOT NULL default '0',\n"+
            "PRIMARY KEY (`ftypeid`,`gid`),\n"+
            "KEY `gid` (`gid`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableGenomeTemplate =
            "CREATE TABLE `genomeTemplate` (\n" +
            "  `genomeTemplate_id` int(11) NOT NULL auto_increment,\n" +
            "  `genomeTemplate_name` varchar(255) default NULL,\n" +
            "  `genomeTemplate_species` varchar(255) default NULL,\n" +
            "  `genomeTemplate_version` varchar(255) default NULL,\n" +
            "  `genomeTemplate_description` varchar(255) default NULL,\n" +
            "  `genomeTemplate_source` varchar(255) default NULL,\n" +
            "  `genomeTemplate_release_date` date default NULL,\n" +
            "  `genomeTemplate_type` enum('SVG','PNG') NOT NULL default 'SVG',\n" +
            "  `genomeTemplate_scale` int(11) default NULL,\n" +
            "  `genomeTemplate_vgp` enum('Y','N') NOT NULL default 'N',\n" +
            "  PRIMARY KEY  (`genomeTemplate_id`)\n" +
            ") ENGINE=MyISAM";

    public static final String createTableEntrypoint =
            "CREATE TABLE `entryPointTemplate` (\n" +
            "  `entryPointTemplateId` int(10) unsigned NOT NULL auto_increment,\n" +
            "  `refseqTemplateId` int(10) unsigned NOT NULL default 0,\n" +
            "  `fref` varchar(100) default NULL,\n" +
            "  `gclass` varchar(100) default NULL,\n" +
            "  `length` int(10) unsigned default NULL,\n" +
            "  PRIMARY KEY  (`entryPointTemplateId`),\n" +
            "  UNIQUE KEY `refseqTemplateId` (`refseqTemplateId`,`fref`)\n" +
            ") ENGINE=MyISAM";


    public static final String createTableTemplate2Upload =
            "CREATE TABLE `template2upload` (\n" +
            "  `template2uploadId` int(10) unsigned NOT NULL auto_increment,\n" +
            "  `templateId` int(10) unsigned NOT NULL default '0',\n" +
            "  `uploadId` int(10) unsigned NOT NULL default '0',\n" +
            "  PRIMARY KEY  (`template2uploadId`)\n" +
            ") ENGINE=MyISAM";


    public static final String createTableFref =
            "CREATE TABLE `fref` (\n"+
            "  `rid` int unsigned NOT NULL auto_increment,\n"+
            "  `refname` varchar(255) NOT NULL,\n"+
            "  `rlength` bigint unsigned NOT NULL,\n"+
            "  `rbin` double(20,6) NOT NULL default 0.000000,\n"+
            "  `ftypeid` int unsigned NOT NULL default 0,\n"+
            "  `rstrand` enum('+','-') default NULL,\n"+
            "  `gid` int unsigned NOT NULL default 0,\n"+
            "  `gname` varchar(100) default NULL,\n"+
            "  PRIMARY KEY `rid` (`rid`),\n"+
            "  UNIQUE KEY `refname` (`refname`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableFdata2x =
            "  `fid` int(10) unsigned NOT NULL auto_increment,\n"+
            "  `rid` int(10) unsigned NOT NULL default '0',\n"+
            "  `fstart` int(10) unsigned NOT NULL default '0',\n"+
            "  `fstop` int(10) unsigned NOT NULL default '0',\n"+
            "  `fbin` double(20,6) NOT NULL default '0.000000',\n"+
            "  `ftypeid` int(10) unsigned NOT NULL default '0',\n"+
            "  `fscore` double NOT NULL default '0',\n"+
            "  `fstrand` enum('+','-') NOT NULL default '+',\n"+
            "  `fphase` enum('0','1','2') NOT NULL default '0',\n"+
            "  `ftarget_start` int(10) default NULL,\n"+
            "  `ftarget_stop` int(10) default NULL,\n"+
            "  `gname` varchar(255) NOT NULL default '',\n"+
            "  `displayCode` int(10) unsigned default NULL,\n"+
            "  `displayColor` int(10) unsigned default NULL,\n"+
            "  `groupContextCode` char(1) default NULL,\n"+
            "  PRIMARY KEY (`rid`, `ftypeid`, `fbin`, `fstart`, `fstop`, `gname`, `fscore`, `fstrand`, `fphase`),\n"+
            "  UNIQUE KEY `fid` (`fid`),\n"+
            "  KEY `ftypeid_fscore` (`ftypeid`,`fscore`),\n"+
            "  KEY `gnameIdx` (`gname`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableImageCache =
            "CREATE TABLE `image_cache` (\n"+
            "  `imageCacheId` int(10) unsigned NOT NULL auto_increment,\n"+
            "  `rid` int(10) unsigned NOT NULL,\n"+
            "  `fstart` bigint(20) unsigned NOT NULL,\n"+
            "  `fstop` bigint(20) unsigned NOT NULL,\n"+
            "  `cacheKey` varchar(32) NOT NULL,\n"+
            "  `fileName` varchar(64) NOT NULL,\n"+
            "  `currentDate` datetime NOT NULL,\n"+
            "  `hitCount` int(10) unsigned NOT NULL default 0,\n"+
            "  PRIMARY KEY (`imageCacheId`),\n"+
            "  UNIQUE KEY `segment` (`rid`,fstart,fstop,`cacheKey`),\n"+
            "  KEY `currentDate` (`currentDate`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableFdata2 =
            "CREATE TABLE `fdata2` (\n"+createTableFdata2x;

    public static final String createTableFdata2_gv =
            "CREATE TABLE `fdata2_gv` (\n"+createTableFdata2x;

    public static final String createTableFdata2_cv =
            "CREATE TABLE `fdata2_cv` (\n"+createTableFdata2x;

    public static final String createTableGclass =
            "CREATE TABLE `gclass` (\n"+
            "  `gid` int unsigned NOT NULL auto_increment,\n"+
            "  `gclass` varchar(100) default NULL,\n"+
            "  PRIMARY KEY  (`gid`),\n"+
            "  UNIQUE KEY `gclass` (`gclass`)\n"+
            ") ENGINE=MyISAM";

    public static final String createFtypeCount =
            "CREATE TABLE `ftypeCount` (\n"+
            "`ftypeId` int unsigned NOT NULL auto_increment,\n"+
            "`numberOfAnnotations` bigint(11) default 0,\n"+
            "PRIMARY KEY (`ftypeid`)\n"+
            ") ENGINE=MyISAM";


      public static final String createTableStyle =
            "CREATE TABLE `style` (\n"+
            "`styleId` int unsigned NOT NULL auto_increment,\n"+
            "`name` varchar(255) default NULL,\n"+
            "`description` varchar(255) default NULL,\n"+
            "PRIMARY KEY (`styleId`),\n"+
	    "UNIQUE KEY `name` (`name`)\n" +
            ") ENGINE=MyISAM";

    public static final String createTableFtypeAccess =
            "CREATE TABLE `ftypeAccess` (\n"+
            "`id` int(10) unsigned NOT NULL auto_increment,\n"+
            "`userId` int(10) unsigned NOT NULL default '1',\n"+
            "`ftypeid` int(10) unsigned NOT NULL,\n" +
            "`permissionBits` bigint(20) NOT NULL default '0',\n"+
            "PRIMARY KEY (`id`),\n"+
            "UNIQUE KEY `userIdFtypeid` (`ftypeid`,`userId`)\n"+
            ") ENGINE=MyISAM";


    public static final String createTableFeaturetostyle =
            "CREATE TABLE `featuretostyle` (\n"+
            "`ftypeid` int unsigned NOT NULL,\n"+
            "`userId` int unsigned NOT NULL,\n"+
            "`styleId` int unsigned NOT NULL,\n"+
            "PRIMARY KEY `userId` (userId,ftypeid,styleId),\n"+
	    "UNIQUE KEY `userId` (`userId`,`ftypeid`),\n" +
            "KEY `ftypeid` (`ftypeid`),\n"+
            "KEY `styleId` (`styleId`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableColor =
            "CREATE TABLE `color` (\n"+
            "`colorId` int unsigned NOT NULL auto_increment,\n"+
            "`value` varchar(32) default NULL,\n"+
            "PRIMARY KEY (`colorId`),\n"+
	    "UNIQUE KEY `value` (`value`)\n" +
            ") ENGINE=MyISAM";

    public static final String createTableFeaturetocolor =
            "CREATE TABLE `featuretocolor` (\n"+
            "`ftypeid` int unsigned NOT NULL,\n"+
            "`userId` int unsigned NOT NULL,\n"+
            "`colorId` int unsigned NOT NULL,\n"+
            "PRIMARY KEY `userId` (userId,ftypeid,colorId),\n"+
	    "UNIQUE KEY `userId` (`userId`,`ftypeid`),\n" +
            "KEY `ftypeid` (`ftypeid`),\n"+
            "KEY `colorId` (`colorId`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableAttNames =
            "CREATE TABLE `attNames` (\n" +
            "`attNameId` int(10) unsigned NOT NULL auto_increment,\n" +
            "`name` varchar(255) NOT NULL default '',\n" +
            "PRIMARY KEY  (`attNameId`),\n" +
            "UNIQUE KEY `nameIdx` (`name`)\n" +
            ") ENGINE=MyISAM";

    public static final String createTableAttValues =
            "CREATE TABLE `attValues` (\n" +
            "`attValueId` int(10) unsigned NOT NULL auto_increment,\n" +
            "`value` text NOT NULL,\n" +
            "`md5` varchar(32) NOT NULL,\n" +
            "PRIMARY KEY  (`attValueId`),\n" +
            "UNIQUE KEY `md5Unique` (`md5`),\n" +
            "KEY `valueIdx` (`value`(255))\n" +
            ") ENGINE=MyISAM";

    public static final String createTableFid2attribute =
            "CREATE TABLE `fid2attribute` (\n" +
            "`fid` int(10) unsigned NOT NULL default '0',\n" +
            "`attNameId` int(10) unsigned NOT NULL default '0',\n" +
            "`attValueId` int(10) unsigned NOT NULL default '0',\n" +
            "PRIMARY KEY  (`fid`,`attNameId`,`attValueId`),\n" +
            "UNIQUE KEY `byAVP` (`attNameId`,`attValueId`, `fid`)\n" +
            ")  ENGINE=MyISAM";


    public static final String createTableFtype2attributeName =
            "CREATE TABLE `ftype2attributeName` (\n" +
            "`ftypeid` int(10) unsigned NOT NULL default '0',\n" +
            "`attNameId` int(10) unsigned NOT NULL default '0',\n" +
            "PRIMARY KEY  (`ftypeid`,`attNameId`)\n" +
            ")  ENGINE=MyISAM";

    public static final String createTableLink =
            "CREATE TABLE IF NOT EXISTS `link` (\n"+
            "`linkId` char(32) NOT NULL default '',\n"+
            "`name` varchar(255) default NULL,\n"+
            "`description` varchar(255) default NULL,\n"+
            "PRIMARY KEY  (`linkId`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableFeaturetolink =
            "CREATE TABLE IF NOT EXISTS `featuretolink` (\n"+
            "`ftypeid` int(10) unsigned NOT NULL default '0',\n"+
            "`userId` int(10) unsigned NOT NULL default '0',\n"+
            "`linkId` char(32) NOT NULL default '',\n"+
            "PRIMARY KEY  (`userId`,`ftypeid`,`linkId`),\n"+
            "KEY `ftypeid` (`ftypeid`),\n"+
            "KEY `linkId` (`linkId`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableFeaturesort =
            "CREATE TABLE IF NOT EXISTS `featuresort` (\n"+
            "`ftypeid` int(10) unsigned NOT NULL default '0',\n"+
            "`userId` int(10) unsigned NOT NULL default '0',\n"+
            "`sortkey` int(10) unsigned NOT NULL default '0',\n"+
            "PRIMARY KEY  (`userId`,`sortkey`,`ftypeid`),\n"+
            "UNIQUE KEY `userId` (`userId`,`ftypeid`),\n"+
            "KEY `ftypeid` (`ftypeid`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableFeaturedisplay =
            "CREATE TABLE `featuredisplay` (\n"+
            "`ftypeid` int unsigned NOT NULL,\n"+
            "`userId` int unsigned NOT NULL,\n"+
            "`display` int unsigned NOT NULL default 1,\n"+
            "PRIMARY KEY (`ftypeid`,`userId`),\n"+
            "KEY `k_userId` (`userId`),\n"+
            "KEY `k_ftypeid` (`ftypeid`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableFtype =

            "CREATE TABLE `ftype` (\n"+
            "  `ftypeid` int(11) NOT NULL auto_increment,\n"+
            "  `fmethod` varchar(100) NOT NULL default '',\n"+
            "  `fsource` varchar(100) default NULL,\n"+
            "  PRIMARY KEY  (`ftypeid`),\n"+
            "  UNIQUE KEY `ftype` (`fmethod`,`fsource`)\n"+
            ") ENGINE=MyISAM";


    public static final String createTableFeatureurl =
            "CREATE TABLE `featureurl` (\n"+
            "`ftypeid` int(10) unsigned NOT NULL default '0',\n"+
            "`url` varchar(255) default NULL,\n"+
            "`description` text,\n"+
            "`label` varchar(255) default NULL,\n"+
						" PRIMARY KEY  (`ftypeid`)\n"+
            ") ENGINE=MyISAM" ;


    public static final String createTableSamples =
            "CREATE TABLE `samples` (\n" +
            "`saId` int(10) unsigned NOT NULL auto_increment,\n" +
            "`saName` varchar(255) NOT NULL default '',\n" +
            "`state` int(11) NOT NULL default '0',\n" +
            "PRIMARY KEY  (`state`,`saId`,`saName`),\n" +
            "UNIQUE KEY `samplesNamesU` (`state`,`saName`)\n"+
            ") ENGINE=MyISAM" ;


    public static final String createTableSamples2attributes =
            "CREATE TABLE `samples2attributes` (\n" +
            "`saId` int(10) unsigned NOT NULL default '0',\n" +
            "`saAttNameId` int(10) unsigned NOT NULL default '0',\n" +
            "`saAttValueId` int(10) unsigned NOT NULL default '0',\n" +
            "`state` int(11) NOT NULL default '0',\n" +
            "PRIMARY KEY  (`state`,`saId`,`saAttNameId`,`saAttValueId`), \n" +
            "UNIQUE KEY `byAV` (`state`,`saAttNameId`,`saAttValueId`,`saId`)\n"+
            ") ENGINE=MyISAM" ;


    public static final String createTableSamplesAttNames  =
            "CREATE TABLE `samplesAttNames` (\n" +
            "`saAttNameId` int(10) NOT NULL auto_increment,\n" +
            "`saName` varchar(255) default NULL,\n" +
            "`state` int(11) NOT NULL default '0',\n" +
            "PRIMARY KEY  (`state`, `saAttNameId`),\n" +
            "UNIQUE KEY `saNameIdx` (`state`,`saName`)\n"+
            ") ENGINE=MyISAM" ;


    public static final String createTableSamplesAttValues =
            "CREATE TABLE `samplesAttValues` (\n" +
            "`saAttValueId` int(10) NOT NULL auto_increment,\n" +
            "`saValue` text,\n" +
            "`saSha1` char(40) default NULL,\n" +
            "`state` int(11) NOT NULL default '0',\n" +
            "PRIMARY KEY  (`state`, `saAttValueId`),\n" +
            "UNIQUE KEY `saSha1Unique` (`state`,`saSha1`),\n" +
            "KEY `saValueIdx` (`state`, `saValue`(255))\n" +
            ") ENGINE=MyISAM" ;


  // STUDY - related tables
  public static final String createTableStudies =
    "create table if not exists studies (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  type varchar(255) not null," +
    "  lab varchar(255) not null," +
    "  contributors text not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name(255))," +
    "  key (type(255))," +
    "  key (lab(255))" +
    ") engine=MyISAM ;" ;

  public static final String createTableStudyAttrNames =
    "create table if not exists studyAttrNames (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name)" +
    ") engine=MyISAM ;" ;

  public static final String createTableStudyAttrValues =
    "create table if not exists studyAttrValues (" +
    "  id int unsigned not null auto_increment," +
    "  value text not null," +
    "  sha1 char(40) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (sha1, state)," +
    "  key (value(255), state)" +
    ") engine=MyISAM ;" ;

  public static final String createTableStudy2attributes =
    "create table if not exists study2attributes (" +
    "  study_id int unsigned not null," +
    "  studyAttrName_id int unsigned not null," +
    "  studyAttrValue_id int unsigned not null," +
    "  primary key (study_id, studyAttrName_id)," +
    "  key (studyAttrName_id, studyAttrValue_id)" +
    ") engine=MyISAM ;" ;

  // BIOSAMPLE - related tables
  public static final String createTableBioSamples =
    "create table if not exists bioSamples (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  type varchar(255) not null," +
    "  biomaterialState varchar(255) not null," +
    "  biomaterialProvider varchar(255) not null," +
    "  biomaterialSource varchar(255) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name(255))," +
    "  key (type(255))," +
    "  key (biomaterialState(255))," +
    "  key (biomaterialProvider(255))" +
    ") engine=MyISAM ;" ;

  public static final String createTableBioSampleAttrNames =
    "create table if not exists bioSampleAttrNames (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name)" +
    ") engine=MyISAM ;" ;

  public static final String createTableBioSampleAttrValues =
    "create table if not exists bioSampleAttrValues (" +
    "  id int unsigned not null auto_increment," +
    "  value text not null," +
    "  sha1 char(40) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (sha1, state)," +
    "  key (value(255), state)" +
    ") engine=MyISAM ;" ;

  public static final String createTableBioSample2attributes =
    "create table if not exists bioSample2attributes (" +
    "  bioSample_id int unsigned not null," +
    "  bioSampleAttrName_id int unsigned not null," +
    "  bioSampleAttrValue_id int unsigned not null," +
    "  primary key (bioSample_id, bioSampleAttrName_id)," +
    "  key (bioSampleAttrName_id, bioSampleAttrValue_id)" +
    ") engine=MyISAM ;" ;

  // BIOSAMPLE SET - related tables
  public static final String createTableBioSampleSets =
    "create table if not exists bioSampleSets (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name(255))" +
    ") engine=MyISAM ;" ;

  public static final String createTableBioSampleSetAttrNames =
    "create table if not exists bioSampleSetAttrNames (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name)" +
    ") engine=MyISAM ;" ;

  public static final String createTableBioSampleSetAttrValues =
    "create table if not exists bioSampleSetAttrValues (" +
    "  id int unsigned not null auto_increment," +
    "  value text not null," +
    "  sha1 char(40) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (sha1)," +
    "  key (value(255))" +
    ") engine=MyISAM ;" ;

  public static final String createTableBioSampleSet2attributes =
    "create table if not exists bioSampleSet2attributes (" +
    "  bioSampleSet_id int unsigned not null," +
    "  bioSampleSetAttrName_id int unsigned not null," +
    "  bioSampleSetAttrValue_id int unsigned not null," +
    "  primary key (bioSampleSet_id, bioSampleSetAttrName_id)," +
    "  key (bioSampleSetAttrName_id, bioSampleSetAttrValue_id)" +
    ") engine=MyISAM ;" ;

  public static final String createTableBioSample2bioSampleSet =
    "create table if not exists bioSample2bioSampleSet ( " +
    "  bioSample_id int(10) unsigned NOT NULL, " +
    "  bioSampleSet_id int(10) unsigned NOT NULL, " +
    "  primary key (bioSampleSet_id, bioSample_id), " +
    "  key bioSample_id (bioSample_id) " +
    ") engine=MyISAM ;" ;

  // EXPERIMENT - related tables
  public static final String createTableExperiments =
    "create table if not exists experiments (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  type varchar(255) not null," +
    "  study_id int unsigned default null," +
    "  bioSample_id int unsigned default null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name(255))," +
    "  key (type(255))" +
    ") engine=MyISAM ;" ;

  public static final String createTableExperimentAttrNames =
    "create table if not exists experimentAttrNames (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name)" +
    ") engine=MyISAM ;" ;

  public static final String createTableExperimentAttrValues =
    "create table if not exists experimentAttrValues (" +
    "  id int unsigned not null auto_increment," +
    "  value text not null," +
    "  sha1 char(40) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (sha1, state)," +
    "  key (value(255), state)" +
    ") engine=MyISAM ;" ;

  public static final String createTableExperiment2attributes =
    "create table if not exists experiment2attributes (" +
    "  experiment_id int unsigned not null," +
    "  experimentAttrName_id int unsigned not null," +
    "  experimentAttrValue_id int unsigned not null," +
    "  primary key (experiment_id, experimentAttrName_id)," +
    "  key (experimentAttrName_id, experimentAttrValue_id)" +
    ") engine=MyISAM ;" ;

  // RUN - related tables
  public static final String createTableRuns =
    "create table if not exists runs (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  type varchar(255) not null," +
    "  time datetime not null," +
    "  performer varchar(255) not null," +
    "  location varchar(255) not null," +
    "  experiment_id int unsigned default null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name(255))," +
    "  key (type(255))," +
    "  key (time)" +
    ") engine=MyISAM ;" ;

  public static final String createTableRunAttrNames =
    "create table if not exists runAttrNames (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name)" +
    ") engine=MyISAM ;" ;

  public static final String createTableRunAttrValues =
    "create table if not exists runAttrValues (" +
    "  id int unsigned not null auto_increment," +
    "  value text not null," +
    "  sha1 char(40) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (sha1, state)," +
    "  key (value(255), state)" +
    ") engine=MyISAM ;" ;

  public static final String createTableRun2attributes =
    "create table if not exists run2attributes (" +
    "  run_id int unsigned not null," +
    "  runAttrName_id int unsigned not null," +
    "  runAttrValue_id int unsigned not null," +
    "  primary key (run_id, runAttrName_id)," +
    "  key (runAttrName_id, runAttrValue_id)" +
    ") engine=MyISAM ;" ;

  // ANALYSIS - related tables
  public static final String createTableAnalyses =
    "create table if not exists analyses (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  type varchar(255) not null," +
    "  dataLevel int not null default -1," +
    "  experiment_id int unsigned default null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name(255))," +
    "  key (type(255))," +
    "  key (experiment_id, dataLevel)" +
    ") engine=MyISAM ;" ;

  public static final String createTableAnalysisAttrNames =
    "create table if not exists analysisAttrNames (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name)" +
    ") engine=MyISAM ;" ;

  public static final String createTableAnalysisAttrValues =
    "create table if not exists analysisAttrValues (" +
    "  id int unsigned not null auto_increment," +
    "  value text not null," +
    "  sha1 char(40) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (sha1, state)," +
    "  key (value(255), state)" +
    ") engine=MyISAM ;" ;

  public static final String createTableAnalysis2attributes =
    "create table if not exists analysis2attributes (" +
    "  analysis_id int unsigned not null," +
    "  analysisAttrName_id int unsigned not null," +
    "  analysisAttrValue_id int unsigned not null," +
    "  primary key (analysis_id, analysisAttrName_id)," +
    "  key (analysisAttrName_id, analysisAttrValue_id)" +
    ") engine=MyISAM ;" ;

  // PUBLICATION - related tables
  public static final String createTablePublications =
    "create table if not exists publications (" +
    "  id int unsigned not null auto_increment," +
    "  pmid int unsigned default 0," +
    "  type varchar(255) not null, " +
    "  title text not null," +
    "  authorList text not null," +
    "  journal varchar(255) default null," +
    "  meeting varchar(255) default null," +
    "  date date null," +
    "  volume varchar(255) default null," +
    "  issue varchar(255) default null," +
    "  startPage int unsigned default 0," +
    "  endPage int unsigned default 0," +
    "  abstract text default null," +
    "  meshHeaders text default null," +
    "  url text default null," +
    "  state int not null default 0," +
    "  language varchar(255) not null default 'eng'," +
    "  primary key (id)," +
    "  key (pmid)," +
    "  key (type, date, authorList(500))," +
    "  key (authorList(500), date, type)" +
    ") engine=MyISAM ;" ;

  public static final String createTablePublicationAttrNames =
    "create table if not exists publicationAttrNames (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name)" +
    ") engine=MyISAM ;" ;

  public static final String createTablePublicationAttrValues =
    "create table if not exists publicationAttrValues (" +
    "  id int unsigned not null auto_increment," +
    "  value text not null," +
    "  sha1 char(40) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (sha1, state)," +
    "  key (value(255), state)" +
    ") engine=MyISAM ;" ;

  public static final String createTablePublication2attributes =
    "create table if not exists publication2attributes (" +
    "  publication_id int unsigned not null," +
    "  publicationAttrName_id int unsigned not null," +
    "  publicationAttrValue_id int unsigned not null," +
    "  primary key (publication_id, publicationAttrName_id)," +
    "  key (publicationAttrName_id, publicationAttrValue_id)" +
    ") engine=MyISAM ;" ;

  //--------------------------------------------------------------------------
  public static final String createTableFtypeAttrNames =
    "create table if not exists ftypeAttrNames(" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (name)" +
    ") engine=MyISAM ;" ;

  public static final String createTableFtypeAttrValues =
    "create table if not exists ftypeAttrValues(" +
    "  id int unsigned not null auto_increment," +
    "  value text not null," +
    "  sha1 char(40) not null," +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (sha1, state)," +
    "  key (value(255), state)" +
    ") engine=MyISAM ;" ;

  public static final String createTableFtype2attributes =
    "create table if not exists ftype2attributes(" +
    "  ftype_id int unsigned not null," +
    "  ftypeAttrName_id int unsigned not null," +
    "  ftypeAttrValue_id int unsigned not null," +
    "  primary key (ftype_id, ftypeAttrName_id)," +
    "  key (ftypeAttrName_id, ftypeAttrValue_id)" +
    ") engine=MyISAM ;" ;

  public static final String createTableFtypeAttrDisplays =
    "create table if not exists ftypeAttrDisplays(" +
    "  id int unsigned not null auto_increment," +
    "  ftype_id int unsigned not null," +
    "  ftypeAttrName_id int unsigned not null," +
    "  genboreeuser_id int not null default 0," +
    "  rank int not null default 0," +
    "  color varchar(255) not null default '#000080'," +
    "  flags tinyint unsigned not null default 0, " +
    "  state int not null default 0," +
    "  primary key (id)," +
    "  unique key (ftype_id, genboreeuser_id, rank)," +
    "  key (genboreeuser_id)" +
    ") engine=MyISAM ;" ;

  // ------------------------------------------------------------------
  public static final String createTableBlockLevelDataInfo =
    "create table if not exists blockLevelDataInfo(" +
    "  id int unsigned not null auto_increment," +
    "  fileName varchar(255) not null," +
    "  offset bigint unsigned not null," +
		"  byteLength int(11) unsigned NOT NULL DEFAULT '0'," +
    "  numRecords int not null default -1," +
    "  rid int(10) unsigned NOT NULL DEFAULT '0'," +
    "  ftypeid int(10) unsigned NOT NULL DEFAULT '0'," +
    "  fstart int(10) unsigned NOT NULL DEFAULT '0'," +
    "  fstop int(10) unsigned NOT NULL DEFAULT '0'," +
    "  fbin double(20,6) NOT NULL DEFAULT '0.000000'," +
    "  gbBlockBpSpan int unsigned default null," +
    "  gbBlockBpStep int unsigned default null," +
    "  gbBlockScale double default null," +
    "  gbBlockLowLimit double default null," +
    "  primary key (id)," +
    "  UNIQUE KEY fileName (fileName,offset)," +
    "  KEY rid (rid,ftypeid,fbin,fstart,fstop)" +
    ") engine=MyISAM ;" ;

  public static final String createTableZoomLevels =
   "CREATE TABLE if not exists zoomLevels (" +
   " id int(10) unsigned NOT NULL auto_increment," +
    "level tinyint(4) NOT NULL DEFAULT '0'," +
    "ftypeid int(10) unsigned NOT NULL DEFAULT '0'," +
    "rid int(10) unsigned NOT NULL DEFAULT '0'," +
    "fbin double(20,6) NOT NULL DEFAULT '0.00000'," +
    "fstart int(10) unsigned NOT NULL DEFAULT '0'," +
    "fstop int(10) unsigned NOT NULL DEFAULT '0'," +
    "scoreCount int(11) NOT NULL DEFAULT '0'," +
    "scoreSum double NOT NULL DEFAULT '0.0000'," +
    "scoreMax double NOT NULL DEFAULT '0.0000'," +
    "scoreMin double NOT NULL DEFAULT '0.0000'," +
    "scoreSumOfSquares double NOT NULL DEFAULT '0.0000'," +
    "negScoreCount int(11) NOT NULL DEFAULT '0'," +
    "negScoreSum double NOT NULL DEFAULT '0.0000'," +
    "negScoreSumOfSquares double NOT NULL DEFAULT '0.0000'," +
    "PRIMARY KEY  (id)," +
    "UNIQUE KEY ftype_id (ftypeid,rid,fbin,fstart,fstop,level)" +
    ") ENGINE=MyISAM ;" ;

	public static final String createTableFiles =
		"CREATE TABLE IF NOT EXISTS files (" +
		"	id int(10) unsigned NOT NULL AUTO_INCREMENT," +
		"name blob NOT NULL," +
		"digest  varchar(40) NOT NULL," +
		"label blob NOT NULL," +
		"description text," +
		"autoArchive tinyint(1) NOT NULL," +
		"hide tinyint(1) NOT NULL," +
		"createdDate timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP," +
		"lastModified timestamp NOT NULL DEFAULT '1970-01-01 15:00:00'," +
		"modifiedBy int(10) DEFAULT NULL," +
    "remoteStorageConf_id int(10) unsigned," +
		"PRIMARY KEY  (id)," +
		"UNIQUE KEY digest (digest)," +
		"KEY name (name(766))" +
		") ENGINE=MyISAM ;" ;

	public static final String createTableFileAttrNames =
	"CREATE TABLE IF NOT EXISTS fileAttrNames (" +
	" id int(10) unsigned NOT NULL AUTO_INCREMENT," +
	"name varchar(255) NOT NULL," +
  "state int(11) NOT NULL DEFAULT '0'," +
  "PRIMARY KEY (id)," +
  "UNIQUE KEY name (name)" +
	") ENGINE=MyISAM;" ;

	public static final String createTableFileAttrValues =
	"CREATE TABLE IF NOT EXISTS fileAttrValues (" +
	" id int(10) unsigned NOT NULL AUTO_INCREMENT," +
	"value text NOT NULL," +
	"sha1 char(40) NOT NULL," +
  "state int(11) NOT NULL DEFAULT '0'," +
  "PRIMARY KEY (id)," +
  "UNIQUE KEY sha1 (sha1, state)," +
	"KEY value (value(255),state)" +
	") ENGINE=MyISAM;" ;

	public static final String createTableFile2Attributes =
	"CREATE TABLE IF NOT EXISTS file2attributes (" +
	" file_id int(10) unsigned NOT NULL," +
	"fileAttrName_id int(10) unsigned NOT NULL," +
  "fileAttrValue_id int(10) unsigned NOT NULL," +
  "PRIMARY KEY (file_id, fileAttrName_id)," +
  "KEY fileAttrName_id (fileAttrName_id, fileAttrValue_id)" +
	") ENGINE=MyISAM;" ;

  public static final String createTableRemoteStorageConfs =
  "CREATE TABLE IF NOT EXISTS remoteStorageConfs (" +
  "  id int(10) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY," +
  "  conf text" +
  ") ENGINE=MyISAM ;" ;

// RESOURCE LISTS FOR CURRENT DATA ENTITY TYPES
  public static final String createMixedResourceListTable =
    "create table if not exists mixedResourceList (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  url varchar(32768) not null," +
    "  primary key (id)," +
    "  unique key (name, url(512))," +
    "  key (url(512))" +
    ") engine=MyISAM ;" ;

  public static final String createTrackResourceListTable =
    "create table if not exists trackResourceList (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  url varchar(32768) not null," +
    "  primary key (id)," +
    "  unique key (name, url(512))," +
    "  key (url(512))" +
    ") engine=MyISAM ;" ;

  public static final String createFileResourceListTable =
    "create table if not exists fileResourceList (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  url varchar(32768) not null," +
    "  primary key (id)," +
    "  unique key (name, url(512))," +
    "  key (url(512))" +
    ") engine=MyISAM ;" ;

  public static final String createSampleResourceListTable =
    "create table if not exists sampleResourceList (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  url varchar(32768) not null," +
    "  primary key (id)," +
    "  unique key (name, url(512))," +
    "  key (url(512))" +
    ") engine=MyISAM ;" ;

  public static final String createSampleSetResourceListTable =
    "create table if not exists sampleSetResourceList (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  url varchar(32768) not null," +
    "  primary key (id)," +
    "  unique key (name, url(512))," +
    "  key (url(512))" +
    ") engine=MyISAM ;"  ;

  public static final String createExperimentResourceListTable =
    "create table if not exists experimentResourceList (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  url varchar(32768) not null," +
    "  primary key (id)," +
    "  unique key (name, url(512))," +
    "  key (url(512))" +
    ") engine=MyISAM ;"  ;

  public static final String createStudyResourceListTable =
    "create table if not exists studyResourceList (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  url varchar(32768) not null," +
    "  primary key (id)," +
    "  unique key (name, url(512))," +
    "  key (url(512))" +
    ") engine=MyISAM ;"  ;

  public static final String createAnalysisResourceListTable =
    "create table if not exists analysisResourceList (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  url varchar(32768) not null," +
    "  primary key (id)," +
    "  unique key (name, url(512))," +
    "  key (url(512))" +
    ") engine=MyISAM ;"  ;

  public static final String createRunResourceListTable =
    "create table if not exists runResourceList (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  url varchar(32768) not null," +
    "  primary key (id)," +
    "  unique key (name, url(512))," +
    "  key (url(512))" +
    ") engine=MyISAM ;"  ;

  public static final String createPublicationResourceListTable =
    "create table if not exists publicationResourceList (" +
    "  id int unsigned not null auto_increment," +
    "  name varchar(255) not null," +
    "  url varchar(32768) not null," +
    "  primary key (id)," +
    "  unique key (name, url(512))," +
    "  key (url(512))" +
    ") engine=MyISAM ;" ;

    public static final String[] migrateFdata =
            {
                "fref", createTableFref,
                "fdata2", createTableFdata2,
                "fdata2_gv", createTableFdata2_gv,
                "fdata2_cv", createTableFdata2_cv,
                "gclass", createTableGclass,
                "style", createTableStyle,
                "ftypeCount", createFtypeCount,
                "ftypeAccess", createTableFtypeAccess,
                "featuretostyle", createTableFeaturetostyle,
                "color", createTableColor,
                "featuretocolor", createTableFeaturetocolor,
                "link", createTableLink,
                "attNames", createTableAttNames,
                "attValues", createTableAttValues,
                "fid2attribute", createTableFid2attribute,
                "ftype2attributeName", createTableFtype2attributeName ,
                "featuretolink", createTableFeaturetolink,
                "featuresort", createTableFeaturesort,
                "featuredisplay", createTableFeaturedisplay
            };

    public static final String createTableFmeta =
            "CREATE TABLE `fmeta` (\n"+
            "  `fname` varchar(255) NOT NULL default '',\n"+
            "  `fvalue` varchar(255) NOT NULL default '',\n"+
            "  PRIMARY KEY  (`fname`)\n"+
            ") ENGINE=MyISAM";


    public static final String createTableRidSequence =

            "CREATE TABLE `ridSequence` (\n"+
            "`ridSeqId` int(10) unsigned NOT NULL auto_increment,\n"+
            "`seqFileName` varchar(255) default NULL,\n"+
            "`deflineFileName` varchar(255) default NULL,\n"+
            "PRIMARY KEY (`ridSeqId`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTablerid2RidSeqId =
            "CREATE TABLE `rid2ridSeqId` (\n"+
            "`rid` int(10) unsigned NOT NULL default '0',\n"+
            "`ridSeqId` int(10) unsigned NOT NULL default '0',\n"+
            "`offset` int(10) unsigned NOT NULL default '0',\n"+
            "`length` int(10) unsigned NOT NULL default '0',\n"+
            "PRIMARY KEY (`rid`,`ridSeqId`),\n"+
            "UNIQUE KEY `reverse` (`ridSeqId`,`rid`)\n"+
            ") ENGINE=MyISAM";

    public static final String createTableFidText =
            "CREATE TABLE `fidText` (\n"+
            "`fid` int(10) unsigned NOT NULL default '0',\n"+
            "`ftypeid` int(10) unsigned NOT NULL default '0',\n"+
            "`textType` enum('t','s') NOT NULL default 't',\n"+
            "`text` mediumtext,\n"+
            "PRIMARY KEY  (`fid`,`textType`),\n"+
            "KEY ftypeid (`ftypeid`)\n"+
            ") ENGINE=MyISAM";


    public static final String createTabularLayoutTable =
            "CREATE TABLE IF NOT EXISTS tabularLayouts (\n"+
             "id INT UNSIGNED NOT NULL auto_increment,\n"+
             "name VARCHAR(255) NOT NULL,\n"+
             "userId INT UNSIGNED NOT NULL,\n"+
             "createDate DATE NOT NULL,\n"+
             "lastModDate DATETIME NOT NULL,\n"+
             "description VARCHAR(255),\n"+
             "columns BLOB NOT NULL,\n"+
             "sort BLOB NOT NULL,\n"+
             "groupMode TINYINT NOT NULL DEFAULT 0,\n"+
             "flags TINYINT UNSIGNED NOT NULL,\n"+
             "PRIMARY KEY(id),\n"+
             "UNIQUE (name)\n"+
             ") ENGINE=MyISAM ;";

    public static final String createQueriesTable =
             "CREATE TABLE IF NOT EXISTS queries (\n" +
             "  id INT NOT NULL AUTO_INCREMENT,\n" +
             "  name VARCHAR(255) NOT NULL,\n" +
             "  description VARCHAR(255),\n" +
             "  user_id INT(10) NOT NULL,\n" +
             "  query TEXT NOT NULL,\n" +
             "  PRIMARY KEY (id),\n" +
             "  UNIQUE (name)\n" +
             ") ENGINE=MyISAM ;" ;


    public static final String[] dbSchema =
            {
                createTableAttNames,
                createTableAttValues,
                createTableFid2attribute,
                createTableFtype2attributeName,
                createTableFmeta,
                createTableFtype,
                createTableFref,
                "CREATE TABLE `fdata2` (\n" + createTableFdata2x,
                "CREATE TABLE `fdata2_gv` (\n" + createTableFdata2x,
                "CREATE TABLE `fdata2_cv` (\n" + createTableFdata2x,
                createTableGclass,
                createTableStyle,
                createFtypeCount,
                createTableFtypeAccess,
                createTableFeaturetostyle,
                createTableColor,
                createTableFeaturetocolor,
                createTableLink,
                createTableFeaturetolink,
                createTableFeaturesort,
                createTableFeatureurl,
                createTableFtype2gclass,
                createTableFeaturedisplay,
                createTableImageCache,
                createTableRidSequence,
                createTablerid2RidSeqId,
                createTableFidText,
                createTableSamples,
                createTableSamples2attributes,
                createTableSamplesAttNames,
                createTableSamplesAttValues,
                createTableStudies,
                createTableStudy2attributes,
                createTableStudyAttrValues,
                createTableStudyAttrNames,
                createTableRuns,
                createTableRun2attributes,
                createTableRunAttrNames,
                createTableRunAttrValues,
                createTableExperiments,
                createTableExperimentAttrNames,
                createTableExperimentAttrValues,
                createTableExperiment2attributes,
                createTableBioSamples,
                createTableBioSampleAttrNames,
                createTableBioSampleAttrValues,
                createTableBioSample2attributes,
                createTableBioSampleSets,
                createTableBioSampleSetAttrNames,
                createTableBioSampleSetAttrValues,
                createTableBioSampleSet2attributes,
                createTableBioSample2bioSampleSet,
                createTableAnalyses,
                createTableAnalysis2attributes,
                createTableAnalysisAttrNames,
                createTableAnalysisAttrValues,
                createTablePublications,
                createTablePublication2attributes,
                createTablePublicationAttrNames,
                createTablePublicationAttrValues,
                createTableFtype2attributes,
                createTableFtypeAttrNames,
                createTableFtypeAttrValues,
                createTableFtypeAttrDisplays,
                createTableBlockLevelDataInfo,
                createTabularLayoutTable,
                createQueriesTable,
                createTableZoomLevels,
                createMixedResourceListTable,
                createTrackResourceListTable,
                createFileResourceListTable,
                createSampleResourceListTable,
                createSampleSetResourceListTable,
                createExperimentResourceListTable,
                createStudyResourceListTable,
                createAnalysisResourceListTable,
                createRunResourceListTable,
                createPublicationResourceListTable,
								createTableFiles,
								createTableFile2Attributes,
								createTableFileAttrNames,
								createTableFileAttrValues,
                createTableRemoteStorageConfs,
                "INSERT INTO fmeta (fname,fvalue) VALUES ('MIN_BIN', '1000')",
                "INSERT INTO fmeta (fname,fvalue) VALUES ('STRAIGHT_JOIN_LIMIT', '200000')",
                "INSERT INTO fmeta (fname,fvalue) VALUES ('MAX_BIN', '1000000000')",
                "INSERT INTO fmeta (fname,fvalue) VALUES ('CHUNK_SIZE', '2000')",
                "INSERT INTO ftype (ftypeid, fmethod, fsource) VALUES (1, 'Component', 'Chromosome' )",
                "INSERT INTO ftype (ftypeid, fmethod, fsource) VALUES (2, 'Supercomponent', 'Sequence' )"
            };

}
