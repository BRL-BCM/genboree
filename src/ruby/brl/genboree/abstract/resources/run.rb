#!/usr/bin/env ruby

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++
  # Run - this module defines helper methods related to runs, intended
  # to be used as a mix-in.
  module Run

    # This method returns true/false depending on whether a run already
    # exists within Genboree.  NOTE: you must have already selected a DataDB on
    # this DBUtil instance prior to calling this method or it will fail.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+runName+] Name of the run to query for
    # [+returns+] +true+ if an run by this name already exists in this database
    def runExists(dbu, runName)
      retval = false
      row = dbu.selectRunByName(runName)
      unless(row.nil? or row.empty?)
        retval = true
      end
      return retval
    end

    # This method fetches all key-value pairs from the associated +run+
    # AVP tables.  Run is specified by run id.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+runId+] DB id of the run to query AVPs for.
    # [+returns+] A +Hash+ of the AVP pairs associated with this run.
    def getAvpHash(dbu, runId)
      retVal = {}
      run2attrRows = dbu.selectRun2AttributesByRunId(runId)
      unless(run2attrRows.nil? or run2attrRows.empty?)
        run2attrRows.each{|row|
          keyRows = dbu.selectRunAttrNameById(row['runAttrName_id'])
          key = keyRows.first['name'] unless (keyRows.nil? or keyRows.empty?)
          valueRows = dbu.selectRunAttrValueById(row['runAttrValue_id'])
          value = valueRows.first['value'] unless (valueRows.nil? or valueRows.empty?)
          retVal[key] = value
        }
      end

      return retVal
    end
    
    # This method completely updates all of the associated AVP pairs for
    # the specified +run+.  This method examines existing AVPs and changes
    # values as appropriate, but also looks for any pairs that exist in the
    # DB but not the new +Hash+, and removes those relationships, making it
    # possible to delete AVP pairs by removing them from the +Hash+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+runId+] DB Id of the +run+ for which to update the AVPs.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +run+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def updateAvpHash(dbu, runId, newHash)
      retVal = true

      newHash = {} if(newHash.nil?)
      begin
        oldHash = getAvpHash(dbu, runId)
        if(oldHash.nil? or oldHash.empty?)
          # AVP hash didn't exist before, insert all keys and values
          newHash.each { |attrName,attrValue|
            insertAvp(dbu, runId, attrName, attrValue)
          }
        else
          # AVP hash exists, check all key/value pairs for changes
          oldHash.each { |oldKey, oldVal|
            if(newHash.include?(oldKey))
              if(newHash[oldKey] != oldVal)
                rowsUpdated = insertAvp(dbu, runId, oldKey, newHash[oldKey], :update)
              end
              newHash.delete(oldKey)
            else
              keyRow = dbu.selectRunAttrNameByName(oldKey)
              key = keyRow.first
              rowsDeleted = dbu.deleteRun2AttributesByRunIdAndAttrNameId(runId, key['id'])
            end
          }
          # All remaining values in newHash will be insertions
          newHash.each { |newKey, newVal|
            insertAvp(dbu, runId, newKey, newVal)
          }
        end
      rescue => e
        dbu.logDbError("ERROR: Unknown DB error occurred during BRL::Abstract::Resources::Run.updateAvpHash()", e)
        retVal = false
      end
      
      return retVal
    end

    # This method inserts a new AVP pairing into the +run+ associated AVP tables.
    # You can also update an existing relationship between a +run+ and a
    # +runAttrName+ by setting the +mode+ parameter to the symbol +:update+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+runId+] DB Id of the +run+ for which to associate with this AVP.
    # [+attrName+] A +String+ of the attribute name to use.
    # [+attrValue+] A +String+ of the attibute value to use.
    # [+mode+] A symbol of either +:insert+ or +:update+ to set the mode to use.
    # [+returns+] Number of rows affected in the DB.  +1+ when successful, +0+ when not.
    def insertAvp(dbu, runId, attrName, attrValue, mode = :insert)
      retVal = nil

      # Test for uniqueness of attribute to be inserted
      attrNameExists = dbu.selectRunAttrNameByName(attrName)
      nameId = valId = nil
      if(attrNameExists.nil? or attrNameExists.empty?)
        nameInsert = dbu.insertRunAttrName(attrName)
        nameId = dbu.getLastInsertId(:userDB)
      else
        nameId = attrNameExists.first['id']
      end

      # Test for uniqueness of value to be inserted
      attrValExists = dbu.selectRunAttrValueByValue(attrValue)
      if(attrValExists.nil? or attrValExists.empty?)
        attrValInsert = dbu.insertRunAttrValue(attrValue)
        valId = dbu.getLastInsertId(:userDB)
      else
        valId = attrValExists.first['id']
      end

      # Create the AVP link using the run2attribute table
      if(runId and nameId and valId)
        if(mode == :update)
          retval = dbu.updateRun2AttributeForRunAndAttrName(runId, nameId, valId)
        else
          retVal = dbu.insertRun2Attribute(runId, nameId, valId)
        end
      end

      return retVal
    end
  end
end ; end ; end ; end 
