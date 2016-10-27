require 'brl/sites/redmine'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/rawDataEntity'

module BRL; module REST; module Resources
class UserRedminePrjs < GenboreeResource
  HTTP_METHODS = { :get => true }
  RSRC_TYPE = "userRedminePrjs"

  def self.pattern()
    return %r{/REST/#{VER_STR}/usr/([^/\?]+)/redminePrjs}
  end

  def self.priority()
    return 3 # higher than user
  end

  def initOperation()
    initStatus = super()
    if(initStatus == :OK)
      @rsrcUserName = @uriMatchData[1]
      initStatus = initUserGeneric()
      if(initStatus == :OK)
        @redmineObj = BRL::Sites::Redmine.new()
      end
    end
    return initStatus
  end

  def cleanup()
    super()
    @rsrcUserName = @redmineObj = nil
  end

  # @see self.partitionPrjs
  def get()
    initStatus = initOperation()
    if(initStatus != :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end
    
    rawData = self.class.partitionPrjs({
      :redmineObj => @redmineObj,
      :userName => @rsrcUserName,
      :dbu => @dbu
    })

    respEntity = BRL::Genboree::REST::Data::RawDataEntity.new(false, rawData)
    respEntity.setStatus(@statusName, @statusMsg)
    configResponse(respEntity) # sets @resp

    return @resp
  end

  # Get a list of redmine projects that the @rsrcUserName has access in form
  # { 
  #   :registeredPrjs => { {group_name} => {project_id}, ... },
  #   :unregisteredPrjs => [ {project_id}, {project_id}, ... ]
  # }
  def self.partitionPrjs(args={})
    # Get redmine project identifiers that this user has access to
    projectIds = args[:redmineObj].getProjectIdsForUser(args[:userName])
    if(projectIds.nil?)
      raise "Cannot retrieve Redmine projects for user #{args[:userName].inspect}"
    end

    # Partition redmine project identifiers into those that are already registered with
    #   Genboree groups and those that aren't
    redminePrjRecs = args[:dbu].selectRedminePrjsByProjectIds(projectIds)
    if(redminePrjRecs.nil?)
      raise "Cannot access Redmine project/Genboree group associations"
    end
    regProjectIds = redminePrjRecs.map { |redminePrjRec| redminePrjRec['project_id'] }
    regProjectMap = {}
    redminePrjRecs.each { |redminePrjRec|
      groupName = redminePrjRec['groupName']
      projectId = redminePrjRec['project_id']
      regProjectMap[groupName] = projectId
    }
    unregProjectIds = projectIds - regProjectIds
    rawData = {
      :registeredPrjs => regProjectMap,
      :unregisteredPrjs => unregProjectIds
    }
  end

end
end; end; end
