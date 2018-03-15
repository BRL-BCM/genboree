require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/data/kbDocEntity'

module BRL; module REST; module Resources

# Operations for a set of questionnaires
class KbQuestions < GenboreeResource
  HTTP_METHODS = { :get => true }
  RSRC_TYPE = 'kbQuestions'

  def cleanup()
    super()
    @groupName = @kbName = @collName = nil
  end

  def self.pattern()
    return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/quests}
  end

  def self.priority()
    return 6
  end

  def initOperation()
    initStatus = super()
    if(initStatus == :OK)
      @groupName  = Rack::Utils.unescape(@uriMatchData[1])
      @kbName     = Rack::Utils.unescape(@uriMatchData[2])
      @collName   = Rack::Utils.unescape(@uriMatchData[3])
      initStatus = initQuestion() # sets @mongoKbDb and @mongoQh
    end
    return initStatus
  end

  # Get a list of questionnaire names or, if detailed, a list of full questionnaire documents
  # Number of questionnaires is assumed to be small so we take no care in limiting the response size

  def get()
    initStatus = initOperation()
    if(initStatus == :OK)
      questCollName = BRL::Genboree::KB::Helpers::QuestionsHelper::KB_CORE_COLLECTION_NAME
      unless(@mongoQh.coll.nil?)
        if(READ_ALLOWED_ROLES[@groupAccessStr])
          dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
          if(dataHelper)
            metadata = nil
            bodyData = BRL::Genboree::REST::Data::KbDocEntityList.new(@connect)
            mgCursor = @mongoQh.coll.find() #get all the documents in 'kbQuestionnaires' collection
            docs = []
            if(mgCursor.count > 0)
              mgCursor.rewind!
              docIds = []
              mgCursor.each {|doc|
                kbDoc = BRL::Genboree::KB::KbDoc.new(doc)
                docIds << doc['_id']
                next if(kbDoc.getPropVal('Questionnaire.Coll') != @collName)
                docs << kbDoc
              }
              metadata = @mongoQh.getMetadata(docIds, questCollName)
              docs.sort { |aa,bb|
                xx = aa.getPropVal('Questionnaire')
                yy = bb.getPropVal('Questionnaire')
                retVal = (xx.downcase <=> yy.downcase)
                retVal = (xx <=> yy) if(retVal == 0)
                retVal
              }
            else
                # then there are no transforms -- return empty array
            end
            docs.each {|doc|
              if(@detailed)
                entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
              else
                entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, { "text" => { "value" => doc.getPropVal('Questionnaire')} })
              end
              bodyData << entity
            }
            bodyData.metadata = metadata if(metadata)
            @statusName = configResponse(bodyData)
          else
            @statusName = :'Not Found'
            @statusMsg = "NO_COLL: There appears to be no data collection #{@collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      else
        @statusName = :'Not Found'
        @statusMsg = "NO_QUESTIONNAIRE_COLL: There appears to be no internal collection #{questCollName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} . #{questCollName} is a GenboreeKB internal collection and absence of this collection means that the #{@kbName.inspect} is an outdated GenboreeKB."
      end
    end
    # If something wasn't right, represent as error
    @resp = representError() if(@statusName != :OK)
    return @resp
  end



end
end; end; end
