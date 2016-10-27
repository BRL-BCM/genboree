#!/usr/bin/env ruby

require "json"

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++

  # Query - this class implements behaviors related to saved Queries
  class Query
    # This method returns true/false depending on whether a query with the
    # name already exists in Genboree in the currently selected data database.
    # NOTE: you must have already selected a DataDB on  this DBUtil instance
    # prior to calling this method or it will fail.
    #
    # [+dbu+] Instance of DbUtil, ready to do DB work.
    # [+queryName+] Name of a saved query.
    # [+returns+] +true+ if a query by this name already exists in this database
    def self.queryExists(dbu, queryName)
      retVal = false
      row = dbu.getQueryByName(queryName)
      unless(row.nil? or row.empty?)
        retVal = true
      end
      return retVal
    end

    # [+dbu+] Instance of dbUtil.
    # [+name+] Name of the query you've got questions about.
    # [+returns+] "Shared" if the query is shared to the group, owner's user id if it's private
    def self.fetchQueryOwner(dbu, name)
      owner = nil
      rows = dbu.getQueryByName(name)
      unless(rows.nil? or rows.empty?)
        ownerRow = rows.first
        ownerName = (ownerRow['user_id']==-1)? "Shared" : ownerRow['user_id']
      end
      # Clean up
      rows.clear() unless(rows.nil?)
      return ownerName
    end
  end # class Query
end ; end ; end ; end # module BRL ; Genboree ; Abstract ; Resources
