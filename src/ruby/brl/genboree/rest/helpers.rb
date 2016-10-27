#!/usr/bin/env ruby
# ##############################################################################
# Predeclare module (solve circular dependency namespace issue in requires below)
module BRL ; module Genboree ; module REST ; module Helpers ; end ; end ; end ; end
# ##############################################################################

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'uri'
require 'rack'
require 'brl/util/util'
require 'brl/rest/resource'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeContext'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/rest/helpers/apiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/abstract/resources/entrypoint'
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/trackEntity'

module Rack #:nodoc:
# == Rack::Utils overridden methods
# Override Rack's Rack::Utils#escape method so that space (' ') is consitently escaped
# as %20, not shortcut + and/or %20. One-way digests and libraries that default space to %20
# will thank you.
module Utils
  # Keep a reference to the original implementation, so we can call it.
  alias escape_orig escape

  # URL escape a +String+. First calls the original implementation and then
  # makes result consistent by replacing any + characters (for spaces) with %20.
  def escape(str)
    val = escape_orig(str)
    val.gsub!(/\+/, "%20")
    return val
  end

  # Re-export the original function as a module functions (accessible via +Rack::Utils.escape_orig()+)
  module_function :escape_orig
  # Re-export the replacemnt function as a module functions (accessible via +Rack::Utils.escape()+)
  module_function :escape
end ; end # module Rack ; module Utils


#--
module BRL ; module Genboree ; module REST
#++

