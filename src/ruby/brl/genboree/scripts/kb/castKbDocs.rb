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
doInsert = false # Flag to indicate if update/insert should be done
# Standard setup stuff
begin
  dbrc = BRL::DB::DBRC.new()
  dbrcRec = dbrc.getRecordByHost(gbHost, :api)
  mongoDbrcRec = dbrc.getRecordByHost(host, :nosql)
  raise "Can't create/load key config object" unless(dbrc and dbrcRec and mongoDbrcRec)
rescue => err
  $stderr.puts %Q@
    ERROR: Run this script via Genboree-env enabled user like genbadmin.
      * Account must have standard Genboree-related env variables configured
        for the intended Genboree instance, such as: $DBRC_FILE,
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
count = 0
kbInfo = kbRecs.map { |kbRec| [ kbRec['databaseName'], kbRec['name'], kbRec['group_id'] ] }
results = Hash.new { |hh,kk| hh[kk] = { } }
kbRecs.each { |rec|
  mongoDbName = rec['databaseName']
  kb = rec['name']
  $stderr.puts " Scanning KB: #{kb.inspect} (db: #{mongoDbName})"
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
    colls = mdb.collections(:data, :names)
    modelsHelper = mdb.modelsHelper()
    colls.each {|coll|
      begin
        modelDoc = modelsHelper.modelForCollection(coll)
        model =  modelDoc.getPropVal("name.model")
        dataHelper = mdb.dataCollectionHelper(coll) rescue nil
        idPropName = dataHelper.getIdentifierName()
        $stderr.puts " - Coll: #{coll}; Identifer Property: #{idPropName}"
        docCursor = dataHelper.allDocs(:cursor)
        totalDocs = docCursor.entries.size
        docCursor.rewind!
        docsToInsert = {}
        noOfIdentPropsReqCasting = 0
        noOfDocsNotReqCasting = 0
        noOfSubPropsReqCasting = 0
        noOfIdentPropsWithConflict = 0
        noOfSubPropsWithConflict = 0
        # Iterate over all of the docs in the collection and see if a document needs to be updated (requires casting)
        docCursor.each {|doc|
          okToInsert = true
          identPropReqCastingForDoc = false
          castReq = false
          subPropsReqCastingForDoc = []
          docKb = BRL::Genboree::KB::KbDoc.new(doc)
          origDocIdentPropVal = docKb.getPropVal(idPropName)
          $stderr.puts "  - Scanning document: #{origDocIdentPropVal}"
          docKb.cleanKeys!(['_id', :_id]) # Will insert the _id key before doing bulk upload.
          origDocKb = BRL::Genboree::KB::KbDoc.new(doc)
          dv = BRL::Genboree::KB::Validators::DocValidator.new()
          # This should do the casting
          isValid = dv.validateDoc(docKb, model)
          idPropNameVal = docKb.getPropVal(idPropName)
          if(isValid[:result] == :VALID)
            if(dv.modelValidator.needsCastingPropPaths.empty?)
              next
            else # we need to insert the new validated doc which has values of the correct type provided the rules are met.
              uniqProps = [idPropName]
              indexedProps = dv.modelValidator.indexedDocLevelProps
              indexedProps.each_key {|pp|
                if(indexedProps[pp][:unique])
                  uniqProps.push(pp)
                end
              }
              # Iterate over all the 'unique' props and check against the original doc.
              #  - If value is different than the original, check against the db.
              #  - If db already has a doc with the converted value, make sure the ids are the same before inserting
              #  - If Ids different, do not update
              propCount = 0
              uniqProps.each { |pp|
                propCount += 1
                convVal = kbDoc.getPropVal(pp)
                origVal = origDocKb.getPropVal(pp)
                if(origVal.class == convVal.class and origVal == convVal)
                  # There is no change.
                else
                  # We have converted the original value
                  # Check against the db with the new value. 
                  docPath = modelsHelper.modelPath2DocPath(pp, coll)
                  newVal = docKb.getPropVal(pp)
                  docsFoundCursor = dataHelper.coll.find( { docPath => newVal } )  
                  resSize = docsFoundCursor.entries.size
                  if(resSize == 0)
                    if(propCount == 1)
                      identPropReqCastingForDoc = true
                    else
                      subPropsReqCastingForDoc.push(pp)
                    end
                    castReq = true
                  else
                    # Oops. Found something already in the db.
                    docsFoundCursor.rewind!
                    if(resSize == 1)
                      if(docsFoundCursor.entries[0]['_id'] == origDocKb['_id'])
                        if(propCount == 1)
                          identPropReqCastingForDoc = true
                        else
                          subPropsReqCastingForDoc.push(pp)
                        end
                        castReq = true
                      else
                        okToInsert = false
                        if(propCount == 1)
                          noOfIdentPropsWithConflict += 1
                          $stderr.puts "  - IDENT_PROP_CONFLICT: #{origDocIdentPropVal}    (MongoDb: #{mongoDbName}; Coll: #{coll})"
                        else
                          noOfSubPropsWithConflict += 1
                          $stderr.puts "  - SUB_PROP_CONFLICT (Document: #{origDocIdentPropVal}): Property: #{pp}    (MongoDb: #{mongoDbName}; Coll: #{coll})"
                        end  
                      end
                    else
                      okToInsert = false  
                      if(propCount == 1)
                        noOfIdentPropsWithConflict += 1
                        $stderr.puts "  - IDENT_PROP_CONFLICT (2 or more hits): #{origDocIdentPropVal}    (MongoDb: #{mongoDbName}; Coll: #{coll})"
                      else
                        noOfSubPropsWithConflict += 1
                        $stderr.puts "  - SUB_PROP_CONFLICT (Document: #{origDocIdentPropVal}) (2 or more hits): Property: #{pp}    (MongoDb: #{mongoDbName}; Coll: #{coll})"
                      end
                    end
                  end
                end
              }
              if(okToInsert)
                if(identPropReqCastingForDoc)
                  noOfIdentPropsReqCasting += 1 
                  $stderr.puts "  - IDENT_PROP_CAST_REQ: #{origDocIdentPropVal}"  
                end
                if(subPropsReqCastingForDoc.size > 0)
                  noOfSubPropsReqCasting += subPropsReqCastingForDoc.size
                  $stderr.puts "  - SUB_PROP_CAST_REQ (Document: #{origDocIdentPropVal}): #{subPropsReqCastingForDoc.join(",")}"
                end
                unless(castReq)
                  noOfDocsNotReqCasting += 1 
                  $stderr.puts "  - NO_CAST_REQ: #{origDocIdentPropVal}"  
                end
              end
            end
          else
            $stderr.puts "  - Doc: #{origDocIdentPropVal.inspect} failed validation.    (MongoDb: #{mongoDbName}; Coll: #{coll})"
          end
          if(doInsert)
            if(okToInsert)
              docKb['_id'] = origDocKb['_id']
              docsToInsert[idPropName] = docKb
              if(docsToInsert.keys.size >= 1000)
                upsertStatus = dataHelper.bulkUpsert(idPropName, docsToInsert, 'paithank')
                $stderr.puts upsertStatus
                docsToInsert = {}
              end
            end
          end
        }
        results[mongoDbName][coll] = { :totalDocs => totalDocs, :noOfDocsNotReqCasting => noOfDocsNotReqCasting, :noOfIdentPropsReqCasting => noOfIdentPropsReqCasting, :noOfSubPropsReqCasting => noOfSubPropsReqCasting, :noOfIdentPropsWithConflict => noOfIdentPropsWithConflict, :noOfSubPropsWithConflict => noOfSubPropsWithConflict}
        if(doInsert)
          if(!docsToInsert.empty?)
            upsertStatus = dataHelper.bulkUpsert(idPropName, docsToInsert, 'paithank')
            $stderr.puts upsertStatus
            docsToInsert = {}
          end
        end
      rescue => err
        $stderr.puts "  - Failed to process coll: #{coll}\n\nERROR:\n\n#{err}"
        next
      end      
    }
  rescue => err
    $stderr.puts "RESULT: >>FAILED<<\n  - Will continue to next Mongo DB.\n  - Error Details:\n    . Err Class: #{err.class}\n    . Err Msg: #{err.message}\n    . Err Trace:\n#{err.backtrace.join("\n")}"
  ensure
    mdb.clear()
    $stderr.puts '-' * 60
  end
}

