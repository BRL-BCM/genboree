
USE `prequeue`;

INSERT INTO systems(id, type, host, adminEmails) VALUES(2, 'GenboreeUtilityJob', 'localhost', 'Piotr.Pawliczek@bcm.edu');
INSERT INTO systems(id, TYPE, HOST, adminEmails) VALUES(4, 'LocalHost'         , 'localhost', 'Piotr.Pawliczek@bcm.edu');


USE `genboree`;

-- --------------------------------------------------------------------------
-- PRIME GENBOREEGROUP TABLE
-- --------------------------------------------------------------------------
INSERT INTO genboreegroup(groupId,groupName,description,student) VALUES (3,'Public','A group that has access to publicly accessable refseqs',0);
INSERT INTO genboreegroup(groupId,groupName,description,student) VALUES (4,'genbadmin','Genbadmin group',0);
INSERT INTO genboreegroup(groupId,groupName,description,student) VALUES (18,'libraryFeatures','Group for Templates',2);

-- --------------------------------------------------------------------------
-- PRIME GENBOREEUSER TABLE
-- --------------------------------------------------------------------------
INSERT INTO genboreeuser(userId,name,password,firstName,lastName,institution,email,phone) VALUES (7,'genbadmin','genbadmin','Genboree','Administrator Account','', 'Piotr.Pawliczek@bcm.edu','');
INSERT INTO genboreeuser(userId,name,password,firstName,lastName,institution,email,phone) VALUES (112,'public',NULL,NULL,NULL,'UNKNOWN',NULL,NULL);
-- system users
INSERT INTO genboreeuser(userId,name,password,firstName,lastName,institution,email,phone) VALUES (1001,'gbPublicToolUser','X9dEGVs8d3r',NULL,NULL,'System User',NULL,NULL);
INSERT INTO genboreeuser(userId,name,password,firstName,lastName,institution,email,phone) VALUES (1002,'gbCacheUser'     ,'X9dEGVs8d3r',NULL,NULL,'System User',NULL,NULL);

-- --------------------------------------------------------------------------
-- PRIME USERGROUP TABLE
-- --------------------------------------------------------------------------
INSERT INTO usergroup(userGroupId,groupId,userId,userGroupAccess,permissionBits) VALUES (2683,4,7,'o',0);
INSERT INTO usergroup(userGroupId,groupId,userId,userGroupAccess,permissionBits) VALUES (3140,18,7,'o',0);
INSERT INTO usergroup(userGroupId,groupId,userId,userGroupAccess,permissionBits) VALUES (730,3,7,'r',0);

-- searchConfig
INSERT INTO searchConfig(scid,ucscOrg,ucscDbName,ucscHgsid,epPrefix,epSuffix) VALUES ( 1,NULL,NULL,NULL,'','' );

-- unlockedGroupResources
INSERT INTO unlockedGroupResources(id,group_id,resourceType,resource_id,unlockKey,resourceUriDigest,resourceUri,public) VALUES ( 38,0,'ui',0,'TNkdABu0','59061f7fea141f16f69c1e2bb0c3b05cb8901646','/REST/v1/genboree/ui',0 );
INSERT INTO unlockedGroupResources(id,group_id,resourceType,resource_id,unlockKey,resourceUriDigest,resourceUri,public) VALUES ( 39,0,'rsrc',0,'TNkdABu0','98129dd6b0668fb1fd3016621d51a59a847b2a97','/REST/v1/resources/plainTexts',0 );
INSERT INTO unlockedGroupResources(id,group_id,resourceType,resource_id,unlockKey,resourceUriDigest,resourceUri,public) VALUES ( 47,0,'shortUrl',0,'xng7hi','aaf89c3a843bdd22acece4bd51b0c30943e1cf50','/REST/v1/shortUrl',0 );
INSERT INTO unlockedGroupResources(id,group_id,resourceType,resource_id,unlockKey,resourceUriDigest,resourceUri,public) VALUES ( 58,0,'digest',0,'xng7hi','cc845d7e0ecaafbeeaba20354e08fd7b7f3063b2','/REST/v1/digest',0 );
INSERT INTO unlockedGroupResources(id,group_id,resourceType,resource_id,unlockKey,resourceUriDigest,resourceUri,public) VALUES ( 73,0,'menu',0,'rektjxdd','fa99dc0f6dc3b01b18c9a513cfc01c9905440b98','/REST/v1/genboree/ui/menu',0 );

