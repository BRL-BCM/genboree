#!/usr/bin/env ruby

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++
  # Experiment - this module defines helper methods related to experiments, intended
  # to be used as a mix-in.
  module Experiment

    # This method returns true/false depending on whether a experiment already
    # exists within Genboree.  NOTE: you must have already selected a DataDB on
    # this DBUtil instance prior to calling this method or it will fail.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+experimentName+] Name of the experiment to query for
    # [+returns+] +true+ if an experiment by this name already exists in this database
    def experimentExists(dbu, experimentName)
      retval = false
      row = dbu.selectExperimentByName(experimentName)
      unless(row.nil? or row.empty?)
        retval = true
      end
      return retval
    end

    # This method fetches all key-value pairs from the associated +experiment+
    # AVP tables.  Experiment is specified by experiment id.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+experimentId+] DB id of the experiment to query AVPs for.
    # [+returns+] A +Hash+ of the AVP pairs associated with this experiment.
    def getAvpHash(dbu, experimentId)
      retVal = {}
      experiment2attrRows = dbu.selectExperiment2AttributesByExperimentId(experimentId)
      unless(experiment2attrRows.nil? or experiment2attrRows.empty?)
        experiment2attrRows.each{|row|
          keyRows = dbu.selectExperimentAttrNameById(row['experimentAttrName_id'])
          key = keyRows.first['name'] unless (keyRows.nil? or keyRows.empty?)
          valueRows = dbu.selectExperimentAttrValueById(row['experimentAttrValue_id'])
          value = valueRows.first['value'] unless (valueRows.nil? or valueRows.empty?)
          retVal[key] = value
        }
      end

      return retVal
    end
    
    # This method completely updates all of the associated AVP pairs for
    # the specified +experiment+.  This method examines existing AVPs and changes
    # values as appropriate, but also looks for any pairs that exist in the
    # DB but not the new +Hash+, and removes those relationships, making it
    # possible to delete AVP pairs by removing them from the +Hash+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+experimentId+] DB Id of the +experiment+ for which to update the AVPs.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +experiment+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def updateAvpHash(dbu, experimentId, newHash)
      retVal = true

      newHash = {} if(newHash.nil?)
      begin
        oldHash = getAvpHash(dbu, experimentId)
        if(oldHash.nil? or oldHash.empty?)
          # AVP hash didn't exist before, insert all keys and values
          newHash.each { |attrName,attrValue|
            insertAvp(dbu, experimentId, attrName, attrValue)
          }
        else
          # AVP hash exists, check all key/value pairs for changes
          oldHash.each { |oldKey, oldVal|
            if(newHash.include?(oldKey))
              if(newHash[oldKey] != oldVal)
                rowsUpdated = insertAvp(dbu, experimentId, oldKey, newHash[oldKey], :update)
              end
              newHash.delete(oldKey)
            else
              keyRow = dbu.selectExperimentAttrNameByName(oldKey)
              key = keyRow.first
              rowsDeleted = dbu.deleteExperiment2AttributesByExperimentIdAndAttrNameId(experimentId, key['id'])
            end
          }
          # All remaining values in newHash will be insertions
          newHash.each { |newKey, newVal|
            insertAvp(dbu, experimentId, newKey, newVal)
          }
        end
      rescue => e
        dbu.logDbError("ERROR: Unknown DB error occurred during BRL::Abstract::Resources::Experiment.updateAvpHash()", e)
        retVal = false
      end
      
      return retVal
    end

    # This method inserts a new AVP pairing into the +experiment+ associated AVP tables.
    # You can also update an existing relationship between a +experiment+ and a
    # +experimentAttrName+ by setting the +mode+ parameter to the symbol +:update+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+experimentId+] DB Id of the +experiment+ for which to associate with this AVP.
    # [+attrName+] A +String+ of the attribute name to use.
    # [+attrValue+] A +String+ of the attibute value to use.
    # [+mode+] A symbol of either +:insert+ or +:update+ to set the mode to use.
    # [+returns+] Number of rows affected in the DB.  +1+ when successful, +0+ when not.
    def insertAvp(dbu, experimentId, attrName, attrValue, mode = :insert)
      retVal = nil

      # Test for uniqueness of attribute to be inserted
      attrNameExists = dbu.selectExperimentAttrNameByName(attrName)
      nameId = valId = nil
      if(attrNameExists.nil? or attrNameExists.empty?)
        nameInsert = dbu.insertExperimentAttrName(attrName)
        nameId = dbu.getLastInsertId(:userDB)
      else
        nameId = attrNameExists.first['id']
      end

      # Test for uniqueness of value to be inserted
      attrValExists = dbu.selectExperimentAttrValueByValue(attrValue)
      if(attrValExists.nil? or attrValExists.empty?)
        attrValInsert = dbu.insertExperimentAttrValue(attrValue)
        valId = dbu.getLastInsertId(:userDB)
      else
        valId = attrValExists.first['id']
      end

      # Create the AVP link using the experiment2attribute table
      if(experimentId and nameId and valId)
        if(mode == :update)
          retval = dbu.updateExperiment2AttributeForExperimentAndAttrName(experimentId, nameId, valId)
        else
          retVal = dbu.insertExperiment2Attribute(experimentId, nameId, valId)
        end
      end

      return retVal
    end
  end
end ; end ; end ; end 
