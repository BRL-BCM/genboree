#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/util/expander'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/convertText'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class SamplesImporter < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used for importing sample data to Genboree.",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # @todo pull this from UI?
    IMPORT_BEHAVIORS = {
      "create" => "Create New Record",
      "merge" => "Merge and Update",
      "replace" => "Replace Existing",
      "keep" => "Keep Existing"
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
        @importBehavior = @settings['importBehavior']
        @renameChar = @settings['renameChar']
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
        # Set up format options coming from the UI
        @sampleSetName = nil
        @successFiles = []
        @additionalInfo = '' # additional information to provide in email to user
        @failureFiles = {}
        if(@sampleSetApiHelper.extractName(@outputs[0]))
          @sampleSetName = @sampleSetApiHelper.extractName(@outputs[0])
        else
          @sampleSetName = ( (!@settings['sampleSetName'].nil? and !@settings['sampleSetName'].empty?) ? @settings['sampleSetName'] : nil )
        end
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
        @inputs.each {|input|
          if(@fileApiHelper.extractName(input))
            fileName = downloadFile(input)
            importSamples(fileName)
          else
            uriObj = URI.parse(input)
            apiCaller = WrapperApiCaller.new(uriObj.host, uriObj.path, @userId)
            apiCaller.get()
            resp = apiCaller.parseRespBody()['data']
            if(input =~ /\/files\/entityList\//)
              resp.each {|fileUri|
                fileName = downloadFile(fileUri['url'])
                importSamples(fileName)
              }
            else
              resp.each { |fileObj|
                fileName = downloadFile(fileObj['refs'][BRL::Genboree::REST::Data::DatabaseFileEntity::REFS_KEY])
                importSamples(fileName)
              }
            end
          end
        }
        if(@successFiles.empty?)
          @errUserMsg = "None of the input files could be successfully imported as sample data. Below is a list of the files with their respective problem:\n"
          @failureFiles.each_key { |file|
            @errUserMsg << " * #{File.basename(file)}: #{@failureFiles[file]}\n"
          }
          raise "No files could be successully imported as samples.\n\n#{@errUserMsg}"
        end
      rescue => err
        @err = err
        @errUserMsg = err.message if(@errUserMsg.nil? or @errUserMsg.empty?)
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      end
      return @exitCode
    end

    def importSamples(fileName)
      # Extract and convert the file to unix before uploading
      exp = BRL::Util::Expander.new(fileName)
      exp.extract()
      outputUri = URI.parse(@dbApiHelper.extractPureUri(@outputs[0]))
      exp.each {|file|
        convTextObj = BRL::Util::ConvertText.new(file, replaceOrig=true)
        convTextObj.convertText()
        uriObj = URI.parse(@dbApiHelper.extractPureUri(@outputs[0]))
        apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/samples?format=tabbed&importBehavior=#{@importBehavior}&renameChar=#{@renameChar}", @userId)
        apiCaller.put(File.read(file))
        if(!apiCaller.succeeded?)
          @failureFiles[File.basename(file)] = apiCaller.parseRespBody['status']['msg']
        else
          @successFiles << File.basename(file)
          # Link samples to sample set name if sample set name provided
          if(@sampleSetName)
            sampleList = []
            rr = File.open(file)
            rr.each_line { |line|
              line.strip!
              next if(line.nil? or line.empty? or line =~ /^#/)
              # The fields other than name don't really matter here because this payload is only going to be used for adding to a sample set where only name is important
              sampleList << { "name" => line.split(/\t/)[0].strip, "type" => "", "biomaterialProvider" => "", "biomaterialState" => "", "biomaterialSource" => "", "state" => 0, "avpHash" => {}}
            }
            rr.close()
            payload = { "data" =>  sampleList }
            apiCaller = WrapperApiCaller.new(outputUri.host, "#{outputUri.path}/sampleSet/#{CGI.escape(@sampleSetName)}/samples?", @userId)
            apiCaller.put(payload.to_json)
          end
        end
      }
      `rm -rf #{Shellwords.escape(exp.tmpDir)}`
      `rm -f #{Shellwords.escape(fileName)}`
    end

    def downloadFile(file)
      fileName = File.basename(@fileApiHelper.extractName(file))
      uriObj = URI.parse(file)
      apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/data?", @userId)
      ff = File.open(fileName, 'w')
      apiCaller.get() { |chunk| ff.print(chunk) }
      ff.close()
      return fileName
    end

    # Send success email
    # [+returns+] emailObj
    def prepSuccessEmail()
      additionalInfo = "Sample data was imported successfully from the following files:\n"
      @successFiles.each {|file|
        additionalInfo << " * #{File.basename(file)}"
        additionalInfo << "\n"
      }
      if(@sampleSetName)
        additionalInfo << "\n\nYour samples have been included in the sample set: #{@sampleSetName}\n"
      end
      settings = nil
      unless(@importBehavior.nil? or @importBehavior.empty?)
        settings = {
          "Import Behavior" => IMPORT_BEHAVIORS[@importBehavior]
        }
      end
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return successEmailObject
    end

    # Send failure/error email
    # [+returns+] emailObj
    def prepErrorEmail()
      additionalInfo = @errUserMsg
      settings = nil
      unless(@importBehavior.nil? or @importBehavior.empty?)
        settings = {
          "Import Behavior" => IMPORT_BEHAVIORS[@importBehavior]
        }
      end
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::SamplesImporter)
end
