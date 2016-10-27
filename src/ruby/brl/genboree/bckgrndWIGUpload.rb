#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'cgi'
require 'fileutils'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'

module BRL ; module Genboree
  class BckGrndWIGUploader
    # Requires 'genbTaskWrapper.rb' to be available in the PATH!
    #
    # If you want to override the default file names used as stdout and stderr streams by the
    # task wrapper, then provide taskErrOutFilesBase as a full path. The .out and .err
    # extensions will be added to the end of this path to name each file.
    #
    # Remember to use the "gbApiUploadDir" property from the Genboree config file
    # (or other such settings) when making your file locations and such.

    attr_accessor :userId, :refSeqId, :wigFile, :taskErrOutFilesBase
    attr_accessor :ioArray, :cmdExitStatus, :cmdBase, :uploadCmdBase
    attr_accessor :verbose, :groupName, :dbName, :email, :trackName
    attr_accessor :windowingMethod, :recordType, :noZoom, :importLockFalse
    attr_accessor :useLog, :attributesPresent
    def initialize(userId, refSeqId, groupName, email, wigFile=nil, taskErrOutFilesBase=nil)
      @userId, @refSeqId, @groupName, @email, @wigFile, @taskErrOutFilesBase = userId, refSeqId, groupName, email, wigFile, taskErrOutFilesBase
      @verbose = true
      @trackName = nil
      @windowingMethod = nil
      @recordType = nil
      @useLog = nil
      @attributesPresent = nil
    end

    # _returns_ - Array of [cmdStdin, cmdStdout, cmdStderr]
    def doUpload()
      taskErrOutFilesBase = @taskErrOutFilesBase.strip
      # First, let's get the dir of the WIG file and cd to it. This will be helpful/safe when launching uploader process.
      if(@wigFile =~ %r{^(.+)\/[^\/]+})
        @wigFileDir = $1
        $stderr.puts "API UPLOAD LFF cd'd to this working dir: #{@wigFileDir}"
        FileUtils.cd(@wigFileDir)
      end
      # Make the upload command to run
      @uploadCmdOutFile = "#{@taskErrOutFilesBase}.autoUploader.out"
      @uploadCmdErrFile = "#{@taskErrOutFilesBase}.autoUploader.err"
      #Prepare arguments for 'importWiggleInGenboree.rb'
      gc = BRL::Genboree::GenboreeConfig.load
      @uploadCmdBase = "#{gc.toolScriptPrefix}importWiggleInGenboree.rb -i #{CGI.escape(@wigFile)} -d #{@refSeqId} -g #{CGI.escape(@groupName)} -u #{@userId} " +
                       "-E #{@email} "
      args = ""
      args << " --gbTrackWindowingMethod '#{@windowingMethod}' " if(!@windowingMethod.nil?)
      args << " -z #{@recordType} " if(!@recordType.nil?)
      args << " --useLog " if(@useLog)
      args << " --attributesPresent " if(@attributesPresent)
      @uploadCmdBase << args if(!args.empty?)
      # Here we add specific options, if they are available (probably looping over some static array of possible specific options)
      @uploadCmdBase << " -t #{CGI.escape(@trackName)} " if(@trackName) # To pass trackName safely, we need the CGI.escape() approach. It can contain anything.
      # After adding them, we finish off the command with the redirections
      @uploadCmdBase << " 1> #{@uploadCmdOutFile} 2> #{@uploadCmdErrFile} "
      # Make task command:
      # -- note, it's safest to URL encode arguments to genbTaskWrapper.rb whose values are based on user-input (db names, user names, etc.)
      # -- they will be decoded automatically if detected
      # -- obviously, if the value contains an escape sequence itself, then it MUST be encoded (such that the string "Demo%20123" becomes "Demo%2520123" for example)
      @cmdBase =  "genbTaskWrapper.rb -c #{CGI.escape(@uploadCmdBase)} -g #{ENV['GENB_CONFIG']} "
      @cmdBase << " -v " if(@verbose)
      @cmdBase << " -o #{CGI.escape(taskErrOutFilesBase)}.out -e #{CGI.escape(taskErrOutFilesBase)}.err > #{taskErrOutFilesBase}.launch.output 2>&1 " if(taskErrOutFilesBase)
      @cmdBase << " & " # necessary to run in background, since genbTaskWrapper.rb will -detach- itself
      $stderr.puts "\nAPI UPLOAD WIG CMD: #{@cmdBase.inspect}"
      # Execute command...should return right away
      $stderr.puts "BEFORE launching genbTaskWrapper => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
      `#{@cmdBase}`
      @cmdExitStatus = $?
      $stderr.puts "AFTER launching genbTaskWrapper => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
      $stderr.puts "\nAPI UPLOAD WIG CMD EXECUTED AS DETACHED BACKGROUND PROCESS. Exit status: #{@cmdExitStatus.exitstatus}"
      return @cmdExitStatus
    end
  end # class BckGrndLFFUploader
end ; end # module BRL ; module Genboree
