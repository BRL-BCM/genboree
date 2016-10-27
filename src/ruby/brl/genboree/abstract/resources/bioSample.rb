#!/usr/bin/env ruby

#--
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
  # BioSample - this module defines helper methods related to studies, intended
  # to be used as a mix-in.
  module BioSample

    # This method returns true/false depending on whether a bioSample already
    # exists within Genboree.  NOTE: you must have already selected a DataDB on
    # this DBUtil instance prior to calling this method or it will fail.
    #
    # @param dbu [DBUtil] instance of +DBUtil+, ready to do DB work.
    # @param bioSampleName [String] name of the bioSample to query for
    # @return +true+ if a bioSample by this name already exists in this database
    def bioSampleExists(dbu, bioSampleName)
      retval = false
      row = dbu.selectBioSampleByName(bioSampleName)
      unless(row.nil? or row.empty?)
        retval = true
      end
      return retval
    end

    # This method fetches all key-value pairs from the associated +bioSample+
    # AVP tables.  BioSample is specified by bioSample id.
    #
    # @param dbu [DBUtil] Instance of +DBUtil+, ready to do DB work.
    # @param bioSampleId [Integer] DB Id of the +bioSample+ to query AVPs for.
    # @return [Hash] the AVP pairs associated with this +bioSample+
    def getAvpHash(dbu, bioSampleId)
      retVal = {}
      bioSample2attrRows = dbu.selectBioSample2AttributesByBioSampleId(bioSampleId)
      unless(bioSample2attrRows.nil? or bioSample2attrRows.empty?)
        bioSample2attrRows.each{|row|
          keyRows = dbu.selectBioSampleAttrNameById(row['bioSampleAttrName_id'])
          key = keyRows.first['name'] unless (keyRows.nil? or keyRows.empty?)
          valueRows = dbu.selectBioSampleAttrValueById(row['bioSampleAttrValue_id'])
          value = valueRows.first['value'] unless (valueRows.nil? or valueRows.empty?)
          retVal[key] = value
        }
      end

      return retVal
    end

    # Insert bioSample AVPs based on the mode
    #
    # @param dbu [DBUtil] Instance of +DBUtil+, ready to do DB work.
    # @param bioSampleId [Integer] DB Id of the +bioSample+ to query AVPs for.
    # @param newHash [Hash] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +bioSample+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # @param mode [:merge, :replace, :keep]
    #   :merge will merge in new attributes and update existing attributes
    #   :replace will delete all existing AVPs and insert the new ones
    #   :keep will merge in new attributes but not update existing attributes
    # @return [Boolean] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def insertAvpHash(dbu, bioSampleId, newHash, mode=:merge)
      retVal = true
      begin
        oldHash = getAvpHash(dbu, bioSampleId)
        if(oldHash.nil? or oldHash.empty?)
          # AVP hash didn't exist before, insert all keys and values
          newHash.each { |attrName,attrValue|
            insertAvp(dbu, bioSampleId, attrName, attrValue)
          }
        else
          # AVP hash exists, check all key/value pairs for changes
          oldHash.each { |oldKey, oldVal|
            if(newHash.include?(oldKey))
              if(newHash[oldKey] != oldVal)
                if(mode == :merge or mode == :replace)
                  # then update existing attributes
                  rowsUpdated = insertAvp(dbu, bioSampleId, oldKey, newHash[oldKey], :update)
                end
              end
              # remove already updated attributes from our working list
              newHash.delete(oldKey)
            else
              if(mode == :replace)
                # then delete attributes not mentioned in the newHash
                keyRow = dbu.selectBioSampleAttrNameByName(oldKey)
                key = keyRow.first
                rowsDeleted = dbu.deleteBioSample2AttributesByBioSampleIdAndAttrNameId(bioSampleId, key['id'])
              end
            end
          }
          # All remaining values in newHash will be insertions
          newHash.each { |newKey, newVal|
            insertAvp(dbu, bioSampleId, newKey, newVal)
          }
        end
      rescue => e
        dbu.logDbError("ERROR: Unknown DB error occurred during BRL::Abstract::Resources::BioSample.insertAvpHash()", e)
        retVal = false
      end

      return retVal
    end

    # Insert or update an AVP associated with the bioSample given by bioSampleId
    #
    # @param dbu [DBUtil] instance of +DBUtil+, ready to do DB work.
    # @param bioSampleId [Integer] id of the bioSample to query AVPs for
    # @param attrName [String] attribute name to query for id or insert if new 
    # @param attrValue [String] attribute value to query for id or insert if new
    # @param mode [Symbol] use :update if set, otherwise MySQL :insert statement executed
    # @return [Integer] number of rows inserted or updated
    def insertAvp(dbu, bioSampleId, attrName, attrValue, mode = :insert)
      retVal = nil

      # Test for uniqueness of attribute to be inserted
      attrNameExists = dbu.selectBioSampleAttrNameByName(attrName)
      nameId = valId = nil
      if(attrNameExists.nil? or attrNameExists.empty?)
        nameInsert = dbu.insertBioSampleAttrName(attrName)
        nameId = dbu.getLastInsertId(:userDB)
      else
        nameId = attrNameExists.first['id']
      end

      # Test for uniqueness of value to be inserted
      attrValExists = dbu.selectBioSampleAttrValueByValue(attrValue)
      if(attrValExists.nil? or attrValExists.empty?)
        attrValInsert = dbu.insertBioSampleAttrValue(attrValue)
        valId = dbu.getLastInsertId(:userDB)
      else
        valId = attrValExists.first['id']
      end

      # Create the AVP link using the bioSample2attribute table
      if(bioSampleId and nameId and valId)
        if(mode == :update)
          retval = dbu.updateBioSample2AttributeForBioSampleAndAttrName(bioSampleId, nameId, valId)
        else
          retVal = dbu.insertBioSample2Attribute(bioSampleId, nameId, valId)
        end
      end

      return retVal
    end

    # Insert, update, or replace a BioSample and its AVPs
    #
    # @param dbu [BRL::Genboree::DBUtil] DBUtil object already connected to user database
    # @param bioSampleEntity [BRL::Genboree::REST::Data::BioSampleEntity]
    # @param mode [Symbol] supported symbols:
    #   :keep - if bioSampleEntity.name already exists in the database, dont update its representation and dont update
    #     its AVPs
    #   :replace - if bioSampleEntity.name already exists in the database, replace it with the given bioSampleEntity
    #   :merge - if bioSampleEntity.name already exists in the database, update its representation and merge in
    #     bioSampleEntity.avpHash to its AVPs
    # @note :create mode is not supported for singular bioSample
    def insertBioSampleAndAvpHash(dbu, bioSampleEntity, mode=:merge)
      # first, find out if this bioSample already exists
      sampleRecs = dbu.selectBioSampleByName(bioSampleEntity.name)
      if(sampleRecs.nil?)
        # then something went wrong with the query
        raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", 
                                               "Failed attempting to retrieve #{bioSampleEntity.name} from the database!")
      elsif(sampleRecs.empty?)
        # then sample doesnt exist, insert it
        dbu.insertBioSample(bioSampleEntity.name, bioSampleEntity.type, bioSampleEntity.biomaterialState, 
                            bioSampleEntity.biomaterialProvider, bioSampleEntity.biomaterialSource, bioSampleEntity.state)
        bioSampleId = dbu.lastInsertId
        insertAvpHash(dbu, bioSampleId, bioSampleEntity.avpHash, :merge)
      else
        # then sample does exist, do what mode says
        bioSampleId = sampleRecs.first['id']
        if(mode == :keep)
          # dont do anything
        elsif(mode == :replace)
          # delete then insert
          dbu.deleteBioSampleById(bioSampleId)
          dbu.insertBioSample(bioSampleEntity.name, bioSampleEntity.type, bioSampleEntity.biomaterialState, 
                              bioSampleEntity.biomaterialProvider, bioSampleEntity.biomaterialSource, bioSampleEntity.state)

          # do the same for the AVPs
          insertAvpHash(dbu, bioSampleId, bioSampleEntity.avpHash, :replace)
        else
          # default mode == :merge
          dbu.updateBioSampleById(bioSampleId, bioSampleEntity.name, bioSampleEntity.type, bioSampleEntity.biomaterialState, 
                                  bioSampleEntity.biomaterialProvider, bioSampleEntity.biomaterialSource, bioSampleEntity.state)
          insertAvpHash(dbu, bioSampleId, bioSampleEntity.avpHash, :merge)
        end
      end
    end

  end
end ; end ; end ; end
