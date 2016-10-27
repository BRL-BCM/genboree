#!/usr/bin/env ruby
#########################################################
############ smRNAPipeline metadata bulk upload #####
## This wrapper splits the metadata doc file into individual 
## collections and uploads them to the appropriate collection
## in GenboreeKB
#########################################################

require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/sniffer'
require 'brl/genboree/abstract/resources/user'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class ExRNAMetadataUploadWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for uploading metadata to GenboreeKB exRNA metadata Collections'.
                        This tool is intended to be called when jobs are submitted through the workbench or by the FTP Pipeline",
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
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        
        ## Genboree specific "context" variables
        @dbrcKey = @context['apiDbrcKey']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)

        #@host = "genboree.org"

        ## Get GenboreeKB details
        @exRNAKbGroup = @settings['exRNAKbGroup']
        @exRNAKb = @settings['exRNAKb']
 
        # Define metadata collections and the corresponding name used in the Doc
        #@metadataObjects = {"Biosample"=>"Biosamples", "Run"=>"Runs", "Analysis"=>"Analyses", "Experiment"=>"Experiments", "Study"=>"Studies", "Submission"=>"Submissions"}
        @metadataObjects = JSON.parse(File.read(@genbConf.kbExRNAMetadataCollections))
        
        ## If wrapper is called internally from another tool, 
        ## it is very useful to suppress emails
        @suppressEmail = (@settings["suppressEmail"].to_s.strip =~ /^(?:true|yes)$/i ? true : false)
           
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. \n"
        @errInternalMsg = "ERROR: Could not set up required variables for running job. \nCheck your jobFile.json to make sure all variables are defined."
        @err = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        # Get data
        command = ""
        @outFile = "" 
        @user = @pass = nil
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          # get super user, pass and hostname
          @user = dbrc.user
          @pass = dbrc.password
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          @user = suDbDbrc.user
          @pass = suDbDbrc.password
        end
        @metadataFiles = []
        @uploadStats = {} 
        @outFile = "#{@scratchDir}/exRNAMetadataUpload.out"
        
        # Download the input from the server
        downloadFiles()
       
        @metadataFiles.each { |metadataFile|
          # Split metadata docs for various collections (if multiple docs are available in the same file)
          docObj = splitDocs(metadataFile)
   
          # Upload docs to various collections in the exRNA GenboreeKB
          uploadToKB(docObj)  
        }
       
        exRNAMetadataResults = File.open(@outFile,"w") 
          
        @uploadStats.each { |collName, uploadMsg|
          exRNAMetadataResults.puts "#{collName}:\n#{uploadMsg}\n\n"
        }
 
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of exRNA Metadata Upload wrapper failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to upload your docs to GenboreeKB." if(@errInternalMsg.nil?)
        @exitCode = 30
      end
      return @exitCode
    end

