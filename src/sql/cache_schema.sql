
CREATE DATABASE `cache` DEFAULT CHARACTER SET latin1 DEFAULT COLLATE latin1_general_cs;

USE `cache`;

CREATE TABLE apiRespCache (
  id char(32) NOT NULL,
  rsrcPath text NOT NULL,
  versionId varchar(255) NOT NULL,
  content longblob NOT NULL,
  secKey text,
  recordDate timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=MyISAM;
GRANT ALL PRIVILEGES ON cache.* TO 'genboree'@'localhost' ;
