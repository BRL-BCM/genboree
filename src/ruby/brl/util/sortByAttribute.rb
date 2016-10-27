#!/usr/bin/env ruby
# Author: Sameer Paithankar

# Load required libraries
require 'brl/util/textFileUtil'

module BRL; module Genboree; module Helpers

#############################################################################
# This class is implemented to sort a lff file by one of the attributes in the Attribute-Value Pair (AVP) list.
#
# Usage:
# sortObj = BRL::Genboree::Helpers::SortByAttribute.new(pathToUnsortedFile, attributeName)
# sortObj.sortByAtt()
# fullPathToSortedFile = sortObj.sortedFile
#
# Notes:
#  - Assumes the file is validated.
#  - Assumes that the file is uncompressed
#  - Assumes file is of unix format
#############################################################################
class SortByAttribute
  
  # Full path to unsorted/input file 
  attr_accessor :fileName
  
  # Full Path to sorted/output file
  attr_accessor :sortedFile
  
  # Name of the attribute to be used for sorting
  attr_accessor :attributeName
  # ############################################################################
  # METHODS
  # ############################################################################
  # Constructor
  # [+pathToUnsortedFile+]
  # [+attributeName+]
  # [+returns+] nil
  def initialize(pathToUnsortedFile, attributeName)
    @fileName = pathToUnsortedFile
    @sortedFile = nil
    @attributeName = attributeName
    # Make sure we have genuine values
    raise ArgumentError, "File: #{@fileName} does not exist.", caller if(!File.exists?(@fileName))
    raise ArgumentError, "attributeName: #{@attributeName.inspect} empty or nil." if(@attributeName.nil? or @attributeName.empty?)
    # Get workingDir
    @workingDir = File.dirname(@fileName)
  end
  
  # Sorts the LFF by the requested attributeName:
  # First creates a temp file with the value for the desired attribute name being the first column in the temp file
  # Next, use unix sort to sort the temp file by the first column.
  # Lastly, remove the first column, thereby converting the temp file into a proper LFF file.
  # [+returns+] nil
  def sortByAtt()
    begin
      # First we make a temp file with the first column being the value we want to sort by:
      @reader = BRL::Util::TextReader.new(@fileName)
      attrRegExp = /#{@attributeName}\s*=\s*([^;\t\n]+)/
      timeStamp = Time.now.to_f
      tempFile = "#{@workingDir}/#{timeStamp}.temp.lff"
      tempSortedFile = "#{@workingDir}/#{timeStamp}.temp.sorted.lff"
      tmpWriter = File.open(tempFile, "w")
      @reader.each_line { |line|
        line.strip!
        next if(line.nil? or line.empty? or line =~ /^#/ or line =~ /^\s*$/)
        if(line =~ attrRegExp)
          tmpWriter.print("#{$1}\t#{line}\n")
        end
      }
      tmpWriter.close()
      @reader.close()
      # Next we run unix sort to sort by the first column of the temp file
      cmd = "sort -k1 #{tempFile} > #{tempSortedFile}"
      exitStatus = system(cmd)
      exitObj = $?.dup()
      raise "Sort Failed: #{cmd.inspect}.\nExitstatus: #{exitObj.inspect}" if(!exitStatus)
      # Finally remove the first column
      @sortedFile = "#{@workingDir}/sorted_#{File.basename(@fileName)}"
      @writer = File.open(@sortedFile, "w")
      @reader = File.open(tempSortedFile)
      @reader.each_line { |line|
        line.strip!
        next if(line.nil? or line.empty? or line =~ /^#/ or line =~ /^\s*$/)
        fields = line.split(/\t/)
        lffLine = ""
        fields.size.times { |ii|
          next if(ii == 0)
          lffLine << "#{fields[ii]}\t"
        }
        lffLine << "\n"
        @writer.print(lffLine)
      }
      @reader.close()
      @writer.close()
      # Remove unwanted file
      cmd = "rm #{tempFile} #{tempSortedFile}"
      exitStatus = system(cmd)
      exitObj = $?.dup()
      if(!exitStatus)
        $stderr.puts "rm cmd failed: #{rm.inspect}\nExitstaus: #{exitObj.inspect}"
      end
    rescue => err
      raise err
    end
  end
  


end
end; end; end
