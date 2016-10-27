#!/usr/bin/env ruby

require 'uri'
require 'brl/extensions/bson'
require 'bson'
require 'diffy'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocVersionEntity'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/kb/producers/fullPathTabbedDocProducer'

module BRL ; module REST ; module Resources

  class KbModelVersions < BRL::REST::Resources::GenboreeResource
  
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbDocVersions'

    def cleanup()
      super()
      @groupName = @kbName = @collName = @docName = @docId = nil
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/model/vers}
    end

    def self.priority()
      return 8
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1]).to_s.strip
        @kbName = Rack::Utils.unescape(@uriMatchData[2]).to_s.strip
        @collName = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        initStatus = initGroupAndKb()
      end
      return initStatus
    end

    # Validate and intialize path-related elements found in the pattern
    # @raises [BRL::Genboree::GenboreeError] if group is unaccessible (403) or if objects
    #   associated with path elements are not found (404)
    # @return [String] internal document id for the model of the collection in the resource path
    def initPath()
      # validate user access to this resource
      @statusName = initOperation()
      if(@statusName != :OK)
        defaultMsg = "Unable to authorize access to this resource"
        @statusMsg = (@statusMsg.nil? or @statusMsg.empty? ? defaultMsg : @statusMsg) 
        err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        raise err
      end
      modelsHelper = @mongoKbDb.modelsHelper()
      doc = modelsHelper.modelForCollection(@collName)
      if(doc.nil? or doc.empty?)
        @statusName = :"Not Found"
        @statusMsg = "The model document for the collection: #{@collName} does not exist."
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
      end
      @docId = doc["_id"]
      return @docId
    end
    

    # @todo detailed = false for just version numbers
    def get()
      begin
        docId = initPath()
        # finally, get versions of the model document
        versionsHelper = @mongoKbDb.versionsHelper('kbModels') rescue nil
        if(versionsHelper.nil?)
          @statusName = :"Internal Server Error"
          @statusMsg = "Failed to access versions collection for collection 'kbModels'"
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end
        dbRef = BSON::DBRef.new('kbModels', docId)
        versionsList = versionsHelper.allVersions(dbRef)
        if(versionsList.nil?)
          @statusName = :"Internal Server Error"
          @statusMsg = "Failed to get versions for the model"
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end
        #$stderr.puts "versionsList:\n\n#{versionsList.inspect}"
        if(@detailed)
          versionEntityList = BRL::Genboree::REST::Data::KbDocVersionEntityList.from_json(versionsList)
          
        else
          versionEntityList = BRL::Genboree::REST::Data::KbDocEntityList.new(@connect)
          versionsList.each { |verObj|
            doc = BRL::Genboree::KB::KbDoc.new( { "text" => { "value" => verObj['versionNum']['value'] } } )
            entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
            versionEntityList << entity
          }
        end
        @statusName = configResponse(versionEntityList) # sets @resp
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace)
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end
  end
end ; end ; end
