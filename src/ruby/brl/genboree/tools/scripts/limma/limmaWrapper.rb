#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'

include BRL::Genboree::REST


module BRL ; module Genboree; module Tools
class WrapperUserLimma < ToolWrapper
  attr_accessor :user_first, :user_last, :toolTitle, :exitCode, :apiExitCode, :input, :email
  attr_accessor :jobID, :studyName

  VERSION = "1.0"

    DESC_AND_EXAMPLES = {
      :description => "Wrapper to run tool, which runs limma on user uploaded data",
      :authors      => [ "Sriram Raghuraman" ],
      :examples => [
        "#{File.basename(__FILE__)} --jsonFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
   # . Prepare successmail
    def prepSuccessEmail
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      emailObject.additionalInfo = @additionalInfo
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      emailObject.resultFileLocations = "http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape("#{@pathOutput}/file/Limma/#{CGI.escape(@analysis)}/raw.results.zip/data")}"

      return emailObject
    end

    # . Prepare Failure mail
    def prepErrorEmail
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @firstName
      emailObject.userLast      = @lastName
      emailObject.analysisName  = @analysis
      inputsText                = buildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.errMessage    = @errMsg
      emailObject.exitStatusCode = @exitCode
      return emailObject
    end

  
    def processJobConf()
    @inputs      = @jobConf["inputs"]
    @outputs     = @jobConf["outputs"]
    @matrixFileURI = @inputs[0]
    @metadataFileURI = @jobConf["settings"]["metadataFile"]
    @gbConfFile = @jobConf["context"]["gbConfFile"]
    @apiDBRCkey = @jobConf["context"]["apiDbrcKey"]
    @scratch    = @jobConf["context"]["scratchDir"]
    @userEmail      = @jobConf["context"]["userEmail"]
    @firstName = @jobConf["context"]["userFirstName"]
    @lastName  = @jobConf["context"]["userLastName"]
    @username   = @jobConf["context"]["userLogin"]
    @gbAdminEmail = @jobConf["context"]["gbAdminEmail"]
    @jobID      = @jobConf["context"]["jobId"]
    @userId     = @jobConf["context"]["userId"]
    @prefix = @jobConf["context"]["toolScriptPrefix"]
    @normalize    = @jobConf['settings']['normalize']
    @analysis  = @jobConf["settings"]["analysisName"]
    @sortby     = @jobConf["settings"]["sortBy"]
    @minPval    = @jobConf["settings"]["minPval"]
    @minAdjPval = @jobConf["settings"]["minAdjPval"]
    @minFoldCh  = @jobConf["settings"]["minFoldChange"]    
    @minBval    = @jobConf["settings"]["minBval"]
    @testMethod = @jobConf["settings"]["testMethod"]
    @adjustMethod= @jobConf["settings"]["adjustMethod"]
    @multiplier   = @jobConf["settings"]["multiplier"]
    if(@multiplier.nil? or @multiplier.to_f <= 0) then @multiplier = 1 end
      
    @maxMatrixEntries = 250_000_000
    @metadata   = @jobConf["settings"]["metaDataColumns"]
    @metadataTemp = ""
    @metadata.each {|meta|
      @metadataTemp << "#{File::makeSafePath(meta,:underscore)},"
    }
    @metadataTemp.chomp!(",")
    @metadata = @metadataTemp
    
    @filJobName = CGI.escape(@analysis).gsub(/%[0-9a-f]{2,2}/i, "_")
    
    # One apiCaller to rule them all
    @apiCaller = WrapperApiCaller.new("","",@userId)
    
    @dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @fileHelper = BRL::Genboree::REST::Helpers::FileApiUriHelper.new(@gbConfFile)

    ##pulling out upload location specifications
    @output = @outputs[0].chomp('?')
    uriOutput = URI.parse(@output)
    @hostOutput = uriOutput.host
    @pathOutput = uriOutput.path
    return EXIT_OK
  end


  def downloadFile(fileURI,filePath)
    path = "#{@fileHelper.extractPath(fileURI)}/data"
    path << "?gbKey=#{@dbhelper.extractGbKey(fileURI)}" if(@dbhelper.extractGbKey(fileURI))
    puts "Downloading file #{fileURI} to #{File.basename(filePath)}"
    saveFile = File.open(filePath,"w")
    @apiCaller.setHost(@fileHelper.extractHost(fileURI))
    @apiCaller.setRsrcPath(path)
    httpResp = @apiCaller.get(){|chunk| saveFile.write chunk}
    saveFile.close
    if @apiCaller.succeeded?
      $stdout.puts "Successfully downloaded #{File.basename(filePath)}"
      return EXIT_OK
    else
      $stderr.puts @apiCaller.respBody().inspect
      @errMsg = "Unable to download file #{fileURI}"
      raise @errMsg
      #@apiCaller.parseRespBody()
      #$stderr.puts "API response; message: #{@apiCaller.inspect}"
      #raise "#{@apiCaller.apiStatusObj['msg']}"
    end
  end


  def processMetadataFile
    system("mv #{@outputDir}/metadata.txt #{@outputDir}/metadata-raw.txt")
    ifh=File.open("#{@outputDir}/metadata-raw.txt","r")
    ofh=File.open("#{@outputDir}/metadata.txt","w")
    header=ifh.readline().chomp
    header.gsub!(/^#/,"")
    sl = header.split(/\t/).map{|xx| File::makeSafePath(xx,:ultra)}

    sl.each{|ss| @valueSet << Hash.new(0)}
    headerMap={}

    sl.each_index{|ii|
      newsl = File::makeSafePath(sl[ii],:ultra)
      headerMap[sl[ii]] = newsl
      @headerNames << newsl
    }

    newHeader = @headerNames.join("\t")
    ofh.puts newHeader
    ifh.each_line{|ll|
      sl=ll.chomp.split(/\t/)
      sl.each_index{|ii| @valueSet[ii]["X#{sl[ii]}"] += 1}
      ofh.print ll
    }
    ofh.close
    ifh.close
    system("rm #{@outputDir}/metadata-raw.txt")
    @headerNames = @headerNames[1 .. -1]
    @valueSet = @valueSet[1 .. -1]
    @valueSet.each_index{|ii|
      vv = @valueSet[ii]
      if(vv.keys.length < 2) then
        @errMsg = "Unable to use attribute #{@headerNames[ii]}.\nEach metadata attribute must have atleast two distinct values for this limma tool to run successfully."
        raise @errMsg
      end
      vv.each_key{|kk|
        if(vv[kk] < 2) then
          @errMsg = "Unable to use attribute #{@headerNames[ii]}.\nEach attribute value must have atleast two samples associated with it for this limma tool to run successfully."
          raise @errMsg
        end
      }
    }
    return EXIT_OK
  end
  
  def createDesignFiles
    dfh = []
    @headerNames.each{|hh|
      fh = File.open("#{@outputDir}/#{hh}Design.txt","w")
      fh.puts "sample\tTarget"
      dfh<<fh
      }
    mfh = File.open("#{@outputDir}/metadata.txt")
    mfh.readline
    mfh.each_line{|line|
      sl=line.chomp.split(/\t/)
      (1 .. sl.length-1).each{|ss|
        dfh[ss-1].puts "#{sl[0]}\tX#{sl[ss]}"
        }
      }
    mfh.close
    dfh.each{|dd| dd.close}
  end
  
  def runLimma
    createDesignFiles()
    errorState = false
    @headerNames.each_index{|hh|
      vals = @valueSet[hh].keys
      numSets = vals.length
      setString = StringIO.new
      normalizeString = nil
      if(@normalize == "Quantile") then
          normalizeString = "dataMatrixNormalize <- normalize.quantiles(dataMatrix, copy=TRUE)"
        elsif(@normalize == "Percentage")
          normalizeString = "dataMatrix[is.na(dataMatrix)]<-0\ncolSums <- apply(dataMatrix,2,sum)\n"+
          "dataMatrixNormalize <- t(apply(dataMatrix,1,function(x) (x/colSums)*#{@multiplier}))"
        else
          normalizeString = "dataMatrixNormalize <- dataMatrix"
        end
      contrastString = nil
      if(numSets > 2) then
        (0 .. numSets-2).each{|ii|
          (ii+1 .. numSets-1).each{|jj|
            setString << " #{vals[ii]} - #{vals[jj]},"
          }
        }
        contrastString = "makeContrasts(#{setString.string} levels=design)"
      else
        contrastString = "makeContrasts(#{vals[0]}Vs#{vals[1]}=#{vals[0]}-#{vals[1]}, levels=design)"
      end
      valString = vals.map{|vv| "\"#{vv}\""}.join(",")
      limmaFileName = "#{@headerNames[hh]}.R"
      limmaFile = File.open("#{@outputDir}/#{limmaFileName}","w")
      limmaFile.print <<-END
      library(preprocessCore)
      library(limma)
      pathPrefix <- \"#{@outputDir}\"
      dataMatrix <- read.table(paste(pathPrefix,\"/\",\"matrix.txt\",sep=\"\"),check.names=FALSE,header=TRUE,row.names=1)     
      dataMatrix <- as.matrix(dataMatrix)
      #{normalizeString}
      rownames(dataMatrixNormalize) <- rownames(dataMatrix)
      colnames(dataMatrixNormalize) <- colnames(dataMatrix)
      write.table(dataMatrixNormalize,file=paste(pathPrefix,\"/\",\"normalizedMatrix.txt\",sep=\"\"),quote=FALSE,sep='\\t')
      targets <- readTargets(file=paste(pathPrefix,\"/\",\"#{@headerNames[hh]}Design.txt\",sep=\"\"))
      f <- factor(targets$Target, levels = c(#{valString}))
      design <- model.matrix(~0 + f)
      colnames(design) <- c(#{valString})
      cont.matrix <- #{contrastString}
        fit <- lmFit(dataMatrixNormalize, design)
        fit2 <- contrasts.fit(fit, cont.matrix)
        fit2 <- eBayes(fit2)
        topResults <- toptable(fit2, adjust.method = \"#{@adjustMethod}\",number="inf")
        row.names(topResults) <- row.names(dataMatrixNormalize)[as.integer(row.names(topResults))]
        write.table(topResults,file=paste(pathPrefix,\"/\",\"#{@headerNames[hh]}_topTableNoFilter.txt\",sep=\"\"),col.names=NA,quote=FALSE,sep='\\t')
        topResults<-topResults[which(abs(topResults[,2]) > abs(#{@minFoldCh})),]
        opResults <- topResults[which((topResults[,"P.Value"] < #{@minPval}) & (topResults[,"adj.P.Val"] < #{@minAdjPval})),]        
        write.table(topResults,file=paste(pathPrefix,\"/\",\"#{@headerNames[hh]}_topTable.txt\",sep=\"\"),quote=FALSE,col.names=NA,sep='\\t')
        results <- decideTests(fit2, method=\"#{@testMethod}\", adjust.method=\"#{@adjustMethod}\", p.value=#{@minAdjPval}, lfc=#{@minFoldCh})
        write.table(results,file=paste(pathPrefix,\"/\",\"#{@headerNames[hh]}_decideTests.txt\",sep=\"\"),col.names=NA,quote=FALSE,sep='\\t')
        write.table(summary(results),file=paste(pathPrefix,\"/\",\"#{@headerNames[hh]}_decideTestsClassification.txt\",sep=\"\"),quote=FALSE,col.names=NA,sep='\\t')
        END
        limmaFile.close
        $stderr.debugPuts(__FILE__, __method__, "Status", "Running Limma for attribute #{@headerNames[hh]}")
        system("Rscript --vanilla #{@outputDir}/#{limmaFileName}")
        exitStatus = ($?.success?) ? EXIT_OK : 113
        if(exitStatus != EXIT_OK) then errorState = true end
        $stderr.debugPuts(__FILE__, __method__, "Status", "Limma tool completed with #{exitStatus} for attribute #{@headerNames[hh]}")
      }
    if(errorState) then return 113 else return EXIT_OK end
    end

    def checkMatrixSize(filePath,limit)
      numFileLines = `wc -l '#{filePath}'`.split(/\s+/).first.to_i
      matrixSize = numFileLines * (@headerNames.length)
      if(matrixSize > limit) then
        @errMsg = "Unfortunately, the size of your data set is too large to analyze with LIMMA."+
        "\n- Your matrix has #{numFileLines} annotations."+
        "\n- You have #{(@headerNames.length).commify} samples (tracks)."+
        "\nThis is a total of #{matrixSize.commify} datapoints."+
        "\nDue to memory constraints, we cannot accept LIMMA analysis jobs with more than #{@maxMatrixEntries.commify} total data points."
        return false
      else
        return true
      end
    end

    def run      
      system("mkdir -p #{@scratch}")
      Dir.chdir(@scratch)
      @outputDir = "#{@scratch}/#{@filJobName}"
      system("mkdir -p #{@outputDir}")
      downloadFile(@matrixFileURI,"#{@outputDir}/matrix.txt")
      downloadFile(@metadataFileURI,"#{@outputDir}/metadata.txt")
      begin
        @valueSet = []
        @headerNames = []
        exitStatus = processMetadataFile()
        if(exitStatus != EXIT_OK) then
          @errMsg = "Error processing metadata file"
          $stderr.debugPuts(__FILE__, __method__, "ERROR",@errMsg)
          exitStatus = 120
        else
          if(checkMatrixSize("#{@outputDir}/matrix.txt",@maxMatrixEntries)) then
            exitStatus = runLimma()
            if(exitStatus != EXIT_OK) then
              @errMsg = "Error running Limma tool"
              $stderr.debugPuts(__FILE__, __method__, "ERROR",@errMsg)
              exitStatus = 113
            else
              $stderr.debugPuts(__FILE__, __method__, "Done","Limma ran successfully")
              compressFiles()
              uploadStatus = uploadResults()
              if (uploadStatus!=EXIT_OK) then
                @errMsg = "Result data upload failed"
                $stderr.debugPuts(__FILE__, __method__, "ERROR", @errMsg)
                exitStatus = 118
              else
                exitStatus=EXIT_OK
              end
            end
          else
            $stderr.debugPuts(__FILE__, __method__, "Error", "Matrix size exceeds maximum limit")
            exitStatus = 120
          end
        end
      rescue => err
        $stderr.debugPuts(__FILE__,__method__,"Error",err.inspect)
        @errMsg = err.message
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 121
      ensure
        @exitCode = exitStatus
        return exitStatus
      end
    end


    ##tar of output directory
    def compressFiles
      Dir.chdir(@outputDir)
      system("zip raw.results.zip * -x *atrix.txt -x metadata.txt -x *Design.txt -x *NoFilter.txt -x *.R")
    end


    def uploadUsingAPI(jobName,fileName,filePath)
      @apiCaller.setHost(@hostOutput)
      restPath = @pathOutput
      path = restPath +"/file/{file}/data"
      path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
      @apiCaller.setRsrcPath(path)
      $stderr.debugPuts(__FILE__,__method__,"PATH",path)
      infile = File.open("#{filePath}","r")
      @apiCaller.put({:file=>"Limma/#{jobName}/#{fileName}"},infile)
      if @apiCaller.succeeded?
        $stdout.puts "Successfully uploaded #{fileName} "
        return EXIT_OK
      else
        $stderr.puts @apiCaller.respBody()
        @errMsg = "Unable to upload file #{fileName} to #{filePath}"
        raise @errMsg
        #$stderr.puts "API response; statusCode: #{@apiCaller.apiStatusObj['statusCode']}, message: #{@apicaller.apiStatusObj['msg']}"
        #@exitCode = @apiCaller.apiStatusObj['statusCode']
        #raise "#{@apiCaller.apiStatusObj['msg']}"
      end
    end

def uploadResults()
      exitStatus = EXIT_OK
      begin
        exitStatus = uploadUsingAPI(@analysis,"raw.results.zip","#{@outputDir}/raw.results.zip")
        if(exitStatus != EXIT_OK) then exitStatus = 118 end
      rescue => err
        $stderr.debugPuts(__FILE__,__method__,"Error",err.inspect)
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        exitStatus = 118
      end
      return exitStatus
    end

    def WrapperUserLimma.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

      PROGRAM DESCRIPTION:
      Limma wrapper for  microbiome workbench
      COMMAND LINE ARGUMENTS:
      --file         | -j => Input json file
      --help         | -h => [Optional flag]. Print help info and exit.

      usage:

      ruby Limmawrapper.rb -f jsonFile
      ";
      exit;
    end #

  end
end ; end; end;
if($0 and File.exist?($0) )
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::WrapperUserLimma)
end
