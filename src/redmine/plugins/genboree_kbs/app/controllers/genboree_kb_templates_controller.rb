require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'brl/rest/apiCaller'
require 'brl/util/util'
include BRL::REST

class GenboreeKbTemplatesController < ApplicationController
  include GenboreeKbHelper

  unloadable

  SEARCH_LIMIT = 20

  respond_to :json

  def templates()
    coll = params['collectionSet']
    rsrcPath= "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/templates?docIdentAsRootOnly=true"
    fieldMap =  { :coll => coll }
    apiResult = apiGet( rsrcPath, fieldMap )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def template()
    coll = params['collectionSet']
    templateId = params['templateId']
    rsrcPath= "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/template/{id}"
    fieldMap =  { :coll => coll, :id => templateId }
    apiResult = apiGet( rsrcPath, fieldMap )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def propVals()
    coll = params['collectionSet']
    propPaths = params['propPaths']
    templateId = params['templateId']
    rsrcPath= "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/template/{id}/propPathsValue"
    fieldMap =  { :coll => coll, :id => templateId }
    payload = []
    propPathsArr = propPaths.split(",")
    propPathsArr.each {|propPath|
      payload.push( { 'text' => propPath } )  
    }
    apiResult = apiGet( rsrcPath, fieldMap, true, nil, payload )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  
end

