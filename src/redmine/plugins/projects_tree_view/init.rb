require 'redmine'

require 'projects_tree_view_projects_helper_patch'

# Patches to the Redmine core.
Rails.configuration.to_prepare do
  require_dependency 'projects_helper'
  ProjectsHelper.send(:include, ProjectsTreeView::ProjectsHelperPatch)
end

Redmine::Plugin.register :projects_tree_view do
  name 'Projects Tree View plugin'
  author 'Chris Peterson and Github community'
  description 'This is a Redmine plugin which will turn the projects page into a tree view'
  url 'https://github.com/cforce/projects_tree_view'
  version '0.0.8'
  requires_redmine :version_or_higher => '2.1.0'
end
