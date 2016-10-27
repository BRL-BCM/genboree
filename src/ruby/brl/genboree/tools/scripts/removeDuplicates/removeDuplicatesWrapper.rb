#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/util/samTools'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class RemoveDuplicatesWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This tool can be used for removing duplicates from a BAM/SAM file also allows for keeping only uniquely mapped reads in the resultant BAM/SAM file .
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        @targetUri = @outputs[0]
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        @deleteSourceFiles = @settings['deleteSourceFiles']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @toolScriptPrefix = @context['toolScriptPrefix']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @removeDuplicates = @settings['removeDuplicates']
        @keepUniqueMappings = @settings['keepUniqueMappings']
        @removeSecondaryMappings = @settings['removeSecondaryMappings']
        @dbName = @dbApiHelper.extractName(@dbApiHelper.extractPureUri(@outputs[0]))
        @groupName = @grpApiHelper.extractName(@grpApiHelper.extractPureUri(@outputs[0]))
        @resultFileBaseName = CGI.escape(@settings['resultFileBaseName'])
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Run Picard and other commands
    # [+returns+] nil
    def run()
      begin
        # First download the input file
        inputFile = downloadFile(@inputs[0])
        # Run Picard, if required
        if(@removeDuplicates)
          picardCmd = "module load picard/1.47; java -Xmx2g -jar /cluster.shared/local/bin/MarkDuplicates.jar INPUT=#{inputFile} OUTPUT=deDup_#{inputFile} METRICS_FILE=Picard.metrics REMOVE_DUPLICATES=true VALIDATION_STRINGENCY=LENIENT > picard.out 2> picard.err"
          `#{picardCmd}`
          exitObj = $?.dup()
          if(exitObj.exitstatus != 0) # Something went wrong
            @errUserMsg = ""
            @errUserMsg = File.read("picard.out")
            if(@errUserMsg.empty?)
              @errUserMsg = File.read("picard.err")
            end
            raise "Picard failed with exit status: #{exitObj.exitstatus}. Check picard.out and picard.err for more information."
          end
          inputFile = "deDup_#{inputFile}"
        end
        # Remove non-unique mappings, if required (start with removing the secondary mappings)
        if(@removeSecondaryMappings)
          # If the input file is not a SAM file, we need to convert it into a SAM file
          samFile = nil
          if(inputFile !~ /\.sam/i)
            samFile = inputFile.gsub(/\.bam$/i, ".sam")
            BRL::Util::SamTools.bam2sam(inputFile, samFile)
          else
            samFile = inputFile
          end
          cmd = "grep --mmap -v -P '\sX1:i:(?:0+[1-9]|[1-9])' #{samFile} > withoutSecondaryMappingsFirstPass.sam"
          `#{cmd}`
          exitObj = $?.dup()
          if(exitObj.exitstatus != 0)
            @errUserMsg = "Error:\nFirst pass for removing secondary mappings failed."
            raise "Command Failed: #{cmd}"
          end
          cmd = "ruby -nae 'puts $_ if($F[0] =~ /^@/ or ($F[1].to_i & 256 != 256))' withoutSecondaryMappingsFirstPass.sam > withoutSecondaryMappingsSecondPass.sam"
          `#{cmd}`
          exitObj = $?.dup()
          if(exitObj.exitstatus != 0)
            @errUserMsg = "Error:\nSecond pass for removing secondary mappings failed."
            raise "Command Failed: #{cmd}"
          end
          inputFile = 'withoutSecondaryMappingsSecondPass.sam'
        end
        # Lastly remove the optimal non-unique mappings
        if(@keepUniqueMappings)
          samFile = nil
          if(inputFile !~ /\.sam/i)
            samFile = inputFile.gsub(/\.bam$/i, ".sam")
            BRL::Util::SamTools.bam2sam(inputFile, samFile)
          else
            samFile = inputFile
          end
          cmd = "grep --mmap -vP '^@' #{samFile} | cut -f1 -d $'\t' | sort | uniq -d > read.kill.list"
          `#{cmd}`
          exitObj = $?.dup()
          if(exitObj.exitstatus != 0)
            @errUserMsg = "Error:\nFirst pass for removing optimal mappings failed."
            raise "Command Failed: #{cmd}"
          end
          cmd = "grep --mmap -v -F -f read.kill.list #{samFile} > uniqueMappings_#{samFile}"
          `#{cmd}`
          exitObj = $?.dup()
          if(exitObj.exitstatus != 0)
            @errUserMsg = "Error:\nSecond pass for removing optimal mappings failed."
            raise "Command Failed: #{cmd}"
          end
          inputFile = "uniqueMappings_#{samFile}"
        end
        if(@fileApiHelper.subdir(@outputs[0]) == '/') # Its a db or 'files'
          @outputUri = URI.parse(@dbApiHelper.extractPureUri(@outputs[0]))
          @rsrcPath = "#{@outputUri.path}/file/"
          @target = "Files"
        else
          @outputUri = URI.parse(@dbApiHelper.extractPureUri(@outputs[0]))
          subdir = @fileApiHelper.subdir(@outputs[0])
          @rsrcPath = "#{@outputUri.path}/file#{subdir.chomp("?")}/"
          @target = CGI.unescape(subdir.chomp("?"))
        end
        # We may need to resultant file back into the original format
        if(@fileApiHelper.extractName(@inputs[0]) =~ /\.bam$/i)
          @resultFileBaseName << ".bam"
          if(inputFile !~ /\.bam$/i) # Convert sam to bam
            BRL::Util::SamTools.sam2bam(inputFile, "#{inputFile.gsub(/\.sam$/i, ".bam")}")
            inputFile = "#{inputFile.gsub(/\.sam$/i, ".bam")}"
          end
        else
          if(inputFile !~ /\.sam$/i) # Convert bam to sam
            BRL::Util::SamTools.bam2sam(inputFile, "#{inputFile.gsub(/\.bam$/i, ".sam")}")
            inputFile = "#{inputFile.gsub(/\.bam$/i, ".sam")}"
          end
          @resultFileBaseName << ".sam"
        end
        Dir.entries(".").each { |file|
          if( file != inputFile and ( file =~ /\.sam$/i or file =~ /\.bam$/i ) ) # Nuke all irrelevant files
            `rm -f #{file}`
          else # Transfer the file to the target database/folder
            if(file == inputFile or file == 'picard.err' or file == 'Picard.metrics')
              # Zip the file before transferring
              fileToTransfer = nil
              if(file =~ /\.sam$/i)
                `zip #{@resultFileBaseName}.zip #{file}`
                `rm -f #{file}`
                fileToTransfer = "#{@resultFileBaseName}.zip"
              elsif(file == 'picard.err')
                `zip #{file}.zip #{file}`
                `rm -f #{file}`
                fileToTransfer = "#{file}.zip"
              elsif(file =~ /\.bam$/i)
                fileToTransfer = @resultFileBaseName
                `mv #{file} #{@resultFileBaseName}`
              else # Do nothing
                fileToTransfer = file
              end
              apiCaller = WrapperApiCaller.new(@outputUri.host, "#{@rsrcPath}#{fileToTransfer}/data?", @userId)
              apiCaller.put({}, File.open(fileToTransfer))
              if(!apiCaller.succeeded?)
                $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not upload file: #{fileToTransfer}\nApiCaller Response: #{apiCaller.respBody.inspect}")
              else
                `rm -f #{fileToTransfer}`
              end
            end
          end
        }
        @resultFileBaseName << ".zip" if(@resultFileBaseName =~ /\.sam$/i)
      rescue => err
        @err = err
        # Try to read the out file first:
        if(@errUserMsg.nil? or @errUserMsg.empty?) # Should not be empty at this point.
          @errUserMsg = "Unknown error"
        end
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      end
      return @exitCode
    end

    # Download input file for the tool to be run
    # [+file+] file to be downloaded via API call
    # [+returns+] inputFile (Full path to downloaded file)
    def downloadFile(file)
      fileBase = @fileApiHelper.extractName(file)
      inputFile = "#{CGI.escape(fileBase)}"
      ww = File.open(inputFile, "w")
      inputUri = URI.parse(file)
      rsrcPath = "#{inputUri.path}/data?"
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(file)}" if(@dbApiHelper.extractGbKey(file))
      apiCaller = WrapperApiCaller.new(inputUri.host, rsrcPath, @userId)
      apiCaller.get() { |chunk| ww.print(chunk) }
      ww.close()
      if(!apiCaller.succeeded?)
        @errUserMsg = "Failed to download file: #{fileBase} from server"
        raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
      end
      # If its a sam file, it may require extraction
      if(inputFile !~ /\.bam$/i)
        exp = BRL::Genboree::Helpers::Expander.new(inputFile)
        exp.extract()
        if(exp.uncompressedFileList.size > 1)
          @errUserMsg = "#{File.basename(fileBase)} extracted to more than 1 file. This is not supported."
          raise @errUserMsg
        end
        `mv #{exp.uncompressedFileList[0]} #{File.dirname(inputFile)}`
        `rm -rf #{exp.tmpDir}`
        inputFile = File.basename(exp.uncompressedFileList[0])
      end
      return inputFile
    end

    # Overrides the parent method for writing a success email to the user for the tool being run
    # [+returns+] nil
    def prepSuccessEmail()
      additionalInfo = "  Database: '#{@dbName}'\n  Group: '#{@groupName}'\n\n" +
                        "You can download the resultant file: '#{CGI.unescape(@resultFileBaseName)}' from the '#{@target}' folder. "
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return successEmailObject
    end

    # Overrides the parent method for writing a failure email to the user for the tool being run
    # [+returns+] nil
    def prepErrorEmail()
      additionalInfo = "     Error:\n#{@errUserMsg}\n\n\nPlease make sure that you are uploading only BAM/SAM files."
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::RemoveDuplicatesWrapper)
end
