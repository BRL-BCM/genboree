#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/bioSampleEntity'
require 'brl/genboree/abstract/resources/bioSample'
#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # BioSampleAttributes - exposes information about the specific attributes
  # of a bioSample including the AVP pair information.
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntity
  # * BRL::Genboree::REST::Data::BioSampleEntity
  class BioSampleAttributes < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources::BioSample
    include BRL::Genboree::Constants
    # INTERFACE: Map of what http methods this resource supports
    #   ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false).
    HTTP_METHODS = { :get => true, :put => true, :delete => true }
    # Labels, etc, for building more generic strings that are copy-paste-bug free
    RSRC_STRS = { :type => 'Sample', :label => 'Sample', :capital => 'Sample', :pluralType => 'samples', :pluralLabel => 'samples', :pluralCap => 'Samples' }
    # Standard (mainly table-column) attrs
    STD_ATTRS = { 'name' => true, 'state' => true, 'name' => true, 'biomaterialState' => true, 'biomaterialSource' => true, 'biomaterialProvider' => true, 'type' => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      # variables exposed from call to initGroupAndDatabase() Helper
      @databaseName = @groupName = @groupId = @groupDesc = @groupAccessStr = @refseqRow = @refSeqId = nil
      # remove variables created by this class
      @attrName = @entityName = @dbName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] The +Regexp+ for this resource.
    def self.pattern()
      # Look for /REST/v1/grp/{grp}/db/{db}/bioSample/{bioSample}/attribute/{attr} URIs
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/(?:bioS|s)ample/([^/\?]+)/attribute/([^/\?]+)(?:/([^/\?]+))?$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      # Higher priority than grp/{grp}/db/{db}/bioSample
      return 7
    end

    # ATTR INTERFACE: Calls appropriate row-select-by @entityName method of dbu
    def selectEntityByName(entityName)
      return @dbu.selectBioSampleByName(entityName)
    end

    # ATTR INTERFACE: Calls appropriate row-select by attribute name to get attr name row
    def selectAttrNameByName(attrName)
      return @dbu.selectBioSampleAttrNameByName(attrName)
    end

    # ATTR INTERFACE: Deal with getting special attribute value (if any) (used by commonAttrGet())
    def getSpecialValue(row)
      retVal = nil
      if(@attrName == "study" and row["study_id"])
        studyRow = @dbu.selectStudyById(row["study_id"])
        retVal = studyRow.first['name'] if(studyRow and studyRow.first)
      elsif(@attrName == "bioSample" and row["bioSample_id"])
        bioSampleRow = @dbu.selectBioSampleById(row["bioSample_id"])
        retVal = bioSampleRow.first['name'] if(bioSampleRow and bioSampleRow.first)
      end
      return retVal
    end

    # ATTR INTERFACE: set up Hash for correct values of STD_ATTRS (using current + payload as appropriate)
    def updatedSpecialAttrValMap(entityRow, entityId, payloadEntity)
      attrValMap = {}
      entityText = payloadEntity.text
      # Set current values from row, update whichever is @attrName from payload
      STD_ATTRS.each { |attr|
        if(@attrName != attr) # Not one being changed, use Current Value:
          val = entityRow[attr]
          attrValMap[attr] = val
        else # One being changed, use New Value:
          if(STATE_ATTRS.key?(attr))
            # 'state' is actually column we will modify
            attrValMap['state'] = switchState(attr, entityRow['state'], entityText)
          else # non-state thing, do what is appropriate
            val = entityText
            attrValMap[attr] = val
          end
        end
      }
      return attrValMap
    end

    # ATTR INTERFACE: use attrValMap correctly to update entity's std_attrs
    def updateEntityStdAttrs(entityId, attrValMap)
      return @dbu.updateBioSampleById(entityId, attrValMap['name'], attrValMap['type'], attrValMap['biomaterialState'], attrValMap['biomaterialProvider'], attrValMap['biomaterialSource'], attrValMap['state'])
    end

    # ATTR INTERFACE: Calls appropriate row-select-by @entityName method of dbu
    def deleteEntity2AttributeById(entityId, attrId)
      return @dbu.deleteBioSample2AttributesByBioSampleIdAndAttrNameId(entityId, attrId)
    end

    # Set up some common variables
    # [+returns+] A symbol representing the status, +:OK+ for existing studies,
    #   +:'Not Found'+ for missing studies, or an error symbol otherwise.
    def initOperation()
      initStatus = super()
      if(initStatus == :'OK')
        initStatus = initAttrOperation(initStatus)
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      return commonAttrGet()
    end

    # Process a PUT operation on this resource.
    # [+returns+] Rack::Response instance
    def put()
      return commonAttrPut()
    end

    # Process a DELETE operation on this resource.  This can only be
    # used on attributes that are AVP attributes.
    # [+returns+] Rack::Response instance
    def delete()
      return commonAttrDelete()
    end
  end # class BioSampleAttributes
end ; end ; end # module BRL ; module REST ; module Resources
