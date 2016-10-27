require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'brl/rest/apiCaller'
require 'brl/util/util'
include BRL::REST

class GenboreeKbUserController < ApplicationController
  include GenboreeKbHelper

  unloadable

  SEARCH_LIMIT = 20

  respond_to :json

  def groups()
    rsrcPath  = "/REST/v1/usr/{usr}/grps?"
    @project = Project.find(params[:project_id])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    @gbHost = @genboreeKb.gbHost.strip    
    userInfo = getUserInfo(@gbHost)
    apiResult  = apiGet(rsrcPath, { :usr => userInfo[0] })
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def role()
    @project = Project.find(params[:project_id])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    @gbHost = @genboreeKb.gbHost.strip    
    userInfo = getUserInfo(@gbHost)
    apiResult = apiGet( "/REST/v1/grp/{grp}/usr/{usr}/role", { :usr => userInfo[0], :grp => CGI.unescape(params['group']) } )
    $stderr.puts "API ROLE RESP:\n\n#{JSON.pretty_generate(apiResult[:respObj]) rescue apiResult[:respObj].inspect}\n\n"
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def databases
    rsrcPath  = "/REST/v1/grp/{grp}/dbs?"
    @project = Project.find(params[:project_id])
    @genboreeKb = GenboreeKb.find_by_project_id(@project)
    apiResult  = apiGet(rsrcPath, { :grp => CGI.unescape(params['group']) })
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def getdb
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}?"
    apiResult = apiGet(rsrcPath)
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def checkDb()
    kbDb = params['kbDb']
    rsrcPath = "/REST/v1/grp/{grp}/db/{db}?"
    apiResult = apiGet(rsrcPath, {:db => kbDb})
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end

end

