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
      "--trackSet1"   =>  [ :REQUIRED_ARGUMENT, "-t", "Input trackSet1" ],
      "--trackSet2"   =>  [ :REQUIRED_ARGUMENT, "-T", "Input trackSet2" ],
      "--roiTrack"    =>  [ :OPTIONAL_ARGUMENT, "-r", "ROI track" ],
      "--span"        =>  [ :REQUIRED_ARGUMENT, "-s", "Span size" ],
      "--lastTrkROI"  =>  [ :REQUIRED_ARGUMENT, "-l", "Last Track ROI" ],
      "--scratch"     =>  [ :REQUIRED_ARGUMENT, "-S", "Scratch area" ],
      "--resolution"  =>  [ :REQUIRED_ARGUMENT, "-R", "Resolution" ],
      "--normalize"   =>  [ :REQUIRED_ARGUMENT, "-n", "Normalize data" ],
      "--sortby"      =>  [ :REQUIRED_ARGUMENT, "-o", "Sort by" ],
      "--minPval"     =>  [ :REQUIRED_ARGUMENT, "-p", "Min P value" ],
      "--minAdjPval"  =>  [ :REQUIRED_ARGUMENT, "-M", "Min Adjusted P value" ],
      "--minFoldChange"=> [ :REQUIRED_ARGUMENT, "-F", "Min fold Change" ],
      "--minAveExp"   =>  [ :REQUIRED_ARGUMENT, "-e", "Min Average Exp" ],
      "--minBval"     =>  [ :REQUIRED_ARGUMENT, "-b", "Min B value" ],
      "--testMethod"  =>  [ :REQUIRED_ARGUMENT, "-m", "Test method" ],
      "--adjustMethod"=>  [ :REQUIRED_ARGUMENT, "-A", "Adjust Method" ],
      "--multiplier"  =>  [ :REQUIRED_ARGUMENT, "-E", "Multiplier" ],
      "--printTaxanomy"=> [ :OPTIONAL_ARGUMENT, "-P", "Print taxonomy" ],
      "--apiDBRC"     =>  [ :REQUIRED_ARGUMENT, "-a", "api DBRC key" ],
      "--type"        =>  [ :REQUIRED_ARGUMENT, "-Q", "track type" ],
      "--subType"     =>  [ :REQUIRED_ARGUMENT, "-c", "track sub-type" ],
      "--userId"      =>  [ :REQUIRED_ARGUMENT, "-u", "userId" ],
      "--help"        =>  [ :NO_ARGUMENT, "-h", "Help"]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Driver to run tool, which generates Limma results on epigenome data",
      :authors      => [ "Arpit Tandon" ],
      :examples => [
        "#{File.basename(__FILE__)} -t trackSet1 -T trackSet2 -r 'http://genboree.org/REST/v1/grp/aa/db/bb/trk/CpG:Islands' -s AVG -S /scratch/test -R 10000 -f true -n true -o fdr -p 0.5 -M 0.5",
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
      exitStatus = EXIT_OK
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running Driver .....")
        @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
        validateAndProcessArgs()
        system("mkdir -p #{@scratch}/matrix")
        system("mkdir -p #{@scratch}/signal-search/trksDownload")
        system("mkdir -p #{@scratch}/logs")
        if(File.exists?("#{@scratch}/matrix") and File.exists?("#{@scratch}/signal-search/trksDownload") and  File.exists?("#{@scratch}/logs"))
          exitStatus = buildHashofVectorEntity()
          $stderr.debugPuts(__FILE__, __method__, "ExitStatus",exitStatus)
          if(exitStatus != 0)
            $stderr.debugPuts(__FILE__, __method__, "ERROR","Some of the tracks are either removed or not accessible by user")
            exitStatus = 120
          else
            exitStatus = runBuildMatrixTool()
            if(exitStatus != 0)
              $stderr.debugPuts(__FILE__, __method__, "ERROR","Matrix couldn't be built")
              exitStatus = 113
            else
              $stderr.debugPuts(__FILE__, __method__, "Done","Matrix is created")
              exitStatus = runLimma()
              if(exitStatus != 0)
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "Limma tool didn't run properly")
                exitStatus = 114
              else
                $stderr.debugPuts(__FILE__, __method__, "Done", "Limma tool ran successfully")
                compressRawOutput()
                exitStatus = generateGene()
                if(exitStatus != 0)
                  if(exitStatus == 117)
                    $stderr.debugPuts(__FILE__, __method__, "Done", "No classification found")
                  else
                    $stderr.debugPuts(__FILE__, __method__, "ERROR", "Gene list couldn't be created")
                    exitStatus = 115
                  end
                else
                  $stderr.debugPuts(__FILE__, __method__, "Done", "Gene list is created")
                  exitStatus = compressFiles
                  if(exitStatus != 0)
                    $stderr.debugPuts(__FILE__, __method__, "ERROR", "Compression failed")
                    exitStatus = 116
                  else
                    $stderr.debugPuts(__FILE__, __method__, "Done", "Compression")
                    exitStatus = 0
                    # exitStatus = davidTool()
                    if(exitStatus != 0)
                      $stderr.debugPuts(__FILE__, __method__, "ERROR", "David Tool Failed")
                      exitStatus = 118
                    else
                      $stderr.debugPuts(__FILE__, __method__, "Done", "DAVID TOOL")
                      #exitStatus = makeAtlasLink()
                      #if (exitStatus!=0) then
                      #  exitStatus = 115
                      #end
                    end
                  end
                end
              end
            end
          end
        else
          $stderr.debugPuts(__FILE__, __method__, "Status", "Dir generation failed")
          exitStatus = 119
        end
      rescue => err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 121
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Driver completed with #{exitStatus}")
      return exitStatus
    end

    ##Download file tracklist
    def buildHashofVectorFile()
      exitStatus=EXIT_OK
      begin
        tempFile1 = File.open("#{@scratch}/tmpFile1.txt","w+")
        tempFile2 = File.open("#{@scratch}/tmpFile2.txt","w+")
        tmpPath = "#{@path1}/data?"
        tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(@trackSet1)}" if(@dbApiHelper.extractGbKey(@trackSet1))
        apicaller = WrapperApiCaller.new(@host,tmpPath,@userId)
        apicaller.get() {| chunk|
          tempFile1.write chunk
        }
        tempFile1.close
        if apicaller.succeeded?
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "1st trackSet downloaded successfully")
        else
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool- ERROR", apicaller.parseRespBody().inspect)
          @exitCode = apicaller.apiStatusObj['statusCode']
          raise "Error downloading first trackSet"
        end
        tmpPath = "#{@path2}/data?"
        tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(@trackSet2)}" if(@dbApiHelper.extractGbKey(@trackSet2))
        apicaller = WrapperApiCaller.new(@host,tmpPath,@userId)
        apicaller.get() {| chunk|
          tempFile2.write chunk
        }
        tempFile2.close
        if apicaller.succeeded?
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "2nd trackSet downloaded successfully")
        else
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool -ERROR", apicaller.parseRespBody().inspect)
          @exitCode = apicaller.apiStatusObj['statusCode']
          raise "Error downloading second trackSet"
        end
      rescue => err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 120
      end
      return exitStatus
    end


    ##Download entityList
    ##And verify all the tracks are accessible
    def buildHashofVectorEntity()
      exitCode = 0
      begin
        @trkSetHash = {}
        tempFile1 = File.open("#{@scratch}/tmpFile1.txt","w+")
        tempFile2 = File.open("#{@scratch}/tmpFile2.txt","w+")
        tmpPath = "#{@path1}/data?"
        tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(@trackSet1)}" if(@dbApiHelper.extractGbKey(@trackSet1))
        apicaller = WrapperApiCaller.new(@host,tmpPath,@userId)
        apicaller.get()
        if apicaller.succeeded?
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "1st trackSet downloaded successfully")
        else
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool- ERROR", apicaller.parseRespBody().inspect)
          exitCode = apicaller.apiStatusObj['statusCode']
          raise "Error downloading first trackSet"
        end
        apicaller.parseRespBody
        apicaller.apiDataObj.each { |obj|
          tempFile1.puts obj['url']
          @trkSetHash[obj['url']] = ""
        }
        tempFile1.close
        tmpPath = "#{@path2}/data?"
        tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(@trackSet2)}" if(@dbApiHelper.extractGbKey(@trackSet2))
        apicaller = WrapperApiCaller.new(@host,tmpPath,@userId)
        apicaller.get()
        if apicaller.succeeded?
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "2nd trackSet downloaded successfully")
        else
          $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool -ERROR", apicaller.parseRespBody().inspect)
          exitCode = apicaller.apiStatusObj['statusCode']
          raise "Error downloading second trackSet"
        end
        apicaller.parseRespBody
        apicaller.apiDataObj.each { |obj|
          tempFile2.puts obj['url']
          @trkSetHash[obj['url']] = ""
        }
        tempFile2.close

        ## Checking if THE TRACKS in entitylist EXIST and are ACCESSIBLE by the user
        exitCode = tracksAccessible?(@trkSetHash)
      rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 120
      end
      return exitCode
    end

    ## To ensure AlL THE TRACKS in entitylist EXIST and are ACCESSIBLE by the user
    def tracksAccessible?(trkSetHash)
      exitStatus = 0
      begin
       trkSetHash.each_key{|key|
         uri = URI.parse(key)
         host= uri.host
         path = uri.path
         path << "?gbKey=#{@dbApiHelper.extractGbKey(key)}" if(@dbApiHelper.extractGbKey(key))
         api = WrapperApiCaller.new(host,"#{path}",@userId)
         api.get
         if(!api.succeeded?)
           exitStatus = 120
           $stderr.debugPuts(__FILE__, __method__, "#{File.basename(path)}", api.parseRespBody().inspect)
           raise "Error checking accessibility of track #{key}"
           break
         else
           $stderr.debugPuts(__FILE__, __method__, "Track Access", "#{File.basename(path)} is accessible")
         end
       }
       rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 120
      end
      return exitStatus
    end


    ##run buildMatrix tool
    def runBuildMatrixTool()
      exitStatus = 0
      begin
      $stderr.debugPuts(__FILE__, __method__, "Running ", "Building Matrix")
      cmd ="limmaSignalComparison.rb "
      cmd << " -t '#{CGI.escape(@trackSet1)}' -T '#{CGI.escape(@trackSet2)}' -S #{@scratch}  -s #{@span}  -a #{@apiDBRC} -u #{@userId} "
      if(@lastRoi == "true")
        cmd <<" -r '#{CGI.escape(@roi)}' "
      end
      cmd << " > #{@scratch}/logs/epigenomeTool.log 2>#{@scratch}/logs/epigenomeTool.error.log "
      $stderr.debugPuts(__FILE__, __method__, "Matrix tool command ", cmd)
      system(cmd)
      if($?.exitstatus != 0)
        exitStatus = 113
      else
        $stderr.debugPuts(__FILE__, __method__, "Done", "Building matrix ")
      end
      rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 113
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Matrix tool completed with #{exitStatus}")
      return exitStatus
    end

    ##run Limma tool
   def runLimma()
    exitStatus = 0
    $stderr.debugPuts(__FILE__, __method__, "Running", "Running Limma")
    begin
    cmd = "run_limma.rb "
    cmd << " -i #{@scratch}/matrix/matrix.txt -m #{@scratch}/matrix/metadata.txt -o #{@scratch}/matrix -s #{@sortby} -p #{@minPval} -a #{@minAdjPVal} -f #{@minFoldCh}"
    cmd << " -e #{@minAveExp} -b #{@minBval} -T #{@testMethod} -A #{@adjustMethod} -x #{@multiplier} -t #{@printTaxa} -n #{@normalize} -c 'class'"
    cmd << " >#{@scratch}/logs/limma.log 2>#{@scratch}/logs/limma.error.log"
    
    $stderr.debugPuts(__FILE__, __method__, "Limma tool command ", cmd)
    system(cmd)
    if(!$?.success?)
      exitStatus = 114
    else
      $stderr.debugPuts(__FILE__, __method__, "Done", "Limma Tool")
    end
    rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 114
    end
    $stderr.debugPuts(__FILE__, __method__, "Status", "Limma tool completed with #{exitStatus}")
    return exitStatus
   end

   ##run gene geration list
   def generateGene()
      exitStatus = EXIT_OK
      begin
      multiComparisonFile = %x{ls #{@scratch}/matrix/*Multi-Comparison-Report.tsv}
      multiComparisonFile.strip!
      cmd ="convertlff.rb -f #{multiComparisonFile} -w #{@window.to_i} -c 1 -t '#{@type}' -T '#{@subType}' "
      cmd <<" >#{@scratch}/logs/convertlff.log 2>#{@scratch}/logs/convertlff.error.log"
      $stderr.debugPuts(__FILE__, __method__, "Running", "Gene Intersection Tool I")
      $stderr.debugPuts(__FILE__, __method__, "LffIntersect Tool command ", cmd)
      system(cmd)
      
      if($?.exitstatus!= 0) then raise "Lff Intersection encountered an error" end
      ##Proceed only if find any classification among the samples
      ## CC
      #nonBlank = false
      #if(File.exists?("#{multiComparisonFile}.lff"))
      #  fileNameHandle = File.open("#{multiComparisonFile}.lff")
      #  fileNameHandle.each { |ll|
      #    if(ll =~ /\S/)
      #      nonBlank = true
      #      break
      #    end
      #    }
      #end
      ## CC
      nonBlank = discriminantFeaturesFound()
      if(nonBlank)
        Dir.chdir("#{@scratch}/matrix")
        cmd ="findGenes.rb -f #{multiComparisonFile}.lff -s /home/coarfa/forArpit/newMiRNAs-host-genes-hg19/hg19.wholeGenes.lff"
        cmd <<" >#{@scratch}/logs/new_generateGene.log 2>#{@scratch}/logs/new_generateGene.error.log"
        $stderr.debugPuts(__FILE__, __method__, "Running", "Finding Gene Tool II")
        $stderr.debugPuts(__FILE__, __method__, "Gene Finding Tool command ", cmd)
        system(cmd)
        exitStatus = $?.exitstatus
        if(exitStatus !=0) then raise "Finding Genes Tool encountered an error" end
        ##import atlas link to project area
        ## CC
         exitStatus=makeAtlasLink()
         if(exitStatus !=0) then raise "Unable to create Atlas link" end
         
        # cmd = "makeAtlasLink.rb -i #{@scratch}/matrix -j #{@scratch}/jobFile.json"
        #cmd <<" >#{@scratch}/logs/import.log 2>#{@scratch}/logs/import.error.log"
        # $stderr.debugPuts(__FILE__, __method__, "Running" , "Making links to Atlas")
        #$stderr.debugPuts(__FILE__, __method__, "Import Tool command ", cmd)
        # exitStatus = system(cmd)
        # exitStatus = 0
        exitStatus = 0
      else
        exitStatus = 117
      end
    rescue=> err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 115
    end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Gene generate TOOLS completed with #{exitStatus}")
      return exitStatus
   end

  # check if any discriminant features were found by LIMMA
  def discriminantFeaturesFound()
    multiComparisonFile = %x{ls #{@scratch}/matrix/*Multi-Comparison-Report.tsv}
    multiComparisonFile.strip!
    nonBlank = false
    if(File.exists?("#{multiComparisonFile}.lff"))
      fileNameHandle = File.open("#{multiComparisonFile}.lff")
      fileNameHandle.each { |ll|
        if(ll =~ /\S/)
          nonBlank = true
          break
        end
        }
    end
    return nonBlank
  end

  # make the Atlas link, including GO results
  def makeAtlasLink()
    ##import atlas link to project area
    exitStatus = EXIT_OK
    cmd = "makeAtlasLink.rb -i #{@scratch}/matrix -j #{@scratch}/jobFile.json "
    cmd <<" >#{@scratch}/logs/import.log 2>#{@scratch}/logs/import.error.log"
    $stderr.debugPuts(__FILE__, __method__, "Running" , "Making links to Atlas")
    $stderr.debugPuts(__FILE__, __method__, "Import Tool command ", cmd)
    exitStatus = system(cmd)
    return $?.exitstatus
  end

   ## generic archive of output directory, regardless whether LIMMA succeeded or not
  def compressRawOutput()
    Dir.chdir("#{@scratch}/matrix")
    system("zip raw.results.zip  * -x *.xlsx -x matrix.txt -x metadata.txt")
    Dir.chdir(@scratch)
  end

  ##tar of output directory, if LIMMA found discriminant features
  def compressFiles
    Dir.chdir("#{@scratch}/matrix")
    system("zip class*.xlsx.zip `find . -name 'class*.xlsx'`")
    Dir.chdir(@scratch)
  end

  ##Calls DAVID tool
  def davidTool
    cmd = "davidTool.rb -g #{@scratch}/matrix/sorted_geneList.xls -o #{@scratch}/DAVID"
    cmd <<" >#{@scratch}/logs/DAVID.log 2>#{@scratch}/logs/DAVID.error.log"
    $stderr.debugPuts(__FILE__, __method__, "DAVID Tool" , "cmd #{cmd}")
    exitStatus = system(cmd)
    if(!$?.success?)
      return 118
    else
      return 0
    end
  end
    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...

    def validateAndProcessArgs

      @trackSet1    = @optsHash['--trackSet1']
      @trackSet2    = @optsHash['--trackSet2']
      @span         = @optsHash['--span']
      @roi          = @optsHash['--roiTrack']
      @lastRoi      = @optsHash['--lastTrkROI']
      @normalize    = @optsHash['--normalize']
      @analysis     = @optsHash['--analysisName']
      @sortby       = @optsHash["--sortby"]
      @minPval      = @optsHash["--minPval"]
      @minAdjPVal   = @optsHash["--minAdjPval"]
      @minFoldCh    = @optsHash["--minFoldChange"]
      @minAveExp    = @optsHash["--minAveExp"]
      @minBval      = @optsHash["--minBval"]
      @testMethod   = @optsHash["--testMethod"]
      @adjustMethod = @optsHash["--adjustMethod"]
      @multiplier   = @optsHash["--multiplier"]
      # @printTaxa    = @optsHash["--printTaxanomy"]
      @printTaxa = 0
      # CC: we do not need the taxonomic aspect for the Epigenomic Analysis
      @metadata     = @optsHash["--metaDataColumns"]
      @apiDBRC      = @optsHash['--apiDBRC']
      @scratch      = @optsHash['--scratch']
      @type         = @optsHash['--type']
      @subType      = @optsHash['--subType']
      @userId = @optsHash['--userId']

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
      @path1          = uri.path.chomp('?')
      uri             = URI.parse(@trackSet2)
      @path2          = uri.path.chomp('?')

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
