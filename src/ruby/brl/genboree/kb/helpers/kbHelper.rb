#!/bin/env ruby

require 'brl/genboree/kb/helpers/abstractHelper'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/dbUtil'

module BRL ; module Genboree ; module KB ; module Helpers
  # This class assists with KB level operations.
  # @note There is no corresponding collection for this helper class like other helper classes.
  # @note The class exists just provides a uniform interface to similar methods defined in other helper classes.
  class KbHelper < AbstractHelper
    KB_CORE_COLLECTION_NAME = ""
    # @return [Hash] A model document or model template which can be used to place an appropriate
    #    model document into the @kbModels@ collection when the database (or this helper's collection)
    #    is first created.
    KB_MODEL =
    {
      "name"        => { "value" => "KB Model", "properties" =>
      {
        "internal"  => { "value" => true },
        "model"     => { "value" =>
          {
            "name"        => "name",
            "description" => "The name of the KB.",
            "identifier"  => true,
            "properties"  =>
            [
              {
                "name"        => "description",
                "description" => "A description of the KB."
              },
              {
                "name"        => "kbDbName",
                "description" => "Name of the Genboree database this KB is linked with.",
              },
              {
                "name"        => "collections",
                "description" => "The list of collections contained within the KB.",
                "items" =>
                [
                  {
                    "name" => "collection",
                    "identifier" => true
                  }
                ]
              }
            ]
          }
        }
      }}
    }

    # Create new instance of this helper.
    # @param [MongoKbDatabase] kbDatabase The KB database object this helper is assisting.
    # @param [String] collName The name of the document collection this helper uses.
    def initialize(kbDatabase, collName="")
      super(kbDatabase, collName)
      unless(collName.is_a?(Mongo::Collection))
        @coll = @kbDatabase.viewsCollection() rescue nil
      end
    end

    # Get the model doc template for the collection this helper assists with.
    # @todo change this from returning KB_MODEL constant
    #   in the respective sub-class, but rather have them loaded from
    #   some .yml files. Maybe cached like the SingletonJSONCache, etc.
    # @param [nil, Object] params Provide any parameters as individual arguments. Generally none are
    #   needed, except for some sub-classes that override this method and need some info.
    # @return [Hash] A suitable model template for the collection this helper assists with.
    def self.getModelTemplate(*params)
      return self::KB_MODEL
    end

    # Helper method to create a new mongoDB database (KB)
    # @param [String] userId The userId of the user creating the KB. Needed to make the associated user database [if neeeded].
    # @param [String] host The name of the host (Example: genboree.org)
    # @param [String] groupName Name of the group in which to create the KB in.
    # @param [String] kbName Name of the kb to create.
    # @param [String] gbDbName Name of the database associated with the KB to create
    # @param [String] description Description of the KB to create
    # @param [Object] dbu DBUtil Instance
    # @param [Object] mongoDbrcRec dbrc record indicating which mongoDB server to connect to.
    def createKB(userId, host, groupName, kbName, gbDbName=nil, description=nil, dbu=nil, mongoDbrcRec=nil)
      retVal = true
      dbrc = BRL::DB::DBRC.new()
      dbu = BRL::Genboree::DBUtil.new("DB:#{host}", nil, nil) unless(dbu)
      grpRecs = dbu.selectGroupByName(groupName)
      raise "Group: #{groupName} does not exist." if(grpRecs.nil? or grpRecs.empty?)
      groupId = grpRecs.first['groupId']
      mongoDbrcRec = dbrc.getRecordByHost(host, :nosql)  unless(mongoDbrcRec and mongoDbrcRec.is_a?(Hash))
      mongoDbName = BRL::Genboree::KB::MongoKbDatabase.constructMongoDbName(host, groupName, kbName)
      mdb = BRL::Genboree::KB::MongoKbDatabase.new(mongoDbName, mongoDbrcRec[:driver], { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password] } )
      mdb.create()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "New mongoDB: #{mongoDbName} created.")
      gbDbName = "KB:#{kbName}" unless(gbDbName)
      insertStatus = dbu.insertKb(groupId, gbDbName, kbName, mongoDbName, description)
      raise "Could not create new kbs record for mongoDbName: #{mongoDbName.inspect} under group: #{groupName} and KB: #{kbName}" if(insertStatus != 1)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "New Kb record inserted for mongoDB: #{mongoDbName}.")
      # Do we need to make the associated database 'gbDbName'
      dbResultSet = dbu.selectRefseqByNameAndGroupId(gbDbName, groupId)
      if(dbResultSet.size < 1)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "There is no user database #{gbDbName.inspect} in group #{groupName.inspect} (#{groupId.inspect}) so we WILL CREATE it.")
        # Create an empty Db
        dbc = BRL::Genboree::DatabaseCreator.new(userId, groupId, gbDbName)
        exitStatus = dbc.createEmptyDb()
        if(exitStatus == 0)
          retVal = true
        else
          retVal = false
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "DatabaseCreator failed with exit status #{exitStatus.inspect}")
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "The user database #{gbDbName.inspect} already existis in group #{groupName.inspect} (#{groupId.inspect}, with refSeqId #{dbResultSet.first["refSeqId"].inspect rescue nil}, so we WON'T CREATE it.")
      end
      return retVal
    end
  end # class ViewsHelper
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers
