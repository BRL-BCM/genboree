require 'brl/util/util'

module PluginHelpers
  module BeforeFiltersHelper
    # ----------------------------------------------------------------
    # BEFORE_FILTERS - useful before_filter methods for your controller
    # ----------------------------------------------------------------

    # Retrieve the project-specific plugin settings record.
    # @note Assume the Controller defines PLUGIN_SETTINGS_MODEL_CLASS.
    # @return [Object] An instance of the plugin model settings for the current project
    #   with access to any project-specific settings for this plugin.
    def plugin_proj_settings()
      @pluginProjSettings = nil
      if(defined?(self.class::PLUGIN_SETTINGS_MODEL_CLASS))
        #$stderr.debugPuts(__FILE__, __method__, '++++++ DEBUG', "Have model class: #{self.class::PLUGIN_SETTINGS_MODEL_CLASS.inspect}")
        @pluginProjSettings = self.class::PLUGIN_SETTINGS_MODEL_CLASS.find_by_project_id(@project) # rescue nil
      end
      @pluginProjSettings
    end
  end
end
