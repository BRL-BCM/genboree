require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'brl/rest/apiCaller'
require 'brl/util/util'
include BRL::REST

class GenboreeKbQuestionnairesController < ApplicationController
  include GenboreeKbHelper

  unloadable


  respond_to :json

  def all()
    coll = params['collectionSet']
    rsrcPath= "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/quests?detailed=true"
    fieldMap =  { :coll => coll }
    apiResult = apiGet( rsrcPath, fieldMap )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def answer
    coll = params['collectionSet']
    answerDoc = params['answerDoc']
    questionnaireId = params['questionnaireId']
    rsrcPath= "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/quest/{quest}/answer/{ans}?detailed=true"
    fieldMap =  { :coll => coll, :quest =>  questionnaireId, :ans => "" }
    apiResult = apiPut( rsrcPath, answerDoc, fieldMap )
    respond_with(apiResult[:respObj], :status => apiResult[:status], :location => "")
  end
  
end

