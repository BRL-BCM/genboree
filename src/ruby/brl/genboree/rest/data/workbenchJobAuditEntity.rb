#!/usr/bin/env ruby
require 'brl/genboree/rest/data/entity'

module BRL ; module Genboree ; module REST ; module Data

  # WorkbenchJobEntity - Representation of a job submitted by the workbench
  #
  # Common Interface Methods:
  # - #to_json, #to_yaml, #to_xml             -- default implementations from parent class
  # - AbstractEntity.from_json, AbstractEntity.from_yaml, AbstractEntity.from_xml       -- default implementations from parent class
  # - #json_create, #getFormatableDataStruct  -- OVERRIDDEN
  class WorkbenchJobAuditEntity < BRL::Genboree::REST::Data::AbstractEntity
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :WkBnchJbAudit

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # Any basic name-value type fields; i.e. where the value is not a complex data structure but rather some text or a number.
    # Framework will do some automatic processing and presentation of those for you. Subclasses will override this, obviously.
    SIMPLE_FIELD_NAMES = [ "user", "submitHost", "systemHost", "systemType", "queue", "systemJobId", "toolType", "toolId", "label", "name", "entryDate", "submitDate", "execStartDate", "execEndDate", "status" ]
    # TABBED_HEADER is used by the to_tabbed() method to generate the header; should only include
    # core fields, as as user-defined attributes in the avpHash will be given their own columns.
    TABBED_HEADER = [ "user", "toolType", "toolId", "label", "jobName", "status", "submitHost", "systemHost", "systemType", "queue", "systemJobId", "entryDate", "submitDate", "execStartDate", "execEndDate", "directives" ]

    # ACCESSORS
    # User who submitted the job
    attr_accessor :user
    # Genboree host from which the user submitted the job
    attr_accessor :submitHost
    # Batch system on which the job ran
    attr_accessor :systemHost
    # Type of batch system
    attr_accessor :systemType
    # Queue name in the batch system
    attr_accessor :queue
    # Id on the batch system
    attr_accessor :systemJobId
    # Tool's internal type or "category"
    attr_accessor :toolType
    # Tool's idStr
    attr_accessor :toolId
    # Tool's more human readable label
    attr_accessor :label
    # Job name/ticket unique ID
    attr_accessor :name
    # When the job was entered into Genboree by the user
    attr_accessor :entryDate
    # When the job was submitted to the batch system to await execution
    attr_accessor :submitDate
    # When the job started execution on the batch system
    attr_accessor :execStartDate
    # When the job finished execution on the batch system
    attr_accessor :execEndDate
    # The last know status of the job
    attr_accessor :status
    # A Hash of job directive name => value. Things like "ppn" and "nodes".
    attr_accessor :directives

    # CONSTRUCTOR.
    def initialize(doRefs=false, user=nil, submitHost="UNKNOWN", systemHost=nil, systemType=nil, queue=nil, systemJobId=nil, toolType=nil, toolId=nil, label=nil, name=nil, entryDate=nil, submitDate=nil, execStartDate=nil, execEndDate=nil, status=nil, directives=nil)
      super(doRefs)
      @genbConf = nil
      self.update(user, submitHost, systemHost, systemType, queue, systemJobId, toolType, toolId, label, name, entryDate, submitDate, execStartDate, execEndDate, status, directives)
    end

    # REUSE INSTANCE. Update this instance with new data; supports reuse of instances rather than always making new objects
    # [+url+] [The url +String+ to represent
    def update(user, submitHost, systemHost, systemType, queue, systemJobId, toolType, toolId, label, name, entryDate, submitDate, execStartDate, execEndDate, status, directives)
      @refs.clear() if(@refs)
      # Simple fields:
      @user, @submitHost, @systemHost, @systemType, @queue, @systemJobId, @toolType, @toolId, @label, @name, @entryDate, @submitDate, @execStartDate, @execEndDate, @status =
        user, submitHost, systemHost, systemType, queue, systemJobId, toolType, toolId, label, name, entryDate, submitDate, execStartDate, execEndDate, status
      # Complex fields
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "directives => #{directives.inspect}")
      if(directives.is_a?(Hash))
        @directives = directives
      elsif(directives.is_a?(String) and !directives.empty?)
        @directives = JSON.parse(directives)
      else # likely NULL in db, so nil here or maybe ""...who cares.
        directives = {}
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@directives => #{@directives.inspect}")
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
                "user" => @user,
                "submitHost" => @submitHost,
                "systemHost" => @systemHost,
                "systemType" => @systemType,
                "queue" => @queue,
                "systemJobId" => @systemJobId,
                "toolType" => @toolType,
                "toolId" => @toolId,
                "toolLabel" => @label,
                "jobName" => @name,
                "entryDate" => (@entryDate.respond_to?(:rfc822) ? @entryDate.rfc822 : @entryDate.to_s),
                "submitDate" => (@submitDate.respond_to?(:rfc822) ? @submitDate.rfc822 : @submitDate.to_s),
                "execStartDate" => (@execStartDate.respond_to?(:rfc822) ? @execStartDate.rfc822 : @execStartDate.to_s),
                "execEndDate" => (@execEndDate.respond_to?(:rfc822) ? @execEndDate.rfc822 : @execEndDate.to_s),
                "status" => @status,
                "directives" => @directives         # Hash
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
        "user" => @user,
        "submitHost" => @submitHost,
        "systemHost" => @systemHost,
        "systemType" => @systemType,
        "queue" => @queue,
        "systemJobId" => @systemJobId,
        "toolType" => @toolType,
        "toolId" => @toolId,
        "toolLabel" => @label,
        "jobName" => @name,
        "entryDate" => (@entryDate.respond_to?(:rfc822) ? @entryDate.rfc822 : @entryDate.to_s),
        "submitDate" => (@submitDate.respond_to?(:rfc822) ? @submitDate.rfc822 : @submitDate.to_s),
        "execStartDate" => (@execStartDate.respond_to?(:rfc822) ? @execStartDate.rfc822 : @execStartDate.to_s),
        "execEndDate" => (@execEndDate.respond_to?(:rfc822) ? @execEndDate.rfc822 : @execEndDate.to_s),
        "status" => @status,
        "directives" => @directives               # Hash
      }
      data['refs'] = @refs if(@refs)
      retVal = (wrap ? self.wrap(data) : data)
      return retVal
    end

    def to_tabbed(attributes=nil, headerDone=false)
      # Build header
      retVal = ''
      retVal << "##{TABBED_HEADER.join("\t")}" unless(headerDone)
      retVal << "\n"
      # Now output our data line
      retVal << "#{@user}\t#{@toolType}\t#{@toolId}\t#{@label}\t#{@name}\t#{@status}\t#{@submitHost}\t#{@systemHost}\t#{@systemType}\t#{@queue}\t#{@systemJobId}\t#{@entryDate}\t#{@submitDate}\t#{@execStartDate}\t#{@execEndDate}\t#{@directives.to_json}\n"
      return retVal
    end
  end # class WorkbenchJobAuditEntity

  class WorkbenchJobAuditEntityList < BRL::Genboree::REST::Data::EntityList
    # What formats are supported, using the conventional +Symbols+. Subclasses may or may not override this.
    FORMATS = [ :JSON, :JSON_PRETTY, :XML, :YAML, :TABBED ]
    # A +Symbol+ naming the resource with a code-friendly (ok, XML tag-name friendly) name. This is currently used in
    # generating XML for _lists_...they will be lists of tags of this type (XML makes it hard to express certain natural things easily...)
    RESOURCE_TYPE = :WkBnchJbAuditList

    # @return [String] The key for the reference url (when connect=yes)
    # @todo remove this and use JSON-LD @ref approach
    REFS_KEY = "#{RESOURCE_TYPE}_#{FORMATS.join('.')}"

    # What kind of objects does this collection/list store?
    ELEMENT_CLASS = WorkbenchJobAuditEntity
    # Whether the values stored in @array are objects implementing toStructuredData() (constant to save reflection at runtime)
    ELEMENT_IMPLEMENTS_TOSTRUCTUREDDATA = ELEMENT_CLASS.method_defined?(:toStructuredData)

    def to_tabbed()
      retVal = ""
      retVal << "##{WorkbenchJobAuditEntity::TABBED_HEADER.join("\t")}"
      headerDone = true
      self.each { |jobAuditEntity|
        retVal << jobAuditEntity.to_tabbed(nil, headerDone)
        headerDone = true # So only done for the first entity
      }
      return retVal
    end
  end # class WorkbenchJobAuditEntityList < BRL::Genboree::REST::Data::EntityList
end ; end ; end ; end  # module BRL ; module Genboree ; module REST ; module Data
