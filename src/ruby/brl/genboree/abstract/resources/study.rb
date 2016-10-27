#!/usr/bin/env ruby

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++
  # Study - this module defines helper methods related to studies, intended
  # to be used as a mix-in.
  module Study

    # This method returns true/false depending on whether a study already
    # exists within Genboree.  NOTE: you must have already selected a DataDB on
    # this DBUtil instance prior to calling this method or it will fail.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+studyName+] Name of the study to query for
    # [+returns+] +true+ if a study by this name already exists in this database
    def studyExists(dbu, studyName)
      retval = false
      row = dbu.selectStudyByName(studyName)
      unless(row.nil? or row.empty?)
        retval = true
      end
      return retval
    end

    # This method fetches all key-value pairs from the associated +study+
    # AVP tables.  Study is specified by study id.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+studyId+] DB Id of the +study+ to query AVPs for.
    # [+returns+] A +Hash+ of the AVP pairs associated with this +study+
    def getAvpHash(dbu, studyId)
      retVal = {}
      study2attrRows = dbu.selectStudy2AttributesByStudyId(studyId)
      unless(study2attrRows.nil? or study2attrRows.empty?)
        study2attrRows.each{|row|
          keyRows = dbu.selectStudyAttrNameById(row['studyAttrName_id'])
          key = keyRows.first['name'] unless (keyRows.nil? or keyRows.empty?)
          valueRows = dbu.selectStudyAttrValueById(row['studyAttrValue_id'])
          value = valueRows.first['value'] unless (valueRows.nil? or valueRows.empty?)
          retVal[key] = value
        }
      end

      return retVal
    end
    
    # This method completely updates all of the associated AVP pairs for
    # the specified +study+.  This method examines existing AVPs and changes
    # values as appropriate, but also looks for any pairs that exist in the
    # DB but not the new +Hash+, and removes those relationships, making it
    # possible to delete AVP pairs by removing them from the +Hash+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+studyId+] DB Id of the +study+ for which to update the AVPs.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +study+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def updateAvpHash(dbu, studyId, newHash)
      retVal = true

      newHash = {} if(newHash.nil?)
      begin
        oldHash = getAvpHash(dbu, studyId)
        if(oldHash.nil? or oldHash.empty?)
          # AVP hash didn't exist before, insert all keys and values
          newHash.each { |attrName,attrValue|
            insertAvp(dbu, studyId, attrName, attrValue)
          }
        else
          # AVP hash exists, check all key/value pairs for changes
          oldHash.each { |oldKey, oldVal|
            if(newHash.include?(oldKey))
              if(newHash[oldKey] != oldVal)
                rowsUpdated = insertAvp(dbu, studyId, oldKey, newHash[oldKey], :update)
              end
              newHash.delete(oldKey)
            else
              keyRow = dbu.selectStudyAttrNameByName(oldKey)
              key = keyRow.first
              rowsDeleted = dbu.deleteStudy2AttributesByStudyIdAndAttrNameId(studyId, key['id'])
            end
          }
          # All remaining values in newHash will be insertions
          newHash.each { |newKey, newVal|
            insertAvp(dbu, studyId, newKey, newVal)
          }
        end
      rescue => e
        dbu.logDbError("ERROR: Unknown DB error occurred during BRL::Abstract::Resources::Study.updateAvpHash()", e)
        retVal = false
      end
      
      return retVal
    end

    # This method inserts a new AVP pairing into the +study+ associated AVP tables.
    # You can also update an existing relationship between a +study+ and a
    # +studyAttrName+ by setting the +mode+ parameter to the symbol +:update+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+studyId+] DB Id of the +study+ for which to associate with this AVP.
    # [+attrName+] A +String+ of the attribute name to use.
    # [+attrValue+] A +String+ of the attibute value to use.
    # [+mode+] A symbol of either +:insert+ or +:update+ to set the mode to use.
    # [+returns+] Number of rows affected in the DB.  +1+ when successful, +0+ when not.
    def insertAvp(dbu, studyId, attrName, attrValue, mode = :insert)
      retVal = nil

      # Test for uniqueness of attribute to be inserted
      attrNameExists = dbu.selectStudyAttrNameByName(attrName)
      nameId = valId = nil
      if(attrNameExists.nil? or attrNameExists.empty?)
        nameInsert = dbu.insertStudyAttrName(attrName)
        nameId = dbu.getLastInsertId(:userDB)
      else
        nameId = attrNameExists.first['id']
      end

      # Test for uniqueness of value to be inserted
      attrValExists = dbu.selectStudyAttrValueByValue(attrValue)
      if(attrValExists.nil? or attrValExists.empty?)
        attrValInsert = dbu.insertStudyAttrValue(attrValue)
        valId = dbu.getLastInsertId(:userDB)
      else
        valId = attrValExists.first['id']
      end

      # Create the AVP link using the study2attribute table
      if(studyId and nameId and valId)
        if(mode == :update)
          retval = dbu.updateStudy2AttributeForStudyAndAttrName(studyId, nameId, valId)
        else
          retVal = dbu.insertStudy2Attribute(studyId, nameId, valId)
        end
      end

      return retVal
    end
  end
end ; end ; end ; end 
