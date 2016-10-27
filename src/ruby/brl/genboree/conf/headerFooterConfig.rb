#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'json'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'

#=== *Purpose* :
#  Namespace for BRL's directly-related Genboree Ruby code.
module BRL ; module Genboree ; module Conf
  class HeaderFooterConfig < Hash
    attr_accessor :configFile

    def initialize()
      super()
      @configFile = nil
    end

    def self.load()
      retVal = self.new()
      retVal.loadConfigFile()
      return retVal
    end

    def loadConfigFile()
      # First, we need info from the genboree config file to determine the header-footer config file location
      genbConf = BRL::Genboree::GenboreeConfig.load()
      @configFile = "#{genbConf.resourcesDir}/hostedSites/headerFooter.config.json"
      # Load the header-footer config file
      reader = BRL::Util::TextReader.new(@configFile)
      content = reader.read()
      reader.close()
      # Parse and store
      contentAsHash = JSON.parse(content)
      contentAsHash.each_key { |key|
        self[key] = contentAsHash[key]
      }
      return
    end

    def makeAnchorOpen(hostedSite, component)
      #$stderr.puts "hostedSite: #{hostedSite}, component: #{component}, self[hostedSite]: #{self[hostedSite]}"
      retVal = ""
      if(self[hostedSite] and self[hostedSite][component])
        compSettings = self[hostedSite][component]
      else
        compSettings = self['default'][component]
      end
      retVal = "<a href=\"#{compSettings['link']}\">" if(compSettings and compSettings.key?('link'))
      return retVal
    end

    def makeImgAttributes(hostedSite, component)
      retVal = ""
      if(self[hostedSite] and self[hostedSite][component])
        compSettings = self[hostedSite][component]
      else
        compSettings = self['default'][component]
      end
      retVal = " src=\"#{compSettings['imgSrc']}\" height=\"#{compSettings['height']}\" width=\"#{compSettings['width']}\" alt=\"#{compSettings['alt']}\" title=\"#{compSettings['alt']}\" " if(compSettings)
      return retVal
    end
  end
end ; end ; end