####################################
#### Methods used in this wrapper
####################################

    ## Download input files from database
    def downloadFiles()
      @inputs.each { |input|
        @inputLocal = (input =~ /^\// ? true : false )
        
        if(@inputLocal)
          fileBaseName = File.basename(input)
          tmpFile = fileBaseName.makeSafeStr(:ultra)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Copying input file #{input} to #{@scratchDir}/#{tmpFile}")
          `cp #{input} #{@scratchDir}/#{tmpFile}`
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading input file #{input}")
          fileBase = @fileApiHelper.extractName(input)
          fileBaseName = File.basename(fileBase)
          tmpFile = fileBaseName.makeSafeStr(:ultra)
          retVal = @fileApiHelper.downloadFile(input, @userId, tmpFile)
          if(!retVal)
            @errUserMsg = "Failed to download file: #{fileBase} from server"
            raise "ApiCaller Failed: #{apiCaller.respBody.inspect}"
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "File downloaded successfully to #{tmpFile}")
          end
        end

        ## Extract the file if it is compressed
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        exp.extract()

        ## TODO: Some sniffer to ensure this is two column tab separated prop-value file?
=begin
        # Sniffer - To check FASTQ format
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Detecting Fastq file type using sniffer")
        sniffer = BRL::Genboree::Helpers::Sniffer.new()
        inputFileFastq1 = true 
          @inputFile1 = exp.uncompressedFileName
          if(File.zero?(@inputFile1))
            @errUserMsg = "Input file is empty. Please upload non-empty file and try again."
            raise @errUserMsg
          end
          #Detect if file is in FASTQ format
          sniffer.filePath = @inputFile1
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sniffing file #{@inputFile1}")
          unless(sniffer.detect?("fastq"))
            inputFileFastq1 = false
            @errUserMsg = "Input file is not in FASTQ format. Please check the file format."
            raise @errUserMsg
          end
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done Sniffing file type")
=end
        # Convert to unix format
        convObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, true)
        convObj.convertText()
        @inputFile = exp.uncompressedFileName
        @metadataFiles << @inputFile
      }
    end

    ## Split docs for various collections
    def splitDocs(inputFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Splitting docs into various collections")

      ## Split docs into various collections
      docObjects = {}
      @metadataObjects.each {|mdObj, collName|
        docObjects[collName] = ""
      }

      linesInFile = File.read(inputFile)
      @docsArray = linesInFile.split(/^(?=#)/)

      @docsArray.each{ |data|
      #$stderr.puts "doc  = #{data}"
        @metadataObjects.each {|mdObj, collName|
          if(data =~ /^#{mdObj}/)
            #$stderr.puts "doc type  = #{mdObj} so it goes into coll #{collName}"
            docObjects[collName] << data
          end
        }
      }
      #$stderr.puts "doc Objects  = #{docObjects.inspect}"

      $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE Splitting docs from various collections")
      return docObjects
    end

    ## Upload docs to GenboreeKB
    def uploadToKB(docObjects)
      $stderr.puts "doc Objects  = #{docObjects.inspect}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading docs to various collection in GenboreeKB")
      #targetUri = URI.parse(@outputs[0])
      docObjects.each { |collName, metadataDocs|
        # format tell the API the format of the payload (JSON is the default payload format)
        # docType is the document type: data or model. Currently only data is supported. 
        rsrcPath = "/REST/v1/grp/{grp}/kb/{kb}/coll/{coll}/docs?format=tabbed_prop_nesting&docType=data&responseFormat=JSON"
        next if(metadataDocs.nil? or metadataDocs.empty?)
        apiCaller = WrapperApiCaller.new(@host, rsrcPath, @userId)
        apiCaller.put(
          { :grp => "#{@exRNAKbGroup}", :kb => "#{@exRNAKb}", :coll => "#{collName}" },
            metadataDocs
        )
        if(apiCaller.succeeded?)
          uploadMsg = apiCaller.parseRespBody['status']['msg']
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded all docs to the \"#{collName}\" collection in \"#{@exRNAKb}\" KB")
        else
          uploadMsg = apiCaller.parseRespBody['status']['msg']
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to upload docs to the \"#{collName}\" collection in \"#{@exRNAKb}\" KB. API Response:\n#{apiCaller.respBody.inspect}")
        end
        @uploadStats["#{collName}"] = uploadMsg
      }
    end
   

###################################################################################
    def prepSuccessEmail()
      @settings = @jobConf['settings']
      
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = "nil"
      emailObject.inputsText    = "nil"
      emailObject.outputsText   = "nil"
      emailObject.settings      = @settings
      emailObject.exitStatusCode = @exitCode
      additionalInfo = ""
      additionalInfo << "  Metadata documents have been uploaded to various collections in GenboreeKB \n\n" +
                        "  Summary of metadata upload:\n"+
                        " ----------------------------------------\n\n" 

        @uploadStats.each { |collName, uploadMsg|
          additionalInfo << "#{collName}:\n#{uploadMsg}\n\n"
        }
      emailObject.resultFileLocations = nil
      emailObject.additionalInfo = additionalInfo
      if(@suppressEmail)
        return nil
      else
        return emailObject
      end
    end

    def prepErrorEmail()
      emailErrorObject                = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailErrorObject.userFirst      = @userFirstName
      emailErrorObject.userLast       = @userLastName
      emailErrorObject.analysisName   = "nil"
      emailObject.inputsText          = "nil"
      emailObject.outputsText         = "nil"
      emailErrorObject.settings       = @jobConf['settings']
      emailErrorObject.errMessage     = @errUserMsg
      emailErrorObject.exitStatusCode = @exitCode
      if(@suppressEmail)
        return nil
      else
        return emailErrorObject
      end
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::ExRNAMetadataUploadWrapper)
end

