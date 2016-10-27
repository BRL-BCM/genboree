require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# RESOURCE LIST RELATED TABLES
# - DBUtil Extension Methods for dealing with entity-resource-list tables
# - Because the individual entity-specific resource list tables are all
#   the same, this extension code takes a generic approach where
#   the entity type is passed in.
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # ############################################################################
  # CONSTANTS
  # ############################################################################

  # ############################################################################
  # GENERIC METHODS - these build correct SQL based on entityTableName (like generics in DbUtil)
  # ############################################################################

  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  #                     - note: "mixed" is an addition ~entity, although there are no specific entity tables for it
  # [+tableType+]       [optional; default=:userDB] A flag indicating which database handle to use. Important to provide if doing main-genboree top-level enitities! One of these +Symbols+: :userDB, :mainDB, :otherDB
  # [+returns+]         Array of 0+ rows of unique names of resources lists of the given type
  def selectResourceListNames(entityTableName, tableType=:userDB)
    retVal = singularName = nil
    # Make singular name
    singularName = DBUtil.makeSingularTableName(entityTableName)
    return selectDistinctValues(tableType, "#{singularName}ResourceList", "name", "ERROR: [#{File.basename(__FILE__)}] DBUtil##{__method__}()")
  end

  # [+entityTableName+] Name of the entity table to count list names in. Assumed to be a proper pluralized name.
  #                     - note: "mixed" is an addition ~entity, although there are no specific entity tables for it
  # [+tableType+]       [optional; default=:userDB] A flag indicating which database handle to use. Important to provide if doing main-genboree top-level enitities! One of these +Symbols+: :userDB, :mainDB, :otherDB
  # [+returns+]         Single row with the 'count' of the number of lists of the indicated type.
  def countResourceListNames(entityTableName, tableType=:userDB)
    retVal = singularName = nil
    # Make singular name
    singularName = DBUtil.makeSingularTableName(entityTableName)
    return countDistinctValues(tableType, "#{singularName}ResourceList", "name", "ERROR: [#{File.basename(__FILE__)}] DBUtil##{__method__}()")
  end

  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  #                     - note: "mixed" is an addition ~entity, although there are no specific entity tables for it
  # [+name+]            Array of 1+ names of the resource list containing entities of type entityTableName
  # [+tableType+]       [optional; default=:userDB] A flag indicating which database handle to use. Important to provide if doing main-genboree top-level enitities! One of these +Symbols+: :userDB, :mainDB, :otherDB
  # [+returns+]         Array of 0+ rows of resource URLs in the named list(s)
  def selectResourceListUrlsByNames(entityTableName, names, tableType=:userDB)
    retVal = singularName = nil
    names = [ names ] unless(names.is_a?(Array))
    # Make singular name
    singularName = DBUtil.makeSingularTableName(entityTableName)
    return selectFieldsByFieldWithMultipleValues(tableType, "#{singularName}ResourceList", ["url"], true, "name", names, "ERROR: [#{File.basename(__FILE__)}] DBUtil##{__method__}()")
  end

  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  #                     - note: "mixed" is an addition ~entity, although there are no specific entity tables for it
  # [+name+]            Array of 1+ names of the resource list containing entities of type entityTableName
  # [+tableType+]       [optional; default=:userDB] A flag indicating which database handle to use. Important to provide if doing main-genboree top-level enitities! One of these +Symbols+: :userDB, :mainDB, :otherDB
  # [+returns+]         Array of 0+ rows of resource URLs in the named list(s)
  def countResourceListUrlsByNames(entityTableName, names, tableType=:userDB)
    retVal = singularName = nil
    names = [ names ] unless(names.is_a?(Array))
    # Make singular name
    singularName = DBUtil.makeSingularTableName(entityTableName)
    return countByFieldWithMultipleValues(tableType, "#{singularName}ResourceList", "url", names, "ERROR: [#{File.basename(__FILE__)}] DBUtil##{__method__}()")
  end

  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  #                     - note: "mixed" is an addition ~entity, although there are no specific entity tables for it
  # [+name+]            Name of resource list of type entityTableName into which to add the URLs.
  # [+urls+]            Array of resource URLs of type entityTableName
  # [+tableType+]       [optional; default=:userDB] A flag indicating which database handle to use. Important to provide if doing main-genboree top-level enitities! One of these +Symbols+: :userDB, :mainDB, :otherDB
  # [+returns+]         Num rows updated
  def insertResourceListUrls(entityTableName, name, urls, tableType=:userDB)
    retVal = singularName = nil
    # Make singular name
    singularName = DBUtil.makeSingularTableName(entityTableName)
    # Make data records to insert
    data = urls.map { |url| [ name, url] }
    return insertRecords(tableType, "#{singularName}ResourceList", data, true, urls.size, 2, true, "ERROR: [#{File.basename(__FILE__)}] DBUtil##{__method__}()")
  end

  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  #                     - note: "mixed" is an addition ~entity, although there are no specific entity tables for it
  # [+name+]            Array of 1+ names of the resource lists of type entityTableName to delete.
  # [+tableType+]       [optional; default=:userDB] A flag indicating which database handle to use. Important to provide if doing main-genboree top-level enitities! One of these +Symbols+: :userDB, :mainDB, :otherDB
  # [+returns+]         Num rows deleted
  def deleteResourceListsByNames(entityTableName, names, tableType=:userDB)
    retVal = singularName = nil
    names = [ names ] unless(names.is_a?(Array))
    # Make singular name
    singularName = DBUtil.makeSingularTableName(entityTableName)
    return deleteByFieldWithMultipleValues(tableType, "#{singularName}ResourceList", "name", names, "ERROR: [#{File.basename(__FILE__)}] DBUtil##{__method__}()")
  end

  # [+entityTableName+] Name of the entity table to select from. Assumed to be a proper pluralized name.
  #                     - note: "mixed" is an addition ~entity, although there are no specific entity tables for it
  # [+name+]            Name of resource list of type entityTableName from which to remove URLs
  # [+urls+]            The URLs to remove (must be unique in first 512 bytes; every URL with same 512 bytes will be removed)
  # [+tableType+]       [optional; default=:userDB] A flag indicating which database handle to use. Important to provide if doing main-genboree top-level enitities! One of these +Symbols+: :userDB, :mainDB, :otherDB
  # [+returns+]         Num rows deleted
  def deleteResourceListUrls(entityTableName, name, urls, tableType=:userDB)
    retVal = singularName = nil
    # Make singular name
    singularName = DBUtil.makeSingularTableName(entityTableName)
    # TODO: make some single batch version so this not O(numUrls) but rather just O(1)
    # Loop over each url and compose appropriate multi-filed delete
    countDeleted = 0
    urls.each { |url|
      whereData = {
        "name" => name,
        "url"  => url
      }
      numDeleted = deleteByMultipleFieldsAndValues(tableType, "#{singularName}ResourceList", whereData, :and, "ERROR: [#{File.basename(__FILE__)}] DBUtil##{__method__}()")
      countDeleted += numDeleted if(numDeleted and numDeleted >= 0)
    }
    return countDeleted
  end

  # [+entityTableName+] Name of the entity table to rename. Assumed to be a proper pluralized name.
  #                     - note: "mixed" is an addition ~entity, although there are no specific entity tables for it
  # [+name+]            Original name of the entity list
  # [+newName+]         New name of the entity list
  # [+tableType+]       [optional; default=:userDB] A flag indicating which database handle to use. Important to provide if doing main-genboree top-level enitities! One of these +Symbols+: :userDB, :mainDB, :otherDB
  # [+returns+]         Num rows updated
  def renameResourceList(entityTableName, name, newName, tableType=:userDB)
    retVal = singularName = nil
    # Make singular name
    singularName = DBUtil.makeSingularTableName(entityTableName)
    setData = {
                "name" => "#{newName}"
              }
    numRenamed = updateByFieldAndValue(tableType, "#{singularName}ResourceList", setData, 'name', name, "ERROR: [#{File.basename(__FILE__)}] DBUtil##{__method__}()")
    return numRenamed
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
