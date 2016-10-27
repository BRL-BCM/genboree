#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/entrypointEntity'
require 'brl/sql/binning'
require 'brl/genboree/rest/resources/entrypoints'
require 'brl/util/util'
require 'brl/genboree/abstract/resources/fastaHandler'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Entrypoint - exposes information about entrypoints (chromosomes) within specific user databases.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::DetailedEntrypointEntity
  class Entrypoint < BRL::REST::Resources::GenboreeResource

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true , :delete => true}

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @refseqRow.clear() if(@refseqRow)
      @epName = @dbName = @refseqRow = @refSeqId = @databaseName = @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/ep/([^/\?]+)</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/ep/([^/\?]+)}      # Look for /REST/v1/grp/{grp}/db/{db}/ep/{ep} URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 6          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @epName = Rack::Utils.unescape(@uriMatchData[3])
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          # Get entrypoint row in the user database
          frefRows = @dbu.selectFrefsByName(@epName, true)
          unless(frefRows.nil? or frefRows.empty?)
            frefRow = frefRows.first
            @rid = frefRow['rid']
            @epLength = frefRow["rlength"]
          else # no such entrypoint
            initStatus = :'Not Found'
            @statusMsg = "NO_EP: There is no entrypoint #{@epName.inspect} in user database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
          end
          frefRows.clear() if(frefRows)
        end
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      @statusName = initOperation()
      setResponse() if(@statusName == :OK)
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # The put function for this resource will add or update and entrypoint
    def put()
      initStatus = initOperation()
      payloadHash = parseRequestBody() # Hash containing the data from the payload that will be the same for any format
      if(@apiError.nil?)
        if(payloadHash.empty?)
          @apiError = BRL::Genboree::GenboreeError.new(:"Bad Request", "The request body can not be empty for this operation.")
        else
          if(initStatus == :OK) # Update
            updateEntrypoint(payloadHash)
          elsif(initStatus == :'Not Found') # Create
            insertEntrypoint(payloadHash)
          end
          if(@statusName == :OK or @statusName == :Created or @statusName == :'Moved Permanently' or @statusName == :'Not Modified')
            setResponse()
          end
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        @dbu.deleteByFieldAndValue(:userDB, 'rid2ridSeqId', 'rid', @rid, "BRL::REST::Resources::GenboreeResource::EntryPoint.delete")
        rows = @dbu.deleteByFieldAndValue(:userDB, 'fref', 'rid', @rid, "BRL::REST::Resources::GenboreeResource::EntryPoint.delete")
        if(rows > 0)
          entity = AbstractEntity.new()
          entity.setStatus(:OK, "DELETED: Entrypoint successfully deleted.")
          @statusName = configResponse(entity, :OK)
        else
          @statusName = :'Not Modified'
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def setResponse(statusName=@statusName, statusMsg=@statusMsg)
      retVal = nil
      # Get entrypoint row in the user database
      frefRows = @dbu.selectFrefsByName(@epName, true)
      unless(frefRows.nil? or frefRows.empty?)
        frefRow = frefRows.first
        # Transform entrypoint record to return data
        case @repFormat
          when :CHR_BAND_PNG
            # To create a cytoband image of the annotations, we need a landmark specified
            @landmark = @epName if(@landmark.nil? or @landmark.empty?)  # Then assume we want the whole chromosome drawn
            begin
              # Create a cytoband drawer
              drawer = BRL::Genboree::Graphics::CytobandDrawer.new(@dbu, @databaseName, @userId, @genbConf)
              drawOpts = Hash.new()
              drawOpts['height'] = @nvPairs['pxHeight']
              drawOpts['width'] = @nvPairs['pxWidth']
              drawOpts['orientation'] = @nvPairs['orientation']
              drawOpts['topMargin'] = @nvPairs['topMargin']
              drawOpts['rightMargin'] = @nvPairs['rightMargin']
              drawOpts['bottomMargin'] = @nvPairs['bottomMargin']
              drawOpts['leftMargin'] = @nvPairs['leftMargin']

              # Generate a cytoband image for the annotations in this track - Returned as a blog (string)
              #image = drawer.createCytobandImageForTrack(@landmark, @ftypeHash, drawOpts)
              image = drawer.createCytobandImageForChrom(@landmark, drawOpts)

              # Return the image
              @resp.status = HTTP_STATUS_NAMES[:OK]
              @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:CHR_BAND_PNG]
              @resp.body = image
              retVal = @resp
            rescue => error
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "An error occurred while trying to draw the cytoband image: #{error}\n#{error.backtrace.join(" \n")}")
              $stderr.puts "ERROR: An error occurred in BRL::Util::CytobandDrawer#createCytobandImage: #{error}\n#{error.backtrace.join(" \n")}"
            end
          when :FASTA
            begin
              # get all expected arguments for fastaHandler from query string
              from = nvPairs['from']
              to = nvPairs['to']
              # try to sensibly convert Booleans in String form in the resource path to the appropriate values
              doAllUpper = ((nvPairs['doAllUpper'].to_s.autoCast(true) == true) ? true : false)
              doAllLower = ((nvPairs['doAllLower'].to_s.autoCast(true) == true) ? true : false)
              doRevCompl = ((nvPairs['doRevCompl'].to_s.autoCast(true) == true) ? true : false)
              begin
                # construct entrypoint fasta representation with fastaHandler
                fastaHandler = BRL::Genboree::Abstract::Resources::FastaHandler.new(@groupName, @dbName, @epName, from, to, doAllUpper, doAllLower, doRevCompl)
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
          else  # assume format is one of usual ones (JSON, XML, YAML)
            epsEntity = BRL::Genboree::REST::Data::DetailedEntrypointEntity.new(@connect, frefRow['refname'], frefRow["rlength"])
            epsEntity.setStatus(statusName, statusMsg)
            @statusName = configResponse(epsEntity, statusName)
        end
      end
      return retVal
    end

    # Helper method that idetifies the format of the request body and parses it.
    # Raises exceptions if there are errors that should stop the process.
    #
    # [+returns+] Hash
    def parseRequestBody()
      payloadHash = {} # Hash containing the data from the payload that will be the same for any format
      # parse the payload depending on the value of the url param 'format' and assign values to payloadHash
      if(@repFormat == :LFF)
        epList = BRL::REST::Resources::Entrypoints.parseRequestBodyFor3ColLFF(self.readAllReqBody())
        payloadHash = epList.first
      elsif(@repFormat == :CHR_BAND_PNG)
        @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', 'The chr_band_png PNG format can only be used to get a representation of this chromosome, not to upload one.')
      elsif(@repFormat == :FASTA)
        @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', 'The FASTA format can only be used to upload FASTA data through the eps resource, not ep resource.')
      else # default format JSON
        entity = parseRequestBodyForEntity(['DetailedEntrypointEntity'])
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', 'The format of the request body is not supported for this operation.')
        else
          payloadHash['name'], payloadHash['length'] = entity.name, entity.length
        end
      end
      return payloadHash
    end

    # Helper method that updates an entrypoint
    # Raises exceptions if there are errors that should stop the process and sets status accordingly
    #
    # [+epHash+]  Hash containing the data from the payload
    # [+returns+] Status
    def updateEntrypoint(epHash)
      # Only support updating the name of the entrypoint.
      # Check if the submitted length is different and warn accordingly
      if(epHash['length'].to_i != @epLength.to_i)
        @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "Updating the length of the entrypoint is not supported.  The value of 'length' can not be different.")
      else
        updateData = {'refname' => epHash['name']}
        rowsUpdated = @dbu.updateFrefByRid(@rid, updateData)
        if(rowsUpdated == 1)
          @epName = epHash['name']
          @statusName, @statusMsg = :'Moved Permanently', "The entrypoint '#{@epName}' has been renamed."
        else
          @statusName, @statusMsg = :OK, "The entrypoint has not been updated."
        end
      end
      return @statusName
    end

    # Helper method that inserts an entrypoint
    # Raises exceptions if there are errors that should stop the process and sets status accordingly
    #
    # [+epHash+]  Hash containing the data from the payload
    # [+returns+] Status
    def insertEntrypoint(epHash)
      if(@epName != epHash['name'])
        @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "The name of the entrypoint in the request body does not match the name of the entrypoint resource")
      else
        # Calculate rbin
        binner = BRL::SQL::Binning.new
        rbin = binner.bin(BRL::SQL::MIN_BIN, 0, epHash['length'])
        # The values (1, '+', 1, 'Chromosome') are defaults for columns that aren't used but defined to be consistent with the values that Genboree uses
        insertData = ['null', epHash['name'], epHash['length'], rbin, 1, '+', 1, 'Chromosome']
        @rid = @dbu.insertFrefRec(insertData)
        if(@rid > 0)
          @statusName, @statusMsg = :Created, "The entrypoint '#{@epName}' has been added."
        else
          @statusName, @statusMsg = :'Not Modified', "The entrypoint has not been added."
        end
      end
      return @statusName
    end

  end # class Entrypoint
end ; end ; end # module BRL ; module REST ; module Resources
