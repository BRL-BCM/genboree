require 'brl/util/util'
require 'brl/genboree/rest/resources/genboreeResource'

module BRL ; module Genboree ; module StorageHelpers
  class AbstractStorageHelper

    attr_reader :dbrcHost, :dbrcPrefix, :genbConf, :dbu
    attr_accessor :relatedJobIds

    def initialize(dbrcHost = nil, dbrcPrefix = nil)
      # Set up
      @dbrcHost = dbrcHost if(dbrcHost)
      @dbrcPrefix = dbrcPrefix if(dbrcPrefix)
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
      @relatedJobIds = []
    end

    # ------------------------------------------------------------------
    # ABSTRACT INTERFACE METHODS - to be implemented in sub-classes
    # ------------------------------------------------------------------

    def exists?()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end
   
    def mtime()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end
   
    def getFileType()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def getFileSize()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end
    
    def getMimeType()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def uploadFile()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def downloadFile()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def deleteFile()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def openRemoteConnection()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    def closeRemoteConnection()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

    # NOTE: This is a helper method used for building the appropriate file path. Should be included in every child, but does not provide a "storage function" in itself.
    def getFullFilePath()
      raise NotImplementedError, "ERROR: this class (#{self.class}) does not implement the abstract interface method '#{__method__}', but is required to do so."
    end

  end
end ; end ; end # module BRL ; module Genboree ; module StorageHelpers
