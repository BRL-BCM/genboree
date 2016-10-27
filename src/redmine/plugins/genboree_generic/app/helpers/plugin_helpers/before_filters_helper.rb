require 'brl/util/util'

module PluginHelpers
  module BeforeFiltersHelper
    # ----------------------------------------------------------------
    # BEFORE_FILTERS - useful before_filter methods for your controller
    # ----------------------------------------------------------------

    # Retrieve the project-specific plugin settings record.
    # @note Assume the Controller defines PLUGIN_SETTINGS_MODEL_CLASS.
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
  end
end
