#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/rest/data/kbDocVersionEntity'
require 'brl/genboree/rest/data/strArrayEntity'

module BRL ; module REST ; module Resources
  class KbDocsVersion < BRL::REST::Resources::GenboreeResource

    HTTP_METHODS = { :get => true, :put => true }
    RSRC_TYPE = 'kbDocsVersion'
    PREDEFINED_VERS = ['PREV', 'CURR', 'HEAD']

    def cleanup()
      super()
      @mongoKbDb = @mongoDbrcRec = @kbId = @kbName = @kbDbName = @groupName = @collName = @version = nil
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/docs/ver/([^/\?]+)}
    end

    def self.priority()
      return 9
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1]).to_s.strip
        @kbName = Rack::Utils.unescape(@uriMatchData[2]).to_s.strip
        @collName = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        @version = Rack::Utils.unescape(@uriMatchData[4]).to_s.strip
        # check the version here
        # No numbers allowed - must be within PREDEFINED_VERS
        if(PREDEFINED_VERS.include?(@version))
          @version = @version
        else
          @statusName = :'Bad Request'
          @statusMsg = "BAD_PARAMS: Supported version for multiple documents are either of the these - #{PREDEFINED_VERS.inspect}. The version you requested, #{@version.inspect} is not supported/implemented."
        end

        @authorFullName = @nvPairs['authorFullName'] rescue nil 
        # get the doc ids 
        @docIDs = @nvPairs['docIDs'].to_s.strip
        if(@docIDs =~ /\S/)
          # Protect escaped , actually in the names (i.e. not delimiter)
          @docIDs = @docIDs.gsub(/\\,/, "\v").split(/,/,-1).map { |xx| xx.gsub(/\v/, ',').strip }
        else
          @docIDs = nil
        end
        initStatus = @statusName
        initStatus = initGroupAndKb() if(initStatus == :OK)
      end
      return initStatus
    end

    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        unless(@docIDs.nil?)
          begin
            dataCollHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
            if(dataCollHelper)
              identProp = dataCollHelper.getIdentifierName()
              versionsHelper = @mongoKbDb.versionsHelper(@collName) rescue nil
              
              bodyData = getVersionRecs(identProp, versionsHelper, @docIDs)
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", " @statusName=#{@statusName.inspect}")
              if(@statusName == :OK)
                @statusName = configResponse(bodyData)
              end
            else
              @statusName = :"Not Found"
              @statusMsg = "NO_COLL: There appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
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
        else 
          # no document ids in the request
          @statusName = :'Bad Request'
          @statusMsg = "BAD_PARAMS: You are requesting version records for multiple documents, BUT failed to provide the document identifiers of interest. Provide docIDs={docIDsList}."
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end


   def put()
    initStatus = initOperation()
    if(initStatus == :OK)
        if(WRITE_ALLOWED_ROLES[@groupAccessStr])
          begin
            dataCollHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
            if(dataCollHelper)
              identProp = dataCollHelper.getIdentifierName()
              versionsHelper = @mongoKbDb.versionsHelper(@collName) rescue nil
              payload = parseRequestBodyForEntity('StrArrayEntity')
                if(payload.nil? or (payload.is_a?(BRL::Genboree::REST::Data::StrArrayEntity) and payload.array and payload.array.empty?))
                  @statusName = :'Not Implemented'
                  @statusMsg = "EMPTY_DOC: The doument list is empty."
                elsif(payload == :'Unsupported Media Type')
                  @statusName = :'Unsupported Media Type'
                  @statusMsg = "BAD_DOC: The document list in te put request does not follow the strArrayEntity representation."
                else
                  bodyData = getVersionRecs(identProp, versionsHelper, payload.array)
                  $stderr.debugPuts(__FILE__, __method__, "DEBUG", " @statusName=#{@statusName.inspect}")
                  if(@statusName == :OK)
                    @statusName = configResponse(bodyData)
                  end
               end
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_COLL: can't put the request as it appears there is no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
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
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
    # If something wasn't right, represent as error
    end
    @resp = representError() if(@statusName != :OK)
    return @resp

   end