-- style
INSERT INTO style(styleId,name,description) VALUES ( 1,'simple_draw','Simple Rectangle' );
INSERT INTO style(styleId,name,description) VALUES ( 2,'bes_draw','Paired-End' );
INSERT INTO style(styleId,name,description) VALUES ( 3,'cdna_draw','Boxed Group' );
INSERT INTO style(styleId,name,description) VALUES ( 4,'gene_draw','Line-Linked' );
INSERT INTO style(styleId,name,description) VALUES ( 5,'tag_draw','Anchored Arrows' );
INSERT INTO style(styleId,name,description) VALUES ( 6,'singleFos_draw','Half Paired-End' );
INSERT INTO style(styleId,name,description) VALUES ( 7,'scoreBased_draw','Global Score Barchart (small)' );
INSERT INTO style(styleId,name,description) VALUES ( 8,'barbed_wire_draw','Barbed-Wire Rectangle' );
INSERT INTO style(styleId,name,description) VALUES ( 9,'chromosome_draw','Label Within Rectangle' );
INSERT INTO style(styleId,name,description) VALUES ( 10,'largeScore_draw','Global Score Barchart (big)' );
INSERT INTO style(styleId,name,description) VALUES ( 11,'negative_draw','Simple Rectangle With Gaps' );
INSERT INTO style(styleId,name,description) VALUES ( 12,'groupNeg_draw','Line-Linked With Gaps' );
INSERT INTO style(styleId,name,description) VALUES ( 13,'fadeToWhite_draw','Score Colored (fade to white)' );
INSERT INTO style(styleId,name,description) VALUES ( 14,'fadeToGray_draw','Score Colored (fade to gray)' );
INSERT INTO style(styleId,name,description) VALUES ( 15,'fadeToBlack_draw','Score Colored (fade to black)' );
INSERT INTO style(styleId,name,description) VALUES ( 16,'differentialGradient_draw','Score Colored (fixed colors)' );
INSERT INTO style(styleId,name,description) VALUES ( 17,'barbed_wire_noLine_draw','Barbed-Wire Rectangle (no lines)' );
INSERT INTO style(styleId,name,description) VALUES ( 18,'pieChart_draw','Score Pie Chart' );
INSERT INTO style(styleId,name,description) VALUES ( 19,'local_scoreBased_draw','Local Score Barchart (small)' );
INSERT INTO style(styleId,name,description) VALUES ( 20,'local_largeScore_draw','Local Score Barchart (big)' );
INSERT INTO style(styleId,name,description) VALUES ( 21,'sequence_draw','Line-Linked with Sequence' );
INSERT INTO style(styleId,name,description) VALUES ( 23,'bidirectional_draw_large','Global Bidirectional Barchart' );
INSERT INTO style(styleId,name,description) VALUES ( 24,'bidirectional_local_draw_large','Local Bidirectional Barchart' );

