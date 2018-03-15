require 'brl/util/util'

module PluginHelpers
  module BeforeFiltersHelper
    # ----------------------------------------------------------------
    # BEFORE_FILTERS - useful before_filter methods for your controller
    # ----------------------------------------------------------------

    # Retrieve the project-specific plugin settings record.
    # @note Assumes the Controller defines PLUGIN_SETTINGS_MODEL_CLASS.
    # @param [Project] project Optional. Defaults to @project when used within controller. To support settings
    #   must hand in Project object. 
    # @param [Class] settingsClass Optional. Not needed in controller, since will use PLUGIN_SETTINGS_MODEL_CLASS defined in your controller.
    #    To support settings  must hand in settings class/model.
    # @return [Object] An instance of the plugin model settings for the current project
    #   with access to any project-specific settings for this plugin.
    def plugin_proj_settings(project=@project, settingsClass=nil)
      if(settingsClass.nil?) # then within controller _instance_ and can get class from controller
        settingsClass = ( defined?(self.class::PLUGIN_SETTINGS_MODEL_CLASS) ? self.class::PLUGIN_SETTINGS_MODEL_CLASS : nil )
      end
      @pluginProjSettings = nil
      if(settingsClass)
        #$stderr.debugPuts(__FILE__, __method__, '++++++ DEBUG', "Have model class: #{self.class::PLUGIN_SETTINGS_MODEL_CLASS.inspect}")
        @pluginProjSettings = settingsClass.find_by_project_id(project) # rescue nil
      else
        $stderr.debugPuts(__FILE__, __method__, 'WARNING', "Either this *plugin* controller (#{self.class.inspect}) does not define PLUGIN_SETTINGS_MODEL_CLASS or we're not in a controller / instance context (e.g. project-settings) and the appropriate settings class was not passed in.")
      end
      @pluginProjSettings
    end

    def enforce_approved_project( approvedProjects, project, plugin )
      approved = false
      projToCheck = ( project.is_a?(Project) ? project : Project.find( project) ) rescue nil
      plugin = Redmine::Plugin.find( plugin ) unless( plugin.is_a?( Redmine::Plugin ) )
      if(projToCheck)
        # Check against each of the approvdedProjects
        approved = approvedProjects.any? { |approvedProject|
          approvedProject = Project.find( approvedProject) unless( approvedProject.is_a?(Project) )
          ( projToCheck == approvedProject )
        }
      end

      if( approved ) # Either user allowed or project is public
        true
      else # project is not one of the approved projects
        flash.now[:warning] = "<b>NOTICE:</b> The project <em>&quot;#{projToCheck.name}&quot;</em> has not been pre-approved to employ the <em>&quot;#{plugin.name}&quot;</em> plugin. For security and privacy reasons, the plugin cannot be employed in this project without Administrator approval."
        deny_access
      end
    end
  end
end
