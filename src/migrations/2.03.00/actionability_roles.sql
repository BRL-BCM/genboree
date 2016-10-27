
USE redmine;

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
