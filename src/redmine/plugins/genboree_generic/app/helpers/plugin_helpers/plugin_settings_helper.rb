require 'brl/util/util'

module PluginHelpers
  module PluginSettingsHelper

    # Set an instance variable with this projects Active Record settings (and which fields are
    #   of interest there) in @settingsRec and @settingsFields.
    # @note Assumes the Controller defines PLUGIN_SETTINGS_MODEL_CLASS, the name of the plugin
    #   model (and thus plugin's settings table)
    # @note Assumes the Controller defines PLUGIN_PROJ_SETTINGS_FIELDS, an @Array<Symbol>@ of
    #   the settings fields available in the model
    # @note @project must be set (call find_project first)
    def find_settings(project=@project)
      klass = ( ( self.is_a?(Class) or self.is_a?(Module) ) ? self : self.class )
      settingsFields = klass::PLUGIN_PROJ_SETTINGS_FIELDS
      settingsRec = plugin_proj_settings(project, klass::PLUGIN_SETTINGS_MODEL_CLASS)
      # If instance, set instance vars
      unless( self.is_a?(Class) )
        @settingsFields, @settingsRec = settingsFields, settingsRec
      end
      return settingsFields, settingsRec
    end
  end
end
