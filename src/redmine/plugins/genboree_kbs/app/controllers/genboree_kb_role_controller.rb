require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'brl/rest/apiCaller'
include BRL::REST

class GenboreeKbRoleController < ApplicationController
  include GenboreeKbHelper

  unloadable

  respond_to :json


  def role()
    @project = Project.find(params[:project_id])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    @gbHost = @genboreeKb.gbHost.strip    
    userInfo = getUserInfo(@gbHost)
    apiResult = apiGet( "/REST/v1/grp/{grp}/usr/{usr}/role", { :usr => userInfo[0] } )
    $stderr.puts "API ROLE RESP:\n\n#{JSON.pretty_generate(apiResult[:respObj]) rescue apiResult[:respObj].inspect}\n\n"
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
end
