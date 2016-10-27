require 'redmine'
require 'projects_controller_patch'
Rails.logger.info 'Starting Project Settings Hook Plugin for Redmine'

Rails.configuration.to_prepare do
    unless ProjectsHelper.included_modules.include?(SettingsProjectsHelperPatch)
        ProjectsHelper.send(:include, SettingsProjectsHelperPatch)
    end
end

Redmine::Plugin.register :project_settings_hook do
    name 'Project Settings Hook'
    author 'Andriy Lesyuk'
    author_url 'http://www.andriylesyuk.com'
    description 'Adds a hook allowing to add tabs to project settings.'
    url 'http://projects.andriylesyuk.com/projects/project-settings'
    version '0.1.0'
end
