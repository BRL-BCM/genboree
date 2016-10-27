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
  class PostProcessFiles < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used for the post-processing of files once they have been uploaded using the 'uploadDbFile' tool. The script mainly extracts compressed files and/or converts files to unix format.",
      :authors      => [ "Sameer Paithankar (paithank@bcm.edu)" ],
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
        @suppressEmail = (@settings["suppressEmail"].to_s.strip =~ /^(?:true|yes)$/i ? true : false)
        # Set up format options coming from the UI
        @unpack = @settings['unpack']
        @convToUnix = @settings['convToUnix']
        @fileOpts = @settings['fileOpts']
        if(@convToUnix and @fileOpts and @fileOpts == 'createName')
          @fileExt = CGI.escape(@settings['fileName'])
        else
          @fileExt = nil
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
        # Download the file to be processed one at a time
        @transferredFiles = {}
        @skippedFileHash = {}
        @inputs.each {|file|
          downloadFile(file)
          # Depending on the options selected, i.e, unpack and/or convertToUnix, process the file
          exp = processFile()
          @transferredFiles[@fileApiHelper.extractName(file)] = @filesToTransfer.dup()
          @skippedFileHash[@fileApiHelper.extractName(file)] = @skippedFiles.dup()
          @filesToTransfer.clear()
          @skippedFiles.clear()
        }
      rescue => err
        @err = err
        @errUserMsg = err.message
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      end
      return @exitCode
    end

    # Perform 'post-processing' of uploaded file
    # [+returns+] Expander Object
    def processFile()
      @filesToTransfer = []
      @skippedFiles = []
      # Instantiate the Expander class
      exp = BRL::Util::Expander.new(@fileToProcess)
      # Always extract since we cannot run even the conversions on a compressed file
      exp.extract()
      isCompressed = exp.isCompressed? ? true : false
      @multiFileArchive = exp.multiFileArchive
      @multiFileArchive = true if(exp.getFileType == 'Zip') # @multiFileArchive will be false if zip only has one file
      if(!@multiFileArchive)
        exp.each(true) { |file|
          if((exp.getFileType(file) rescue nil) != 'text')
            @skippedFiles << CGI.unescape(File.basename(file))
            next
          end
        }
        # If the user wants to create a new file, move the extracted file to be the 'new' file
        if(@fileExt)
          mvToFile = "#{File.dirname(exp.uncompressedFileName)}/#{File.basename(exp.uncompressedFileName)}#{@fileExt}"
          `mv #{exp.uncompressedFileName} #{mvToFile}`
          exp.uncompressedFileName = mvToFile
        end
        if(@unpack and @convToUnix) # Should be just one file to convert
          convTextObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, replaceOrig=true)
          convTextObj.convertText()
          # Now compress the converted file back into the original file. We will transfer both the files back
          # This will prevent any downstream errors if the user selects the compressed file for analysis
          @filesToTransfer << compressFile(exp, @fileExt.nil?) if(isCompressed)
          @filesToTransfer << exp.uncompressedFileName
        elsif(@unpack and !@convToUnix)
          exp.uncompressedFileList.each { |file|
            @filesToTransfer << file
          }
        elsif(!@unpack and @convToUnix)
          # See if the file is compressed since we cannot blindly run dos2unix/mac2unix on gzip/bzip files
          if(!isCompressed)
            convTextObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, replaceOrig=true)
            convTextObj.convertText()
            @filesToTransfer << exp.uncompressedFileName
          else
            convTextObj = BRL::Util::ConvertText.new(exp.uncompressedFileName, replaceOrig=true)
            convTextObj.convertText()
            # Now compress the converted file back into the original file. We will transfer the converted-compressed file.
            @filesToTransfer << compressFile(exp, @fileExt.nil?)
          end
        else
          # No-op
        end
        # Finally transfer the file(s) to the target
        transferFiles(exp)
      else # For multi-file archives
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Processing multi-file archive (MFA)")
        if(@convToUnix)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Converting to unix contents of MFA")
          exp.each { |file|
            if((exp.getFileType(file) rescue nil) != 'text')
              @skippedFiles << CGI.unescape(File.basename(file))
              next 
            end
            convTextObj = BRL::Util::ConvertText.new(file, replaceOrig=true)
            convTextObj.convertText()
          }
        end
        compressType = exp.getFileType(@fileToProcess)
        if(@unpack)
          exp.each(true) { |file|
            correctedPath = file.gsub(/^(.)*#{exp.tmpDir}\//, '')
            if(File.directory?(file))
              @filesToTransfer << "#{correctedPath}/"
              next
            end
            if((exp.getFileType(file) rescue nil) != 'text')
              @filesToTransfer << correctedPath
              next
            end
            if(@fileExt)
              newPath = "#{file}#{@fileExt}"
              `mv #{file} #{newPath}`
              correctedPath = newPath.gsub(/^(.)*#{exp.tmpDir}\//, '')
            end
            @filesToTransfer << correctedPath
          }
        else # No extraction, pack the files back up and add a suffix if required
          Dir.chdir(exp.tmpDir)
          fileName = nil
          if(compressType == 'gzip')
            fileName = @fileToProcess.gsub(/\.tar\.gz$/, '')
          elsif(compressType == 'bzip2')
            fileName = @fileToProcess.gsub(/\.tar\.bz2$/, '')
          elsif(compressType == 'xz')
            fileName = @fileToProcess.gsub(/\.tar\.xz$/, '')
          elsif(compressType == 'Zip')
            fileName = @fileToProcess.gsub(/\.zip$/i, '')
          elsif(compressType == 'tar')
            fileName = @fileToProcess.gsub(/\.tar$/, '')
          end
          archive = ( @fileExt ? "#{fileName}#{@fileExt}" : fileName )
          if(compressType == 'Zip')
            cmd = "zip"
            archive << ".zip"
          else
            archive << ".tar"
            cmd = "tar -cf"
          end
          `#{cmd} #{archive} *`
          if(compressType == 'tar' or compressType == 'Zip')
            @filesToTransfer << archive
          else
            if(compressType == 'gzip')
              `gzip -c #{archive} > #{archive}.gz`
              @filesToTransfer << "#{archive}.gz"
            elsif(compressType == 'bzip2')
              `bzip2 -c #{archive} > #{archive}.bz2`
              @filesToTransfer << "#{archive}.bz2"
            elsif(compressType == 'xz')
              `xz -c #{archive} > #{archive}.gz`
              @filesToTransfer << "#{archive}.xz"
            else
              # No-op
            end
          end
          Dir.chdir(@scratchDir)
        end
        # Finally transfer the file(s) to the target
        transferFiles(exp, true)
      end
      return exp
    end

    # Compresses file back into original type
    # [+exp+] Expander object
    # [+useOrigFileAsOutputFile+] True | False: True if replacing original, false otherwise
    # [+returns+] outputFile: The re-compressed file
    def compressFile(exp, useOrigFileAsOutputFile=true)
      outputFile = nil
      compressType = exp.getFileType(@fileToProcess)
      if(useOrigFileAsOutputFile)
        outputFile = @fileToProcess.dup()
      else
        fileBaseName = "#{File.basename(exp.uncompressedFileName)}"
        if(compressType == 'gzip')
          outputFile = "#{fileBaseName}.gz"
        elsif(compressType == 'bzip2')
          outputFile = "#{fileBaseName}.bz2"
        elsif(compressType == 'xz')
          outputFile = "#{fileBaseName}.xz"
        elsif(compressType == 'Zip')
          outputFile = "#{fileBaseName}.zip"
        else
          # No-op
        end
      end
      if(compressType == 'gzip')
        `gzip -c #{exp.uncompressedFileName} > #{outputFile}`
      elsif(compressType == 'bzip2')
        `bzip2 -c #{exp.uncompressedFileName} > #{outputFile}`
      elsif(compressType == 'xz')
        `xz -c #{exp.uncompressedFileName} > #{outputFile}`
      elsif(compressType == 'Zip')
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "moving #{exp.uncompressedFileName} to #{File.dirname(outputFile)}")
        `mv #{exp.uncompressedFileName} #{File.dirname(outputFile)}`
        `zip #{outputFile} #{File.basename(exp.uncompressedFileName)}`
        exp.uncompressedFileName = File.basename(exp.uncompressedFileName)
      else
        # No-op
      end
      return outputFile
    end

    # Transfer all processed files to the target
    # [+exp+] Expander Obj
    # [+returns+] nil
    def transferFiles(exp, copyFromTmpDir=false)
      Dir.chdir(exp.tmpDir) if(copyFromTmpDir)
      rsrcPath = ""
      dbUri = nil
      subdir = nil
      if(@outputs.empty?)
        dbUri = URI.parse(@dbApiHelper.extractPureUri(@inputs[0]))
        subdir = @fileApiHelper.subdir(@inputs[0])
      else
        dbUri = URI.parse(@dbApiHelper.extractPureUri(@outputs[0]))
        subdir = @fileApiHelper.subdir(@outputs[0])
      end
      apiCaller = WrapperApiCaller.new(dbUri.host, "", @userId)
      gbKey = @dbApiHelper.extractGbKey(@inputs[0]) ? "gbKey=#{@dbApiHelper.extractGbKey(@inputs[0])}" : ""
      filteredFiles = []
      @filesToTransfer.each {|file|
        filteredFiles << file if(file !~ /__MACOSX/)
      }
      @filesToTransfer = filteredFiles
      @count = 0
      @filesToTransfer.each { |file|
        # Sleep for 5 seconds after doing 20 put calls
        if(@count != 0 and @count % 20 == 0)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "SLEEPING FOR 5 SECONDS - COUNT IS CURRENTLY #{@count}")
          sleep(5)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE SLEEPING")
        end
        fileNameToUse = copyFromTmpDir ? file : File.basename(file)
        fileURI = "http://#{dbUri.host}#{dbUri.path}/file/#{fileNameToUse.chomp('/')}"
        # Check if fileURI is a valid URI
        requiresEscaping = false
        begin
          URI.parse(fileURI)
        rescue => err
          if(err.class == URI::InvalidURIError)
            requiresEscaping = true            
          end
        end
        fileNameToUse = File.makeSafePath(fileNameToUse) if(requiresEscaping)
        if(subdir == '/') # The target is a db or top level 'Files' folder
          rsrcPath = "#{dbUri.path}/file/#{fileNameToUse.chomp("/")}/"
          rsrcPath << "data?" if(file !~ /\/$/)
        else
          rsrcPath = "#{dbUri.path}/file#{subdir.chomp('/')}/#{fileNameToUse.chomp("/")}/"
          rsrcPath << "data?" if(file !~ /\/$/)
        end
        rsrcPath << gbKey
        apiCaller.setRsrcPath(rsrcPath)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "copying #{file} to #{rsrcPath} at #{dbUri.host}")
        if(file =~ /\/$/)
          # For folders, only do a 'put' if it doesn't already exist
          apiCaller.get()
          if(!apiCaller.succeeded?)
            apiCaller.put()
            @count += 1
            if(!apiCaller.succeeded?)
              raise apiCaller.respBody.inspect  
            end
          end
        else
          # Upload file to Genboree and then remove local file
          uploadFile(dbUri.host, rsrcPath, @userId, file, {})
          `rm -f #{file}` 
          @count += 1
        end
      }
      Dir.chdir(@scratchDir) if(copyFromTmpDir)
      # Remove the original file
      `rm -f #{@fileToProcess}` if(File.exists?(@fileToProcess))
      # Remove the tmp dir
      `rm -rf #{exp.tmpDir}` if(exp.tmpDir and File.exists?(exp.tmpDir))
    end

    # Download the file to be processed
    # Raises exception if unable to download the file
    # [+returns+] nil
    def downloadFile(file)
      @fileToProcess = CGI.escape(File.basename(@fileApiHelper.extractName(file)))
      retVal = @fileApiHelper.downloadFile(file, @userId, @fileToProcess)
      if(!retVal)
        @errUserMsg = "Failed to download file: #{@fileToProcess} from server after many attempts.\nPlease try again later."
        raise @errUserMsg
      end
    end

    # Upload a given file to Genboree server
    # @param host [String] host that user wants to upload to
    # @param rsrcPath [String] resource path that user wants to upload to
    # @param userId [Fixnum] genboree user id of the user
    # @param inputFile [String] full path of the file on the client machine where data is to be pulled
    # @param templateHash [Hash<Symbol, String>] hash that contains (potential) arguments to fill in URI for API put command
    # @return [nil]
    def uploadFile(host, rsrcPath, userId, input, templateHash)
      # Call FileApiUriHelper's uploadFile method to upload current file
      retVal = @fileApiHelper.uploadFile(host, rsrcPath, userId, input, templateHash)
      # Set error messages if upload fails using @fileApiHelper's uploadFailureStr variable
      unless(retVal)
        @errUserMsg = @fileApiHelper.uploadFailureStr
        @errInternalMsg = @fileApiHelper.uploadFailureStr
        @exitCode = 38
        @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
        raise @err
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{input} uploaded successfully to server")
      end
      return
    end

    # Send success email
    # [+returns+] emailObj
    def prepSuccessEmail()
      additionalInfo = "Below is a list of all the input files and the files they generated.\nIt is possible that some files are still being processed.\nAll files should appear in your Genboree workbench shortly.\n\n"
      additionalInfo << "Total number of files transferred: #{@count}\n"
      
      @inputs.each {|input|
        fileName = @fileApiHelper.extractName(input)
        dbName = @dbApiHelper.extractName(input)
        groupName = @grpApiHelper.extractName(input)
        additionalInfo << " File: #{fileName}\n Database: #{dbName}\n Group: #{groupName}\n\n"
        additionalInfo << "The following file(s) were generated:\n"
        targetGrp = @outputs.empty? ? groupName : @grpApiHelper.extractName(@outputs[0])
        targetDb = @outputs.empty? ? dbName : @dbApiHelper.extractName(@outputs[0])
        targetFolder = @outputs.empty? ? @fileApiHelper.subdir(input) : @fileApiHelper.subdir(@outputs[0])
        additionalInfo << "Target Group: #{targetGrp}\nTarget Database: #{targetDb}\n"
        @transferredFiles[fileName].each { |file|
          fileNameToUse = ( !@multiFileArchive ? CGI.unescape(File.basename(file)) : CGI.unescape(file) )
          $stderr.puts "fileNameToUse: #{fileNameToUse}; targetFolder: #{targetFolder}"
          additionalInfo << " * #{CGI.unescape(targetFolder).chomp("/")}/#{fileNameToUse}\n"
        }
        skippedFiles = @skippedFileHash[fileName]
        if(!skippedFiles.empty? and @convToUnix)
          additionalInfo << "The following file(s) could not be converted to unix format since they are not ASCII text:\n"
          skippedFiles.each {|file|
            additionalInfo <<  "   #{CGI.unescape(File.basename(file))}\n"
          }
        end
        additionalInfo << "\n*********************************\n\n"
      }
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      if(@suppressEmail)
        return nil
      else
        return successEmailObject
      end
    end

    # Send failure/error email
    # [+returns+] emailObj
    def prepErrorEmail()
      additionalInfo = "     Error:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
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
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::PostProcessFiles)
end
