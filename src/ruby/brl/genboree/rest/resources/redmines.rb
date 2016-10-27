require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/rawDataEntity'

module BRL; module REST; module Resources
  class Redmines < GenboreeResource
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = "redmines"

    # Genboree config setting for Redmine configurations
    REDMINE_CONFS_SETTING = "gbRedmineConfs"

    def self.pattern()
      return %r{/REST/#{VER_STR}/redmines$}
    end

    def self.priority()
      return 1 # lowest, root
    end

    def initOperation()
      initStatus = super() # sets @genbConf
      return initStatus
    end

    def cleanup()
      super()
    end

    # Retrieve information about the configured Redmines for this Genboree instance
    def get()
      initStatus = initOperation
      unless(initStatus == :OK)
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
      end

      redmineConfsLoc = @genbConf.send(REDMINE_CONFS_SETTING.to_sym)
      if(redmineConfsLoc.nil?)
        raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "This Genboree instance configuration is missing information about associated Redmines")
      end

      unless(File.exists?(redmineConfsLoc))
        raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "This Genboree instance configuration has an invalid location set for associated Redmine configurations")
      end
      redmineConfs = nil
      File.open(redmineConfsLoc) { |fh|
        redmineConfs = JSON.parse(fh.read) rescue nil
      }
      if(redmineConfs.nil? or !redmineConfs.is_a?(Hash))
        raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "Could not parse the Redmine configuration file set for this Genboree instance")
      end

      # Return map of Redmine name to URL
      respHash = {}
      redmineConfs.each_key { |redmine|
        conf = redmineConfs[redmine]
        respHash[redmine] = "http://#{conf["host"]}#{conf["path"]}"
      }
      respEntity = BRL::Genboree::REST::Data::RawDataEntity.new(false, respHash)
      configResponse(respEntity) # sets @resp
      return @resp
    end
  end
end; end; end
