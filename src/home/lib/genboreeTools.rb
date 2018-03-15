#!/usr/bin/env ruby

require "cgi"
require 'brl/util/util'
require 'brl/db/dbrc'
require 'brl/genboree/rest/apiCaller'
require 'mysql' # for escape string


# ================================================= LOW LEVEL STUFF ===========================================================

$user = nil
$password = nil
$dbConnection_genboree = nil
$dbConnection_redmine = nil

# create ApiCaller object
def getApiCallerForObject(resource)
  if $user.nil?
    dbrc = BRL::DB::DBRC.new()
    dbrcRec = dbrc.getRecordByHost("localhost", :api)
    apiCaller = BRL::Genboree::REST::ApiCaller.new( "localhost", '/REST/v1/usr/genbadmin?', dbrcRec[:user], dbrcRec[:password] )
    resp = apiCaller.get()
    apiCaller.parseRespBody()
    if(not apiCaller.succeeded?())
      raise "Api call failed (get), details:\n  response=#{resp}\n  request=#{apiCaller.fullApiUri()}\n  fullResponse=#{apiCaller.respBody()}"
    end
    dbs = apiCaller.apiDataObj
    $user = dbs['login']
    $password = dbs['password']
  end
  apiCaller = BRL::Genboree::REST::ApiCaller.new( "localhost", resource, $user, $password )
  return apiCaller
end

# run SQL statement on genboree database
def runSqlStatement_genboree(sql)
  if $dbConnection_genboree.nil?
    dbrc = BRL::DB::DBRC.new()
    dbrcRec = dbrc.getRecordByHost("localhost", :db)
    $dbConnection_genboree = Mysql2::Client.new(:host => 'localhost', :database => 'genboree', :username=>dbrcRec[:user], :password=>dbrcRec[:password])
  end
  return $dbConnection_genboree.query(sql)
end

# run SQL statement on redmine database
def runSqlStatement_redmine(sql)
  if $dbConnection_redmine.nil?
    dbrc = BRL::DB::DBRC.new()
    dbrcRec = dbrc.getRecordByHost("localhost", :db)
    $dbConnection_redmine = Mysql2::Client.new(:host => 'localhost', :database => 'redmine', :username=>dbrcRec[:user], :password=>dbrcRec[:password])
  end
  return $dbConnection_redmine.query(sql)
end

# ----------------------------- SQL helpers

# returns string "INSERT INTO table(keys) VALUES(values)"
def sql_insert(table, fields)
  values = ""
  keys = ""
  fields.each { |k,v|
    keys   += "," if keys   != ""
    values += "," if values != ""
    keys   += "#{k}"
    values += (v.nil?) ? ("NULL") : ("'#{Mysql.escape_string(v.to_s)}'")
  }
  return "INSERT INTO #{table}(#{keys}) VALUES(#{values})"
end

# returns string "UPDATE table SET key1=value1, key2=value2, ..."
def sql_update(table, fields)
  keys_and_values = ""
  fields.each { |k,v|
    keys_and_values += "," if keys_and_values != ""
    keys_and_values += "#{k}=#{(v.nil?) ? ("NULL") : ("'#{Mysql.escape_string(v.to_s)}'")}"
  }
  return "UPDATE #{table} SET #{keys_and_values}"
end

# =================================================== SOME UTILITIES =====================================================

# GET requests
def api_get(resource)
  apiCaller = getApiCallerForObject(resource)
  resp = apiCaller.get()
  apiCaller.parseRespBody()
  raise "Api call failed (get), details:\n  request=#{apiCaller.fullApiUri()}\n  fullResponse=#{apiCaller.respBody()}" if(apiCaller.failed?())  
  return apiCaller.apiDataObj
end

# PUT requests
def api_put(resource, payload = nil)
  apiCaller = getApiCallerForObject(resource)
  payload = payload.to_json if payload.is_a?(Hash) or payload.is_a?(Array)
  resp = (payload.nil?) ? (apiCaller.put()) : (apiCaller.put(payload))
  apiCaller.parseRespBody()
  raise "Api call failed (put), details:\n  request=#{apiCaller.fullApiUri()}\n  fullResponse=#{apiCaller.respBody()}" if(apiCaller.failed?())  
