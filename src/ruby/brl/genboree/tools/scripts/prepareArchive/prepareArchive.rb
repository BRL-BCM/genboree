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
  class PrepareArchive < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used for preparing files as an archive from Genboree.",
      :authors      => [ "Aaron Baker(aaron.baker@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    MAX_ARCHIVE_SIZE = 100_000_000_000 # Just under 100GB

    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # @return nil
    def processJobConf()
      begin
        @dbOrFolderTargetUri = @outputs[0]
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        @archiveName = @settings['archiveName']
        @safeArchiveName = @archiveName.makeSafeStr
        @fullArchiveDirPath = nil
        @compressionType = @settings['compressionType']
        @preserveStructure = @settings['preserveStructure']
        @deleteOriginalFiles = @settings['deleteOriginalFiles']
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
        @failureFiles = Hash.new(0)
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # determine input type for each input and appends to the @successList of files organized within the input
    # add each file in @successList to an archive
    # @return nil
    def run()
      begin
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "List of file URLs from @inputs:\n    #{@inputs.join("\n    ")}")
        # check each input to see if it is a file, folder, file entity list, or db
        @successFiles = @fileApiHelper.expandFileContainers(@inputs, @userId)
        # download files temporarily to scratch
        @fullArchiveDirPath = "#{@scratchDir}/#{@safeArchiveName}"
        `mkdir #{@fullArchiveDirPath}`
        maxRenameCount = 10
        renamePattern = /_(\d+)$/
        extensionPattern = /(\..+)$/
        # prepare a mapping file header
        unless(@preserveStructure)
          mapFileName = "#{@fullArchiveDirPath}/map.txt"
          File.open(mapFileName, 'w'){ |mapFile|
            mapFileFields = ['new file name', 'host', 'group', 'database', 'sub-folders', 'original file name']
            mapFile.write("##{mapFileFields.join("\t")}")
          }
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Full list of file URLs to put in archive:\n    #{@successFiles.inspect}")
        @successFiles.each { |fileUri|
          fileAndFolderName = @fileApiHelper.extractName(fileUri)
          fileName = fileAndFolderName.split('/')[-1]
          uriObj = URI.parse(fileUri)
          folderArray = extractFolderStructure(fileUri)
          if(@preserveStructure)
            currentFolderString = @fullArchiveDirPath.dup           
            folderArray.each{ |childFolder|
              currentFolderString << "/#{childFolder.makeSafeStr}"
              unless(File.directory?(currentFolderString))
                Dir.mkdir(currentFolderString)
              end
            }
            fullFileName = "#{currentFolderString}/#{fileName}"
          else
            # provide a mapping file if file name conflicts occur
            fullFileName = "#{@fullArchiveDirPath}/#{fileName}"
            renameCount = 1
            origNameConflict = File.file?(fullFileName)
            nameConflict = origNameConflict
            renamedFile = fileName
            while(nameConflict and renameCount <= maxRenameCount)
              # prepare email content for name conflict
              @failureFiles[File.basename(fullFileName)] += 1

              # remove the file extension if it exists
              extensionMatch = renamedFile.match(extensionPattern)
              unless(extensionMatch.nil?)
                fileExtension = extensionMatch[1]
                renamedFile = renamedFile.gsub(extensionPattern, '')
              else
                fileExtension = nil
              end

              # create a new file name according to rename pattern, adding back extension if it exists
              renameMatch = renamedFile.match(renamePattern)
              unless(renameMatch.nil?)
                fileNum = renameMatch[1].to_i
              else
                fileNum = 0
              end
              fileNum += 1
              fileWithoutRename = renamedFile.gsub(renamePattern, '')
              if(fileExtension.nil?)
                renamedFile = "#{fileWithoutRename}_#{fileNum}"
              else
                renamedFile = "#{fileWithoutRename}_#{fileNum}#{fileExtension}"
              end
              fullFileRenamed = "#{@fullArchiveDirPath}/#{renamedFile}"
              nameConflict = File.file?(fullFileRenamed)
              renameCount += 1
            end
            if(origNameConflict)
              # then make the rename
              fullFileName = fullFileRenamed
            end

            # regardless, record file origin in the mapping file
            host = uriObj.host
            groupName = @grpApiHelper.extractName(fileUri)
            dbName = @dbApiHelper.extractName(fileUri)
            File.open(mapFileName, 'a'){ |mapFile|
              mapArray = [renamedFile, host, groupName, dbName]
              mapArray.push(folderArray.join'/')
              mapArray.push(fileName)
              mapFile.write("\n#{mapArray.join("\t")}")
            }

          end
          retVal = @fileApiHelper.downloadFile(fileUri, @userId, fullFileName)
          # If we are unable to download our file successfully, we will set an error message for the user.
          unless(retVal)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Failed to download file: #{fileUri} from server.")
            @errUserMsg = "Failed to download file: #{fileUri} from server"
            raise @errUserMsg
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "File #{fileUri} downloaded successfully to #{fullFileName}")
          end
        }
        # Build command to compress those files
        archiveNameWithExt = nil
        if(@compressionType == 'tar.gz')
          archiveNameWithExt = "#{@safeArchiveName}.tar.gz"
          cmd = "tar -cf - -C #{@scratchDir} #{File.basename(@fullArchiveDirPath)} | gzip -9 > #{@scratchDir}/#{archiveNameWithExt}"
        elsif(@compressionType == 'tar.bz2')
          archiveNameWithExt = "#{@safeArchiveName}.tar.bz2"
          cmd = "tar -cjf #{@scratchDir}/#{archiveNameWithExt} -C #{@scratchDir} #{File.basename(@fullArchiveDirPath)}"
        elsif(@compressionType == 'zip')
          archiveNameWithExt = "#{@safeArchiveName}.zip"
          cmd = "cd #{@scratchDir} ; zip -9 -r #{archiveNameWithExt} #{File.basename(@fullArchiveDirPath)}"
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Compression type: #{@compressionType.inspect} not recognized, using .tar.gz instead")
          archiveNameWithExt = "#{@safeArchiveName}.tar.gz"
          cmd = "tar -cf - -C #{@scratchDir} #{File.basename(@fullArchiveDirPath)} | gzip -9 > #{@scratchDir}/#{archiveNameWithExt}"
        end

        # Run actual archive cmd
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Archive cmd:\n\n#{cmd.inspect}\n\n")
        cmpOut = `#{cmd}`
        exitStatusObj = $?
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Archive exit status obj:\n\n#{exitStatusObj.inspect}\n\n")

        # Preparing archive work ok?
        if(exitStatusObj.success?)
          archiveSize = File.size("#{@scratchDir}/#{archiveNameWithExt}")
          # Size is ok?
          if(archiveSize <= MAX_ARCHIVE_SIZE)
            # upload the archive to database or a file folder within it
            filesRegexp = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/db/[^/]+/files/([^\?]+)}
            if(@dbOrFolderTargetUri =~ filesRegexp)
              # put a file in the given subdirectory
              dirPath = "file/#{$1}"
            else
              # put the file at the root of the database
              dirPath = "file"
            end
            dbTargetUri = @dbApiHelper.extractPureUri(@dbOrFolderTargetUri)
            dbTargetUriObj = URI.parse(dbTargetUri)
            # Upload file to target area
            uploadFile(dbTargetUriObj.host, "#{dbTargetUriObj.path.chomp('?')}/#{dirPath}/#{CGI.escape(archiveNameWithExt)}/data?", @userId, archiveNameWithExt, {})
          else # archive too big.
            @errUserMsg = "Your archive ends up being #{('%.2f' % (archiveSize / (1024 * 1024 * 1024.0))).commify}GB. Which is too big for a single file; the upload to Genboree would be rejected for a single file this size. Please place significantly fewer--and/or smaller--files into the archive; your significant reduction in the number/size of input files needs to produce a final archive that is no more than #{MAX_ARCHIVE_SIZE.commify} bytes in size."
            @exitCode = 36
            # Arrange to clean up too big archive
            @removeFiles = [ "#{@scratchDir}/#{archiveNameWithExt}" ]
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Created archive that is too big and will likely be rejected by Genboree. Archive was #{archiveSize.commify.inspect} bytes. Maximum is #{MAX_ARCHIVE_SIZE.commify.inspect}. Arranged error email to user and cleaning up of too-big archive.")
          end
        else # create archive failed
          @errUserMsg = "Underlying archive creation command failed."
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to create archive file #{@scratchDir}/#{archiveNameWithExt} of type #{@compressionType.inspect}.\n\n  Archive Cmd: #{cmd}\n  Exit status obj: #{exitStatusObj.inspect}")
          @exitCode = 35
        end

        # Regardless: Clean up: remove the uncompressed folder now that we have the archive or failed.
        `rm -rf #{@fullArchiveDirPath}`

      rescue => err
        @err = err
        @errUserMsg = err.message if(@errUserMsg.nil? or @errUserMsg.empty?)
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30 if(@exitCode == 0)
      end
      return @exitCode
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
    # @return emailObj
    def prepSuccessEmail()
      # note success files
      additionalInfo = "The following files have been successfully added to an archive:\n"
      @successFiles.each { |file|
        additionalInfo << " * #{File.basename(file).chomp('?')}"
        additionalInfo << "\n"
      }
      # and failure files (those with duplicate names)
      unless(@failureFiles.nil? or @failureFiles.empty?)
        additionalInfo << "The following files had name conflicts with other files in your selection:\n"
        @failureFiles.each_key{ |file|
          additionalInfo << " * #{file}\n"
        }
        additionalInfo << "and they have been renamed according to the map.txt file in your archive. See the tool help for more information.\n"
      end
      # Note if we deleted original input files (because user selected "Delete Original Files After Archiving?" option)
      if(@deleteOriginalFiles)
        unless(@errorWhileDeleting)
          additionalInfo << "\nIn addition, your original input files have been deleted\nbecause you picked the \"Delete Original Files After Archiving?\" option.\n"
        else
          additionalInfo << "\nHowever, we were unable to delete\nat least some of your original files.\nPlease contact a Genboree administrator to learn more.\n"
        end
      end
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return successEmailObject
    end

    # Send failure/error email
    # @return emailObj
    def prepErrorEmail()
      additionalInfo = @errUserMsg
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return errorEmailObject
    end

    # Represent folder structure as an ordered array where the first
    #   element is the root folder, the second element is a folder
    #   defined within it, and so on
    # @param uri [String] the resource uri
    # @return [Array] the folder structure array mentioned in the method
    #   description
    def extractFolderStructure(uri)
      retVal = []
      grpName = @grpApiHelper.extractName(uri)
      dbName = @dbApiHelper.extractName(uri)
      fileName = @fileApiHelper.extractName(uri)
      foldersAndFile = fileName.split('/')
      folders = []
      if foldersAndFile.length > 1
        folders = foldersAndFile[0..-2]
      end
      retVal << grpName
      retVal << dbName
      folders.each{ |folder|
        retVal << folder
      }
      return retVal
    end # end extractFolderStructure method
  end # end class
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::PrepareArchive)
end
