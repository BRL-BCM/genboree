require 'yaml'
require 'json'
require 'uri'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'plugins/genboree_kbs/app/helpers/async_bioportal_helper'
require 'brl/sites/bioOntology'
require 'brl/sites/emBioOntology'
require 'brl/rest/apiCaller'
require 'brl/util/util'
include BRL::REST

class GenboreeKbDocController < ApplicationController
  include GenboreeKbHelper

  unloadable

  SEARCH_LIMIT = 20

  respond_to :json

  def show()
    t1 = Time.now
    rsrcPath  = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}"
    collName  = params['collectionSet']
    docId     = params['itemId']
    docVersion = params['docVersion']
    fieldMap  = { :coll => collName, :doc => docId } # :grp & :kb auto-filled for us if we don't supply them
    if(!docVersion.empty?) # get the specific version of the document if required
      rsrcPath << "/ver/{ver}?detailed=true&contentFields={cf}"
      fieldMap[:ver] = docVersion
      fieldMap[:cf] = ['.']
    end
    apiResult  = apiGet(rsrcPath, fieldMap)
    resp = {}
    if(docVersion.empty?)
      resp = apiResult[:respObj]
    else
      resp = { "data" => apiResult[:respObj]['data']['versionNum']['properties']['content']['value'] }
    end
    jsonResp = JSON.generate(resp)
    render(:json => jsonResp, :content_type => "text/html", :status => apiResult[:status])
  end

  def download()
    downloadFormat = params['download_format']
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}"
    jsonResp = true
    version = params['docVersion']
    if( downloadFormat != 'json' )
      rsrcPath << "?format=#{downloadFormat}"
      rsrcPath << "&versionNum=#{CGI.escape(version)}" if(version != "")
      jsonResp = false
    else
      rsrcPath << "?versionNum=#{CGI.escape(version)}" if(version != "")
    end
    collName  = params['collectionSet']
    docId     = params['itemId']
    fieldMap  = { :coll => collName, :doc => docId } # :grp & :kb auto-filled for us if we don't supply them
    apiResult  = apiGet(rsrcPath, fieldMap, jsonResp)
    resp = nil
    fileExt = nil
    if(downloadFormat == 'json')
      resp = JSON.pretty_generate(apiResult[:respObj]['data'])
      fileExt = 'json'
    else
      resp = apiResult[:respObj]
      fileExt = ( downloadFormat =~ /nesting/ ?  'compact.tsv' : 'fullPath.tsv' )
    end
    send_data(resp, :filename => "#{docId.makeSafeStr(:ultra)}.#{fileExt}", :type => "application/octet", :disposition => "attachment")
  end

  # Controller method for supporting document search in a collection.
  def search()
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "search NVPs:\n\n#{params.inspect}\n\n")
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?limit={lim}"
    collName = params['coll']
    limit = params['limit']
    startIdx = params['start']
    page = params['page']
    fieldMap = { :coll => collName, :lim => limit }
    searchStr = params['searchStr'].to_s.strip
    if(searchStr =~ /\S/)
      rsrcPath << "&matchValue={val}&matchMode=keyword"
      fieldMap[:val] = searchStr
    end
    apiResult = apiGet(rsrcPath, fieldMap)
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end

  # Controller method for supporting 'search-as-you-type' lookup for the 'bioportal' domain
  def biopsearch
    domainInfoStr = params['url']
    limit = params['limit'].to_i
    searchStr = params['searchStr'].to_s.strip
    # Get an instance of the BioOntology class
    respObj = nil
    if(domainInfoStr =~ /\(/)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "domainInfo param: #{domainInfoStr.inspect}\n    limit param: #{limit.inspect}\n    searchStr param: #{searchStr.inspect}")
      ontArr = []
      subTreeArr = []
      domainInfoStr.scan(/\(\s*([^\),]+?)\s*,\s*([^\),]+?)\s*\)/) { |pairArray|
        ontArr.push(pairArray.first)
        subTreeArr.push(pairArray.last)
      }
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "After parsing 'url' parameter, have:\n  termArr:\n    #{ontArr.join("\n    ")}\n  urlArr:\n    #{subTreeArr.join("\n    ")}")
      bioOnt = BRL::Sites::BioOntology.new(ontArr, subTreeArr, nil)
      respObj = bioOnt.requestTermsByNameViaSubtree(searchStr, true, limit)
    else
      bioOnt = BRL::Sites::BioOntology.fromUrl(domainInfoStr, { :proxyHost => ENV['PROXY_HOST'], :proxyPort => ENV['PROXY_PORT'] })
      bioOnt.debug = true
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Starting bioontology query with URL: #{domainInfoStr.inspect}.")
      begin
        if(domainInfoStr =~ /subtree_root/)
          respObj = bioOnt.requestTermsByNameViaSubtree(searchStr, true, limit)
        else
          respObj = bioOnt.requestTermsByName(searchStr, true, limit)
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", err)
        respObj = nil
      end
    end
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Bioontology query done.")
    status = 200
    resp = []
    if(respObj.nil?)
      resp = {}
      status = 404
    else
      ii = 0
      respObj.each { |obj|
        ii += 1
        id = obj['@id'] ? obj['@id'] : ""
        type = obj['@type'] ? obj['@type']  : ""
        synonym = "[NONE]"
        if(obj['synonym'] and obj['synonym'].is_a?(Array))
          synonym = obj['synonym'].join(",")
        end
        definition = "[NONE]"
        if(obj['definition'] and obj['definition'].is_a?(Array))
          definition = obj['definition'].join("</br>")
        end
        prefLabel = obj['prefLabel']
        resp.push( { 'prefLabel' => prefLabel, 'id' => id, 'type' => type, 'definition' => definition, 'synonym' => synonym, 'divId' => Time.now.to_f} )
        break if(ii == limit)
      }
      respJson = resp.to_json
      resp = JSON.parse(respJson)
    end
    respond_with(resp, :status => status)
  end
  
  def asyncBioPortalSearch()
    domainInfoStr = params['url']
    limit = params['limit'].to_i
    searchStr = params['searchStr'].to_s.strip
    queryType = :singleOntology
    if(domainInfoStr =~ /\(/)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "domainInfo param: #{domainInfoStr.inspect}\n    limit param: #{limit.inspect}\n    searchStr param: #{searchStr.inspect}")
      ontArr = []
      subTreeArr = []
      domainInfoStr.scan(/\(\s*([^\),]+?)\s*,\s*([^\),]+?)\s*\)/) { |pairArray|
        ontArr.push(pairArray.first)
        subTreeArr.push(pairArray.last)
      }
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "After parsing 'url' parameter, have:\n  termArr:\n    #{ontArr.join("\n    ")}\n  urlArr:\n    #{subTreeArr.join("\n    ")}")
      bioOntHelper = AsyncBioportalHelper.new(ontArr, subTreeArr, searchStr, true, limit)
      queryType = :multipleOntologies
    else
      bioOntHelper = AsyncBioportalHelper.new(nil, nil, searchStr, true, limit)
      bioOntHelper.domainInfoStr = domainInfoStr
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Starting bioontology query.")
    end
    bioOntHelper.env = env
    EM.next_tick {
      bioOntHelper.start(queryType)
    }
    throw :async
  end

  # Controller method used for getting an initial list of identifiers when a collection is selected in the UI
  def initialDocList
    collName = params['collectionSet']
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?limit=20"
    fieldMap = { :coll => collName } # :grp & :kb auto-filled for us if we don't supply them
    apiResult = apiGet( rsrcPath, fieldMap )
    $stderr.puts "apiResult: #{apiResult.inspect}"
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def save()
    collName = params['collectionSet']
    docId = params['identifier']
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}"
    fieldMap = { :coll => collName, :doc => docId }
    apiResult = apiPut(rsrcPath, params['data'], fieldMap)
    respond_with(apiResult[:respObj], :status => apiResult[:status], :location => "")
  end

  def delete()
    collName = params['collectionSet']
    docId = params['identifier']
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}?"
    fieldMap = { :coll => collName, :doc => docId }
    apiResult = apiDelete(rsrcPath, fieldMap)
    respond_with(apiResult[:respObj], :status => apiResult[:status], :location => "")
  end

  # Controller method for supporting file downloads for properties with 'fileUrl' domain
  def downloadfile
    url = params['fileUrl']
    rsrcPath = URI.parse(url).path
    fileName = rsrcPath.split("/").last
    rsrcPath << "/data?"
    # Get the full url that the em-http-request client will use to stream the data using the ApiCaller
    fullApiUrl = returnFullApiUrl(rsrcPath, {})
    asyncHeader = {}
    asyncHeader['Content-Type'] = "text/plain"
    asyncHeader['Content-disposition'] = "attachment; fileName=\"#{CGI.unescape(fileName)}\""
    asyncResp = GenboreeKbHelper::EMHTTPAsyncResp.new(env, 200, asyncHeader, fullApiUrl)
    EM.next_tick do
      asyncResp.start()
    end
    throw :async
  end
  
  def checkFile()
    url = params['fileUrl']
    urlObj = URI.parse(url)
    rsrcPath = urlObj.path
    gbHost = urlObj.host
    fileName = rsrcPath.split("/").last
    apiResult = apiGet( rsrcPath, {}, true, gbHost )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end

  # Controller method for supporting file uploads for properties with 'fileUrl' domain
  def uploadfile
    group = params['gbGroup']
    db = params['kbDb']
    folder = params['displayTargetFolderSelector']
    escFilePath = ""
    filePath = []
    fileName = params['fileBaseName']
    if(!folder.nil? and !folder.empty?)
      tmpFilePath = folder.chomp("/").gsub(/^\//, "")
      tmpFilePath.split("/").each { |ff|
        filePath << CGI.escape(ff)
      }
      escFilePath = filePath.join("/")
      escFilePath << "/#{CGI.escape(fileName)}"
    else
      escFilePath = CGI.escape(fileName)
    end
    rsrcPath = "/REST/v1/grp/{grp}/db/{db}/file/#{escFilePath}/data?"
    fieldMap = { :grp => group, :db => db }
    # Get the full url that the em-http-request client will use to stream the data using the ApiCaller
    fullApiUrl = returnFullApiUrl(rsrcPath, fieldMap)
    asyncHeader = {}
    asyncHeader['Content-Type'] = "text/html"
    asyncResp = GenboreeKbHelper::EMHTTPAsyncResp.new(env, 202, asyncHeader, fullApiUrl)
    uploadFilePath = request.headers['HTTP_X_GB_UPLOADED_FILE']
    # Get the boundary used in the multi-part mime file. Required by Andrew's EM de-encoding library
    gbUploadContentType = request.headers['HTTP_X_GB_UPLOADED_CONTENT_TYPE']
    GenboreeKbHelper::BOUNDARY_EXTRACTOR =~ gbUploadContentType
    formBoundary = $1.dup
    formBoundary = "--"+formBoundary
    asyncHeader = {}
    asyncHeader['Content-Type'] = "text/html"
    asyncResp = GenboreeKbHelper::EMHTTPAsyncResp.new(env, 202, asyncHeader, fullApiUrl)
    asyncResp.uploadFilePath = uploadFilePath
    asyncResp.db = db
    asyncResp.grp = getGroup()
    asyncResp.host = getHost()
    asyncResp.formBoundary = formBoundary
    # We will do the actual upload of the file using async approaches.
    #   - The upload will be done AFTER returning a response to the client immediately.
    EM.next_tick do
      asyncResp.start('put', false)
    end
    throw :async
  end

  def contentgen()
    coll = params['collectionSet']
    doc = params['doc']
  end
end