end

# DELETE requests
def api_delete(resource)
  apiCaller = getApiCallerForObject(resource)
  resp = apiCaller.delete()
  apiCaller.parseRespBody()
  raise "Api call failed (delete), details:\n  request=#{apiCaller.fullApiUri()}\n  fullResponse=#{apiCaller.respBody()}" if(apiCaller.failed?())  
end

# check if exists
def api_object_exists(resource)
  apiCaller = getApiCallerForObject(resource)
  resp = apiCaller.get() 
  return false if(resp.kind_of?(::Net::HTTPNotFound))
  return true  if(apiCaller.succeeded?())
  raise "Api call failed (get), details:\n  uri=#{uriPath}\n  response=#{resp}\n  request=#{apiCaller.fullApiUri()}\n  fullResponse=#{apiCaller.respBody()}"   

end

# PUT requests with large payload from file (as vector of documents)
def api_put_from_file_in_chunks(resource, filename, substitutions=Hash.new, chunk_size=128)
  json_data = nil
  if filename =~ /\.gz$/
    json_data = Zlib::GzipReader.open("#{filename}").read()
  else
    json_data = File.read("#{filename}")
  end
  substitutions.each { |k, v|
    json_data.gsub!(k, v) if k != v
  }
  docs = JSON.parse(json_data)
  apiCaller = getApiCallerForObject(resource)
  uploaded_chunks = 0
  while docs.size > 0
    if docs.kind_of?(Array)
        payload = { "data" => docs.shift(chunk_size) }
    else
        payload = { "data" => docs }
        docs = []
    end
    apiCaller.put( payload.to_json )
    apiCaller.parseRespBody()
    raise "Api call failed (put from file), details:\n  request=#{apiCaller.fullApiUri()}\n  fullResponse=#{apiCaller.respBody()}\n  uploadedChunks=#{uploaded_chunks}" if(apiCaller.failed?())
    uploaded_chunks +=1
  end
end

# --------------------------------------------- redmine ---------------------------

# GET request for redmine
def redmine_api_get(resource)
  resource = "http://localhost/redmine" + resource 
  resource += (resource.include?('?')) ? '&' : '?' 
  resource += "key=779665443f782f5f670a5e3ae69874a78607cdc0"
  resp = Net::HTTP.get_response(URI(resource))
  raise "Redmine api call failed (get), details:\n  request=#{resource}\n  response=#{resp.inspect}" if not resp.is_a?(Net::HTTPSuccess)
  return JSON.parse(resp.body)
end

def redmine_api_post(resource, payload)
  resource = "http://localhost/redmine" + resource 
#  resource += (resource.include?('?')) ? '&' : '?' 
#  resource += "key=779665443f782f5f670a5e3ae69874a78607cdc0"
  payload = payload.to_json if payload.is_a?(Hash)
  uri = URI(resource)
  req = Net::HTTP::Post.new( 'http://' + uri.host + uri.path )
#  params = Hash.new
#  uri.query.split('&').each { |param|
#    t = param.split('=')
#    raise "Redmine api call failed (post), incorrect format of parameters:\n  request=#{resource}\n  parameter=#{param}" if t.size != 2
#    params[t[0]] = t[1] 
#  }
#  req.set_form_data(params)
  req.add_field('content-type', 'application/json')
  req.add_field('X-Redmine-API-Key', '779665443f782f5f670a5e3ae69874a78607cdc0')
  req.body = payload
  resp = Net::HTTP.start(uri.host, uri.port) do |http| http.request(req) end
  raise "Redmine api call failed (post), details:\n  request=#{resource}\n  payload=#{payload}\n  response=#{resp.inspect}\n  body=#{resp.body}" if not resp.is_a?(Net::HTTPSuccess)
  return JSON.parse(resp.body)
end

