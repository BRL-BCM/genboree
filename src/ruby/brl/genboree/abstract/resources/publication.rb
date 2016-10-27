#!/usr/bin/env ruby

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++
  # Publication - this module defines helper methods related to studies, intended
  # to be used as a mix-in.
  module Publication 
    # This method fetches all key-value pairs from the associated +publication+
    # AVP tables.  Publication is specified by publication id.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+publicationId+] DB Id of the +publication+ to query AVPs for.
    # [+returns+] A +Hash+ of the AVP pairs associated with this +publication+
    def getAvpHash(dbu, publicationId)
      retVal = {}
      publication2attrRows = dbu.selectPublication2AttributesByPublicationId(publicationId)
      unless(publication2attrRows.nil? or publication2attrRows.empty?)
        publication2attrRows.each{|row|
          keyRows = dbu.selectPublicationAttrNameById(row['publicationAttrName_id'])
          key = keyRows.first['name'] unless (keyRows.nil? or keyRows.empty?)
          valueRows = dbu.selectPublicationAttrValueById(row['publicationAttrValue_id'])
          value = valueRows.first['value'] unless (valueRows.nil? or valueRows.empty?)
          retVal[key] = value
        }
      end

      return retVal
    end
    
    # This method completely updates all of the associated AVP pairs for
    # the specified +publication+.  This method examines existing AVPs and changes
    # values as appropriate, but also looks for any pairs that exist in the
    # DB but not the new +Hash+, and removes those relationships, making it
    # possible to delete AVP pairs by removing them from the +Hash+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+publicationId+] DB Id of the +publication+ to query AVPs for.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +publication+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def updateAvpHash(dbu, publicationId, newHash)
      retVal = true
      begin
        oldHash = getAvpHash(dbu, publicationId)
        if(oldHash.nil? or oldHash.empty?)
          # AVP hash didn't exist before, insert all keys and values
          newHash.each { |attrName,attrValue|
            insertAvp(dbu, publicationId, attrName, attrValue)
          }
        else
          # AVP hash exists, check all key/value pairs for changes
          oldHash.each { |oldKey, oldVal|
            if(newHash.include?(oldKey))
              if(newHash[oldKey] != oldVal)
                rowsUpdated = insertAvp(dbu, publicationId, oldKey, newHash[oldKey], :update)
              end
              newHash.delete(oldKey)
            else
              keyRow = dbu.selectPublicationAttrNameByName(oldKey)
              key = keyRow.first
              rowsDeleted = dbu.deletePublication2AttributesByPublicationIdAndAttrNameId(publicationId, key['id'])
            end
          }
          # All remaining values in newHash will be insertions
          newHash.each { |newKey, newVal|
            insertAvp(dbu, publicationId, newKey, newVal)
          }
        end
      rescue => e
        dbu.logDbError("ERROR: Unknown DB error occurred during BRL::Abstract::Resources::Publication.updateAvpHash()", e)
        retVal = false
      end
      
      return retVal
    end

    # This method completely updates all of the associated AVP pairs for
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+publicationId+] DB Id of the +publication+ to query AVPs for.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +publication+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def insertAvp(dbu, publicationId, attrName, attrValue, mode = :insert)
      retVal = nil

      # Test for uniqueness of attribute to be inserted
      attrNameExists = dbu.selectPublicationAttrNameByName(attrName)
      nameId = valId = nil
      if(attrNameExists.nil? or attrNameExists.empty?)
        nameInsert = dbu.insertPublicationAttrName(attrName)
        nameId = dbu.getLastInsertId(:userDB)
      else
        nameId = attrNameExists.first['id']
      end

      # Test for uniqueness of value to be inserted
      attrValExists = dbu.selectPublicationAttrValueByValue(attrValue)
      if(attrValExists.nil? or attrValExists.empty?)
        attrValInsert = dbu.insertPublicationAttrValue(attrValue)
        valId = dbu.getLastInsertId(:userDB)
      else
        valId = attrValExists.first['id']
      end

      # Create the AVP link using the publication2attribute table
      if(publicationId and nameId and valId)
        if(mode == :update)
          retval = dbu.updatePublication2AttributeForPublicationAndAttrName(publicationId, nameId, valId)
        else
          retVal = dbu.insertPublication2Attribute(publicationId, nameId, valId)
        end
      end

      return retVal
    end
  end
end ; end ; end ; end 
