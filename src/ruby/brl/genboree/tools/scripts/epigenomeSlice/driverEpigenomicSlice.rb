#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'pathname'
require 'brl/util/util'
require 'brl/genboree/rest/wrapperApiCaller'
# Require scriptDriver.rb
require 'brl/script/scriptDriver'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'
include BRL::Genboree::REST

# Write sub-class of BRL::Script::ScriptDriver
module BRL ; module Script
  class DriverLimmaSignalComparison < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--trackSet"    =>  [ :REQUIRED_ARGUMENT, "-t", "Input trackSet(s)" ],
      "--roiTrack"    =>  [ :OPTIONAL_ARGUMENT, "-r", "ROI track" ],
      "--aggF"        =>  [ :REQUIRED_ARGUMENT, "-A", "Agg Function" ],
      "--scratch"     =>  [ :REQUIRED_ARGUMENT, "-S", "Scratch area" ],
      "--apiDBRC"     =>  [ :REQUIRED_ARGUMENT, "-a", "api DBRC key" ],
      "--userId"      =>  [ :REQUIRED_ARGUMENT, "-u", "user id"],
      "--removeNoData"=>  [ :REQUIRED_ARGUMENT, "-R", "remove no data region"],
      "--help"        =>  [ :NO_ARGUMENT, "-h", "Help"]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Driver to run tool, which generates matrix on epigenome data",
      :authors      => [ "Arpit Tandon" ],
      :examples => [
        "#{File.basename(__FILE__)} -t trackSet -r 'http://genboree.org/REST/v1/grp/aa/db/bb/trk/CpG:Islands' -s AVG -S /scratch/test -R 10000 -f true -n true -o fdr -p 0.5 -M 0.5",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . optsHash contains the command-line args, keyed by --longName
    def run()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running Driver .....")
      exitStatus = EXIT_OK
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      validateAndProcessArgs()
      system("mkdir -p #{@scratch}/matrix")
      system("mkdir -p #{@scratch}/signal-search/trksDownload")
      system("mkdir -p #{@scratch}/logs")
      if(File.exists?("#{@scratch}/matrix") and File.exists?("#{@scratch}/signal-search/trksDownload") and  File.exists?("#{@scratch}/logs"))
        exitStatus = buildHashofVectorEntity()
        $stderr.debugPuts(__FILE__, __method__, "ExitStatus",exitStatus)
        if(exitStatus == 120)
          $stderr.debugPuts(__FILE__, __method__, "ERROR","Some of the tracks are either removed or not accessible by user")
          exitStatus = 120
        else
          exitStatus = runBuildMatrixTool()
          if(exitStatus == 113)
            $stderr.debugPuts(__FILE__, __method__, "ERROR","Matrix couldn't be built")
            exitStatus = 113
          else
            $stderr.debugPuts(__FILE__, __method__, "Done","Matrix is created")
            exitStatus = compressFiles
            if(exitStatus != 0)
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Compression failed")
              exitStatus = 116
            else
              $stderr.debugPuts(__FILE__, __method__, "Done", "Compression")
            end
          end
        end
     else
        $stderr.debugPuts(__FILE__, __method__, "Status", "Dir generation failed")
        exitStatus = 119
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Driver completed with #{exitStatus}")
      return exitStatus
    end

    ##Download entityList
    ##And verify all the tracks are accessible
    def buildHashofVectorEntity()
      exitCode = 0
      @trkSetHash = {}
      tempFile1 = File.open("#{@scratch}/tmpFile.txt","w+")
      ##for multiple trackEntity Lists
      @trackSets = @trackSet.split(/,/)
      puts @trackSet
      @trackSets.each { |trackSet|
        if(trackSet =~ BRL::Genboree::REST::Helpers::TrackEntityListApiUriHelper::NAME_EXTRACTOR_REGEXP) then 
        uri            = URI.parse(trackSet)
        host           = uri.host
        path1          = uri.path.chomp('?')
        path1 << "/data?"
        encodedUri = trackSet
        path1 << "gbKey=#{@dbApiHelper.extractGbKey(encodedUri)}" if(@dbApiHelper.extractGbKey(encodedUri))
        apicaller = WrapperApiCaller.new(@host,path1,@userId)
        apicaller.get()
        if apicaller.succeeded?
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "#{trackSet} trackSet downloaded successfully")
        else
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool- ERROR", apicaller.parseRespBody().inspect)
          exitCode = apicaller.apiStatusObj['statusCode']
        end
        apicaller.parseRespBody
        apicaller.apiDataObj.each { |obj|
          tempFile1.puts obj['url']
          @trkSetHash[obj['url']] = ""
        }
        else # just a track
           tempFile1.puts trackSet
           @trkSetHash[trackSet] = ""
        end
      }
      tempFile1.close
      ## Checking if THE TRACKS in entitylist EXIST and are ACCESSIBLE by the user
      exitCode = tracksAccessible?(@trkSetHash)
      return exitCode
    end

    ## To ensure AlL THE TRACKS in entitylist EXIST and are ACCESSIBLE by the user
    def tracksAccessible?(trkSetHash)
      exitStatus = 0
       trkSetHash.each_key{|key|
         uri = URI.parse(key)
         host= uri.host
         path = uri.path
         path << "?gbKey=#{@dbApiHelper.extractGbKey(key)}" if(@dbApiHelper.extractGbKey(key))
         api = WrapperApiCaller.new(host,path,@userId)
         api.get
         if(!api.succeeded?)
           exitStatus = 120
           $stderr.debugPuts(__FILE__, __method__, "#{File.basename(path)}", api.parseRespBody().inspect)
           break
         else
           $stderr.debugPuts(__FILE__, __method__, "Track Access", "#{File.basename(path)} is accessible")
         end
       }
      return exitStatus
    end


    ##run buildMatrix tool
    def runBuildMatrixTool()
      $stderr.debugPuts(__FILE__, __method__, "Running ", "Building Matrix")
      cmd ="epigenomicSliceTool.rb "
      cmd << " -t '#{@scratch}/tmpFile.txt' -S #{@scratch}  -A #{@aggF} -a #{@apiDBRC} -r '#{CGI.escape(@roi)}' -u #{@userId} -R #{@removeNoData}"
      cmd << " > #{@scratch}/logs/matrix.log 2>#{@scratch}/logs/matrix.error.log "
      exitStatus = EXIT_OK
      $stderr.debugPuts(__FILE__, __method__, "Matrix tool command ", cmd)
      system(cmd)
      if($?.exitstatus == 113)
        exitStatus = 113
      else
        $stderr.debugPuts(__FILE__, __method__, "Done", "Building matrix ")
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Matrix tool completed with #{exitStatus}")
      return exitStatus
    end

    ##tar of output directory, usually LIMMA genearted result
    def compressFiles
      Dir.chdir("#{@scratch}/matrix")
      system("gzip matrix.xls")
      Dir.chdir(@scratch)
      Dir.chdir(@scratch)
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...
    def validateAndProcessArgs
      @trackSet     = @optsHash['--trackSet']
      @aggF         = @optsHash['--aggF']
      @roi          = @optsHash['--roiTrack']
      @analysis     = @optsHash['--analysisName']
      @scratch      = @optsHash['--scratch']
      @apiDBRC      = @optsHash['--apiDBRC']
      @userId       = @optsHash['--userId'].to_i
      @removeNoData = @optsHash['--removeNoData']

      case @optsHash["--resolution"]
        when "high"
          @resolution = 1000
        when "medium"
          @resolution = 10000
        when "low"
          @resolution = 100000
        else
          @resolution = 10000
      end
      @gbConfFile     = "/cluster.shared/local/conf/genboree/genboree.config.properties"
      @grph           = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
      @dbhelper       = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
      @trackhelper    = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)

      dbrc 	      = BRL::DB::DBRC.new(nil, @apiDBRC)
      @pass 	      = dbrc.password
      @user 	      = dbrc.user

      @tdb            = @dbhelper.extractName(@trackSet)
      @tGrp           = @grph.extractName(@trackSet)
      uri             = URI.parse(@trackSet)
      @host           = uri.host
      @path1          = uri.path.chomp('?')
    end
  end
end ; end # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
puts __FILE__
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::DriverLimmaSignalComparison)
end