# ================================================== HIGH LEVEL FUNCTIONS =====================================================

# add user To Genboree
def genboree_add_user(login, password, email, firstname, lastname)
  fields = Hash.new
  fields['name'] = login
  fields['password'] = password
  fields['email'] = email
  fields['firstName'] = firstname
  fields['lastName'] = lastname
  runSqlStatement_genboree( sql_insert('genboreeuser',fields) )
  begin
    redmine_api_post('/users.json', '{"user":{"login": "' + "#{login}" + '","firstname": "' + "#{firstname}" + '","lastname": "' + "#{lastname}" + '","mail": "' + "#{email}" + '", "auth_source_id": 1}}')
  rescue
    begin
      runSqlStatement_genboree("DELETE FROM genboreeuser WHERE name='#{login}'")
    rescue
    end
    raise
  end
end

def genboree_user_exists(login)
  sql = "SELECT * FROM genboreeuser WHERE name='#{Mysql.escape_string(login)}'"
  res = runSqlStatement_genboree(sql)
  return (res.size > 0)
end

# delete user from Genboree
# def genboree_delete_user(login)
#  sql = "DELETE FROM genboreeuser WHERE name='#{login}'"
#  runSqlStatement_genboree(sql)
#end

def genboree_add_group(groupName) 
  api_put('/REST/v1/grp/' + CGI::escape(groupName))
end

# check if group exists
def genboree_group_exists(group)
  return api_object_exists("/REST/v1/grp/#{CGI::escape(group)}")
end

def genboree_add_kb(group, kb, description = nil)
  kbUri = '/REST/v1/grp/' + CGI::escape(group) + '/kb/' + CGI::escape(kb)
  payload = '{ "name": { "value": "' + kb + '", "properties": { "kbDbName": { "value": "' + kb + '" }' 
  payload += ',"description": { "value": "' + description + '" }' if description
  payload += ' } } }'
  api_put(kbUri, payload)
end

def genboree_delete_kb(group, kb)
  kbUri = '/REST/v1/grp/' + CGI::escape(group) + '/kb/' + CGI::escape(kb)
  api_delete(kbUri)
end

# check if kb exists
def genboree_kb_exists(group, kb)
  return api_object_exists('/REST/v1/grp/' + CGI::escape(group) + '/kb/' + CGI::escape(kb))
end

# set KB as public
def genboree_set_kb_public(group, kb)
  # Compose the KB URL which needs to be publicly unlocked. Let's have our apiCaller help us with this via URI Templates.
  apiCaller = getApiCallerForObject("/REST/v1/grp/{grp}/kb/{kb}")
  kbUrl = apiCaller.fillApiUriTemplate( { :grp => group, :kb => kb})
  # Construct unlock record for the KB we want to unlock
  unlockRec = { "url" => kbUrl, "public" => true }
  # Sent PUT request
  api_put("/REST/v1/grp/#{CGI::escape(group)}/unlockedResources", [unlockRec].to_json)
end

# assign user to group (change role, if user already assigned)
def genboree_assign_user_to_group_as_subscriber(user, group)
  api_put("/REST/v1/grp/#{CGI::escape(group)}/usr/#{CGI::escape(user)}/role", {"role"=>"subscriber", "permissionBits"=>""})
end
def genboree_assign_user_to_group_as_author(user, group)
  api_put("/REST/v1/grp/#{CGI::escape(group)}/usr/#{CGI::escape(user)}/role", {"role"=>"author", "permissionBits"=>""})
end

def genboree_kb_add_collection(group, kb, collection, model)
  uri = "/REST/v1/grp/#{CGI::escape(group)}/kb/#{CGI::escape(kb)}/coll/#{CGI::escape(collection)}/model"
  model = model.to_json if model.is_a?(Hash)
  api_put(uri, model)
end

def genboree_kb_add_transform(group, kb, transformDefinition)
  transformDefinition = JSON.parse(transformDefinition) if transformDefinition.is_a?(String)
  name = transformDefinition['Transformation']['value']
  uri = "/REST/v1/grp/#{CGI::escape(group)}/kb/#{CGI::escape(kb)}/transform/#{CGI::escape(name)}"
  api_put(uri, transformDefinition.to_json)
