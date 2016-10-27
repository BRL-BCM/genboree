#!/usr/bin/env ruby

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++

  # TabularLayout - this class implements behaviors related to saved TabularLayouts
  class TabularLayout

    # This method returns true/false depending on whether a layout name already
    # exists within Genboree.  NOTE: you must have already selected a DataDB on
    # this DBUtil instance prior to calling this method or it will fail.
    #
    # [+dbu+] Instance of DbUtil, ready to do DB work.
    # [+layoutName+] Name of a saved tabular layout.
    # [+returns+] +true+ if a layout by this name already exists in this database
    def self.layoutNameExists(dbu, layoutName)
      retVal = false
      row = dbu.getLayoutByName(layoutName)
      unless(row.nil? or row.empty?)
        retVal = true
      end
      return retVal
    end
  end # class TabularLayout
end ; end ; end ; end
