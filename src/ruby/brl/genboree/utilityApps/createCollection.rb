#!/usr/bin/env ruby
require 'brl/db/dbrc'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/validators/docValidator'


def checkResponse(httpResponse, apiCaller)
    if (not apiCaller.succeeded?())
        raise "Api call failed, details:\n  uri=#{apiCaller.fullApiUri}\n  response=#{httpResponse}\n fullResponse=#{apiCaller.respBody()}"
    end
end


def getApiCallerForUser(userName = nil)  # nil - superuser
    dbrc = BRL::DB::DBRC.new()
    dbrcRec = dbrc.getRecordByHost("localhost", :api)
    apiCaller = BRL::Genboree::REST::ApiCaller.new( "localhost", '', dbrcRec[:user], dbrcRec[:password] )
    if not userName.nil?
        apiCaller.setRsrcPath("/REST/v1/usr/#{userName}?")
        resp = apiCaller.get()
        checkResponse(resp, apiCaller)
        apiCaller.parseRespBody()
        dbs = apiCaller.apiDataObj
        apiCaller = BRL::Genboree::REST::ApiCaller.new( "localhost", '', dbs['login'], dbs['password'] )
    end
    return apiCaller
end



if ARGV.size() != 4
  puts "Parameters:  genboreeGroup  kbName  collectionName fileWithModel"
  exit 1
end 

gbGroup  = ARGV[0]
gbKbName = ARGV[1]
collName = ARGV[2]
fileWithModel = ARGV[3]
puts "Read file with model..."
doc = File.read(fileWithModel)
puts "Connect with API..."
apiCaller = getApiCallerForUser()
puts "Create collection..."
# Save model
apiCaller.setRsrcPath("/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/model?")
resp = apiCaller.put( doc, { :grp => gbGroup, :kb => gbKbName, :coll => collName } )
checkResponse(resp, apiCaller)
puts "Done!"

