#!/usr/bin/env ruby
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/helpers/sniffer'
require 'brl/util/util'

module BRL ; module Util

#############################################################################
# This class is used to convert text to unix format from dos and/or mac
#
# Usage:
# require 'brl/util/convertText'
# convertObj = BRL::Util::ConvertText.new(fullPathToFileToConvert)
# convertObj.convertText(:all2unix)
# fullPathToConvertedFile = convertObj.convertedFileName
#
# Notes:
# The convertText method can take any ONE of these 3 arguments: :all2unix, :mac2unix, :dos2unix
# :all2unix (default)- Will first run dos2unix followed by mac2unix
# :mac2unix - Will only run mac2unix
# :dos2unix - Will only run dos2unix
# The resulting file will ALWAYS have an extension: .2unix regardless of the type of conversion
#############################################################################
class ConvertText

  # The absolute path to the converted file
  attr_accessor :convertedFileName

  # The path to the file to be converted
  attr_accessor :uncovertedFileName

  # status Obj
  attr_accessor :statusObj

  # Transform character encoding to ASCII if not so
  attr_accessor :transformEncoding
  
  # [+Constructor+]
  # [+fileName+]  string: Full path to the file to be converted
  # [+replaceOrig+] replace the original file with the final file
  def initialize(fileName, replaceOrig=false)
    raise ArgumentError, "File: #{fileName} does not exist.", caller if(!File.exists?(fileName))
    @convertedFileName = nil
    @statusObj = nil
    # make file name command line safe
    @dirName = File.dirname(fileName)
    escapedDirName = Shellwords.escape(@dirName)
    safeFileName = File.makeSafeSymlink(fileName, escapedDirName)
    @unconvertedFileName = safeFileName
    @replaceOrig = replaceOrig
    @transformEncoding = false
  end

  # Converts @unconvertedFileName to unix format by converting the character set encoding with iconv
  #   or by converting the line endings of non-binary bioinformatic file types detected by the sniffer
  # @param convertCmd [:all2unix, :dos2unix, :mac2unix] the command to use to convert line endings
  # @return [nil]
  # @raise [RuntimeError] error if conversion with iconv fails or is not attempted due to anticipated failure
  def convertText(convertCmd=:all2unix)
    begin
      snifferObj = BRL::Genboree::Helpers::Sniffer.new(@unconvertedFileName)
      format = snifferObj.autoDetect()
      if(@transformEncoding)
        # First check if the file is ASCII (rather than a more specific file type) according to the Sniffer
        isAscii = snifferObj.detect?('ascii')
        unless(isAscii)
          # if not, is the format encoded in a supported format that can be *safely* converted to ASCII
          if(format and BRL::Genboree::Helpers::Sniffer::ASCII_CONVERTIBLE_FORMATS.key?(format))
            if(format == 'UTF')
              formatExtractRegExp = /(?:UTF-\S+)/
              fileStdOut = `file #{@unconvertedFileName}`                
              format = fileStdOut.scan(formatExtractRegExp)[0]
            end
            `iconv -f #{format} -t ASCII #{@unconvertedFileName} > #{@unconvertedFileName}.ASCII; mv #{@unconvertedFileName}.ASCII #{@unconvertedFileName}`
            if($?.exitstatus == 0)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully converted #{@unconvertedFileName} (#{format}) to ASCII") 
            else
              raise "FATAL: Could not convert #{@unconvertedFileName} (#{format}) to ASCII"
            end
          else
            raise "FATAL: #{File.basename(@unconvertedFileName)} (#{format.inspect}) is not in the list of supported formats that can be safely transformed to ASCII. Exiting."
          end
        end
      end
      unless(format.nil?)
        # then sniffer was able to find which format this is
        formatStruct = snifferObj.getFormatConf(format)
        if(formatStruct.ascii)
          # then format is amenable to line ending conversion
          @convertedFileName = self.send(convertCmd, @unconvertedFileName)
        end
      else
        # the sniffer could not determine the file format, probably a false positive for some format not in the conf
        # try the convert command anyway
        @convertedFileName = self.send(convertCmd, @unconvertedFileName)
      end
    rescue => err
      raise err
    end
    if(@replaceOrig)
      # follow the symbolic link created and escape the resulting potentially mv-command-unsafe file name
      unescapedName = ((File.symlink?(@unconvertedFileName)) ? File.readlink(@unconvertedFileName) : @unconvertedFileName)
      escapedName = Shellwords.escape(unescapedName)
      `mv #{@convertedFileName} #{escapedName}`
    end
    # regardless, remove the link now that we are done
    `rm -f #{@unconvertedFileName}` if(File.symlink?(@unconvertedFileName))
  end

  # [+uncovertedFileName+] file to be converted to unix format
  def all2unix(uncovertedFileName)
    dos2unixFile = dos2unix(uncovertedFileName)
    mac2unixFile = mac2unix(dos2unixFile, false)
    return mac2unixFile
  end

  # [+uncovertedFileName+] file to be converted to unix format
  # [+return+] dos2unixFile
  def dos2unix(uncovertedFileName)
    cmd = "dos2unix -n #{uncovertedFileName} #{uncovertedFileName}.2unix"
    exitStatus = system(cmd)
    @statusObj = $?.dup()
    raise "dos2unix failed with exitstatus:#{@statusObj.inspect}\nCommand: #{cmd.inspect}" if(!exitStatus)
    dos2unixFile = "#{uncovertedFileName}.2unix"
    return dos2unixFile
  end

  # [+uncovertedFileName+] file to be converted to unix format
  # [fileExt] true or false
  # [+return+] mac2unixFile
  def mac2unix(uncovertedFileName, fileExt=true)
    if(fileExt)
      cmd = "mac2unix -n #{uncovertedFileName} #{uncovertedFileName}.2unix"
    else
      cmd = "mac2unix #{uncovertedFileName}"
    end
    exitStatus = system(cmd)
    @statusObj = $?.dup()
    raise "mac2unix failed with exitstatus:#{@statusObj.inspect}\nCommand: #{cmd.inspect}" if(!exitStatus)
    mac2unixFile = ""
    if(fileExt)
      mac2unixFile = "#{uncovertedFileName}.2unix"
    else
      mac2unixFile = uncovertedFileName
    end
    return mac2unixFile
  end


end

end ; end
