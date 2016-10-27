#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/entrypointEntity'
require 'brl/genboree/rest/data/countEntity'
require 'brl/genboree/abstract/resources/entrypoint'
require 'brl/genboree/rest/data/entrypointsEditEntity'
require 'brl/sql/binning'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/fileUploadUtils'
require 'brl/genboree/constants'
require 'brl/genboree/helpers/expander'
require 'brl/util/util'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Entrypoints - exposes information about the collection of entrypoints (chromosomes) within a specific user database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DetailedEntrypointEntityList
  # * BRL::Genboree::REST::Data::DetailedEntrypointEntity
  class Entrypoints < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    SUPPORTED_ASPECTS = {
                          "count" => true
                        }
    RSRC_TYPE = 'entrypoints'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @dbName = @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/eps</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/eps(?:$|/([^/\?]+)$)}      # Look for /REST/v1/grp/{grp}/db/{db}/eps URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other services should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 6          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @aspect = (@uriMatchData[3].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[3])
        # TODO: if @detailed, then everything ; if not then just ep list
        initStatus = initGroupAndDatabase()
      end
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        setResponse()
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # PUT a DetailedEntrypointEntityList, LFF file, or FASTA file
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        epList = parseRequestBody() # Array containing potential EP records. Could also be a hash for renaming eps.
        notRenamed = []
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "ab4 epList=#{epList.inspect} when @repFormat=#{@repFormat}")
        if(!epList.nil? and !epList.empty?)
          if(epList.is_a?(Hash)) # This payload object is only for renaming. The chromosome should already exist. 
            dbRecs = @dbu.selectRefseqByName(@dbName)
            @dbu.setNewDataDb(dbRecs.first['databaseName'])
            epList.each_key { |oldName|
              newName = epList[oldName].keys[0]
              newLength = epList[oldName][newName]
              refRows = @dbu.selectFrefsByName(oldName, true)
              if(!refRows.nil? and !refRows.empty?)
                refId = refRows.first['rid']
                newRefRows = nil
                newRefRows = @dbu.selectFrefsByName(newName, true) if(newName != oldName)
                if(newRefRows.nil? or newRefRows.empty?)
                  @dbu.updateRefNameByRid(refRows.first['rid'], newName) if(newName != oldName)
                  # Calculate rbin
                  binner = BRL::SQL::Binning.new
                  rbin = binner.bin(BRL::SQL::MIN_BIN, 0, newLength)
                  frefRec = refRows.first
                  @dbu.updateFrefRec([frefRec['rid'], newName, newLength, rbin, frefRec['ftypeid'], frefRec['rstrand'], frefRec['gid'], frefRec['gname'] ])
                else
                  notRenamed << oldName
                end
              else
                notRenamed << oldName
              end
            }
            @statusMsg = "The following entrypoints could not be edited/updated because they either do not exist or the name you are trying to rename it to already exists. (#{notRenamed.join(', ')})" unless(notRenamed.empty?)
          else # This can be used for inserting new eps
            epList.each { |ep|
              frefRows = @dbu.selectFrefsByName(ep['name'], true)
              unless(frefRows.nil? or frefRows.empty?)
                # then ep already exists, skip it
              else
                # Calculate rbin
                binner = BRL::SQL::Binning.new
                rbin = binner.bin(BRL::SQL::MIN_BIN, 0, ep['length'])
                # Define default values
                # The values (1, '+', 1, 'Chromosome') are defaults for columns that aren't used but defined to be consistent with the values that Genboree uses
                insertData = ['null', ep['name'], ep['length'], rbin, 1, '+', 1, 'Chromosome']
                @rid = @dbu.insertFrefRec(insertData)
                @statusName = :Created
              end
            }
          end
        end
      end
      if(@statusName == :OK or @statusName == :Created)
        setResponse(@statusName, @statusMsg)
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def setResponse(statusName=:OK, statusMsg='')
      # Get entrypoints in the user database
      epsEntity = nil
      frefRows = nil
      dbIds = @nvPairs['dbIds']
      frefHash = {}
      addDbIds = false
      if( dbIds and ( dbIds == 'true' or dbIds == 'yes') )
        frefRecs = @dbu.selectAllRefNames()
        frefRecs.each {|rec|
          frefHash[rec['refname']] = rec['rid']                      
        }
        addDbIds = true
      end
      if(@aspect.nil?)
        frefRows =  BRL::Genboree::Abstract::Resources::Entrypoint.getFrefRows(@dbu, @databaseName)
        # Transform entrypoint records to return data
        case @repFormat
          when :FASTA
            begin
              # get all expected arguments for fastaHandler from query string
              from = nvPairs['from']
              to = nvPairs['to']
              # try to sensibly convert Booleans in String form in the resource path to the appropriate values
              doAllUpper = ((nvPairs['doAllUpper'].to_s.autoCast(true) == true) ? true : false)
              doAllLower = ((nvPairs['doAllLower'].to_s.autoCast(true) == true) ? true : false)
              doRevCompl = ((nvPairs['doRevCompl'].to_s.autoCast(true) == true) ? true : false)
              # transform epList into a Ruby Array
              unless(nvPairs['epList'].nil?)
                epList = nvPairs['epList'].dup()
                epList = epList.gsub(/[\[\]]/,'')
                epList = epList.split(',')
              else
                epList = nvPairs['epList']
              end
              begin
                # construct entrypoint fasta representation with fastaHandler
                fastaHandler = BRL::Genboree::Abstract::Resources::FastaHandler.new(@groupName, @dbName, epList, from, to, doAllUpper, doAllLower, doRevCompl)
                #bypass configResponse for entrypoint entity and configure response here instead
                @resp.body = fastaHandler
                @resp.status = HTTP_STATUS_NAMES[:OK]
                @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:FASTA]
              rescue ArgumentError => error
                # failed attempts to setupUserDb and access sequence information in the database specified in @groupName, @dbName
                @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "Could not get FASTA because the database #{@groupName}/#{@dbName} is missing sequence information -- usually this is caused when a sequence is not uploaded for the database, try a PUT to eps with FASTA sequence data")
              end
            rescue => error
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "An error occurred while trying to get FASTA sequences: #{error}\n#{error.backtrace.join(" \n")}")
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "An error occurred while trying to get FASTA sequences: #{error}\n#{error.backtrace.join(" \n")}")
            end
          else
            refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/ep") if(@connect)
            epsEntity = BRL::Genboree::REST::Data::DetailedEntrypointEntityList.new(@connect, frefRows.size)
            frefRows.each { |row|
              refName = row['refname']
              entity = BRL::Genboree::REST::Data::DetailedEntrypointEntity.new(@connect, refName, row["rlength"], row['gname'])
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(refName)}") if(@connect)
              entity.dbId = frefHash[refName] if(addDbIds)
              epsEntity << entity
            }
            epsEntity.setStatus(statusName, statusMsg)
            configResponse(epsEntity)            
        end
      else
        if(SUPPORTED_ASPECTS.key?(@aspect))
          if(@aspect == 'count')
            frefCountRecs = @dbu.countFrefs()
            frefCount = frefCountRecs[0][0]
            epsEntity = BRL::Genboree::REST::Data::CountEntity.new(@connect, frefCount)
          end
          epsEntity.setStatus(statusName, statusMsg)
          configResponse(epsEntity)
        else
          @statusName = :'Not Found'
          @statusMsg = "Unknown aspect #{@aspect}"
        end
      end
      frefRows.clear() if(frefRows)
    end

    # Helper method that idetifies the format of the request body and parses it.
    # Raises exceptions if there are errors that should stop the process.
    #
    # [+returns+] Array
    def parseRequestBody()
     epList = [] # Array containing potential EP records
      if(@repFormat == :LFF or @repFormat == :LFF3COL or @repFormat == :FASTA)
        if(@repFormat != :FASTA)
          epList = BRL::REST::Resources::Entrypoints.parseRequestBodyFor3ColLFF(self.readAllReqBody(), @dbu, @dbName, @groupId, @userId)
        else
          userRows = @dbu.getUserByUserId(@userId)
          userName, userEmail = userRows.first['name'], userRows.first['email']
          refseqRecs = @dbu.selectRefseqByNameAndGroupId(@dbName, @groupId)
          refseqId = refseqRecs.first['refSeqId']
          fullDbName = refseqRecs.first['databaseName']
          directoryToUse = BRL::Genboree::Helpers::FileUploadUtils.createFinalDir(BRL::Genboree::Constants::UPLOADDIRNAME, fullDbName, CGI.escape(userName))
          origFastaFile = "#{directoryToUse}/genb.#{Time.now.to_f}.#{rand(10_000)}.fasta.orig"
          fastaWriter = File.open(origFastaFile, "w")
          # keep track of which entrypoints we are writing based on the defline required by FASTA format
          refNameList = []
          @req.body.each{ |line|
            if(line[0,1] == '>')
              # add the refName to our list
              # anticipate the following defline formats: ">#{refName}", ">#{refName}:#{start}-#{stop}",
              #   ">#{deflineID}|#{@refName}|#{@from}|#{@to}| DNA_SRC: #{@refName} START: #{@from} STOP: #{@to} STRAND: #{@doRevCompl ? '-' : '+'} "
              if(line.index('|').nil?)
                # then one of the two non pipe formats
                deflineTokens = line.split(':')
                refName = deflineTokens[0][1, deflineTokens[0].length]
              else
                # then the pipe format
                deflineTokens = line.split('|')
                refName = deflineTokens[1]
              end
              refNameList << refName
            end
            fastaWriter.write(line)
          }
          fastaWriter.close()
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "ab4 refNameList=#{refNameList}")
          # allow legacy java code to overwrite existing entrypoints by deleting them here
          # java checks for permission to delete -- perhaps this delete should be done there as well?
          @dbu.setNewDataDb(refseqId)
          refNameList.each{ |refname|
            ridRecs = @dbu.selectRidByName(refname)
            unless(ridRecs.nil?)
              ridRecs.each{ |ridHash|
                rid = ridHash['rid']
                @dbu.deleteRid2RidSeqId(rid)
              }
            end
          }
          # run legacy java code
          extractedFile = origFastaFile.gsub(/\.orig/, "")
          inflateCmd = "expander.rb -f #{origFastaFile} -o #{extractedFile}"
          suppressEmail = @nvPairs.key?('suppressEmail') ? true : false
          importCmd = BRL::Genboree::Helpers::DataImport.buildFastaUploadCmd(extractedFile, @userId, refseqId, useCluster=false, suppressEmail, true)
          importCmd = "#{inflateCmd} ; source #{@genbConf.javaSourceFile}; #{importCmd} "
          wrappedCmd = BRL::Genboree::Helpers::DataImport.wrapCmdForRubyTaskWrapper(importCmd, directoryToUse)
          $stderr.puts(Time.now.to_s + " DEBUG: importCmd \n" + importCmd.inspect)
          $stderr.puts(Time.now.to_s + " DEBUG: wrapperCmd \n" + wrappedCmd.inspect)
          # Run actual import command
          `/usr/bin/nohup #{wrappedCmd}`
          exitObj = $?.dup()
          if(exitObj.exitstatus != 0)
            @apiError = BRL::Genboree::GenboreeError.new(:"Internal Server Error", "Command to upload FASTA file failed: #{wrappedCmd}")
            @statusName = :"Internal Server Error"
            @statusMsg = "Command to upload FASTA file failed: #{wrappedCmd}"
          else
            @statusName = :Created
          end
        end
        @repFormat = :JSON # Change the format back into json for responding to client
      else # format is default, JSON
        entity = parseRequestBodyForEntity(['DetailedEntrypointEntityList'])
        if(!entity.nil? and entity != :'Unsupported Media Type')
          epList = entity.entrypoints
        else
          entity = parseRequestBodyForEntity(['EntrypointsEditEntity'])
          if(!entity.nil? and entity != :'Unsupported Media Type')
            epList = entity.epHash
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', 'The format of the request body is not supported for this operation.')
          end
        end
      end
      return epList
    end


    # Method used to parse the request body and return an array of hashes containing keys (name, type, length)
    # Raises exceptions if there are errors that should stop the process and sets status accordingly
    #
    # [+reqBody+] The Request body, typically generated by self.readAllReqBody()
    # [+returns+] Array of Hashes
    def self.parseRequestBodyFor3ColLFF(reqBody, dbu=nil, dbName=nil, groupId=nil, userId=nil)
      epList = []
      lffFile = ''
      if(dbu.nil?) # Old approach
        lffFile = reqBody
      else
        userRows = dbu.getUserByUserId(userId)
        userName, userEmail = userRows.first['name'], userRows.first['email']
        refseqRecs = dbu.selectRefseqByNameAndGroupId(dbName, groupId)
        refseqId = refseqRecs.first['refSeqId']
        fullDbName = refseqRecs.first['databaseName']
        directoryToUse = BRL::Genboree::Helpers::FileUploadUtils.createFinalDir(BRL::Genboree::Constants::UPLOADDIRNAME, fullDbName, CGI.escape(userName))
        origEpFile = "#{directoryToUse}/genb.#{Time.now.to_f}.#{rand(10_000)}.3colff.orig"
        lffWriter = File.open(origEpFile, "w")
        lffWriter.write(reqBody)
        lffWriter.close()
        exp = BRL::Genboree::Helpers::Expander.new(origEpFile)
        exp.extract('text')
        lffFile = File.read(exp.uncompressedFileName) # Should be fine to read into memory. No actual sequence data
      end
      lineCount = 0
      # Validate the lff file
      if(lffFile.empty?)
        @apiError = BRL::Genboree::GenboreeError.new(:"Bad Request", "The request body can not be empty for this operation.")
      end
      # Process lines and add to array
      lffFile.each_line { |line|
        lineCount += 1
        ep = {} # Hash used for an entrypoint which will be added to epList
        lineParts = line.split()
        if(lineParts.size != 3)
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "Check that the format of the LFF file is correct, Column count is not 3. (line: #{lineCount})")
        else
          ep['name'], ep['type'], ep['length'] = lineParts[0], lineParts[1], lineParts[2]
          # Make sure type is 'Chromosome'
          if(ep['type'].downcase != 'chromosome')
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "Genboree does not support entry points that are not chromosomes (line: #{lineCount})")
          elsif(ep['length'] !~ /^\d+$/)
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The format of the entry point length (#{ep['length']}) is invalid, must be an integer (line: #{lineCount})")
          else
            # It's ok, add it to the list
            epList << ep
          end
        end
      }
      return epList
    end

    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        entity = parseRequestBodyForEntity(['TextEntityList'])
        if(!entity.nil? and entity != :'Unsupported Media Type')
          dbRecs = @dbu.selectRefseqByName(@dbName)
          @dbu.setNewDataDb(dbRecs.first['databaseName'])
          entity.each { |epObj|
            ep = epObj.text
            @dbu.deleteFrefByName(ep)
          }
          @statusName = :Deleted
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', 'The format of the request body is not supported for this operation.')
          @statusMsg = "The format of the request body is not supported for this operation"
        end
      end
      if(@statusName == :OK or @statusName == :Deleted)
        setResponse(@statusName, @statusMsg)
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

  end # class Entrypoints
end ; end ; end # module BRL ; module REST ; module Resources
