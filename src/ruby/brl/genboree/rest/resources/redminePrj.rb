require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/redminePrjEntity'

module BRL; module REST; module Resources
class RedminePrj < GenboreeResource
  HTTP_METHODS = { :get => true, :put => true, :delete => true }
  RSRC_TYPE = "redminePrj"
  
  def self.pattern()
    return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/redminePrj/([^/\?]+)$}
  end

  def self.priority()
    return 3 # higher than group
  end

  def initOperation()
    initStatus = super()
    if(initStatus == :OK)
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @redminePrjId = Rack::Utils.unescape(@uriMatchData[2]) # @note this is the "identifier" not the "id" and not the "name"
      # Provides: @groupId, @groupDesc, @groupAccessStr
      # Sets @statusName, @statusMsg; poor @statusName caught by get, put, etc.
      initStatus = initGroup()
    end
    return initStatus
  end

  def cleanup()
    super()
    @groupName = @redminePrjId = nil
  end

  # access an existing redmine project that is registered with a genboree group
  def get()
    initStatus = initOperation()
    unless(initStatus == :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    rmpRecs = @dbu.selectRedminePrjByGroupIdAndProjectId(@groupId, @redminePrjId)
    if(rmpRecs.nil? or rmpRecs.empty?)
      @statusName = :"Not Found"
      @statusMsg = "No Redmine project with the identifier #{@redminePrjId.inspect} has been registered with the group #{@groupName.inspect}"
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end
    if(rmpRecs.size > 1)
      raise "Too many redmine project records were returned for groupId #{@groupId.inspect} and redminePrj #{@redminePrjId.inspect}"
    end

    respEntity = BRL::Genboree::REST::Data::RedminePrjEntity.new(false, rmpRecs[0]["url"], rmpRecs[0]["project_id"])
    @statusName = @statusMsg = :OK
    respEntity.setStatus(@statusName, @statusMsg)
    configResponse(respEntity) # sets @resp
    
    return @resp
  end

  # create new, update existing, or rename existing redmine projects associated with this group
  def put()
    initStatus = initOperation()
    unless(initStatus == :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    # check for write access
    unless(WRITE_ALLOWED_ROLES.include?(@groupAccessStr))
      @statusName = :"Forbidden"
      @statusMsg = "FORBIDDEN: The username provided does not have sufficient access or permissions to operate on the resource."
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    # parse payload
    entity = parseRequestBodyForEntity("RedminePrjEntity")
    if(entity == :'Unsupported Media Type')
      @statusName = :"Unsupported Media Type"
      @statusMsg = "Could not parse the payload as a Redmine project"
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    respEntity = self.class.createUpdateRename({
      :groupId => @groupId,
      :groupName => @groupName,
      :redminePrjId => @redminePrjId,
      :dbu => @dbu,
      :reqEntity => entity
    })
    configResponse(respEntity) # sets @resp
    @statusName, @statusMsg = respEntity.statusCode, respEntity.msg

    return @resp
  end

  # Utility function for multiple possible meanings of PUT request based on the payload
  # @param [Hash] args named arguments for create or update or rename:
  # @option args [Integer] :groupId the groupId of the Genboree group to Redmine project association
  # @option args [String] :groupName the name associated with groupId (used for messages to the user)
  # @option args [String] :redminePrjId the Redmine project identifier for the association
  # @option args [BRL::Genboree::DBUtil] :dbu a connection to the database where the association is stored
  # @option args [BRL::Genboree::REST::Data::RedminePrjEntity] :reqEntity the parsed request body
  # @todo validate project identifier/url
  def self.createUpdateRename(args={})
    respEntity = nil

    if(args[:redminePrjId] != args[:reqEntity].projectId)
      # then PUT is a rename operation
      respEntity = rename(args[:dbu], args[:groupId], args[:groupName], args[:redminePrjId], args[:reqEntity].projectId, args[:reqEntity].url)
    else
      # then not a rename operation
      rmpRecs = args[:dbu].selectRedminePrjByProjectId(args[:redminePrjId])
      if(rmpRecs.nil? or rmpRecs.empty?)
        # then not found, create it
        respEntity = create(args[:dbu], args[:groupId], args[:reqEntity].projectId, args[:reqEntity].url)
      elsif(rmpRecs.size == 1)
        if(rmpRecs[0]["group_id"] != args[:groupId])
          # then this redmine project is already registered in another group
          statusName = :"Bad Request"
          statusMsg = "The Redmine project identified by #{args[:redminePrjId]} is already registered to another group. Please contact an administrator."
          raise BRL::Genboree::GenboreeError.new(statusName, statusMsg)
        else
          # then found, update it
          respEntity = update(args[:dbu], args[:groupId], args[:groupName], args[:redminePrjId], args[:reqEntity].url)
        end
      else
        # then error
        raise "Too many redmine project records were returned for groupId #{args[:groupId].inspect} and redminePrj #{args[:redminePrjId].inspect}"
      end
    end

    return respEntity
  end

  # @see createUpdateRename
  def self.rename(dbu, groupId, groupName, fromProjectId, toProjectId, url)
    respEntity = nil
    rmpRecs = dbu.selectRedminePrjByGroupIdAndProjectId(groupId, fromProjectId)
    if(rmpRecs.nil? or rmpRecs.empty?)
      # then not found/bad request
      statusName = :"Not Found"
      statusMsg = "Cannot rename #{fromProjectId.inspect} to #{toProjectId.inspect} because no Redmine project named #{fromProjectId} has been registered with the group #{groupName.inspect}"
      raise BRL::Genboree::GenboreeError.new(statusName, statusMsg)
    elsif(rmpRecs.size == 1)
      # then rename existing
      # @todo HTTP 301?
      nUpdated = dbu.updateRedminePrjIdAndUrlByGroupIdAndPrjId(toProjectId, reqEntity.url, groupId, fromProjectId)
      statusName = :OK
      statusMsg = "Renamed and updated #{fromProjectId.inspect} to #{toProjectId.inspect}"
      respEntity = BRL::Genboree::REST::Data::AbstractEntity.new(false)
      respEntity.setStatus(statusName, statusMsg)
    else
      raise "Too many redmine project records were returned for groupId #{groupId.inspect} and redminePrj #{fromProjectId.inspect}"
    end
    return respEntity
  end

  # @see createUpdateRename
  def self.create(dbu, groupId, projectId, url)
    nInsert = dbu.insertRedminePrj(groupId, projectId, url)
    respEntity = BRL::Genboree::REST::Data::AbstractEntity.new(false)
    statusName = :Created
    statusMsg = "Associated Redmine project #{projectId.inspect} at #{url.inspect} with the Genboree group"
    respEntity.setStatus(statusName, statusMsg)
    return respEntity
  end

  # @see createUpdateRename
  def self.update(dbu, groupId, groupName, projectId, url)
    nUpdated = dbu.updateRedminePrjUrlByGroupIdAndPrjId(url, groupId, projectId)
    respEntity = BRL::Genboree::REST::Data::AbstractEntity.new(false)
    statusName = :OK
    statusMsg = "Updated Redmine project #{projectId.inspect} associated with the Genboree group #{groupName.inspect} to refer to #{url.inspect}"
    respEntity.setStatus(statusName, statusMsg)
    return respEntity
  end

  # remove an existing redmine project/genboree group association
  def delete
    initStatus = initOperation()
    unless(initStatus == :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    # check for write access
    unless(WRITE_ALLOWED_ROLES.include?(@groupAccessStr))
      @statusName = :"Forbidden"
      @statusMsg = "FORBIDDEN: The username provided does not have sufficient access or permissions to operate on the resource."
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    # look for the redmine project/genboree group association to delete
    rmpRecs = @dbu.selectRedminePrjByGroupIdAndProjectId(@groupId, @redminePrjId)
    if(rmpRecs.nil? or rmpRecs.empty?)
      # then not found
      @statusName = :"Not Found"
      @statusMsg = "No Redmine project with the identifier #{@redminePrjId.inspect} has been registered with the group #{@groupName.inspect}"
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    elsif(rmpRecs.size == 1)
      # then delete existing record
      numDeleted = @dbu.deleteRedminePrjByPrjId(rmpRecs.first['project_id'])
      if(numDeleted == 1)
        @statusName = :OK
        @statusMsg = "Removed the association of the Redmine project #{@redminePrjId.inspect} from the group #{@groupName.inspect}"
      else
        @statusName = :"Internal Server Error"
        @statusMsg = "An error occurred while removing the Redmine project #{@redminePrjId.inspect} association with the group #{@groupName.inspect}"
      end
      respEntity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
      respEntity.setStatus(@statusName, @statusMsg)
    else
      # then error
      raise "Too many redmine project records were returned for groupId #{@groupId.inspect} and redminePrj #{@redminePrjId.inspect}"
    end
    configResponse(respEntity) # sets @resp

    return @resp
  end
end
end; end; end
