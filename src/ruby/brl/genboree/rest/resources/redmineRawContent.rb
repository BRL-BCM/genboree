require 'brl/sites/redmine'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/abstract/resources/redmine'
require 'brl/genboree/rest/data/rawDataEntity'

module BRL; module REST; module Resources

# Provide an simpler interface to the rawcontent extension than what would
#   be available through simple request proxying: 
#   (1) we hide users of this interface from the two-step process associated with uploading 
#     files to a Redmine raw content area with a single request here
#   (2) thus we need not expose the non-project related resource {redmine_root}/uploads.json
class RedmineRawContent < GenboreeResource
  extend ::BRL::Genboree::Abstract::Resources::Redmine
  HTTP_METHODS = { :get => true, :put => true, :delete => true }
  RSRC_TYPE = "RedmineRawContent"

  def self.pattern()
    return %r{/REST/#{VER_STR}/grp/([^/\?]+)/redminePrj/([^/\?]+)/rawcontent(/[^\?]+)$}
  end

  def self.priority()
    return 5 # higher than redminePrjChildren
  end

  def initOperation()
    initStatus = super()
    if(initStatus == :OK)
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @redminePrjId = Rack::Utils.unescape(@uriMatchData[2]) # @note this is the "identifier" not the "id" and not the "name"
      @rawContentPath = Rack::Utils.unescape(@uriMatchData[3]) # @note has a /path/to/file like structure
      # Provides: @groupId, @groupDesc, @groupAccessStr
      # Sets @statusName, @statusMsg; poor @statusName caught by get, put, etc.
      initStatus = initGroup()
    end
    return initStatus
  end

  # Retrieve the file contents of a rawcontent file
  def get()
    initStatus = initOperation()
    unless(initStatus == :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    # @todo attempting to access a rawcontent file through the API gives http 500?
    raise BRL::Genboree::GenboreeError.new(:"Not Implemented", "This feature is not yet implemented, sorry!")
  end

  # Upload a file to the rawcontent area of a Redmine project
  def put()
    initStatus = initOperation()
    unless(initStatus == :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end
    unless(WRITE_ALLOWED_ROLES.include?(@groupAccessStr))
      raise BRL::Genboree::GenboreeError.new(:Forbidden, "You do not have sufficient privileges to perform this operation")
    end

    ioObj = @req.body
    ioSize = @req.env["CONTENT_LENGTH"] rescue nil
    if(ioSize.nil? or ioSize.to_i == 0)
      raise BRL::Genboree::GenboreeError.new(:"Bad Request", "You must provide the Content-Length header with the size of the file you are uploading for this request to proceed")
    end

    # Upload raw content to the Redmine project associated with this Genboree group
    redmineUrlRoot = self.class.getRedmineUrlRoot(@dbu, @groupId, @redminePrjId)
    redmineObj = BRL::Sites::Redmine.new(redmineUrlRoot)
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading request body to Redmine project #{@redminePrjId.inspect} at rawcontent path #{@rawContentPath.inspect}")
    uploadRespObj = redmineObj.uploadRawContentIo(@redminePrjId, @rawContentPath, ioObj, ioSize)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "uploadRespObj[:resp].body=#{uploadRespObj[:resp].body}")
    respEntity = nil
    if(uploadRespObj[:success])
      @statusName = :Created
      @statusMsg = "Created"
      respEntity = BRL::Genboree::REST::Data::RawDataEntity.new(false, uploadRespObj[:obj])
      respEntity.setStatus(@statusName, @statusMsg)
    else
      respEntity = BRL::Genboree::REST::Data::AbstractEntity.new(false)
      @statusName = HTTP_STATUS_CODES[uploadRespObj[:resp].code.to_i]
      @statusMsg = uploadRespObj[:msg]
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to upload request body:\n#{uploadRespObj[:msg]}")
      respEntity.setStatus(@statusName, @statusMsg)
    end
    
    configResponse(respEntity) # sets @resp
    return @resp
  end

  # Remove a file from the rawcontents area of a Redmine project
  def delete()
    initStatus = initOperation()
    unless(initStatus == :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end
    unless(WRITE_ALLOWED_ROLES.include?(@groupAccessStr))
      raise BRL::Genboree::GenboreeError.new(:Forbidden, "You do not have sufficient privileges to perform this operation")
    end
  end
end

end; end; end
