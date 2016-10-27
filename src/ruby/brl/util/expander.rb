#!/usr/bin/env ruby
require 'find'
require 'pathname'
require 'open4'
require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'
require 'brl/util/sniffer'

module BRL ; module Util

#############################################################################
# This class is implemented to replace the Expander class from Java
# It is used to uncompress any type of compressed file
#
# Usage:
# expanderObj = Expander.new(fullPathToCompFile)
# expanderObj.extract()
# fullPathToUncompFile = expanderObj.uncompressedFileName
#
# Notes:
#  - If the file is already extracted, as in, it is not a compressed file,
#    then uncompressedFileName will be set to compressedFileName
#  - The compressed file remains on disk so it is up to you to clean it up.
#  - If the compressed file does not have the expected extension.  It will be appended.
#    and the uncompressed file will have the input name so be aware,
#    the compressed input file name becomes the uncompressed file name
#    and your compressed file gets renamed. ( See setFileNames() )
#############################################################################
class Expander
  FILE_TYPES = [ "text", "gzip", "bzip2", "Zip", "tar", "xz", "7-zip", "executable", "directory" ]
  UNIX_FILE_TYPES = [ "gzip", "bzip2", "Zip", "tar", "xz", "7-zip", "executable", "directory" ]    # Must be ~unique (eg keyword 'text' too likely in many file records)
  # 7-zip should be near last since it supports many compression types including gzip, zip, bzip2, tar, and others
  TYPE_ARRAY_ORDER = [ "Zip", "xz", "tar", "bzip2", "gzip", "7-zip" ] # Specific order for finding type
  QUICK_TEST_BY_TYPE = {
    'gzip'  => "gzip -l {fileName} > /dev/null 2> /dev/null",
    'Zip'   => "unzip -l {fileName} > /dev/null 2> /dev/null",
    'xz'    => "xz -l {fileName} > /dev/null 2> /dev/null",
    '7-zip'    => "7za t -t7z {fileName} > /dev/null 2> /dev/null",
    'tar'   => :unixFileCmd,
    'bzip2' => :unixFileCmd,
  }
  FALSE_POSITIVE_TYPE = {
    'gzip' => { "bam" => "file {fileName} | grep -P 'gzip.+extra\\sfield' > /dev/null 2> /dev/null" }
  }
  MULTIFILE_ARCHIVE_BY_TYPE = {
    'gzip'  => false,
    'Zip'   => true,
    'xz'    => false,
    'tar'   => true,
    'bzip2' => false,
    '7-zip' => true
  }
  MULTIFILE_ARCHIVE_BY_EXT = {
    'gz'  => false,
    'zip'   => true,
    'xz'    => false,
    'tar'   => true,
    'bz2' => false,
    '7z' => true
  }
  FILE_EXTS = { "text" => "", "gzip" => "gz", "bzip2" => "bz2", "Zip" => "zip", "zip" => "zip", 
                "tar" => "tar", "xz" => "xz", "7-zip" => "7z", "executable" => "exe", "directory" => "" }

  #FILE_CMD = BRL::Genboree::GenboreeConfig.load.fileUtil + " -m " + BRL::Genboree::GenboreeConfig.load.magicFile
  # Try to load GenboreConfig to get file command, else default to 'file ' if it fails
  FILE_CMD = BRL::Genboree::GenboreeConfig.load.fileCmd rescue 'file '

  UNZIP_CMD = BRL::Genboree::Constants::UNZIPUTIL
  BUNZIP_CMD = BRL::Genboree::Constants::BUNZIPUTIL
  GUNZIP_CMD = BRL::Genboree::Constants::GUNZIPUTIL
  UNXZ_CMD = BRL::Genboree::Constants::UNXZUTIL
  UN7Z_CMD = BRL::Genboree::Constants::UN7ZUTIL

  # The absolute path to the compressed file
  attr_accessor :compressedFileName
  # The absolute path to the uncompressed file  or dir if file is a tar archive
  attr_accessor :uncompressedFileName
  attr_accessor :uncompressedFileNames # @todo ALWAYS an empty array! does anything use this??
  # Turn this on for verbose logging
  attr_accessor :debug
  # These are used for handling system calls
  attr_reader :stderrStr, :stdoutStr, :errorLevel
  # Will contain any non-fatal warning message recorded
  attr_reader :warningMsg
  # If true, print warnings to stderr as well as store in warningmsg
  attr_accessor :printWarnings
  # absolute paths to the list of uncompressed files
  attr_accessor :uncompressedFileList
  # Intermediate compressed file hash
  attr_accessor :intermediateCompFileHash
  # Dir where the extraction will happen
  attr_accessor :tmpDir
  # FORCE ALL output to end up in this file
  attr_accessor :forcedOutputFileName
  # See if the file is a multi file archive
  attr_accessor :multiFileArchive

  # [+fileName+]  string: Full path of the compressed file
  def initialize(fileName, printWarnings=true)
    raise ArgumentError, "File: #{fileName} does not exist.", caller if(!File.exists?(fileName))
    fileName = File.expand_path(fileName) # accept relative or absolute path
    @compressedFileName = fileName
    @workingDir = File.dirname(fileName)
    @tmpDir = "#{@workingDir}/#{CGI.escape(SHA1.hexdigest(fileName))}"
    @debug = false
    @stderrStr = ''
    @stdoutStr = ''
    @errorLevel = -1
    @uncompressedFileName = nil
    @uncompressedFileNames = []
    @multiFileArchive = nil
    @warningMsg = nil
    @printWarnings = printWarnings
    @uncompressedFileList = []
    @intermediateCompFileHash = {}
    @uniqueString = ''
    @forcedOutputFileName = nil
    @selfCall = false
    @givenFullPath = (fileName[0].chr == '/')
    @sniffer = BRL::Util::Sniffer.new()
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Expander instantiated.\n  - fileName = #{fileName.inspect}\n  - @compressedFileName = #{@compressedFileName.inspect}\n  - @workingDir = #{@workingDir.inspect}\n  - @tmpDir = #{@tmpDir.inspect} ")
  end

  # Tests the file type and returns true if it's a known compressed file type, (gzip, bzip2, Zip, xz, tar)
  #
  # [+fileName+]  string: Full path of the compressed file
  # @raise IOError 
  def isCompressed?(fileName=@compressedFileName)
    fileType = getFileType(fileName)
    return (fileType == 'gzip' || fileType == 'bzip2' || fileType == 'Zip' || fileType == 'xz' || fileType == 'tar')
  end

  # [+returns+] bool - true if the file has been uncompressed
  def hasUncompressed?()
    return File.exists?(@uncompressedFileName)
  end

  # This method uses the 'file' command with the magic file /usr/local/brl/local/apache/magic.genboree
  #
  # Will only return types as defined in FILE_TYPES
  #
  # [+fileName+]   string: Full path of the compressed file
  # [+defaultType+]   string: default file type to assume if nothing matches (put nil to return nil)
  # [+returns+] string: - The file type
  # @todo Add ~suppressEmptyArchiveError param, to allow empty files to return as 'text' (non archive) rather than raise error!
  # @raise ArgumentError if fileName does not exist or is empty
  # @raise IOError
  def getFileType(fileName=@compressedFileName, defaultType=FILE_TYPES[0])
    retVal = defaultType
    # Validations first:
    if(!File.exists?(fileName))
      @errorLevel = 29
      @stderrStr = "ERROR: the file #{fileName.inspect} does not exist."
      @stdoutStr = ""
      raise ArgumentError, @stderrStr, caller
    elsif(File.zero?(fileName))
      @errorLevel = 30
      @stderrStr = "ERROR: the file #{fileName.inspect} appears to be empty. Therefore not a valid archive of any kind."
      @stdoutStr = ""
      raise ArgumentError, @stderrStr, caller
    else # try to get archive file type
      @sniffer.filePath = fileName
      # Detect file type using sniffer
      fileType = @sniffer.autoDetect
      # Convert file type from sniffer to Expander's version of the file type (bzip2 instead of bz, etc.).
      # If Expander doesn't recognize the file type, then fileType will be set to nil.
      fileType = FILE_EXTS.index(fileType)
      # This fixes the issue created by "Zip" => "zip" and "zip" => "zip" in the above FILE_EXTS hash (TEMPORARY FIX - CAN PROBABLY REMOVE THE "zip" => "zip" KEY-VALUE PAIR)
      fileType = "Zip" if(fileType == "zip")
      # If Expander includes the file type grabbed above, then we'll set retVal accordingly.
      # If not, retVal will remain the defaultType of "text".
      retVal = fileType if(FILE_TYPES.include?(fileType))
    end
    return retVal
  end

  # Eliminate false positives for a specific format
  # Example: for a file in bam format - gzip is a false positive
  # Will only return types as defined in FALSE_POSITIVE_TYPE
  #
  # [+fileName+]   string: Full path of the compressed file
  # [+type+]   string: file type to check for known false positives 
  # [+returns+] string: - The known false positive file type
  def checkFalsePositive(fileName, type)
    retVal = type
    # Get all commands to be checked for possible false positives
    if(FALSE_POSITIVE_TYPE.has_key?(type))
        FALSE_POSITIVE_TYPE[type].each_key { |falsePos|
        fpCmds = FALSE_POSITIVE_TYPE[type][falsePos]
        # Check if the given type is a false positive 
        fpCmds.each{ |falsePosCmd|
          cmd = falsePosCmd.gsub(/\{fileName\}/, Shellwords.escape(fileName))
          # Check exit success in this case
          exitOk = system(cmd)
          if(exitOk)
            # The current type is a false positive
            retVal = falsePos
            break
          end
        }
      }
    end
    return retVal
  end

  # Identify the type of compression that was used, and decompress
  # If @compressedFileName is a multi-file archive, 
  #   sets @uncompressedFileName to the 
  #   filepath of a unique String temporary directory tmpDir
  #   AND sets @uncompressedFileList to the top level file names (no 
  #   recursing into extracted directories) extracted
  # Otherwise, @compressedFileName is not a multi-file archive
  #   and sets @uncompressedFileName to the filepath of the
  #   uncompressed file
  #   and sets @uncompressedFileList to an array containing
  #   that filepath
  #
  # @param desiredType [String] The expected fileType of the extracted file
  # @param mainCall [Boolean] For internal use during recursive uncompression
  # @return processedSuccessfully [Boolean] indication of success (true) or failure (false)
  # @raise ArgumentError (from getFileType()) if @compressedFileName does not exist or is empty
  def extract(desiredType='text', mainCall=true)
    # Make a temp dir and and make a link to the file to be extracted
    if(mainCall)
      @tmpCompressedFileName = @compressedFileName.dup() # level up from tmp dir
      `mkdir -p #{Shellwords.escape(@tmpDir)}`
      @compressedFileName = File.join(@tmpDir, File.basename(@compressedFileName))
      `ln #{Shellwords.escape(@tmpCompressedFileName)} #{Shellwords.escape(@compressedFileName)}`
      # We now have a hard link of the source file in our special subdir work area or at least a command-line safe file name to begin with
      # Make sure it gets removed when done.
      @filesToCleanUp = [ @compressedFileName ]
    end
    processedSuccessfully = false
    compressionType = getFileType(@compressedFileName)
    logObjectStatus("Expander run:\n    After testingTheFileType\n    the compressionType = #{compressionType.inspect}") if(@debug)
    if(compressionType.nil?)
      processedSuccessfully = false
    else
      if(FILE_TYPES.index(compressionType) >= 0)
        processedSuccessfully = case (compressionType)
          when 'text' # text or any "not compressed"
            handleTextFile()
          when 'gzip'
            extractGz()
          when 'bzip2'
            extractBz2()
          when 'Zip'
            # Protect against unzip auto-adding .zip extension when we're done
            newName = "#{@compressedFileName}.#{SHA1.hexdigest(@compressedFileName)}"
            `mv #{Shellwords.escape(@compressedFileName)} #{Shellwords.escape(newName)}`
            @compressedFileName = newName
            # Need to clean up this weird/safe "tmp" file
            @filesToCleanUp << @compressedFileName
            # Should be safe now:
            extractZip()
          when 'xz'
            extractXz()
          when 'tar'
            extractTar()
          when '7-zip'
            extract7z()
          else
            @errorLevel = 30
            theExFile = (@uncompressedFileName.nil?) ? @compressedFileName : @uncompressedFileName
            if(@stderrStr.nil?)
              @stderrStr = "ERROR: Unable to recognize file: " + theExFile + " WRONG FORMAT OR ARCHIVE"
              @stdoutStr = ''
              logObjectStatus("") if(@debug)
              break
            end
          end
      end
      logObjectStatus("Expander: After attempting to extract.") if(@debug)
      if(@errorLevel == 0)
        # Check the file type of the uncompressed file
        processedSuccessfully = verifyUncompressedFile(desiredType)
        # We may need to do a recursive extract
        if(!processedSuccessfully)
          @compressedFileName = @uncompressedFileName
          @selfCall = true
          processedSuccessfully = extract(desiredType, false)
        end
      end
      logObjectStatus("After verification") if(@debug)
    end
    if(mainCall)
      @compressedFileName = @tmpCompressedFileName
      # If forcedOutputFileName, we want to mv the last tmp output to the user's designated target file
      if(@forcedOutputFileName)
        # Move final output into place
        `mv -f #{Shellwords.escape(@uncompressedFileName)} #{Shellwords.escape(@forcedOutputFileName)}`
        @uncompressedFileList << @forcedOutputFileName
        # Now set the uncompressedFileName to be their designated target file
        @uncompressedFileName = @forcedOutputFileName
        # Remove whole tmpDir!
        `rm -rf #{Shellwords.escape(@tmpDir)}`
      end
      @filesToCleanUp.each { |fileName|
        `rm -f #{Shellwords.escape(fileName)}` #if("#{File.basename(fileName)}" != File.basename(@uncompressedFileName)) # Don't remove the 'text' file from the temp dir in case the original file was 'text'
      }
      @uncompressedFileList -= @intermediateCompFileHash.keys
      @uncompressedFileList -= @filesToCleanUp
      ## Since uncompressedFileList is the full path of dirs, use delete_if to remove the 
      ## Macosx dirs from this list
      @uncompressedFileList.delete_if{|xx| xx =~ /__MACOSX\/?$/} # Some of the files received from Mac may have these
      #@uncompressedFileList -= ['__MACOSX'] # Some of the files received from Mac may have these
      # Ensure no filesToCleanUp are in the @intermediateCompFileHash
      @filesToCleanUp.each { |fileName|
        @intermediateCompFileHash.delete(fileName)
      }
      @intermediateCompFileHash.delete(@uncompressedFileName)
      # do we need to remove the unique string used to protect against file collisions?
      if(@uniqueString != '' and @uncompressedFileName =~ /\.#{@uniqueString}/)
        finalUncompFileName = @uncompressedFileName.gsub(/\.#{@uniqueString}/,'')
        `mv -f #{Shellwords.escape(@uncompressedFileName)} #{Shellwords.escape(finalUncompFileName)}` unless(finalUncompFileName == @uncompressedFileName)
        origUncompFileName = @uncompressedFileList.delete(@uncompressedFileName)
        @uncompressedFileName = finalUncompFileName
        unless(origUncompFileName.nil?)
          # then we removed old name from the list, add the new one
          @uncompressedFileList << @uncompressedFileName
        end
      end
      # Remove @tmpDir IF (a) empty and (b) @debug not set
      if(!@debug and File.exist?(@tmpDir) and Dir.entries(@tmpDir).size <= 2)
        `rm -rf #{Shellwords.escape(@tmpDir)}`
      end
      logObjectStatus("After clean up") if(@debug)
    end
    return processedSuccessfully
  end

  # Iterate over each uncompressed *file*.
  # @param [Boolean] includeDirs if false, exclude directories in iterator
  def each(includeDirs=false)
    fileCount = 0
    unless(@uncompressedFileList.nil? or @uncompressedFileName.nil?)
      # Iterate over each @uncompressedFileList entity (may be file or dir)
      # - will not have the intermediate files nor cleaned up temp files b/c extract() removed them at the end
      Find.find(*@uncompressedFileList) { |subItem|
        # What is full path to item and its basename?
        fullItemPath = File.expand_path(subItem)
        baseName = File.basename(subItem)
        # Make sure to skip things like . and .., but not .dotfiles... etc
        if(File.directory?(fullItemPath))
          if(baseName == '.' or baseName == '..')
            Find.prune
          else # skip directories unless asked to return them
            if(includeDirs)
              fileCount += 1
              yield fullItemPath
            end
          end
        else # a file, yield it up
          fileCount += 1
          yield fullItemPath
        end
      }
    end
    return fileCount
  end

  # Return a list of uncompressed files from any fileNames given
  # @see extract
  # @see each
  # @note makes the class-wide assumption of no nested multifile archive types
  # @return [Hash] map input fileNames to its uncompressed contents (singleton array if uncompressed),
  #   or to an error object:
  #   [Hash] :success => { path => [ path1, path2, ... ], ... }
  #   [Hash] :fail => { path => error, ... } (error messages are user friendly)
  def self.extract_files(fileNames, desiredType='text', includeDirs=false)
    retVal = { :success => {}, :fail => {} }
    fileNames.each{ |fileName|
      exp = self.new(fileName)
      compressed = exp.isCompressed? rescue nil
      if(compressed)
        success = exp.extract()
        if(success)
          uncompressedFiles = []
          exp.each { |filepath|
            uncompressedFiles << filepath
          }
          retVal[:success][fileName] = uncompressedFiles
        else
          retVal[:fail][fileName] = ArgumentError.new("Could not extract archive")
        end
      else
        # then not compressed or empty
        if(File.zero?(exp.compressedFileName))
          retVal[:fail][fileName] = ArgumentError.new("File is empty")
        else
          retVal[:success][fileName] = [fileName]
        end
      end
    }
    return retVal
  end

  #--------------------------
  # private methods
  #--------------------------

  def typeFromUnixFileCmd(fileName, tryMultiMatch=true, defaultType=FILE_TYPES[0])
    retVal = defaultType
    # Build file command to run
    multiMatchArg = (tryMultiMatch ? ' -k ' : '')
    dereferenceArg = ' -L '
    cmd = "#{FILE_CMD} -b #{multiMatchArg} #{dereferenceArg} #{Shellwords.escape(fileName)}"
    # Run the file command capturing, return value, stderr and stdout
    pid, stdin, stdout, stderr = Open4.popen4(cmd)
    stdin.close
    setOutputInfo(pid, stdout, stderr)
    if(@errorLevel != 0)
      logObjectStatus("FATAL ERRORLEVEL: from unix 'file' command. ")
      raise ArgumentError, "FATAL ERROR: from unix 'file' command. "
    else
      # Parse stdout for the matching file output to determine the compression type.
      # The output will NOT have our file name in it (b/c of -b), just the matching records.
      #
      # To reduce risk of odd false-positives, we will look at each record rather than whole string.
      # Thus, split stdout string into records:
      matchRecords = @stdoutStr.split(/\n-/)
      # Look for each type in file's output text (minus the filename). Collect all.
      archiveMatches = []
      UNIX_FILE_TYPES.each { |currType|
        matchRecords.each { |matchRecord|
          if(matchRecord.index(currType))
            archiveMatches << currType
          end
        }
      }
      # If multiple matching archive records, we failed.
      if(archiveMatches.size > 1)
        $stderr.puts "ERROR: '#{fileName}' matches several archive types according to unix 'file' (#{archiveMatches.join(", ")}). Can't proceed!"
        retVal = nil
      elsif(matchRecords.size == 1 and archiveMatches.size == 1) # there is 1 match and it is an archive type
        retVal = archiveMatches.first
      elsif(matchRecords.size > 1 and archiveMatches.size == 1) # there are multiple matches but only 1 is an archive type
        retVal = archiveMatches.first
        @warningMsg = "WARNING: '#{fileName}' matches several files types according to unix 'file' (#{archiveMatches.join(", ")}), but only one is archive. Proceeding using the archive type."
        $stderr.puts @warningMsg if(@printWarnings)
      else # unix 'file' came up with nothing, keep default type
        retVal = defaultType
      end
    end
    # Either default type, some archive type determined by 'file', or nil if multiple possible archive types
    return retVal
  end

  # This method performs the extraction,
  # setting @stderrStr, @stdoutStr, @errorLevel
  #
  # [+compType+]  string - The compression type as identified by getFileType
  # [+cmd+]       string - The (escaped) command to use for this compression type
  # [+returns+] errorLevel
  def extractType(compType, cmd)
    $stderr.puts "STATUS: #{self.class}: The decompressCommand = " + cmd.inspect if(@debug)
    pid, stdin, stdout, stderr = Open4.popen4(cmd)
    stdin.close
    $stderr.puts "STATUS: #{self.class}: The decompressCommand has pid = " + pid.inspect if(@debug)
    setOutputInfo(pid, stdout, stderr)
    return @errorLevel
  end

  def extractXz()
    setFileNames('.xz')
    xunzipCmd = "#{UNXZ_CMD} -c #{Shellwords.escape(@compressedFileName)} > #{Shellwords.escape(@uncompressedFileName)}"
    extractType('xz', xunzipCmd)
    if(@errorLevel == 2)
      if(@stderrStr.indexOf("trailing garbage ignored") >= 0)
        @errorLevel = 0
      end
    end
    @uncompressedFileList << @uncompressedFileName
    @intermediateCompFileHash[@uncompressedFileName] = nil if(isCompressed?(@uncompressedFileName))
    return (@errorLevel == 0)
  end

  def extractGz()
    setFileNames('.gz')
    gunzipCmd = "#{GUNZIP_CMD} -c #{Shellwords.escape(@compressedFileName)} > #{Shellwords.escape(@uncompressedFileName)}"
    extractType('gzip', gunzipCmd)
    if(@errorLevel == 2)
      if(@stderrStr.indexOf("trailing garbage ignored") >= 0)
        @errorLevel = 0
      end
    end
    @uncompressedFileList << @uncompressedFileName
    @intermediateCompFileHash[@uncompressedFileName] = nil if(isCompressed?(@uncompressedFileName))
    return (@errorLevel == 0)
  end

  def extractBz2()
    setFileNames('.bz2')
    bunzipCmd = "#{BUNZIP_CMD} -c #{Shellwords.escape(@compressedFileName)} > #{Shellwords.escape(@uncompressedFileName)}"
    extractType('bzip2', bunzipCmd)
    @uncompressedFileList << @uncompressedFileName
    @intermediateCompFileHash[@uncompressedFileName] = nil if(isCompressed?(@uncompressedFileName))
    return (@errorLevel == 0)
  end

  def extractTar()
    @multiFileArchive = true
    setFileNames('.tar')
    if(@forcedOutputFileName)
      tarCmd = "tar -Oxvf #{Shellwords.escape(@compressedFileName)} > #{Shellwords.escape(@uncompressedFileName)}"
    else
      tarCmd = "tar -xvf #{Shellwords.escape(@compressedFileName)} -C #{Shellwords.escape(File.dirname(@compressedFileName))}"
    end
    extractType('tar', tarCmd)
    if(@errorLevel == 2)
      if(@stderrStr.indexOf("trailing garbage ignored") >= 0)
        @errorLevel = 0
      end
    end
    if(!@forcedOutputFileName)
      @uncompressedFileName = @tmpDir
      Dir.entries(@tmpDir).each { |entry|
        next if(entry == '.' or entry == '..' or entry == File.basename(@tmpCompressedFileName))
        @uncompressedFileList << "#{@tmpDir}/#{entry}" if(!@uncompressedFileList.include?("#{@tmpDir}/#{entry}"))
      }
    end
    return (@errorLevel == 0)
  end

  def extractZip()
    setFileNames('.zip')
    if(@forcedOutputFileName)
      unzipCmd = "#{UNZIP_CMD} -o -p #{Shellwords.escape(@compressedFileName)} > #{Shellwords.escape(@uncompressedFileName)}"
    else
      unzipCmd = "#{UNZIP_CMD} -o -d #{Shellwords.escape(File.dirname(@compressedFileName))} #{Shellwords.escape(@compressedFileName)}"
    end
    extractType('Zip', unzipCmd)
    # If zip extracted more than 1 file, we will return the directory, otherwise the file name
    if(@stdoutStr.nil? or @stdoutStr.empty?) # Something went wrong
      @errorLevel = 30
      $stderrStr = "ERROR: No Stdout from zip; no files extracted."
      logObjectStatus("No Stdout from zip")
    else
      if(!@forcedOutputFileName)
        if(@stdoutStr.scan(/(?:inflating:|extracting:)/i).size >= 2) # We have multiple files
          @multiFileArchive = true
          @uncompressedFileName = @tmpDir
        else # just one file
          @stdoutStr =~ /(?:inflating:|extracting:)\s*([^\n]+)/i
          @uncompressedFileName = $1.strip
        end
        Dir.entries(@tmpDir).each { |entry|
          next if(entry == '.' or entry == '..' or entry == File.basename(@tmpCompressedFileName))
          @uncompressedFileList << "#{@tmpDir}/#{entry}" if(!@uncompressedFileList.include?("#{@tmpDir}/#{entry}"))
        }
      end
      @errorLevel = 0
    end
    return (@errorLevel == 0)
  end
  
  def extract7z()
    setFileNames('.7z')
    if(@forcedOutputFileName)
      # error out unless target is 7z = -t7z, force output = -so
      un7zipCmd = "#{UN7Z_CMD} e -t7z -so #{Shellwords.escape(@compressedFileName)} > #{Shellwords.escape(@uncompressedFileName)}"
    else
      # yes to all = -y, output directory = -o{directory} 
      un7zipCmd = "#{UN7Z_CMD} e -t7z -y -o#{Shellwords.escape(File.dirname(@compressedFileName))} #{Shellwords.escape(@compressedFileName)}"
    end
    extractType('7-zip', un7zipCmd)
    if(@stdoutStr.nil? or @stdoutStr.empty?)
      # then something went wrong
      @errorLevel = 30
      $stderrStr = "ERROR: No Stdout from 7-zip; no files extracted."
      logObjectStatus("No Stdout from zip")
    else
      # determine from stdout if the archive is multi-file or not
      fileCountPattern = /^Files:\s*(\d+)/
      @stdoutStr.match(fileCountPattern) 
      if($1.nil?)
        # then its probably a single file, get the file name
        fileNamePattern = /^Extracting\s*([^\n]+)/
        @stdoutStr.match(fileNamePattern)
        unless($1.nil?)
          @uncompressedFileName = "#{@tmpDir}/#{$1.strip}"

          # also set the @uncompressedFileList in case other code tries to use it
          @uncompressedFileList = [@uncompressedFileName]
        else
          # something went wrong..
          @errorLevel = 30
          @stderrStr = "ERROR: No file name from 7-zip; exiting."
          logObjectStatus("No file name from 7-zip")
        end
      else
        # then its probably a multi file archive
        @multiFileArchive = true
        @uncompressedFileName = @tmpDir
        Dir.entries(@tmpDir).each{| entry|
          next if (entry == '.' or entry =='..' or entry == File.basename(@tmpCompressedFileName))
          @uncompressedFileList << "#{@tmpDir}/#{entry}" if(!@uncompressedFileList.include?("#{tmpDir}/#{entry}"))
        }
      end
    end
    return (@errorLevel == 0)
  end

  def removeIntermediateCompFiles()
    @intermediateCompFileHash.each_key { |key|
      `rm -f #{Shellwords.escape(key)}`
    }
  end

  # This method take the values returned by popen4 and sets useful instance vars
  #
  # [+pid+]     Int from popen4
  # [+stdout+]  IO from popen4
  # [+stderr+]  IO from popen4
  def setOutputInfo(pid, stdout, stderr)
    @stdoutStr = ''
    @stderrStr = ''
    stdout.each_line { |ll| @stdoutStr += ll } if(!stdout.nil?)
    stderr.each_line { |ll| @stderrStr += ll } if(!stderr.nil?)
    stdout.close
    stderr.close
    ignored, errorLevel = Process::waitpid2(pid)
    @errorLevel = errorLevel.to_i
  end

  # If the input file is already a text file, set instance vars
  #
  # [+returns+] true
  def handleTextFile()
    @uncompressedFileName = @tmpCompressedFileName
    @uncompressedFileList << @tmpCompressedFileName
    @errorLevel = 0
    @stderrStr = ""
    @stdoutStr = "Text file"
    return true
  end

  # Use this method for debugging and logging
  def logObjectStatus(msg)
    $stderr.puts "## DEBUG: #{Time.now} -- #{msg}"
    $stderr.puts "   compressedFileName = #{@compressedFileName.inspect}"
    $stderr.puts "   uncompressedFileName = #{@uncompressedFileName.inspect}"
    $stderr.puts "   errorLevel = #{@errorLevel.inspect}"
    $stderr.puts "   stderr: #{@stderrStr}"
    $stderr.puts "   stdout: #{@stdoutStr}"
  end

  def verifyUncompressedFile(desiredType)
    processedSuccessfully = false
    if(@multiFileArchive.nil?)
      # Check the file type of the uncompressed file
      uncompressedFileType = getFileType(@uncompressedFileName)
      logObjectStatus("After rechecking the file = " + @uncompressedFileName + " the uncompressedFileType = " + uncompressedFileType) if(@debug)
      if(@errorLevel == 0)
        if(uncompressedFileType != desiredType)
          @errorLevel = 30
          @stderrStr = "ERROR: FILE #{uncompressedFileType.inspect} is not the desired type #{uncompressedFileType.inspect} WRONG FORMAT OR ARCHIVE."
          $stdoutStr = ""
          logObjectStatus("DEBUG: ") if(@debug)
          processedSuccessfully = false;
        else
          processedSuccessfully = true;
        end
      end
    else
      processedSuccessfully = true
    end
    return processedSuccessfully
  end

  # This method ensures that the compressed file has the appropriate compression file extension
  # and the uncompressed doesn't by setting @uncompressedFileName and @compressedFile
  #
  # [+fileExt+]   string - The file extension of the compression type, compressed file is renamed using this if it doesn't have it
  # [+returns+]
  # @todo - Address issue with compressed files without any extension not uncompressed properly (Example: tmp.gz where tmp is another gzipped file)
  def setFileNames(fileExt=nil)
    compFileName, uncompFileName = getFileNames(@compressedFileName, fileExt, true, false)
    @compressedFileName, @uncompressedFileName = compFileName, uncompFileName
    # Set up for forcedOutputFileName situation:
    if(@forcedOutputFileName)
      @uncompressedFileName = "#{@tmpDir}/#{File.basename(@uncompressedFileName)}.#{SHA1.hexdigest(@uncompressedFileName)}"
      @filesToCleanUp << @uncompressedFileName
    end
    return @uncompressedFileName
  end

  # Gets the names as they WOULD be, if expansion were done.
  # - Only adjusts the actual file names on disk if fixFiles is true.
  def getFileNames(compressedFileName=@compressedFileName, fileExt=nil, fixFiles=false, recursiveFileGuess=true)
    if(fileExt.nil?)
      fileType = getFileType(compressedFileName)
      fileExt = ".#{FILE_EXTS[fileType]}"
    end
    if(@forcedOutputFileName) # only do this set for forcedOutputFileName when setting up, not when recursing through archives-of-archives
      if(!@selfCall)
        uncompressedFileName = @forcedOutputFileName
      else
        uncompressedFileName = @uncompressedFileName
      end
    else
      if(fileExt and !fileExt.empty?)
        # add a unique string to intermediate file uncompression to prevent intermediate name conflicts
        origCompressedFileName = compressedFileName.dup()
        compressedFileName = ((@uniqueString == '') ? compressedFileName : compressedFileName.gsub(/\.#{@uniqueString}/, ''))
        compressedFileName = compressedFileName.gsub(/#{fileExt}$/, '')
        uncompressedFileName = compressedFileName
        @uniqueString = uncompressedFileName.generateUniqueString
        # ensure that removing the extension hasnt left us with no file name at all
        uncompressedFileName = (File.basename(compressedFileName) == File.basename(@tmpDir) ? "#{File.join(File.dirname(origCompressedFileName), @uniqueString)}" : "#{uncompressedFileName}.#{@uniqueString}")
        # Compressed file gets the extension appended
        newFileName = "#{compressedFileName}#{fileExt}"
        unless(origCompressedFileName == newFileName)
          `mv #{Shellwords.escape(origCompressedFileName)} #{Shellwords.escape(newFileName)}` if(fixFiles)
        end
        compressedFileName = newFileName
        # Ensure this changed file name--also in @tmpDir--gets cleaned up
        # But ALSO ensure the original compressed file name (now likely the final uncompressed name)
        # is NOT in the filesToCleanUp list...
        if(@filesToCleanUp)
          @filesToCleanUp.delete(uncompressedFileName)
          @filesToCleanUp << compressedFileName
        end
        # Ensure uncompressedFileName will be in @tmpDir, regarless of whether compressedFileName input arg is or not.
        if(MULTIFILE_ARCHIVE_BY_TYPE[fileType])
          uncompressedFileName = @tmpDir
        elsif(recursiveFileGuess)
          uncompressedFileName = "#{@tmpDir}/#{File.basename(uncompressedFileName)}"
          uncompressedFileName =~ /^(.+)\.([^\.]+)$/
          uncompExt = $2
          if(uncompExt) # then we found an extension
            if(MULTIFILE_ARCHIVE_BY_EXT[uncompExt]) # then we found a multifile extension
              uncompressedFileName = @tmpDir
            else # need to keep looking
              uncompressedFileName = $1
              uncompExt.downcase!
              while(!uncompExt.nil? and FILE_EXTS.key?(uncompExt))
                uncompressedFileName =~ /^(.+)\.([^\.]+)$/
                uncompExt = $2
                if(uncompExt)
                  uncompressedFileName = $1
                  if(MULTIFILE_ARCHIVE_BY_EXT[uncompExt])
                    uncompressedFileName = @tmpDir
                    break
                  else
                    uncompExt.downcase!
                  end
                end
              end
            end
          else # no extension found, must be at end, assume not a multifile archive
            # nothing
          end
        else
          # nothing
        end
      else # not a compressed type we know of
        uncompressedFileName = "#{@tmpDir}/#{File.basename(compressedFileName)}"
      end
    end
    return compressedFileName, uncompressedFileName
  end

  # Use "setFileNames()" for internal usage. This is for use outside, esp prior to expansion.
  def getUncompressedFileName()
    compFileName, uncompFileName = getFileNames()
    return uncompFileName
  end

  # --------------------------------------------------------------------------
  # HELPERS
  # --------------------------------------------------------------------------
  def Expander.processArguments()
    optsArray = [
                  ['--file', '-f', GetoptLong::REQUIRED_ARGUMENT],
                  ['--outputFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--removeIntFiles', '-r', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
                  ['--help', '-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    Expander.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash
    Expander.usage() if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end

  def Expander.usage(msg='')
    puts "\n#{msg}\n" unless(msg.empty?)
    puts "

  PROGRAM DESCRIPTION:
    Inflates the input file using the most appropriate command.

    COMMAND LINE ARGUMENTS:
      --file                  |   -f    => URL escaped command(s).
      --outputFile            |   -o    => [optional] Force ALL output to be concatenated into
                                           this file (even if multiple file archive!!!!)
      --removeIntFiles        |   -r    => Remove Intermediate files and put the extracted file(s) in the same directory as the input file
      --verbose               |   -v    => [optional flag] More verbose on stderr.
      --help                  |   -h    => [optional flag] Output usage info and exit.

    USAGE:
    expander.rb -f compressed.file
  "
    exit(16)
  end
end
end ; end # module BRL ; module Util


# --------------------------------------------------------------------------
# MAIN (command line execution begins here)
# --------------------------------------------------------------------------
begin
  if($0 and File.exist?($0))
    # In case symlink chain, get ultimate file paths
    fileBeingRun = Pathname.new($0).realpath.to_s
    thisFile = Pathname.new(__FILE__).realpath.to_s
    if(!fileBeingRun.rindex('brl').nil?)
      fileBeingRun = fileBeingRun[fileBeingRun.rindex('brl'), fileBeingRun.size]
    end
    if(!(thisFile.rindex('brl').nil?)) # on the server
      thisFile = thisFile[thisFile.rindex('brl'),  thisFile.size]
    else
      raise "SERVER MISCONFIGURED! (#{thisFile} should by properly linked to $RUBYLIB area."
    end
    if(fileBeingRun == thisFile)
      # process args
      optsHash = BRL::Util::Expander::processArguments()
      # instantiate
      expander = BRL::Util::Expander.new(optsHash['--file'])
      expander.debug = true
      if(optsHash['--outputFile'])
        expander.forcedOutputFileName = optsHash['--outputFile']
      end
      $stderr.puts "EXPANDER instantiated" if(optsHash.key?('--verbose'))
      # call
      inflateOk = expander.extract()
      if(inflateOk)
        $stdout.print expander.uncompressedFileName
        if(optsHash.key?('--removeIntFiles'))
          expander.removeIntermediateCompFiles()
          `mv #{Shellwords.escape(expander.tmpDir)}/* #{File.dirname(optsHash['--file'])}`
          finalUncompFileName = File.join(File.dirname(optsHash['--file']), File.basename(expander.uncompressedFileName))
          `rm -rf #{Shellwords.escape(expander.tmpDir)}`
        end
        exitVal = 0
      else
        raise "ERROR: could not expand file. Expander object:\n    #{expander.inspect}"
      end
    end
  end
rescue => err
  errTitle =  "(#{$$}) #{Time.now()} Expander - FATAL ERROR: Couldn't run the expansion command. Exception listed below."
  errstr   =  "\n   The error message was: #{err.message}\n"
  errstr   += "\n   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
  $stderr.puts errTitle + errstr
  exitVal = 1
end
