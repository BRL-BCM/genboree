require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'brl/rest/apiCaller'
require 'brl/util/util'
include BRL::REST

class GenboreeKbModelController < ApplicationController
  include GenboreeKbHelper

  unloadable

  respond_to :json

  def show()
    collName = params['collectionSet']
    version = params['version']
    fieldMap = { :coll => collName, :ver => version } # :grp & :kb auto-filled for us if we don't supply them
    rsrcPath = (version == "" ? "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model/ver/{ver}" )
    apiResult = apiGet( rsrcPath, fieldMap )
    #$stderr.puts "API MODEL RESP:\n\n#{JSON.pretty_generate(apiResult[:respObj]) rescue apiResult[:respObj].inspect}\n\n"
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def download()
    collName = params['collectionSet']
    version = params['modelVersion']
    format = params['download_format']
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model"
    jsonResp = true
    if(format != 'json')
      rsrcPath << "?format=#{format}"
      rsrcPath << "&versionNum=#{CGI.escape(version)}" if(version != "")
      jsonResp = false
    else
      rsrcPath << "?versionNum=#{CGI.escape(version)}"  if(version != "")
    end
    fieldMap = { :coll => collName, :ver => version } # :grp & :kb auto-filled for us if we don't supply them
    apiResult = apiGet( rsrcPath, fieldMap, jsonResp )
    respBody = nil
    fileExt = nil
    if(format == 'json')
      respBody = JSON.pretty_generate(apiResult[:respObj]['data']) 
      fileExt = 'json'
    else
      respBody = apiResult[:respObj]
      fileExt = ( format =~ /nesting/ ? 'compact.tsv' : 'fullPath.tsv' )
    end
    send_data(respBody, :filename => "#{collName.makeSafeStr(:ultra)}.model.#{fileExt}", :type => "application/octet", :disposition => "attachment")
  end
  
  def table()
    apiResult = apiGet( "/REST/v1/grp/atest/db/a1/file/model.json/data?" )
    $stderr.puts "API MODEL RESP:\n\n#{JSON.pretty_generate(apiResult[:respObj]) rescue apiResult[:respObj].inspect}\n\n"
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def save()
    collName = params['collectionSet']
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model"
    fieldMap = { :coll => collName }
    apiResult = apiPut(rsrcPath, params['data'], fieldMap)
    #$stderr.puts "API SAVE RESP:\n\n#{JSON.pretty_generate(apiResult[:respObj]) rescue apiResult[:respObj].inspect}\n\n"
    respond_with(apiResult[:respObj], :status => apiResult[:status], :location => "")
  end
  
  def collshow()
    coll = params['collectionSet']
    rsrcPath= "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}"
    fieldMap =  { :coll => coll }
    apiResult = apiGet( rsrcPath, fieldMap )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end

end
