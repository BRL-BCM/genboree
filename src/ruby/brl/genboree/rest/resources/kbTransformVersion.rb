#!/usr/bin/env ruby

require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocVersionEntity'
require 'brl/genboree/rest/data/numericEntity'
require 'brl/genboree/kb/helpers/transformsHelper'

module BRL ; module REST ; module Resources
  class KbTransformVersion < BRL::REST::Resources::GenboreeResource 

    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbTransformVersion'
    PREDEFINED_VERS = ['PREV', 'CURR', 'HEAD']

    def cleanup()
      super()
      @version = nil
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/(?:trRulesDoc|transform)/([^/\?]+)/ver/([^/\?]+)}
    end

    def self.priority()
      return 8
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1]).to_s.strip
        @kbName = Rack::Utils.unescape(@uriMatchData[2]).to_s.strip
        @transformationName = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        initStatus = initGroupAndKb()
        @version = Rack::Utils.unescape(@uriMatchData[4]).to_s.strip
        if(PREDEFINED_VERS.include?(@version))
          @version = @version
        else
          @version = @version.to_f
        end
      end
      return initStatus
    end

    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        begin
          versionDoc = nil
          collName = BRL::Genboree::KB::Helpers::TransformsHelper::KB_CORE_COLLECTION_NAME
          transformsHelper = @mongoKbDb.transformsHelper()
          if(transformsHelper and transformsHelper.coll)
            if(READ_ALLOWED_ROLES[@groupAccessStr])
              # check if the transformation doc exist
              mgCursor = transformsHelper.coll.find({ "Transformation.value" =>  @transformationName })
              if(mgCursor and mgCursor.is_a?(Mongo::Cursor))
                if(mgCursor.count == 1) # should always be one
                  versionDoc = transformsHelper.getDocVersion(@transformationName, @version)
                  if(versionDoc)
                    # need just the version number
                    if(@nvPairs.key?('versionNumOnly') and @nvPairs['versionNumOnly'] =~ /true/i)
                      versionKbDoc = BRL::Genboree::KB::KbDoc.new(versionDoc)
                      versionNum = versionKbDoc.getPropVal('versionNum')
                      versionEntity = BRL::Genboree::REST::Data::NumericEntity.new(@connect, versionNum.to_i)
                    elsif(@detailed)
                      versionEntity = BRL::Genboree::REST::Data::KbDocVersionEntity.from_json(versionDoc)
                    else # remove the data document part from the version doc and keep the rest of the metadata
                      versionKbDoc = BRL::Genboree::KB::KbDoc.new(versionDoc)
                      versionKbDoc.delProp('versionNum.content') rescue nil
                      versionEntity = BRL::Genboree::REST::Data::KbDocVersionEntity.from_json(versionKbDoc)
                    end
                    @statusName = configResponse(versionEntity)
                  else
                    @statusName = :"Not Found"
                    @statusMsg = "Requested version #{@version} for the transformation document #{@transformationName} does not exist."
                    raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
                  end
                else # cursor size should be zero
                  @statusName = :'Not Found'
                  @statusMsg = "NO_TRANSFORMATION_DOCUMENT: There is no transformation document, #{@transformationName.inspect} under #{@kbName} KB."
                end
              else
                @statusName = :'Internal Server Error'
                @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
              end
          else
            @statusName = :Forbidden
            @statusMsg = "You do not have sufficient permissions to perform this operation."
          end
          else
            @statusName = :"Not Found"
            @statusMsg = "NO_TRANSFORMATION_COLL: can't get transformation rules document named #{@transformationName.inspect} because appears to be no data collection #{collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{collName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
          end
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
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end


   
  end
end ; end ; end
