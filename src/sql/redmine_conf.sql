
USE redmine;


INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('app_title'               ,'GENBOREE REDMINE'  , NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('emails_subject_prefix'   ,'GENBOREE REDMINE: ', NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('host_name'               ,'localhost/redmine' , NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('attachment_max_size'     ,20971520            , NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('self_registration'       ,0                   , NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('autologin'               ,0                   , NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('unsubscribe'             ,0                   , NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('ui_theme'                ,'redminecrm'        , NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('user_format'             ,'lastname_firstname', NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('default_projects_modules','--- 
- documents
- wiki
- boards
- calendar
- gantt
', NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('default_projects_tracker_ids','--- []

', NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('sequential_project_identifiers','0', NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('default_projects_public'       ,'0', NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('new_project_user_role_id'      ,'3', NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('plugin_genboree_customizations','--- !map:ActiveSupport::HashWithIndifferentAccess \nsignin_msg: |-\n  You must be a registered Genboree Workbench user to use the Redmine.\r\n  <br>\r\n  Please log-in with your Workbench credentials.\nmain_gb_url: \"\"\nno_stats_hosts: \"\"\nforgot_pw_url: /java-bin/forgotten.jsp\n', NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('login_required'                ,0  , NOW());
INSERT INTO `settings`(`name`,`value`,`updated_on`) VALUES ('rest_api_enabled'              ,1  , NOW());


DELETE FROM `issue_statuses`;
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES ( 1,'New'           ,0,1, 1,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES ( 2,'Assigned'      ,0,0, 2,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES ( 3,'Acknowledged'  ,0,0, 3,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES ( 4,'Confirmed'     ,0,0, 4,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES ( 5,'Escalated'     ,0,0, 5,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES ( 6,'Resolved'      ,0,0, 6,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES ( 7,'Feedback'      ,0,0, 7,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES ( 8,'Deferred'      ,0,0, 8,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES ( 9,'Deployed'      ,1,0, 9,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES (10,'Closed'        ,1,0,10,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES (11,'Rejected'      ,1,0,11,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES (12,'Approved-Final',1,0,12,NULL);
INSERT INTO `issue_statuses`(`id`,`name`,`is_closed`,`is_default`,`position`,`default_done_ratio`) VALUES (13,'Re-open'       ,0,0,13,NULL);


UPDATE `trackers` SET `is_in_roadmap`=1;


INSERT INTO `custom_fields`(`type`,`name`,`field_format`,`possible_values`,`regexp`,`min_length`,`max_length`,`is_required`,`is_for_all`,`is_filter`
,`position`,`searchable`,`default_value`,`editable`,`visible`,`multiple`) VALUES ('IssueCustomField','Tags','string',NULL,'',1,0,0,0,1,1,1,NULL,1,1,0);
INSERT INTO `custom_fields`(`type`,`name`,`field_format`,`possible_values`,`regexp`,`min_length`,`max_length`,`is_required`,`is_for_all`,`is_filter`
,`position`,`searchable`,`default_value`,`editable`,`visible`,`multiple`) VALUES ('ProjectCustomField','Google Calendar','text',NULL,'',0,0,0,0,0,1,0,NULL,1,0,0);
INSERT INTO `custom_fields`(`type`,`name`,`field_format`,`possible_values`,`regexp`,`min_length`,`max_length`,`is_required`,`is_for_all`,`is_filter`
,`position`,`searchable`,`default_value`,`editable`,`visible`,`multiple`) VALUES ('ProjectCustomField','List Project if Public?','bool',NULL,'',0,0,1,0,1,2,0,0,1,1,0);

-- update roles
UPDATE `roles` SET `permissions`='--- 
- :view_documents
- :view_files
- :view_issues
- :view_wiki_pages
- :edit_wiki_pages
' WHERE `name`='Non member';

UPDATE `roles` SET `permissions`='--- 
- :view_documents
- :view_files
- :view_wiki_pages
' WHERE `name`='Anonymous';

UPDATE `roles` SET `permissions`='--- 
- :view_activity
- :add_project
- :edit_project
- :close_project
- :select_project_modules
- :manage_members
- :manage_versions
- :add_subprojects
- :manage_categories
- :view_issues
- :add_issues
- :edit_issues
- :manage_issue_relations
- :manage_subtasks
- :set_issues_private
- :set_own_issues_private
- :add_issue_notes
- :edit_issue_notes
- :edit_own_issue_notes
- :view_private_notes
- :set_notes_private
- :move_issues
- :delete_issues
- :manage_public_queries
- :save_queries
- :view_issue_watchers
- :add_issue_watchers
- :delete_issue_watchers
- :log_time
- :view_time_entries
- :edit_time_entries
- :edit_own_time_entries
- :manage_project_activities
- :manage_news
- :comment_news
- :add_documents
- :edit_documents
- :delete_documents
- :view_documents
- :manage_files
- :view_files
- :manage_wiki
- :rename_wiki_pages
- :delete_wiki_pages
- :view_wiki_pages
- :export_wiki_pages
- :view_wiki_edits
- :edit_wiki_pages
- :delete_wiki_pages_attachments
- :protect_wiki_pages
- :manage_repository
- :browse_repository
- :view_changesets
- :commit_access
- :manage_related_issues
- :manage_boards
- :add_messages
- :edit_messages
- :edit_own_messages
- :delete_messages
- :delete_own_messages
- :view_calendar
- :view_gantt
- :view_google_calendar_tab
- :view_checklists
- :done_checklists
- :edit_checklists
- :add_wiki_comment
- :delete_wiki_comments
- :edit_wiki_comments
- :wiki_extensions_settings
- :view_genboree_kbs
- :create_genboree_kbs
- :update_genboree_kbs
' WHERE `name`='Manager';

UPDATE `roles` SET `permissions`='--- 
- :view_activity
- :add_subprojects
- :add_messages
- :edit_own_messages
- :delete_own_messages
- :view_calendar
- :add_documents
- :edit_documents
- :delete_documents
- :view_documents
- :manage_files
- :view_files
- :view_gantt
- :view_google_calendar_tab
- :view_issues
- :add_issues
- :edit_issues
- :manage_subtasks
- :add_issue_notes
- :edit_issue_notes
- :edit_own_issue_notes
- :view_private_notes
- :set_notes_private
- :manage_public_queries
- :view_issue_watchers
- :add_issue_watchers
- :delete_issue_watchers
- :comment_news
- :log_time
- :view_time_entries
- :edit_own_time_entries
- :rename_wiki_pages
- :view_wiki_pages
- :export_wiki_pages
- :view_wiki_edits
- :edit_wiki_pages
- :protect_wiki_pages
- :add_wiki_comment
- :edit_wiki_comments
- :view_genboree_kbs
- :create_genboree_kbs
- :update_genboree_kbs
' WHERE `name`='Developer';

UPDATE `roles` SET `permissions`='--- 
- :view_activity
- :add_messages
- :edit_own_messages
- :view_calendar
- :view_documents
- :view_files
- :view_gantt
- :view_google_calendar_tab
- :view_issues
- :add_issues
- :add_issue_notes
- :edit_own_issue_notes
- :view_issue_watchers
- :view_wiki_pages
- :view_wiki_edits
- :view_genboree_kbs
' WHERE `name`='Reporter';

-- add roles for actionability
INSERT INTO `roles` (`name`,`position`,`assignable`,`builtin`,`permissions`,`issues_visibility`) VALUES ('AC Scorer',6,1,0,'--- 
- :add_project
- :view_calendar
- :view_documents
- :view_files
- :gbac_view_sencha
- :gbac_view_entry
- :gbac_view_full_view
- :gbac_view_stg1_rule_out_report
- :gbac_view_stg2_summary_report
- :gbac_view_curation
- :gbac_view_scoring
- :gbac_edit_syndrome_info
- :gbac_edit_scoring
- :view_genboree_kbs
- :gbrc_view
- :view_issues
- :view_wiki_pages
','default');
INSERT INTO `roles` (`name`,`position`,`assignable`,`builtin`,`permissions`,`issues_visibility`) VALUES ('AC Consensus Scorer',7,1,0,'--- 
- :add_project
- :view_calendar
- :view_documents
- :view_files
- :gbac_view_sencha
- :gbac_view_entry
- :gbac_view_full_view
- :gbac_view_stg1_rule_out_report
- :gbac_view_stg2_summary_report
- :gbac_view_curation
- :gbac_view_stage1
- :gbac_view_scoring
- :gbac_edit_doc_status_info
- :gbac_edit_doc_release
- :gbac_finalize_lit_search
- :gbac_edit_stage1
- :gbac_edit_final_stage1
- :gbac_finalize_stage1
- :gbac_edit_scoring
- :gbac_edit_final_scores
- :gbac_finalize_scoring
- :gbac_rollback_completion
- :view_genboree_kbs
- :gbrc_view
- :view_issues
- :view_wiki_pages
','default');
INSERT INTO `roles` (`name`,`position`,`assignable`,`builtin`,`permissions`,`issues_visibility`) VALUES ('AC KST',8,1,0,'--- 
- :add_project
- :view_calendar
- :view_documents
- :view_files
- :gbac_view_sencha
- :gbac_view_entry
- :gbac_view_full_view
- :gbac_view_stg1_rule_out_report
- :gbac_view_stg2_summary_report
- :gbac_view_curation
- :gbac_view_lit_search
- :gbac_view_stage1
- :gbac_view_stage2
- :gbac_view_scoring
- :gbac_edit_syndrome_info
- :gbac_edit_doc_status_info
- :gbac_edit_doc_release
- :gbac_edit_lit_search
- :gbac_edit_stage1
- :gbac_edit_stage2
- :gbac_finalize_stage2
- :view_genboree_kbs
- :gbrc_view
- :view_issues
- :view_wiki_pages
','default');



DELETE FROM `workflows`;
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,1,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,2,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,2,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,2,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,2,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,2,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,2,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,2,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,2,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,2,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,2,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,3,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,3,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,3,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,3,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,3,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,3,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,3,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,3,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,3,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,3,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,4,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,4,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,4,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,4,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,4,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,4,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,4,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,4,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,4,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,5,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,5,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,5,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,5,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,5,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,5,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,5,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,5,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,5,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,5,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,6,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,6,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,6,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,6,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,6,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,6,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,7,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,8,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,8,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,8,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,8,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,8,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,8,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,8,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,8,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,8,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,9,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,9,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,9,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,9,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,10,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,10,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,10,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,10,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,11,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,11,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,11,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,11,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,11,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,11,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,12,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,3,13,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,1,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,2,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,2,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,2,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,2,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,2,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,2,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,2,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,3,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,3,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,3,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,3,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,3,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,3,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,4,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,4,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,4,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,4,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,4,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,5,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,5,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,5,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,5,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,5,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,5,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,6,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,6,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,6,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,7,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,7,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,7,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,7,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,7,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,7,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,7,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,8,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,8,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,9,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,9,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,10,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,10,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,10,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,11,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,11,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,13,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,13,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,13,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,13,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,13,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,13,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,4,13,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,2,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,2,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,2,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,2,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,2,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,3,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,3,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,3,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,3,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,4,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,4,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,4,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,5,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,5,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,5,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,5,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,6,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,7,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,7,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,7,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,7,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,8,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,8,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,8,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,9,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,10,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (1,5,11,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,1,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,2,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,2,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,2,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,2,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,2,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,2,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,2,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,2,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,2,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,2,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,3,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,3,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,3,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,3,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,3,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,3,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,3,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,3,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,3,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,3,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,4,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,4,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,4,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,4,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,4,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,4,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,4,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,4,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,4,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,5,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,5,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,5,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,5,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,5,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,5,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,5,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,5,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,5,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,5,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,6,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,6,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,6,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,6,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,6,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,6,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,7,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,8,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,8,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,8,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,8,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,8,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,8,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,8,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,8,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,8,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,9,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,9,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,9,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,9,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,10,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,10,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,10,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,10,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,11,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,11,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,11,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,11,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,11,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,11,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,12,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,3,13,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,1,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,2,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,2,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,2,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,2,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,2,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,2,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,2,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,3,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,3,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,3,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,3,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,3,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,3,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,4,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,4,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,4,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,4,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,4,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,5,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,5,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,5,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,5,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,5,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,5,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,6,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,6,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,6,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,7,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,7,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,7,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,7,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,7,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,7,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,7,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,8,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,8,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,9,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,9,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,10,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,10,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,10,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,11,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,11,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,13,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,13,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,13,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,13,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,13,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,13,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,4,13,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,2,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,2,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,2,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,2,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,2,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,3,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,3,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,3,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,3,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,4,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,4,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,4,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,5,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,5,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,5,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,5,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,6,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,7,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,7,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,7,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,7,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,8,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,8,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,8,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,9,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,10,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (2,5,11,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,1,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,2,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,2,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,2,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,2,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,2,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,2,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,2,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,2,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,2,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,2,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,3,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,3,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,3,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,3,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,3,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,3,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,3,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,3,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,3,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,3,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,4,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,4,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,4,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,4,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,4,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,4,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,4,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,4,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,4,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,5,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,5,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,5,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,5,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,5,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,5,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,5,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,5,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,5,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,5,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,6,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,6,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,6,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,6,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,6,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,6,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,7,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,8,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,8,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,8,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,8,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,8,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,8,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,8,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,8,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,8,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,9,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,9,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,9,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,9,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,10,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,10,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,10,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,10,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,11,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,11,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,11,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,11,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,11,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,11,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,12,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,11, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,8, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,2, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,3,13,12, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,1,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,2,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,2,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,2,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,2,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,2,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,2,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,2,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,3,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,3,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,3,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,3,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,3,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,3,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,4,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,4,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,4,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,4,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,4,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,5,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,5,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,5,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,5,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,5,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,5,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,6,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,6,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,6,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,7,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,7,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,7,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,7,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,7,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,7,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,7,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,8,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,8,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,9,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,9,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,10,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,10,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,10,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,11,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,11,13, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,13,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,13,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,13,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,13,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,13,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,13,9, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,4,13,10, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,2,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,2,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,2,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,2,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,2,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,3,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,3,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,3,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,3,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,4,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,4,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,4,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,5,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,5,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,5,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,5,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,6,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,7,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,7,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,7,4, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,7,3, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,8,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,8,6, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,8,5, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,9,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,10,7, 0, 0, 'WorkflowTransition');
INSERT INTO `workflows`(`tracker_id`,`role_id`,`old_status_id`,`new_status_id`,`assignee`,`author`,`type`) VALUES (3,5,11,7, 0, 0, 'WorkflowTransition');