-- color
INSERT INTO color(colorId,value) VALUES ( 1,'#996600' );
INSERT INTO color(colorId,value) VALUES ( 2,'#666600' );
INSERT INTO color(colorId,value) VALUES ( 3,'#99991E' );
INSERT INTO color(colorId,value) VALUES ( 4,'#CC0000' );
INSERT INTO color(colorId,value) VALUES ( 5,'#FF0000' );
INSERT INTO color(colorId,value) VALUES ( 6,'#FF00CC' );
INSERT INTO color(colorId,value) VALUES ( 7,'#FFCCCC' );
INSERT INTO color(colorId,value) VALUES ( 8,'#FF9900' );
INSERT INTO color(colorId,value) VALUES ( 9,'#FFCC00' );
INSERT INTO color(colorId,value) VALUES ( 10,'#FFFF00' );
INSERT INTO color(colorId,value) VALUES ( 11,'#CCFF00' );
INSERT INTO color(colorId,value) VALUES ( 12,'#00FF00' );
INSERT INTO color(colorId,value) VALUES ( 13,'#358000' );
INSERT INTO color(colorId,value) VALUES ( 14,'#0000CC' );
INSERT INTO color(colorId,value) VALUES ( 15,'#6699FF' );
INSERT INTO color(colorId,value) VALUES ( 16,'#99CCFF' );
INSERT INTO color(colorId,value) VALUES ( 17,'#00FFFF' );
INSERT INTO color(colorId,value) VALUES ( 18,'#CCFFFF' );
INSERT INTO color(colorId,value) VALUES ( 19,'#9900CC' );
INSERT INTO color(colorId,value) VALUES ( 20,'#CC33FF' );
INSERT INTO color(colorId,value) VALUES ( 21,'#CC99FF' );
INSERT INTO color(colorId,value) VALUES ( 22,'#666666' );
INSERT INTO color(colorId,value) VALUES ( 23,'#999999' );
INSERT INTO color(colorId,value) VALUES ( 24,'#CCCCCC' );
INSERT INTO color(colorId,value) VALUES ( 25,'#CCCC99' );
INSERT INTO color(colorId,value) VALUES ( 26,'#79CC3D' );
INSERT INTO color(colorId,value) VALUES ( 27,'#F14041' );
INSERT INTO color(colorId,value) VALUES ( 28,'#F7B0B4' );
INSERT INTO color(colorId,value) VALUES ( 29,'#F48A99' );
INSERT INTO color(colorId,value) VALUES ( 30,'#960046' );
INSERT INTO color(colorId,value) VALUES ( 31,'#F7AFD0' );
INSERT INTO color(colorId,value) VALUES ( 32,'#F387BC' );
INSERT INTO color(colorId,value) VALUES ( 33,'#F20079' );
INSERT INTO color(colorId,value) VALUES ( 34,'#B3005A' );
INSERT INTO color(colorId,value) VALUES ( 35,'#970066' );
INSERT INTO color(colorId,value) VALUES ( 36,'#F200A5' );
INSERT INTO color(colorId,value) VALUES ( 37,'#B4007B' );
INSERT INTO color(colorId,value) VALUES ( 38,'#82007E' );
INSERT INTO color(colorId,value) VALUES ( 39,'#6D0069' );
INSERT INTO color(colorId,value) VALUES ( 40,'#AB0EA8' );
INSERT INTO color(colorId,value) VALUES ( 41,'#FF00FF' );
INSERT INTO color(colorId,value) VALUES ( 42,'#BC7BBD' );
INSERT INTO color(colorId,value) VALUES ( 43,'#CDA2CE' );
INSERT INTO color(colorId,value) VALUES ( 44,'#680080' );
INSERT INTO color(colorId,value) VALUES ( 45,'#54006B' );
INSERT INTO color(colorId,value) VALUES ( 46,'#8730AA' );
INSERT INTO color(colorId,value) VALUES ( 47,'#A176BC' );
INSERT INTO color(colorId,value) VALUES ( 48,'#B99CCD' );
INSERT INTO color(colorId,value) VALUES ( 49,'#430081' );
INSERT INTO color(colorId,value) VALUES ( 50,'#30006C' );
INSERT INTO color(colorId,value) VALUES ( 51,'#583BAA' );
INSERT INTO color(colorId,value) VALUES ( 52,'#A597CD' );
INSERT INTO color(colorId,value) VALUES ( 53,'#8173BB' );
INSERT INTO color(colorId,value) VALUES ( 54,'#0000FF' );
INSERT INTO color(colorId,value) VALUES ( 55,'#A0A7D7' );
INSERT INTO color(colorId,value) VALUES ( 56,'#7A8AC8' );
INSERT INTO color(colorId,value) VALUES ( 57,'#9BB7E2' );
INSERT INTO color(colorId,value) VALUES ( 58,'#003677' );
INSERT INTO color(colorId,value) VALUES ( 59,'#2C6AB9' );
INSERT INTO color(colorId,value) VALUES ( 60,'#104C8E' );
INSERT INTO color(colorId,value) VALUES ( 61,'#6CA0D7' );
INSERT INTO color(colorId,value) VALUES ( 62,'#005181' );
INSERT INTO color(colorId,value) VALUES ( 63,'#0088CC' );
INSERT INTO color(colorId,value) VALUES ( 64,'#00659B' );
INSERT INTO color(colorId,value) VALUES ( 65,'#8FD8F9' );
INSERT INTO color(colorId,value) VALUES ( 66,'#00BBF3' );
INSERT INTO color(colorId,value) VALUES ( 67,'#008FB9' );
INSERT INTO color(colorId,value) VALUES ( 68,'#00789A' );
INSERT INTO color(colorId,value) VALUES ( 69,'#00CAF6' );
INSERT INTO color(colorId,value) VALUES ( 70,'#3DCCC6' );
INSERT INTO color(colorId,value) VALUES ( 71,'#00BEB5' );
INSERT INTO color(colorId,value) VALUES ( 72,'#009189' );
INSERT INTO color(colorId,value) VALUES ( 73,'#007972' );
INSERT INTO color(colorId,value) VALUES ( 74,'#98DAD6' );
INSERT INTO color(colorId,value) VALUES ( 75,'#009259' );
INSERT INTO color(colorId,value) VALUES ( 76,'#00BE72' );
INSERT INTO color(colorId,value) VALUES ( 77,'#007B46' );
INSERT INTO color(colorId,value) VALUES ( 78,'#57CB95' );
INSERT INTO color(colorId,value) VALUES ( 79,'#FF6633' );
INSERT INTO color(colorId,value) VALUES ( 80,'#9BD9B4' );
INSERT INTO color(colorId,value) VALUES ( 81,'#2C9A53' );
INSERT INTO color(colorId,value) VALUES ( 82,'#51CA6D' );
INSERT INTO color(colorId,value) VALUES ( 83,'#97D691' );
INSERT INTO color(colorId,value) VALUES ( 84,'#B8E1B4' );
INSERT INTO color(colorId,value) VALUES ( 85,'#5D8838' );
INSERT INTO color(colorId,value) VALUES ( 86,'#76A44B' );
INSERT INTO color(colorId,value) VALUES ( 87,'#A5D961' );
INSERT INTO color(colorId,value) VALUES ( 88,'#BDE290' );
INSERT INTO color(colorId,value) VALUES ( 89,'#D3EAB4' );
INSERT INTO color(colorId,value) VALUES ( 90,'#9B9A00' );
INSERT INTO color(colorId,value) VALUES ( 91,'#FFFB00' );
INSERT INTO color(colorId,value) VALUES ( 92,'#BDBA00' );
INSERT INTO color(colorId,value) VALUES ( 93,'#FFFC87' );
INSERT INTO color(colorId,value) VALUES ( 94,'#FFFDB0' );
INSERT INTO color(colorId,value) VALUES ( 95,'#976D00' );
INSERT INTO color(colorId,value) VALUES ( 96,'#B88514' );
INSERT INTO color(colorId,value) VALUES ( 97,'#F8B13D' );
INSERT INTO color(colorId,value) VALUES ( 98,'#D4C5AF' );
INSERT INTO color(colorId,value) VALUES ( 99,'#FAC57A' );
INSERT INTO color(colorId,value) VALUES ( 100,'#BA9B70' );
INSERT INTO color(colorId,value) VALUES ( 101,'#FCD7A6' );
INSERT INTO color(colorId,value) VALUES ( 102,'#D3B58B' );
INSERT INTO color(colorId,value) VALUES ( 103,'#975300' );
INSERT INTO color(colorId,value) VALUES ( 104,'#7F5C32' );
INSERT INTO color(colorId,value) VALUES ( 105,'#906E45' );
INSERT INTO color(colorId,value) VALUES ( 106,'#A5845B' );
INSERT INTO color(colorId,value) VALUES ( 107,'#B0A192' );
INSERT INTO color(colorId,value) VALUES ( 108,'#B6651A' );
INSERT INTO color(colorId,value) VALUES ( 109,'#8F8378' );
INSERT INTO color(colorId,value) VALUES ( 110,'#736A62' );
INSERT INTO color(colorId,value) VALUES ( 111,'#F7AA75' );
INSERT INTO color(colorId,value) VALUES ( 112,'#FBC39D' );
INSERT INTO color(colorId,value) VALUES ( 113,'#F48740' );
INSERT INTO color(colorId,value) VALUES ( 114,'#58504D' );
INSERT INTO color(colorId,value) VALUES ( 115,'#F8B097' );
INSERT INTO color(colorId,value) VALUES ( 116,'#F48C6E' );
INSERT INTO color(colorId,value) VALUES ( 117,'#950000' );
INSERT INTO color(colorId,value) VALUES ( 118,'#B31E1E' );
INSERT INTO color(colorId,value) VALUES ( 119,'#FFCCFF' );
INSERT INTO color(colorId,value) VALUES ( 120,'#E3E3E3' );
INSERT INTO color(colorId,value) VALUES ( 121,'#D9D9D9' );
INSERT INTO color(colorId,value) VALUES ( 122,'#D0D0D0' );
INSERT INTO color(colorId,value) VALUES ( 123,'#C6C6C6' );
INSERT INTO color(colorId,value) VALUES ( 124,'#BCBCBC' );
INSERT INTO color(colorId,value) VALUES ( 125,'#B1B1B1' );
INSERT INTO color(colorId,value) VALUES ( 126,'#A7A7A7' );
INSERT INTO color(colorId,value) VALUES ( 127,'#9C9C9C' );
INSERT INTO color(colorId,value) VALUES ( 128,'#919191' );
INSERT INTO color(colorId,value) VALUES ( 129,'#858585' );
INSERT INTO color(colorId,value) VALUES ( 130,'#797979' );
INSERT INTO color(colorId,value) VALUES ( 131,'#6C6C6C' );
INSERT INTO color(colorId,value) VALUES ( 132,'#5F5F5F' );
INSERT INTO color(colorId,value) VALUES ( 133,'#515151' );
INSERT INTO color(colorId,value) VALUES ( 134,'#414141' );
INSERT INTO color(colorId,value) VALUES ( 135,'#603913' );
INSERT INTO color(colorId,value) VALUES ( 136,'#000000' );
INSERT INTO color(colorId,value) VALUES ( 137,'#005952' );
INSERT INTO color(colorId,value) VALUES ( 138,'#587B94' );
INSERT INTO color(colorId,value) VALUES ( 139,'#C69C6D' );
INSERT INTO color(colorId,value) VALUES ( 140,'#D0A89C' );
INSERT INTO color(colorId,value) VALUES ( 141,'#999966' );
INSERT INTO color(colorId,value) VALUES ( 142,'#FFCA00' );
INSERT INTO color(colorId,value) VALUES ( 143,'#B95B58' );
INSERT INTO color(colorId,value) VALUES ( 144,'#DEDBB0' );

