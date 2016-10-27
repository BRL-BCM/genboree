use genboree;
create table if not exists gbToRmMaps (
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
