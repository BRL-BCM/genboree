require 'brl/sites/redmine'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/rawDataEntity'
require 'brl/genboree/abstract/resources/redmine'

module BRL; module REST; module Resources

# Proxy requests to the Redmine HTTP REST API
class RedminePrjChildren < GenboreeResource
  extend ::BRL::Genboree::Abstract::Resources::Redmine

  HTTP_METHODS = { :get => true, :put => true, :delete => true }
  RSRC_TYPE = "redminePrjChildren"

  def self.pattern()
    return %r{/REST/#{VER_STR}/grp/([^/\?]+)/redminePrj/([^/\?]+)/(.+)$}
  end

  def self.priority()
    return 4 # higher than redminePrj
  end

  def initOperation()
    initStatus = super()
    if(initStatus == :OK)
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @redminePrjId = Rack::Utils.unescape(@uriMatchData[2]) # @note this is the "identifier" not the "id" and not the "name"
      @redminePrjSubResource = @uriMatchData[3] # @note cannot unescape then re-escape because will include "/"
      # Provides: @groupId, @groupDesc, @groupAccessStr
      # Sets @statusName, @statusMsg; poor @statusName caught by get, put, etc.
      initStatus = initGroup()
    end
    return initStatus
  end

  # interface
  def get()
    initStatus = initOperation()
    unless(initStatus == :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    request()
  end

  # interface
  def put()
    initStatus = initOperation()
    unless(initStatus == :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    if(WRITE_ALLOWED_ROLES.include?(@groupAccessStr))
      resp = request()
    else
      raise BRL::Genboree::GenboreeError.new(:Forbidden, "You do not have sufficient privileges to perform this operation")
    end
    return @resp
  end

  # interface
  def delete()
    initStatus = initOperation()
    unless(initStatus == :OK)
      raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
    end

    if(WRITE_ALLOWED_ROLES.include?(@groupAccessStr))
      request()
    else
      raise BRL::Genboree::GenboreeError.new(:Forbidden, "You do not have sufficient privileges to perform this operation")
    end
    return @resp
  end

  def request()
    args = {
      :dbu => @dbu,
      :groupId => @groupId,
      :redminePrjId => @redminePrjId,
      :redminePrjSubResource => @redminePrjSubResource,
      :rackReq => @req
    }
    respEntity = self.class.proxyRequest(args)
    @statusName, @statusMsg = respEntity.statusCode, respEntity.msg
    configResponse(respEntity, @statusName) # sets @resp

    return @resp
  end

  # Proxy a request to a Redmine HTTP REST API
  # @param [Hash] args named arguments
  # @option args [BRL::Genboree::DBUtil] :dbu a connection to the database where the association is stored
  # @option args [Integer] :groupId the groupId of the Genboree group to Redmine project association
  # @option args [String] :redminePrjId the Redmine project identifier for the association
  # @option args [String] :redminePrjSubResource the Redmine resource url fragment (such as wiki/{wiki-name}.json)
  # @option args [Rack::Request] :rackReq an object with #request_method, and #body methods
  # @todo change :rackReq to :httpReq ?
  def self.proxyRequest(args)
    # make request to redmine
    redmineUrlRoot = getRedmineUrlRoot(args[:dbu], args[:groupId], args[:redminePrjId])
    redmineObj = BRL::Sites::Redmine.new(redmineUrlRoot)
    $stderr.debugPuts(__FILE__, __method__, "API-STATUS", "Proxying request to Redmine instance at #{redmineUrlRoot.inspect}")
    redmineUrlPath = getRedminePath(redmineUrlRoot, args[:redminePrjId], args[:redminePrjSubResource])
    $stderr.debugPuts(__FILE__, __method__, "API-STATUS", "Accessing Redmine resource defined by the path #{redmineUrlPath.inspect}")
    httpReqObj = rackToHttp(args[:rackReq], redmineUrlPath)
    redmineResp = redmineObj.requestWithObj(httpReqObj)

    # prepare response for genboree
    # @todo update statusName and statusMsg based on redmineResp
    respEntity = nil
    statusName = HTTP_STATUS_CODES[redmineResp.code.to_i].to_sym
    if((200..299).include?(redmineResp.code.to_i))
      redmineRespBodyObj = (JSON.parse(redmineResp.body) rescue nil)
      if(redmineRespBodyObj.nil?)
        redmineRespBodyObj = { "text" => "" }
      end
      respEntity = BRL::Genboree::REST::Data::RawDataEntity.new(false, redmineRespBodyObj)
      statusMsg = statusName
    else
      respEntity = BRL::Genboree::REST::Data::AbstractEntity.new(false)
      statusMsg = redmineResp.body
    end
    respEntity.setStatus(statusName, statusMsg)

    return respEntity
  end

  # @todo passthrough headers?
  # @todo passthrough query string
  def self.rackToHttp(rackReq, path)
    rackMethodToHttpCls = {
      :get => ::Net::HTTP::Get,
      :put => ::Net::HTTP::Put,
      :delete => ::Net::HTTP::Delete
    }
    httpCls = rackMethodToHttpCls[rackReq.request_method.downcase.to_sym]
    httpObj = httpCls.new(path)
    httpObj.body = rackReq.body.string
    return httpObj
  end
end
end; end; end