end

# load documents to KB collections
def genboree_kb_add_documents(group, kb, collection, documents, autoAdjustId=true, substitutions=Hash.new, chunk_size=128)
  uri = "/REST/v1/grp/#{CGI::escape(group)}/kb/#{CGI::escape(kb)}/coll/#{CGI::escape(collection)}/docs"
  uri += "?autoAdjust=true" if autoAdjustId
  while documents.size > 0
    payload = { "data" => documents.shift(chunk_size) }
    payload = payload.to_json
    substitutions.each { |k, v|
      payload.gsub!(k, v) if k != v
    }
    api_put(uri, payload)
  end
end

def genboree_kb_add_documents_from_file(group, kb, collection, filename, autoAdjustId=true, substitutions=Hash.new, chunk_size=128)
  uri = "/REST/v1/grp/#{CGI::escape(group)}/kb/#{CGI::escape(kb)}/coll/#{CGI::escape(collection)}/docs"
  uri += "?autoAdjust=true" if autoAdjustId
  api_put_from_file_in_chunks(uri, filename, substitutions, chunk_size)
end

# add redmine project
# examples of modules: 'files', 'genboree_ac', 'genboree_kb', 'genboree_registry', 'register_clingen_user', 'wiki'
def redmine_add_project(identifier, name, modules=[], public=false)
  fields = Hash.new
  fields['name'] = name
  fields['identifier'] = identifier
  fields['description'] = ''
  fields['enabled_module_names'] = modules
  fields['is_public'] = public
  redmine_api_post("/projects.json", "{\"project\":#{fields.to_json}}")
end

# assign user to redmine project
def redmine_assign_user_to_project(user_login, project_identifier, roles_names)
  # find user id
  resp = redmine_api_get("/users.json?name=#{user_login}")
  user_id = nil
  resp['users'].each { |user|
    next if user['login'] != user_login
    user_id = user['id']
    break
  }
  raise "Cannot find user: #{user_login}" if user_id.nil?
  # find roles ids
  roles_names = roles_names.map { |x| x.downcase }
  resp = redmine_api_get("/roles.json")
  roles_ids = []
  resp['roles'].each { |role|
    roles_ids << role['id'] if roles_names.include?(role['name'].downcase)
  }
  raise "Cannot find all roles: #{roles_names}" if roles_ids.size != roles_names.size
  # assign user to project
  redmine_api_post("/projects/#{project_identifier}/memberships.json", '{"membership":{"user_id":' + "#{user_id}" + ',"role_ids":' + roles_ids.to_json + '}}')
end

# set configuration of genboree_kb project
def redmine_configure_project_genboree_kb(project_identifier, genboree_group, kb_name)
  # find project id
  resp = redmine_api_get("/projects/#{project_identifier}.json")
  id = resp["project"]["id"]
  raise "Cannot find project with identifier: #{project_identifier}" if id.nil?
  # set record's fields
  fields = Hash.new
  fields['project_id'] = id
  fields['name'] = "#{kb_name}"
  fields['gbGroup'] = "#{genboree_group}"
  fields['gbHost'] = 'localhost'
  # check if the record exists and rub insert or update
  sql = "SELECT COUNT(1) AS count FROM genboree_kbs WHERE project_id=#{id}"
  if runSqlStatement_redmine(sql).first['count'].to_i == 0
    sql = sql_insert('genboree_kbs', fields)
  else
    sql = sql_update('genboree_kbs', fields) + " WHERE project_id=#{id}"
  end
  runSqlStatement_redmine(sql)
end

