CREATE DATABASE cache ;
USE cache ;
CREATE TABLE apiRespCache (
  id char(32) NOT NULL,
  rsrcPath text NOT NULL,
  versionId varchar(255) NOT NULL,
  content longblob NOT NULL,
  secKey text,
  recordDate timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 ;
GRANT ALL PRIVILEGES ON cache.* TO 'genboree'@'localhost' ;