# == Helper methods module
# Collection of commonly called methods. These are mixed into resource subclasses.
#
# <i>NOTE: try to avoid adding to this grab-bag module. Instead, create Classes and
# Modules within BRL::Genboree::REST::Abstract::Resources that implement the
# necessary behaviors to mix-in or to directly call.</i>
module Helpers
  READ_ONLY_METHODS = { :get => true, :head => true, :options => true }
  # Attributes corresponding to special state flags
  STATE_ATTRS = { 'fail' => BRL::Genboree::Constants::FAIL_STATE, 'pending' => BRL::Genboree::Constants::PENDING_STATE, 'running' => BRL::Genboree::Constants::RUNNING_STATE, 'public' => BRL::Genboree::Constants::PUBLIC_STATE, 'isTemplate' => BRL::Genboree::Constants::IS_TEMPLATE_STATE, 'isCompleted' => BRL::Genboree::Constants::IS_COMPLETED_STATE }
  READ_ALLOWED_ROLES  = { 'p' => true, 'r' => true, 'w' => true, 'o' => true }
  WRITE_ALLOWED_ROLES = { 'w' => true, 'o' => true }
  ADMIN_ALLOWED_ROLES = { 'o' => true }

  # ############################################################################
  # Generic Helpers
  # ############################################################################

  # Helper method for switching the value of a state
  # [+name+] the name of the state flag
  # [+state+] value of state in the database
  # [+newState+] value of state to be set. could be "true" or "yes", "false" or "no"
  # [+returns+]  properly set (bitwise) state
  def switchState(name, state, newState)
    retVal = state
    flag = STATE_ATTRS[name]
    if(newstate and newState.strip =~ /^(?:yes|true)$/i)
      retVal = state | flag
    else
      retVal = state & ~flag
    end
    return retVal
  end

  # ############################################################################
  # Standardized-Attributes (AVP) Helpers: for getting a hash of ALL attributes of a resource
  # ############################################################################
  # Gets all attributes for the child entity
  def commonAttributesGet()
    initStatus = initAttributesOperation()
    if(initStatus == :'OK')
      entityRows = selectEntityByName(@entityName)
      if(!entityRows.nil? and !entityRows.empty?)
        entityRow = entityRows.first
        avpHash = getAvpHash(@dbu, entityRow['id'])
        # Handle attributes appropriately
        avpHash.each_key { |key|
          value = nil
          if(self.class::STD_ATTRS.key?(key))
            # try special attr value first, otherwise treat as a column name in table row
            value = (getSpecialAttrValue(entityRow) or entityRow[key])
          elsif(STATE_ATTRS.key?(key))
            flag = STATE_ATTRS[key]
            unless(flag.nil?)
              value = (((entityRow['state'] & flag) > 0) ? "yes" : "no")
            end
          else
            avpHash = getAvpHash(@dbu, entityRow['id'])
            value = avpHash[key] if(avpHash.include?(key))
          end
          avpHash[key] = value
        }
        # Only respond if we got something
        if(avpHash)
          entity = BRL::Genboree::REST::Data::AttributesEntity.new(@connect, avpHash)
          @statusName = configResponse(entity)
        else # no attributes
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "NOT_FOUND: The #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} does not have any attributes")
        end
      else
        @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "UNKNOWN_ERROR: There was a DB error while querying for the #{self.class::RSRC_STRS[:capital]} named #{@entityName.inspect} from database #{@dbName.inspect} in group #{@groupName.inspect}.")
      end
      entityRows.clear() unless (entityRows.nil?)
    end
  end

  # Puts all attributes for the child entity
  def commonAttributesPut()
    initStatus = initAttributesOperation()
    # Check permission for inserts (must be author/admin of a group)
    if(@groupAccessStr == 'r')
      @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "FORBIDDEN: You do not have access to update #{self.class::RSRC_STRS[:capital]} attributes in database #{@dbName.inspect} in user group #{@groupName.inspect}")
    elsif(initStatus == :OK)
      # Get the entity from the HTTP request
      entity = parseRequestBodyForEntity('AttributesEntity')
      if(entity == :'Unsupported Media Type')
        @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type TextEntity")
      elsif(entity.nil?)
        # Cannot update an entity with a nil entity
        @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an attribute-value update/insert")
      else # We have something to update
        # Get the entity row by name using method implemented in specific rest/resource/*.rb file:
        entityRows = selectEntityByName(@entityName)
        # Can we locate the table row?
        if(!entityRows.nil? and !entityRows.empty?)
          entityRow = entityRows.first
          entityId = entityRow['id']
          # Update the avp hash
          avpHash = getAvpHash(@dbu, entityId)
          entityAttributesHash = entity.attributes
          entityAttributesHash.each_key { |key|
            value = nil
            if(self.class::STD_ATTRS.key?(key) or STATE_ATTRS.key?(key)) # CORE ATTRIBUTE / COLUMN
              # Get a Hash with correct STD_ATTRS values and 'state' setting, using current values + payload appropriately,
              # using method implemented in specific rest/resource/*.rb file:
              attrValMap = updatedSpecialAttrValMap(entityRow, entityId, entity)
              value = attrValMap[key]
            else # CUSTOM ATTRIBUTE
              # Update the avp hash
              value = entityAttributesHash[key]
            end
            avpHash[key] = value
          }
          updateAvpHash(@dbu, entityId, avpHash)
          entity.setStatus(:OK)
          configResponse(entity)
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "UNKNOWN_ERROR: There was a DB error while querying for the #{self.class::RSRC_STRS[:capital]} named #{@entityName.inspect} from database #{@dbName.inspect} in group #{@groupName.inspect}.")
        end
      end
    end

    # Respond with an error if appropriate
    @resp = representError() if(@statusName != :OK)
    return @resp
  end

   # Common entity attribute-value DELETE implementation, using appropriate specific methods implemented by including resource class
  def commonAttributesDelete()
    initStatus = initAttributesOperation()
    if(initStatus == :OK)
      if(@groupAccessStr == 'r')
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "FORBIDDEN: You do not have access to delete #{self.class::RSRC_STRS[:capital]} attributes in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      else  # Get the entity row by name using method implemented in specific rest/resource/*.rb file:
        entity = parseRequestBodyForEntity('AttributesEntity')
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type TextEntity")
        elsif(entity.nil?) # Delete all attributes except the 'core' ones
          entityRows = selectEntityByName(@entityName)
          if(!entityRows.nil? and !entityRows.empty?)
            entityRow = entityRows.first
            entityId = entityRow['id']
            avpHash = getAvpHash(@dbu, entityId)
            coreAttrs = []
            deletedAttrs = []
            problemAttrs = []
            avpHash.each_key { |key|
              if(!self.class::STD_ATTRS.key?(key) and !STATE_ATTRS.key?(key))
                attrRow = selectAttrNameByName(key)
                attrId = attrRow.first['id']
                rowsDeleted = deleteEntity2AttributeById(entityId, attrId)
                if(rowsDeleted != 1)
                  problemAttrs.push(key)
                else
                  deletedAttrs.push(key)
                end
              else
                coreAttrs.push(key)
              end
            }
            if(problemAttrs.empty?)
              entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
              setStatusStr = "The following attributes: (#{deletedAttrs.join(",")}) were successfully deleted from the #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect}"
              setStatusStr << "\nHowever, the following 'core' attributes were not deleted: (#{coreAttrs.join(",")})" if(!coreAttrs.empty?)
              entity.setStatus(:OK, setStatusStr)
              @statusName = configResponse(entity)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the following attributes: (#{problemAttrs.join(",")}) from the #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} from database #{@dbName.inspect} in user group #{@groupName.inspect}")
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting all attributes from the #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} from database #{@dbName.inspect} in user group #{@groupName.inspect}")
          end
        else # We have a payload. Delete only those attributes that are present in the payload
          entityRows = selectEntityByName(@entityName)
          if(!entityRows.nil? and !entityRows.empty?)
            entityRow = entityRows.first
            entityId = entityRow['id']
            # First make sure none of the attrs is a 'core' key
            entityTextHash = entity.attributes
            notAllowed = false
            attrNotAllowed = nil
            entityTextHash.each_key { |key|
              if(self.class::STD_ATTRS.key?(key) or STATE_ATTRS.key?(key))
                notAllowed = true
                attrNotAllowed = key
                break
              end
            }
            if(!notAllowed)
              allDeleted = true
              entityTextHash.each_key { |key|
                attrRow = selectAttrNameByName(key)
                attrId = attrRow.first['id']
                rowsDeleted = deleteEntity2AttributeById(entityId, attrId)
                allDeleted = false if(rowsDeleted != 1)
              }
              if(allDeleted)
                entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
                entity.setStatus(:OK, "The attribute(s) were successfully deleted from the #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect}")
                @statusName = configResponse(entity)
              else
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting some of the attributes from the #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} from database #{@dbName.inspect} in user group #{@groupName.inspect}")
              end
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "UNDELETEABLE: You cannot perform a DELETE operation on the attribute #{attrNotAllowed.inspect}")
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "UNKNOWN_ERROR: There was a DB error while querying for the #{self.class::RSRC_STRS[:capital]} named #{@entityName.inspect} from database #{@dbName.inspect} in group #{@groupName.inspect}.")
          end
        end
      end
    end
    # If something wasn't right, represent as error
    @resp = representError() if(@statusName != :OK)
    return @resp
  end


   # Common initialization code for standard attributes of an entity
  def initAttributesOperation()
    @groupName = Rack::Utils.unescape(@uriMatchData[1])
    @dbName = Rack::Utils.unescape(@uriMatchData[2])
    @entityName = Rack::Utils.unescape(@uriMatchData[3])
    initStatus = initGroupAndDatabase()
    if(initStatus == :'OK')
      if(selectEntityByName(@entityName).length <= 0)
        initStatus = @statusName = :'Not Found'
        @statusMsg = "NOT_FOUND: The #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} was not found in the database #{@dbName.inspect}."
      end
    end
    return initStatus
  end

  # ############################################################################
  # Standardized-Attribute (AVP) Helpers
  # ############################################################################

  # Common initialization code for standard attributes / AVPs of an data entity
  def initAttrOperation(initStatus)
    @groupName = Rack::Utils.unescape(@uriMatchData[1])
    @dbName = Rack::Utils.unescape(@uriMatchData[2])
    @entityName = Rack::Utils.unescape(@uriMatchData[3])
    @attrName = Rack::Utils.unescape(@uriMatchData[4])
    # Look for an attribute "aspect". This is for compatibility with the
    # track attribute interface for which aspects can be present.
    # - For most entity attributes, only the 'value' aspect is available
    # - If no aspect, then 'value' is assumed
    @aspect = (@uriMatchData[5].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[5])
    initStatus = initGroupAndDatabase()
    if(initStatus == :'OK')
      if(selectEntityByName(@entityName).length <= 0)
        initStatus = @statusName = :'Not Found'
        @statusMsg = "NOT_FOUND: The #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} was not found in the database #{@dbName.inspect}."
      elsif(!@aspect.nil? and @aspect !~ /value/)
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "BAD_ATTRIBUTE_ASPECT: #{self.class::RSRC_STRS[:capital]} attributes do not support the aspect #{@aspect.inspect}. Only the [optional] 'value' aspect is supported."
      end
    end
    return initStatus
  end

  # Similar to above but for core/main database resources instead of data resources.
  # - NOTE: the calling function should have already set @entityName, @attrName, @aspect (usually in the initOperation() method)
  #   This method assumes that extraction from @uriMatchData[] has been done correctly by the calling class.
  def initCoreAttrOperation(initStatus)
    if(initStatus == :OK)
      @entityRows = selectEntityByName(@entityName)
      if(@entityRows.nil? or @entityRows.empty?) # then failed to find the row
        initStatus = @statusName = :'Not Found'
        @statusMsg = "NOT_FOUND: The #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} was not found."
      elsif(!@aspect.nil? and @aspect !~ /value/)
        initStatus = @statusName = :'Bad Request'
        @statusMsg = "BAD_ATTRIBUTE_ASPECT: #{self.class::RSRC_STRS[:capital]} attributes do not support the aspect #{@aspect.inspect}. Only the [optional] 'value' aspect is supported."
      end
    end
    return initStatus
  end

  # Common entity attribute-value GET implementation, using appropriate specific methods implemented by including resource class
  def commonAttrGet()
    initStatus = initOperation()
    if(initStatus == :OK)
      # Get the entity row by name using method implemented in specific rest/resource/*.rb file:
      entityRows = selectEntityByName(@entityName)
      if(!entityRows.nil? and !entityRows.empty?)
        entityRow = entityRows.first
        value = nil
        if(self.class::STD_ATTRS.key?(@attrName))
          # try special attr value first, otherwise treat as a column name in table row
          value = (getSpecialAttrValue(entityRow) or entityRow[@attrName])
        elsif(STATE_ATTRS.key?(@attrName))
          flag = STATE_ATTRS[@attrName]
          unless(flag.nil?)
            value = (((entityRow['state'] & flag) > 0) ? "yes" : "no")
          end
        else
          avpHash = getAvpHash(@dbu, entityRow['id'])
          value = avpHash[@attrName] if(avpHash.include?(@attrName))
        end

        # Only respond with a value if one was found
        if(value)
          entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, value)
          @statusName = configResponse(entity)
        else # no such attr
          @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "NOT_FOUND: The #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} does not have the attribute #{@attrName.inspect}")
        end
      else
        @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "UNKNOWN_ERROR: There was a DB error while querying for the #{self.class::RSRC_STRS[:capital]} named #{@entityName.inspect} from database #{@dbName.inspect} in group #{@groupName.inspect}.")
      end
      entityRows.clear() unless (entityRows.nil?)
    end
    # If something wasn't right, represent as error
    @resp = representError() if(@statusName != :OK)
    return @resp
  end

  # Common entity attribute-value GET implementation for core/main resources rather than data resources.
  # - NOTE: @entityRows is assumed to have been set, usually through a call to initCoreAttrOperation() above
  #   by the resource class' initOperation() method.
  def commonCoreAttrGet(accessMap=PERMISSIONS_ALL_READ_ONLY, entityRowColName='id')
    initStatus = @statusName = initOperation()
    if(initStatus == :OK)
      # Check permission for inserts (by default must be admin of a group)
      unless(accessAllowed?(accessMap))
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "FORBIDDEN: You do not have sufficient access to update #{self.class::RSRC_STRS[:capital]} attributes for #{@entityName.inspect}.")
      else  # Sufficient access
        # Get the entity row by name using method implemented in specific rest/resource/*.rb file:
        if(@entityRows and !@entityRows.empty?)
          entityRow = @entityRows.first
          value = nil
          if(self.class::STD_ATTRS.key?(@attrName))
            # try special attr value first, otherwise treat as a column name in table row
            value = ((getSpecialAttrValue(entityRow) or entityRow[@attrName]))
          else
            avpHash = getAvpHash(@dbu, entityRow[entityRowColName])
            value = avpHash[@attrName] if(avpHash.key?(@attrName))
          end

          # Only respond with a value if one was found
          unless(value.nil?)
            entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, value)
            @statusName = configResponse(entity)
          else # no such attr
            @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "NOT_FOUND: The #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} does not have the attribute #{@attrName.inspect}")
          end
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "UNKNOWN_ERROR: There was a DB error while querying for the #{self.class::RSRC_STRS[:capital]} named #{@entityName.inspect}.")
        end
      end
    end
    # If something wasn't right, represent as error
    @resp = representError() if(@statusName != :OK)
    return @resp
  end

  # Common entity attribute-value PUT implementation, using appropriate specific methods implemented by including resource class
  def commonAttrPut()
    initStatus = initOperation()
    # Check permission for inserts (must be author/admin of a group)
    if(@groupAccessStr == 'r')
      @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "FORBIDDEN: You do not have access to update #{self.class::RSRC_STRS[:capital]} attributes in database #{@dbName.inspect} in user group #{@groupName.inspect}")
    elsif(initStatus == :OK)
      # Get the entity from the HTTP request
      entity = parseRequestBodyForEntity('TextEntity')
      if(entity == :'Unsupported Media Type')
        @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type TextEntity")
      elsif(entity.nil?)
        # Cannot update an entity with a nil entity
        @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an attribute-value update/insert")
      else # We have something to update
        # Get the entity row by name using method implemented in specific rest/resource/*.rb file:
        entityRows = selectEntityByName(@entityName)
        # Can we locate the table row?
        if(!entityRows.nil? and !entityRows.empty?)
          entityRow = entityRows.first
          entityId = entityRow['id']
          # What kind of thing to update? Deal with it approrpriately
          if(self.class::STD_ATTRS.key?(@attrName) or STATE_ATTRS.key?(@attrName)) # CORE ATTRIBUTE / COLUMN
            # Get a Hash with correct STD_ATTRS values and 'state' setting, using current values + payload appropriately,
            # using method implemented in specific rest/resource/*.rb file:
            attrValMap = updatedSpecialAttrValMap(entityRow, entityId, entity)
            # Perform update using method implemented in specific rest/resource/*.rb file:
            rowsUpdated = updateEntityStdAttrs(entityId, attrValMap)
            if(@attrName == "name")
              entity.setStatus(:'Moved Permanently', "The entity has a new name (and thus new URL), because the attribute #{@attrName.inspect} has been set to #{entity.text.inspect}.")
              configResponse(entity, :'Moved Permanently')
            else
              entity.setStatus(:OK, "The attribute #{@attrName.inspect} has been set to #{entity.text.inspect}.")
              configResponse(entity)
            end
          else # CUSTOM ATTRIBUTE
            # Update the avp hash
            avpHash = getAvpHash(@dbu, entityId)
            avpHash[@attrName] = entity.text
            updateAvpHash(@dbu, entityId, avpHash)
            entity.setStatus(:OK)
            configResponse(entity)
          end
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "UNKNOWN_ERROR: There was a DB error while querying for the #{self.class::RSRC_STRS[:capital]} named #{@entityName.inspect} from database #{@dbName.inspect} in group #{@groupName.inspect}.")
        end
      end
    end

    # Respond with an error if appropriate
    @resp = representError() if(@statusName != :OK)
    return @resp
  end

  # Common entity attribute-value PUT implementation for core/main resources rather than data resources.
  # - NOTE: @entityRows is assumed to have been set, usually through a call to initCoreAttrOperation() above
  #   by the resource class' initOperation() method.
  def commonCoreAttrPut(accessMap=PERMISSIONS_RW_GET_ONLY, entityRowColName='id')
    initStatus = @statusName = initOperation()
    if(initStatus == :OK)
      # Check permission for inserts (by default must be admin of a group)
      unless(accessAllowed?(accessMap))
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "FORBIDDEN: You do not have sufficient access to update #{self.class::RSRC_STRS[:capital]} attributes for #{@entityName.inspect}.")
      else  # Sufficient access
        # Get the entity from the HTTP request
        entity = parseRequestBodyForEntity('TextEntity')
        if(entity == :'Unsupported Media Type')
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not of type TextEntity")
        elsif(entity.nil?)
          # Cannot update an entity with a nil entity
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "EMPTY_PAYLOAD_ON_UPDATE: You must supply a payload when performing an attribute-value update/insert")
        else # We have something to update
          # Can we locate the table row?
          if(@entityRows and !@entityRows.empty?)
            entityRow = @entityRows.first
            entityId = entityRow[entityRowColName]
            # What kind of thing to update? Deal with it approrpriately
            if(self.class::STD_ATTRS.key?(@attrName)) # CORE ATTRIBUTE / COLUMN
              # Get a Hash with current STD_ATTRS values using current values + payload appropriately,
              # using method implemented in specific rest/resource/*.rb file:
              attrValMap = updatedSpecialAttrValMap(entityRow, entityId, entity)
              # Perform update using method implemented in specific rest/resource/*.rb file:
              rowsUpdated = updateEntityStdAttrs(entityId, attrValMap)
              if(rowsUpdated and rowsUpdated == 1)
                if(@attrName == 'name')
                  entity.setStatus(:'Moved Permanently', "The entity has a new name (and thus new URL), because the attribute #{@attrName.inspect} has been set to #{entity.text.inspect}.")
                  configResponse(entity, :'Moved Permanently')
                else
                  entity.setStatus(:OK, "The attribute #{@attrName.inspect} has been set to #{entity.text.inspect}.")
                  configResponse(entity)
                end
              else
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "UNKNOWN_ERROR: There was an error trying to update #{self.class::RSRC_STRS[:capital]} named #{@entityName.inspect}. Rows updated returned: #{rowsUpdated.inspect}")
              end
            else # CUSTOM ATTRIBUTE
              # Update the avp hash
              avpHash = getAvpHash(@dbu, entityId)
              avpHash[@attrName] = entity.text
              updateAvpHash(@dbu, entityId, avpHash)
              entity.setStatus(:OK)
              configResponse(entity)
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "UNKNOWN_ERROR: There was a DB error while querying for the #{self.class::RSRC_STRS[:capital]} named #{@entityName.inspect}.")
          end
        end
      end
    end

    # Respond with an error if appropriate
    @resp = representError() if(@statusName != :OK)
    return @resp
  end

  # Common entity attribute-value DELETE implementation, using appropriate specific methods implemented by including resource class
  def commonAttrDelete()
    initStatus = initOperation()
    if(initStatus == :OK)
      if(@groupAccessStr == 'r')
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "FORBIDDEN: You do not have access to delete #{self.class::RSRC_STRS[:capital]} attributes in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      elsif(self.class::STD_ATTRS.key?(@attrName) or STATE_ATTRS.key?(@attrName))
        @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "UNDELETEABLE: You cannot perform a DELETE operation on the attribute #{@attrName.inspect}")
      else
        # Get the entity row by name using method implemented in specific rest/resource/*.rb file:
        entityRows = selectEntityByName(@entityName)
        if(!entityRows.nil? and !entityRows.empty?)
          entityRow = entityRows.first
          entityId = entityRow['id']
          # Find the id of the attribute to be deleted
          attrRow = selectAttrNameByName(@attrName)
          avpHash = getAvpHash(@dbu, entityId)
          if(!avpHash.key?(@attrName))
            @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "NOT_FOUND: The #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} does not have the attribute #{@attrName.inspect}")
          else
            attrId = attrRow.first['id']
            # Use appropriate entity-attribute deleting method implemented in specific rest/resource/*.rb file:
            rowsDeleted = deleteEntity2AttributeById(entityId, attrId)
            if(rowsDeleted == 1)
              entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
              entity.setStatus(:OK, "The attribute #{@attrName.inspect} was successfully deleted from the #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect}")
              @statusName = configResponse(entity)
            else
              @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the attribute #{@attrName.inspect} from the #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} from database #{@dbName.inspect} in user group #{@groupName.inspect}")
            end
          end
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "UNKNOWN_ERROR: There was a DB error while querying for the #{self.class::RSRC_STRS[:capital]} named #{@entityName.inspect} from database #{@dbName.inspect} in group #{@groupName.inspect}.")
        end
      end
    end

    # If something wasn't right, represent as error
    @resp = representError() if(@statusName != :OK)
    return @resp
  end

  # Common entity attribute-value PUT implementation for core/main resources rather than data resources.
  # - NOTE: @entityRows is assumed to have been set, usually through a call to initCoreAttrOperation() above
  #   by the resource class' initOperation() method.
  def commonCoreAttrDelete(accessMap=PERMISSIONS_RW_GET_ONLY, entityRowColName='id')
    initStatus = @statusName = initOperation()
    if(initStatus == :OK)
      # Check permission for inserts (by default must be admin of a group)
      unless(accessAllowed?(accessMap))
        @apiError = BRL::Genboree::GenboreeError.new(:'Forbidden', "FORBIDDEN: You do not have sufficient access to delete #{self.class::RSRC_STRS[:capital]} attributes for #{@entityName.inspect}.")
      else  # Sufficient access
        # Get the entity row by name using method implemented in specific rest/resource/*.rb file:
        if(@entityRows and !@entityRows.empty?)
          entityRow = @entityRows.first
          entityId = entityRow[entityRowColName]
          if(self.class::STD_ATTRS.key?(@attrName)) # CORE ATTRIBUTE / COLUMN
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "UNDELETEABLE: You cannot perform a DELETE operation on the attribute #{@attrName.inspect}")
          else  # custom attribute
            # Find the id of the attribute to be deleted using selectAttrNameByName() as implemented in specific rest/resource/*.rb file:
            attrRow = selectAttrNameByName(@attrName)
            avpHash = getAvpHash(@dbu, entityId)
            if(!avpHash.key?(@attrName))
              @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "NOT_FOUND: The #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect} does not have the attribute #{@attrName.inspect}")
            else
              attrId = attrRow.first['id']
              # Use appropriate entity-attribute deleting method implemented in specific rest/resource/*.rb file:
              rowsDeleted = deleteEntity2AttributeById(entityId, attrId)
              if(rowsDeleted == 1)
                entity = BRL::Genboree::REST::Data::AbstractEntity.new(@connect)
                entity.setStatus(:OK, "The attribute #{@attrName.inspect} was successfully deleted from the #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect}")
                @statusName = configResponse(entity)
              else
                @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "There was a problem deleting the attribute #{@attrName.inspect} from the #{self.class::RSRC_STRS[:capital]} #{@entityName.inspect}")
              end
            end
          end
        else
          @apiError = BRL::Genboree::GenboreeError.new(:'Internal Server Error', "UNKNOWN_ERROR: There was a DB error while querying for the #{self.class::RSRC_STRS[:capital]} named #{@entityName.inspect}")
        end
      end
    end

    # If something wasn't right, represent as error
    @resp = representError() if(@statusName != :OK)
    return @resp
  end

  # ############################################################################
  # User-Related Helpers
  # ############################################################################

  # Initialize user related info, do checks. Will set @statusName; on error, will
  # set a suitable @statusMsg.
  #
  # * Assumes availability of: @reqMethod, @userId (from +gbLogin+ param), @rsrcUuserName (from resource path), @dbu
  # * Provides: @rsrcUserId
  #
  # [+returns+] The status of obtaining this info (i.e. @statusName) as a +Symbol+. For success, :OK, else other HTTP response error name.
  def initUser()
    status = initUserGeneric()
    if(status == :Forbidden)
      if(@detailed)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "user access info:\n  - #{@rsrcUserName.inspect}\n  - #{@usrName.inspect}\n  - #{@gbKeyverified.inspect}\n  - #{@rsrcUserId.inspect}\n  - #{@userId.inspect}")
        @statusMsg = "FORBIDDEN: You can't access in-depth user information for people other than yourself."
      else
        # then relax access restriction from initUserGeneric to allow access to non-detailed user information
        @statusName = :OK
        @statusMsg = "OK"
      end
    end
    return @statusName
  end

  # Restrict/allow access to resources with the pattern /REST/{ver}/usr/{usr}
  # @return [Symbol] HTTP status code name as a symbol (generally OK, Forbidden, Not Found)
  def initUserGeneric()
    @statusName = :OK
    # Check that @userId (from gbLogin) matches userId for @rsrcUserName (from resource path)
    # Get users for @userName
    users = @dbu.getUserByName(@rsrcUserName)
    unless(users.nil? or users.empty?)
      @rsrcUserId = users.first["userId"]
      @usrName = users.first['name']
      @usrEmail = users.first['email']
      if(@rsrcUserName == @usrName)
        # If the user in the rsrcPath is not the user making the request then the requestor needs to be the superuser
        if(!@gbKeyVerified and @rsrcUserId != @userId and @superuserApiDbrc.user != @gbLogin)
          @statusName = :'Forbidden'
          @statusMsg = "You do not have permission to access user information for #{@rsrcUserName.inspect}."
        end
      else
        @statusName = :'Not Found'
        @statusMsg = "NO_USR: There is no user #{@rsrcUserName.inspect}. Names are case sensitive, please use correct capitalization." # Adding this might be a security risk: (perhaps you meant '#{@refseqName}')?"
      end
    else
      @statusName = :'Not Found'
      @statusMsg = "NO_USR: The user #{@rsrcUserName.inspect} resource referenced in the API URL doesn't exist (or perhaps isn't encoded correctly?)"
    end
    return @statusName
  end

  # ############################################################################
  # User Group-Related Helpers
  # ############################################################################

  # Initialize user group related info, do checks. Will set @statusName; on error, will
  # set a suitable @statusMsg.
  #
  # * Assumes availability of: @reqMethod, @groupName, @dbu, @isSuperuser
  # * Provides: @groupId, @groupDesc, @groupAccessStr
  #
  # [+checkAccess+] if true, this method will check whether the users role is adequate for the requested method
  # [+returns+] The status of obtaining this info (i.e. @statusName) as a +Symbol+. For success, :OK, else other HTTP response error name.
  #
  # @note resources calling this method (and not a more specific initGroupAnd* method) should explicitly check the value
  #   of @groupAccessStr and not rely on the return value. Otherwise, if a group has ANY public databases (@groupAccessStr = 'p'),
  #   resources relying on initGroup return value of :OK will incorrectly provide access
  def initGroup(checkAccess=true)
    @statusName = :OK
    # Get groupId for groupName
    genboreegroupRows = @dbu.selectGroupByName(@groupName)
    unless(genboreegroupRows.nil? or genboreegroupRows.empty?)
      @groupId = genboreegroupRows.first['groupId']
      @grpName = genboreegroupRows.first['groupName']
      @groupDesc = genboreegroupRows.first['description']
      if(@groupName == @grpName)
        if(@isSuperuser)
          # Superuser has full access
          @groupAccessStr = 'o'
        else # non-superuser access, determine appropriate access level
          if((@gbLogin and !@gbLogin.empty? and @userId and @userId != 0) or (!@gbKeyVerified))
            # Is user in group and does he have enough permission to perform REQUEST_METHOD?
            groupAccessStrRow = @dbu.getAccessByUserIdAndGroupId(@userId, @groupId)
            @groupAccessStr = ((groupAccessStrRow.nil? or groupAccessStrRow.empty?) ? nil : groupAccessStrRow['userGroupAccess'] )
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@userId: #{@userId.inspect} ; @groupId: #{@groupId.inspect} ; @groupAccessStr: #{@groupAccessStr.inspect} ; groupAccessStrRow:\n\n#{groupAccessStrRow.inspect}")
            if(@groupAccessStr.nil? or @groupAccessStr.empty?)  # Then user NOT in group, but need to check if allowed access because public
              # Need to determine if the group contains ANY public databases. We will PROVISIONALLY allow access to the group,
              # with more specific resource [database] determining whether access should actually be granted.
              publicDbs = @dbu.selectPublicRefseqsByGroupId(@groupId)
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Any public databases in this group? #{publicDbs.size}")
              if(!publicDbs.empty?)
                # If there are public databases, grant access to those dbs (final decision made in initGroupAndDatabase(), using specific database)
                @groupAccessStr = 'p'
              end
            end
          elsif(@groupId == @genbConf.publicGroupId.to_i)
            @groupAccessStr = 'p'
          end
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "@reqMethod: #{@reqMethod.inspect} ; @groupAccessStr: #{@groupAccessStr.inspect} ; @grpName: #{@grpName.inspect} ; @gbKey: #{@gbKey.inspect} ; @grpName: #{@grpName.inspect} ; @dbName: #{@dbName.inspect}")
          # Added checkAccess so other resources could use these methods and so a gbKey can rescue a user who isn't a member of the group
          if( checkAccess and (@groupAccessStr.nil? or @groupAccessStr.empty? or
              (READ_ONLY_METHODS.key?(@reqMethod) and @groupAccessStr !~ /^(?:r|w|o|p)$/) or
              (!READ_ONLY_METHODS.key?(@reqMethod) and @groupAccessStr !~ /^(?:w|o)$/)))
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "(READ_ONLY_METHODS.key?(@reqMethod) and @groupAccessStr !~ /^(?:r|w|o|p)$/): #{(READ_ONLY_METHODS.key?(@reqMethod) and @groupAccessStr !~ /^(?:r|w|o|p)$/)} ; (!READ_ONLY_METHODS.key?(@reqMethod) and @groupAccessStr !~ /^(?:w|o)$/) #{(!READ_ONLY_METHODS.key?(@reqMethod) and @groupAccessStr !~ /^(?:w|o)$/)}")
            # Try to fall back on gbKey if present
            reusableComponents = { :superuserApiDbrc => @superuserApiDbrc, :superuserDbDbrc => @superuserDbDbrc }
            apiUriHelper = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@dbu, @genbConf, reusableComponents)
            apiUriHelper.rackEnv = @rackEnv
            gbKeyAccessStatus = apiUriHelper.gbKeyAccess(@req.url, @reqMethod, @gbKey)
            if(gbKeyAccessStatus == :OK)
              @gbKeyVerified = true
              # some instance vars that are required by resources
              @groupAccessStr = 'r' # default access should be read
              @userId = 0           # default user id
              @statusMsg = @statusName = :OK
            else
              @statusName = :'Forbidden'
              @statusMsg = "FORBIDDEN: The username provided does not have sufficient access or permissions to operate on the resource."
            end
              #end
            #end
          end
        end
      else
        @statusName = :'Not Found'
        @statusMsg = "NO_GRP: There is no user group #{@groupName.inspect}. Names are case sensitive, please use correct capitalization." # Adding this might be a security risk: (perhaps you meant '#{@refseqName}')?"
      end
    else
      @statusName = :'Not Found'
      @statusMsg = "NO_GRP: The user group #{@groupName.inspect} resource referenced in the API URL doesn't exist (or perhaps isn't encoded correctly?)"
    end
    return @statusName
  end

  # ############################################################################
  # User Database-Related Helpers
  # ############################################################################

  # Initialize user group and user database related info, do checks. Will set @statusName; on error, will
  # set a suitable @statusMsg.
  #
  # * Assumes availability of: @reqMethod, @groupName, @dbu
  # * Provides: @groupId, @groupDesc, @groupAccessStr, @refSeqId, @databaseName
  #
  # [+checkAccess+] if true, this method will check whether the users role is adequate for the requested method
  # [+returns+] The status of obtaining this info (i.e. @statusName) as a +Symbol+. For success, :OK, else other HTTP response error name.
  def initGroupAndDatabase(checkAccess=true)
    # Init group first:
    @statusName = initGroup(checkAccess)
    if(@statusName == :OK)
      grpIdFound = false
      refseqRows = nil
      # We need to handle proper & matched group-refseq pairs in the resource path
      # AND the older approach to accessing published databases through the special
      # "Public" group. These two cases require separate handling initially.
      # . in particular we need to allow access to published databases being access via the
      #   special "Public" group but which are NOT ACTUALLY IN the "Public" group
      # . i.e. it's being used as a kind of "view" which is the old approach from the Java code.
      # . see notes in initGroup()

      # Accessing via special "Public" group/view? [bad & old & has risks]
      if(@groupId == @genbConf.publicGroupId.to_i and (@groupAccessStr == 'p' or @groupAccessStr == 'r'))
        # Get refseq rows using database name only. Not guarranteed unique! (only unique within its original group! oh no!)
        refseqRows = @dbu.selectRefseqByName(@dbName)
        # Also need to check which of returned databases (ideally 1, but can't rely on that) are flagged as "public".
        if(refseqRows)
          refseqRows.delete_if { |refseqRow|
            (refseqRow['public'] != true and refseqRow['public'] != 1)
          }
          # Ideally we are left with just 1 refseq row...the 1 database with that name which is
          # also public.  If no rows, then it was a lie/attack/problem. If 2+ rows, there are
          # MULTIPLE public databases with that name. OUCH! Can't tell which is the specific
          # public one being accessed. That's an situation we cannot resolve!
          if(refseqRows.size == 1) # then we have the 1 public database with this name, yay!
            # Info about database
            @refseqName = refseqRows.first["refseqName"]
            @refSeqId = refseqRows.first["refSeqId"]
            @databaseName = refseqRows.first["databaseName"]
            @dbu.setNewDataDb(@databaseName)
            # Still don't know *real* group owning this database.
            # Unlike regular, non-Public-Group access, we weren't given this. Get it.
            groupRefSeqRows = @dbu.selectGroupRefSeqByRefSeqId(@refSeqId)
            grpIdFound = false
            groupRefSeqRows.each { |row| # It MAY be a member of special Public group explicitly (old) or it may not (new)
              if(row['groupId'] != @genbConf.publicGroupId.to_i)
                grpIdFound = true
                @groupId = row['groupId']
                @statusName = :OK
                @statusMsg = ''
                break # Found true group id, don't bother with the rest
              end
            }
            if(grpIdFound) # need to fill in ACTUAL (non-"Public") group info! resources expect the REAL group, not this special Public fake group thing!
              genboreegroupRows = @dbu.selectGroupById(@groupId)
              unless(genboreegroupRows.nil? or genboreegroupRows.empty?)
                @groupId = genboreegroupRows.first['groupId']
                @grpName = @groupName = genboreegroupRows.first['groupName']
                @groupDesc = genboreegroupRows.first['description']
              end
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_DB: Could not find the *actual* group in which #{@dbName.inspect} resides."
            end
          elsif(refseqRows.size < 1) # then no public databases with that name
            @statusName = :'Not Found'
            @statusMsg = "NO_DB: There is no publicly-accessible database named #{@dbName.inspect}."
          else # (refseqRows.size > 1) # then more than one database with that name is public! oh no!
            @statusName = :'Not Found'
            @statusMsg = "FORBIDDEN: Unfortunately, there are #{refseqRows.size} databases named #{@dbName.inspect} which are also public. Thus they CANNOT be accessed via the 'Public' special group/view; the actual group in which the database resides is needed to resolve the ambiguity! Contact your Genboree installation admins for assistance."
          end
        end
      else # Not an access via special "Public" group. May be a publicly accessible group, but not going through grp/Public/db/{db}
        # Usual db access checking
        # Get refseqRow matching dbName AND groupId
        refseqRows = @dbu.selectRefseqByNameAndGroupId(@dbName, @groupId)
        unless(refseqRows.nil? or refseqRows.empty?)
          refseqRows.each { |refseqRow|
            # First, check if refseqName matches exactly (i.e. by case too)
            # the @dbName from the URI
            if(@dbName == refseqRow["refseqName"])
              @refseqName = refseqRow["refseqName"]
              @refSeqId = refseqRow["refSeqId"]
              @databaseName = refseqRow["databaseName"]
              @dbu.setNewDataDb(@databaseName)
              # Is this user database in the indicated group? (no backdoors...)
              groupRefSeqRows = @dbu.selectGroupRefSeqByRefSeqId(@refSeqId)
              if(!groupRefSeqRows.nil? and !groupRefSeqRows.empty?)
                grpIdFound = false
                groupRefSeqRows.each { |row|
                  if(@groupId == row['groupId'])
                    grpIdFound = true
                    @statusName = :OK
                    @statusMsg = ''
                    break # Found it, don't bother with the rest
                  end
                }
                if(grpIdFound)
                  break # Found it, don't bother with the rest
                else
                  @statusName = :'Not Found'
                  @statusMsg = "NO_DB: There is no user database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
                end
              else
                @statusName = :'Not Found'
                @statusMsg = "NO_DB: There is no user database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
              end
            else
              @statusName = :'Not Found'
              @statusMsg = "NO_DB: There is no user database #{@dbName.inspect} in user group #{@groupName.inspect}. Names are case sensitive, please use correct capitalization." # Adding this might be a security risk: (perhaps you meant '#{@refseqName}')?"
            end
          }
        else
          @statusName = :'Not Found'
          @statusMsg = "NO_DB: There is no user database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)" # Actually, worse: no such db at all; but we don't reveal that info for security.
        end
      end
      # If we're doing a PUBLIC access (@userId = 0 and/or @groupAccessStr = 'p'), without a gbKey provided (or without the correct one, anyway)
      # then to allow access to the resource, assert that @refSeqId is actually public (else, having just 1 public database in a group gives
      # access to ALL databases in group)@groupAccessStr = #{@groupAccessStr.inspect}")
      if(@userId == 0 or @groupAccessStr == 'p')
        unless(@gbKeyVerified)  # If a gbKey not given or wrong, see if we can give access on basis of resource being PUBLIC
          # Verify the refseq is actually public then:
          if(@dbu.isRefseqPublic(@refSeqId))
            @groupAccessStr = 'r'
            @statusName = :OK
            @statusMsg = "OK"
          else
            @statusName = :'Forbidden'
            @statusMsg = "FORBIDDEN: The Genboree database #{@dbName.inspect} is private and you are not a member of the group that owns it."
          end
        else  # gbKey was given and verified (which set @userId=0), so give 'r' access
          @groupAccessStr = 'r'
          @statusName = :OK
          @statusMsg = "OK"
        end
      # else was a real user access and we've check they have sufficient access
      end

      # cleanup
      refseqRows.clear() if(refseqRows)
    end
    return @statusName
  end

  def verifyUnlockKey(key)
    notImplemented()
  end

  # ############################################################################
  # Knowledgebase-Related Helpers
  # ############################################################################

  # Initialize user group and user knowledgebase related info, do checks. Will set @statusName; on error, will
  #   set a suitable @statusMsg.
  # * Assumes availability of: @reqMethod, @groupName, @dbu
  # * Provides: @groupId, @groupDesc, @groupAccessStr, @refSeqId, @databaseName, @mongoKbDb
  # @param [Boolean] checkAccess If @true@, this method will check whether the users role is adequate for the requested method
  # @return [Symbol] The status of obtaining this info (i.e. {#statusName}) as a {Symbol}. For success, @:OK,@ else other HTTP response error name.
  def initGroupAndKb(checkAccess=true)
    # Init group first:
    @statusName = initGroup(checkAccess)
    if(@statusName == :OK)
      kbRows = nil
      @kbDbName = @kbId = nil
      @kbRefSeqName = nil
      # Usual access checking
      # Get kbs row matching kbName AND groupId. May return several since MySQL searches case-insensitive by default
      kbRows = @dbu.selectKbByNameAndGroupId(@kbName, @groupId)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "kbRows:\n\n#{kbRows ? JSON.pretty_generate(kbRows) : "NO KB ROWS!"}\n\n")
      unless(kbRows.nil? or kbRows.size != 1)
        kbRow = kbRows.first
        # First, check if name in row matches exactly (i.e. by case too) the @kbName from the URI.
        # - perhaps unnecessary, although does protect nicely against MySQL's case-insensitivity default.
        if(@kbName == kbRow['name'])
          @kbId = kbRow['id']
          @kbDbName = kbRow["databaseName"]
          @kbRefSeqName = kbRow['refseqName']
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "KB found: #{@kbName.inspect}, #{@kbId.inspect}, #{@kbDbName.inspect}")
          # @todo Create a mongodb connection to this databaseName
          # - Get dbrc record for the mongo host backing @reqHost
          dbrc = BRL::DB::DBRC.new()
          @mongoDbrcRec = dbrc.getRecordByHost(@reqHost, :nosql) unless(@mongoDbrcRec and @mongoDbrcRec.is_a?(Hash))
          # - Create MongoKbDb object, which will establish a connection, auth against 'admin' and then auth against actual database
          begin
            #$stderr.debugPuts(__FILE__, __method__, "TIME", "__before__ new MongoKbDatabase" )
            @mongoKbDb = BRL::Genboree::KB::MongoKbDatabase.new(@kbDbName, @mongoDbrcRec[:driver], { :user => @mongoDbrcRec[:user], :pass => @mongoDbrcRec[:password] })
            #$stderr.debugPuts(__FILE__, __method__, "TIME", "__after__ after new MongoKbDatabase" )
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Made MongoKbDatabase instance:\n\n#{@mongoKbDb.inspect}\n\n")
          rescue => err
            @statusName = :'Internal Server Error'
            @statusMsg = "BAD_KB: The GenboreeKB you are trying to access is not presne or cannot be accessed by the Genboree server, perhaps due to a configuration or internal authentication problem."
            $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "Could not make proper connection to #{@kbDbName.inspect} using DSN #{@mongoDbrcRec ? @mongoDbrcRec[:driver].inspect : '[NO VALID DSN STRING FOUND]'}. Possibly authentication info wrong in that database, or preliminary connection to 'admin' database failed. Exception specifics:\n  ERR CLASS: #{err.class}\n  ERR MSG: #{err.message}\n  ERR TRACE:\n#{err.backtrace.join("\n")}")
          end
          # Did the @mongoKbDb.db get set to a valid Mongo::DB? (should have; but MongoKbDatabase allows the db to be provided later)
          unless(@mongoKbDb and @mongoKbDb.db.is_a?(Mongo::DB))
            @statusName = :'Internal Server Error'
            @statusMsg = "BAD_KB: While we found the internal name and identifier for #{@kbName} (#{@kbDbName.inspect}, #{@kbId.inspect}), the Genboree server could not establish a valid connection to it. This GenboreeKB is possibly corrupt and/or misconfigured."
            @kbId = nil
          end
        else
          @statusName = :'Not Found'
          @statusMsg = "NO_KB: There is no GenboreeKB #{@kbName.inspect} in user group #{@groupName.inspect} (perhaps incorrect case was provided in the spelling? names are case-sensitive)"
        end
      else
        @statusName = :'Not Found'
        @statusMsg = "NO_KB: There is no user knowledgebase #{@kbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
      end # unless(kbRows.nil? or kbRows.size != 1)
      # Cleanup
      kbRows.clear() if(kbRows)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "kbId = #{@kbId.inspect} ; kbDbName = #{@kbDbName.inspect} ; statusName = #{@statusName.inspect} ; statusMsg = #{@statusMsg.inspect}")
      # If we found our Kb, there are still some things to take care of...
      if(@kbId and @statusName == :OK)
        # If we're doing a PUBLIC access (@userId = 0 and/or @groupAccessStr = 'p'), without a gbKey provided (or without the correct one, anyway)
        # then to allow access to the resource, assert that @kbId is actually public (else, having just 1 public database in a group gives
        # access to ALL databases in group)
        if(@userId == 0 or @groupAccessStr == 'p')
          unless(@gbKeyVerified)  # i.e. If a gbKey not given or wrong, see if we can give access anyway on basis of resource being PUBLIC
            # Verify the refseq is actually public then:
            if(@dbu.isKbPublic(@kbId))
              @groupAccessStr = 'r'
              @statusName = :OK
              @statusMsg = "OK"
            else
              @statusName = :'Forbidden'
              @statusMsg = "FORBIDDEN: The Genboree database #{@kbName.inspect} is private and you are not a member of the group that owns it."
            end
          else  # gbKey was given and verified (which set @userId=0), so give 'r' access
            @groupAccessStr = 'r'
            @statusName = :OK
            @statusMsg = "OK"
          end
        # else was a real user access and we have already checked they have sufficient access
        end
      end
    end
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "about to return ; statusName = #{@statusName.inspect} ; statusMsg = #{@statusMsg.inspect}")
    return @statusName
  end

  # @set @mongoDch, assumes @mongoKbDb has been set already by e.g. initGroupAndKb
  # @param [Boolean] checkAccess @see initGroupAndKb
  # @param [String] collName the collection name to get a handle to
  def initColl(checkAccess=true, collName=@collName)
    begin
      if(@mongoKbDb.nil? or !@mongoKbDb.db.is_a?(Mongo::DB))
        statusName = initGroupAndKb(checkAccess)
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg) unless(statusName == :OK)
      end
      unless(@mongoKbDb.collections.include?(collName))
        @statusName = :"Not Found"
        @statusMsg = "NO_COLL: There is no data collection #{collName.inspect} in the #{@kbName.inspect} GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
      end
      @mongoDch = @mongoKbDb.dataCollectionHelper(collName)
      @statusName = :OK
      @statusMsg = "OK"
    rescue => err
      unless(err.is_a?(BRL::Genboree::GenboreeError))
        @statusName = :"Internal Server Error"
        @statusMsg = "Could not initialize access to the collection #{collName.inspect}"
      end
    end
    return @statusName
  end

  # Initialize access to a questionnaire resource
  # @see initColl
  # @sets @mongoKbDb and @mongoQh
  def initQuestion(checkAccess=true)
    begin
      if(@mongoKbDb.nil? or !@mongoKbDb.db.is_a?(Mongo::DB))
        statusName = initGroupAndKb(checkAccess)
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg) unless(statusName == :OK)
      end
      # in addition to preparing access to the @mongoKbDb, also prepare access to questionnaire collection
      @mongoQh = @mongoKbDb.questionsHelper()
      @statusName = :OK
      @statusMsg = "OK"
    rescue => err
      unless(err.is_a?(BRL::Genboree::GenboreeError))
        @statusName = :"Internal Server Error"
        @statusMsg = "Could not initialize access to the questionnaires for kb #{@kbName.inspect}"
      end
    end
    return @statusName
  end

  # Initialize access to a answer document resource
  # @see initColl
  # @sets @mongoKbDb and @mongoAn
  def initAnswer(checkAccess=true)
    begin
      if(@mongoKbDb.nil? or !@mongoKbDb.db.is_a?(Mongo::DB))
        statusName = initGroupAndKb(checkAccess)
        raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg) unless(statusName == :OK)
      end
      # in addition to preparing access to the @mongoKbDb, also prepare access to questionnaire collection
      @mongoAn = @mongoKbDb.answersHelper()
      @mongoQh = @mongoKbDb.questionsHelper()
      @statusName = :OK
      @statusMsg = "OK"
    rescue => err
      unless(err.is_a?(BRL::Genboree::GenboreeError))
        @statusName = :"Internal Server Error"
        @statusMsg = "Could not initialize access to answers for kb #{@kbName.inspect}"
      end
    end
    return @statusName
  end

  # ############################################################################
  # Project-Related Helpers
  # ############################################################################

  # Initialize user group and project related info, do checks. Will set @statusName; on error, will
  # set a suitable @statusMsg.
  #
  # * Assumes availability of: @reqMethod, @groupName, @projName, @dbu
  # * Provides: @groupId, @groupDesc, @groupAccessStr, @topLevelProjs, @projName, @projBaseDir, @escProjName, @projDir
  #
  # [+returns+] The status of obtaining this info (i.e. @statusName) as a +Symbol+. For success, :OK, else other HTTP response error name.
  def initGroupAndProject()
    # Init the group first
    @statusName  = initGroup()
    @topLevelProjs = nil
    @projName = @projectName if(@projectName and !@projectName.nil?)
    if(@statusName == :OK)
      # Get top-level projects in this group
      @topLevelProjs = @dbu.getProjectsByGroupId(@groupId)
      # Extract top-level project name if any (projName can be fully quyalified sub-project name)
      if(@projName and !@projName.empty?)
        pathElems = @projName.split(/\//)
        unless(pathElems.nil? or pathElems.empty?)
          @topLevelProjName = pathElems.first
          # If there is a sub-project path, does it exist? (This check should also end up enforcing the case-specificity)
          @projBaseDir = genbConf.gbProjectContentDir
          @escProjName = Rack::Utils.escape(@projName)
          @projDir = "#{@projBaseDir}/#{@projName}"
          unless(File.exist?(@projDir))
            @statusName = :'Not Found'
            @statusMsg = "NO_PRJ: There is no project #{@projName.inspect} in user group #{@groupName.inspect} (perhaps isn't encoded correctly? specifically had problems locating the project directory)"
          end
        else
          @statusName = :'Not Found'
          @statusMsg = "NO_PRJ: There is no project #{@projName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
        end
      end
    end
    return @statusName
  end

  # Initialize project-specific operation; used _instead_ of directly calling the inherited #initOperation. This
  # method will call that but also will add some stuff specific to projects. Will set @statusName; on error, will
  # set a suitable @statusMsg.
  #
  # * Assumes availability of: @req, @uriMatchData, @reqMethod
  # * Provides: @context, @groupName, @groupId, @groupDesc, @groupAccessStr, @topLevelProjs, @projName, @projBaseDir, @escProjName, @projDir
  #
  # [+returns+] The status of obtaining this info (i.e. @statusName) as a +Symbol+. For success, :OK, else other HTTP response error name.
  def initProjOperation()
    # Init the operation
    @statusName = initOperation()
    @context = nil
    if(@statusName == :OK)
      # Init the group first
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @statusName = initGroup()
      if(@statusName == :OK)
        @projName = (@uriMatchData[2] ? Rack::Utils.unescape(@uriMatchData[2]) : '')
        @aspect = (@uriMatchData[3] ? Rack::Utils.unescape(@uriMatchData[3]) : nil)
        @aspectProperty = (@uriMatchData[4] ? Rack::Utils.unescape(@uriMatchData[4]) : nil)
        # We need a GenboreeContext object, with :dbu, :groupId, and :userId entries
        @context = BRL::Genboree::GenboreeContext.load({}, @req.env)
        @context[:dbu], @context[:groupId], @context[:userId] = @dbu, @groupId, @userId
        @statusName = initGroupAndProject()
      end
    end
    return @statusName
  end

  # Creates a +BRL::Genboree::Abstract::Resources::Project+ instance for managing elements of a Project.
  # Will set @statusName; on error, will set a suitable @statusMsg.
  #
  # * Assumes availability of: @context, @projName, @context[:groupId]
  # * Provides: @projectObj
  #
  # [+returns+] The status of obtaining this info (i.e. @statusName) as a +Symbol+. For success, :OK, else other HTTP response error name.
  def initProjectObj()
    @statusName = :OK
    @projectObj = nil
    begin
      @context[:projectName] = @projName
      @projectObj = BRL::Genboree::Abstract::Resources::Project.new(@projName, @context[:groupId])
    rescue => err
      BRL::Genboree::GenboreeUtil.logError("ERROR: failed to create Project abstract resourceinstance.", err, @projName, @context)
      @statusName = :'Internal Server Error'
      bktrace = err.backtrace.join("\n")
      @statusMsg = "FATAL: server encountered an error retreiving information on project #{@projName.inspect} in user group #{@groupName.inspect}.\n#{err}:\n#{bktrace}"
    end
    return @statusName
  end

  # ############################################################################
  # Annotation Data-Related Helpers
  # ############################################################################

  # Are ALL tracks in the given Array (of Track abstraction objects) downloadable? Or do some have their anno download blocks via 'gbNotDownloadable' attribute?
  def checkTracksDownloadable(trackObjs)
    retVal = :OK
    nonDownloadTracks = []
    trackObjs.each { |trkObj|
      nonDownloadTracks << trkObj.trackName if(trkObj.annoDownloadBlocked?)
    }
    # Did we find any non-downloadable tracks? If so, build message and return non-OK
    unless(nonDownloadTracks.empty?)
      retVal = @statusName = :'Forbidden'
      @statusMsg = "FORBIDDEN: Annotation download is forbidden for one or more of the requested tracks. Download blocked for: #{nonDownloadTracks.join(' , ')}."
    end
    return retVal
  end

  # Get the fref (entrypoint info) rows for a particular user database.
  #
  # * Assumes availability of: @databaseName, @dbu
  #
  # [+genbDBName+] [optional; default=@databaseName] Genboree user DB name to get entrypoint info for.
  # [+returns+] +Array+ of +fref+ table rows for the database.
  def getFrefRows(genbDBName=@databaseName)
    BRL::Genboree::Abstract::Resources::Entrypoint.getFrefRows(dbu, genbDBName)
  end

  # Get a map of ftypeid->classNames info for each database.
  #
  # * Assumes availability of: @dbu
  #
  # [+dbRecs+]  +Array+ of struct objects that each have a +.dbName+ and +.ftypeid+ property, indicating all the databases this track is avialable in.
  # [+returns+] +Hash+ mapping dbName->ftypeid->classNames
  def getTrackClassInfo(dbRecs)
    retVal = Hash.new{|hh,kk| hh[kk] = Hash.new{|jj, ll| jj[ll] = [] } }  # {dbName=>{ftypeid=>[gclass1,...]}}
    dbRecs.each { |dbRec|
      @dbu.setNewDataDb(dbRec.dbName)
      ftype2gclassNamesRows = @dbu.selectAllFtypeClasses(dbRec.ftypeid)
      ftype2gclassNamesRows.each { |row|
        retVal[dbRec.dbName][dbRec.ftypeid] << row['gclass']
      }
      ftype2gclassNamesRows.clear()
    }
    return retVal
  end

  # Get 3 column array of track description, url, and urlLabel for a track.
  #
  # * Assumes availability of: @dbu
  #
  # [+dbRecs+]  +Array+ of struct objects that each have a +.dbName+ and +.ftypeid+ property, indicating all the databases this track is avialable in.
  # [+returns+] +Array+ of +fref+ table rows for the database.
  def getTrackDescUrlInfo(dbRecs)
    descInfo = [ nil, nil, nil ]
    dbRecs.each { |dbRec|
      @dbu.setNewDataDb(dbRec.dbName)
      featureurlRows = @dbu.selectFeatureurlByFtypeId(dbRec.ftypeid)
      unless(featureurlRows.nil? or featureurlRows.empty?)
        descRow = featureurlRows.first
        descInfo[0] = descRow['description']
        descInfo[1] = descRow['url']
        descInfo[2] = descRow['label']
        break
      end
      featureurlRows.clear() if(featureurlRows)
    }
    return descInfo
  end

  # ############################################################################
  # Entity-Creation Helpers
  # ############################################################################

  # Create a BRL::Genboree::REST::Data::DetailedTrackEntity object for a track
  # an other core information.
  #
  # * Assumes availability of: @connect, @dbu
  #
  # [+ftypeHash+]     A +Hash+-like object for the track with keys 'fmethod' and 'fsource'
  # [+dbRecs+]        +Array+ of structs having fields +.dbName+, +.ftypeid+, indicating all the databases this track is avialable in.
  # [+refBase+]       A base URl for making any reference links/connections.
  # [+doAttributes+]  [optional; default=true] Boolean indicating whether to get the attributes for the track or not.
  # [+returns+]       The new BRL::Genboree::REST::Data::DetailedTrackEntity instance.
  def makeDetailedTrackEntity(ftypeHash, dbRecs, refBase, doAttributes=true)
    # collect unique dbNames (we will have to get some info (classes, attributes) from both template & user databases where this track lives)
    dbNames = {}
    dbRecs.each { |dbRec| dbNames[dbRec.dbName] = true }
    # compose track name
    tname = "#{ftypeHash['fmethod']}:#{ftypeHash['fsource']}"
    # get ftypeid<->description info for this track; local overrides template db for desc, url, urlLabel:
    desc, url, urlLabel = getTrackDescUrlInfo(dbRecs)
    # make entity for this track:
    entity = BRL::Genboree::REST::Data::DetailedTrackEntity.new(@connect, tname, desc, url, urlLabel)
    entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(tname)}")
    # get classes for track
    classListEntity = makeClassesListEntity(dbRecs)
    entity.classes = classListEntity
    if(doAttributes)
      # get attributes for this track, and add to the track entity
      annoAttrListEntity = makeAttributesListEntity(dbRecs)
      entity.annoAttributes = annoAttrListEntity
    end # if(doAttributes)
    @statusName = :OK
    return entity
  end # def makeDetailedTrackEntity(ftypeHash, dbRecs, refBase, doAttributes=true)

  # Create list of classes associated with a track (from all the related databases in dbRecs)
  # as a BRL::Genboree::REST::Data::TextEntityList
  #
  # * Assumes availability of: @connect, @dbu
  #
  # [+dbRecs+]        +Array+ of structs having fields +.dbName+, +.ftypeid+
  # [+returns+]       The new BRL::Genboree::REST::Data::TextEntityList instance containing the class names.
  def makeClassesListEntity(dbRecs)
    # get ftypeid<->classes lists for each database
    ftypeid2classes = getTrackClassInfo(dbRecs)                         # {dbName=>{ftypeid=>[gclass1,...]}}
    # Find unique class names for this track, from each database
    classesHash = {}
    dbRecs.each { |dbRec|
      ftypeid2classes[dbRec.dbName][dbRec.ftypeid].each { |className|
        classesHash[className] = true
      }
    }
    ftypeid2classes.clear() if(ftypeid2classes)
    # Add list of unique classes to this track entity
    classArray = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
    classesHash.keys.sort{|aa, bb| aa.downcase<=>bb.downcase}.each { |className|
      entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, className)
      classArray << entity
    }
    classesHash.clear()
    @statusName = :OK
    return classArray
  end

  # Create list of attributes associated with a track (from all the related databases in dbRecs)
  # as a BRL::Genboree::REST::Data::TextEntityList
  #
  # * Assumes availability of: @connect, @dbu
  #
  # Note: TAC => There are 2 types of attributes, this method is used to create the data for the {trk}/annoAttribute API resource
  # from the fid2attribute tables;
  # As opposed to the {trd}/attribute resource which is handled by BRL::Genboree::Abstract::Resources::TrackAttributesHandler
  # from the ftype2attributes tables
  #
  # [+dbRecs+]        +Array+ of structs having fields +.dbName+, +.ftypeid+
  # [+returns+]       The new BRL::Genboree::REST::Data::TextEntityList instance containing the attribute names.
  def makeAttributesListEntity(dbRecs)
    # get attribute names associated with track from each database
    attrNames = {}
    dbRecs.each { |dbRec|
      attrIds = []
      @dbu.setNewDataDb(dbRec.dbName)
      ftype2AttrRows = @dbu.selectAttributesForTrack(dbRec.ftypeid)
      ftype2AttrRows.each { |row|
        attrIds << row['attNameId']
      }
      ftype2AttrRows.clear()
      unless(attrIds.empty?) # Can have no attributes for track...don't call selectAttributesByIds with empty array!
        attrNameRows = @dbu.selectAttributesByIds(attrIds)
        attrNameRows.each { |row|
          next if(row['name'].empty?) # skip empty string attribute if there...should NOT BE
          attrNames[row['name']] = true
        }
        attrIds.clear()
        attrNameRows.clear()
      end
    }
    # add unique attribure names to this track entity as a Text list
    attrArray = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
    attrNames.each_key { |attrName|
      entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, attrName)
      attrArray << entity
    }
    attrNames.clear()
    return attrArray
  end

  # Create list of chromosomes(rid) associated with a track (from all the related databases in dbRecs)
  # [+dbRecs+]        +Array+ of structs having fields +.refname+, +.length+
  # [+returns+]       The new BRL::Genboree::REST::Data::DetailedEntrypointEntityList instance containing the chromosome names.
  def makeEpsListEntity(dbRecs, nameFilter=nil)
    # get chromosome names associated with track from each database
    epRows = []
    dbRecs.each { |dbRec|
      @dbu.setNewDataDb(dbRec.dbName)
      $stderr.puts "db: #{dbRec.dbName.inspect}"
      rows = nameFilter.nil? ? @dbu.selectDistinctRidsByFtypeId(dbRec.ftypeid) : @dbu.selectDistinctRidsByFtypeIdAndGname(dbRec.ftypeid, nameFilter)
      if(!rows.nil? and !rows.empty?)
        epRows = rows
      end
    }
    # Check block level recs if epRows still empty
    if(epRows.empty?)
      dbRecs.each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        rows = @dbu.selectDistinctRidsByFtypeIdForBlockLevelData(dbRec.ftypeid)
        if(!rows.nil? and !rows.empty?)
          epRows = rows
        end
      }
    end
    epsArray = []
    epRows.each { |epRow|
      entity = BRL::Genboree::REST::Data::DetailedEntrypointEntity.new(@connect, epRow['refname'], epRow['rlength'].to_i)
      epsArray << entity
    }
    epsListArray = BRL::Genboree::REST::Data::DetailedEntrypointEntityList.new(@connect, epsArray.size, epsArray)
    return epsListArray
  end

  # ##########################################################################
  # Upload/Download Helpers
  # ##########################################################################

  # Creates an appropriately located and permissioned file in which any error
  # content associate with a download (eg annotation download) will go (for debugging, etc.)
  #
  # * Assumes availability of: @genbConf, @dbNameu, @gbLogin, @groupName
  # * Provices: @fileBase, @errFile
  #
  # [+returns+] Nothing meaningful. Sets instance state and creates file.
  def prepDownloadErrorFile()
    apiDownloadDir = @genbConf.gbApiDownloadDir
    @fileBase = "#{apiDownloadDir}/#{CGI.escape(@groupName)}/#{CGI.escape(@dbName)}/#{CGI.escape(@gbLogin)}/#{Time.now.to_s.gsub(/\s/, '_')}"
    @errFile = "#{@fileBase}/#{Time.now.to_f}_#{sprintf('%05d', rand(65535))}_downloadedViaApi.err"
    # Let's make sure everything we need exists and set to right params
    FileUtils.mkdir_p(@fileBase)
    FileUtils.chmod(02775, @fileBase)
    FileUtils.touch(@errFile)
    FileUtils.chmod(0664, @errFile)
    return
  end
end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module Helpers
