#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/tools/toolWrapper'

include GSL
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class QiimeWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { 
      '--inputFile' => [GetoptLong::REQUIRED_ARGUMENT, '-j', ""]
    }
    DESC_AND_EXAMPLES = {
      :description => "Run QIIME on the inputFile",
      :authors => [ "Arpit Tandon", "Aaron Baker (ab4@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
  
    # Extract relevant information to run the job
    # @todo TODO a lot of these instance variables are redundant references to @settings or @context
    #   and could just be used as such rather than making a whole new variable
    def processJobConf()
      begin
        @exitCode = 0

        # based on parent
        @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)

        # outputs section of inputFile is unordered, find db and project (if any)
        @outputs.each{|output|
          if(output =~ BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP)
            @output = output
          elsif(output =~ BRL::Genboree::REST::Helpers::ProjectApiUriHelper::NAME_EXTRACTOR_REGEXP)
            @outputProj = output 
          else
            raise ArgumentError, "inputFile has unrecognized output URIs"
          end
        }
        @output   = @output.chomp('?')
        @dbOutput = @dbApiHelper.extractName(@output)
        @grpOutput = @grpApiHelper.extractName(@output)
        uriOutput = URI.parse(@output)
        @hostOutput = uriOutput.host
        @pathOutput = uriOutput.path

        # generic settings 
        @jobName            = @settings["jobName"]
        @studyName          = @settings["studyName"]
        @jobName1   = CGI.escape(@jobName)
        @jobName      = @jobName1.gsub(/%[0-9a-f]{2,2}/i, "_")
        @studyName1   = CGI.escape(@studyName)
        @studyName    = @studyName1.gsub(/%[0-9a-f]{2,2}/i, "_")

        # qiime settings
        @createTaxaSummaries    = @settings["createTaxaSummaries"]
        @runAlphaDiversityFlag  = @settings["runAlphaDiversityFlag"]
        @otuFastMethod        = @settings["otuFastMethod"]
        @runBetaDiversityFlag = @settings["runBetaDiversityFlag"]
        @assignTaxonomyMethod = @settings["assignTaxonomyMethod"]
        @createPhylogeneticTreeFlag = @settings["createPhylogeneticTreeFlag"]
        @makeTreeMethod     = @settings["makeTreeMethod"]
        @runAlphaDiversityFlag  = @settings["runAlphaDiversityFlag"]
        @runLoopWithNormalizedDataFlag = @settings["runLoopWithNormalizedDataFlag"]
        @alphaMetrics       = @settings["alphaMetrics"]
        @otuSlowMethod        = @settings["otuSlowMethod"]
        @alignmentMethod      = @settings["alignmentMethod"]
        @createOTUnetworkFlag = @settings["createOTUnetworkFlag"]
        @createHeatmapFlag    = @settings["createHeatmapFlag"]
        @removeChimeras     = @settings["removeChimeras"]
        if(@removeChimeras == true)
          @removeChimeras = 1
        else
          @removeChimeras = 0
        end
        @createOTUtableFlag   = @settings["createOTUtableFlag"]
        @assignTaxonomyMinConfidence = @settings["assignTaxonomyMinConfidence"]
        @qiimeVersion       = @settings["qiimeVersion"]
        @alignSeqsMinLen      = @settings["alignSeqsMinLen"]
        @betaMetrics        = @settings["betaMetrics"]

        # context
        @apiDBRCkey   = @context["apiDbrcKey"]
    
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = "ERROR: Could not set up required variables for running job. Check your jobFile.json to make sure all variables are defined."
        @exitCode = 22
      end

      return @exitCode
    end
  
    def run()
      begin
        @exitCode = 0
        fileApiHelper = BRL::Genboree::REST::Helpers::FileApiUriHelper.new(@dbu, @genbConf)
        system("mkdir -p #{@scratchDir}")
        Dir.chdir(@scratchDir)
        @outputDir = "#{@scratchDir}/#{@jobName}"
        system("mkdir -p #{@outputDir}")

        # clear metadata file if it exists already
        metaPath = "#{@outputDir}/metadata.txt"
        File.open(metaPath, "w"){|ff|
          ff.write("")
        }
        for i in 0...@inputs.size
          $stdout.puts "#{Time.now.to_s}: downloading metadata and filtered files from #{File.basename(@inputs[i])}"
          $stderr.puts "#{Time.now.to_s}: downloading metadata and filtered files from #{File.basename(@inputs[i])}"

          # download filtered sequence files
          @inputs[i] = @inputs[i].chomp('?')
          uriObj = URI.parse(@inputs[i])
          fastaArchivePath = "#{uriObj.path.gsub(/\/files\//,'/file/')}/filtered_fasta.result.tar.gz?"
          fastaArchivePath << "gbKey=#{@dbApiHelper.extractGbKey(@inputs[i])}" if(@dbApiHelper.extractGbKey(@inputs[i]))
          uriToDownload = "#{uriObj.scheme}://#{uriObj.host}#{fastaArchivePath}"
          outputFile = "#{@outputDir}/#{File.basename(@inputs[i])}.tar.gz"
          fileDownloaded = fileApiHelper.downloadFile(uriToDownload, @userId, outputFile, @hostAuthMap, noOfAttempts=10, mode="w+")
          unless(fileDownloaded)
            @exitCode = 23
            @errUserMsg = "Unable to download file #{uriToDownload}. Cannot proceed with QIIME job."
            @errInternalMsg = @errUserMsg
            @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
            raise @err
          end
  
          # extract sequence files
          Dir.chdir(@outputDir)
          system("tar -zxf #{@outputDir}/#{File.basename(@inputs[i])}.tar.gz")
          Dir.chdir(@scratchDir)
    
          # download metadata file -- append to our file at metaPath
          metadataPath = "#{uriObj.path.gsub(/\/files\//,'/file/')}/sample.metadata"
          uriToDownload = "#{uriObj.scheme}://#{uriObj.host}#{metadataPath}"
          fileDownloaded = fileApiHelper.downloadFile(uriToDownload, @userId, metaPath, @hostAuthMap, noOfAttempts=10, mode="a+")
          unless(fileDownloaded)
            @exitCode = 24
            @errUserMsg = "Unable to download file #{uriToDownload}. Cannot proceed with QIIME job."
            @errInternalMsg = @errUserMsg
            @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
            raise @err
          end
        end
        $stderr.puts "#{Time.now.to_s}: downloading done."
    
        # clean metadata file by replacing missing values with "no-Value" string
        cleanedMetaPath = "#{@outputDir}/tmp.metadata.txt"
        self.class.cleanTsvFile(metaPath, cleanedMetaPath, "no-Value")
        system(" mv #{cleanedMetaPath} #{@outputDir}/metadata.txt ")
    
        # look for minSeqLength value and assigning alignSeqsMinLen accordingly
        fileSeq = File.open("#{@outputDir}/metadata.txt")
        lineNo = 0
        it = 0
        minSeqArray = []
        fileSeq.each_line {|line|
          columns = line.split(/\t/)
          if (lineNo == 0)
            for it in 0 ... columns.size
              if(columns[it] == "minseqLength")
                # upon breaking, {it} is the column number for minseqLength
                break;
              end
            end
          elsif (lineNo != 0)
            ih = lineNo - 1
            # calling .to_i will convert 'no-Value' to 0
            minSeqArray[ih] = columns[it].to_i
          end
          lineNo += 1
        }
        if(minSeqArray.min >= 200)
          @alignSeqsMinLen = 150
        else
          @alignSeqsMinLen = minSeqArray.min * 0.75
          @alignSeqsMinLen = @alignSeqsMinLen.to_i
        end
    
        # call qiime pipeline
        cmd = "module load mbwDeps/v1 ; run_QIIME_ARG_pipeline.rb -u #{@outputDir}/metadata.txt -z #{@outputDir} -f #{@otuFastMethod} -s #{@otuSlowMethod} -b '#{@betaMetrics}' -a '#{@alphaMetrics}' "
        cmd << "-t #{@assignTaxonomyMethod} -c #{@assignTaxonomyMinConfidence} -l #{@alignSeqsMinLen} -r #{@runAlphaDiversityFlag} -p #{@runBetaDiversityFlag} "
        cmd << "-i #{@createPhylogeneticTreeFlag} -o #{@createOTUtableFlag} -m #{@createHeatmapFlag} -n #{@createOTUnetworkFlag} -q #{@createTaxaSummaries} "
        cmd << "-d #{@runLoopWithNormalizedDataFlag} -e #{@alignmentMethod} -g #{@makeTreeMethod} -x #{@removeChimeras} >#{@outputDir}/qiime.log 2>#{@outputDir}/qiime.error.log"
        $stdout.puts "#{Time.now.to_s}: RUNNING COMMAND ----->>>> #{cmd}"
        $stderr.puts "#{Time.now.to_s}: Running tool "
        system(cmd)
        @warningMessage = ""
        if(!$?.success?)
          @exitCode = 26
          @errUserMsg = "readsfilter script didn't run properly"
          @errInternalMsg = @errUserMsg
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        end

        # compress files
        compression()
        if(!$?.success?)
          @exitCode = 27
          @errUserMsg = "compression didn't run properly"
          @errInternalMsg = @errUserMsg
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        end
        
        # upload files to genboree
        uploadData()
        if(!$?.success?)
          @exitCode = 28
          @errUserMsg = "upload failed"
          @errInternalMsg = @errUserMsg
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        end

        # plot figures in project if project in outputs
        if(@outputs.size==2)
          projectPlot()
          if(!$?.success?)
            @exitCode = $?.exitstatus
			# If plots aren't generated, then we want to give the user a warning message (but we don't want to raise an error, since their data might be OK otherwise).
            if(@exitCode == 21 )
              @warningMessage = "WARNING: The job did not appear to generate any 2D or 3D plots.\n"\
			                    "Unfortunately, the underlying QIIME tool or the pipeline that drives QIIME\n"\
								"died while trying to create your plots, reporting errors to Genboree.\n"\
								"There may have been a problem with the run.\n"\
								"Please contact genboree_admin@genboree.org for help with this warning."
              # We want the job to succeed even if the plots aren't generated, so we reset exitCode to 0 to make this happen.
			  @exitCode = 0
            else
              @exitCode = 30
              @errUserMsg = "failed to generate plots"
              @errInternalMsg = @errUserMsg
              @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
              raise @err
            end
          end
        end

        # if no errors, remove downloaded files
        Dir.chdir("#{@outputDir}")
        system("find . ! -name '*.log' '.' '..' | xargs rm -rf")
        Dir.chdir(@scratchDir)
        rmCmd = "for xx in `find ./ -type f -name '*.fa'`; do `rm -f $xx`; done"
        `#{rmCmd}`

      rescue => err
        if(@exitCode == EXIT_OK)
          @err = err
          $stderr.debugPuts(__FILE__, __method__, "QIIME ERROR", "@err=#{@err.inspect}")
          @exitCode = 25
          @errUserMsg = "ERROR: An unrecognized error occurred while running QIIME."
          @errInternalMsg = @errUserMsg
        end
        # otherwise when @exitCode is set, assume @err, @errUserMsg, and @errInternalMsg were also set
      end

      return @exitCode
    end # end run method
  
    # Clean the tab-delimited file specified by path by replacing any missing values with the missingStr
    # @param [String] inFile filepath to tsv file to clean
    # @param [String] outFile filepath to save transformed tsv file to 
    # @param [String] missingStr the string to use in place of missing values
    # @note NOTE assumes file is UNIX line endings; modify to call String::toUnix as modified in brl/util/util.rb
    # if necessary
    def self.cleanTsvFile(inFile, outFile, missingStr)
      headerPattern = /^SampleID/i
      File.open(inFile, 'r'){|inHandle|
        File.open(outFile, 'w+'){|outHandle|
          fieldNames = nil
          inHandle.each_line{|line|
            # skip blank lines and remove terminal new line characters but leave other terminal whitespace
            next if(line !~ /\S+/)
            line.gsub!("\n", "")
          
            # get field names from first non-empty line and process subsequent lines
            if(line =~ headerPattern)
              fieldNames = line.split("\t")
  
              # validate header
              fieldNames.each{|name|
                if(name !~ /\S+/)
                  raise ArgumentError, "inFile=#{inFile} contains a field name with no non-whitespace characters"
                end
              }
              # copy header line to outFile
              outHandle.puts(line)
            else
              if(fieldNames.nil?)
                # then we encountered a non-header line before a header line
                raise ArgumentError, "inFile=#{inFile} has a non-header line before a header line. Header lines match the "\
                                     "pattern #{headerPattern.inspect}"
              else
                numFields = fieldNames.length
                inLineValues = line.split("\t", numFields)
  
                # insert {missingStr} in place of missing values
                outLineValues = inLineValues.dup()
                inLineValues.each_index{|ii|
                  value = inLineValues[ii]
                  if(value !~ /\S+/)
                    outLineValues[ii] = missingStr
                  end
                }
                # write modified values line to outFile
                outHandle.puts(outLineValues.join("\t"))
              end
            end 
          }
        }
      }
    end
  
     ##tar of output directory
    def compression
      $stdout.puts "#{Time.now.to_s}: compression"
      $stderr.puts "#{Time.now.to_s}: compression begins ..."
      ##Preparing directory structure for "project" area to display html
      system("mkdir -p #{@outputDir}/htmlPages/#{@studyName1}/QIIME/#{@jobName1}")
      system("cp -r #{@outputDir}/QIIME_result/plots #{@outputDir}/htmlPages/#{@studyName1}/QIIME/#{@jobName1}")
  
      Dir.chdir("#{@outputDir}/QIIME_result")
      system("tar czf raw.results.tar.gz * --exclude=filtered_aln --exclude=taxa --exclude=aln --exclude=plots")
      system("tar czf phylogenetic.result.tar.gz filtered_aln")
      system("tar czf taxonomy.result.tar.gz taxa")
      system("tar czf fasta.result.tar.gz aln")
      system("tar czf plots.result.tar.gz plots")
      Dir.chdir(@scratchDir)
      $stderr.puts "#{Time.now.to_s}: compression done"
    end
  
    ##Calling script to create html pages of plot in project area
    def projectPlot
      $stdout.puts "#{Time.now.to_s} : running projectplot script"
      $stderr.puts "#{Time.now.to_s} : running projectplot script..."
      jsonLocation  = CGI.escape("#{@scratchDir}/jobFile.json")
      htmlLocation = CGI.escape("#{@outputDir}/htmlPages/#{@studyName1}")
      exitStatus = system("importMicrobiomeProjectFiles.rb -j #{jsonLocation} -i #{htmlLocation} >#{@outputDir}/project_plot.log 2>#{@outputDir}/project_plot.error.log")
      $stderr.puts "#{Time.now.to_s} : projectplot script done"
    end
  
  
    def uploadUsingAPI(studyName,toolName,jobName,fileName,filePath)
      $stdout.puts "#{Time.now.to_s}: uploading #{fileName}"
      $stderr.puts "#{Time.now.to_s}: uploading #{fileName}..."
      restPath = @pathOutput
      path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/QIIME/#{@jobName1}/#{fileName}/data"
      path << "?gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
      @apiCaller.setRsrcPath(path)
      infile = File.open("#{filePath}","r")
      @apiCaller.put(infile)
      if @apiCaller.succeeded?
        $stdout.puts "#{Time.now.to_s}: successfully uploaded #{fileName} "
      else
        $stderr.puts "#{Time.now.to_s}: #{@apiCaller.parseRespBody()}"
        $stderr.puts "API response; statusCode: #{@apiCaller.apiStatusObj['statusCode']}, message: #{@apiCaller.apiStatusObj['msg']}"
        @exitCode = @apiCaller.apiStatusObj['statusCode'].to_i
        raise "#{@apiCaller.apiStatusObj['msg']}"
      end
      $stderr.puts "#{Time.now.to_s}: uploaded #{fileName}"
    end
  
    def uploadData
      @apiCaller = ApiCaller.new(@hostOutput,"",@hostAuthMap)
      restPath = @pathOutput
      @success = false
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"otu.table","#{@outputDir}/QIIME_result/otu_table.txt")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"phylogenetic.result.tar.gz","#{@outputDir}/QIIME_result/phylogenetic.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"taxonomy.result.tar.gz","#{@outputDir}/QIIME_result/taxonomy.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"fasta.result.tar.gz","#{@outputDir}/QIIME_result/fasta.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"plots.result.tar.gz","#{@outputDir}/QIIME_result/plots.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"raw.results.tar.gz","#{@outputDir}/QIIME_result/raw.results.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"sample.metadata","#{@outputDir}/metadata.txt")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"repr_set.fasta.ignore.","#{@outputDir}/QIIME_result/repr_set.fasta.ignore.")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"settings.json","#{@scratchDir}/jobFile.json")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"mapping.txt","#{@outputDir}/QIIME_result/mapping.txt")
      @success = true
    end
     
    def prepSuccessEmail()
      # prepare inputs description 
      inputsText = {}
      @inputs.each{|input|
        inputTokens = input.split('/')
        folderName = CGI.unescape(inputTokens[-1])
        inputsText[folderName] = "folder used as #{@shortToolTitle} input"
      }
  
      # prepare settings description
      # currently only setting exposed via Workbench is "Remove Chimeras?"
      chimerasBool = (@removeChimeras == 1 ? true : false)
      settings = {
        "Remove Chimeras?" => chimerasBool
      }

      # prepare resultFileLocations
      locationStr = "Group : #{@grpOutput}\n"\
        "Database : #{@dbOutput}\n"\
        "Files\n"\
        "  MicrobiomeWorkBench\n"\
        "    #{CGI.unescape(@studyName)}\n"\
        "      QIIME\n"\
        "        #{CGI.unescape(@jobName1)}\n"
      resultFileLocations = [locationStr]
  
      # prepare resultFileURLs
      if(@outputs.size == 2)
        # outputs were sorted in processJobConf
        prjName = @prjApiHelper.extractName(@outputs[1])
        if(prjName)
          resultFileURLs = {
            @jobName => "http://#{@hostOutput}/java-bin/project.jsp?projectName=#{prjName}"
          }
        else
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "project API helper unable to extract name for #{@outputs[1].inspect}")
          resultFileURLs = nil
        end
      else
        resultFileURLs = nil
      end

      additionalInfo = (@warningMessage.nil? or @warningMessage.empty? ? nil : @warningMessage)
  
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, 
        @userLastName, @studyName, inputsText, outputsText='n/a', settings, additionalInfo, resultFileLocations, 
        resultFileURLs=nil, shortToolTitle=nil)
      return successEmailObject
    end
  
    def prepErrorEmail()
      # prepare inputs description 
      inputsText = {}
      @inputs.each{|input|
        inputTokens = input.split('/')
        folderName = CGI.unescape(inputTokens[-1])
        inputsText[folderName] = "folder used as #{@shortToolTitle} input"
      }

      # prepare settings description
      # currently only setting exposed via Workbench is "Remove Chimeras?"
      chimerasBool = (@removeChimeras == 1 ? true : false)
      settings = {
        "Remove Chimeras?" => chimerasBool
      }
  
      failureEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, 
        @userLastName, @studyName, inputsText, outputsText='n/a', settings, additionalInfo=nil, resultFileLocations=nil, 
        resultFileURLs=nil, shortToolTitle=nil)
      failureEmailObject.errMessage = @errUserMsg
      failureEmailObject.exitStatusCode = @exitCode.to_s
      return failureEmailObject
    end
  end
end; end; end; end

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::QiimeWrapper)
end
