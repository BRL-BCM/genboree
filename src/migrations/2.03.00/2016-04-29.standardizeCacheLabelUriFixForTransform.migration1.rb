#!/usr/bin/env ruby
require 'brl/db/dbrc'
require 'brl/genboree/dbUtil'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/helpers/transformCacheHelper'

raise "\n\nERROR: migration script takes 1 argument: the domain/IP of your Genboree host.\n This script will delete the internal collection - kbTransform.cache and all the associated records from other internal collections like kbModels, etc." unless(ARGV.size == 1)

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
$stderr.puts mongoDbNames.inspect
coreCollName = BRL::Genboree::KB::Helpers::TransformCacheHelper::KB_CORE_COLLECTION_NAME
migrationOutCome = Hash.new { |hh, kk| hh[kk] = {'status' =>  nil, 'dbTag' => nil, 'message' => nil}}
$stderr.puts "-" * 60
$stderr.puts "Starting to DELETE Transform.cache from the databases............."
$stderr.puts "-" * 60

# Update/check each mongoDbName
puts mongoDbNames.inspect
mongoDbNames.each { |mongoDbName|
  $stderr.puts "KB: #{mongoDbName.inspect}"
  begin
    status = :OK
    dbTag = ""
    message = []
    mdb = BRL::Genboree::KB::MongoKbDatabase.new(
        mongoDbName,
        mongoDbrcRec[:driver],
        { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password]}
      )
    if(mdb and mdb.db)
      # XXXX ====== THIS MIGRATION WAS ADJUSTED TO LAST RUBY SOURCES (because it didn't work)
      # XXXX trcHelper = mdb.transformCacheHelper rescue nil
      if true  # XXXX (trcHelper and !(trcHelper.coll.nil?))
        #1. internal collection is present
        $stderr.puts "#{coreCollName} is present. "
        #2. Record in metadataCollections ?
        cur = mdb.collMetadataHelper.coll.find( {'name.value' => coreCollName} )
        if(cur.count > 0)
           #3.versions and revisions are present?
           versionsHelper = mdb.versionsHelper(coreCollName) rescue nil
           revisionsHelper = mdb.revisionsHelper(coreCollName) rescue nil
           if(versionsHelper and revisionsHelper)
             #4. Remove model in kbModels collection
             # XXXX trcModel = mdb.transformCacheHelper.class.getModelTemplate()
             # XXXX trcModelObj = BRL::Genboree::KB::KbDoc.new(trcModel)
             modelDocName = "TransformCache Model - #{coreCollName}" # XXXX trcModelObj.getPropVal("name")
             collModelDoc = mdb.modelsHelper.modelForCollection(modelDocName, false)
             if(collModelDoc)
               $stderr.puts "Found rec in kbModels collection, going to remove it  . . . ."
               cur = mdb.modelsHelper.coll.remove({'name.value' => modelDocName})
               $stderr.puts "Found versions and revisions collection, going to remove it  . . . ."
               versionsHelper.coll.drop if(versionsHelper)
               revisionsHelper.coll.drop if(revisionsHelper)
               $stderr.puts "Found metadata records for the collection. Going to remove the records from the metadata collection."
               mdb.collMetadataHelper.coll.remove( {'name.value' => coreCollName} )
               $stderr.puts "#{coreCollName} is present. Going to drop the collection ....."
               mdb.db.drop_collection(coreCollName) # XXXX trcHelper.coll.drop
               status = :OK
               dbTag = :DELETION_COMPLETE
               message << "#{coreCollName} collection, records from kbColl.metadata, versions, revisions collection and records from kbModels collection successfully removed."
             else
               status = :FAILED
               dbTag = :DB_CORRUPT_DELETION_INCOMPLETE
               message << "Found #{coreCollName} for mongo db #{mongoDbName.inspect} (deleted) and also found its record in kbColl.metadata (which was deleted). Versions and revisions collections were also located and succesfully deleted. But the corresponding record was not found in kbModels collection. This is not allowed and hence tagging the db as corrupt. This db requires manual inspection."
             end
           else
             status = :FAILED
             dbTag = :DB_CORRUPT_DELETION_INCOMPLETE
             message << "Found #{coreCollName} for mongo db #{mongoDbName.inspect} (deleted) and also found its record in kbColl.metadata (which was deleted), but failed to find versions or/and revisions collection. This is not allowed and hence tagging the db as corrupt. This db requires manual inspection."
           end
        else
          status = :FAILED
          dbTag = :DB_CORRUPT_DELETION_INCOMPLETE
          message << "Found #{coreCollName} for mongo db #{mongoDbName.inspect} (deleted), but failed to find the corresponding record in the kbColl.metadata collection. This is not allowed and hence tagging this database as corrupt - requires manual inspection."
        end
      else
         # no kbTransform.cache collection
         status = :FAILED
         dbTag = :Transform_CACHE_COLL_NOT_FOUND
         message << "#{coreCollName} not found for mongo db #{mongoDbName.inspect}. All the kbs are supposed to have this internal collection. Need manual inspection. Does this kb have any records of it in kbColl.metadata?. Currently tagged as #{dbTag}."
         cur = mdb.collMetadataHelper.coll.find( {'name.value' => coreCollName} )
         if(cur.count != 0)
           dbTag = :CORRUPT
           message << "Found no #{coreCollName} collection, but located associated rec in kbColl.metadata. This DB requires manual inspection. Tag changed to #{dbTag.inspect}."
         else
           message << "No rec found in kbColl.metadata."
         end
         versionsHelper = mdb.versionsHelper(coreCollName) rescue nil
         revisionsHelper = mdb.revisionsHelper(coreCollName) rescue nil
         if(versionsHelper and revisionsHelper)
           dbTag = :CORRUPT
           message << "Found no #{coreCollName} collection, but located versions and/or revisions collection!!!! This DB requires manual inspection. Tag changed to #{dbTag.inspect}"
         else
           message << "Found no versions and revisions collection."
         end
         #"TransformCache Model - kbTransforms.cache"
         name = "TransformCache Model - kbTransforms.cache"
         cc = mdb.modelsHelper.coll.find({'name.value' => name})
         if(cc.count != 0)
            dbTag = :CORRUPT
            message << "Found rec in kbModels collections. This db is corrupt and need manual inspection"
         else
           message << "No rec in kbModels collection"
         end
      end     
    else
        status = :FAILED
        dbTag = :DB_MISSING
        message << "Can't instantiate MongoKbDatabase for mongo db #{mongoDbName.inspect} OR that database is missing in your Mongo instance (but IS in your main MySQL 'kbs' table, which is inappropriate)."
    end
    if(status != :OK)
      $stderr.puts "RESULT: >>FAILED<<\n. - Will continue to the next Mongo DB.\n - STATUS : #{status}\n - DB TAG: #{dbTag.inspect}\n - Error Details : #{message}."
     end
  rescue Exception => err
    status = :FAILED
    dbTag = :DELETION_INCOMPLETE
    $stderr.puts "RESULT: >>FAILED<<\n  - Will continue to next Mongo DB.\n  - Error Details:\n    . Err Class: #{err.class}\n    . Err Msg: #{err.message}\n    . Err Trace:\n#{err.backtrace.join("\n")}"
  ensure
    mdb.clear()
    migrationOutCome[mongoDbName]['status'] = status
    migrationOutCome[mongoDbName]['dbTag'] = dbTag
    migrationOutCome[mongoDbName]['message'] = message
    $stderr.puts '-' * 60
  end
}
$stderr.puts '#' *60
$stderr.puts 'Migration Summary'
$stderr.puts '#' *60
$stderr.puts "KB_NAME\tSTATUS\tTAG\tMESSAGE"
migrationOutCome.each_key {|kk|
  $stderr.puts "#{kk}\t#{migrationOutCome[kk]['status']}\t#{migrationOutCome[kk]['dbTag']}\t#{migrationOutCome[kk]['message'].join()}"
}
$stderr.puts '#' *60