# set configuration of genboree_exrna_at project
def redmine_configure_project_genboree_exrna_at(project_identifier, genboree_group, kb_name, home_page = "/redmine/projects/#{project_identifier}/exat")
  # find project id
  resp = redmine_api_get("/projects/#{project_identifier}.json")
  id = resp["project"]["id"]
  raise "Cannot find project with identifier: #{project_identifier}" if id.nil?
  # set record's fields
  fields = Hash.new
  fields['project_id'] = id
  fields['gbHost'] = 'localhost'
  fields['gbGroup'] = genboree_group
  fields['gbKb'] = kb_name
  fields['appLabel'] = nil
  fields['useRedmineLayout'] = 1
  fields['headerIncludeFileLocation'] = nil
  fields['footerIncludeFileLocation'] = nil
  fields['analysesColl'] = 'Analyses'
  fields['biosamplesColl'] = 'Biosamples'
  fields['donorsColl'] = 'Donors'
  fields['experimentsColl'] = 'Experiments'
  fields['jobsColl'] = 'Jobs'
  fields['resultFilesColl'] = 'Result Files'
  fields['runsColl'] = 'Runs'
  fields['studiesColl'] = 'Studies'
  fields['submissionsColl'] = 'Submissions'
  fields['updateData'] = 0
  fields['newsFile'] = ''
  fields['contactTo'] = ''
  fields['contactBccs'] = ''
  fields['jobHost'] = 'localhost'
  fields['toolUsageHost'] = ''
  fields['toolUsageGrp'] = ''
  fields['toolUsageKb'] = ''
  fields['toolUsageColl'] = ''
  fields['toolUsageView'] = ''
  fields['privateSubmitters'] = ''
  fields['homePageUrl'] = home_page
  fields['infoFlashHtml'] = ''
  fields['prevVersions'] = ''
  # check if the record exists and run insert or update
  sql = "SELECT COUNT(1) AS count FROM genboree_exrna_ats WHERE project_id=#{id}"
  if runSqlStatement_redmine(sql).first['count'].to_i == 0
    sql = sql_insert('genboree_exrna_ats', fields)
  else
    sql = sql_update('genboree_exrna_ats', fields) + " WHERE project_id=#{id}"
  end
  runSqlStatement_redmine(sql)
end


# configuration of register_clingen_user project
def redmine_configure_project_register_clingen_user(project_identifier)
  # find project id
  resp = redmine_api_get("/projects/#{project_identifier}.json")
  id = resp["project"]["id"]
  raise "Cannot find project with identifier: #{project_identifier}" if id.nil?
  # set record's fields
  fields = Hash.new
  fields['project_id'] = id
  fields['gb_host'] = 'localhost'
  fields['acmg_guideline_rest'] = '/REST/v1/grp/pcalc_resources/kb/pcalc_resources/coll/GuidelineRulesMetaRules/doc/ACMG2015-Guidelines'
  fields['acmg_transformation_rest'] = '/REST/v1/grp/pcalc_resources/kb/pcalc_resources/trRulesDoc/acmgTransform'
  fields['acmg_allowed_tags_rest'] = '/REST/v1/grp/pcalc_resources/kb/pcalc_resources/coll/AllowedTags/doc/ACMG2015-Caps'
  fields['gb_public_tool_user'] = 'gbPublicToolUser'
  fields['gb_cache_user'] = 'gbCacheUser'
  fields['registry_grp'] = 'Registry'
  fields['configuration_group'] = 'pcalc_resources'
  fields['configuration_kb'] = 'pcalc_resources'
  fields['cache_group'] = 'pcalc_cache'
  fields['cache_kb'] = 'pcalc_cache'
  fields['privilaged_user'] = 'genbadmin'
  # check if the record exists and run insert or update
  sql = "SELECT COUNT(1) AS count FROM clingen_resource_settings WHERE project_id=#{id}"
  if runSqlStatement_redmine(sql).first['count'].to_i == 0
    sql = sql_insert('clingen_resource_settings', fields)
  else
    sql = sql_update('clingen_resource_settings', fields) + " WHERE project_id=#{id}"
  end
  runSqlStatement_redmine(sql)
end


# =========================== load tools from installed apps

Dir.glob( File.join("/usr/local/brl/local/etc/conf","*Tools.rb") ) { |path| require path }

