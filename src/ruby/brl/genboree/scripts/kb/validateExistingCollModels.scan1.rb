#!/usr/bin/env ruby
require 'brl/db/dbrc'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/validators/docValidator'
require 'brl/genboree/kb/validators/modelValidator'

raise "\n\nERROR: scan script takes 1 arg: the domain/IP of your Genboree host. i.e.:\n    ruby ./scan.rb {gbHost}\n\n" unless(ARGV.size == 1)
# Gather args
gbHost = ARGV[0]

# Standard setup stuff
begin
  dbrc = BRL::DB::DBRC.new()
  dbrcRec = dbrc.getRecordByHost(gbHost, :api)
  mongoDbrcRec = dbrc.getRecordByHost(gbHost, :nosql)
  raise "Can't create/load key config object" unless(dbrc and dbrcRec and mongoDbrcRec)
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
mongoDbNames = kbRecs.map { |kbRec| kbRec['databaseName'] }
kbInfo = kbRecs.map { |kbRec| [ kbRec['databaseName'], kbRec['name'], kbRec['group_id'] ] }

# Scan each mongoDbName
results = Hash.new { |hh,kk| hh[kk] = { } }
mongoDbNames.each { |mongoDbName|
  $stderr.puts "KB: #{mongoDbName.inspect}"
  begin
    # Make mdb
    mdb = BRL::Genboree::KB::MongoKbDatabase.new(
      mongoDbName,
      mongoDbrcRec[:driver],
      { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password] }
    )
    raise "Can't instantiate MongoKbDatabase for mongo db #{mongoDbName.inspect} OR that database is missing in your Mongo instance (but IS in your main MySQL 'kbs' table, which is inappropriate)." unless(mdb and mdb.db)
    # Get all the user colls for this mongodb
    modelsHelper = mdb.modelsHelper()
    colls = mdb.collections(:data, :names)
    colls.each { |coll|
      status = :BAD
      $stderr.puts "  - START: Collection #{coll.inspect}"
      # Need a DataCollectionHelper for this collection
      dataHelper = mdb.dataCollectionHelper(coll) rescue nil
      if(dataHelper)
        begin
          # If we get the appropriate model validator using DataCollectionHelper#modelValidator() it will:
          # * Retrieve the correct model doc from kbModels collection in Mongo
          # * Validate the model
          modelValidator = dataHelper.modelValidator(true, true)

          # Is model valid?
          if(modelValidator.validationErrors and !modelValidator.validationErrors.empty?)
            $stderr.puts "  - >>FAILED<< COLLECTION: INVALID MODEL stored for collection #{coll.inspect}; not a proper model. Validation error(s):\n\n    . #{modelValidator.validationErrors.join("\n    . ")}\n\n"
            results[mongoDbName][coll] = :ERR_INVALID_MODEL
          else
            $stderr.puts "  - OK COLLECTION: Valid model stored for #{coll.inspect}"
            results[mongoDbName][coll] = :OK
            status = :OK
          end
        rescue Exception => err
          $stderr.puts "    SCAN >>FAILED<<: !!!! Interrogating collection #{coll.inspect} raised exception (bad collection?) Will continue to to next collection.\n  - Error Details:\n    . Err Class: #{err.class}\n    . Err Msg: #{err.message}\n    . Err Trace:\n#{err.backtrace.join("\n")}\n\n"
            results[mongoDbName][coll] = :ERR_EXCEPTION_DURING_VALIDATE
        end
      else
        $stderr.puts "    SCAN >>FAILED<<: !!!! couldn't get DataCollectionHelper for collection #{coll.inspect} (bad collection/kb?). MongoKbDatabase.dataCollectionHelper() returned: #{dataHelper.inspect}"
            results[mongoDbName][coll] = :ERR_BAD_DATAHELPER
      end
      $stderr.puts "  - DONE: Collection #{coll.inspect} - Status: #{status} #{" - Recommend DELETE THIS COLLECTION " if(status != :OK)}\n#{'-'*20}"
    }
  rescue => err
    $stderr.puts "SCAN >>FAILED<<: !!!! Exception while interrogating mongo kb database named #{mongoDbName.inspect}. Will continue to next Mongo DB.\n  - Error Details:\n    . Err Class: #{err.class}\n    . Err Msg: #{err.message}\n    . Err Trace:\n#{err.backtrace.join("\n")}\n\n"
      results[mongoDbName] = :ERR_KB_LEVEL_EXCEPTION
  ensure
    mdb.clear() rescue nil
    $stderr.puts "DONE KB #{mongoDbName.inspect}\n#{'=' * 60}\n\n"
  end
}

# Report:
puts "#{'=' * 60}\n#{'=' * 60}\nSUMMARY:\n\n"
puts "GROUP ID\tKB NAME\tKB DB NAME\tCOLLECTION\tSTATUS"
kbInfo.sort{ |aa, bb| aa[2] <=> bb[2]}.each { |kbInfoRec|
  mongoKbDatabase, kbName, groupId = *kbInfoRec
  # Group name
  grpRecs = dbu.selectGroupById(groupId)
  grpName = grpRecs.first['groupName']
  collStatuses = results[mongoKbDatabase]
  if(collStatuses == :ERR_KB_LEVEL_EXCEPTION)
    puts "#{grpName}\t#{kbName}\t#{mongoKbDatabase}\t#{collStatuses}\tShould delete WHOLE KB"
  else
    collStatuses.keys.sort().each { |coll|
      puts "#{grpName}\t#{kbName}\t#{mongoKbDatabase}\t#{coll}\t#{collStatuses[coll]}"
    }
  end
}
