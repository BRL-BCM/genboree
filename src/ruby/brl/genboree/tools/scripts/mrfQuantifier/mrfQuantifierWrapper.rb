#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class MrfQuantifierWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'MrfQuantifier'.
                        This tool is intended to be called internally via the wrappers",
      :authors      => [ "Sai Lakshmi Subramanian(sailakss@bcm.edu)" ],
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
        # Options to run mrfQuantifier
        @mrfFile = @inputs[0]
        @genomeVersion = @settings['genomeVersion']
        if(!@genomeVersion.nil?)
          @gbRSeqToolsGenomesInfo = JSON.parse(File.read(@genbConf.gbRSeqToolsGenomesInfo))
          @geneAnnoIndexBaseName = @gbRSeqToolsGenomesInfo[@genomeVersion]['indexBaseName']
          if(@geneAnnoIndexBaseName.nil?)
            @errUserMsg = "The reference gene annotations for genome: #{@genomeVersion} could not be found since this annotation is not supported currently.\nPlease contact the Genboree Administrator for adding support for this gene annotation. "
            raise @errUserMsg
          end
        end
        @rseqtoolsKnownGeneAnnoDir = ENV['RSEQTOOLS_ANNOS']
        @genomeKnownGeneAnnoDir = "#{@rseqtoolsKnownGeneAnnoDir}/#{@geneAnnoIndexBaseName}"
        @knownGeneCompositeModel = "#{@genomeKnownGeneAnnoDir}/knownGene_composite.interval"
      
        if(!File.exists?(@knownGeneCompositeModel))
          @errUserMsg = "Gene annotation composite model #{@knownGeneCompositeModel} is unavailable. Please contact the Genboree Administrator about this."
          raise @errUserMsg
        end

        ## This prevents the wrapper from sending emails when tool is called internally from other wrappers
        @suppressEmail = (@settings["suppressEmail"].to_s.strip =~ /^(?:true|yes)$/i ? true : false)
        
        @overlapType = @settings['overlapType']
        @analysisName = @settings['analysisName']
        
        @scratchDir = @context['scratchDir']
        @outFile = "#{@scratchDir}/#{CGI.escape(@analysisName)}_geneExpression.txt"

        @outputLocally = (@outputs[0] =~ /^\// ? true : false )       
        if(@outputLocally)
          @resultsDir = File.expand_path(@outputs[0])
        else
          ## Currently this tool is implemented to be called internally from wrappers,
          ## so the resultsDir will be same as scratchDir
          ## This else section can be modified to accept Genboree URLs when the tool
          ## is implemented to be called from workbench UI
          @resultsDir = "."
        end  

        ## Make the results directory
        `mkdir -p #{@resultsDir}`
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracted these settings from jobFile:\n\n @resultsDir => #{@resultsDir.inspect}\n @mrfFile => #{@mrfFile.inspect}\n @fileAnnotation => #{@fileAnnotation}\n @overlapType => #{@overlapType}\n @outFile => #{@outFile}\n\n") 
      
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = "ERROR: Could not set up required variables for running job. "
        @err = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        # Run the tool. 
        @errFile = "#{@scratchDir}/mrfQuantifier.err"
        command = "cat #{@mrfFile} | mrfQuantifier #{@knownGeneCompositeModel} #{@overlapType} "
        command << " > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
        exitStatus = system(command)
        if(!exitStatus)
          @errUserMsg = "MrfQuantifier failed to run"
          raise "Command: #{command} died. Check #{@outFile} and #{@errFile} for more information."
        end
      
        if(@outputLocally)
          system("mv #{@outFile} #{@resultsDir}")
          #system("mv #{@scratchDir}/* #{@resultsDir}")
          `touch #{@scratchDir}/internalWrapperJob.txt`
        else
          ## Modify this section to copy files to Genboree target db
          ## if Genboree specific URL is provided in the output targets section
            ## Doing nothing now
        end

      rescue => err
        @err = err
        # Try to read the out file first:
        outStream = ""
        outStream << File.read(@outFile) if(File.exists?(@outFile))
        # If out file is not there or empty, read the err file
        if(!outStream.empty?)
          errStream = ""
          errStream = File.read(@errFile) if(File.exists?(@errFile))
          @errUserMsg = errStream if(!errStream.empty?)
        end
        @exitCode = 30
      end
      return @exitCode
    end

    def prepSuccessEmail()
      additionalInfo = "MrfQuantifier ran successfully."
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      if(@suppressEmail)
        return nil
      else
        return successEmailObject
      end
    end


    def prepErrorEmail()
      additionalInfo = @errUserMsg
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil, @shortToolTitle)
      if(@suppressEmail)
        return nil
      else
        return errorEmailObject
      end
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::MrfQuantifierWrapper)
end
