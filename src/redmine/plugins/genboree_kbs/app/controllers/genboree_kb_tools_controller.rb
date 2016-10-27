require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'brl/rest/apiCaller'
require 'brl/util/util'
include BRL::REST

class GenboreeKbToolsController < ApplicationController
  include GenboreeKbHelper

  unloadable

  respond_to :json

  
  def run()
    coll = params['collectionSet']
    scope = params['scope']
    toolIdStr = params['toolIdStr']
    #rsrcPath = ( scope == 'collection' ? "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/tool" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}/tool" )
    #fieldMap =  { :coll => coll }
    #apiResult = apiGet( rsrcPath, fieldMap )
    #respond_with(apiResult[:respObj], :status => apiResult[:status])
    respond_with({}, 200)
  end
  
  def summary
    tool = params['tool']
    rsrcPath = "/REST/v1/jobs?detailed=summary&toolIdStrs=#{tool}"
    apiResult = apiGet( rsrcPath )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
end
