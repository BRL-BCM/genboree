
USE redmine;

INSERT INTO `custom_fields`(`type`,`name`,`field_format`,`possible_values`,`regexp`,`min_length`,`max_length`,`is_required`,`is_for_all`,`is_filter`
,`position`,`searchable`,`default_value`,`editable`,`visible`,`multiple`) VALUES ('ProjectCustomField','List Project if Public?','bool',NULL,'',0,0,1,0,1,2,0,0,1,1,0);
