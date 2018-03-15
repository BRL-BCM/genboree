#!/usr/bin/env ruby

require 'brl/genboree/rest/data/numericEntity'
require 'brl/genboree/rest/resources/kbDocRevisions'
require 'brl/genboree/kb/kbDoc'

module BRL ; module REST ; module Resources
  class KbDocRevision < BRL::REST::Resources::KbDocRevisions

    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbDocRevision'
    PREDEFINED_REVS = ['PREV', 'CURR', 'HEAD']

    def cleanup()
      super()
      @revision = nil
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/doc/([^/\?]+)/rev/([^/\?]+)}
    end

    def self.priority()
      return 9
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @revision = Rack::Utils.unescape(@uriMatchData[5]).to_s.strip
        if(PREDEFINED_REVS.include?(@revision))
          @revision = @revision
        else
          @revision = @revision.to_f
        end
      end
      return initStatus
    end

    def get()
      begin
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "HERE")
        @docId = initPath()
        revisionsHelper = @mongoKbDb.revisionsHelper(@collName) rescue nil
        modelsHelper = @mongoKbDb.modelsHelper() rescue nil
        dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
        if(revisionsHelper.nil?)
          @statusName = :"Internal Server Error"
          @statusMsg = "Failed to access revisions collection for data collection #{@collName}"
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end
        dbRef = BSON::DBRef.new(@collName, @docId)
        allVers = nil
        revisionDoc = nil
        if(PREDEFINED_REVS.include?(@revision))
          allRevs = revisionsHelper.allRevisions(dbRef, nil, { :sort => ['revisionNum.value', Mongo::ASCENDING] })
          if(@revision == 'HEAD' or @revision == 'CURR')
            revisionDoc = allRevs.last
          else # PREV
            # Make sure the doc has more than one version to return the 'PREV' version
            if(allRevs.size > 1)
              revisionDoc = allRevs[allRevs.size-2]
            else
              @statusName = :"Not Found"
              @statusMsg = "There is no 'PREV' revision for this document. There is only one revision (HEAD) for this document."
              raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
            end
          end
        else
          revisionDoc = revisionsHelper.getRevision(@revision, dbRef)
        end
        if(revisionDoc.nil?)
          @statusName = :"Not Found"
          @statusMsg = "Requested revision #{@revision} for the document #{@docName} does not exist."
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end
        revisionEntity = nil
        if(@nvPairs.key?('revisionNumOnly') and @nvPairs['revisionNumOnly'] =~ /true/i)
          kbRevDoc = BRL::Genboree::KB::KbDoc.new(revisionDoc)
          revisionNum = kbRevDoc.getPropVal('revisionNum')
          revisionEntity = BRL::Genboree::REST::Data::NumericEntity.new(@connect, revisionNum.to_i)
        else
          revisionEntity = BRL::Genboree::REST::Data::KbDocRevisionEntity.from_json(revisionDoc)
        end
        @statusName = configResponse(revisionEntity) # sets @resp
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
