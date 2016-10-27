#!/usr/bin/env ruby
require 'json'
require 'brl/dataStructure/singletonJsonFileCache'
require 'brl/genboree/genboreeUtil'

module BRL ; module Genboree ;  module REST ; module Extensions
  module Helpers
    # Local shortcut to {BRL::DataStructure::SingletonJsonFileCache}
    # @return [Class]
    ExtConfCache = BRL::DataStructure::SingletonJsonFileCache

    # Hook to extend class (for class methods) or include instance methods (for instance methods)
    def self.included(includingClass)
      includingClass.send(:include, InstanceMethods)
      includingClass.extend(ClassMethods)
    end

    module InstanceMethods
      def userIdForLogin(login)
        users = @dbu.getUserByName(login) # should connect to main database now
        return ( users.first['userId'] rescue nil )
      end
    end

    module ClassMethods
      # Load and return the extension-specific conf file contents
      def loadConf(apiExtCategory, apiRsrcType) # Base api extension conf dir
        gbConf = BRL::Genboree::GenboreeConfig.load()
        apiExtConfsDir = gbConf.gbApiExtConfsDir
        extConfFile = "#{apiExtConfsDir}/#{apiExtCategory}/#{apiRsrcType}.json"
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "extConfFile: #{extConfFile.inspect} ; readable? #{File.readable?(extConfFile)}")
        # Get json object from global cache
        conf = ExtConfCache.getJsonObject(:apiExtensions, extConfFile)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "extConf content:\n\n#{JSON.pretty_generate(conf)}\n\n")
        return conf
      end

      def templateDir( apiExCategory, apiRsrcType, apiExtConf )
        retVal = nil
        # See if there is a specific one mentioned in the extension conf file under template.dir:
        if(apiExtConf['template'])
          retVal = apiExtConf['template']['dir'] rescue nil
          # If there doesn't seem to be a specific one mentioned, use the standard location which is under the conf area for this extension
          unless(retVal and retVal =~ /\S/)
            gbConf = BRL::Genboree::GenboreeConfig.load()
            apiExtConfsDir = gbConf.gbApiExtConfsDir
            retVal = "#{gbConf.gbApiExtConfsDir}/#{apiExCategory}/templates/#{apiRsrcType}"
          end
        end
        return retVal
      end
    end
  end
end ; end ; end ; end # module BRL ; module REST ; module Extensions
