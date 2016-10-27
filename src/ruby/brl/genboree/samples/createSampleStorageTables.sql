


CREATE TABLE assay (
  id int(10) unsigned NOT NULL auto_increment,
  name varchar(255) default NULL,
  recordSize int(11) default NULL,
  annoAttribute varchar(255) default NULL,
  annoTrack varchar(255) default NULL,
  PRIMARY KEY  (id)
) ENGINE=MyISAM AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;


CREATE TABLE assay2GenomeAnnotation (
  id int(10) unsigned NOT NULL auto_increment,
  assayId int(11) default NULL,
  recordNumber int(11) default NULL,
  annoAttrValue varchar(255) default NULL,
  PRIMARY KEY  (id)
) ENGINE=MyISAM AUTO_INCREMENT=291 DEFAULT CHARSET=latin1;


CREATE TABLE assay2attributes (
  assayId int(10) unsigned NOT NULL default '0',
  asAttNameId int(10) unsigned NOT NULL default '0',
  asAttValueId int(10) unsigned NOT NULL default '0',
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,assayId,asAttNameId,asAttValueId),
  UNIQUE KEY byAV (state,asAttNameId,asAttValueId,assayId)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


CREATE TABLE assayAttNames (
  asAttNameId int(10) NOT NULL auto_increment,
  asName varchar(255) default NULL,
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,asAttNameId),
  UNIQUE KEY asNameIdx (state,asName)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


CREATE TABLE assayAttValues (
  asAttValueId int(10) NOT NULL auto_increment,
  asValue text,
  asSha1 char(40) default NULL,
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,asAttValueId),
  UNIQUE KEY asSha1Unique (state,asSha1),
  KEY asValueIdx (state,asValue(255))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


CREATE TABLE assayData (
  id int(10) unsigned NOT NULL auto_increment,
  sampleId int(11) default NULL,
  assayId int(11) default NULL,
  assayRunId int(11) default NULL,
  fileLocation varchar(255) default NULL,
  insert_date date default NULL,
  PRIMARY KEY  (id)
) ENGINE=MyISAM AUTO_INCREMENT=451 DEFAULT CHARSET=latin1;


CREATE TABLE assayRecordFields (
  id int(10) unsigned NOT NULL auto_increment,
  assayId int(11) default NULL,
  fieldName varchar(255) default NULL,
  fieldNumber int(11) default NULL,
  dataType int(11) default NULL,
  size int(11) default NULL,
  offset int(11) default NULL,
  PRIMARY KEY  (id)
) ENGINE=MyISAM AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;


CREATE TABLE assayRun (
  id int(10) unsigned NOT NULL auto_increment,
  assayId int(11) default NULL,
  name varchar(255) default NULL,
  date date default NULL,
  PRIMARY KEY  (id)
) ENGINE=MyISAM AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;


CREATE TABLE assayRun2attributes (
  assayRunId int(10) unsigned NOT NULL default '0',
  arAttNameId int(10) unsigned NOT NULL default '0',
  arAttValueId int(10) unsigned NOT NULL default '0',
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,assayRunId,arAttNameId,arAttValueId),
  UNIQUE KEY byAV (state,arAttNameId,arAttValueId,assayRunId)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


CREATE TABLE assayRunAttNames (
  arAttNameId int(10) NOT NULL auto_increment,
  arName varchar(255) default NULL,
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,arAttNameId),
  UNIQUE KEY arNameIdx (state,arName)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


CREATE TABLE assayRunAttValues (
  arAttValueId int(10) NOT NULL auto_increment,
  arValue text,
  arSha1 char(40) default NULL,
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,arAttValueId),
  UNIQUE KEY arSha1Unique (state,arSha1),
  KEY arValueIdx (state,arValue(255))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