# Report:
puts "#{'=' * 60}\n#{'=' * 60}\nSUMMARY:\n\n"
puts "GROUP\tKB NAME\tKB DB NAME\tCOLLECTION\tTotal Docs\t#Docs not Req Casting\t#Ident Props Req Casting\t#Sub Props Req Casting\t#Ident Props With Conflict\t#Sub Props With Conflict"
kbInfo.sort{ |aa, bb| aa[2] <=> bb[2]}.each { |kbInfoRec|
  mongoKbDatabase, kbName, groupId = *kbInfoRec
  # Group name
  grpRecs = dbu.selectGroupById(groupId)
  grpName = grpRecs.first['groupName']
  collStatuses = results[mongoKbDatabase]
  collStatuses.keys.sort().each { |coll|
    statusInfo = collStatuses[coll]
    noOfIdentPropsReqCasting = statusInfo[:noOfIdentPropsReqCasting]
    noOfIdentPropsWithConflict = statusInfo[:noOfIdentPropsWithConflict]
    noOfSubPropsWithConflict = statusInfo[:noOfSubPropsWithConflict]
    noOfSubPropsReqCasting = statusInfo[:noOfSubPropsReqCasting]
    noOfDocsNotReqCasting = statusInfo[:noOfDocsNotReqCasting]
    totalDocs = statusInfo[:totalDocs]
    puts "#{grpName}\t#{kbName}\t#{mongoKbDatabase}\t#{coll}\t#{totalDocs}\t#{noOfDocsNotReqCasting}\t#{noOfIdentPropsReqCasting}\t#{noOfSubPropsReqCasting}\t#{noOfIdentPropsWithConflict}\t#{noOfSubPropsWithConflict}"
  }
}
