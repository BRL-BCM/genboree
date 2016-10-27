#!/usr/bin/env ruby
require 'stringio'
require 'zlib'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'

#############################################################################
# Extend IO to compute Adler32 of contents via read() using CheckSumUtil class below.
#############################################################################
class IO
  CHUNK_FOR_ADLER32 = 8 * 1024 * 1000
  # Compute adler32 checksum of this object
  def adler32()
    chunk = ''
    # Initialize adler checksum
    adler32 = Zlib.adler32()
    while(read(CHUNK_FOR_ADLER32, chunk))
      adler32 = Zlib.adler32(chunk, adler32)
    end
    return adler32
  end
end

#############################################################################
# Extend File to compute Adler32 of contents via read() using CheckSumUtil class below.
#############################################################################
class File
  # Compute adler32 of File or file name
  def self.adler32(file)
    adler32 = nil
    if(file.is_a?(String) and File.exist?(file))
      File.open(file) { |fileObj|
        adler32 = fileObj.adler32()
      }
    elsif(file.is_a?(File))
      adler32 = file.adler32()
    else
      raise "FATAL ERROR: #{self.class}##{__method__}() file is not a File object nor a string pointing to an existing file." unless(ioObj.respond_to?(:read))
    end
    return adler32
  end

  # Ensure that file downloaded correctly with checksum and truncate file to remove checksum line
  # This method will read the checksum from the file, truncate it and then recompute the checksum
  # If the read and computed checksums do not match OR if the file has no checksum to begin with OR if the checksum cannot be computed, an error is thrown
  def self.verifyCheckSum(file)
    begin
      fileSum = BRL::Util::CheckSumUtil.stripAdler32(file,true)
      if(fileSum)  then fileSum = fileSum.to_i(16) # Hex to integer
        $stderr.debugPuts(__FILE__, __method__, "DEBUG","Checksum in file #{file}=#{fileSum.inspect}")
        if(fileSum) then
          calcSum = File.adler32(file)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG","Calculated Checksum for file #{file}=#{calcSum.inspect}")
          if(calcSum and calcSum==fileSum) then
            return true
          else
            return false
          end
        else
          return false
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR","No Checksum in file #{file}")
        return false
      end
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Unable to verify checksum for #{file}\n#{err.message}\n#{err.backtrace.join("\n")}")
      raise err
    end
  end
end

class String
  # Returns the Check sum value from the last line of this String object (if present)
  # [+returns+] adler32 check sum value or nil if not present
  def getAdler32CheckSum()
    retVal = nil
    begin
      # Test & extract
      retVal = (self[-22, self.size] =~ /\A#ADLER_32: (0x[0-9A-Fa-f]{8,8})\n\Z/ ? $1 : nil)
    rescue => err
      $stderr.puts err
    end
    return retVal
  end

  # Strips adler checksum value from this String object
  # [+returns+] A copy of this string, without the adler checksum
  def stripAdler32()
    retVal = self.dup
    adlerSum = self.getAdler32CheckSum()
    if(adlerSum)
      retVal.slice!(-22, retVal.size)
    end
    return retVal
  end

  # Strips adler checksum value from this String object (modify self!)
  # [+returns+] This string, without the adler checksum
  def stripAdler32!()
    adlerSum = self.getAdler32CheckSum()
    if(adlerSum)
      self.slice!(-22, self.size)
    end
    return self
  end

  # Checks if this String obj has an Adler checksum at the end
  # [+returns+] boolean
  def hasAdler?()
    retVal = (self[-22, self.size] =~ /\A#ADLER_32: (0x[0-9A-Fa-f]{8,8})\n\Z/ ? true : false)
    return retVal
  end
end

module BRL ; module Util

#############################################################################
# This class is used to do a check sums using the Adler32 algorithm provided by zlib
#############################################################################
class CheckSumUtil
  # Update the crc
  # [+str+]
  # [+currAdler32+]
  # [+returns] updated currAdler32
  def self.updateAdler32(str, currAdler32)
    return Zlib.adler32(str, currAdler32)
  end

  # returns line with the Adler32 check sum
  # The line looks like: '#ADLER_32: adlerValue'
  # [+adler32crc+]
  # [+returns+] line with Adler32 flag followed by the checksum value
  def self.getAdler32Str(adler32crc)
    adler32Str = ('%08x' % adler32crc)
    return  "#ADLER_32: 0x#{adler32Str}\n"
  end

  # Checks if a given String has an Adler checksum at the end
  # [+strBuffer+]
  # [+returns+] boolean
  def self.hasAdler?(strBuffer)
    return strBuffer.hasAdler?()
  end

  # Extracts the Check sum value from the last line of the file
  # [+fileName+]
  # [+returns+] adler32 check sum value or nil if not present
  def self.getAdler32CheckSum(fileName)
    retVal = nil
    begin
      # Open file for reading
      ff = File.open(fileName)
      # Seek to correct spot
      ff.seek(-22, IO::SEEK_END)
      # Get the adler string tag
      adler32str = ff.read
      ff.close
      # Test & extract
      retVal = adler32str =~ /\A#ADLER_32: (0x[0-9A-Fa-f]{8,8})\n\Z/ ? $1 : nil
    rescue => err
      $stderr.puts err
    end
    return retVal
  end

  # Strips the Adler32 line from the file
  # [+fileName+]
  # [+returnAdler+] Set to true to retrieve the adler32 checksum value. False by default
  def self.stripAdler32(fileName, returnAdler=false)
    retVal = false
    adlerSum = self.getAdler32CheckSum(fileName)
    if(adlerSum)
      File.truncate(fileName, File.size(fileName) - 22)
      if(returnAdler) then retVal = adlerSum else retVal = true end
    end
    return retVal
  end
end
end ; end
