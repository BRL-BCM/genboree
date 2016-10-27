#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/util/expander'
require 'brl/util/samTools'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/convertText'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class CreateBAIWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used to generate BAI (index) files for BAM/SAM file(s). It is intended to be called from the workbench.",
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
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        # Download the BAM/SAM file(s) one at a time and generate the corresponding BAI file
        skippedFiles = []
        @linkHash = {}
        @inputs.each { |input|
          uriObj = URI.parse(input)
          apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/data?", @userId)
          fileName = CGI.escape(File.basename(@fileApiHelper.extractName(input)))
          ff = File.open(fileName, 'w')
          apiCaller.get() { |chunk| ff.print(chunk) }
          ff.close()
          bamFile= nil
          isSAMFile = false
          # Convert SAM to BAM if file is SAM
          if(fileName =~ /\.SAM/i)
            isSAMFile = true
            exp = BRL::Util::Expander.new(fileName)
            exp.extract()
            fileName = exp.uncompressedFileName
            bamFile = fileName.gsub(/SAM$/i, 'bam')
            BRL::Util::SamTools.sam2bam(fileName, bamFile)
          elsif(fileName =~ /\.BAM/i)
            bamFile = fileName
          else
            @skippedFiles << input
            next
          end
          # Sort the bam file if not sorted already
          if(!BRL::Util::SamTools.isBamSorted?(bamFile))
            BRL::Util::SamTools.sortBam(bamFile)
            bamFile.gsub!(/\.bam$/, '.sorted.bam') # The sort function replaces the suffix .bam with .sorted.bam
          end
          BRL::Util::SamTools.generateIndex(bamFile)
          indexFile = "#{bamFile}.bai"
          subdir = @fileApiHelper.subdir(input)
          dbUri = URI.parse(@dbApiHelper.extractPureUri(input))
          rsrcPath = nil
          attrRsrcPath = nil
          attrName = 'gbBAM'
          if(subdir == '/') # The target is a db or top level 'Files' folder
            rsrcPath = "#{dbUri.path}/file/#{File.basename(indexFile)}"
            attrRsrcPath = "#{dbUri.path}/file/#{File.basename(indexFile)}/attribute/#{attrName}/value?"
          else
            rsrcPath = "#{dbUri.path}/file#{subdir.chomp('/')}/#{File.basename(indexFile)}"
            attrRsrcPath = "#{dbUri.path}/file#{subdir.chomp('/')}/#{File.basename(indexFile)}/attribute/#{attrName}/Value?"
          end
          apiCaller.setRsrcPath("#{rsrcPath}/data?")
          apiCaller.put({}, File.open(indexFile))
          # Also transfer the BAM file if the input is a SAM file
          rsrcPathForBAM = nil
          fullUriForBAM = nil
          if(isSAMFile)
            if(subdir == '/')
              rsrcPathForBAM = "#{dbUri.path}/file/#{File.basename(bamFile)}/data?"
            else
              rsrcPathForBAM = "#{dbUri.path}/file#{subdir.chomp('/')}/#{File.basename(bamFile)}/data?"
            end
            apiCaller.setRsrcPath(rsrcPathForBAM)
            apiCaller.put({}, File.open(bamFile))
            fullUriForBAM = "http://#{dbUri.host}#{rsrcPathForBAM.gsub(/\/data\?$/, '')}?"
          end
          `rm -f #{indexFile}`
          apiCaller.setRsrcPath(attrRsrcPath)
          gbBamLink = ( isSAMFile ? fullUriForBAM : input)
          payload = { "data" => {"text" => gbBamLink} }
          apiCaller.put(payload.to_json)
          gbBaiLinkRsrcPath = ( isSAMFile ? URI.parse(fullUriForBAM).path : uriObj.path )
          apiCaller.setRsrcPath("#{gbBaiLinkRsrcPath}/attribute/gbBAI/value?")
          payload = { "data" => {"text" => "http://#{uriObj.host}#{rsrcPath}?" } }
          apiCaller.put(payload.to_json)
          linkHashKey = ( isSAMFile ? "#{input},#{fullUriForBAM}" : input) 
          @linkHash[linkHashKey] = "#{CGI.unescape(subdir).chomp('/')}/#{CGI.unescape(File.basename(indexFile))}"
          `rm -f #{bamFile} #{fileName}` # Cleanup
          `rm -f #{CGI.escape(File.basename(@fileApiHelper.extractName(input)))}`
        }
        if(skippedFiles.size == @inputs.size)
          raise "None of the input file(s) seem to be of BAM/SAM format. Please make sure that your input files are SAM/BAM."
        end
      rescue => err
        @err = err
        @errUserMsg = err.message
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      end
      return @exitCode
    end


    # Send success email
    # [+returns+] emailObj
    def prepSuccessEmail()
      additionalInfo = "The BAI file(s) have been generated in the same folder as the source file(s).\n\n"
      additionalInfo << "Below is a mapping of the input file(s) to their corresponding BAI file:\n"
      @linkHash.each_key { |keyStr|
        keyEls = keyStr.split(',')
        key = keyEls[0]
        gp = @grpApiHelper.extractName(key)
        db = @dbApiHelper.extractName(key)
        host = @dbApiHelper.extractHost(key)
        bamFileStr = ( keyEls.size == 1 ? "" : "(/#{@fileApiHelper.extractName(keyEls[1])})" )
        additionalInfo << "/#{@fileApiHelper.extractName(key)} #{bamFileStr} => #{@linkHash[keyStr]} (#{gp}:#{db})\n\n"  
      }
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return successEmailObject
    end

    # Send failure/error email
    # [+returns+] emailObj
    def prepErrorEmail()
      additionalInfo = "     Error:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::CreateBAIWrapper)
end
