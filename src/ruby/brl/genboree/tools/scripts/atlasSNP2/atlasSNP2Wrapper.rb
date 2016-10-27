#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/util/emailer'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/tools/toolWrapper'
require 'brl/util/convertText'
require 'brl/util/samTools'
require 'brl/util/vcfParser'
require 'uri'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class AtlasSnp2Wrapper < BRL::Genboree::Tools::ToolWrapper
    # ToolWrapper interface
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { } # few tools actually implement this like the toolWrapper says
    DESC_AND_EXAMPLES = {
        :description  => "Call variants with the Atlas-SNP2 and Genboree",
        :authors      => [ "Sameer Paithankar(paithank@bcm.edu)", "Aaron Baker(ab4@bcm.edu)" ],
        :examples     => [
          "#{File.basename(__FILE__)} --inputFile=filePath",
          "#{File.basename(__FILE__)} --help",
          "#{File.basename(__FILE__)} --version"
      ]
    }
  
    # other class constants
    NON_ATLASSNP2_SETTINGS = { 'clusterQueue' => true }
    MAX_OUT_BUFFER = 1024 * 1024 * 4
  
    def processJobConf()
      begin
        # unique to this wrapper (but probably shouldnt be) and not a part of settings
        @successUserMsg = nil
        @resultFileLocations = nil
        
        # Get Input/Output
        @input = @inputs[0]
        @output = @outputs[0]
  
        # dbrc
        @dbrcKey = @context['apiDbrcKey']
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
  
        # reminaing context
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @scratchDir = @context['scratchDir']
  
        # Get Settings options
        @studyName = @settings['studyName']
        @jobName = @settings['jobName']
        @uploadSNPTrack = @settings['uploadSNPTrack']
        @platformType = @settings['platformType']
        @eCovPriori = @settings['eCoveragePriori']
        @lCovPriori = @settings['lCoveragePriori']
        @maxPercSubBases = @settings['maxPercSubBases']
        @maxPercIndelBases = @settings['maxPercIndelBases']
        @maxAlignPileup = @settings['maxAlignPileup']
        @postProbCutOff = @settings['postProbCutOff']
        @minCov = @settings['minCov']
        @insertionSize = @settings['insertionSize']
        @sampleName = @settings['sampleName']
        @fastaDir = @settings['fastaDir']
        @refGenome = @settings['refGenome']
        @lffType = @settings['lffType']
        @lffSubType = @settings['lffSubType']
        @removeDup = @settings['removeDup']
        @keepOnlyUniqueMappings = @settings['keepOnlyUniqueMappings']
        @separateSNPs = @settings['separateSNPs']
  
        @trackName = CGI.escape("#{@lffType}:#{@lffSubType}") if(@uploadSNPTrack)
        @lffType = CGI.escape(@sampleName) unless(@lffType)
        @lffSubType = 'SNPs' unless(@lffSubType)
        @groupName = @grpApiHelper.extractName(@output)
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", err.message)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", err.backtrace.join("\n"))
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end
  
    def run()
      begin
        # Run Atlas-SNP2.rb program
        runAtlasSnp2()
  
        # Prepares lff file:
        prepLff()
  
        # Uploads lff file as track in Genboree (if required)
        uploadLff() if(@uploadSNPTrack)
  
        # Transfer .vcf., .snp and .lff files to target
        transferFiles()
  
      rescue Exception => err
        if(err.is_a?(GenboreeAtlasError) and err.code == 1)
          # then this is more of a problem with the input file and not necessarily an error
          $stderr.debugPuts(__FILE__, __method__, "ATLAS", err.message)
  
          # upload Atlas stdout which communicates information about the input file in context of SNP calling
          dbUri = URI.parse(@output)
          atlasResultDirpath = "#{dbUri.path}/file/#{CGI.escape("Atlas2 Suite Results")}/#{CGI.escape(@studyName)}/Atlas-SNP2/#{CGI.escape(@jobName)}"
          atlasStdoutFilepath = "#{atlasResultDirpath}/#{@atlasStdoutBasename}/data"
          apiCaller = WrapperApiCaller.new(dbUri.host, atlasStdoutFilepath, @userId)
          apiCaller.put({}, File.open("#{@scratchDir}/#{@atlasStdoutBasename}"))
  
          # finally, notify the user that we have provided this file
          if(@resultFileLocations.nil?)
            @resultFileLocations = ["#{dbUri.host}#{atlasStdoutFilepath}"]
          elsif(@resultFileLocations.is_a?(Array))
            @resultFileLocations << "#{dbUri.host}#{atlasStdoutFilepath}"
          end
          @successUserMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "ERROR", err.backtrace.join("\n"))
          @exitCode = 24
        end
      end
  
      return @exitCode
    end
  
    # Downloads inputs files and runs the Atlas-SNP2 program
    # [+returns+] nil
    def runAtlasSnp2()
      filehelperObj = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
      dbHelperObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      # First check if we have the reference fasta sequence for the tool
      dirFound = File.directory?(@fastaDir)
      if(!dirFound)
        @errUserMsg = "The reference Fasta sequence file for genome: #{@refGenome} could not be found."
        raise @errUserMsg
      end
      # Download the sam/bam file
      uri = URI.parse(@input)
      rcscUri = uri.path
      rcscUri = rcscUri.chomp("?")
      rcscUri << "/data?"
      rcscUri << "gbKey=#{@dbApiHelper.extractGbKey(@input)}" if(@dbApiHelper.extractGbKey(@input))
      @inputFileName = CGI.escape(File.basename(filehelperObj.extractName(@input)))
      fileWriter = File.open(@inputFileName, "w")
      uri = URI.parse(@input)
      apiCaller = WrapperApiCaller.new(uri.host, rcscUri, @userId)
      $stderr.puts "Downloading bam/sam file: #{@inputFileName}"
      writeBuff = ''
      apiCaller.get() { |chunk|
        writeBuff << chunk
        if(writeBuff.size >= MAX_OUT_BUFFER)
          fileWriter.print(writeBuff)
          writeBuff = ''
        end
      }
      if(!apiCaller.succeeded?)
        @errUserMsg = "Failed to download file: #{CGI.unescape(@inputFileName)}"
        raise "Failed to download file: #{CGI.unescape(@inputFileName)}.\nDetails:\n#{apiCaller.respBody.inspect}"
      end
      if(!writeBuff.empty?)
        fileWriter.print(writeBuff)
        writeBuff = ''
      end
      fileWriter.close()
      # If the file is a sam file, we need to expand it and convert it to unix format and finally convert that into a bam file
      bamFile = @inputFileName !~ /\.bam$/i ? prepSamFile(@inputFileName) : @inputFileName.dup()
      # Once we get the bam file, we check if sorting is required or not (using samTools)
      preppedFile = BRL::Util::SamTools.isBamSorted?(bamFile) ? bamFile.dup() : sortBamFile(bamFile)
      # Now try using picard to sort the file (if it did not get sorted)
      if(!BRL::Util::SamTools.isBamSorted?(preppedFile))
        cmd = " module load picard/1.47; java -Xmx2g -jar /cluster.shared/local/bin/SortSam.jar INPUT=#{preppedFile} OUTPUT=#{preppedFile.gsub(/\.bam$/, ".sortedWithPicard.bam")} SORT_ORDER=coordinate"
        cmd << " > sortByPicard.out 2> sortByPicard.err"
        $stderr.debugPuts(__FILE__, __method__, "COMMAND", cmd)
        `#{cmd}`
        exitObj = $?.dup()
        if(exitObj.exitstatus != 0)
          stderrStream = File.read("sortByPicard.err")
          stdoutStream = File.read("sortByPicard.out")
          @errUserMsg = "Sorting using Picard failed.\nStderr:\n#{stderrStream}\nStdout:\n#{stdoutStream}\n"
          raise "Picard failed with exit status: #{exitObj.exitstatus}. Check sortByPicard.out and sortByPicard.err for more information."
        end
        `rm -f #{preppedFile}`
        preppedFile = preppedFile.gsub(/\.bam$/, ".sortedWithPicard.bam")
      end
      # Check if we need to remove clonal duplicates from the bam file
      if(@removeDup)
        @deDupFile = "#{File.basename(preppedFile).gsub(/\.bam/i, ".withoutDuplicates.bam")}"
        removeDupCmd = "module load picard/1.47; java -Xmx2g -jar /cluster.shared/local/bin/MarkDuplicates.jar INPUT=#{preppedFile} OUTPUT=#{@deDupFile} METRICS_FILE=Picard.metrics REMOVE_DUPLICATES=true VALIDATION_STRINGENCY=LENIENT > picard.out 2> picard.err"
        $stderr.debugPuts(__FILE__, __method__, "COMMAND", removeDupCmd)
        `#{removeDupCmd}`
        exitObj = $?.dup()
        if(exitObj.exitstatus != 0) # Something went wrong
          stderrStream = File.read("picard.err")
          stdoutStream = File.read("picard.out")
          @errUserMsg = "Could not remove duplicates using Picard.\nStderr:\n#{stderrStream}\nStdout:\n#{stdoutStream}\n"
          raise "Picard failed with exit status: #{exitObj.exitstatus}. Check picard.out and picard.err for more information."
        end
        `rm -f #{preppedFile}`
        preppedFile = @deDupFile
      end
      # Check if we need to keep only unique mappings
      if(@keepOnlyUniqueMappings)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing non unique mappings")
        inputFileForUniqueMappings = preppedFile.dup()
        samFileWithoutUniqueMappings = inputFileForUniqueMappings.gsub(/\.bam$/i, ".withoutUniqueMappings.sam")
        samFileWithUniqueMappings = "#{samFileWithoutUniqueMappings.gsub(/\.withoutUniqueMappings.sam$/i, ".withUniqueMappings.sam")}"
        # First convert the bam file to sam since grep is not going to work on a bam file
        BRL::Util::SamTools.bam2sam(inputFileForUniqueMappings, samFileWithoutUniqueMappings)
        # First, the secondary mappings will be removed with 2 passes
        `grep --mmap -v -P '\sX1:i:(?:0+[1-9]|[1-9])' #{samFileWithoutUniqueMappings} > withoutSecondaryMappingsFirstPass.sam`
        `ruby -nae 'puts $_ if($F[0] =~ /^@/ or ($F[1].to_i & 256 != 256))' withoutSecondaryMappingsFirstPass.sam > withoutSecondaryMappingsSecondPass.sam`
        # Next, remove the mappings with > 1 high quality primary mappings
        `grep --mmap -vP '^@' withoutSecondaryMappingsSecondPass.sam | cut -f1 -d $'\t' | sort | uniq -d > read.kill.list`
        wcLines = `wc -l read.kill.list`
        if(wcLines.split(" ")[0] == "0") # Nothing more to do
          `mv withoutSecondaryMappingsSecondPass.sam #{samFileWithUniqueMappings}`
        else # Remove the mappings listed in the kill ist
          `grep --mmap -v -F -f read.kill.list withoutSecondaryMappingsSecondPass.sam > #{samFileWithUniqueMappings}`
        end
        # Convert the sam file back into a bam file
        preppedFile = samFileWithUniqueMappings.gsub(/\.withUniqueMappings.sam$/i, ".withUniqueMappings.bam")
        BRL::Util::SamTools.sam2bam(samFileWithUniqueMappings, preppedFile)
        `rm -f withoutSecondaryMappingsFirstPass.sam withoutSecondaryMappingsSecondPass.sam`
      end
      # Run Atlas-SNP2.rb (for illumina and 454) or solid-* (for solid) programs
      cmd = "module load atlastools; samtools index #{preppedFile}; "
      if(@inputFileName !~ /\.bam$/i)
        @inputFileName.gsub!(/\.sam(?:\.[^\.]+)?/i, "")
      else
        @inputFileName.gsub!(/\.bam(?:\.[^\.]+)?/i, "")
      end
      if(@platformType == '454flx' or @platformType == '454titanium' or @platformType == 'illumina')
        cmd << " Atlas-SNP2.rb -i #{preppedFile} -r #{@fastaDir}/#{@refGenome}.fa -o #{@scratchDir}/#{@inputFileName}.snp -v -n #{CGI.escape(@sampleName)}"
        if(@platformType == '454titanium')
          cmd << " -x -l #{@lCovPriori} "
        elsif(@platformType == '454flx')
          cmd << " -l #{@lCovPriori} "
        else
          cmd << " -s "
        end
        @atlasStdoutBasename = "#{CGI.escape(@sampleName)}.#{@platformType}.snp.stdout"
        cmd << " -e #{@eCovPriori} -c #{@postProbCutOff} -y #{@minCov} -m #{@maxPercSubBases} -g #{@maxPercIndelBases} -f #{@maxAlignPileup} -p #{@insertionSize} "
        cmd << "> #{@scratchDir}/#{@atlasStdoutBasename} 2> #{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.snp.stderr"
        $stderr.puts "Launching Command: #{cmd.inspect}"
  
        # determine if the command was run successfully, error otherwise
        exitStatus = system(cmd)
        statusObj = $?.dup()
        if(!exitStatus)
          stderrStream = File.read("#{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.snp.stderr")
          stdoutStream = File.read("#{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.snp.stdout")
          @errUserMsg = "Failed to run: Atlas-SNP2.rb.\n Stderr:\n#{stderrStream}\nStdout:\n#{stdoutStream}\n"
          raise "Atlas-SNP2.rb failed with status: #{statusObj.inspect}.\nCommand: #{cmd.inspect}"
        end
  
        # consider empty output file an error (we shouldnt try to perform subsequent tool steps
        # such as uploading lff of non-existent results)
        numLines = nil
        wcCmd = " wc -l #{@scratchDir}/#{@inputFileName}.snp"
        output = `#{wcCmd}`
        exitStatus = $?.exitstatus
        if(exitStatus == 0)
          matchDataObj = /(\d+)/.match(output)

          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "matchDataObj=#{matchDataObj.inspect}")

          unless(matchDataObj.nil?)
            numLines = matchDataObj[1].to_i
          else
            # this shouldnt happen unless wc command output fundamentally changes
            msg = "Unable to determine number of lines from successful wc command"
            code = 3
            err = GenboreeAtlasError.new(code, msg)
            raise err
          end
        else
          # this also shouldnt happen unless the file is removed or something
          msg = "Unable to determine the number of lines in the file #{@scratchDir}/#{@inputFileName}.snp"
          code = 2
          err = GenboreeAtlasError.new(code, msg)
          raise err
        end

        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "numLines=#{numLines.inspect}")
        if(numLines.nil? or numLines == 1)
          msg = "Atlas-SNP2 could not reliably call any SNPs in your input data file #{@inputFileName} against the "\
                "reference genome #{@refGenome}. A file from Atlas-SNP2 has been uploaded to your database with information "\
                "about the processing of the reads in the input file."
          code = 1
          err = GenboreeAtlasError.new(code, msg)
          raise err
        end
        
      else # For solid
        # OLD version [more convenient, but oh well]
        #cmd << "solid-vcf.rb #{preppedFile} #{@fastaDir}/#{@refGenome}.fa #{CGI.escape(@sampleName)} #{@scratchDir}/#{@inputFileName}.vcf "
        #cmd << "> #{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.stdout 2> #{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.stderr"
        #
        # NEWER version should be better SNP caller but less conveniently wrapped:
        cmd << "solid-genotyper #{preppedFile} #{@fastaDir}/#{@refGenome}.fa | 2vcf.rb #{CGI.escape(@sampleName)} > #{@scratchDir}/#{@inputFileName}.vcf 2> #{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.stderr"
        #
        $stderr.puts "Launching Command: #{cmd.inspect}"
        exitStatus = system(cmd)
        statusObj = $?.dup()
        if(!exitStatus)
          stderrStream = File.read("#{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.stderr")
          # Not available in NEWER version recommended way of running:
          #stdoutStream = File.read("#{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.stdout")
          #@errUserMsg = "Failed to run: solid-vcf.rb.\n Stderr:\n#{stderrStream}\nStdout:\n#{stdoutStream}\n"
          @errUserMsg = "Failed to run: solid-vcf.rb.\n Stderr:\n#{stderrStream}\n"
          raise "solid-vcf.rb failed with status: #{statusObj.inspect}.\nCommand: #{cmd.inspect}"
        end
      end
      # Compress the bam.bai file
      cmd = "zip #{preppedFile}.bai.zip #{preppedFile}.bai"
      exitStatus = system(cmd)
      statusObj = $?.dup()
      if(!exitStatus)
        $stderr.puts "ERROR: Failed to zip file: #{preppedFile}.bai\nExitStatus: #{statusObj.inspect}\nCommand: #{cmd.inspect} "
      end
      # remove the original .bai file
      cmd = "rm #{preppedFile}.bai"
      exitStatus = system(cmd)
      statusObj = $?.dup()
      if(!exitStatus)
        $stderr.puts "ERROR: Failed to rm file: #{preppedFile}.bai\nExitStatus: #{statusObj.inspect}\nCommand: #{cmd.inspect} "
      end
      `rm -f #{@inputFileName}`
      unless(@removeDup or @keepOnlyUniqueMappings) # If the bam file was 'specially' treated, we will transfer it to the target database
        `rm -f #{preppedFile}`
      else
        @preppedFile = preppedFile
      end
      # Remove any remaining sam files
      Dir.entries('.').each { |file|
        `rm -f #{file}` if(file =~ /\.sam$/i and file != preppedFile)
      }
    end
  
    # Sortes bam file
    # [+bamFile+]
    # [+returns+] preppedFile
    def sortBamFile(bamFile)
      preppedFile = nil
      begin
        BRL::Util::SamTools.sortBam(bamFile)
        preppedFile = "#{bamFile.gsub(".bam", ".sorted")}.bam"
      rescue => err
        raise err
      end
      return preppedFile
    end
  
    # Preps downloaded Sam file:
    # expands it and converts it to unix format
    # Finally converts it into a bam file
    # [+samFile+]
    # [+returns+] bamFile
    def prepSamFile(samFile)
      $stderr.puts "Prepping SAM file..."
      # Uncompress the file if its zipped
      expanderObj = BRL::Genboree::Helpers::Expander.new(samFile)
      expanderObj.extract(desiredType = 'text')
      fullPathToUncompFile = expanderObj.uncompressedFileName
      # Convert to unix format:
      convertObj = BRL::Util::ConvertText.new(fullPathToUncompFile)
      convertObj.convertText(:all2unix)
      preppedFile = convertObj.convertedFileName
      # Convert it into a  bam file
      bamFile = preppedFile.gsub(".sam.2unix", ".bam")
      begin
        BRL::Util::SamTools.sam2bam(preppedFile, bamFile, false)
      rescue => err
        raise err
      end
      Dir.entries(expanderObj.tmpDir).each { |file|
        next if(file == '.' or file == '..' or file == bamFile)
        `rm -f #{file}`
      }
      return bamFile
    end
  
    # Transfer output files to target
    # [+returns+] nil
    def transferFiles()
      uri = URI.parse(@output)
      host = uri.host
      rcscUri = uri.path
      rcscUri = rcscUri.chomp("?")
      rcscUri << "/file/#{CGI.escape("Atlas2 Suite Results")}/#{CGI.escape(@studyName)}/Atlas-SNP2/#{CGI.escape(@jobName)}/"
      # Transfer files:
      files = nil
      if(@platformType != "solid")
        if(@separateSNPs)
          files = [ @passedVCFFile, @otherVCFFile, @lffFile, @snpFile ]
        else
          files = [ @snpFile, @vcfFile, @lffFile ]
        end
      else # Solid does not generate .snp file
        if(@separateSNPs)
          files = [ @passedVCFFile, @otherVCFFile, @lffFile ]
        else
          files = [ @vcfFile, @lffFile ]
        end
      end
      # zip the files
      compressedFiles = []
      files.each { |file|
        cmd = "zip #{file}.zip #{file}"
        exitStatus = system(cmd)
        exitObj = $?.dup()
        if(!exitStatus)
          @errUserMsg = "Could not compress file: #{file.inspect}"
          raise "zip cmd failed.\nExit Status: #{exitObj.inspect}\nCommand: #{cmd.inspect}"
        end
        if(File.exists?("#{file}.zip"))
          compressedFiles.push("#{file}.zip")
          `rm -f #{file}`
        end
      }
      compressedFiles.each { |file|
        fileUri = rcscUri.dup()
        fileUri << "#{File.basename(file)}/data?"
        fileUri << "gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
        apiCaller = WrapperApiCaller.new(host, fileUri, @userId)
        $stderr.puts "Transferring file: #{File.basename(file)}"
        apiCaller.put({}, File.open(file))
        if(!apiCaller.succeeded?)
          @errUserMsg = "Failed to transfer file: #{File.basename(file)} to target."
          raise "Failed to transfer file: #{File.basename(file)} to target.\nDetails: \n#{apiCaller.respBody.inspect}"
        else # Delete file from disk since we don't need it anymore
          `rm -f #{file}` if(file !~ /\.lff/)
        end
      }
      if(@removeDup or @keepOnlyUniqueMappings) # Also transfer the 'specially' treated bam file
        rsrcPath = "#{rcscUri}#{File.basename(@preppedFile)}/data?"
        apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
        apiCaller.put({}, File.open(@preppedFile))
        `rm -f #{@preppedFile}`
        if(@removeDup) # Also transfer the Picard stderr file if it was run
          `zip Picard_Report.txt.zip picard.err`
          exitObj = $?.dup()
          if(exitObj.exitstatus != 0)
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not zip picard.err")
          else
            rsrcPath = "#{rcscUri}Picard_Report.txt.zip/data?"
            apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
            apiCaller.put({}, File.open("Picard_Report.txt.zip"))
          end
          rsrcPath = "#{rcscUri}Picard.metrics/data?"
          apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
          apiCaller.put({}, File.open("Picard.metrics"))
        end
        `rm -f #{@deDupFile}` if(File.exists?(@deDupFile))
      end
    end
  
    # Uploads Lff File as a track
    # [+returns+] nil
     def uploadLff()
      @uploadFailed = false
      uri = URI.parse(@output)
      host = uri.host
      rcscUri = uri.path.chomp("?")
      # First create the empty track
      rcscUri << "/trk/#{@trackName}?"
      rcscUri << "gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
      apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
      apiCaller.put()
      if(apiCaller.succeeded?) # OK, set the default display
        payload = { "data" => { "text" => "Expand with Names" } }
        rcscUri.chomp!("?")
        rcscUri << "/defaultDisplay?"
        rcscUri << "gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
        apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
        apiCaller.put(payload.to_json)
        $stderr.puts "Setting the default display for track: #{@trackName} failed (rcscUri: #{rcscUri.inspect}): #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
        # Set the default color
        rcscUri.gsub!("/defaultDisplay?", "/defaultColor?")
        apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
        payload = { "data" => { "text" => "#0000ff" } }
        apiCaller.put(payload.to_json)
        $stderr.puts "Setting the default color for track: #{@trackName} failed (rcscUri: #{rcscUri.inspect}): #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
      else # Failed
        $stderr.puts "Creating the empty track: #{@trackName} failed (Track already exists?) (rcscUri: #{rcscUri.inspect}): #{apiCaller.respBody.inspect}"
      end
      # Get the refseqid of the target database
      outputUri = URI.parse(@output)
      rsrcUri = outputUri.path
      rsrcUri << "?gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
      apiCaller = WrapperApiCaller.new(outputUri.host, rsrcUri, @userId)
      apiCaller.get()
      resp = JSON.parse(apiCaller.respBody)
      uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
      uploadAnnosObj.refSeqId = resp['data']['refSeqId']
      uploadAnnosObj.groupName = @groupName
      uploadAnnosObj.userId = @userId
      uploadAnnosObj.outputs = [@output]
      begin
        uploadAnnosObj.uploadLff(CGI.escape(File.expand_path(@lffFile)), false)
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        @errUserMsg = "FATAL ERROR: Could not upload result lff file to target database."
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise @errUserMsg
      end
    end
  
    # Creates an lff file from the .vcf and .snp file generated by Atlas-SNP2.rb program
    # [+returns+] nil
    def prepLff()
      $stderr.puts "Preparing LFF File..."
      vcfReader = nil
      lffWriter = nil
      if(@platformType != "solid")
        @vcfFile = "#{@inputFileName}.snp.vcf"
        vcfReader = File.open(@vcfFile)
        @snpFile = "#{@inputFileName}.snp"
        snpReader = File.open(@snpFile)
        @lffFile = "#{@inputFileName}.lff"
        lffWriter = File.open(@lffFile, "w")
      else
        @lffFile = "#{@inputFileName}.lff"
        lffWriter = File.open(@lffFile, "w")
        @vcfFile = "#{@inputFileName}.vcf"
        vcfReader = File.open(@vcfFile)
      end
  
      # Separate the VCF file into 2 files based on whether the SNPs passed QC or not if required
      passedVCFWriter = otherVCFWriter = nil
      if(@separateSNPs)
        @passedVCFFile = "PASS_#{@vcfFile}"
        @otherVCFFile = "OTHER_#{@vcfFile}"
        passedVCFWriter = File.open(@passedVCFFile, 'w')
        otherVCFWriter = File.open(@otherVCFFile, 'w')
      end
  
      buff = ''
      vcfObj = nil
      vcfReader.each_line { |line|
        if(line =~ /^#(?!#)/) # Column Header
          # Init vcfParser
          vcfObj = BRL::Util::VcfParser.new(line, nil)
          break
        end
      }
  
      # Go through the vcf file and create a lff record for each record in the file or multiple lff recs per sample
      vcfReader.each_line { |line|
        line.strip!
        next if(line.nil? or line =~ /^#/ or line =~ /^\s*$/ or line.empty?)
        vcfObj.parseLine(line)
        if(@platformType != "solid")
          snpReader.each_line { |snpLine|
            line.strip!
            next if(line.nil? or line =~ /^#/ or line =~ /^\s*$/ or line.empty?)
            snpData = line.split(/\t/)
            chr = snpData[0]
            coord = snpData[1].to_i
            if(coord == vcfObj.vcfDataHash['POS'].to_i and chr == vcfObj.vcfDataHash['CHROM'])
              vcfObj.vcfDataHash['totalFilteredReadCoverage'] = snpData[8].to_i
              vcfObj.vcfDataHash['homoPolymer'] = snpData[17].to_i
              if(@separateSNPs)
                if(vcfObj.vcfDataHash['FILTER'] == 'PASS')
                  buff << vcfObj.makeLFF("Atlas Tool Suite", @lffType, "PASS_#{@lffSubType}")
                  passedVCFWriter.puts(line)
                else
                  buff << vcfObj.makeLFF("Atlas Tool Suite", @lffType, "#{@lffSubType}")
                  otherVCFWriter.puts(line)
                end
              else
                buff << vcfObj.makeLFF("Atlas Tool Suite", @lffType, @lffSubType)
              end
              break
            end
          }
        else # Solid does not generate .snp file
          if(@separateSNPs)
            if(vcfObj.vcfDataHash['FILTER'] == 'PASS')
              buff << vcfObj.makeLFF("Atlas Tool Suite", @lffType, "PASS_#{@lffSubType}")
              passedVCFWriter.puts(line)
            else
              buff << vcfObj.makeLFF("Atlas Tool Suite", @lffType, "#{@lffSubType}")
              otherVCFWriter.puts(line)
            end
          else
            buff << vcfObj.makeLFF("Atlas Tool Suite", @lffType, @lffSubType)
          end
        end
        vcfObj.deleteNonCoreKeys
        if(buff.size >= MAX_OUT_BUFFER)
          lffWriter.print(buff)
          buff = ''
        end
      }
      if(!buff.empty?)
        lffWriter.print(buff)
        buff = ''
      end
      # Close all file handlers
      if(@separateSNPs)
        otherVCFWriter.close()
        passedVCFWriter.close()
      end
      vcfReader.close()
      snpReader.close() if(@platformType != 'solid')
      lffWriter.close()
    end
  
    def prepSuccessEmail()
        additionalInfo = @successUserMsg

        # copy settings labels from workbenchDialog
        # any changes here should also be reflected in the workbenchDialog.rhtml for this tool
        settingsIdToLabelMap = {
          "studyName" => "Study Name",
          "jobName" => "Job Name",
          "platformType" => "Platform",
          "sampleName" => "Sample Name",
          "uploadSNPTrack" => "Upload as a Track ?",
          "removeDup" => "Remove Clonal Duplicates",
          "trackName" => "SNPs Track Name",
          "separateSNPs" => "Separate SNPs Passing QC",
          "minCov" => "Min. Coverage",
          "maxAlignPileup" => "Max. Pile-Up",
          "maxPercSubBases" => "Max. % Substitutions",
          "maxPercIndelBases" => "Max. % Indels",
          "insertionSize" => "Insert Size",
          "postProbCutOff" => "Posterior Prob. Cutoff",
          "eCoveragePriori" => "Prior Prob. for Coverage > 2",
          "lCoveragePriori" => "Prior Prob. for Coverage <= 2"
        }

        # create readable settings for email only for explicitly named settings in the workbench dialog
        userSettings = {}
        settingsIdToLabelMap.each_key{|id|
          settingLabel = settingsIdToLabelMap[id]
          settingValue = @settings[id]
          userSettings[settingLabel] = settingValue
        }

        successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, 
                                                                      @userLastName, analysisName="", inputsText="n/a", 
                                                                      outputsText="n/a", settings=userSettings, additionalInfo, 
                                                                      resultFileLocations=@resultFileLocations, resultFileURLs=nil)
        return successEmailObject
    end
  
    def prepErrorEmail()
      additionalInfo = @errUserMsg
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, 
                                                                  analysisName="", inputsText="n/a", outputsText="n/a", 
                                                                  settings=nil, additionalInfo, resultFileLocations=nil, 
                                                                  resultFileURLs=nil)
      return errorEmailObject
    end
  end

  # provide a special error class to provide more informative output to user
  class GenboreeAtlasError < RuntimeError
    
    attr_accessor :code
  
    ErrorCodes = {
      1 => "Atlas-SNP2 found no SNPs",
      2 => "wc on Atlas-SNP2 output failed",
      3 => "Unable to process wc results on Atlas-SNP2 output"
    }
  
    # add an error code to the parent initialize(msg = nil) constructor
    def initialize(code, msg)
      super(msg)
      @code = code
      set_backtrace( (caller[1,caller.size] || []) )
    end
  end

end; end ; end ; end

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::AtlasSnp2Wrapper)
end
