#!/usr/bin/env ruby
require 'brl/db/dbrc'
require 'brl/genboree/dbUtil'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/validators/transformValidator'
require 'brl/genboree/kb/validators/docValidator'

raise "\n\nERROR: migration script takes 2 args: the domain/IP of your Genboree host, and true/false indicating whether to update the transformation model:\n    ./migration.rb {gbHost} false\n\n Setting second argument to true will update the transformation model of the databases that passes the validation.\n\n Second argument if false will only scan the databases." unless(ARGV.size == 2)

# Gather args
gbHost = ARGV[0]
update = ARGV[1].autoCast()
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

# Transformation core collection name
coreCollName = BRL::Genboree::KB::Helpers::TransformsHelper::KB_CORE_COLLECTION_NAME

migrationOutCome = Hash.new { |hh, kk| hh[kk] = {'status' =>  nil, 'dbTag' => nil, 'message' => nil}}

$stderr.puts "-" * 60
$stderr.puts "Starting to scan the databases............."
if(update == true)
  $stderr.puts "Update mode is on ....."
else
  $stderr.puts "Update mode is off ....."
end
$stderr.puts "-" * 60
# Update/check each mongoDbName
mongoDbNames.each { |mongoDbName|
  $stderr.puts "KB: #{mongoDbName.inspect}"
  begin
    status = :OK
    dbTag = ""
    updateTag = "NOT_UPDATED"
    message = ""
    mdb = BRL::Genboree::KB::MongoKbDatabase.new(
        mongoDbName,
        mongoDbrcRec[:driver],
        { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password]}
      )
    if(mdb and mdb.db)
      tvalidator = BRL::Genboree::KB::Validators::TransformValidator.new()
      docValidator = BRL::Genboree::KB::Validators::DocValidator.new()
      transformsHelper = mdb.transformsHelper
      # Get the current transformation model
      modelsHelper = mdb.modelsHelper
      transformsModel = transformsHelper.class.getModelTemplate()
      modelDocName = transformsModel['name']['value']
      currentModel = modelsHelper.modelForCollection(modelDocName, false)
      if(transformsHelper.coll)
        cursor = transformsHelper.coll.find()
        docs = []
        validWithNewModel = true
        validWithCurrentModel = true
        if(cursor.count > 0)
          $stderr.puts "Mongo db #{mongoDbName.inspect} has #{cursor.count} number of documents in kbTransforms collection."
          $stderr.puts "#{cursor.count} documents being validated."
          docs = cursor.collect() {|doc| BRL::Genboree::KB::KbDoc.new(doc) }
          docs.each{|trDoc|
            docID = trDoc.getPropVal('Transformation')
            $stderr.puts '-' * 60
            $stderr.puts "Validating document - #{docID} against the new Model"
            validWithNewModel = tvalidator.validate(trDoc)
            unless(validWithNewModel)
              dbTag = :INVALID_DOC_CORRUPT
              status = :OK
              message = "VALIDATION_FAILED_WITH_NEW_MODEL: Document #{docID} is an invalid document : #{tvalidator.validationErrors.inspect}"
              $stderr.puts "VALIDATION_FAILED_WITH_NEW_MODEL: Doc - #{docID} VALID: #{validWithNewModel}. Validating against the existing model. ERROR_DETAILS: #{tvalidator.validationErrors.inspect}"
              $stderr.puts "Validating #{docID} against the current transformation model now ..........."
              #validWithCurrentModel = docValidator.validateDoc(doc, currentModel)
              #if(validWithCurrentModel)
                #message += "Doc - #{docID} is valid against the current transformation model, but failed against the new Model only. Ths database is corrupt and the transformation documents musts be investigated manually. Moves on to the next DB. "
              #else
                #message += "Doc = #{docID} is invalid against both the current and new model. This database is corrupt and the transformation documents musts be investigated manually. Moves on to the next DB. #{docValidator.validationErrors.join("\n")}"
              #end
              #$stderr.puts "#{message}"
              break
            end
            $stderr.puts "Document - #{docID} is valid - #{validWithNewModel}" if(validWithNewModel)
          }
          (dbTag = :ALL_TRANSFORMATION_DOCS_VALID and status = :OK and message = "") if(validWithNewModel)
        else
          status = :OK
          dbTag = :NO_TRANSFORMATION_DOCS
          message = "No Transformation documents found in this database."
          $stderr.puts "Mongo db #{mongoDbName.inspect} has #{cursor.count} number of documents in kbTransforms collection."
        end
        # If update mode is on, then update the model
        if(update == true and validWithNewModel)
          $stderr.puts "All the documents are valid, ready to update the new model for the db #{mongoDbName.inspect}"
          # Get the existing model record
          trcursor = modelsHelper.coll.find({'name.value' => modelDocName})
          if(trcursor and trcursor.is_a?(Mongo::Cursor) and trcursor.count == 1) # Should be just one
            trcursor.rewind!
            doc = trcursor.first
            $stderr.puts "Getting the docObjId of the transformation model document."
            transformsModel['_id'] = doc['_id']
            trModel = BRL::Genboree::KB::KbDoc.new(transformsModel)
            $stderr.puts "Adding the unique docObjId #{doc['_id'].inspect}to the new transformation model. About to update."
            begin
              docId = modelsHelper.save(trModel, mdb.conn.defaultAuthInfo[:user])
              status = :OK
              updateTag = :UPDATE_COMPLETED
              message = "New transformation successfully updated for the db #{mongoDbName.inspect}. DOCID: #{docId.inspect}"
              $stderr.puts message
            rescue => err
              status = :FAILED
              updateTag = :UPDATE_INCOMPLETE
              message = "Updating the model document failed for the db #{mongoDbName.inspect}. Check #{err.message}\n\n. Moing to the next database."
            end
          else
            status = :FAILED
            updateTag = :CORRUPT
            message = "Failed to retrieve transformation model document from Mongo db #{mongoDbName.inspect}. Update NOT COMPLETE. This database to be examined manually. Moving to the next database"
            $stderr.puts message
          end
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
    migrationOutCome[mongoDbName]['updateTag'] = updateTag
    migrationOutCome[mongoDbName]['message'] = message
    $stderr.puts '-' * 60
  end
}

$stderr.puts '#' *60
$stderr.puts 'Migration Summary'
$stderr.puts '#' *60
$stderr.puts "KB_NAME\tSTATUS\tTAG\tMESSAGE"
migrationOutCome.each_key {|kk|
  $stderr.puts "#{kk}\t#{migrationOutCome[kk]['status']}\t#{migrationOutCome[kk]['dbTag']}\t#{migrationOutCome[kk]['message']}\t#{migrationOutCome[kk]['updateTag']}"
}
$stderr.puts '#' *60
