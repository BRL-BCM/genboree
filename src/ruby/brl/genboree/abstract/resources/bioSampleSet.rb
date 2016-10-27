#!/usr/bin/env ruby

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++
  # BioSampleSet - this module defines helper methods related to bioSampleSet, intended
  # to be used as a mix-in.
  module BioSampleSet 

    # This method returns true/false depending on whether a bioSampleSet already
    # exists within Genboree.  NOTE: you must have already selected a DataDB on
    # this DBUtil instance prior to calling this method or it will fail.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+bioSampleSetName+] Name of the bioSampleSet to query for
    # [+returns+] +true+ if a bioSampleSetSet by this name already exists in this database
    def bioSampleSetExists(dbu, bioSampleSetName)
      retval = false
      row = dbu.selectBioSampleSetByName(bioSampleSetName)
      unless(row.nil? or row.empty?)
        retval = true
      end
      return retval
    end

    # This method fetches all key-value pairs from the associated +bioSampleSet+
    # AVP tables.  BioSampleSet is specified by bioSampleSet id.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+bioSampleSetId+] DB Id of the +bioSampleSet+ to query AVPs for.
    # [+returns+] A +Hash+ of the AVP pairs associated with this +bioSampleSet+
    def getAvpHash(dbu, bioSampleSetId)
      retVal = {}
      bioSampleSet2attrRows = dbu.selectBioSampleSet2AttributesByBioSampleSetId(bioSampleSetId)
      unless(bioSampleSet2attrRows.nil? or bioSampleSet2attrRows.empty?)
        bioSampleSet2attrRows.each{|row|
          keyRows = dbu.selectBioSampleSetAttrNameById(row['bioSampleSetAttrName_id'])
          key = keyRows.first['name'] unless (keyRows.nil? or keyRows.empty?)
          valueRows = dbu.selectBioSampleSetAttrValueById(row['bioSampleSetAttrValue_id'])
          value = valueRows.first['value'] unless (valueRows.nil? or valueRows.empty?)
          retVal[key] = value
        }
      end
      return retVal
    end
    
    # This method completely updates all of the associated AVP pairs for
    # the specified +bioSampleSet+.  This method examines existing AVPs and changes
    # values as appropriate, but also looks for any pairs that exist in the
    # DB but not the new +Hash+, and removes those relationships, making it
    # possible to delete AVP pairs by removing them from the +Hash+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+bioSampleSetId+] DB Id of the +bioSampleSet+ to query AVPs for.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +bioSampleSet+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def updateAvpHash(dbu, bioSampleSetId, newHash)
      retVal = true
      begin
        oldHash = getAvpHash(dbu, bioSampleSetId)
        if(oldHash.nil? or oldHash.empty?)
          # AVP hash didn't exist before, insert all keys and values
          newHash.each { |attrName,attrValue|
            insertAvp(dbu, bioSampleSetId, attrName, attrValue)
          }
        else
          # AVP hash exists, check all key/value pairs for changes
          oldHash.each { |oldKey, oldVal|
            if(newHash.include?(oldKey))
              if(newHash[oldKey] != oldVal)
                rowsUpdated = insertAvp(dbu, bioSampleSetId, oldKey, newHash[oldKey], :update)
              end
              newHash.delete(oldKey)
            else
              keyRow = dbu.selectBioSampleSetAttrNameByName(oldKey)
              key = keyRow.first
              rowsDeleted = dbu.deleteBioSampleSet2AttributesByBioSampleSetIdAndAttrNameId(bioSampleSetId, key['id'])
            end
          }
          # All remaining values in newHash will be insertions
          newHash.each { |newKey, newVal|
            insertAvp(dbu, bioSampleSetId, newKey, newVal)
          }
        end
      rescue => e
        dbu.logDbError("ERROR: Unknown DB error occurred during BRL::Abstract::Resources::BioSampleSet.updateAvpHash()", e)
        retVal = false
      end
      
      return retVal
    end

    # This method completely updates all of the associated AVP pairs for
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+bioSampleSetId+] DB Id of the +bioSampleSet+ to query AVPs for.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +bioSampleSet+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def insertAvp(dbu, bioSampleSetId, attrName, attrValue, mode = :insert)
      retVal = nil

      # Test for uniqueness of attribute to be inserted
      attrNameExists = dbu.selectBioSampleSetAttrNameByName(attrName)
      nameId = valId = nil
      if(attrNameExists.nil? or attrNameExists.empty?)
        nameInsert = dbu.insertBioSampleSetAttrName(attrName)
        nameId = dbu.getLastInsertId(:userDB)
      else
        nameId = attrNameExists.first['id']
      end

      # Test for uniqueness of value to be inserted
      attrValExists = dbu.selectBioSampleSetAttrValueByValue(attrValue)
      if(attrValExists.nil? or attrValExists.empty?)
        attrValInsert = dbu.insertBioSampleSetAttrValue(attrValue)
        valId = dbu.getLastInsertId(:userDB)
      else
        valId = attrValExists.first['id']
      end

      # Create the AVP link using the bioSampleSet2attribute table
      if(bioSampleSetId and nameId and valId)
        if(mode == :update)
          retval = dbu.updateBioSampleSet2AttributeForBioSampleSetAndAttrName(bioSampleSetId, nameId, valId)
        else
          retVal = dbu.insertBioSampleSet2Attribute(bioSampleSetId, nameId, valId)
        end
      end

      return retVal
    end
  end
end ; end ; end ; end 
