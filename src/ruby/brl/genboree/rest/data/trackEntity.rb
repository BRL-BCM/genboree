#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/textEntity'
#load 'brl/genboree/rest/helpers'

module BRL ; module Genboree ; module REST ; module Data

  # DetailedTrackEntity - Representation of a track: its name and description, and list of
  # ANNOTATION attribute names for the annotations in the track.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class DetailedTrackEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :TrkDetailed

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    # - NOTE: "url" and "urlLabel" and "annoAttributes" are only in the representation IF non-nil (say, if the detail level doesn't need them)
    #SIMPLE_FIELD_NAMES = [ "name", "description", "url", "urlLabel" ]
    SIMPLE_FIELD_NAMES = [ "name", "description"]

    # TABBED_HEADER is used by the to_tabbed() method to generate the header; should only include
    # core fields, as as user-defined attributes in the avpHash will be given their own
    # columns.
    TABBED_HEADER = [ "name", "description", "url", "urlLabel", "bigWig", "bigBed", "dbId", "numAnnos", "classes", "annoAttributes" ]
    # Track name as "type:subtype" formatted +String+
    attr_accessor :name
    # Track description; may contain HTML tags
    attr_accessor :description
    # URL associated with track, if any, as a +String+
    attr_accessor :url
    # Label text for track's URL
    attr_accessor :urlLabel
    # A TextEntityList instance that lists the classes this track is in
    attr_accessor :classes
    # A TextEntityList instance that lists the attribute names
    attr_accessor :annoAttributes
    # Either a: key-value Hash, Array of OOAttributeEntity, Hash of AttributeValueDisplayEntity, or Array of OOAttributeValueDisplayEntity with the desired level of attribute info
    attr_accessor :attributes
    # If there's a bigWig file available for this track, then the timestamp (%Y-%m-%d %H:%M) it was created on; else nil.
    attr_accessor :bigWig
    # If there a bigBed file available for this track, then the string timestamp (%Y-%m-%d %H:%M) it was created on; else nil.
    attr_accessor :bigBed
    # Add ftypeid to response if true
    attr_accessor :dbId
    # Number of annotations for the track: for HD tracks, this is the number of bps with scores. For non HD tracks, this is the number of records/annotations
    attr_accessor :numAnnos

    # CONSTRUCTOR.
    # [+doRefs+] [optional; default=true] Do you want the "refs" field in any representation of this entity (i.e. make connections or save size/complexity of representation?)
    # [+name+] [optional; default=""] Track name as "type:subtype" format
    # [+description+] [optional; default=""] Track description; may contain HTML tags
    # [+url+] [optional; default=nil] URL associated with track, if any
    # [+urlLabel+] [optional; default=nil] Label text for track's url
    # [+classes+] [optional; default=TextEntityList.new()] A TextEntityList instance that lists the classes this track is in
    # [+annoAttributes+] [optional; default=nil] A TextEntityList instance that lists the attribute names
    # [+attributes+] [optional; default=nil] Either a: AttributeValueEntityHash, Array of OOAttributeEntity, Hash of AttributeValueDisplayEntity, or Array of OOAttributeValueDisplayEntity with the desired level of attribute info
    def initialize(doRefs=true, name="", description="", url=nil, urlLabel=nil, classes=TextEntityList.new(), annoAttributes=nil, attributes=nil, bigWig=nil, bigBed=nil, dbId=nil, numAnnos=nil)
      super(doRefs)
      self.update(name, description, url, urlLabel, classes, annoAttributes, attributes, bigWig, bigBed, dbId, numAnnos)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+name+] [optional; default=""] Track name as "type:subtype" format
    # [+description+] [optional; default=""] Track description; may contain HTML tags
    # [+url+] [optional; default=""] URL associated with track, if any
    # [+urlLabel+] [optional; default=""] Label text for track's url
    # [+classes+] [optional; default=TextEntityList.new()] A TextEntityList instance that lists the classes this track is in
    # [+annoAttributes+] [optional; default=TextEntityList.new()] A TextEntityList instance that lists the attribute names
    # [+attributes+] [optional; default=nil] Either a: AttributeValueEntityHash, Array of OOAttributeEntity, Hash of AttributeValueDisplayEntity, or Array of OOAttributeValueDisplayEntity with the desired level of attribute info
    def update(name, description, url, urlLabel, classes, annoAttributes, attributes, bigWig, bigBed, dbId, numAnnos)
      @classes.clear() unless(@classes.nil?)
      @annoAttributes.clear() unless(@annoAttributes.nil?)
      @attributes.clear() unless(@attributes.nil?)
      @refs.clear() if(@refs)
      @name, @description, @url, @urlLabel, @classes, @annoAttributes = name, description, url, urlLabel, classes, annoAttributes
      @attributes = attributes
      @bigWig = bigWig
      @bigBed = bigBed
      @dbId = dbId
      @numAnnos = numAnnos
    end

    # JSON INTERFACE: Implement a standard AbstractEntity.json_create method.
    # This class method defined by the JSON library allows instances of this class
    # to be created from _parsed_ JSON (i.e. a +Hash+ or +Array+ resulting from JSON::parse).
    # The default implemenation just calls AbstractEntity.from_json which is likely fine for almost all subclasses.
    # [+parsedJsonResult+]  The +Hash+ or +Array+ resulting from parsing the JSON string.
    # [+returns+]           Instance of this class, whose state comes from data within +parsedJsonResult+.
    #
    def self.json_create(parsedJsonResult)
      retVal = self.jsonCreateSimple(parsedJsonResult, self::SIMPLE_FIELD_NAMES)
      unless(retVal.nil?)
        # Get content and status info from Common Wrapper if present...if not, content will be parsedJsonResult
        content = CommonWrapper.extractParsedContent(parsedJsonResult)
        # Create entity based on content, if content is looks correct. Else empty.
        entrypoints = TextEntityArray.new(content["annoAttributes"])
        retVal.entrypoints = entrypoints unless(entrypoints.nil?)
      end
      return retVal
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # [+returns+] A +Hash+ or +Array+ representing this entity (or collection of entities)
    #             wrapped in the standardized Genboree wrapper, if appropriate.
    #             <i>Entity class specific</i>
    def getFormatableDataStruct()
      if(!@annoAttributes.nil?)
        @annoAttributes.doWrap = false
        @annoAttributes.each { |obj| obj.doWrap = false } # these objects are within an Array, they should NOT each be wrapped
        @annoAttributes.sort! { |aa, bb| aa.text <=> bb.text }
      end
      if(@attributes)
        @attributes.doWrap = false
        if(@attributes.respond_to?(:keys))
          @attributes.each_key { |key|
            obj = @attributes[key]
            obj.doWrap = false if(obj.respond_to?(:doWrap))
          }
        else
          @attributes.each { |obj| obj.doWrap = false }  # these objects are within an Array, they should NOT each be wrapped
          # TODO: fix this sort to handle ooMinDetails or ooMaxDetails representations (sort on ["name"] field for both?)
          @attributes.sort! { |aa, bb| aa.text <=> bb.text } if(@attributes.class == TextEntityList)
        end
      end
      @classes.doWrap = false
      @classes.each { |obj| obj.doWrap = false } # these objects are within an Array, they should NOT each be wrapped
      @classes.sort! { |aa, bb| aa.text <=> bb.text }
      data =  {
                "name" => @name,
                "description" => @description,
                "classes" => @classes,
                "attributes" => @attributes,
              }
      # Add these if they are not nil (optional)
      data['url'] = @url if(!@url.nil?)
      data['urlLabel'] = @urlLabel if(!@urlLabel.nil?)
      data['annoAttributes'] = @annoAttributes if(!@annoAttributes.nil?)
      data['bigWig'] = @bigWig || 'none'
      data['bigBed'] = @bigBed || 'none'
      data['dbId'] = @dbId if(!@dbId.nil?)
      data['numAnnos'] = @numAnnos if(!@numAnnos.nil?)
      data['refs'] = @refs if(@refs)
      retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
      return retVal
    end

    # @api RestDataEntity
    # @abstract GENBOREE ABSTRACT INTERFACE. Must override in subclasses.
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
      # Simple properties first:
      data =  {
                'name'        => @name,
                'description' => @description,
                'bigWig'      => (@bigWig || 'none'),
                'bigBed'      => (@bigBed || 'none')
              }
      # Simple but optional properties (skip if nil)
      data['url']       = @url if(!@url.nil?)
      data['urlLabel']  = @urlLabel if(!@urlLabel.nil?)
      data['dbId']      = @dbId if(!@dbId.nil?)
      data['numAnnos']  = @numAnnos if(!@numAnnos.nil?)
      # Fields whose values are AbstractEntity subclass objects
      # - Sort these by default, for benefit of user
      unless(@classes.nil?)
        data['classes']        = @classes.toStructuredData(false)
        data['classes'].sort! { |aa, bb| aa['text'] <=> bb['text'] }
      end
      unless(@annoAttributes.nil?)
        data['annoAttributes'] = @annoAttributes.toStructuredData(false)
        data['annoAttributes'].sort! { |aa, bb| aa['text'] <=> bb['text'] }
      end
      # 'attributes' is tough because it can be:
      # - either a: key-value Hash, Array of OOAttributeEntity, Hash of AttributeValueDisplayEntity,
      #   or Array of OOAttributeValueDisplayEntity or TextEntityList with the desired level of attribute info
      # - just have to use reflection on :toStructuredData to decide (unless nil, in which case skip altogether)
      unless(@attributes.nil?)
        data['attributes'] = ( @attributes.respond_to?(:toStructuredData) ? @attributes.toStructuredData(false) : @attributes )
        # Sort by default, where makes sense
        unless(@attributes.respond_to?(:keys)) # Hash or Hash-backed...no sorting for those
          if(@attributes.is_a?(TextEntityList))
            data['attributes'].sort! { |aa, bb| aa['text'] <=> bb['text'] }
          elsif(@attributes.is_a?(OOAttributeValueDisplayEntityList) or @attributes.is_a?(OOAttributeEntityList))
            data['attributes'].sort! { |aa, bb| aa['name'] <=> bb['name'] }
          end
        end
      end

      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    # This method will construct a tab-delimited string of the information
    # contained by this entity. If called with no attrNames array, it will
    # construct the array based on the avpHash.  If called from the EntityList's
    # to_tabbed() method, an array of attribute names will be provided based on
    # all entities' avpHashes.
    # [+trackAttributes+]  An array of attribute names to append to the header
    #                      after the core fields have been inserted. (currently not supported)
    # [+returns+] Tab delimited track information
    def to_tabbed(trackAttributes=nil)
      # First build and output our header line
      retVal = ''
      if(trackAttributes.nil?)
        trackAttributes = []
        if(@attributes.is_a?(AttributeValueEntityHash)) # 'minDetails'
          trackAttributes += @attributes.hashMap.keys { |xx|}
          retVal << "#name\tdescription\tclasses\tbigWig\tbigBed\tdbId\tnumAnnos"
        elsif(@attributes.is_a?(AttributeValueDisplayEntityHash)) # 'maxDetails'
          retVal << "##{TABBED_HEADER.join("\t")}"
          trackAttributes += @attributes.keys { |xx|}
        else
          raise "Cannot construct tabbed header based on the given entity: #{@attributes.class.inspect}. Need either an AttributeValueEntityHash(minDetails) or an AttributeValueDisplayEntityHash(maxDetails)."
        end
        trackAttributes.uniq!
        trackAttributes.sort! { |aa, bb| aa.downcase <=> bb.downcase }
        trackAttributes.each_index{|ii| retVal << "\t#{esc(trackAttributes[ii])}" }
        retVal << "\n"
      end

      # Now output our data line
      if(@attributes.is_a?(AttributeValueDisplayEntityHash)) # 'maxDetails'
        retVal << "#{esc(@name)}\t#{esc(@description)}\t#{esc(@url)}\t#{esc(@urlLabel)}\t#{esc(@bigWig)}\t#{esc(@bigBed)}\t#{esc(@dbId)}\t#{esc(@numAnnos)}\t"
        # Class list:
        @classes.each_index { |ii|
          retVal << esc(@classes[ii].text)
          retVal << "; " unless(ii >= (@classes.size - 1))
        }
        retVal << "\t"
        # Annotation Attributes list:
        sortedAnnoAttrs = @annoAttributes.sort { |aa, bb| aa.text.downcase <=> bb.text.downcase }
        sortedAnnoAttrs.each_index { |ii|
          retVal << esc(sortedAnnoAttrs[ii].text)
          retVal << "; " unless(ii >= (sortedAnnoAttrs.size - 1))
        }
        trackAttributes.each { |trackAttribute|
          retVal << (@attributes[trackAttribute] ? "\t#{@attributes[trackAttribute].value}" : "\t")
        }
      else # minDetails
        retVal << "#{esc(@name)}\t#{esc(@description)}\t"
        # Big* Files
        retVal << ((@bigWig and !bigWig.empty?) ? "#{esc(@bigWig)}\t" : "none\t")
        retVal << ((@bigBed and !bigBed.empty?) ? "#{esc(@bigBed)}\t" : "none\t")
        retVal << "#{esc(@dbId)}\t#{esc(@numAnnos)}\t"
        # Class list:
        @classes.each_index { |ii|
          retVal << esc(@classes[ii].text)
          retVal << "; " unless(ii >= (@classes.size - 1))
        }
        retVal << "\t"
        trackAttributes.each { |trackAttribute|
          retVal << "\t#{@attributes.hashMap[trackAttribute]}"
        }
      end

      retVal << "\n"
      return retVal
    end

    # Class specific method to support Entity creation from tab-delimited data
    # (needs a proper header)
    def self.from_tabbed(data, opts={})
      retVal = DetailedTrackEntityList.from_tabbed(data, opts)
      raise "Unknown problem building entity" if(retVal.nil?)
      raise "Missing data line" if(retVal.size == 0)
      raise "Multiple data lines in tab-delimited data" if(retVal.size > 1)
      return retVal[0]
    end
  end # class DetailedTrackEntity < BRL::Genboree::REST::Data::AbstractEntity

  # DetailedTrackEntityList - Collection/list containing detailed information for multiple tracks.
  # NOTE: the elements of the list are DetailedTrackEntity objects. Inputs are assumed to correctly be instances of DetailedTrackEntity.
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml        -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml  -- default implementations from parent class
  # - #getFormatableDataStruct           -- default implementations from parent class
  class DetailedTrackEntityList < BRL::Genboree::REST::Data::EntityList
    #include BRL::Genboree::REST::Helpers
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :TrkDetailedList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = DetailedTrackEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    # This method constructs a tab-delimited string representation of the
    # entities contained by this list.  To accomplish this it constructs
    # an appropriate header based on the the avpHashes of all entities,
    # then calls the individual entity's to_tabbed() method, supplying
    # the array of attribute names.
    # [+returns+] A tab-delimited string representing all entities contained
    #             in the entity list.
    def to_tabbed()
      # First loop over tracks, getting avps
      trackAttributes = []
      retVal = ""
      onlyNames = false
      headerDone = false
      self.each { |track|
        attributes = track.attributes
        if(attributes.nil?) # just the track name on each line (not really tabbed)
          retVal << "#{track.name}\n"
          onlyNames = true
        elsif(attributes.is_a?(AttributeValueEntityHash)) # 'minDetails'
          retVal << "#name\tdescription\tclasses" if(!headerDone)
          headerDone = true
          trackAttributes += attributes.hashMap.keys { |xx|}
        elsif(attributes.is_a?(AttributeValueDisplayEntityHash)) # 'maxDetails'
          retVal = "##{DetailedTrackEntity::TABBED_HEADER.join("\t")}" if(!headerDone)
          headerDone = true
          trackAttributes += attributes.keys { |xx|}
        end
      }
      unless(onlyNames)
        # Uniquify, sort avps alphabetically, append them to the header.
        trackAttributes.uniq!
        trackAttributes.sort! { |aa, bb| aa.downcase <=> bb.downcase }
        trackAttributes.each_index{|ii| retVal << "\t#{esc(trackAttributes[ii])}" }
        retVal << "\n"
        # Now output our data lines (one for each item in the list)
        self.each{|track|
          retVal << track.to_tabbed(trackAttributes)
        }
      end
      return retVal
    end


    # Class specific method to support EntityList creation from mult-line
    # tab-delimited data (needs a proper header)
    # TODO - a problem will arise when parsing a DetailedTrackEntity that had
    #   detailed=false because the attributes hash did not contain any values,
    #   (empty cells for that column in the resulting serialized tabbed data)
    #   Therefore this method will improperly reconstruct the attributes hash.
    #   Not sure how to handle this - SGD
    def self.from_tabbed(data, opts={})
      header = nil
      retVal = DetailedTrackEntityList.new(false)
      lineno = 0
      data.each_line{ |line|
        # Skip blank or whitespace-only lines
        lineno += 1
        next if(line =~ /^\s*$/)
        if(header.nil?)
          # Check for a bad header line
          raise "Missing header line" unless(line =~ /^\s*#/)
          # Parse our header array
          #line.gsub!(/^\s*#/, "")
          header = line[1..line.size].strip.split("\t")
        else
          # Use our header to read in our data
          dataLine = line.split("\t")
          raise "Wrong number of columns on line #{lineno}. Header indicates #{header.size} columns. Sample record at line #{lineno} has #{dataLine.size} columns. Aborting sample import." unless(header.size == dataLine.size)
          values = []
          attributes = {}
          header.each_index{ |idx|
            key = header[idx]
            if(key == "name")
              values[0] = dataLine[idx]
            elsif(key == "description")
              values[1] = dataLine[idx]
            elsif(key == "url")
              values[2] = dataLine[idx]
            elsif(key == "urlLabel")
              values[3] = dataLine[idx]
            elsif(key == "classes")
              values[4] = dataLine[idx]
            elsif(key == "annoAttributes")
              values[5] = TextEntityList.new(false, dataLine[idx].split("; "))
            else
              #raise "Duplicate columns in the header" unless(attributes[key].nil?)
              attributes[key] = dataLine[idx] #unless(dataLine[idx].empty?)
            end
          }
          values[6] = attributes
        end
      }

      # Now return our list
      return retVal
    end
  end # class DetailedTrackEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
