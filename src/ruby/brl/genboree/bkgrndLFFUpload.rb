#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'cgi'
require 'fileutils'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/constants'

module BRL ; module Genboree
  class BckGrndLFFUploader
    # Requires 'genbTaskWrapper.rb' to be available in the PATH!
    #
    # If you want to override the default file names used as stdout and stderr streams by the
    # task wrapper, then provide taskErrOutFilesBase as a full path. The .out and .err
    # extensions will be added to the end of this path to name each file.
    #
    # Remember to use the "gbApiUploadDir" property from the Genboree config file
    # (or other such settings) when making your file locations and such.

    attr_accessor :userId, :refSeqId, :groupId, :lffFile, :taskErrOutFilesBase
    attr_accessor :ioArray, :cmdExitStatus, :cmdBase, :uploadCmdBase
    attr_accessor :verbose

    def initialize(userId, refSeqId, groupId, lffFile=nil, taskErrOutFilesBase=nil)
      @userId, @groupId, @refSeqId, @lffFile, @taskErrOutFilesBase = userId, groupId, refSeqId, lffFile, taskErrOutFilesBase
      @verbose = true
    end
    
    def setGroupName
    end

    # _returns_ - Array of [cmdStdin, cmdStdout, cmdStderr]
    def doUpload()
      taskErrOutFilesBase = @taskErrOutFilesBase.strip
      # First, let's get the dir of the LFF file and cd to it. This will be helpful/safe when launching uploader process.
      if(@lffFile =~ %r{^(.+)\/[^\/]+})
        @lffFileDir = $1
        $stderr.puts "API UPLOAD LFF cd'd to this working dir: #{@lffFileDir}"
        FileUtils.cd(@lffFileDir)
      end
      # Make the upload command to run
      # This is the combined script that does zoomlevels and AutoUpload
      
      @cmdOutFile = "#{@taskErrOutFilesBase}.createZoomLevelsAndUploadLFF.out"
      @cmdErrFile = "#{@taskErrOutFilesBase}.createZoomLevelsAndUploadLFF.err"

      # Make task command:
      # -- note, it's safest to URL encode arguments to genbTaskWrapper.rb whose values are based on user-input (db names, user names, etc.)
      # -- they will be decoded automatically if detected
      # -- obviously, if the value contains an escape sequence itself, then it MUST be encoded (such that the string "Demo%20123" becomes "Demo%2520123" for example)
      $stderr.puts "DEBUG: doUpload(): userId: #{@userId.inspect}"
      cmd = "createZoomLevelsAndUploadLFF.rb -i #{CGI.escape(@lffFile)} -d #{@refSeqId} -g #{@groupId} -u #{@userId} > #{@cmdOutFile} 2> #{@cmdErrFile} "
      wrappedCmd = "genbTaskWrapper.rb -c #{CGI.escape(cmd)} -g /usr/local/brl/local/apache/genboree.config.properties"
      wrappedCmd << " -v " if(@verbose)
      wrappedCmd << " -o #{CGI.escape(taskErrOutFilesBase)}.out -e #{CGI.escape(taskErrOutFilesBase)}.err > #{taskErrOutFilesBase}.launch.output 2>&1 " if(taskErrOutFilesBase)
      wrappedCmd << " & " # necessary to run in background, since genbTaskWrapper.rb will -detach- itself
      $stderr.puts "\nAPI UPLOAD LFF CMD: #{@cmd.inspect}"
      $stderr.puts "BEFORE launching genbTaskWrapper => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
      `#{wrappedCmd}`
      @cmdExitStatus = $?
      $stderr.puts "AFTER launching genbTaskWrapper => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
      $stderr.puts "\nAPI UPLOAD LFF CMD EXECUTED AS DETACHED BACKGROUND PROCESS. Exit status: #{@cmdExitStatus.exitstatus}"
      return @cmdExitStatus
    end
  end # class BckGrndLFFUploader
end ; end # module BRL ; module Genboree
