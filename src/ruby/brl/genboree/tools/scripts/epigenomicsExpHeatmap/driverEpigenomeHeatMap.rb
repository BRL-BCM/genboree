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

include BRL::Genboree::REST

# Write sub-class of BRL::Script::ScriptDriver
module BRL ; module Script
  class DriverEpigenomeHeatMap < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--trackSet1" =>  [ :REQUIRED_ARGUMENT, "-t", "Input trackSet1" ],
      "--trackSet2" =>  [ :REQUIRED_ARGUMENT, "-T", "Input trackSet2" ],
      "--roiTrack"  =>  [ :OPTIONAL_ARGUMENT, "-r", "ROI track" ],
      "--span"      =>  [ :REQUIRED_ARGUMENT, "-s", "Span size" ],
      "--lastTrkROI"=>  [ :REQUIRED_ARGUMENT, "-l", "Last Track ROI" ],
      "--scratch"   =>  [ :REQUIRED_ARGUMENT, "-S", "Scratch area" ],
      "--resolution"=>  [ :REQUIRED_ARGUMENT, "-R", "Resolution" ],
      "--filtering" =>  [ :REQUIRED_ARGUMENT, "-f", "Remove zeroes from the data" ],
      "--normalize" =>  [ :REQUIRED_ARGUMENT, "-n", "Normalize data" ],
      "--dendogram" =>  [ :REQUIRED_ARGUMENT, "-d", "Dendogram" ],
      "--distfun"   =>  [ :REQUIRED_ARGUMENT, "-F", "Distance Function" ],
      "--hclustFun" =>  [ :REQUIRED_ARGUMENT, "-H", "Cluster Function" ],
      "--key"       =>  [ :REQUIRED_ARGUMENT, "-k", "key" ],
      "--keySize"   =>  [ :REQUIRED_ARGUMENT, "-K", "Key size" ],
      "--trace"     =>  [ :REQUIRED_ARGUMENT, "-C", "Trace" ],
      "--color"     =>  [ :REQUIRED_ARGUMENT, "-c", "Color" ],
      "--density"   =>  [ :REQUIRED_ARGUMENT, "-D", "Density" ],
      "--height"    =>  [ :REQUIRED_ARGUMENT, "-e", "Height" ],
      "--width"     =>  [ :REQUIRED_ARGUMENT, "-w", "width" ],
      "--apiDBRC"   =>  [ :REQUIRED_ARGUMENT, "-a", "api DBRC key" ],
      "--userId"   =>   [ :REQUIRED_ARGUMENT, "-u", "userId" ],
      "--help"      =>  [ :NO_ARGUMENT, "-h", "Help"]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Driver to run tool, which generates heatmap on sets of epigenomic experiments",
      :authors      => [ "Arpit Tandon" ],
      :examples => [
        "#{File.basename(__FILE__)} -t trackSet1 -T trackSet2 -r 'http://genboree.org/REST/v1/grp/aa/db/bb/trk/CpG:Islands' -s AVG -S /scratch/test -R 10000 -f true -n true -d  none -F both -H dist -G hclust -K TRUE -C Trace -D 10 -w 8 -e 10",
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
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      exitStatus = EXIT_OK
      validateAndProcessArgs()
      ## Make sure mkdir works
      system("mkdir -p #{@scratch}/matrix")
      system("mkdir -p #{@scratch}/signal-search/trksDownload")
      system("mkdir -p #{@scratch}/logs")
      if(File.exists?("#{@scratch}/matrix") and File.exists?("#{@scratch}/signal-search/trksDownload") and  File.exists?("#{@scratch}/logs"))
        exitStatus = buildHashofVectorEntity()
        if(exitStatus == 120)
          $stderr.debugPuts(__FILE__, __method__, "Some of the tracks in your EntityLists were either deleted, renamed, or now reside in a different group or database. They are not accessible as-is.")
          exitStatus = 120
        else
          exitStatus = runBuildMatrixTool()
          if(exitStatus == 113)
            $stderr.debugPuts(__FILE__, __method__, "ERROR","Matrix couldn't be built")
          else
            $stderr.debugPuts(__FILE__, __method__, "Done","Matrix is created")
            exitStatus = runHeatMapTool()
            if(exitStatus == 114)
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "HeatMaps couldn't be generated")
            else
              $stderr.debugPuts(__FILE__, __method__, "Done","Heatmap tool ran successfully")
              exitStatus = runImportTool()
              if(exitStatus == 115)
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "Files couldn't be imported to project area")
              else
                $stderr.debugPuts(__FILE__, __method__, "Done","Files imported")
                svdExitStatus = computeSVD()
                if(svdExitStatus != EXIT_OK) then
                  $stderr.debugPuts(__FILE__, __method__, "ERROR", "SVD computation did not succeed")
                else
                  $stderr.debugPuts(__FILE__, __method__, "Done", "SVD computed successfully")
                end
              end
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

    ##Download file tracklist
    def buildHashFile()
      @exitCode = 0
      tempFile1 = File.open("#{@scratch}/tmpFile1.txt","w+")
      tempFile2 = File.open("#{@scratch}/tmpFile2.txt","w+")
      encodedUri = @trackSet1
      tmpPath = "#{@path1}/data?"
      tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(encodedUri)}" if(@dbApiHelper.extractGbKey(encodedUri))
      apicaller = WrapperApiCaller.new(@host,tmpPath,@userId)
      apicaller.get() {| chunk|
        tempFile1.write chunk
        }
      tempFile1.close
      if apicaller.succeeded?
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "1st trackSet downloaded successfully")
      else
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool- Error", apicaller.parseRespBody().inspect)
        @exitCode = apicaller.apiStatusObj['statusCode']
      end
      encodedUri2 = @trackSet2
      tmpPath = "#{@path2}/data?"
      tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(encodedUri2)}" if(@dbApiHelper.extractGbKey(encodedUri2))
      apicaller = WrapperApiCaller.new(@host,tmpPath,@userId)
      apicaller.get() {| chunk|
        tempFile2.write chunk
        }
      tempFile2.close
      if apicaller.succeeded?
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "2nd trackSet downloaded successfully")
      else
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool- Error", apicaller.parseRespBody().inspect)
        @exitCode = apicaller.apiStatusObj['statusCode']
      end
      return @exitCode
     end


    ##Download entityList
    ##And verify all the tracks are accessible
    def buildHashofVectorEntity()
      exitCode = 0
      @trkSetHash = {}
      tempFile1 = File.open("#{@scratch}/tmpFile1.txt","w+")
      tempFile2 = File.open("#{@scratch}/tmpFile2.txt","w+")
      encodedUri = @trackSet1
      tmpPath = "#{@path1}/data?"
      tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(encodedUri)}" if(@dbApiHelper.extractGbKey(encodedUri))
      apicaller = WrapperApiCaller.new(@host,tmpPath,@userId)
      apicaller.get()
      if apicaller.succeeded?
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "1st trackSet downloaded successfully")
      else
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool- ERROR", apicaller.parseRespBody().inspect)
        exitCode = apicaller.apiStatusObj['statusCode']
      end
      apicaller.parseRespBody
      apicaller.apiDataObj.each { |obj|
        tempFile1.puts obj['url']
        @trkSetHash[obj['url']] = ""
      }
      tempFile1.close
      encodedUri2 = @trackSet2
      tmpPath = "#{@path2}/data?"
      tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(encodedUri2)}" if(@dbApiHelper.extractGbKey(encodedUri2))
      apicaller = WrapperApiCaller.new(@host,tmpPath,@userId)
      apicaller.get()
      if apicaller.succeeded?
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "2nd trackSet downloaded successfully")
      else
        $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool -ERROR", apicaller.parseRespBody().inspect)
        exitCode = apicaller.apiStatusObj['statusCode']
      end
      apicaller.parseRespBody
      apicaller.apiDataObj.each { |obj|
        tempFile2.puts obj['url']
        @trkSetHash[obj['url']] = ""
      }
      tempFile2.close

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


    ##To call the build matrix tool
    def runBuildMatrixTool()
      $stderr.debugPuts(__FILE__, __method__, "Running ", "Building Matrix")
      cmd ="epigenomeHeatMapTool.rb "
      cmd << " -t '#{CGI.escape(@trackSet1)}' -T '#{CGI.escape(@trackSet2)}' -S #{CGI.escape(@scratch)}  -s #{CGI.escape(@span)} -R #{CGI.escape(@resolution)} -a #{CGI.escape(@apiDBRC)}"
      cmd << " -f #{CGI.escape(@filter)} -n #{CGI.escape(@normalize)}  -u #{@userId} "
      if(@lastRoi == "true")
        cmd <<" -r '#{CGI.escape(@roi)}' "
      end
      cmd << " > #{@scratch}/logs/epigenomeTool.log 2>#{@scratch}/logs/epigenomeTool.error.log "
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

    ## To call the heatmap tool
    def runHeatMapTool()
      ##Reverse order Color schene
      @color = "#5E4FA2,#3288BD,#66C2A5,#ABDDA4,#E6F598,#FFFFBF,#FEE08B,#FDAE61,#F46D43,#D53E4F,#9E0142"
      $stderr.debugPuts(__FILE__, __method__, "Running", "HeatMap Tool")
      cmd = "generic_make_2D_heatmap.rb -i #{@scratch}/matrix/matrix.txt -o #{@scratch} -d #{@dendogram} -f #{@distfun} -h #{@hclustFun} -k #{@key} -s #{@keySize.to_f} "
      cmd << "-t #{@trace} -y #{@density} -c '#{@color}' -H #{@height} -W #{@width}"
      cmd << " > #{@scratch}/logs/heatmapTool.log 2>#{@scratch}/logs/heatmapTool.error.log "
      exitStatus = EXIT_OK
      $stderr.debugPuts(__FILE__, __method__, "Heatmap tool command ", cmd)
      system(cmd)
      if($?.exitstatus != 0)
        exitStatus = 114
      else
        $stderr.debugPuts(__FILE__, __method__, "Done", "HeatMap Tool")
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Heatmap tool completed with #{exitStatus}")
      return exitStatus
    end

        ## To compute the svd
    def computeSVD()
      $stderr.debugPuts(__FILE__, __method__, "Running", "SVD computation")
      cmd = "computeSVD.rb -i #{@scratch}/matrix.txt.fixed -o #{@scratch}"
      cmd << " > #{@scratch}/logs/svdTool.log 2>#{@scratch}/logs/svdTool.error.log "
      exitStatus = EXIT_OK
      $stderr.debugPuts(__FILE__, __method__, "SVD tool command ", cmd)
      system(cmd)
      if($?.exitstatus != 0)
        exitStatus = 114
      else
        $stderr.debugPuts(__FILE__, __method__, "Done", "SVD Tool")
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "SVD tool completed with #{exitStatus}")
      return exitStatus
    end
    
    # To import heatmap to atlas area
    def runImportTool()
      $stderr.debugPuts(__FILE__, __method__, "Running", "Import Tool")
      cmd ="importHeatmap.rb "
      cmd <<" -i #{@scratch} -j #{@scratch}/jobFile.json"
      cmd << " > #{@scratch}/logs/importTool.log 2>#{@scratch}/logs/importTool.error.log "
      $stderr.debugPuts(__FILE__, __method__, "Imort Tool command ", cmd)
      exitStatus = EXIT_OK
      system(cmd)
      if($?.exitstatus == 113)
        exitStatus = 115
      else
        $stderr.debugPuts(__FILE__, __method__, "Done", "Import Tool")
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Import tool completed with #{exitStatus}")
      return  exitStatus
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...

    def validateAndProcessArgs

      @trackSet1  = @optsHash['--trackSet1']
      @trackSet2  = @optsHash['--trackSet2']
      @span       = @optsHash['--span']
      @roi        = @optsHash['--roiTrack']
      @filter     = @optsHash['--filtering']
      @lastRoi    = @optsHash['--lastTrkROI']
      @normalize  = @optsHash['--normalize']
      @analysis   = @optsHash['--analysisName']
      @dendogram  = @optsHash['--dendogram']
      @distfun    = @optsHash['--distfun']
      @hclustFun  = @optsHash['--hclustFun']
      @key        = @optsHash['--key']
      @keySize    = @optsHash['--keySize']
      @trace      = @optsHash['--trace']
      @color      = @optsHash['--color']
      @density    = @optsHash['--density']
      @height     = @optsHash['--height']
      @width      = @optsHash['--width']
      @apiDBRC    = @optsHash['--apiDBRC']
      @scratch    = @optsHash['--scratch']
      @userId     = optsHash['--userId']
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

      @tdb            = @dbhelper.extractName(@trackSet1)
      @tGrp           = @grph.extractName(@trackSet1)
      uri             = URI.parse(@trackSet1)
      @host           = uri.host
      @path1          = (uri.path.chomp('?'))
      uri             = URI.parse(@trackSet2)
      @path2          = (uri.path.chomp('?'))
      
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
  BRL::Script::main(BRL::Script::DriverEpigenomeHeatMap)
end
