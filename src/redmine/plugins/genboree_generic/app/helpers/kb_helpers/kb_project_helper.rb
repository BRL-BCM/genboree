
module KbHelpers
  module KbProjectHelper

    # Include the api async helper methods...if you have a kb-backed probject probably you'll
    #   be making api calls to the kb.
    include KbHelpers::KbApiAsyncHelper

    # Retrieves the project plugin settings if not already retrieved and populates
    #   common variables such as @@gbHost@, @@gbGroup@, @@gbKb@ from the settings
    # @note The plugin should use the standard column names for its main KB settings:
    #   'gbHost', 'gbGroup', 'gbKb' or (less good/uniform) provide its own field Symbols.
    # @note Uses @#PluginHelpers::BeforeFiltersHelper#plugin_proj_settings()@ to get project settings instance.
    # @param [Hash] fields [Optional] If your plugin doesn't use uniform column names 'gbHost', 'gbGroup'
    #   or 'gbKb' in its project-specific settings table, provide the corresponding column map here.
    def kbProjectSettings( fields = {:gbHost => :gbHost, :gbGroup => :gbGroup, :gbKb => :gbKb} )
      plugin_proj_settings() unless(@pluginProjSettings)
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Generic Plugin Proj Settings\n\n#{@pluginProjSettings.inspect}\n\n")
      gbHost = (fields[:gbHost] or :gbHost)
      gbGroup = (fields[:gbGroup] or :gbGroup)
      gbKb = (fields[:gbKb] or :gbKb)
      @gbHost = @pluginProjSettings.send(gbHost).to_s.strip
      @gbGroup = @pluginProjSettings.send(gbGroup).to_s.strip
      @gbKb = @pluginProjSettings.send(gbKb).to_s.strip
    end
  end
end
