
USE redmine;


INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('login_required'  ,'1', NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('rest_api_enabled','1', NOW());


INSERT INTO tokens(id,user_id,action,value,created_on) VALUES ( 1,1,'feeds','682c7a53797493d7440c34f95ca02a113cf322df','2014-10-01 14:11:40' );
INSERT INTO tokens(id,user_id,action,value,created_on) VALUES ( 2,1,'api'  ,'779665443f782f5f670a5e3ae69874a78607cdc0','2014-10-02 13:52:12' );


--
-- Dumping data for table `enabled_modules`
--

INSERT INTO `enabled_modules`(id,project_id,name) VALUES 
(1,1,'files'),
(2,1,'wiki'),
(6,1,'wiki_extensions');

--
-- Dumping data for table `projects`
--

INSERT INTO `projects` VALUES 
(1,'Genboree Website Content','\r\n+NOTE:+ This project is for managing the +content+ of the sections/pages of the landing page.\r\n* Many dedicated content pages here _have specific formats/instructions_\r\n** Don''t change Wiki page content or change Wiki page names unless you are familiar with the CMS.\r\n* [[genboree-website-info:|Looking for instructions?]]\r\n\r\nh3. Key Content Areas\r\n\r\nThere are dedicated tabs to the pre-defined / well-known wiki content pages.\r\n* @Wiki@ (Menu), @News@, @Events@, @Image@, @Publications@\r\n* @Files@ is the usual Redmine Files module.\r\n\r\nAdditional arbitrary landing page section/page content appears in non-pre-defined wiki pages you add and link to the menu or wherever.\r\n\r\n\r\n','',1,NULL,'2014-07-03 15:32:44','2014-08-13 18:19:38','genboree_website_content',1,3,4,0);


--
-- Dumping data for table `projects_trackers`
--

INSERT INTO `projects_trackers`(project_id,tracker_id) VALUES (1,1),(1,2);

--
-- WEBSITE CONTENT
--

INSERT INTO `wikis`(id,project_id,start_page,status) VALUES (1,1,'Menu',1);

