require 'yaml'
require 'json'
require 'plugins/genboree_kbs/app/helpers/genboreeKb_helper'
require 'brl/rest/apiCaller'
require 'brl/util/util'
include BRL::REST

class GenboreeKbVersionsController < ApplicationController
  include GenboreeKbHelper

  unloadable

  respond_to :json

  
  # Gets the list of all versions of a doc/model
  def all
    type = params['type']
    identifier = params['identifier']
    coll = params['collectionSet']
    rsrcPath = (type == 'doc' ? "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}/vers?detailed=true" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model/vers?detailed=true")
    apiResult = apiGet( rsrcPath, { :coll => coll, :doc => identifier } )
    # Add more things to the response like Author's email
    dbConn = getDbConn()
    userRecs = dbConn.getAllUsers()
    userHash = {}
    userRecs.each {|rec|
      userHash[rec['name']] = rec  
    }
    resp = []
    apiResult[:respObj]['data'].each {|verObj|
      version = verObj['versionNum']['value']
      login = verObj['versionNum']['properties']['author']['value']
      date = verObj['versionNum']['properties']['timestamp']['value']
      author = nil
      email = nil
      if(userHash.key?(login))
        author = "#{userHash[login]['firstName']} #{userHash[login]['lastName']}"
        email = userHash[login]['email']
      else
        author = login
        email = "N/A"
      end
      resp << { 'version' => version, 'author' => author, 'email' => email, 'date' => date  }
    }
    respond_with({ "data" => resp }, :status => apiResult[:status])
  end
  
  def download()
    format = params['format']
    type = params['type']
    identifier = params['identifier']
    coll = params['collectionSet']
    rsrcPath = ( type == 'model' ? "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model/vers?detailed=true" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}/vers?detailed=true" )
    fieldMap  = { :coll => coll, :doc => identifier } # :grp & :kb auto-filled for us if we don't supply them
    apiResult  = apiGet(rsrcPath, fieldMap, true)
    resp = JSON.pretty_generate(apiResult[:respObj]['data'])
    fileExt = 'json'
    filePrefix = ( type == 'model' ? "#{coll}.model" : identifier)
    send_data(resp, :filename => "#{filePrefix.makeSafeStr(:ultra)}.vers.#{fileExt}", :type => "application/octet", :disposition => "attachment")
  end
  
  def show
    type = params['type']
    identifier = params['identifier']
    coll = params['collectionSet']
    version = params['version']
    rsrcPath = (type == 'doc' ? "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}/ver/{ver}?detailed=true&contentFields={cf}" : "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model/ver/{ver}")
    fieldMap =  { :coll => coll, :doc => identifier, :ver => version }
    if(type == 'doc')
      fieldMap[:cf] = ['.']
    end
    apiResult = apiGet( rsrcPath, fieldMap )
    respond_with(apiResult[:respObj], :status => apiResult[:status])
  end
  
  def diff()
    identifier = params['identifier']
    coll = params['collectionSet']
    version = params['version']
    diffVersion = params['diffVersion']
    rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/doc/{doc}/ver/{ver}?diffVersion={dver}&format=udiffhtml" 
    fieldMap =  { :coll => coll, :doc => identifier, :ver => version, :dver => diffVersion }
    apiResult = apiGet( rsrcPath, fieldMap, false )
    $stderr.puts "respObj:\n\n#{apiResult[:respObj].class.inspect}"
    status = apiResult[:status]
    respond_with({ "data" => apiResult[:respObj].html_safe} , :status => apiResult[:status])
  end

end

