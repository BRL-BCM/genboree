
CREATE TABLE assay2attributes (
  assayId int(10) unsigned NOT NULL default '0',
  asAttNameId int(10) unsigned NOT NULL default '0',
  asAttValueId int(10) unsigned NOT NULL default '0',
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,assayId,asAttNameId,asAttValueId),
  UNIQUE KEY byAV (state,asAttNameId,asAttValueId,assayId)
) ;

CREATE TABLE assayAttNames (
  asAttNameId int(10) NOT NULL auto_increment,
  asName varchar(255) default NULL,
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,asAttNameId),
  UNIQUE KEY asNameIdx (state,asName)
) ;

CREATE TABLE assayAttValues (
  asAttValueId int(10) NOT NULL auto_increment,
  asValue text,
  asSha1 char(40) default NULL,
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,asAttValueId),
  UNIQUE KEY asSha1Unique (state,asSha1),
  KEY asValueIdx (state,asValue(255))
) ;

CREATE TABLE assayRun2attributes (
  assayRunId int(10) unsigned NOT NULL default '0',
  arAttNameId int(10) unsigned NOT NULL default '0',
  arAttValueId int(10) unsigned NOT NULL default '0',
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,assayRunId,arAttNameId,arAttValueId),
  UNIQUE KEY byAV (state,arAttNameId,arAttValueId,assayRunId)
) ;

CREATE TABLE assayRunAttNames (
  arAttNameId int(10) NOT NULL auto_increment,
  arName varchar(255) default NULL,
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,arAttNameId),
  UNIQUE KEY arNameIdx (state,arName)
) ;

CREATE TABLE assayRunAttValues (
  arAttValueId int(10) NOT NULL auto_increment,
  arValue text,
  arSha1 char(40) default NULL,
  state int(11) NOT NULL default '0',
  PRIMARY KEY  (state,arAttValueId),
  UNIQUE KEY arSha1Unique (state,arSha1),
  KEY arValueIdx (state,arValue(255))
) ;




