    
CREATE USER 'genboree'@'localhost' IDENTIFIED BY 'genboree';
GRANT ALL PRIVILEGES          ON *.* TO 'genboree'@'localhost' WITH GRANT OPTION ;
GRANT SHOW DATABASES          ON *.* TO 'genboree'@'localhost' ;
GRANT LOCK TABLES             ON *.* TO 'genboree'@'localhost' ;
GRANT CREATE TEMPORARY TABLES ON *.* to 'genboree'@'localhost' ;
FLUSH PRIVILEGES;

/*
CREATE USER 'genbadmin'@'%' IDENTIFIED BY 'temp';
GRANT ALL PRIVILEGES          ON *.* TO 'genbadmin'@'%' WITH GRANT OPTION ;
GRANT SHOW DATABASES          ON *.* TO 'genbadmin'@'%' ;
GRANT LOCK TABLES             ON *.* TO 'genbadmin'@'%' ;
GRANT CREATE TEMPORARY TABLES ON *.* to 'genbadmin'@'%' ;
FLUSH PRIVILEGES;
*/

