require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'brl/rest/apiCaller'
require 'brl/util/util'
include BRL::REST

class GenboreeKbViewController < ApplicationController
  include GenboreeKbHelper

  unloadable

  respond_to :json

  # Generates a view based on the view document and the parameters provided by the user
  # The view is essentially the document id column along with some of the selected properties as the other columns.
  def generateview
    group = params['gbGroup']
    kb = params['kbName']
    coll = params['collectionSet']
    query = params['viewFormQuery-inputEl']
    mode = params['viewFormMode-inputEl']
    view = params['viewFormView-inputEl']
    term = params['viewFormTerm']
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?matchView={view}"
    rsrcPath << "&matchMode={mode}&matchValue={term}&matchQuery={query}&detailed=true&limit=1000"
    fieldMap = { :grp => group, :kb => kb, :coll => coll, :view => view, :mode => mode, :term => term, :query => query }
    apiResult = apiGet(rsrcPath, fieldMap)
    # The following is required since ExtJS expects the response to be in JSON 
    # Otherwise it deems the request to be a failure. 
    jsonResp = {}
    status = apiResult[:status]
    if(status == 200 or status == 201 or status == 202)
      jsonResp = { 'success' => true, 'data' => apiResult[:respObj]['data']}
    else
      jsonResp = { 'success' => false, 'msg' => apiResult[:respObj]['status']['msg']}
      $stderr.puts "Call to get docs with view: #{view} failed.\n\nERROR:\n#{apiResult.inspect}"
    end
    render(:json => jsonResp.to_json, :content_type => "text/html", :status => status)
  end
  
  # Gets the list of saved queries to present to the user
  def getqueries()
    apiResult = apiGet( "/REST/v1/grp/{grp}/kb/{kb}/queries" )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def download()
    collName = params['collectionSet']
    format = params['download_format']
    matchQuery = params['matchQuery']
    matchView = params['matchView']
    matchValue = params['matchValue']
    matchMode = params['matchMode']
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?format={format}&matchValue={matchValue}&matchQuery={matchQuery}&matchView={matchView}&matchMode={matchMode}&gbEnvelope=false"
    jsonResp = true
    fileExt = 'json'
    if(format !~ /json/i)
      jsonResp = false
      fileExt = "tsv"
    end
    fieldMap = { :format => format, :coll => collName, :matchMode => matchMode, :matchView => matchView, :matchQuery => matchQuery, :matchValue => matchValue } # :grp & :kb auto-filled for us if we don't supply them
    fileName = "#{collName.makeSafeStr(:ultra)}.#{matchQuery.makeSafeStr(:ultra)}.#{matchView.makeSafeStr(:ultra)}.#{matchMode.makeSafeStr(:ultra)}.#{matchValue.makeSafeStr(:ultra)}.#{fileExt}"
    # Get the full url that the em-http-request client will use to stream the data using the ApiCaller
    fullApiUrl = returnFullApiUrl(rsrcPath, fieldMap)
    asyncHeader = {}
    asyncHeader['Content-Type'] = "text/plain"
    asyncHeader['Content-disposition'] = "attachment; fileName=#{fileName}"
    asyncResp = GenboreeKbHelper::EMHTTPAsyncResp.new(env, 200, asyncHeader, fullApiUrl)
    EM.next_tick do
      asyncResp.start()
    end
    throw :async
  end
  
  
  # Gets the list of saved views to present to the user
  def getviews()
    apiResult = apiGet( "/REST/v1/grp/{grp}/kb/{kb}/views?type=flat" )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def getview()
    apiResult = apiGet( "/REST/v1/grp/{grp}/kb/{kb}/view/{view}", { :view => params['view']} )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
end
