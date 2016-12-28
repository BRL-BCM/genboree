require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'brl/rest/apiCaller'
require 'brl/util/util'
include BRL::REST

class GenboreeKbStatsController < ApplicationController
  include GenboreeKbHelper

  unloadable

  respond_to :json


  def stat()
    resp = nil
    scope = params['scope']
    statType = params['statType']
    rsrcPath = ""
    fieldMap = {}
    jsonResp = false
    if(statType == 'docsPerColl')
      rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/colls/stat/docCount?format=hcColumn&scale=linear"
    elsif (statType == 'docCountOverTime')
      rsrcPath = (scope =='kb' ? "/REST/v1/grp/{grp}/kb/{kb}/stat/docCountOverTime?format=hcLine&cumulative=true&scale=linear" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/stat/docCountOverTime?format=hcLine&cumulative=true&scale=linear")
    elsif(statType == 'activityOverTime')
      rsrcPath = (scope =='kb' ? "/REST/v1/grp/{grp}/kb/{kb}/stat/versionCountOverTime?format=hcColumn&cumulative=false&scale=linear" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/stat/versionCountOverTime?format=hcColumn&cumulative=false&scale=linear")
    elsif(statType == 'createCountOverTime')
      rsrcPath = (scope =='kb' ? "/REST/v1/grp/{grp}/kb/{kb}/stat/createCountOverTime?format=hcColumn&cumulative=false&scale=linear" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/stat/createCountOverTime?format=hcColumn&cumulative=false&scale=linear")
    elsif(statType == 'editCountOverTime')
      rsrcPath = (scope =='kb' ? "/REST/v1/grp/{grp}/kb/{kb}/stat/editCountOverTime?format=hcColumn&cumulative=false&scale=linear" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/stat/editCountOverTime?format=hcColumn&cumulative=false&scale=linear")
    elsif(statType == 'deleteCountOverTime')
      rsrcPath = (scope =='kb' ? "/REST/v1/grp/{grp}/kb/{kb}/stat/deleteCountOverTime?format=hcColumn&cumulative=false&scale=linear" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/stat/deleteCountOverTime?format=hcColumn&cumulative=false&scale=linear")
    elsif(statType == 'pointStats')
      rsrcPath = ( scope == 'kb' ? "/REST/v1/grp/{grp}/kb/{kb}/stat/allPointStats" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/stat/allPointStats")
      jsonResp = true
    end
    fieldMap[:coll] = params['collection'] if(scope == 'coll')
    apiResult  = apiGet(rsrcPath, fieldMap, jsonResp)
    if(jsonResp)
      resp = apiResult[:respObj]['data']
    else
      resp = JSON.parse(apiResult[:respObj])
    end
    respond_with({ "data" => resp  }, :status =>  apiResult[:status])
  end
  
end
