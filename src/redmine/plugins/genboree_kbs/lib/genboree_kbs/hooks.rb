#!/usr/bin/env ruby


module GenboreeKbs
  class Hooks < Redmine::Hook::ViewListener
    def helper_projects_settings_tabs(context = {})
      context[:tabs].push({ :name    => 'genboreeKb',
                          :action  => :genboreekb_settings,
                          :partial => 'projects/settings/project_settings',
                          :label   => :gbkb_label_project_settings_tab })
    end
  end
end
