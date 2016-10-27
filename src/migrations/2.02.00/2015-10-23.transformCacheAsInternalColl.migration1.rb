#!/usr/bin/env ruby
require 'brl/db/dbrc'
require 'brl/genboree/dbUtil'
require 'brl/genboree/kb/mongoKbDatabase'

raise "\n\nERROR: migration script takes 1 arg: the domain/IP of your Genboree host. i.e.:\n    ruby ./migration.rb {gbHost}\n\n" unless(ARGV.size == 1)
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

puts mongoDbNames.inspect()
# Answers core collection name
coreCollName = BRL::Genboree::KB::Helpers::TransformCacheHelper::KB_CORE_COLLECTION_NAME

migrationOutCome = Hash.new { |hh, kk| hh[kk] = {'status' =>  nil, 'dbTag' => nil}}

# Update/check each mongoDbName
mongoDbNames.each { |mongoDbName|
  $stderr.puts "KB: #{mongoDbName.inspect}"
  begin
    status = :OK
    dbTag = ""
    message = ""
    mdb = BRL::Genboree::KB::MongoKbDatabase.new(
        mongoDbName,
        mongoDbrcRec[:driver],
        { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password]}
      )
    if(mdb and mdb.db)
      # move on
      $stderr.puts "Checking whether Internal core collection, #{coreCollName.inspect} is present in #{mongoDbName.inspect}...."
      if(mdb.transformCacheHelper.coll.nil?)
        $stderr.puts "Collection #{coreCollName.inspect} is NOT FOUND in #{mongoDbName.inspect}." 
        #A. Make the core collection
        $stderr.puts "Making the core collection #{coreCollName.inspect} in #{mongoDbName.inspect}."
        transformCacheColl = mdb.makeCoreCollection(coreCollName)
        if(transformCacheColl)
          #B.make the versions and revisions collections
          metadataTemplate = mdb.collMetadataHelper().docTemplate(coreCollName, mdb.conn.defaultAuthInfo[:user])
          versionsCollName = metadataTemplate.getPropVal("name.versions")
          revisionsCollName = metadataTemplate.getPropVal("name.revisions")
          $stderr.puts "Making #{coreCollName} versions and revisions collections in #{mongoDbName.inspect}."
          vrColl = mdb.makeCoreCollection(versionsCollName)  if(versionsCollName)
          reColl = mdb.makeCoreCollection(revisionsCollName) if(revisionsCollName)
          if(vrColl and reColl)
            #C Insert metadata docs for the core collection
            $stderr.puts "Inserting metadata doc in the metadata collection."
            metadataDocObjId = mdb.collMetadataHelper.insertForCollection(coreCollName, mdb.conn.defaultAuthInfo[:user])

            #D Insert now the model
            trCacheModel = mdb.transformCacheHelper.class.getModelTemplate()
            modelDocName = trCacheModel['name']['value']
            collModelDoc = mdb.modelsHelper.modelForCollection(modelDocName, false)
            if(collModelDoc.nil?)
              $stderr.puts "Inserting model of #{coreCollName} in the models collection."
              modelObjId = mdb.modelsHelper.insertForCollection(trCacheModel, mdb.conn.defaultAuthInfo[:user])
              status = :OK
              dbTag = :UPDATED
            else
              status = :FAILED
              message += "ERROR: there is already a model doc available for the collection #{coreCollName.inspect}. Somehow it was already created or was created outside the GenboreeKB infrastructure. Regardless, database is tagged as 'CORRUPT'."
              dbTag = :CORRUPT
            end
          else
            status = :FAILED
            message += "ERROR in creating #{coreCollName} versions or(and) revisions in mongo DB #{mongoDbName.inspect}."
            dbTag = :UPDATE_INCOMPLETE
          end
        else
          status = :FAILED
          dbTag = :UPDATE_INCOMPLETE
          message += "Error in making the core collection : #{coreCollName.inspect} in mongo DB #{mongoDbName.inspect}."
        end
      else # kbtransforms.cache is present
        #A. Check for versions and revisions if the kbQueries Collection does exist
        versionsHelper = mdb.versionsHelper(coreCollName) rescue nil
        revisionsHelper = mdb.revisionsHelper(coreCollName) rescue nil
        if(versionsHelper and revisionsHelper)
          #B. Check for model in kbModels collection
          trCacheModel = mdb.transformCacheHelper.class.getModelTemplate()
          modelDocName = trCacheModel['name']['value']
          collModelDoc = mdb.modelsHelper.modelForCollection(modelDocName, false)
          if(collModelDoc)
            #C. Check for metadata collection record
            #cursor = mdb.collMetadataHelper.coll.find( { "$and" => [ {'name.properties.internal.value' => true}, {'name.value' => coreCollName} ] } )
            cursor = mdb.collMetadataHelper.coll.find( {'name.value' => coreCollName} )
            if(cursor.count == 1)
              # Check if the record is marked as 'internal'
              doc = cursor.first
              internal = doc['name']['properties']['internal']['value'] rescue nil
              if(internal)
                status = :OK
                dbTag  = :UPGRADE_NOT_REGD
                message += "Upgrade not required for #{mongoDbName.inspect}.\n"
                message += "This database has \n- #{coreCollName.inspect} core collection.\n" 
                message += "- Corresponding versions and revisions collections.\n- Model in kbModels collection.\n" 
                message += "- Metadata record in metadata collection.\nMoving on to the next mongo DB.\n"
                $stderr.puts message
              else
                status = :FAILED
                dbTag = :CORRUPT
                message += "Collection #{coreCollName.inspect} found for #{mongoDbName.inspect} is not INTERNAL. Must update this database individually. The #{coreCollName} collection is perhaps a 'User' collection !!!!! CAUTION!!!!!!!!!!!!"  
              end
            else
              status = :FAILED
              message += "Metadata record NOT FOUND for #{coreCollName} in the mongo DB : #{mongoDbName.inspect}."
              dbTag = :CORRUPT
            end
          else
            status = :FAILED
            dbTag = :CORRUPT
            message += "#{coreCollName.inspect} is found but the corresponding model document is not available in the models collection. "
          end
        else
          status = :FAILED
          dbTag = :CORRUPT
          message += "Versions or(and) revisions collections are absent for #{coreCollName} in the mongo DB : #{mongoDbName.inspect}"
        end
      end
    else
      status = :FAILED
      message += "Can't instantiate MongoKbDatabase for mongo db #{mongoDbName.inspect} OR that database is missing in your Mongo instance (but IS in your main MySQL 'kbs' table, which is inappropriate)."
    end
    if(status != :OK)
      $stderr.puts "RESULT: >>FAILED<<\n. - Will continue to the next Mongo DB.\n - STATUS : #{status}\n - DB TAG: #{dbTag.inspect}\n - Error Details : #{message}."
    end
  
  rescue Exception => err
    status = :FAILED
    dbTag = :UPDATE_INCOMPLETE 
    $stderr.puts "RESULT: >>FAILED<<\n  - Will continue to next Mongo DB.\n  - Error Details:\n    . Err Class: #{err.class}\n    . Err Msg: #{err.message}\n    . Err Trace:\n#{err.backtrace.join("\n")}"
  ensure
    mdb.clear()
    migrationOutCome[mongoDbName]['status'] = status
    migrationOutCome[mongoDbName]['dbTag'] = dbTag
    $stderr.puts '-' * 60
  end
}

$stderr.puts '#' *60
$stderr.puts 'Migration Summary'
migrationOutCome.each_key {|kk|
  $stderr.puts "#{kk}\t#{migrationOutCome[kk]['status']}\t#{migrationOutCome[kk]['dbTag']}"
}
$stderr.puts '#' *60
