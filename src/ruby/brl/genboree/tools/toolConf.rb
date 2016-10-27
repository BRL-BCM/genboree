#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'ostruct'
require 'brl/util/util'
require 'brl/extensions/units'
require 'brl/genboree/genboreeUtil'
require 'brl/dataStructure/singletonJsonFileCache'

module BRL ; module Genboree ; module Tools
  # This class helps access cached tool-conf info. It uses an in-memory singleton
  #  cache to store tool-configs which will update automatically when the underlying
  #  JSON config file changes.
  #
  # It automatically loads and uses the default tool config settings, overriding them
  #   with tool-specific settings from the tool's config file.
  #
  class ToolConf
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------

    # @return [Class] A local shortcut to {BRL::DataStructure::SingletonJsonFileCache}
    ToolConfsCache = BRL::DataStructure::SingletonJsonFileCache

    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------

    # @return [BRL::Genboree::GenboreeConfig] the loaded @GenboreeConfig@ object in use by this object.
    attr_accessor :gbConf
    # @return [String] the conventional tool id string used to name tool directory & files in various places.
    #   There must be a corresponding @{toolIdStr}.json@ file in @gbConf.toolConfsDir@
    attr_accessor :toolIdStr
    # @return [String] the directory where tool conf .json files can be found. Comes from Genboree config file.
    attr_accessor :toolConfsDir
    # @return [String] the path to the specific tool config .json file for {#toolIdStr}
    attr_accessor :toolConfFile
    # @return [Hash] the default tool configuration, some/many of whose content will be overridden with tool-specific settings
    attr_reader   :defaultConf
    # @return [Hash] the tool-specific config for {#toolIdStr}, built using the default config and {#toolConfFile}
    attr_reader   :conf

    # ------------------------------------------------------------------
    # INSTANCE METHODS
    # ------------------------------------------------------------------

    # CONSTRUCTOR
    # @param [String] toolIdStr The conventional tool id for the tool of insterest.
    # @param [BRL::Genboree::GenboreeConfig] gbConf If provided, an already loaded @GenboreeConfig@
    #   object which will be reused rather than creating and loading a new config object.
    def initialize(toolIdStr, gbConf=nil)
      @conf = nil
      @defaultConf = nil
      @toolIdStr = toolIdStr
      # GenboreeConfig. Create if not provided.
      @gbConf = (gbConf || BRL::Genboree::GenboreeConfig.load() )
      @toolConfsDir = @gbConf.toolConfsDir
      @toolConfFile = "#{@toolConfsDir}/#{@toolIdStr}.json"
      ToolConfsCache.cacheFile(:toolConfs, @toolConfFile)
      @conf = createConf()
    end

    # A method of getting a tool config setting's value. Provide both the setting section
    #   (top-level key; e.g. "cluster", "info", "ui") and the specific setting from that section
    #   which you want the value for.
    # @note This method is somewhat superior to using the {#conf} reader method, because it will
    #   automatically cause the in-memory cache of tool configs to check for new file content.
    # @note This method can optionally return the whole section's settings Hash. Just leave out
    #   the @setting@ (2nd) argument.
    # @param [String] section The top-level key or "section" of the tool config where the setting of interest lives.
    # @param [String,nil] setting The specific setting with @section@ that you want the value for. Or @nil@ if you
    #   want the whole section Hash.
    # @return [Object,nil] the value for the given setting with the indicated section, or the whole section's Hash, or
    #   @nil@ if the setting and/or section are not present (or present but with @nil@ value)
    def getSetting(section, setting=nil)
      retVal = nil
      createConf()
      sectionHash = @conf[section]
      if(sectionHash)
        if(setting)
          retVal = sectionHash[setting]
        else
          retVal = sectionHash
        end
      end
      return retVal
    end

    # Convenience method to return a Hash of cluste directives, as extracted from the
    #   "cluster" section (which also has some other info in it).
    # @return [Hash] the directives Hash, as used in JobHelpers and by JobSumbitters.
    def buildDirectivesHash()
      clusterConf =  getSetting('cluster')
      directives =
      {
        :nodes    => clusterConf['nodes'],
        :ppn      => clusterConf['ppn'],
        :pvmem    => clusterConf['pvmem'],
        :vmem     => clusterConf['vmem'],
        :mem      => clusterConf['mem'],
        :pmem     => clusterConf['pmem'],
        :walltime => clusterConf['walltime']
      }
      # Sanity checks / robustness
      # - if vmem missing but have mem, set vmem = mem
      if(directives[:mem] and !directives[:vmem])
        directives[:vmem] = directives[:mem]
      end
      # - vmem must be at least as big as mem (need units & numbers)
      if(directives[:mem] and directives[:vmem])
        memStr, vmemStr = directives[:mem].upcase, directives[:vmem].upcase
        memStr = memStr.sub(/KI?/, "kilo").sub(/MI?/, "mega").sub(/GI?/, "giga").sub(/TI?/, "tera")
        vmemStr = vmemStr.sub(/KI?/, "kilo").sub(/MI?/, "mega").sub(/GI?/, "giga").sub(/TI?/, "tera")
        memUnit, vmemUnit = Unit(memStr), Unit(vmemStr)
        if(vmemUnit < memUnit)
          raise "ERROR: The mem setting of #{directives[:mem].inspect} is larger than the vmem setting of #{directives[:vmem].inspect}. This is not allowed. Specify a larger vmem."
        end
      end
      return directives
    end

    # ------------------------------------------------------------------
    # HELPER METHODS
    # - mainly for internal use but public if needed outside this class as well
    # ------------------------------------------------------------------

    # Builds this tool's config Hash,by mergine the default config with this tool's
    #   specific config content.
    # @note Uses BRL's {Hash#deepMerge} method, which recursively merges Hashes. i.e. When the
    #   value for a given key is a Hash in BOTH the original and new Hash, @deepMerge@ those two
    #   values rather than just using the value from the new Hash as-is [which is what Ruby's {Hash#merge} does]
    # @return [Hash] this tool's Hash config
    def createConf()
      unless(@defaultConf.is_a?(Hash))
        defConfFile = "#{@toolConfsDir}/default.json"
        ToolConfsCache.cacheFile(:toolConfs, defConfFile)
        @defaultConf = ToolConfsCache.getJsonObject(:toolConfs, defConfFile)
        raise "FATAL ERROR: Could not find and load the default tool config file (default.json)! Is your Genboree environment set up correctly?" unless(@defaultConf)
      end
      toolSpecificConf = ToolConfsCache.getJsonObject(:toolConfs, @toolConfFile)
      if(toolSpecificConf)
        @conf = @defaultConf.deepMerge(toolSpecificConf)
      else
        raise "FATAL ERROR: Could not find the tool config file for #{@toolIdStr.inspect}. Is #{@toolConfFile.inspect} missing? Every tool MUST have a config file."
      end
      return @conf
    end
  end # class ToolConfs
end ; end ; end # module BRL ; module Genboree ; module Tools
