#!/usr/bin/env ruby

module RegisterClinGenUserSettingsHook
  class Hooks < Redmine::Hook::ViewListener
    def helper_projects_settings_tabs(context = {})
      context[:tabs].push({ :name    => :clingen_resource_settings,
                            :action  => :new,
                            :partial => 'projects/settings/clingen_resource_settings',
                            :label   => :clingen_resource_settings_label})
    end
  end
end
