require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/redminePrjEntity'
require 'brl/genboree/rest/data/textEntity'

module BRL; module REST; module Resources
class RedminePrjs < GenboreeResource
  HTTP_METHODS = { :get => true }
  RSRC_TYPE = "redminePrjs"

  def self.pattern()
    return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/redminePrjs$}
  end

  def self.priority()
    return 3 # higher than group
  end

  def initOperation()
    initStatus = super()
    if(initStatus == :OK)
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      initStatus = initGroup()
    end
    return initStatus
  end

  def cleanup()
    super()
    @groupName = nil
  end

  # Get a list of redmine projects registered with this group
  def get()
    initStatus = initOperation()
    unless(initStatus == :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    rmpRecs = @dbu.selectRedminePrjsByGroupId(@groupId)
    if(rmpRecs.nil?)
      @statusName = :"Internal Server Error"
      @statusMsg = "An error occurred while retrieving the Redmine Projects for this group"
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    # add database information to response entity depending on requested level of detail
    respEntity = nil
    if(@detailed)
      # then give full information about the redmine projects
      redminePrjEntities = rmpRecs.map { |rmpRec|
        BRL::Genboree::REST::Data::RedminePrjEntity.new(false, rmpRec["url"], rmpRec["project_id"], rmpRec["gb_project_name"])
      }
      respEntity = BRL::Genboree::REST::Data::RedminePrjEntityList.new(false, redminePrjEntities)
    else
      # then only give the redmine project names
      textEntities = rmpRecs.map { |rmpRec|
        BRL::Genboree::REST::Data::TextEntity.new(false, rmpRec["project_id"])
      }
      respEntity = BRL::Genboree::REST::Data::TextEntityList.new(false, textEntities)
    end

    # finalize response entity
    respEntity.setStatus(@statusName, @statusMsg)
    configResponse(respEntity)
    return @resp
  end
end
end; end; end
