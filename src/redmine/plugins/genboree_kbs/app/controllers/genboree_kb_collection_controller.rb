require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'

require 'brl/rest/apiCaller'
require 'brl/util/util'
include BRL::REST

class GenboreeKbCollectionController < ApplicationController
  # Include helper module (app/helpers)
  include GenboreeKbHelper

  unloadable

  respond_to :json, :html
  
  

  ############# Action Controllers ################
  
  # The index page for the GenboreeKB plugin
  # Will redirect to the login page if user is not logged in
  def index()
    projectId = params[:project_id]
    @project = Project.find(projectId)
    @collection = params['coll'] || ''
    @docIdentifier = params['doc'] || ''
    @prop = params['prop'] || ''
    @docVersion = params['docVersion'] || ''
    @modelVersion = params['modelVersion'] || ''
    @matchQuery = params['matchQuery'] || ''
    @matchView = params['matchView'] || ''
    @matchMode = params['matchMode'] || ''
    @matchValue = params['matchValue'] || ''
    @showModelTree = ( params['showModelTree'] and params['showModelTree'] == 'true' ) ? true : false
    @showViewGrid = ( params['showViewGrid'] and params['showViewGrid'] == 'true' ) ? true : false
    @showDocsVersionsGrid = ( params['showDocsVersionsGrid'] and params['showDocsVersionsGrid'] == 'true' ) ? true : false
    @showModelVersionsGrid = ( params['showModelVersionsGrid'] and params['showModelVersionsGrid'] == 'true' ) ? true : false
    @createNewDoc = ( params['createNewDoc'] and params['createNewDoc'] == 'true' ) ? true : false
    @createNewDocWithTemplate = ( params['createNewDocWithTemplate'] and params['createNewDocWithTemplate'] == 'true' ) ? true : false
    @templateId = params['templateId'] || ''
    @kbMount = RedmineApp::Application.routes.default_scope[:path]
    # If the page is being accessed without logging in, redirect user to login page
    # If the original URL was pointing to a particular document and/or collection,
    # build a back_url paramater to provide with the redirect link
    if(User.current.login.nil? or User.current.login == "")
      @genboreeKb = GenboreeKb.find_by_project_id(@project)
      backUrl = nil
      authRec = []
      if(@genboreeKb)
        host = @genboreeKb.gbHost.strip
        backUrl = constructBackUrl(projectId)
        authRec = getUserInfo(host)
      end
      redirectUrl = "#{@kbMount}/login?"
      redirectUrl << "back_url=#{CGI.escape(backUrl)}" if(backUrl)
      if(authRec[0].nil?)
        redirect_to redirectUrl    
      else
        getCollList()
      end
    else
      getCollList()
    end
  end
  
  
  
  def getCollList()
    apiResult = apiGet( "/REST/v1/grp/{grp}/kb/{kb}" )
    unless(apiResult[:respObj] and apiResult[:respObj]['data'])
      @collectionList = []
    else
      collList = apiResult[:respObj]['data']['name']['properties']['collections']['items']
      collList = [] unless(collList)
      resp = []
      collList.each {|collObj|
        resp.push( {'text' => { 'value' => collObj['collection']['value']} })  
      }
      @collectionList = resp
      @kbDescription = ""
      if(apiResult[:respObj]['data']['name']['properties'].key?('description'))
        @kbDescription = apiResult[:respObj]['data']['name']['properties']['description']['value']
      end
    end
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  
  
  # Controller method for downloading all the documents in a collection
  # Response is streamed back to the client
  def download
    collName = params['collectionSet']
    format = params['download_format']
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?detailed=true&gbEnvelope=false&format=#{format}"
    fileExt = 'json'
    if(format !~ /json/i)
      fileExt = 'tsv'
    end
    fieldMap = { :coll => collName } # :grp & :kb auto-filled for us if we don't supply them
    # Get the full url that the em-http-request client will use to stream the data using the ApiCaller
    fullApiUrl = returnFullApiUrl(rsrcPath, fieldMap)
    asyncHeader = {}
    asyncHeader['Content-Type'] = "text/plain"
    asyncHeader['Content-disposition'] = "attachment; fileName=#{collName.makeSafeStr(:ultra)}.docs.#{fileExt}"
    asyncResp = GenboreeKbHelper::EMHTTPAsyncResp.new(env, 200, asyncHeader, fullApiUrl)
    EM.next_tick do
      asyncResp.start()
    end
    throw :async
  end
  
  
  
  
  
  # Controller method for supporting uploading a file containing kb docs.
  #    - Uses the async feature to do upload as a deferred process and returns to client immediately.
  #    - Uses the callback feature of em-http-response to then submit kb bulk upload job after file is uploaded.
  def uploaddocs
    group = params['gbGroup']
    kb = params['kbName']
    db = params['kbDb']
    coll = params['collectionSet']
    format = constructFormatForUrl(params['format-inputEl'])
    $stderr.puts "format: #{format.inspect}"
    fileName = params['fileBaseName']
    host = getHost()
    userRecs = getUserInfo(host)
    filePath = "Raw%20Data%20Files/KB/#{CGI.escape(userRecs[0])}-#{CGI.escape(Time.now().to_s)}/#{CGI.escape(fileName)}"
    rsrcPath = "/REST/v1/grp/{grp}/db/{db}/file/#{filePath}/data?"
    fieldMap = { :grp => group, :db => db  }
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "uploading file via API")
    asyncResp = getAsyncRespObj(kb, db, coll, host, format, rsrcPath, fieldMap, filePath)
    # We will do the actual upload of the file using async approaches.
    #   - The upload will be done AFTER returning a response to the client immediately.
    #   - As a callback of that upload, we will submit the Kb Bulk Upload job. 
    EM.next_tick do
      asyncResp.start('put')
    end
    throw :async
  end
  
  def show()
    coll = params['collectionSet']
    rsrcPath= "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}"
    fieldMap =  { :coll => coll }
    apiResult = apiGet( rsrcPath, fieldMap )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  ################### HELPER METHODS ##############################
  
  def constructBackUrl(projectId)
    backUrl = "http://#{request.host}#{@kbMount}/genboree_kbs?project_id=#{projectId}"
    # Add all other additional params if provided in the URL
    backUrl << "&coll=#{CGI.escape(@collection)}" if(!@collection.empty?)
    backUrl << "&doc=#{CGI.escape(@docIdentifier)}" if(!@collection.empty? and !@docIdentifier.empty?)
    backUrl << "&docVersion=#{CGI.escape(@docVersion)}" if(@docVersion != "")
    backUrl << "&prop=#{CGI.escape(@prop)}" if(!@collection.empty? and !@docIdentifier.empty? and !@prop.empty?)
    backUrl << "&modelVersion=#{CGI.escape(@modelVersion)}" if(@modelVersion != "")
    backUrl << "&modelVersion=#{CGI.escape(@modelVersion)}" if(@modelVersion != "")
    backUrl << "&matchQuery=#{CGI.escape(@matchQuery)}" if(@matchQuery != "")
    backUrl << "&matchView=#{CGI.escape(@matchView)}" if(@matchView != "")
    backUrl << "&matchMode=#{CGI.escape(@matchMode)}" if(@matchMode != "")
    backUrl << "&matchValue=#{CGI.escape(@matchValue)}" if(@matchValue != "")
    backUrl << "&showModelTree=true" if(@showModelTree)
    backUrl << "&showDocsVersionsGrid=true" if(@showDocsVersionsGrid)
    backUrl << "&showModelVersionsGrid=true" if(@showModelVersionsGrid)
    backUrl << "&showViewGrid=true" if(@showViewGrid)
    backUrl << "&createNewDoc=true" if(@createNewDoc)
    backUrl << "&createNewDocWithTemplate=true" if(@createNewDocWithTemplate)
    backUrl << "&templateId=#{CGI.escape(@templateId)}" if(@templateId != "")
    return backUrl
  end
  
  
  def getAsyncRespObj(kb, db, coll, host, format, rsrcPath, fieldMap, filePath)
    # Get the full url that the em-http-request client will use to stream the data using the ApiCaller
    fullApiUrl = returnFullApiUrl(rsrcPath, fieldMap)
    # Get the path to the multi-part mime file on disk. We will de encode this file using EM
    uploadFilePath = request.headers['HTTP_X_GB_UPLOADED_FILE']
    # Get the boundary used in the multi-part mime file. Required by Andrew's EM de-encoding library
    gbUploadContentType = request.headers['HTTP_X_GB_UPLOADED_CONTENT_TYPE']
    $stderr.puts "gbUploadContentType: #{gbUploadContentType.inspect}"
    GenboreeKbHelper::BOUNDARY_EXTRACTOR =~ gbUploadContentType
    formBoundary = $1.dup
    formBoundary = "--"+formBoundary
    asyncHeader = {}
    asyncHeader['Content-Type'] = "text/html"
    asyncResp = GenboreeKbHelper::EMHTTPAsyncResp.new(env, 202, asyncHeader, fullApiUrl)
    asyncResp.uploadFilePath = uploadFilePath
    asyncResp.kb = kb
    asyncResp.db = db
    asyncResp.coll = coll
    asyncResp.grp = getGroup()
    asyncResp.host = host
    asyncResp.genbFilePath = filePath
    asyncResp.format = format
    asyncResp.formBoundary = formBoundary
    asyncResp.apiCaller = getApiCaller("", {})
    return asyncResp
  end
  
  def constructFormatForUrl(format)
    if(format == 'JSON')
      format = 'json'
    elsif(format == 'TABBED - Compact Property Names')
      format = 'tabbed_prop_nesting'
    elsif(format == 'TABBED - Full Property Names')
      format = 'tabbed_prop_path'
    elsif(format == 'Tabbed (Multi) - Compact Property Names')
      format = 'tabbed_multi_prop_nesting'
    end
    return format
  end
  
end
