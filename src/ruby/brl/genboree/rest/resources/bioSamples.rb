#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/tabularLayoutEntity'
require 'brl/genboree/rest/data/bioSampleEntity'
require 'brl/genboree/abstract/resources/bioSample'
require 'brl/util/util'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # BioSamples - exposes information about the saves tabular layouts for
  # a group / database.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::BioSampleEntity
  # * BRL::Genboree::REST::Data::BioSampleEntityList
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::TextEntityList
  class BioSamples < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::BioSample

    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true }

    # TEMPLATE_URI: Constant to provide an example URI
    # for requesting this resource through the API
    TEMPLATE_URI = "/REST/v1/grp/{grp}/db/{db}/samples"

    RESOURCE_DISPLAY_NAME = "Samples"

    RSRC_TYPE = 'samples'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @dbName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/samples</tt>
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/bioSamples$ URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/(?:bioS|s)amples$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      # Higher priority than grp/{grp}/db/{db}/
      return 4
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        # If format is tabbed, then that ALWAYS implies detailed in the response
        # (doesn't have to be explicitly set)
        @detailed = true if(@repFormat == :TABBED)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK)
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db/#{Rack::Utils.escape(@dbName)}/sample")

          # Get a list of all layouts for this db/group
          bioSampleRows = @dbu.selectAllBioSamples()
          bioSampleRows.sort! { |left, right| left['name'].downcase <=> right['name'].downcase }
          if(@detailed)
            # Process the "detailed" list response
            bodyData = BRL::Genboree::REST::Data::BioSampleEntityList.new(@connect)
            bioSampleRows.each { |row|
              entity = BRL::Genboree::REST::Data::BioSampleEntity.new(@connect, row['name'], row['type'], row['biomaterialState'], row['biomaterialProvider'], row['biomaterialSource'], row['state'], getAvpHash(@dbu, row['id']))
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
              bodyData << entity
            }
          else
            # Process the undetailed (names only) list response
            bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
            bioSampleRows.each { |row|
              entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, row['name'])
              entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(row['name'])}")
              bodyData << entity
            }
          end
          @statusName = configResponse(bodyData)
          bioSampleRows.clear() unless (bioSampleRows.nil?)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource. NOTE: The put() request must
    # include a payload of a BioSampleEntity or it will be rejected as a
    # [+Bad Request+] by this resource.
    # [+returns+] Rack::Response instance
    def put()
      # provide detailed error information concerning put if necessary, rather than an incomprehensible (to users) 
      # backtrace provided by the framework
      begin
        # prepare for operation on this URI
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        initStatus = initOperation()
        initStatus = initGroupAndDatabase() if(initStatus == :OK)
        if(initStatus != :OK or @groupAccessStr == 'r')
          # TODO what should be displayed if initOperation failed?
          @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "You do not have access to create a sample in database #{@dbName.inspect} in user group #{@groupName.inspect}")
        end
  
        # handle any query string parameters
        # importBehavior informs the API how to handle samples in the payload that conflict with those in the database
        validImportBehavior = {
          :create => true,
          :merge => true,
          :replace => true,
          :keep => true,
          nil => true
        }
        if(@nvPairs['importBehavior'].nil? or @nvPairs['importBehavior'].empty?)
          # use default
          importBehavior = :merge
        else
          # use input
          importBehavior = @nvPairs['importBehavior'].downcase.to_sym
        end
        unless(validImportBehavior[importBehavior])
          # provide a warning to debug
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "IMPORT_BEHAVIOR #{importBehavior} not valid!!")
        end
  
        # renameChar informs the API how to rename samples if importBehavior == create
        renameChar = ((@nvPairs.key?('renameChar')) ? @nvPairs['renameChar'] : '_')
  
        # Get the entity from the HTTP request and validate the payload
        entities = parseRequestBodyForEntity('BioSampleEntityList')
        if(entities.nil?)
          # If we have an @apiError set, use it, else set a generic one.
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: To call PUT on this resource, the payload must be a BioSampleEntityList") if(@apiError.nil?)
          raise @apiError
        elsif(entities == :'Unsupported Media Type')
          # If we have an @apiError set, use it, else set a generic one.
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not a BioSampleEntityList") if(@apiError.nil?)
          raise @apiError
        end
  
        # Need to check/validate that all samples have a "name" column
        recCount = 1
        entities.each { |entity|
          if(!entity.respond_to?(:name) or entity.name.nil? or entity.name.empty?)
            msg = "BAD_NAME: Sample record ##{recCount} -> Does not have a proper value in the 'name' column or is"
            msg << " missing the required 'name' column altogether. Aborting sample import."
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', msg)
            @statusName, @statusMsg = @apiError.type, @apiError.message
            raise @apiError
          end
          recCount += 1
        }
  
        # if no error, validations passed
        t1 = Time.now
        sampleNames = entities.collect{ |entity| entity.name}
  
        # act according to import behavior
        if(importBehavior == :create)
          # renaming requires special handling not provided in abstract class
          renameMap = renameSamples(sampleNames, renameChar)
 
          # insert samples with their new names
          samplesToInsert = []
          entities.each{ |entity|
            if(!renameMap[entity.name].nil?)
              # then use the new name for this entity
              entity.name = renameMap[entity.name]
            end
            # mode should be irrelevant because with renaming every sample is new
            insertBioSampleAndAvpHash(@dbu, entity, mode=:merge)
          }

        else
          # use functionality provided by abstract mixin
          entities.each{ |entity|
            insertBioSampleAndAvpHash(@dbu, entity, importBehavior)
          }
        end
  
        # set response status
        @statusName = :'Created'
        @statusMsg = "The samples were successfully added/updated. "
  
        # add messages associated with the specific import behavior options
        if(importBehavior == :create)
          # then add to the message a note about the response body
          unless(renameMap.nil? or renameMap.empty?)
            @statusMsg << "Since you selected the \"#{importBehavior}\" option, we renamed your samples according to the following map where the item "
            @statusMsg << "left of the colon is the sample name you provided and the item right of the colon is its new name: "
            renameMap.keys().sort().each{|kk|
              @statusMsg << "\n  #{kk} : #{renameMap[kk]}"
            }
          end
        end

      rescue => err
        # set apiError if it has not been set already
        if(@apiError.nil?)
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', 
                                                       "Aborting sample import.\nError:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}\n")
        end
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "ERROR: #{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        statusName, @statusMsg = @apiError.type, @apiError.message
        initStatus = @statusName
      end

      # set response, respond with an error if appropriate
      configResponse(BRL::Genboree::REST::Data::BioSampleEntityList.new(false), @statusName)
      @resp = representError() if(!(200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # Rename samples so that PUT samples do not conflict with those already in
    # the database
    #
    # @param sampleNames [Array<String>] the sample names to potentially
    #   rename
    # @param renameChar [String] the character to base the renaming convention
    #   on e.g. "_" will rename mySample to mySample_1 if mySample already
    #   existed in the database
    # @return [Hash] a mapping of the original sample names to new names so
    #   that none of the names conflict with each other or those already in
    #   the database or mapping to nil if no rename is required
    def renameSamples(sampleNames, renameChar)
      renameMap = {}
      renamePattern = /#{"\\" + renameChar}(\d+)$/

      # map name to those with the same basename
      base2LikeNames = {}
      base2SampleNames = Hash.new{|hh, kk| hh[kk] = []}
      sampleNames.each{|sampleName|
        basename = sampleName.gsub(renamePattern, "")
        base2LikeNames[basename] = {}
        base2SampleNames[basename].push(sampleName)
      }

      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "sampleNames=#{sampleNames.inspect}")

      # map basenames to sample names that are already used in the database
      base2LikeNames.each_key{|basename|
        # @todo what if the sample name ends with the rename character?
        likeNames = []
        
        # get exact names
        sampleRecs = @dbu.selectBioSamplesByNames(base2SampleNames[basename])
        unless(sampleRecs.nil? or sampleRecs.empty?)
          likeNames += sampleRecs.collect{|sampleRec| sampleRec['name']}
        end

        # get names that have the rename pattern
        dbPattern = "#{basename}#{renameChar}[0-9]+"
        sampleRecs = @dbu.selectBioSamplesByNameRegexp(dbPattern)
        unless(sampleRecs.nil? or sampleRecs.empty?)
          likeNames += sampleRecs.collect{|sampleRec| sampleRec['name']}
        end
        likeNames.each{|likeName|
          base2LikeNames[basename][likeName] = nil
        }
      }

      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "base2LikeNames=#{base2LikeNames.inspect}")

      # assign new names to samples if needed
      base2LikeNames.each_key{|basename|
        likeNames = base2LikeNames[basename].keys().sort()
        lastName = likeNames[-1]
        matchData = renamePattern.match(lastName)
        unless(matchData.nil?)
          lastN = matchData[1].to_i
        end
        lastN = (lastN.nil? ? 1 : lastN)
        sampleNames = base2SampleNames[basename]
        sampleNames.each{|sampleName|
          if(base2LikeNames[basename].key?(sampleName))
            # then this sample name already existed in the database, rename it
            lastN += 1
            renameMap[sampleName] = "#{basename}#{renameChar}#{lastN}"
          end
        }
      }

      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "renameMap=#{renameMap.inspect}")

      return renameMap
    end

  end # class BioSamples
end ; end ; end # module BRL ; module REST ; module Resources
