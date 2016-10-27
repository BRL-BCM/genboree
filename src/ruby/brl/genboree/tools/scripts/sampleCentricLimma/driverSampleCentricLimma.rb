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
  class DriverSampleCentricLimma < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--trackSet"    =>  [ :REQUIRED_ARGUMENT, "-t", "Input trackSets" ],
      "--roiTrack"    =>  [ :OPTIONAL_ARGUMENT, "-r", "ROI track" ],
      "--span"        =>  [ :REQUIRED_ARGUMENT, "-s", "Span size" ],
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
      "--printTaxanomy"=> [ :REQUIRED_ARGUMENT, "-P", "Print taxanomy" ],
      "--apiDBRC"     =>  [ :REQUIRED_ARGUMENT, "-a", "api DBRC key" ],
      "--attributes"  =>  [ :REQUIRED_ARGUMENT, "-T", "sample attributes for limma analysis" ],
      "--removeNoData"=>  [ :REQUIRED_ARGUMENT, "-N", "remove no data region" ],
      "--userId"      =>  [ :REQUIRED_ARGUMENT, "-U", "userID" ],
      "--aggF"        =>  [ :REQUIRED_ARGUMENT, "-g", "agg Function" ],
      "--type"        =>  [ :REQUIRED_ARGUMENT, "-C", "track type" ],
      "--subType"     =>  [ :REQUIRED_ARGUMENT, "-Q", "track subtype" ],
      "--sampleID"    =>  [ :REQUIRED_ARGUMENT, "-I", "Sample Id to map tracks and samples" ],
      "--db"          =>  [ :REQUIRED_ARGUMENT, "-d", "db of sample" ],
      "--help"        =>  [ :NO_ARGUMENT, "-h", "Help"]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Driver to run tool, which generates Limma results on epigenome data",
      :authors      => [ "Arpit Tandon" ],
      :examples => [
        "#{File.basename(__FILE__)} -t trackSets  -r 'http://genboree.org/REST/v1/grp/aa/db/bb/trk/CpG:Islands' -s AVG -S /scratch/test -R 10000 -f true -n true -o fdr -p 0.5 -M 0.5",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    DEBUG_CC = true
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
            exitStatus = runBuildMetadataTool()
            $stderr.debugPuts(__FILE__, __method__, "INFO","metadata creation exit status #{exitStatus}")

            if(exitStatus == 121)
              $stderr.debugPuts(__FILE__, __method__, "ERROR","Metadata couldn't be built")
              exitStatus = 121
            else
              $stderr.debugPuts(__FILE__, __method__, "Done","Metadata is created")
              # CC note: this is temporary, until the silly empty data bug is fixed
              exitStatus = runLimma()
              if(exitStatus != 0)
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "Limma tool didn't run properly")
                exitStatus = 114
              else
                $stderr.debugPuts(__FILE__, __method__, "Done", "Limma tool ran successfully")
                  # exitStatus = makeAtlasLink()
                 # if(exitStatus != 0)
                    # $stderr.debugPuts(__FILE__, __method__, "ERROR", "Making Atlas links failed")
                    # exitStatus = 116
                  #else
                exitStatus = compressFiles()
                if(exitStatus != 0)
                  $stderr.debugPuts(__FILE__, __method__, "ERROR", "Compression")
                  exitStatus = 116
                else
                  $stderr.debugPuts(__FILE__, __method__, "Done", "Compression")
                  #exitStatus = davidTool()
                  exitStatus = 0
                  if(exitStatus != 0)
                    $stderr.debugPuts(__FILE__, __method__, "ERROR", "David Tool Failed")
                    exitStatus = 118
                  else
                    $stderr.debugPuts(__FILE__, __method__, "Done", "DAVID TOOL")
                    exitStatus = makeAtlasLink()
                    $stderr.debugPuts(__FILE__, __method__, "Done #{exitStatus}", "Atlas Links")
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
      $stderr.debugPuts(__FILE__, __method__, "Status", "Driver completed with #{exitStatus}")
      return exitStatus
    end



    ##Download entityList
    ##And verify all the tracks are accessible
    def buildHashofVectorEntity()
      exitCode = 0
      @trkSetHash = {}
      tempFile  = File.open("#{@scratch}/tmpFile.txt","w+")
      ##Input can be either just track(s) or/and entityList(s)
      ##List of the track(s) from track(s) or/and entityList(s) in a single file
      resrH = BRL::Genboree::REST::Helpers::ApiUriHelper.new(@gbConfig)
      @trackSetArray = @trackSet.split(",")
      $stderr.debugPuts(__FILE__,__method__,"DEBUG",@trackSetArray.inspect)
      @trackSetArray.each{|track|
        uri  = URI.parse(track)
        host = uri.host
        path = uri.path
        ##If its entityList, list all the tracks from it in a file
        if(resrH.extractType(track) == "entityList")
          rcscUri = "#{path}/data?"
          rcscUri << "gbKey=#{@dbhelper.extractGbKey(track)}" if(@dbhelper.extractGbKey(track))
          apicaller = WrapperApiCaller.new(host,rcscUri,@userId)
          apicaller.get()
          if apicaller.succeeded?
            $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool", "1st trackSet downloaded successfully")
          else
            $stderr.debugPuts(__FILE__, __method__, "Build Matrix Tool- ERROR", apicaller.parseRespBody().inspect)
            exitCode = apicaller.apiStatusObj['statusCode']
          end
          apicaller.parseRespBody
          apicaller.apiDataObj.each { |obj|
            tempFile.puts obj['url']
            @trkSetHash[obj['url']] = ""
          }
          ## Else, its a track and just list it in the file
        else
          $stderr.debugPuts(__FILE__, __method__, "About to get #{host}--#{path}?connect=true", "") if (DEBUG_CC)
          rcscUri = "#{path}?connect=true"
          rcscUri << "&gbKey=#{@dbhelper.extractGbKey(track)}" if(@dbhelper.extractGbKey(track))
          apicaller = WrapperApiCaller.new(host,rcscUri,@userId)

          $stderr.debugPuts(__FILE__, __method__, "Build Hash Tool", apicaller.parseRespBody().inspect) if (DEBUG_CC)

          apicaller.get()
          tempFile.puts apicaller.parseRespBody["data"]["refs"][BRL::Genboree::REST::Data::DetailedTrackEntity::REFS_KEY]
          @trkSetHash[apicaller.parseRespBody["data"]["refs"][BRL::Genboree::REST::Data::DetailedTrackEntity::REFS_KEY]] = ""
        end
        }
      tempFile.close
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
          rcscUri = "#{path}?"
          rcscUri << "gbKey=#{@dbhelper.extractGbKey(key)}" if(@dbhelper.extractGbKey(key))
          api = WrapperApiCaller.new(host,rcscUri,@userId)
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
      @attributesArray = @attributes.split(",")
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

    ##Run build metadata file
    def runBuildMetadataTool()
      exitStatus = EXIT_OK
      $stderr.debugPuts(__FILE__, __method__, "Running ", "Building Metadata ")
      cmd = "buildMetadata.rb "
      cmd << " -t #{@scratch}/tmpFile.txt -a '#{CGI.escape(@attributes)}' -A #{@apiDBRC} -s #{@scratch} -u #{@userId} "
      cmd << " -d '#{CGI.escape(@db)}' -S #{CGI.escape(@sampleID)}"
      cmd << " >#{@scratch}/logs/metadata.log 2>#{@scratch}/logs/metadata.error.log"
      exitStatus = EXIT_OK
      $stderr.debugPuts(__FILE__, __method__, "Build Metadata tool command ", cmd)
      system(cmd)
      if($?.exitstatus != 0)
        exitStatus = 121
      else
        $stderr.debugPuts(__FILE__, __method__, "Done", "Building metadata ")
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Metadata tool completed with #{exitStatus}")
      return exitStatus
    end


    ##Calculate Combination. This is required to find the number of columns we need
    ##to read in *Multi-Comparison-Report.tsv. As this would depend on the multi-variable
    ## Calculate nC2
    ##attributes
    def combination(n)
       comb = (n-1)*n/2
       return comb
    end

    ##Number of unique variables in each attribute
    def uniqVar()
      file = File.open("#{@scratch}/metadata.txt")
      header = true
      @unqVarHash = Hash.new {|a,b| a[b] = Hash.new{|k,v| k[v] = [] }}
      @unqVarArr = []
      file.each {|line|
        line.strip!
        if(header)
          column = line.split(/\t/)
          column.delete("#name")
          column.each{|attr|
            @unqVarArr.push(attr)
            }
        else
          column = line.split(/\t/)
          for ii in 1 ... column.size
            @unqVarHash[@unqVarArr[ii-1]][column[ii]].push("a")
          end
        end
        header = false
        }
      file.close
    end


    ##run Limma tool
    def runLimma()
      uniqVar()
      $stderr.debugPuts(__FILE__, __method__, "Running", "Running Limma")
      @singletonArr = []
      @attributesArr.each{|arr|
        @unqVarHash[arr].each{|k,v|
           if(@unqVarHash[arr][k].size == 1)
             @singletonArr.push(1)
           end
        }
        $stderr.debugPuts(__FILE__, __method__, "Running LIMMA TOOL", "Running Limma for #{arr} attribute")
        system("mkdir -p #{@scratch}/#{arr}")
        cmd = "run_limma.rb "
        cmd << " -i #{@scratch}/matrix/matrix_Original.xls -m #{@scratch}/metadata.txt -o #{@scratch}/#{arr} -s #{@sortby} -p #{@minPval} -a #{@minAdjPVal} -f #{@minFoldCh}"
        cmd << " -e #{@minAveExp} -b #{@minBval} -T #{@testMethod} -A #{@adjustMethod} -x #{@multiplier} -t #{@printTaxa} -n #{@normalize} -c #{arr}"
        cmd << " >#{@scratch}/logs/#{arr}_limma.log 2>#{@scratch}/logs/#{arr}_limma.error.log"
        exitStatus = EXIT_OK
        $stderr.debugPuts(__FILE__, __method__, "Limma tool command ", cmd)
        system(cmd)
        if(!$?.success?)
          @exitCode = 114
        else
          $stderr.debugPuts(__FILE__, __method__, "Done", "Limma Tool")
        end
        ##running gene generation list
        generateGene(arr)
        }
      #exitStatus = 0
      #$stderr.debugPuts(__FILE__, __method__, "Status", "Limma tool completed with #{exitStatus}")
      return 0
    end

   ##run gene geration list
   def generateGene(attr)
      $stderr.debugPuts(__FILE__, __method__, "Generate Gene", attr)

      exitStatus = EXIT_OK
      multiComparisonFile = %x{ls #{@scratch}/#{attr}/*Multi-Comparison-Report.tsv}
      multiComparisonFile.strip!
      counter = 0
      @unqVarHash[attr].each{|k,v|
        counter += 1
        }
      columns = @unqVarHash[attr].size
      s = combination(columns)
      cmd ="convertlff.rb -f #{multiComparisonFile} -w #{@window.to_i} -c #{s} -t '#{@type}' -T '#{@subType}_#{attr}'"
      cmd <<" >#{@scratch}/logs/#{attr}_convertlff.log 2>#{@scratch}/logs/#{attr}_convertlff.error.log"
      $stderr.debugPuts(__FILE__, __method__, "Running", "Gene Intersection Tool I for #{attr}")
      $stderr.debugPuts(__FILE__, __method__, "LffIntersect Tool command ", cmd)
      exitStatus= system(cmd)

      ##Proceed only if find any classification among the samples
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
      if(nonBlank)
        # TODO : use full path file names, rather than the hacky and brittle dir.chdir improvisation
        Dir.chdir("#{@scratch}/#{attr}")
        # TODO: put this somewhere "official"
        cmd = "findGenes.rb -f #{multiComparisonFile}.lff -s /home/coarfa/forArpit/newMiRNAs-host-genes-hg19/hg19.wholeGenes.lff"
        cmd <<" >#{@scratch}/logs/#{attr}_new_generateGene.log 2>#{@scratch}/logs/#{attr}_new_generateGene.error.log"
        $stderr.debugPuts(__FILE__, __method__, "Running", "Finding Gene Tool II for #{attr}")
        $stderr.debugPuts(__FILE__, __method__, "Gene Finding Tool command ", cmd)
        system(cmd)
        exitStatus = $?.exitstatus
        Dir.chdir(@scratch)
      else
        exitStatus = 117
      end
      $stderr.debugPuts(__FILE__, __method__, "Status", "Gene generate TOOLS completed with #{exitStatus} for #{attr}")
      system("cd -")
      return exitStatus
   end

  ##tar of output directory, usually LIMMA genearted result
  def compressFiles
    exitStatus = EXIT_OK
    @attributesArray.each{|arr|
      $stderr.debugPuts(__FILE__, __method__, "Compression Begins" , "Begins")
      Dir.chdir("#{@scratch}/#{arr}")
      $stderr.debugPuts(__FILE__, __method__, "Compressing all input and results" , "#{arr} content")
      system("tar czf raw.results.tar.gz  * --exclude=*.xlsx --exclude=matrix.txt --exclude=metadata.txt")

      if(File.exists?("#{@scratch}/#{arr}/sorted_geneList.xls"))
        $stderr.debugPuts(__FILE__, __method__, "LIMMA found discriminating features, compressing spreadsheet results" , "#{arr} content")
        system("tar czf #{arr}.xlsx.tar.gz `find . -name '#{arr}*.xlsx'`")
      end
      Dir.chdir(@scratch)
    }
    return exitStatus
  end


  ##import atlas link to project area
  def makeAtlasLink()
    exitStatus = EXIT_OK
    cmd = "sampleCentricAtlasLink.rb -i #{@scratch}/ -j #{@scratch}/jobFile.json "
    cmd <<" >#{@scratch}/logs/import.log 2>#{@scratch}/logs/import.error.log"
    $stderr.debugPuts(__FILE__, __method__, "Running" , "Making links to Atlas")
    $stderr.debugPuts(__FILE__, __method__, "Import Tool command ", cmd)
    check = system(cmd)
    if (!check) then
      exitStatus = 115
    end
    return exitStatus
  end


  ##Calls DAVID tool
  def davidTool()
    davidToolStatus = true

    $stderr.debugPuts(__FILE__, __method__, "DAVID TOOL", "Runing for all attributes #{@attributesArr.join(",")}")
    @attributesArr.each{|arr|
      $stderr.debugPuts(__FILE__, __method__, "DAVID TOOL", "checking for  #{@scratch}/#{arr}/sorted_geneList.xls")
      system("ls -latrh #{@scratch}/#{arr}/sorted_geneList.xls")
      if(File.exists?("#{@scratch}/#{arr}/sorted_geneList.xls"))
        $stderr.debugPuts(__FILE__, __method__, "DAVID TOOL", "Runing for #{arr}")
        mkdirCommand = "mkdir -p #{@scratch}/DAVID/#{arr}"
        $stderr.debugPuts(__FILE__, __method__, "DAVID TOOL", "mkdir #{mkdirCommand}")

        check=system(mkdirCommand)
        $stderr.debugPuts(__FILE__, __method__, "DAVID TOOL", "mkdir #{mkdirCommand} check #{check}")


        cmd = "davidTool.rb -g #{@scratch}/#{arr}/sorted_geneList.xls -o #{@scratch}/DAVID/#{arr}"
        cmd <<" >#{@scratch}/logs/#{arr}_DAVID.log 2>#{@scratch}/logs/#{arr}_DAVID.error.log"
        $stderr.debugPuts(__FILE__, __method__, "DAVID TOOL Command", "#{cmd}")
        exitStatus = system(cmd)
        if (!exitStatus) then
          davidToolStatus = false
        end
      end
    }
      if(!davidToolStatus)
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

      @trackSet     = @optsHash['--trackSet']
      @span         = @optsHash['--span']
      @roi          = @optsHash['--roiTrack']
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
      @printTaxa    = @optsHash["--printTaxanomy"]
      @metadata     = @optsHash["--metaDataColumns"]
      @apiDBRC      = @optsHash['--apiDBRC']
      @attributes   = @optsHash['--attributes']
      @scratch      = @optsHash['--scratch']
      @userId       = @optsHash['--userId']
      @removeNoData = @optsHash['--removeNoData']
      @aggF         = @optsHash['--aggF']
      @type         = @optsHash['--type']
      @subType      = @optsHash['--subType']
      @sampleID     = @optsHash['--sampleID']
      @db           = @optsHash['--db']
      @attributesArr= @attributes.split(",")

      $stderr.debugPuts(__FILE__,__method__,"DEBUG",@attributes.inspect)
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
  BRL::Script::main(BRL::Script::DriverSampleCentricLimma)
end
