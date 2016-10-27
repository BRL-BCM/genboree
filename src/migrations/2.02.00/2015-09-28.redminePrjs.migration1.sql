
--
-- svn://histidine.brl.bcmd.bcm.edu/brl-repo/PATCH_NOTES/migrations/db/2015-09-28.redminePrjs.migration1.sql
--

CREATE TABLE IF NOT EXISTS redminePrjs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  group_id INT,
  project_id VARCHAR(255) UNIQUE KEY,
  url VARCHAR(255)
) ENGINE=MyISAM AUTO_INCREMENT=1000001;
