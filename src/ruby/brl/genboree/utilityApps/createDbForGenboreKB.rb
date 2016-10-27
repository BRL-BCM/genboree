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



if ARGV.size() != 3
  puts "Parameters:  userName  genboreeGroup  kbName"
  exit 1
end 


# Info regarding new GenboreeKB
gbUser   = ARGV[0]
gbGroup  = ARGV[1]
gbKbName = ARGV[2]
gbDbName = "KB:#{gbKbName}" 

puts "Connect with API..."
apiCaller = getApiCallerForUser()
# Create DbUtil instance, arranging for it to automatically pick up auth credentials
# from .dbrc file and being ready to query the main Genboree database for gbHost
gbHost = "localhost"
dbu = BRL::Genboree::DBUtil.new("DB:#{gbHost}", nil, nil)
# We need the groupId number for gbGroup. Retrieve it:
grpRecs = dbu.selectGroupByName(gbGroup)
if grpRecs.size != 1
    puts "ERROR: Cannot fetch information about give genboree group. Make sure that it exists."
    exit 3
end
groupId = grpRecs.first['groupId']

puts "Create Genboree database..."

# Connect Mongo db with Genboree db 1 

# Switch to user's apiCaller
apiCaller = getApiCallerForUser(gbUser)
# IF NEEDED: unless you created it in the workbench, create a regular Genboree Database (to hold any data files linked/mentioned in docs)
# - 1st: set path for database in apiCaller
apiCaller.setRsrcPath("/REST/v1/grp/{grp}/db/{db}")
# - 2nd: create new database with no metadata (no assembly version, i.e. no genome template, no description, no nothing)
resp = apiCaller.put( { :grp => gbGroup, :db => gbDbName })  # cannot be superuser when adding new database 
checkResponse(resp, apiCaller)

puts "Create MongoDB database..."
# Construct the name of the underlying MongoDB using Genboree's naming heuristic
# - Do NOT make up your own names 
dbrc = BRL::DB::DBRC.new()
mongoDbrcRec = dbrc.getRecordByHost(gbHost, :nosql)
mongoDbName = BRL::Genboree::KB::MongoKbDatabase.constructMongoDbName(
  gbHost,
  gbGroup,
  gbKbName
)

# Instantiate MongoKbDatabase for that gbKbName
mdb = BRL::Genboree::KB::MongoKbDatabase.new(
  mongoDbName,
  mongoDbrcRec[:driver],
  { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password]}
)

# NOTE 1: The actual name of the MongoDB database will be a safe version of the user's kbKbName:
puts "Name of new MongoDB database: #{mdb.name}"

# NOTE 2: Because this GenboreeKB doesn't exist yet, there's no MongoDB object available yet:
# mdb.db.class #=> NilClass
if not mdb.db.nil?
    puts "ERROR: MongoDB database with that name already exists"
    exit 1
end

# Create the new MongoDB database
# * should raise KbError exception if that MongoDB already exists
if (not mdb.create()) 
    puts "ERROR: Cannot create MongoDB database"
    exit 2
end

puts "Assign MongoDB database to Genboree database..."
# Insert a record associating gbKbName with that groupId
# - Note: you can also provide a 5th parameter with the description
# - Note: don't use the "public" (6th) parameter as it will be phased out. It's not needed.
insertStatus = dbu.insertKb(groupId, gbDbName, gbKbName, mongoDbName)

puts "Done!"


