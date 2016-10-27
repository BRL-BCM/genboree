#!/usr/bin/env ruby

# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++
  # Analysis - this module defines helper methods related to analyses, intended
  # to be used as a mix-in.
  module Analysis

    # This method returns true/false depending on whether a analysis already
    # exists within Genboree.  NOTE: you must have already selected a DataDB on
    # this DBUtil instance prior to calling this method or it will fail.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+analysisName+] Name of the analysis to query for
    # [+returns+] +true+ if an analysis by this name already exists in this database
    def analysisExists(dbu, analysisName)
      retval = false
      row = dbu.selectAnalysisByName(analysisName)
      unless(row.nil? or row.empty?)
        retval = true
      end
      return retval
    end

    # This method fetches all key-value pairs from the associated +analysis+
    # AVP tables.  Analysis is specified by analysis id.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+analysisId+] DB id of the analysis to query AVPs for.
    # [+returns+] A +Hash+ of the AVP pairs associated with this analysis.
    def getAvpHash(dbu, analysisId)
      retVal = {}
      analysis2attrRows = dbu.selectAnalysis2AttributesByAnalysisId(analysisId)
      unless(analysis2attrRows.nil? or analysis2attrRows.empty?)
        analysis2attrRows.each{|row|
          keyRows = dbu.selectAnalysisAttrNameById(row['analysisAttrName_id'])
          key = keyRows.first['name'] unless (keyRows.nil? or keyRows.empty?)
          valueRows = dbu.selectAnalysisAttrValueById(row['analysisAttrValue_id'])
          value = valueRows.first['value'] unless (valueRows.nil? or valueRows.empty?)
          retVal[key] = value
        }
      end
      return retVal
    end

    # This method completely updates all of the associated AVP pairs for
    # the specified +analysis+.  This method examines existing AVPs and changes
    # values as appropriate, but also looks for any pairs that exist in the
    # DB but not the new +Hash+, and removes those relationships, making it
    # possible to delete AVP pairs by removing them from the +Hash+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+analysisId+] DB Id of the +analysis+ for which to update the AVPs.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +analysis+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def updateAvpHash(dbu, analysisId, newHash)
      retVal = true

      newHash = {} if(newHash.nil?)
      begin
        oldHash = getAvpHash(dbu, analysisId)
        if(oldHash.nil? or oldHash.empty?)
          # AVP hash didn't exist before, insert all keys and values
          newHash.each { |attrName,attrValue|
            insertAvp(dbu, analysisId, attrName, attrValue)
          }
        else
          # AVP hash exists, check all key/value pairs for changes
          oldHash.each { |oldKey, oldVal|
            if(newHash.include?(oldKey))
              if(newHash[oldKey] != oldVal)
                rowsUpdated = insertAvp(dbu, analysisId, oldKey, newHash[oldKey], :update)
              end
              newHash.delete(oldKey)
            else
              keyRow = dbu.selectAnalysisAttrNameByName(oldKey)
              key = keyRow.first
              rowsDeleted = dbu.deleteAnalysis2AttributesByAnalysisIdAndAttrNameId(analysisId, key['id'])
            end
          }
          # All remaining values in newHash will be insertions
          newHash.each { |newKey, newVal|
            insertAvp(dbu, analysisId, newKey, newVal)
          }
        end
      rescue => e
        dbu.logDbError("ERROR: Unknown DB error occurred during BRL::Abstract::Resources::Analysis.updateAvpHash()", e)
        retVal = false
      end

      return retVal
    end

    # This method inserts a new AVP pairing into the +analysis+ associated AVP tables.
    # You can also update an existing relationship between a +analysis+ and a
    # +analysisAttrName+ by setting the +mode+ parameter to the symbol +:update+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+analysisId+] DB Id of the +analysis+ for which to associate with this AVP.
    # [+attrName+] A +String+ of the attribute name to use.
    # [+attrValue+] A +String+ of the attibute value to use.
    # [+mode+] A symbol of either +:insert+ or +:update+ to set the mode to use.
    # [+returns+] Number of rows affected in the DB.  +1+ when successful, +0+ when not.
    def insertAvp(dbu, analysisId, attrName, attrValue, mode = :insert)
      retVal = nil

      # Test for uniqueness of attribute to be inserted
      attrNameExists = dbu.selectAnalysisAttrNameByName(attrName)
      nameId = valId = nil
      if(attrNameExists.nil? or attrNameExists.empty?)
        nameInsert = dbu.insertAnalysisAttrName(attrName)
        nameId = dbu.getLastInsertId(:userDB)
      else
        nameId = attrNameExists.first['id']
      end

      # Test for uniqueness of value to be inserted
      attrValExists = dbu.selectAnalysisAttrValueByValue(attrValue)
      if(attrValExists.nil? or attrValExists.empty?)
        attrValInsert = dbu.insertAnalysisAttrValue(attrValue)
        valId = dbu.getLastInsertId(:userDB)
      else
        valId = attrValExists.first['id']
      end

      # Create the AVP link using the analysis2attribute table
      if(analysisId and nameId and valId)
        if(mode == :update)
          retval = dbu.updateAnalysis2AttributeForAnalysisAndAttrName(analysisId, nameId, valId)
        else
          retVal = dbu.insertAnalysis2Attribute(analysisId, nameId, valId)
        end
      end

      return retVal
    end
  end # Module Analysis (for mix-in)
end ; end ; end ; end
