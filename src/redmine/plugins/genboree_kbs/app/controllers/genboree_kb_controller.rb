require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'brl/rest/apiCaller'
include BRL::REST

class GenboreeKbController < ApplicationController
  include GenboreeKbHelper
  unloadable

  SEARCH_LIMIT = 20

  def create
    GenboreeKb.create( :project_id => params[:project_id], :name => params[:name], :description => params[:description], :gbGroup => params[:gbGroup], :gbHost => params[:gbHost])
    # To-do:
    # Make API call to create kb in genboree
    flash[:notice] = "Knowledge base created."
    kbMount = RedmineApp::Application.routes.default_scope[:path]
    redirect_to "#{kbMount}/projects/#{params['project_ident']}/settings/genboreeKb"
  end

  def update
    kb = GenboreeKb.find_by_project_id(params['project_id'])
    kb.name = params['name']
    kb.description = params['description']
    kb.gbGroup = params['gbGroup']
    kb.gbHost = params['gbHost']
    if(kb.save)
      flash[:notice] = "Knowledge base updated."
      # To-do:
      # Make API call to update kb in genboree
    end
    kbMount = RedmineApp::Application.routes.default_scope[:path]
    redirect_to "#{kbMount}/projects/#{params['project_ident']}/settings/genboreeKb"
  end

  def find_project
    @project = Project.find(params['project_id'])
    $stderr.puts "@project: #{@project.inspect}"
  end

  

 
end
