#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'brl/util/sniffer'
require 'ostruct'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/dataStructure/singletonJsonFileCache'
require 'shellwords'

module BRL ; module Genboree ; module Helpers
  # Child of sniffer (found in brl/util) that looks for GENBOREE-SPECIFIC path for sniffer conf file
  # All major sniffer code is found in brl/util, not here
  class Sniffer < ::BRL::Util::Sniffer
    
    # ------------------------------------------------------------------
    # INSTANCE METHODS
    # ------------------------------------------------------------------

    # CONSTRUCTOR.
    # @note Loads Genboree-specific conf file
    # @param [String,File] file The file to sniff. If {String}, must be a path to the file; if File,
    #   the path will be determined and the {File} instance left _untouched/modified_.
    # @param [BRL::Genboree::GenboreeConfig] gbConf If provided, an already loaded @GenboreeConfig@
    #   object which will be reused rather than creating and loading a new config object.
    def initialize(file=nil, gbConf=nil)
      super(file, gbConf)
      # GenboreeConfig. Create if not provided.
      @gbConf = (gbConf || BRL::Genboree::GenboreeConfig.load() )
      # Need to ensure we have the gbSnifferFormatConf file cached. It's a singleton
      genbSnifferFormatConfFile = @gbConf.gbSnifferFormatConf
      if(genbSnifferFormatConfFile and File.readable?(genbSnifferFormatConfFile))
        @snifferConfFile = genbSnifferFormatConfFile
        JsonFileCache.cacheFile(:sniffer, @snifferConfFile)
      end
    end

  end # class Sniffer
end ; end ; end # module BRL ; module Genboree ; module Helpers
