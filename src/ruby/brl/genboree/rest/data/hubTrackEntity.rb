#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/abstract/resources/hub'

module BRL ; module Genboree ; module REST ; module Data

  # HubTrackEntity - Representation of a Hub Track
  class HubTrackEntity < BRL::Genboree::REST::Data::AbstractEntity
    extend BRL::Genboree::Abstract::Resources::Hub

    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :UCSC_HUB ]

    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :HubTrack

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # recognize file/track urls even if they have aspects
    TRK_REGEXP = %r{^http://([^/]+)/REST/v\d+/grp/([^/]+)/db/([^/]+)/trk/([^/\?]+)($|[/\?].*)} # adapted from trk api helper 
    FILE_REGEXP = %r{^http://([^/]+)/REST/v\d+/grp/([^/]+)/db/([^/]+)/(?:file|fileData)/([^/\?]+)($|[/\?].*)} # adapted from file api helper 

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ 'type', 'trkUrl', 'dataUrl' ]
    SIMPLE_FIELD_VALUES = [ '', '', '' ]

    # @todo TODO may not be able to handle trkUrl/dataUrl with generic method
    # left as trkUrl for now
    UCSC_FIELD_MAP = {
      "track" => "trkKey",
      "type" => "type",
      "bigDataUrl" => "trkUrl",
      "shortLabel" => "shortLabel",
      "longLabel" => "longLabel"
    }

    attr_reader :trkKey
    attr_reader :type
    attr_reader :shortLabel
    attr_reader :trkUrl
    attr_reader :dataUrl
 
    # fields with integrity checking
    def trkKey=(value)
      trkKeyPattern = /^[A-Za-z][A-Za-z0-9_]+$/
      trkKeyMatch = trkKeyPattern.match(value)
      if(trkKeyMatch.nil?)
        err = BRL::Genboree::GenboreeError.new(:"Bad Request",
          "Unable to create hubTrackEntity because the given trkKey=#{value.inspect} does not conform to UCSC requirements. "\
          "It must consist of a letter followed exclusively by letters, numbers, or \"_\".")
        raise err
      end
      @trkKey = value
    end
    def type=(value)
      supportedTypes = ['bigWig', 'bigBed', 'vcfTabix', 'bam']
      if(value.nil? or value.empty?)
        err = BRL::Genboree::GenboreeError.new(:"Bad Request",
          "Unable to create hubTrackEntity because it cannot be created with a nil or empty (String) type field")
        raise err
      else
        unless(supportedTypes.include?(value))
          err = BRL::Genboree::GenboreeError.new(:"Bad Request",
            "Unable to set type=#{value.inspect} because it is not a supported type (#{supportedTypes.join(" or ")}).")
          raise err
        else
          @type = value
        end
      end
    end
    def shortLabel=(value)
      maxShortLabel = 17
      if(value.length <= maxShortLabel)
        @shortLabel = value
      else
        @shortLabel = value[0...maxShortLabel]
      end
    end
    def trkUrl=(value)
      # ensure trkUrl is a Genboree track url
      trkMatchData = TRK_REGEXP.match(value)
      unless(trkMatchData.nil?)
        @trkUrl = value
      else
        err = BRL::Genboree::GenboreeError.new(:"Bad Request",
          "Unable to set the trkUrl=#{value.inspect} because it is not a valid Genboree track URL")
        raise err
      end
    end
    def dataUrl=(value)
      # ensure dataUrl is a Genboree file url
      fileMatchData = FILE_REGEXP.match(value)
      unless(fileMatchData.nil?)
        @dataUrl = value
      else
        err = BRL::Genboree::GenboreeError.new(:"Bad Request",
          "Unable to set the dataUrl=#{value.inspect} because it is not a valid Genboree file URL")
        raise err
      end
    end

    attr_accessor :longLabel
    attr_accessor :parent_id
    attr_accessor :aggTrack
    # hash to store display settings from trkUrl in; assumes hash has been cleaned of attributes like track, shortLabel, etc.
    attr_accessor :displaySettings 
    attr_accessor :generatedKey # set to true if trkKey generated from trkUrl

    # CONSTRUCTOR for this entity; field descriptions copied from UCSC at Step 7 of
    #   https://genome.ucsc.edu/goldenPath/help/hgTrackHubHelp.html#Setup
    # @param [Boolean] doRefs add "refs" field in any representation of this entity?
    # @param [String] trkKey the symbolic name of the track. The first character must be a letter, and the remaining characters must be letters, numbers, or under-bar ("_")
    # @param [:bigwig, :bigbed, :bam, :vcftabix] type the format of the file specified by bigDataUrl. Must be either 
    #   bigWig, bigBed, bam or vcfTabix.
    #   full URL. If it is not prefaced by a protocol, such as http://, https:// or ftp://, then it is considered to be
    #   a path relative to the trackDb.txt file
    # @param [Fixnum] parent_id
    # @param [String] aggTrack
    # @param [String] trkUrl
    # @param [String] dataUrl
    # @param shortLabel [String] the short name for the track displayed in the track list, in the configuration and 
    #   track settings, and on the details pages. Suggested maximum length is 17 characters
    # @param longLabel [String] the longer description label for the track that is displayed in the configuration and 
    #   track settings, and on the details pages. Suggested maximum length is 80 characters
    def initialize(doRefs=true, type='', trkUrl=nil, dataUrl=nil, trkKey=nil, shortLabel=nil, longLabel=nil, parent_id=nil, aggTrack=nil, displaySettings=nil)
      super(doRefs)
      # bit of a hack to allow trkUrl and/or dataUrl but not neither from the framework
      trkUrl = nil if(trkUrl.nil? or trkUrl.empty?)
      dataUrl = nil if(dataUrl.nil? or dataUrl.empty?)
      self.update(trkUrl, type, parent_id, aggTrack, trkKey, dataUrl, shortLabel, longLabel, displaySettings)
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.from_json method to parse a JSON
    # representation. If the entity is not complex (just has the fields listed in
    # its +SIMPLE_FIELD_NAMES+ +Array+), then the default implementation will make use
    # of the #jsonCreateSimple helper method to do the conversion--no need to override.
    # @param [Hash] parsedJsonResult  The @Hash@ or @Array@ resulting from parsing the JSON string.
    # @return [WorkbenchJobEntity]  Instance of this class, whose state comes from data within +parsedJsonResult+.
    def self.from_json(parsedJsonResult)
      retVal = super(parsedJsonResult) # sets type
      unless(retVal.is_a?(BRL::Genboree::REST::Data::HubTrackEntity))
        err = BRL::Genboree::GenboreeError.new(:"Unsupported Media Type",
          "Unable to create hub track entity")
        raise err
      end

      # since trkUrl or dataUrl must be set we can generate a trkKey
      retVal.generatedKey = false
      trkKey = parsedJsonResult['trkKey']
      if(trkKey.nil?)
        retVal.trkKey = retVal.generateTrkKey() # sets @generatedKey = true
      else
        retVal.trkKey = trkKey # validated by setter
      end

      # fill in missing short label with data url information
      shortLabel = parsedJsonResult['shortLabel']
      if(shortLabel.nil?)
        unless(retVal.dataUrl.nil?)
          fileMatchData = FILE_REGEXP.match(retVal.dataUrl)
          unless(fileMatchData.nil?)
            # if nil should have errored earlier but just in case that changes
            retVal.shortLabel = fileMatchData[4]
          end
        end
      else
        retVal.shortLabel = shortLabel
      end

      # other fields
      retVal.longLabel = parsedJsonResult['longLabel']
      retVal.parent_id = parsedJsonResult['parent_id']
      retVal.aggTrack = parsedJsonResult['aggTrack']

      # display settings from underlying trkUrl
      retVal.displaySettings = parsedJsonResult['displaySettings']

      return retVal
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # @see initialize
    def update(trkUrl, type, parent_id, aggTrack, trkKey, dataUrl, shortLabel, longLabel, displaySettings)
      @refs.clear() if(@refs)

      # required fields
      @type = type

      # fields with validation but may be left nil
      @shortLabel = shortLabel unless(shortLabel.nil?)
      @trkUrl = trkUrl unless(trkUrl.nil?)
      @dataUrl = dataUrl unless(dataUrl.nil?)

      # based on validated fields
      # at least one of trkUrl or dataUrl must be set
      if(@trkUrl.nil? and @dataUrl.nil?)
        err = BRL::Genboree::GenboreeError.new(:"Bad Request",
          "Unable to create a hubTrackEntity because both the \"trkUrl\" and \"dataUrl\" fields are "\
          "missing. Please provide at least one of them.")
        raise err
      end

      # since trkUrl or dataUrl must be set we can generate a trkKey
      @generatedKey = false
      if(trkKey.nil?)
        @trkKey = generateTrkKey() # sets @generatedKey = true
      else
        @trkKey = trkKey # validated by setter
      end

      # fields that wont cause validation errors even if set to nil
      @longLabel, @parent_id, @aggTrack, = longLabel, parent_id, aggTrack
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # @return [Hash, Array] representation of this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate.
    def getFormatableDataStruct()
      data =  {
                "trkKey" => @trkKey,
                "type" => @type,
                "parent_id" => @parent_id,
                "aggTrack" => @aggTrack,
                "trkUrl" => @trkUrl,
                "dataUrl" => @dataUrl,
                "shortLabel" => @shortLabel, 
                "longLabel" => @longLabel
              }
      data['refs'] = @refs if(@refs)
      retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
      return retVal
    end

    # @api RestDataEntity
    # GENBOREE INTERFACE. Subclasses inherit; override if subclass has more than just its SIMPLE_FIELD_VALUES
    # or if the SIMPLE_FIELD_VALUES don't match the @-style instance variable names.
    #
    # Get a {Hash} or {Array} that represents this entity.
    # Generally used to convert to some String format for serialization. Especially to JSON.
    # @note Must ONLY use Ruby primitives (String, Fixnum, Float, booleans) or
    #   basic Ruby collections (Hash, Array). No custom classes.
    # @param [Boolean] wrap Indicating whether the standard Genboree wrapper should be used to
    #   contain the representation or not. Generally true, except when the representation is
    #   within a parent representation [which is likely wrapped].
    # @return [Hash,Array] representing this entity (or collection of entities)
    #   wrapped in the standardized Genboree wrapper, if appropriate.
    def toStructuredData(wrap=@doWrap)
      data =
      {
        "trkKey" => @trkKey,
        "type" => @type,
        "parent_id" => @parent_id,
        "aggTrack" => @aggTrack,
        "trkUrl" => @trkUrl,
        "dataUrl" => @dataUrl,
        "shortLabel" => @shortLabel, 
        "longLabel" => @longLabel
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end


    # Create a trkKey from either the trkUrl or the dataUrl (at least 1 was set if object exists)
    # @return [String] trkKey that was generated from url
    # @note NOTE @trkUrl must be set
    def generateTrkKey()
      urlToUse = ((@dataUrl.nil? or @dataUrl.empty?) ? @trkUrl : @dataUrl)
      @trkKey = self.class.generateTrkKey(urlToUse)
      @generatedKey = true
      return @trkKey
    end

    # Generate a trkKey according to UCSC conventions (in case one is not provided)
    # @param [String] url the track or file url to base the trkKey off of
    # @return [String] trkKey generated from the URL
    def self.generateTrkKey(url)
      trkKey = ''
      maxLength = 255 # set by our db, ucsc doesnt specify max length

      if(matchData = self::TRK_REGEXP.match(url))
      elsif(matchData = self::FILE_REGEXP.match(url))
      else
        err = BRL::Genboree::GenboreeError.new(:"Internal Server Error",
          "Unable to generate track key for #{url.inspect} because it is neither a Genboree track url nor a Genboree file url")
        raise err
      end
      
      # if no error then match
      host, group, db, name = CGI.unescape(matchData[1]), CGI.unescape(matchData[2]), CGI.unescape(matchData[3]), CGI.unescape(matchData[4])
      # modify name to act as a trkKey according to UCSC requirements: only A-Za-z0-9_ and A-Za-z must be first
      name.gsub!(":", "_")
      name.gsub!(/[^A-Za-z0-9]/, "_")
      chrRegexp = /[A-Za-z]/
      unless(chrRegexp.match(name[0..0]))
        # prepend "t" for trkKey/track
        name = "t" + name
      end
      uniqueString = url.generateUniqueString().xorDigest(8, :alphaNum)
      begin
        trkKey = self.append(name, uniqueString, maxLength)
      rescue ArgumentError => err
        newErr = BRL::Genboree::GenboreeError.new(:"Internal Server Error", 
          "Caught err=#{err.inspect}, probably caused by setting xorDigest argument greater than maxLength")
        raise newErr
      end

      return trkKey
    end

    # Append add to src without exceeding maxLength by deleting characters from src as necessary
    # @param [String] src the source string to append to (will not be modified)
    # @param [String] add to string to append to source
    # @param [Integer] maxLength the maximum length for the resulting string to enforce
    # @return [String] add appended to src (with potentially missing characters from src)
    # @todo TODO move this to brl/util/util if desired
    def self.append(src, add, maxLength)
      retVal = ''
      copy = src.dup()
      if(copy.length >= maxLength)
        copy = copy[0...maxLength]
      end
    
      if(add.length > maxLength)
        raise ArgumentError, "add.length=#{add.length} > maxLength=#{maxLength}"
      end
    
      addedLength = copy.length + add.length
      if(addedLength <= maxLength)
        copy << add
        retVal = copy
      else
        # if no previous error, even if src='' and add.length=maxLength we are still fine
        overBy = addedLength - maxLength
        copy[-overBy...maxLength] = add
        retVal = copy
      end
      return retVal
    end

    # Represent hubTrackEntity in UCSC stanza format
    # @return [String] stanza representation of hubTrackEntity
    def to_ucsc()
      retVal = ''
      bigDataUrl = ((@dataUrl.nil? or @dataUrl.empty?) ? @trkUrl : @dataUrl)

      # construct stanza data
      retVal << "track #{@trkKey}\n"
      retVal << "bigDataUrl #{bigDataUrl}\n"
      retVal << "shortLabel #{@shortLabel}\n"
      retVal << "longLabel #{@longLabel}\n"
      retVal << "type #{@type}"

      # add any additional displaySettings
      unless(@displaySettings.nil? or @displaySettings.empty?)
        displayStanza = BRL::Genboree::REST::Data::HubTrackEntity.hashToStanza(@displaySettings)
        retVal << displayStanza
      end
      
      return retVal
    end

    # Create a hubTrackEntity from UCSC stanza data 
    # @return [BRL::Genboree::REST::Data::HubTrackEntity] internal representation of entity created from stanza data
    # @todo TODO cannot parse bigDataUrl that points to a Genboree file location
    def self.from_ucsc(data)
      retVal = self.parseStanzaDataForEntity(data, BRL::Genboree::REST::Data::HubTrackEntity)
      return retVal
    end
  end # class HubTrackEntity < BRL::Genboree::REST::Data::AbstractEntity

  # HubTrackEntityList - Collection/list containing multiple HubTracks
  # NOTE: the elements of the list are HubTrackEntity objects. Inputs are
  #   assumed to correctly be instances of HubTrackEntity.
  class HubTrackEntityList < BRL::Genboree::REST::Data::EntityList
    extend BRL::Genboree::Abstract::Resources::Hub
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :UCSC_HUB ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :HubTrackList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = HubTrackEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    # Represent hubTrackEntityList in UCSC stanza format
    # @return [String] stanza representation of hubTrackEntityList
    def to_ucsc()
      toUcscList = self.map{|entity| entity.to_ucsc() }
      return toUcscList.join("\n\n")
    end

    # Create a hubTrackEntityList from UCSC stanza data 
    # @return [BRL::Genboree::REST::Data::HubTrackEntityList] internal representation of entity created from stanza data
    # @todo TODO cannot parse bigDataUrl that points to a Genboree file location
    def self.from_ucsc(data)
      doRefs = false
      retVal = HubTrackEntityList.new(doRefs)
      entities = self.parseStanzaDataForEntities(data, self::ELEMENT_CLASS)
      retVal.push(*entities)
      return retVal
    end
  end # class HubTrackEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
