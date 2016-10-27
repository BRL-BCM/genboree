#!/usr/bin/env ruby
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/stats/kbStats'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  # KbCollections - exposes information about the knowledgebases within a group
  # (currently just the names of the kbs within the group).
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::KbDocEntityList
  # * BRL::Genboree::REST::Data::KbDocEntity
  class Kb < BRL::REST::Resources::GenboreeResource

    # @return [Hash{Symbol=>Object}] Map of what http methods this resource supports ( @{ :get => true, :put => false }@, etc } ).
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    RSRC_TYPE = 'kb'
    SUPPORTED_ASPECTS = { 'description' => "description", 'kbDbName' => "refseqName" }

    # @api RestAPI INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    #   cleanup that might save memory and aid GC. Their version should call {#super}
    #   so any parent {#cleanup} will be done also.
    # @return [nil]
    def cleanup()
      super()
      @groupId = @groupName = @groupDesc = nil
      @mongoKbDb = @mongoDbrcRec = @kbId = @kbName = @kbDbName = nil
    end

    # @api RestAPI INTERFACE. return a {Regexp} that will match a correctly formed URI for this service
    #   The pattern will be applied against the URI's _path_.
    # @returns [Regexp]
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)(?:$|/([^/\?]+)$)}
    end

    # @api RestAPI return integer from 1 to 10 that indicates whether the regexp/service is
    #   highly specific and should be examined early on, or whether it is more generic and
    #   other services should be matched for first.
    # @return [Fixnum] The priority, from 1 t o 10.
    def self.priority()
      return 4
    end

    # Perform common set up needed by all requests. Extract needed information,
    #   set up access to parent group/database/etc resource info, etc.
    # @return [Symbol] a {Symbol} corresponding to a standard HTTP response code [official English text, not the number]
    #   indicating success/ok (@:OK@), some other kind of success, or some kind of failure.
    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @kbName = Rack::Utils.unescape(@uriMatchData[2])
        @aspect = (@uriMatchData[3].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[3])
        # This function will set @groupId if it exists, return value is :OK or :'Not Found'
        initStatus = ( @reqMethod != :put ? initGroupAndKb() : initGroup() ) # Since a PUT can be used to create a new KB, we will only call initGroup() for PUT
        if(@aspect and !SUPPORTED_ASPECTS.key?(@aspect))
          initStatus = :"Bad Request"
          @statusName = :"Bad Request"
          @statusMsg = :"Unsupported aspect: #{@aspect}. Supported aspects include: #{SUPPORTED_ASPECTS.keys.join(",")}"
        end

      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        # @todo if public or subscriber, can get info
        if(READ_ALLOWED_ROLES[@groupAccessStr])
          # Get collections in @kbName
          colls = @mongoKbDb.collections(:data, :names)
          colls.sort { |aa,bb| retVal = (aa.downcase <=> bb.downcase) ; retVal = (aa <=> bb) if(retVal == 0) ; retVal }
          doc = BRL::Genboree::KB::KbDoc.new()
          doc.setPropVal('name', @kbName)
          doc.setPropVal('name.collections', '')
          kbRefSeqName = ( @kbRefSeqName.nil? ? "" : @kbRefSeqName )
          doc.setPropVal('name.kbDbName', kbRefSeqName)
          kbRecs = @dbu.selectKbByNameAndGroupId(@kbName, @groupId)
          description = kbRecs.first['description']
          doc.setPropVal('name.description', (description.nil? ? "" : description) )
          colls.each { |coll|
            doc.addPropItem("name.collections", { "collection" => { "value" => coll } } )
          }
          bodyData = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Gathered data to send:\n\n#{JSON.pretty_generate(bodyData)}\n\n")
          @statusName = configResponse(bodyData)
        else
          @statusName = :Forbidden
          @statusMsg = "FORBIDDEN: You do not have sufficient permissions to perform this operation."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end


    # Process a PUT operation on this resource.
    # @return [Rack::Response] instance configured and containing correct status code, message, and wrapped data;
    #   or containing correct error information.
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(WRITE_ALLOWED_ROLES[@groupAccessStr])
          payload = parseRequestBodyForEntity('KbDocEntity')
          kbRows = @dbu.selectKbByNameAndGroupId(@kbName, @groupId)
          if(kbRows.nil? or kbRows.empty?) # No such KB exists, Create a new one.
             # Empty payload. Will create a new KB with the default settings
            if(payload.nil?)
              begin
                gbDbName = "KB:#{@kbName}"
                kbHelper = BRL::Genboree::KB::Helpers::KbHelper.new("")
                status = kbHelper.createKB(@userId, @genbConf.gbFQDN, @groupName, @kbName, gbDbName, nil, @dbu)
                @statusName = :"Created"
                @statusMsg = "The KB: #{@kbName} was created."
              rescue => err
                if(err.is_a?(BRL::Genboree::GenboreeError))
                  @statusName = err.type
                  @statusMsg = err.message
                else
                  $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
                  $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
                  @statusName = :"Internal Server Error"
                  @statusMsg = err.message
                end
              end
            # Bad Payload. Reject.
            elsif(payload == :'Unsupported Media Type')
              @statusName = :'Unsupported Media Type'
              @statusMsg = "BAD_KB_DOC: The KB document is not valid. Either the document is empty or does not follow the property based document structure. This is not allowed."
            else # Payload is a KbDocEntity.
              if(@aspect.nil?)
                validator = BRL::Genboree::KB::Validators::DocValidator.new()
                kbDoc = BRL::Genboree::KB::KbDoc.new(payload.doc)
                kbModelDoc = BRL::Genboree::KB::KbDoc.new(BRL::Genboree::KB::Helpers::KbHelper::KB_MODEL)
                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "kbDoc:\n\n#{kbDoc.inspect}")
                isValid = validator.validateDoc(kbDoc, kbModelDoc)
                if(isValid)
                  begin
                    if(kbDoc.getPropVal('name').strip == @kbName)
                      gbDbName = "KB:#{@kbName}"
                      if(kbDoc.getPropVal('name.kbDbName'))
                        gbDbName = kbDoc.getPropVal('name.kbDbName')
                      end
                      desc = nil
                      if(kbDoc.getPropVal('name.description'))
                        desc = kbDoc.getPropVal('name.description')
                      end
                      kbHelper = BRL::Genboree::KB::Helpers::KbHelper.new("")
                      status = kbHelper.createKB(@userId, @genbConf.gbFQDN, @groupName, @kbName, gbDbName, desc, @dbu)
                      @statusName = :"Created"
                      @statusMsg = "The KB: #{@kbName} was created. Any collections provided in the payload document have been ignored."
                    else
                      @statusName = :'Unsupported Media Type'
                      @statusMsg = "BAD_DOC: The KB name specified in the payload document is different than the one provided in the resource path. This is not allowed."
                    end
                  rescue => err
                    if(err.is_a?(BRL::Genboree::GenboreeError))
                      @statusName = err.type
                      @statusMsg = err.message
                    else
                      $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
                      $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
                      @statusName = :"Internal Server Error"
                      @statusMsg = err.message
                    end
                  end
                else
                  @statusName = :'Unsupported Media Type'
                  @statusMsg = "BAD_DOC: The document does not follow the specification of the kb model:\n\n#{validator.validationErrors}"
                end
              else
                @statusName = :"Bad Request"
                @statusMsg = "BAD_REQUEST: Cannot update aspect of KB that does not exist."
              end
            end
          else
            # MySql will do case insensitive matching. We need to do exact matching on our side.
            kbRows.each {|kbRow|
              if(@kbName == kbRow['name'])
                @kbId = kbRow['id']
                @kbDbName = kbRow["databaseName"]
                @kbRefSeqName = kbRow['refseqName']
                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "KB found: #{@kbName.inspect}, #{@kbId.inspect}, #{@kbDbName.inspect}")
                # @todo Create a mongodb connection to this databaseName
                # - Get dbrc record for the mongo host backing @reqHost
                dbrc = BRL::DB::DBRC.new()
                @mongoDbrcRec = dbrc.getRecordByHost(@reqHost, :nosql) unless(@mongoDbrcRec and @mongoDbrcRec.is_a?(Hash))
                # - Create MongoKbDb object, which will establish a connection, auth against 'admin' and then auth against actual database
                begin
                  $stderr.debugPuts(__FILE__, __method__, "TIME", "__before__ new MongoKbDatabase" )
                  @mongoKbDb = BRL::Genboree::KB::MongoKbDatabase.new(@kbDbName, @mongoDbrcRec[:driver], { :user => @mongoDbrcRec[:user], :pass => @mongoDbrcRec[:password] })
                  $stderr.debugPuts(__FILE__, __method__, "TIME", "__after__ after new MongoKbDatabase" )
                  #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Made MongoKbDatabase instance:\n\n#{@mongoKbDb.inspect}\n\n")
                rescue => err
                  @statusName = :'Internal Server Error'
                  @statusMsg = "BAD_KB: The GenboreeKB you are trying to access is not present or cannot be accessed by the Genboree server, perhaps due to a configuration or internal authentication problem."
                  $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "Could not make proper connection to #{@kbDbName.inspect} using DSN #{@mongoDbrcRec ? @mongoDbrcRec[:driver].inspect : '[NO VALID DSN STRING FOUND]'}. Possibly authentication info wrong in that database, or preliminary connection to 'admin' database failed. Exception specifics:\n  ERR CLASS: #{err.class}\n  ERR MSG: #{err.message}\n  ERR TRACE:\n#{err.backtrace.join("\n")}")
                end
                # Did the @mongoKbDb.db get set to a valid Mongo::DB? (should have; but MongoKbDatabase allows the db to be provided later)
                unless(@mongoKbDb and @mongoKbDb.db.is_a?(Mongo::DB))
                  @statusName = :'Internal Server Error'
                  @statusMsg = "BAD_KB: While we found the internal name and identifier for #{@kbName} (#{@kbDbName.inspect}, #{@kbId.inspect}), the Genboree server could not establish a valid connection to it. This GenboreeKB is possibly corrupt and/or misconfigured."
                  @kbId = nil
                end
                break
              end
            }
            if(@mongoKbDb and @mongoKbDb.db.is_a?(Mongo::DB))
              if(payload.nil?)
                @statusName = :"Bad Request"
                @statusMsg = "NO_PAYLOAD: Cannot update any aspect of KB without a valid payload."
              elsif(payload == :'Unsupported Media Type')
                @statusName = :'Unsupported Media Type'
                @statusMsg = "BAD_KB_DOC: The KB document is not valid. Either the document is empty or does not follow the property based document structure. This is not allowed."
              else
                if(@aspect)
                  begin
                    payloadKbDoc = BRL::Genboree::KB::KbDoc.new(payload.doc)
                    newContent = payloadKbDoc.getPropVal(@aspect)
                    if(newContent.nil? or newContent.to_s.empty?)
                      @statusName = :"Unsupported Media Type"
                      @statusMsg = "NO_VALUE: You have not provided any value for the '#{@aspect}' field in the payload. This is not allowed. Only updating aspects ( #{SUPPORTED_ASPECTS.keys.join(",")} ) of existing KBs is allowed."
                    end
                    updateRecs = @dbu.updateKbById(@kbId, {SUPPORTED_ASPECTS[@aspect] => newContent}, true)
                    @statusName = :'Moved Permanently'
                    @statusMsg = "The KB was updated with the new information."
                  rescue => err
                    if(err.is_a?(BRL::Genboree::GenboreeError))
                      @statusName = err.type
                      @statusMsg = err.message
                    else
                      $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
                      $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
                      @statusName = :"Internal Server Error"
                      @statusMsg = err.message
                    end
                  end
                else
                  @statusName = :"Bad Request"
                  @statusMsg = "BAD_REQUEST: Only updating aspects ( #{SUPPORTED_ASPECTS.keys.join(",")} ) of existing KBs is allowed. Please refer to API documentation."
                end
              end
            end
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        if(ADMIN_ALLOWED_ROLES[@groupAccessStr])
          # Get kbs table record
          kbRecs = @dbu.selectKbByNameAndGroupId(@kbName, @groupId)
          if(kbRecs and !kbRecs.empty?)
            kbRec = kbRecs.first
            kbRecId = kbRec['id']
            #$stderr.debugPuts(__FILE__, __method__, "STATUS", "KB DROPPING: Found following kbs table record for #{@kbName.inspect} in group #{@groupName.inspect}.\n\n#{kbRec.inspect}\n\n")
            # Drop the mongo database (passes through mongo's result-object)
            dropResult = @mongoKbDb.drop()
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "KB DROPPED: mongo drop result object:\n\n#{JSON.pretty_generate(dropResult) rescue nil}\n\n")
            if(dropResult and dropResult["ok"] == 1)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "KB DROPPING: successfully dropped the mongo DB corresponding to #{@kbName.inspect} in group #{@groupName.inspect}")
              # Remove the kbs-table record that makes Genboree "aware" of the KB (and mongo database)
              delCount = @dbu.deleteKbById(kbRecId)
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "KB DROPPING: When deleting the kbs table record for #{@kbName.inspect} in group #{@groupName.inspect} via 'id', MySQL reported #{delCount.inspect} records were deleted.")
              if(delCount == 1)
                @statusName = :OK
                @statusMsg = "DELETED: GenboreeKB #{@kbName.inspect} in group #{@groupName.inspect} has been deleted! (Cannot be recovered)"
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "KB DROPPED: all done. statusName = #{@statusName.inspect} ; statusMessage = #{@statusMsg.inspect}")
                entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
                entity.setStatus(@statusName, @statusMsg)
                @statusName = configResponse(entity)
              else
                @statusName = :'Internal Server Error'
                @statusMsg = "ERROR/BUG: Underlying mongo database dropped. But could not remove kbs table record when trying to delete #{@kbName.inspect} in group #{@groupName.inspect}. MySQL unexpectedly reported #{delCount.inspect} records were deleted."
              end
            else # drop failed??
              @statusName = :'Internal Server Error'
              @statusMsg = "ERROR/BUG: Tried to drop the underlying mongo database for this KB but it appeared to fail."
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "FAILED to drop mongo database ; kbs table rec:\n\n#{kbRec.inspect}\n\n    @mongoKbDb:\n\n#{@mongoKbDb.inspect}\n\n")
            end
          else
            @statusName = :'Not Found'
            @statusMsg = "NOT FOUND: Cannot find a GenboreeKB named #{@kbName.inspect} within the group #{@groupName.inspect}."
          end
        else
          @statusName = :Forbidden
          @statusMsg = "You do not have sufficient permissions to perform this operation."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "ERROR RAISED: #{err.class} => #{err.message} ; trace:\n\n#{err.backtrace.join("\n")}")
    end
  end # class Kb < BRL::REST::Resources::GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