######################################
#HELPER METHODS
######################################

   # gets the list of version docs as KbDocEntity class objects
   # @param [String] identProp property of the document identifier
   # @param [BRL::Genboree::KB::Helpers::VersionsHelper] versionHelper version helper instance
   # @param [Array<String>] docIDs list of document identifiers
   # @return [BRL::Genboree::REST::Data::KbDocEntityList] bodyData list of versionDocs
   def getVersionRecs(identProp, versionsHelper, docIDs=nil)
     bodyData = BRL::Genboree::REST::Data::KbDocEntityList.new(@connect)
     # for each document requested get the version doc and add to the entity list
     docIDs.each { |docName|
       doc = versionsHelper.exists?(identProp, docName, @collName)
       if(doc)
         docId = doc.getPropVal('versionNum.content')['_id']
         dbRef = BSON::DBRef.new(@collName, docId)
         allVers = nil
         versionDoc = nil
         vDoc = nil
         allVers = versionsHelper.allVersions(dbRef)
         if(@version == 'HEAD' or @version == 'CURR')
           versionDoc = allVers.last
         else # PREV
           if(allVers.size > 1)
             versionDoc = allVers[allVers.size-2]
           else
             versionDoc = nil
           end
         end
         if(versionDoc)
           verKbDoc = BRL::Genboree::KB::KbDoc.new(versionDoc)
           unless(@detailed)
             # remove the document part of the version doc. need only the metadata
             verKbDoc.delProp('versionNum.content') rescue nil
           end
           docWfullName = addFullNameToDoc(verKbDoc) if(@authorFullName)
           #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "verKbDoc:\n\n#{verKbDoc.inspect}\n\n")
           if(docWfullName)
             vEntity = BRL::Genboree::REST::Data::KbDocVersionEntity.from_json(docWfullName)
             vEntity.doWrap = false
             vDoc = BRL::Genboree::KB::KbDoc.new({docName => { 'data' => vEntity } } )
           else
             vEntity = BRL::Genboree::REST::Data::KbDocVersionEntity.from_json(verKbDoc)
             vEntity.doWrap = false
             vDoc = BRL::Genboree::KB::KbDoc.new({docName => { 'data' => vEntity } } )
           end
         else
           vDoc = BRL::Genboree::KB::KbDoc.new({docName => {"data" => versionDoc}})
         end
         #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "vDoc:\n\n#{vDoc.inspect}")
         entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, vDoc, false)
         bodyData << entity
       else
         @statusName = :'Not Found'
         @statusMsg = "NO_DOC: there is no document with the identifier #{docName.inspect} in the #{@collName.inspect} collection in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc; also consider if it has been deleted)."
         break
       end
     }
     return bodyData
   end   


    # returns the version record with authorFullName as a new property object 
    # @param [Hash] doc the version document to which the authorFullName prop is to be added
    # @return [Hash] retVal the version document with the new prop
    def addFullNameToDoc(doc)
      retVal = nil
      firstName = ""
      lastName = ""
      # get the author info from the doc
      author = doc.getPropVal('versionNum.author') rescue nil
      if(author)
        userRows = @dbu.getUserByName(author)
        unless(userRows.nil? or userRows.empty?)
          firstName = userRows.first["firstName"]
          lastName = userRows.first["lastName"]
          if(@authorFullName =~ /lastfirst/i)
            doc.setPropField('value', 'versionNum.authorFullName', "#{lastName} #{firstName}") rescue nil
          else
            doc.setPropField('value', 'versionNum.authorFullName', "#{firstName} #{lastName}") rescue nil
          end
        end
        retVal = doc
      end
      return retVal
    end



  end
end ; end ; end
