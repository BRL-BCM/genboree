require 'net/http'
require 'net/https'
require 'cgi'
require 'json'
require 'brl/util/util'
require 'brl/db/dbrc'

module BRL; module Sites

# @todo some functions here use the "getRespObj" interface while others dont,
#   standardize ones that dont to use the interface, too
class Redmine # @note does not inherit from AbstractSite and does not use proxy cache
  # header name for admin requests on behalf of another user
  SWITCH_USER_HDR = "X-Redmine-Switch-User"

  # [Boolean] if true, write more status to stderr
  attr_accessor :verbose
  attr_reader :headers

  # @param [String] redmineUrlRoot root to Redmine HTTP REST API e.g. "http://10.15.55.128/genboreeKB_dev"
  # @param [String] apiKey authentication for Redmine API (see the "My Account" Redmine page)
  def initialize(redmineUrlRoot, apiKey=nil)
    @redmineUrlRoot = redmineUrlRoot
    uriObj = URI.parse(@redmineUrlRoot)
    @apiKey = (apiKey.nil? ? self.class.getDefaultApiKey(uriObj.host) : apiKey)
    @headers = {
      "Content-Type" => "application/json",
      "X-Redmine-API-Key" => @apiKey
    }
    unless(redmineUrlValid?(@redmineUrlRoot))
      raise ArgumentError.new("Invalid Redmine url: #{@redmineUrlRoot.inspect}")
    end
    @verbose = false
  end

  # Retrieve an API key from the BRL dbrc file
  # @return [String] the api key
  # @note ENV["DBRC_FILE"] must refer to a file readable by BRL::DB::DBRC
  def self.getDefaultApiKey(host)
    dbrc = BRL::DB::DBRC.new()
    dbrcRec = dbrc.getRecordByHost(host, :redmine)
    if(dbrcRec.nil?)
      raise "Cannot retrieve default API key for host #{host.inspect}"
    end
    return dbrcRec[:password]
  end

  # Verify URL is valid by making a request for Redmine projects
  # @note may give false negative if network unavailable
  def redmineUrlValid?(redmineUrlRoot)
    prjsWrap = getProjects
    prjsWrap[:success]
  end

  # --------------------------------------------------
  # Projects - {{
  # --------------------------------------------------
  
  # Get project objects for Redmine instance
  # @param [String] redmineUrlRoot the redmine instance to get projects for
  # @param [Hash] HTTP request headers to use to authenticate requests
  #   (returned projects will be those visible to the user whose api key is
  #   provided)
  # @return [Hash] @see getRespObj
  def self.getProjects(redmineUrlRoot, headers)
    url = File.join(redmineUrlRoot, "projects.json?limit=100")
    rv = makeRequest(url, headers)
    parseResp!(rv)
    return rv
  end
  def getProjects
    self.class.getProjects(@redmineUrlRoot, @headers)
  end

  # Get all projects with the rawcontent module enabled at the Redmine at @redmineUrlRoot
  # @return [Array<String>] 
  def getProjectsWithRawContent
    rv = nil
    projectsWrap = getProjects
    if(projectsWrap[:success])
      projectIdents = projectsWrap[:obj]['projects'].collect { |xx| xx['identifier'] }
      rv = projectIdents.select { |xx| rawContentOk?(xx) }
    end
    return rv
  end
  
  # Get the projects that are public or that @userName@ is a member of
  # @param [String] userName the user to get projects for
  # @return [Hash] @see getRespObj with :obj as [Array<Hash>] list of project objects for this user
  def getProjectsForUser(userName)
    rv = nil
    headers = { SWITCH_USER_HDR => userName }
    headers = @headers.merge(headers)
    rv = self.class.getProjects(@redmineUrlRoot, headers)
    return rv
  end

  # Get the project identifiers (from the project objects) that a user has access to
  # @param [String] userName the user to get projects for
  # @return [Hash] @see getRespObj with :obj as [Array<String>] list of project identifiers for this user
  def getProjectIdsForUser(userName)
    rv = getProjectsForUser(userName)
    if(rv[:success])
      rv[:obj] = rv[:obj].map { |xx| xx['identifier'] }
    end
    return rv
  end

  # Instead of project membership objects, return project objects
  # @see getProjectMembershipsWhereAdminAndRaw
  def getProjectsWhereAdminAndRaw(userName)
    rv = getRespObj
    memberWrap = getProjectMembershipsWhereAdminAndRaw(userName)
    if(memberWrap[:success])
      projectsWrap = getProjectsForUser(userName)
      if(projectsWrap[:success])
        rv = projectsWrap
        projects = projectsWrap[:obj]["projects"]
        memberships = memberWrap[:obj]
        rv[:obj] = filterProjectsByMemberships(projects, memberships)
      else
        rv = projectsWrap
      end
    else
      rv = memberWrap
    end
    return rv
  end

  # Compose hash of projects using their ids as keys
  # @param [Array<Hash>] projects list of project objects
  # @return [Hash] map of project id to project object
  # @see getProjectsForUser
  def hashProjects(projects)
    map = {}
    projects.each { |project|
      map[project["id"]] = project
    }
    return map
  end
  
  # Get project display labels (name including parent project name) from project objects
  # @param [Hash] projectsHash map of project id to project object
  # @return [Hash] map of project id to project display name
  # @see hashProjects
  # @todo should projects with depth > 2 have full heirarchical name displayed?
  def projectsToLabels(projectsHash)
    rv = {}
    delim = " - "
    projectsHash.each_key { |id|
      project = projectsHash[id]
      nameTokens = []
      if(project.key?("parent"))
        nameTokens << project["parent"]["name"]
      end
      nameTokens << project["name"]
      rv[id] = nameTokens.join(delim)
    }
    return rv
  end

  # Filter a list of Redmine project objects to include only those mentioned
  #   in the list of Redmine membership objects
  # @param [Array<Hash>] projects @see getProjects[:obj]["projects"]
  # @param [Array<Hash>] memberships @see getProjectMembershipsForUser[:obj]
  # @return [Array<Hash>] subset of @projects@
  def filterProjectsByMemberships(projects, memberships)
    memberProjectIds = memberships.collect { |membership| membership.getNestedAttr("project.id") }
    filter = projects.delete_if { |project|
      projectId = project["id"]
      !memberProjectIds.include?(projectId)
    }
    return filter
  end

  # }} -

  # --------------------------------------------------
  # Memberships - {{
  # --------------------------------------------------

  # Get memberships for a user
  # @param [String] userName the user to get memberships for
  # @see http://www.redmine.org/projects/redmine/wiki/Rest_Memberships
  # @return [Hash] @see getRespObj with :obj as [Hash] with
  #   [Array] rv[:obj]["user"]["memberships"] membership objects
  #   {
  #     "user": {
  #       "memberships": [
  #         {
  #           "id": 36,
  #           "project": {
  #             "name": "ajb-kb-test2",
  #             "id": 19
  #           },
  #           "roles": [
  #             {
  #               "name": "Administrator",
  #               "id": 3
  #             }
  #           ]
  #         },
  #         ...
  #       ]
  #     }
  #   }
  def getProjectMembershipsForUser(userName)
    rv = getRespObj
    userWrap = getUserObj(userName)
    if(userWrap[:success])
      userId = userWrap[:obj]["id"]
      url = "#{@redmineUrlRoot}/users/#{CGI.escape(userId)}.json?include=memberships"
      rv = makeRequest(url, @headers)
      parseResp!(rv)
    else
      rv = userWrap
    end
    return rv
  end

  # Subset a memberships object to include only those where the user has an
  #   "Administrator" role in the project
  # @param [Array] membership objects @see http://www.redmine.org/projects/redmine/wiki/Rest_Memberships
  # @return [Array] memberships objects where user is admin
  # @raise [RedmineError] if accessing of membership role names fails
  def filterAdminMemberships(memberships)
    adminRoleName = "Administrator"
    adminMemberships = memberships.delete_if { |membership|
      rv = false
      roles = membership["roles"]
      if(roles.nil?)
        raise RedmineError.new("Cannot access role for membership=#{membership.inspect}: has the response format changed?")
      end
      roles.each { |role|
        roleName = role["name"]
        if(roleName.nil?)
          raise RedmineError.new("Cannot access role name for role=#{role.inspect}: has the response format changed?")
        end
        rv = (roleName != adminRoleName)
      }
      rv
    }
    return adminMemberships
  end

  # Subset a memberships object to include only those where the project
  #   the user is a member of has the Genboree rawcontent module enabled
  # @see filterAdminMemberships
  def filterRawContentMemberships(memberships)
    projectIdPath = "project.id"
    rawContentMemberships = memberships.delete_if { |membership|
      rv = false
      projectId = membership.getNestedAttr(projectIdPath)
      if(projectId.nil?)
        raise RedmineError.new("Cannot access project id for membership=#{membership.inspect}: has the response format changed?")
      end
      hasRawContent = rawContentOk?(projectId)
      rv = !hasRawContent
    }
    return rawContentMemberships
  end

  # Get and filter user memberships for admin memberships of projects with the Genboree raw content module
  # @see getProjectMembershipForUser
  # @see filterAdminMemberships
  # @see filterRawContentMemberships
  def getProjectMembershipsWhereAdminAndRaw(userName)
    rv = getProjectMembershipsForUser(userName)
    if(rv[:success])
      memberships = rv[:obj].getNestedAttr("user.memberships")
      if(memberships.nil?)
        rv[:success] = false
        rv[:msg] = "Cannot access memberships from parsed response: has the response format changed?"
      else
        begin
          rv[:obj] = filterAdminMemberships(memberships)
          rv[:obj] = filterRawContentMemberships(rv[:obj])
        rescue RedmineError => err
          rv[:success] = false
          rv[:msg] = err.message
        end
      end
    end
    return rv
  end

  # }} -

  # --------------------------------------------------
  # Wikis - {{
  # --------------------------------------------------

  # Create a URL to a Wiki resource of a Redmine API
  # @param [String] redmineUrlRoot the Redmine instance
  # @param [String] project the project the wiki belongs to
  # @param [String] wiki the name of the wiki
  # @todo Redmine may be doing a different transformation than CGI.escape
  #   such as transforming " " to "_" and others
  def self.getWikiUrl(redmineUrlRoot, project, wiki)
    return "#{redmineUrlRoot}/projects/#{CGI.escape(project)}/wiki/#{CGI.escape(wiki)}.json"
  end
  def getWikiUrl(project, wiki)
    self.class.getWikiUrl(@redmineUrlRoot, project, wiki)
  end

  # Get contents for a wiki
  # @see getWikiUrl
  def getWiki(project, wiki)
    url = getWikiUrl(project, wiki)
    makeRequest(url, @headers)
  end

  # Update Wiki contents with a wikiObj
  # @param [String] project @see getWikiUrl
  # @param [String] wiki @see getWikiUrl
  # @param [Hash] wikiObj a Redmine representation of a wiki page (try getWiki for example)
  # @return [Hash] @see getRespObj with :obj as [Hash] parsed Redmine wiki object
  def putWiki(project, wiki, wikiObj)
    url = getWikiUrl(project, wiki)
    uriObj = URI.parse(url)
    http = ::Net::HTTP.new(uriObj.host, uriObj.port)
    req = ::Net::HTTP::Put.new(uriObj.request_uri)
    @headers.each_key { |header|
      req[header] = @headers[header]
    }
    req.body = JSON(wikiObj)
    resp = http.request(req)
  end

  # Alternate interface to putWiki using a text string instead of a wiki object
  # @see putWiki
  def editWikiText(project, wiki, text)
    obj = {
      "wiki_page" => { 
        "text" => text
      }
    }
    resp = putWiki(project, wiki, obj)
  end

  # }} -

  # --------------------------------------------------
  # Uploads - {{
  # --------------------------------------------------

  # Get the URL to the Redmine API uploads resource
  def getUploadsUrl
    self.class.getUploadsUrl(@redmineUrlRoot)
  end
  def self.getUploadsUrl(redmineUrlRoot)
    return "#{redmineUrlRoot}/uploads.json"
  end

  # Upload a file to Redmine where it can be moved to a raw content page
  # @return [String, NilClass] return a token that can be used to make this file an attachment
  #   or a raw content file; nil if failure
  def uploadFile(filepath)
    File.open(filepath) { |fh|
      uploadIo(fh, File.size(filepath))
    }
  end

  # Upload an IO object (generalization of file handle)
  # @param [IO] ioObj the content to upload
  # @param [Integer] size the maximum number of bytes that will be read from the IO object
  #   without possible error by downstream server
  # @return @see #uploadFile
  # @note according to comments, BRL uses a version of nginx that does not support the "Transfer-Encoding"
  #   header; using a newer version of nginx would relax the requirement size argument by using
  #   Transfer-Encoding instead of Content-Length
  # @todo return token or parsed upload => token => {token} ?
  def uploadIo(ioObj, size)
    rv = getRespObj
    rv[:url] = getUploadsUrl()
    uriObj = URI.parse(rv[:url])
    http = ::Net::HTTP.new(uriObj.host, uriObj.port)
    req = ::Net::HTTP::Post.new("#{uriObj.path}?#{uriObj.query}")

    # set request headers in _add_ition to the usual @headers
    addHeaders = {
      "Content-Type" => "application/octet-stream",
      "Content-Length" => size
    }
    addHeaders = @headers.merge(addHeaders)
    addHeaders.each_key { |header|
      req[header] = addHeaders[header]
    }

    req.body_stream = ioObj
    rv[:resp] = http.request(req)
    rv[:success] = (200..299).include?(rv[:resp].code.to_i)
    if(rv[:success])
      rv[:obj] = JSON.parse(rv[:resp].body)['upload']['token']
    else
      rv = setErrorMsg(rv)
    end

    return rv
  end

  # Get an upload object (useful for moving uploaded files into raw content areas)
  # @param [String] token the upload token from #uploadFile
  # @param [String] relpath the relative path which when combined with a
  #   raw content URL provides a well-formed URI to the raw content
  def getUploadObj(token, relpath)
    return { "token" => token, "filename" => relpath }
  end

  # }} -

  # --------------------------------------------------
  # Raw Content - {{
  # --------------------------------------------------

  # Get the URL for a rawcontent file
  # @param [String] project the redmine project for the raw content file
  # @param [String] rawContentFile unescaped file path to the raw content file
  # @return [String] a url to the raw content file
  def getRawContentFileUrl(project, rawContentFile)
    return self.class.getRawContentFileUrl(@redmineUrlRoot, project, rawContentFile)
  end
  def self.getRawContentFileUrl(redmineUrlRoot, project, rawContentFile)
    rawContentTokens = rawContentFile.split("/").map { |token| CGI.escape(token) }
    escRawContentFile = rawContentTokens.join("/")
    return "#{redmineUrlRoot}/projects/#{CGI.escape(project)}/rawcontent#{escRawContentFile}"
  end

  # Get the URL for a rawcontent directory (for work with directory metadata special query string
  #   parameters are used here)
  # @param [String] project the name of a project
  # @param [String] rawContentDir the raw content directory ("/") for root
  # @todo validate rawContentDir to include initial "/" and no terminal "/"
  def getRawContentDirUrl(project, rawContentDir)
    self.class.getRawContentDirUrl(@redmineUrlRoot, project, rawContentDir)
  end
  def self.getRawContentDirUrl(redmineUrlRoot, project, rawContentDir)
    rawContentTokens = rawContentDir.split("/").map { |token| CGI.escape(token) }
    escRawContentDir = rawContentTokens.join("/")
    return "#{redmineUrlRoot}/projects/#{CGI.escape(project)}/rawcontent#{escRawContentDir}/"
  end

  # Construct payload for an upload request
  # @param [Array<Hash>] uploadObjs list of @see @getUploadObj@
  def getRawContentObj(uploadObjs)
    rawContentObj = {
      "rawcontent" => {
        "uploads" => uploadObjs
      }
    }
  end

  # Move an uploaded file into the Raw Content area
  # @param [String] rawContentDir
  # @param [Array<Hash>] uploadObjs
  # @todo test after remove of format=json query
  # @todo response object currently not wrapped in rawcontent but will be in future
  def moveRawContent(project, rawContentDir, uploadObjs)
    rv = getRespObj
    rawContentObj = getRawContentObj(uploadObjs)

    # prepare request
    rv[:url] = getRawContentDirUrl(project, rawContentDir)
    uriObj = URI.parse(rv[:url])
    http = ::Net::HTTP.new(uriObj.host, uriObj.port)
    req = ::Net::HTTP::Put.new("#{uriObj.path}?#{uriObj.query}")
    @headers.each_key { |header|
      req[header] = @headers[header]
    }
    req.body = JSON(rawContentObj)

    # make request
    rv[:resp] = http.request(req)
    rv[:success] = (200..299).include?(rv[:resp].code.to_i)
    if(rv[:success])
      rv[:obj] = JSON.parse(rv[:resp].body) rescue nil

      # interrogate moveRespObj further because the raw content HTTP API reports 200 OK even if
      # not everything is ok
      if(rv[:obj].nil?)
        rv[:msg] = "Could not parse response body as JSON; first 100 chars: #{rv[:resp].body[0...100]}"
      else
        numFail = rv[:obj]["rawcontent"]["numFail"] rescue nil
        if(numFail.nil?)
          rv[:msg] = "Could not determine the success/failure of the move operation"
        else
          if(numFail > 0)
            rv[:success] = false
            failIndexes = rv[:obj]["rawcontent"]["failures"].collect{ |failureObj| failureObj["uploadIndex"] }
            failFiles = []
            failIndexes.each { |ii|
              if((0...uploadObjs.size).include?(ii))
                failFiles.push(uploadObjs[ii]["filename"])
              end
            }
            # @note rv[:obj] has more details about the failures but that might be too verbose?
            rv[:msg] = "Failed to reanme the following remote files: #{failFiles.join(", ")}"
          end
        end
      end
    else
      rv = setErrorMsg(rv)
    end

    return rv
  end

  # Upload multiple raw content files
  # @param [String] project @see #getRawContentDirUrl
  # @param [String] rawContentDir @see #getRawContentDirUrl
  # @param [Hash<String, String>] map a local filepath to upload to its
  #   desired remote path relative to rawContentDir
  # @note this operation makes n+1 requests instead of 2n of the naive approach to
  #   (1) upload and (2) move each file because we can move multiple files with one
  #   request
  def uploadRawContentFiles(project, rawContentDir, localToRemoteMap)
    rv = getRespObj

    # @todo IO-bound, would benefit from parallelism
    localToUploadResp = {}
    localToRemoteMap.each_key { |localPath|
      localToUploadResp[localPath] = uploadFile(localPath)
    }

    # partition uploads to success/failure cases
    uploadByStatus = { :success => {}, :fail => {} }
    localToUploadResp.each_key { |localPath|
      respObj = localToUploadResp[localPath]
      if(respObj[:success])
        uploadByStatus[:success][localPath] = respObj
      else
        uploadByStatus[:fail][localPath] = respObj
      end
    }

    # move successful uploads
    uploadObjs = uploadByStatus[:success].map { |localPath, respObj|
      token = respObj[:obj]
      getUploadObj(token, localToRemoteMap[localPath])
    }
    rv = moveRawContent(project, rawContentDir, uploadObjs)

    # collect success/failure
    rv[:success] = (uploadByStatus[:fail].empty? and rv[:success])
    unless(rv[:success])
      # add any failed uploads messages to the failed moves
      if(rv[:msg].nil? or rv[:msg].empty?)
        rv[:msg] = ""
      else
        rv[:msg] << "; "
      end
      # @todo more info in uploadByStatus, log it?
      failFiles = uploadByStatus[:fail].keys()
      rv[:msg] << "Failed to upload the following local files: #{failFiles.join(", ")}"
    end

    return rv
  end

  # Upload the contents of a single IO object to the Redmine Raw Content area
  # @see #uploadRawContentFiles
  def uploadRawContentIo(project, rawContentPath, ioObj, ioSize)
    rv = getRespObj
    uploadRespObj = uploadIo(ioObj, ioSize)
    if(uploadRespObj[:success])
      token = uploadRespObj[:obj]
      uploadObj = getUploadObj(token, File.basename(rawContentPath))
      rv = moveRawContent(project, File.dirname(rawContentPath), [uploadObj])
    else
      # then error: could not retrieve upload token
      rv = uploadRespObj
    end
    return rv
  end

  # Verify that a project has the rawcontent plugin enabled
  # @param [String] project the Redmine project identifier or internal id
  # @return [Boolean] true of the Redmine project has the rawcontent plugin enabled
  # @note the current implementation of the Redmine REST API returns
  #   403 Forbidden to requests made on sub-project resources that
  #   do not exist (perhaps they exist but we just do not have permission to see them);
  #   this is true even for the admin user
  def rawContentOk?(project)
    rv = getRespObj
    url = getRawContentDirUrl(project, "/")
    $stderr.debugPuts(__FILE__, __method__, "VERBOSE", "Making request at #{url.inspect}") if(@verbose)
    respObj = makeRequest(url, @headers)
    rv = respObj[:success]
    return rv
  end

  # }} -

  # --------------------------------------------------
  # User - {{
  # --------------------------------------------------

  # Get full user object (including id for use by other functions) associated
  #   with a userName
  # @param [String] userName
  # @return [Hash] @see getRespObj with :obj as a [Hash] like the following:
  #   "created_on": "2014-07-23T15:02:42Z",
  #   "id": 13,
  #   "lastname": "Baker",
  #   "mail": "ab4@bcm.edu",
  #   "firstname": "Aaron",
  #   "login": "aaron_baker",
  #   "last_login_on": "2015-11-02T16:48:28Z"
  # @see http://www.redmine.org/projects/redmine/wiki/Rest_Users
  def getUserObj(userName)
    url = "#{@redmineUrlRoot}/users.json?name=#{CGI.escape(userName)}"
    rv = makeRequest(url, @headers)
    parseResp!(rv)
    if(rv[:success])
      # check for exact userName match, error otherwise (name query string
      # parameter searches all fields in user object)
      rv[:obj] = rv[:obj]["users"].find { |userObj|
        userObj["login"] == userName
      }
      if(rv[:obj].nil?)
        # then no match found
        rv[:success] = false
        rv[:msg] = "Unable to find exact userName match in response body"
      end
    end
    return rv
  end

  # Retrieve a list of users that Redmine requests can be made on behalf of
  def getUsers
    url = File.join(@redmineUrlRoot, "users.json")
    makeRequest(url, @headers)
  end

  # }} -

  # --------------------------------------------------
  # Private - {{
  # --------------------------------------------------

  # Provide uniform response interface for methods in this class
  # @return [Hash] response wrapper object with keys
  #   [String] :msg error message if failure
  #   [Hash, Array] :obj JSON-parsed response body
  #   [Net::HTTPResponse] :resp response object for request at :url
  #   [Boolean] :success true if request succeeded
  #   [String] :url the URL the request was made at
  # @todo make http-based methods here return this object interface
  def getRespObj
    self.class.getRespObj
  end
  def self.getRespObj
    rv = {
      :msg => nil,
      :obj => nil,
      :resp => nil,
      :success => false,
      :url => nil
    }
  end

  # Set error message for a respObj
  # @param [Hash] respObj @see getRespObj
  # @param [Integer] bodyChars number of characters from response body to include in error message;
  #   may be -1 for all characters
  # @return [NilClass]
  # @see [BRL::Genboree::REST::Helpers::ApiUriHelper#setErrorMsg]
  # @todo code reuse with ApiUriHelper? this method is copy
  def setErrorMsg(respObj, bodyChars=100)
    self.class.setErrorMsg(respObj, bodyChars)
  end
  def self.setErrorMsg(respObj, bodyChars=100)
    bodyChars = ( bodyChars > 0 ? bodyChars - 1 : -1 )
    sizeMsg = ( bodyChars > 0 ? "first #{bodyChars+1} characters of response body:" : "full response body:" )
    respObj[:msg] = "Request at #{respObj[:url].inspect} failed with code #{respObj[:resp].code.inspect}; #{sizeMsg} #{respObj[:resp].body[0..bodyChars]}" rescue nil
    respObj[:msg] = "Could not format error message: is respObj the return value from #getRespObj?" if(respObj[:msg].nil?)
    return respObj
  end

  # Perform a GET request at URL with the given headers
  # @todo other request types?
  # @todo depage redmine responses?
  def requestWrapper(url, headers)
    uriObj = URI.parse(url)
    http = ::Net::HTTP.new(uriObj.host, uriObj.port)
    resp = http.get("#{uriObj.path}?#{uriObj.query}", headers)
  end

  # Fill getRespObj with information from a request
  # @todo rename to requestWrapper, change functions using requestWrapper
  # @note not all requests respond with JSON so we leave setting of :obj to specific functions
  def makeRequest(url, headers=@headers)
    self.class.makeRequest(url, headers)
  end
  def self.makeRequest(url, headers)
    rv = getRespObj
    rv[:url] = url
    uriObj = URI.parse(url)
    http = ::Net::HTTP.new(uriObj.host, uriObj.port)
    if(uriObj.scheme == "https")
      http.use_ssl = true
    end
    pathAndQuery = uriObj.path
    if(!uriObj.query.nil?)
      pathAndQuery << "?#{uriObj.query}"
    end
    rv[:resp] = http.get(pathAndQuery, headers)
    if((200..299).include?(rv[:resp].code.to_i))
      rv[:success] = true
    else
      rv[:msg] = setErrorMsg(rv)
    end
    return rv
  end

  # Return modified respObj based on success/failure of JSON parsing
  # @param [Hash] respObj @see getRespObj
  # @param [Integer] nChars number of characters to include in response body message
  def self.parseResp!(respObj, nChars=100)
    if(respObj[:success])
      respObj[:obj] = JSON.parse(respObj[:resp].body) rescue nil
      if(respObj[:obj].nil?)
        respObj[:success] = false
        respObj[:msg] = "Could not parse response body as JSON; first #{nChars} of response body: #{respObj[:resp].body[0...nChars]}"
      end
    end
    return respObj
  end
  def parseResp!(respObj, nChars=100)
    self.class.parseResp!(respObj, nChars)
  end

  # Add any additional HTTP request context needed to fulfill a request
  #   including (especially) HTTP request headers handled by this class
  # @param [Net::HTTPRequest] httpRequestObj already initialized with #path
  def requestWithObj(httpRequestObj)
    uriObj = URI.parse(@redmineUrlRoot)
    http = ::Net::HTTP.new(uriObj.host, uriObj.port)
    @headers.each_key { |header|
      httpRequestObj[header] = @headers[header]
    }
    resp = http.request(httpRequestObj)
  end

  # }} -
end

# Runtime errors specific to the BRL::Sites::Redmine class
class RedmineError < RuntimeError
end
end; end
