#!/usr/bin/env ruby
require 'brl/db/dbrc'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/validators/modelValidator'

raise "\n\nERROR: migration script takes 1 arg: the domain/IP of your Genboree host. i.e.:\n    ./migration.rb {gbHost}\n\n" unless(ARGV.size == 1)
# Gather args
gbHost = ARGV[0]

# Standard setup stuff
begin
  dbrc = BRL::DB::DBRC.new()
  dbrcRec = dbrc.getRecordByHost(gbHost, :api)
  mongoDbrcRec = dbrc.getRecordByHost(gbHost, :nosql)
  raise "Can't create/load key config object" unless(dbrc and genbConf and dbrcRec and mongoDbrcRec)
rescue => err
  $stderr.puts %Q@
    ERROR: Run this script via Genboree-env enabled user like genbadmin.
      * Account must have standard Genboree-related env variables configured
        for the intended Genboree instance, such as: $DBRC_FILE, $GENB_CONFIG,
        $DOMAIN_ALIAS_FILE.
      * Furthermore, the $DBRC_FILE *must* have prefix-host based entries for
        connecting to the main MySQL database AND to the MongoDB instance.
      * Code will be expecting to be able to module load a module nameed
        'glib-2.0'
      * Will exit, but here are error details:
        - ERR CLASS: #{err.class}
        - ERR MSG:   #{err.message}
        - ERR TRACE:\n#{err.backtrace.join("\n")}

  @
  exit(7)
end

# Make dbu
dbu = BRL::Genboree::DBUtil.new("DB:#{gbHost}", nil, nil)

# Use dbu to find all the kbs
kbRecs = dbu.selectAllKbs()
kbMap = {}
kbRecs.each {|rec|
  kbMap[rec['name']] = rec['databaseName']
}
# Fix each mongoDbName
count = 0
kbMap.each_key { |kb|
  mongoDbName = kbMap[kb]
  $stderr.puts "KB: #{kb.inspect}"
  $stdout.puts "KB: #{kb.inspect}"
  resHash = {}
  begin
    # Make mdb
    mdb = BRL::Genboree::KB::MongoKbDatabase.new(
      mongoDbName,
      mongoDbrcRec[:driver],
      { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password]}
    )
    raise "Can't instantiate MongoKbDatabase for mongo db #{mongoDbName.inspect} OR that database is missing in your Mongo instance (but IS in your main MySQL 'kbs' table, which is inappropriate)." unless(mdb and mdb.db)
    # Get all the colls foe this mongodb
    resHash[mongoDbName] = {}
    colls = mdb.collections(:data, :names)
    modelsHelper = mdb.modelsHelper()
    colls.each {|coll|
      $stdout.puts "  COLL: #{coll}"
      modelDoc = modelsHelper.modelForCollection(coll)
      model =  modelDoc.getPropVal("name.model")
      dataHelper = mdb.dataCollectionHelper(coll) rescue nil
      docCursor = dataHelper.allDocs(:cursor)
      $stdout.puts "      TOTAL DOCS: #{docCursor.entries.size}"
      docsReqCasting = 0
      docCursor.rewind!
      docCursor.each {|doc|
        docKb = BRL::Genboree::KB::KbDoc.new(doc)
        docKb.cleanKeys!(['_id', :_id])
        dv = BRL::Genboree::KB::Validators::DocValidator.new()
        isValid = dv.validateDoc(docKb, model)
        if isValid[:result] == :VALID
          paths = dv.modelValidator.needsCastingPropPaths
          docsReqCasting += 1 if(paths.size > 0)
          paths.each {|pp|
            resHash[mongoDbName][coll] = {} if(!resHash[mongoDbName].key?(coll))
            if !resHash[mongoDbName][coll].key?(pp)
              resHash[mongoDbName][coll][pp] = nil
            end
          }
        end

      }
      $stdout.puts "      DOCS REQUIRING CASTING: #{docsReqCasting}"
      $stdout.puts '-' * 30
    }
    if !resHash[mongoDbName].empty?
      $stderr.puts JSON.pretty_generate(resHash)
    end
  rescue => err
    $stderr.puts "RESULT: >>FAILED<<\n  - Will continue to next Mongo DB.\n  - Error Details:\n    . Err Class: #{err.class}\n    . Err Msg: #{err.message}\n    . Err Trace:\n#{err.backtrace.join("\n")}"
  ensure
    mdb.clear()
    $stderr.puts '-' * 60
    $stdout.puts '-' * 60
  end
}
