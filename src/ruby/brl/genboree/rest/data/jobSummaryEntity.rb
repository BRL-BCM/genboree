#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # jobSummaryEntity - Representation of a summary of a job submitted via the workbench or via the API
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class JobSummaryEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :SUMMARY, :CONFIG ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :jobSummary

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "Job Name", "Tool", "Submit Date", "Completed Date", "Status", "Time in Current Status" ]
    TABBED_HEADER = ["jobName", "tool", "submitDate", "completedDate", "status", "timeInCurrentStatus" ]
    attr_accessor :jobName
    attr_accessor :tool
    attr_accessor :submitDate
    attr_accessor :completedDate
    attr_accessor :status
    attr_accessor :timeInCurrentStatus

    # CONSTRUCTOR.
    def initialize(doRefs=true, jobName="", tool="", submitDate="", completedDate="", status="", timeInCurrentStatus="")
      super(doRefs)
      self.update(jobName, tool, submitDate, completedDate, status, timeInCurrentStatus)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    def update(jobName, tool, submitDate, completedDate, status, timeInCurrentStatus)
      @refs.clear() if(@refs)
      @jobName, @tool, @submitDate, @completedDate, @status, @timeInCurrentStatus = jobName, tool, submitDate, completedDate, status, timeInCurrentStatus
    end

    # GENBOREE INTERFACE. Get a +Hash+ or +Array+ that represents this entity.
    # - used by the default implementations of <tt>to_*()</tt> methods
    # - override in sub-classes
    # - this data structure will be used in the serialization implementations
    # [+returns+] A +Hash+ or +Array+ representing this entity (or collection of entities)
    #             wrapped in the standardized Genboree wrapper, if appropriate.
    #             <i>Entity class specific</i>
    def getFormatableDataStruct()
      data =  {
                "jobName" => @jobName,
                "tool" => @tool,
                "submitDate" => (@submitDate.respond_to?(:rfc822) ? @submitDate.rfc822 : @submitDate.to_s),
                "completedDate" => (@completedDate.respond_to?(:rfc822) ? @completedDate.rfc822 : @completedDate.to_s),
                "status" => @status,
                "timeInCurrentStatus" => @timeInCurrentStatus
              }
      retVal = self.wrap(data)  # Wrap the data content in standard Genboree JSON envelope
      return retVal
    end

    # @api RestDataEntity
    # GENBOREE INTERFACE. Subclasses inherit; override for subclasses that generate
    # complex data representations mainly for speed (i.e. to avoid the reflection methods).
    # Inherited version works by using SIMPLE_FIELD_NAMES and reflection methods; even if you
    # just need the stuff in SIMPLE_FIELD_NAMES and don't have fields with complex data structures
    # in the representation, overriding to NOT use the reflection stuff will be faster [a little].
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
      # The SIMPLE_FIELD_NAMES first. Values are basic Ruby types (String, Hash, Array, Fixnum, Float, boolean, etc)
      data =
      {
        "jobName" => @jobName,
        "tool" => @tool,
        "submitDate" => (@submitDate.respond_to?(:rfc822) ? @submitDate.rfc822 : @submitDate.to_s),   # Time as String
        "completedDate" => (@completedDate.respond_to?(:rfc822) ? @completedDate.rfc822 : @completedDate.to_s).to_s,
        "status" => @status,
        "timeInCurrentStatus" => @timeInCurrentStatus
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    # This method will construct a tab-delimited string of the information
    # contained by this entity. If called with no attrNames array, it will
    # construct the array based on the avpHash.  If called from the EntityList's
    # to_tabbed() method, an array of attribute names will be provided based on
    # all entities' avpHashes.
    # [+attrNames+]  An array of attribute names to append to the header
    #                after the core fields have been inserted.
    # [+columnHeader+]  true or false to output or surpress the column header
    # [+returns+] Tab delimited bioSample information
    def to_tabbed(attrNames=nil, columnHeader=true)
      retVal = ''
      # Construct our header (can change depending on our data)
      headerCols = TABBED_HEADER.dup

      # Data for the 1 record
      dataCols = Array.new(headerCols.size)
      headerCols.each_index { |ii| dataCols[ii] = esc(self.send(headerCols[ii])) }

      # Make output text
      if(columnHeader)
        headerCols.map! { |xx| esc(xx) }
        retVal = "##{headerCols.join("\t")}\n"
      end
      retVal << "#{dataCols.join("\t")}\n"
      return retVal
    end

  end # class

  class JobSummaryEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :jobSummaryList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = JobSummaryEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    # This method constructs a tab-delimited string representation of the
    # entities contained by this list.  To accomplish this it constructs
    # an appropriate header based on the the avpHashes of all entities,
    # then calls the individual entity's to_tabbed() method, supplying
    # the array of attribute names.
    # [+returns+] A tab-delimited string representing all entities contained
    #             by the entity list.
    def to_tabbed()
      retVal = ''
      unless(self.empty?)
        headerCols = JobSummaryEntity::TABBED_HEADER.dup

        # Loop through entities to get them as records
        dataRecordsText = ''
        self.each { |entity| dataRecordsText += "#{entity.to_tabbed(nil, false)}" }
        # Create output text
        headerCols.map! { |xx| esc(xx) }
        retVal = "##{headerCols.join("\t")}\n"
        retVal << dataRecordsText
      end
      return retVal
    end
  end
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
