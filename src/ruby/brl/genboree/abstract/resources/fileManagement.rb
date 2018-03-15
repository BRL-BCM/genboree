require 'time'
require 'json'
require 'tempfile'
require 'fileutils'
require 'brl/activeSupport/time'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'

module BRL ; module Genboree ; module Abstract ; module Resources
  # This module can be mixed into a class that already mixes in the DataIndexFile module
  # as it uses this module to maintain metadata about the files
  # If it is used, DataIndexFile must be mixed in as it refers to several methods defined there, such as replaceDataFile
  module FileManagement

    # Global constants

    # Regexp for finding disallowed characters for file names, \ / : * ? " < > | ' ` ~ { } $ ( ) ; & or files stating with .
    FILENAME_BANNED_CHARS_REGEXP = %r@(?:[\\/:\*\?"<>\|'`~\{\}\$\(\);&])|(?:^\.)@
    # Regexp for finding disallowed characters for sub directory names, \ : * ? " < > | ' ` ~ { } $ ( ) ; & or files stating with . (dirs named '..' are caught too)
    SUBDIR_BANNED_CHARS_REGEXP = %r@(?:[\:\*\?"<>\|'`~\{\}\$\(\);&])|(?:^\.)@
    # List of editable fields within a file index record
    EDITABLE_INDEX_FIELDS = [ 'autoArchive', 'archived', 'date', 'description', 'fileName', 'label', 'hide', 'attributes', 'filename', 'name' ]
    EDITABLE_INDEX_FIELDS_FOR_FILES = [ 'autoArchive', 'description', 'label', 'hide', 'attributes', 'name' ]
    # The auto-archive threshold (2 weeks in seconds)
    AUTOARCHIVE_THRESHOLD = 2 * 7 * 24 * 60 * 60
    # The minimum number of files in the current files list
    MIN_CURRENT_FILES = 5
    # Read buffer size
    READ_BUFFER_SIZE = 4 * 1024 * 1024
    # Maximum size for moving files in-place (versus running localFileProcessor job)
    MAX_LOCAL_SIZE = 8000000

    # Overridden constants

    # The following constants must be defined in the mixees in class

    # The name of the file that has the data contents or the index of contents
    #   DATA_FILE = 'genb^^additionalFiles/projectFiles.json'
    # The auto-archive threshold (2 weeks in seconds)
    #   AUTOARCHIVE_THRESHOLD = 2 * 7 * 24 * 60 * 60
    # The minimum number of files in the current files list
    #   MIN_CURRENT_FILES = 5


    # Each class that uses this module as a mixin should have the following instance vars
    # Array of the non-archived files [index records]
    #   attr_accessor :currentFiles
    # Array of the archived files [index records]
    #   attr_accessor :archivedFiles
    # Directory where all the files of this project live
    #   attr_accessor :filesDir
    # Name of the index file (no path)
    #   attr_accessor :indexFileName
    # Hash of base file names that should not be exposed as project files
    #   attr_accessor :fileKillList


    # Is this component empty of contents?
    # [+returns+] true if yes, false if no
    def empty?(showHidden=false)
      return (FileManagement.isFileListEmpty?(@currentFiles, showHidden) and FileManagement.isFileListEmpty?(@archivedFiles, showHidden))
    end

    # Replaces this component's data file contents with the +String+ data provided.
    # It is assumed that the content is correctly formatted, etc (no validation is done).
    #
    # [+content+]   The +String+ containing the new contents for this component's data file
    # [+reprocess+] [optional; default=true] If true, then content is coming externally or from a
    #               manipulation of the file records in the index and thus should undergo re-categorization
    #               and sorting and such; if false then already processed (e.g. calling from the processFileIndex()
    #               method itself for example where we *definitely* don't want reprocessing--else inf loop)
    # [+returns+] true or some kind of IO related Exception is raised
    def processAndReplaceDataFile(content, reprocess=true)
      retVal = replaceDataFile(content)
      # Need to reparse the new data in order to recategorize files, etc.
      processFileIndex() if(reprocess)
      return retVal
    end

    def buildEscapedPath(path, fileNameInRec)
      return "#{path}/#{fileNameInRec.split('/').map{|nn| CGI.escape(nn) }.join('/')}"
    end

    # Go through the file index, categorize the records by archive status,
    # look for additional files not in the index, sort the file records by their
    # dates, and ensure current file list has a minimum number of records.
    # - will update @maxEditableItemId seen as processes records
    #
    # 'uploadPending' flag was added to identify files that may be in the process of uploading
    # It's ok to have a record in the index without the file on disk if uploadPending=true
    # uploadPending should be removed from the index if the file exists on disk.
    #
    # [+returns+] true
    def processFileIndex()
      t1 = Time.now
      @maxEditableItemId = -1
      # Normalize the file index data structure
      normalizeFileIndex()
      # Are any of the file NOT auto-archived (i.e. user is manually deciding archive status)
      @manualArchiving = @data.detect { |rec| rec['autoArchive'] == false }
      # Cleanup Remove file records whose file doesn't actually exist!
      unless(@data.is_a?(String))
        @data.delete_if { |fileRec|
          actualFilePath = buildEscapedPath(@filesDir.path, fileRec['fileName'])
          # Delete the record from the Index if the file doesn't exist and it's not a pending upload
          # escape subdirs and filename because that's how they're stored on disk
          !File.exist?(actualFilePath) && fileRec['uploadPending'] != true # and uploadPending is not set
        }
      end
      # Divide existing index records amongst current and archived; keep track of fileNames seen.
      indexedFiles = categorizeFiles()
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "Time for init: #{Time.now - t1}")
      t1 = Time.now
      # Give appropriate editableItemId to any file records that are missing them
      (@currentFiles + @archivedFiles).each { |fileRec|
        @maxEditableItemId = fileRec['editableItemId'] if(fileRec['editableItemId'].to_i > @maxEditableItemId)
      }
      (@currentFiles + @archivedFiles).each { |fileRec|
        actualFilePath = buildEscapedPath(@filesDir.path, fileRec['fileName'])
        if(fileRec['editableItemId'].to_i <= 0) # then either nil or inappropriate id
          @maxEditableItemId += 1
          fileRec['editableItemId'] = @maxEditableItemId
        end
        if(File.exist?(actualFilePath) && fileRec['uploadPending'] == true )
          # Unset uploadPending
          fileRec.delete('uploadPending')
        end
      }
      #$stderr.debugPuts(__FILE__, __method__, "TIME", "Time for doing editableItemId: #{Time.now - t1}")
      # Go through rest of files in dir and index any that aren't indexed.
      # Look in subdirs
      t1 = Time.now
      subDirFiles = File.join("#{@filesDir.path}/**/*")
      Dir.glob(subDirFiles).each { |fullFilePath|
        fileName = File.basename(fullFilePath)
        unless(ignoreFile?(fileName))
          # If file not in JSON, add it. Archive if File.mtime > now + two weeks.
          unescFileName = CGI.unescape(fileName)
          unless(indexedFiles.key?(unescFileName))
            # File not indexed; create an index entry for it.
            # Assign an editableItemId
            @maxEditableItemId += 1
            newFileRec = makeFileRec(unescFileName, fullFilePath, @maxEditableItemId)
            # add to relevant array
            if(newFileRec['archived'] == true)
              @archivedFiles << newFileRec
            else
              @currentFiles << newFileRec
            end
          end
        end
      }
      #  Sort current and archived by uploadDate (most recent first)
      sortIndexRecords()
      #  Try to ensure at least 5 files in current files list
      #  - if fewer than 5 in current list, move up to 5 most recent archived ones from archived list
      #    to end of current list
      ensureMinNumCurrentFiles() unless(@manualArchiving)
      # Write out updated JSON file (merge of current and archived lists)
      @data = @currentFiles + @archivedFiles
      @dataStr = JSON.pretty_generate(@data)
      replaceStatus = replaceDataFile(@dataStr)
      return true
    end

    # Call the module method
    def makeFileRec(fileName, fullFilePath, maxEditableItemId=@maxEditableItemId)
      return BRL::Genboree::Abstract::Resources::FileManagement.makeFileRec(fileName, fullFilePath, maxEditableItemId)
    end

    # Module method (not class method, different)
    def FileManagement::makeFileRec(fileName, fullFilePath, maxEditableItemId=@maxEditableItemId)
      newFileRec = {}
      newFileRec['editableItemId'] = maxEditableItemId
      # File label will be same as file name, since we have no other info.
      newFileRec['fileName'] = newFileRec['label'] = fileName
      # File description is blank by default.
      newFileRec['description'] = ''
      # Set the upload time to the mtime of the file.
      # - because large files can take a long time to be "moved" into place,
      #   it's possible we can't get an mtime from this reliably (especially if about to replace file and hit
      #   file as original nuked but before new data written...we have seen this)
      # - therefore, try to get mtime for a few secs, and if fails use Time.now()
      mtime = nil
      5.times { |ii|
        begin
          mtime = File.mtime(fullFilePath)
          break
        rescue => err
          # Expected under certain cases involving large files mv'd in background
          sleep(1)
        end
      }
      mtime = Time.now() if(mtime.nil?)
      #newFileRec['date'] = mtime.rfc2822
      newFileRec['date'] = mtime
      # Default is not hidden
      newFileRec['hide'] = false
      # Use that time to determine if file should be autoArchived or is current.
      newFileRec['autoArchive'] = true
      newFileRec['attributes'] = {}
      newFileRec['archived'] = FileManagement.adjustArchiveStateByTime(mtime, newFileRec)
      return newFileRec
    end

    # Finds the file index record using the label.
    # - will update @maxEditableItemId seen as searches
    #
    # [+fileLabel+] Label to use to look up the file index record
    # [+returns+]   The file index record matching the label (a Hash) or nil if not found
    def findFileRecByLabel(fileLabel)
      @maxEditableItemId = -1
      retVal = nil
      if(@data)
        @data.each { |fileRec|
          @maxEditableItemId = fileRec['editableItemId'].to_i if(fileRec['editableItemId'] and fileRec['editableItemId'].to_i > @maxEditableItemId)
          if(fileRec['label'] == fileLabel)
            retVal = fileRec
            break
          end
        }
      end
      return retVal
    end

    # Finds the file index record using the file name.
    # - will update @maxEditableItemId seen as searches
    #
    # [+fileName+]  File name to use to look up the file index record
    # [+returns+]   The file index record matching the label (a Hash) or nil if not found
    def findFileRecByFileName(fileName)
      @maxEditableItemId = -1
      retVal = nil
      if(@data)
        @data.each { |fileRec|
          @maxEditableItemId = fileRec['editableItemId'].to_i if(fileRec['editableItemId'] and fileRec['editableItemId'].to_i > @maxEditableItemId)
          if(fileRec['fileName'] == fileName)
            retVal = fileRec
            break
          end
        }
      end
      return retVal
    end

    # This method modifies the info/settings associated with a file.
    # - This can also be used to rename a file or provide the file with a new (but unique) label.
    # The internal representations of the file index will also be updated fully.
    #
    # [+fileLabel+] The unique file label identifying the file to update info for.
    # [+infoHash+] A +Hash+ keyed by +Strings+ indicating the file field(s) to change
    #              to the value mapped to the +String+. The following fields are supported:
    #              - 'autoArchive' -> true or false
    #              - 'archived' -> true or false
    #              - 'date' -> Time object
    #              - 'description' -> String
    #              - 'fileName' -> new filename (dir will be the same)
    #              - 'fileLabel' -> new label (must be unique for this index)
    # [+returns+] :OK or some failure symbol. Not an HTTP response code though.
    def updateFileInfo(fileLabel, infoHash)
      retVal = :OK
      # Check that file of interest exists in index and retrieve its record
      fileRec = findFileRecByLabel(fileLabel)
      # Check for fields to be modified and update them
      EDITABLE_INDEX_FIELDS.each { |infoField|
        if(!infoHash[infoField].nil?)
          case infoField
            when 'autoArchive', 'archived', 'hide'
              fileRec[infoField] = (infoHash[infoField]) ? true : false
            when 'description'
              fileRec[infoField] = infoHash[infoField].to_s
            when 'date'
              fileRec[infoField] = case infoHash[infoField].class
              when Time
                infoHash[infoField].rfc2822
              else
                infoHash[infoField]
              end
            when 'fileName' # rename the file (mv's file and updates the record)
              retVal = renameFile(fileRec, infoHash[infoField])
            when 'label' # relabel the file (relabels by extracting old record, change label, and readd record...but only if new label is not in use!)
              retVal = relabelFile(fileLabel, infoHash[infoField])
            when 'attributes'
              fileRec[infoField] = infoHash[infoField]
          end
        end
      }

      # Since we may have changed all sorts of things such as dates and whatnot all at once,
      # we really need to regenerate the internal representations from scratch.
      categorizeFiles()
      ensureMinNumCurrentFiles()
      sortIndexRecords()
      @data = @currentFiles + @archivedFiles
      @dataStr = JSON.pretty_generate(@data)
      # Write the index file back out and unlock/close it
      retVal = :ERROR if(!processAndReplaceDataFile(@dataStr))
      return retVal
    end

    # This method appends new attributes or updates existing attributes
    #
    # [+newAttrs+]  Hash, should have format {'attributes' => {'key' => 'value'}}
    def updateFileAttribute(fileLabel, newAttrs)
      retVal = :OK
      # Check that file of interest exists in index and retrieve its record
      fileRec = findFileRecByLabel(fileLabel)
      newAttrs['attributes'].each_key { |attrName|
        # Add new attributes to fileRec which is reference to the appropriate record in @data
        fileRec['attributes'][attrName] = newAttrs['attributes'][attrName]
      }
      # Write the index file back out and unlock/close it
      retVal = :ERROR if(!processAndReplaceDataFile(JSON.pretty_generate(@data), false))
      return retVal
    end

    # This method is used to change the name of an attribute
    #
    # [+attrName+]  String
    # [+newName+]   String
    def renameFileAttribute(fileLabel, attrName, newName)
      retVal = :OK
      # Check that file of interest exists in index and retrieve its record
      fileRec = findFileRecByLabel(fileLabel)
      # remove the old name and create the new
      attrVal = fileRec['attributes'][attrName]
      fileRec['attributes'][newName] = attrVal
      fileRec['attributes'].delete(attrName)
      # Write the index file back out and unlock/close it
      retVal = :ERROR if(!processAndReplaceDataFile(JSON.pretty_generate(@data), false))
      return retVal
    end

    # This method replaces a existing attribute with a new key value pair, can be used to rename
    #
    # [+attrName+]  String
    # [+newAttrs+]  Hash, should have format {'key' => 'value'}
    def replaceFileAttribute(fileLabel, attrName, newAttr)
      retVal = :OK
      # Check that file of interest exists in index and retrieve its record
      fileRec = findFileRecByLabel(fileLabel)
      # remove the old name and create the new
      fileRec['attributes'].delete(attrName)
      fileRec['attributes'].merge!(newAttr)
      # Write the index file back out and unlock/close it
      retVal = :ERROR if(!processAndReplaceDataFile(JSON.pretty_generate(@data), false))
      return retVal
    end

    # This method is used to delete an attribute by name
    #
    # [+attrName+]  String
    def deleteFileAttribute(fileLabel, attrName)
      retVal = :OK
      # Check that file of interest exists in index and retrieve its record
      fileRec = findFileRecByLabel(fileLabel)
      # remove the attribute
      fileRec['attributes'].delete(attrName)
      # Write the index file back out and unlock/close it
      retVal = :ERROR if(!processAndReplaceDataFile(JSON.pretty_generate(@data), false))
      return retVal
    end

    # This method adds a file to the index.  By default it won't overwrite, but you can set allowOverwrite to allow it
    #
    # [+fileName+]  The unique file name identifying the file.
    # [+content+]   The contents of the file.
    # [+allowOverwrite+]
    # [+extract+] extract the compressed file [Default: false]
    # [+returns+]   :OK or some failure symbol. Not an HTTP response code though.
    def writeFile(fileName, content, allowOverwrite=false, extract=false, processIndexFile=false, fileUpdateArray=[])
      retVal = :Accepted
      # Assert that the file doesn't already exist
      if(allowOverwrite or !(findFileRecByLabel(fileName) or findFileRecByFileName(fileName)))
        writeFileOnDisk(fileName, content, extract, fileUpdateArray) # this will record any in-progress newly written data
        # Write index file back out and unlock/close it
        # - we need to have a lock on the index file to update it
        # - but may have entered this with explicit release of lock (while writing large data say)
        # - so keep track of state; ensure lock, then restore to original state
        # Do processing of index file
        processAndReplaceDataFile(@dataStr) if(processIndexFile)
      else
        retVal = :ALREADY_EXISTS
      end
      return retVal
    end

    # This method 'deletes' a particular file. For future ability to undelete,
    # the 'delete' will be done by backing up the file and compressing it.
    #
    # This method will update the file index, both as represented within this object and
    # in the index file on disk, and "delete" the actual file.
    #
    # [+fileLabel+] The unique file label identifying the file to delete.
    # [+returns+] :OK or some failure symbol. Not an HTTP response code though.
    def deleteFile(fileLabel)
      retVal = :OK
      # Check that file of interest exists in index and retrieve its record
      fileToDeleteRec = findFileRecByLabel(fileLabel)
      # 'Delete' file by moving to a backup dir and then compressing it
      # - may take a while to delete huge file
      # - release lock on index file while doing this
      # - then restore when done (if required)
      retVal = :Error if(!deleteFileOnDisk(fileToDeleteRec['fileName']))
      # Forcibly remove file from index
      removeFileRecByLabel(fileLabel)
      # Do processing of index file
      processAndReplaceDataFile(@dataStr)
      return retVal
    end

    # Renames the file referred to in the fileRec object to have the new
    # file name provided. The file will not change directories, only its name
    # will change. This method also updates the 'fileName' value for the given record
    # if the operation succeeds.
    #
    # [+fileRec+]    The file index record for the file to be renamed. The original
    #                 name will be retrieved from here and this object will be
    #                 updated with the new name (if successful)
    # [+newFileName+] The new name for the file.
    # [+returns+]     :OK or :FATAL if an error occurred. Not an HTTP response code though.
    def renameFile(fileRec, newFileName, useIndexFile=false)
      retVal = nil
      origName = fileRec['fileName'] || fileRec['name']
      origFullPath = origName.split('/').map { |xx| CGI.escape(xx) }.join('/')
      origFullPath = "#{@filesDir.path}/#{origFullPath}"
#      newName = File.basename(newFileName) Removed because subdirs are allowed
      newFullPath = newFileName.split('/').map { |xx| CGI.escape(xx) }.join('/')
      newFullPath = "#{@filesDir.path}/#{newFullPath}"
      begin
        ##### HAVE TO MAKE SURE THE FILE DOESN'T ALREADY EXIST!
        fileExists = nil
        fileExists = File.exists?(newFullPath)
        if(fileExists)
          retVal = :ALREADY_EXISTS
        else
          File.rename(origFullPath, newFullPath)
          fileRec['fileName'] = newFileName
          # If the label is the same as the file name, change the label too.
          fileRec['label'] = newFileName if(fileRec['label'] == origName)
          retVal = :OK
        end
      rescue => err
        $stderr.puts "-"*50
        $stderr.puts  "ERROR: FileManagement#renameFile() => problem renaming file.\n" +
                      "- Exception: #{err.message}\n" +
                      err.backtrace.join("\n")
        $stderr.puts "-"*50
        retVal = :FATAL
      end
      return retVal
    end

    # Relabels the file labeled +oldFileLabel+ to have the new
    # file label provided. The label must be unique in the index
    # Also updates the 'fileLabel' value in +projFileRec+.
    #
    # [+oldFileLebel+]  The old label for the file.
    # [+newFileLebel+]  The new label for the file.
    # [+returns+]       :OK or some failure symbol. Not an HTTP response code though.
    #                   (:DOESNT_EXIST means there is no file with the provided label, :ALREADY_EXISTS means
    #                   that the new label is already in use.)
    def relabelFile(oldFileLabel, newFileLabel)
      retVal = nil
      # Get index record corresponding to oldFileLabel
      fileRec = findFileRecByLabel(oldFileLabel)
      if(fileRec.nil?)
        retVal = :DOESNT_EXIST
      else # got the record
        # Need to assert that newFileLabel is not in use
        if(findFileRecByLabel(newFileLabel).nil?)
          # Remove the record from the index records (updates current and archived lists too)
          removeFileRecByLabel(oldFileLabel, false)
          # Update the label for the record
          fileRec['label'] = newFileLabel
          # Put updated record back in
          @data << fileRec
          # Update @currentFiles and @archivedFiles so the replaced file
          # in in the right place. Since only label changed, the file will end up back in the correct list.
          categorizeFiles()
          # But it will likely be at the end of that list, so resort
          sortIndexRecords()
          # Recreate @data using new lists
          @data = @currentFiles + @archivedFiles
          @dataStr = JSON.pretty_generate(@data)
          retVal = :OK
        else # newFileLabel in use!
          retVal = :ALREADY_EXISTS
        end
      end
      return retVal
    end

    #--------------------------------------------------------------------------
    # HELPER Instance Methods
    #--------------------------------------------------------------------------
    def normalizeFileIndex()
      # Ensure false and true are literal false & true
      boolFields = [ 'autoArchive', 'hide', 'archived' ]
      @data.each { |rec|
        boolFields.each { |field|
          if(rec[field].is_a?(String)) # else assume already true (TrueClass) or false (FalseClass)
            rec[field].strip!
            if(rec[field] =~ /^(?:true|yes)$/i)
              rec[field] = true
            else
              rec[field] = false
            end
          end
        }
      }
      return @data
    end

    # Assign each file index record to either the @currentFiles list
    # or the @archivedFiles list according to its archive status
    # - hidden files are always put into the archive list
    # - calling methods decide what to do with hidden files (generally: don't display in most UI)
    # [+returns+] A Hash of fileNames seen during categorization
    def categorizeFiles()
      indexedFiles = {}
      @currentFiles = []
      @archivedFiles = []
      @maxEditableItemId = 0
      @data.each { |fileRec|
        # If somehow the index file itself has been indexed, then skip it
        # Also skip the "deleted" files (which are actually just renamed and compressed)
        unless(ignoreFile?(fileRec['fileName']))
          # Get the editableItemId first (if present)
          recId = fileRec['editableItemId'].to_i
          @maxEditableItemId = recId if(recId > @maxEditableItemId)
          # Add to the list of seen files
          indexedFiles[fileRec['fileName']] = true
          # Convert date property to a Ruby time object (gets read/written as rfc2822 string, but internally as Time obj for speed)
          unless(fileRec['date'].is_a?(Time))
            if(fileRec['date'].is_a?(String))
              if(fileRec['date'] =~ /json_class.+:.+Time/)
                # NOTE: Thus the record was written using proprietary Ruby->JSON object serialization features
                #   of the JSON gem. It is an object with the Ruby class and particular (class specific)
                #   fields that can recreate the object. This required importing the json/add/core library and
                #   messes with many core Ruby classes--BAD, REMOVED. We no longer use that json/add/core library
                #   but will now deal with the record manually.
                # OLD (requires json/add/core, bad): fileRec['date'] = JSON(fileRec['date'])
                timeHash = JSON.parse(fileRec['date']) # JSON.parse never employs the json/add/core even if loaded.
                # Convert the value into a Time object like original json/add/core was doing
                fileRec['date'] = processJsonTime(timeHash)
              else # Actual timestamp string? if fails, failback to trying JSON...
                begin
                  fileRec['date'] = Time.parse(fileRec['date'])
                rescue => err
                  timeHash = JSON.parse(fileRec['date']) # JSON.parse never employs the json/add/core even if loaded.
                  fileRec['date'] = processJsonTime(timeHash)
                end
              end
            elsif(fileRec['date'].is_a?(Hash)) # assume JSON special time hash
              # See NOTE above. Note using json/add/core anymore. This kind of proprietary time hash is not to be used
              # OLD (requires json/add/core, bad): fileRec['date'] = JSON(fileRec['date'].to_json)
              fileRec['date'] = processJsonTime(fileRec['date'])
            end
          end

          # Ensure settings
          fileRec['archived'] = false unless(fileRec.key?('archived'))
          fileRec['autoArchive'] = true unless(fileRec.key?('autoArchive'))
          # If archived, then goes in archived list. Hidden files always achieved
          if((fileRec['archived'] == true) or FileManagement.isHidden?(fileRec))
            @archivedFiles << fileRec
          elsif(fileRec['autoArchive'] == true) # archived is false, but if autoArchive on then determine if should be autoArchived
            # Is it older than two weeks?
            autoArchived = FileManagement.adjustArchiveStateByTime(fileRec['date'], fileRec)
            # Auto archive into the correct list of files
            if(autoArchived)
              @archivedFiles << fileRec
            else
              @currentFiles << fileRec
            end
          else # not archived, not autoArchived, so current
            @currentFiles << fileRec
          end
        end
      }
      return indexedFiles
    end

    def processJsonTime(timeHash)
      secs = ( timeHash['s'] or 0 )
      usecs = ( timeHash['n'] / 1000.0 or 0.0 )
      # Convert the value into a Time object like original json/add/core was doing
      return Time.at(secs, usecs)
    end

    # Sort the current and archived index recodes by their date fields (most recent first).
    # [+returns+] true
    def sortIndexRecords()
      #  Sort current and archived by uploadDate (most recent first)
      @currentFiles.sort! { |aa, bb|
        retVal = bb['date'] <=> aa['date']
        if(retVal == 0)
          retVal = (aa['label'].downcase <=> bb['label'].downcase)
        end
        retVal
      }
      @archivedFiles.sort! { |aa, bb|
        retVal = bb['date'] <=> aa['date']
        if(retVal == 0)
          retVal = (aa['label'].downcase <=> bb['label'].downcase)
        end
        retVal
      }
      return true
    end

    # Ensure at least a minimum number of files in current files list.
    # - if fewer than minimum in current list, move up to minimum most recent archived ones from archived list
    #   to end of current list
    # [+returns+] true
    def ensureMinNumCurrentFiles()
      numCurrIsShort = MIN_CURRENT_FILES - @currentFiles.size
      while(numCurrIsShort > 0 and !@archivedFiles.empty?)
        @currentFiles << @archivedFiles.shift
        numCurrIsShort = MIN_CURRENT_FILES - @currentFiles.size
      end
      return true
    end

    # Removes a file index record by label and updates the internal representations
    # of the index (@data, @dataStr, @currentFiles, @archivedFiles).
    # Note that this does NOT remove the file itself and should be used
    # in conjunction with other procedures.
    #
    # [+fileLabel+] Label of the file index record to remove.
    # [+updateInternals+] [optional; default=true] If true, the internal representations of the
    #                     file index will be updated. If false, either it's not necessary or
    #                     will be done at a more appropriate time. For performance to avoid
    #                     unnecessary categorizations, resortings, etc.    #
    # [+returns+]   The updated file index (Array of Hashes)
    def removeFileRecByLabel(fileLabel, updateInternals=true)
      retVal = nil
      if(@data and !self.empty?)
        @data.delete_if { |fileRec|
          fileRec['label'] == fileLabel
        }
        if(updateInternals)
          # Update @currentFiles and @archivedFiles
          categorizeFiles()
          # Ensure the current list still has the minimum number of files
          ensureMinNumCurrentFiles()
          # Sort the current and archived lists
          sortIndexRecords()
          # Recreate @data using new lists
          @data = @currentFiles + @archivedFiles
          @dataStr = JSON.pretty_generate(@data)
        end
      end
      return @data
    end

    # Removes a file from the disk (well, compresses and renames it),
    # leaving the door open for an undelete. Note that this does NOT update
    # the file index or the representations of that index in this object and should be
    # used only in conjunction with other procedures.
    #
    # [+fileName+]  The name of the file to delete...presumed to exist within
    #               the @filesDir along with the rest of the files.
    # [+returns+]   true if the 'removal' succeed, else false.
    def deleteFileOnDisk(fileName)
      retVal = true
      fullFilePath = fileName.split('/').map { |xx| CGI.escape(xx) }.join('/')
      fullFilePath = "#{@filesDir.path}/#{fullFilePath}"
      # If the zip file already exists, it will be overwritten with -f
      # Could append a timestamp to the zip file name to provide better archiving
      if(File.exists?(fullFilePath))
        # ARJ: Doing "&" background jobs is not a robust solution, but it will return IMMEDIATELY
        # and run while the parent process (thin instance) is alive.
        # ARJ: PROBLEM?? If run from Apache, apache may clean up the worker, thinking it has handled the request and
        # has too many excess workers????? This would affect Project component delete & UNDO.
        #
        t1 = Time.now
        `mv #{fullFilePath} #{fullFilePath}.GENB_DELETED ; chmod 660 #{fullFilePath}.GENB_DELETED `
        mvOk = $?.exitstatus
        if(mvOk == 0)
          escGzCmd = CGI.escape("gzip -f -9 #{fullFilePath}.GENB_DELETED ; chmod 660 #{fullFilePath}.GENB_DELETED.gz ")
          `genbTaskWrapper.rb --cmd=#{escGzCmd} -o /dev/null -e /dev/null`
        else
          retVal = false
        end
        # ARJ: Cannot test gzip success now that in background
        # ARJ: Lost any way of telling if file is deleted ok or not :()
        #retVal = $?.success?
        #
        # Correct solution to "delete":
        # - make GENB_DELETED/ sub dir if not exist
        # - MOVE (mv) file to that special sub dir
        # - fast and safe and check return code, etc (not in background!)
        # - UNdelete would move the file back from GENB_DELETED/ sub dir if present.
        # - works for API and Projects GUI
      end
      return retVal
    end

    # Writes the file to disk in the directory. Assumes @filesDir is available VIA THE INCLUDING CLASS!
    # [+fileName+]  The name of the file to use on disk
    # [+content+]   The content of the file
    #               It is required that content responds to "read" (and each, gets) and not be closed.
    # [+extract+] extract file after moving
    # [+fileUpdateArray+] An Array with required variables to update the temp update status of a file once it has been copied to the 'real' location
    # [+returns+]
    def writeFileOnDisk(fileName, content, extract=false, fileUpdateArray=[])
      retVal = true
      t1 = Time.now
      # fileName may contain subdirs that do not exist yet
      # if this is the case, identify and create
      # Does the fileName contain a '/'
      @targetDirForDbRec = ""
      subDirs = File.dirname(fileName)
      if(subDirs == '.') # Then just a file name, no subdirs involved
        actualFileName = fileName
        fullEscSubDirs = "#{@filesDir.path}"
      else # We have some subdirs telling us where to put the file (they may need to be created)
        @targetDirForDbRec = subDirs
        actualFileName = File.basename(fileName)
        # Create escaped version of the subdirs if they don't exist. (user may like dirs with ' " * : or whatever...so we make them safe)
        escSubDirs = subDirs.split('/').map { |xx| CGI.escape(xx) }.join('/')
        fullEscSubDirs = "#{@filesDir.path}/#{escSubDirs}"
        `mkdir -p #{fullEscSubDirs}`
      end
      escActualFileName = CGI.escape(actualFileName)
      fullFilePath = "#{fullEscSubDirs}/#{escActualFileName}"
      ##################################################
      # DEBUGGING CHECKS (tracking a problem)
      ##################################################
      unless(fullFilePath[0].chr == '/')
        $stderr.debugPuts(__FILE__, __method__, "FATAL RELATIVE DIR ERROR!!", "Ended up creating a full path of #{fullFilePath.inspect} which does not appear to be a full path to actual disk location for #{fileName.inspect} content. Probably a bug! Probably can lose data & pollute storage! Check code using following backtrace:")
        begin
          raise
        rescue => noErr
          $stderr.puts noErr.backtrace.join("\n")
        end
        $stderr.puts "\n"
      end # DEBUGGING CHECKS (tracking a problem)
      @scratchDir = fullEscSubDirs
      content.rewind() if(content.respond_to?(:rewind))
      # Remove the existing file if its there on disk
      FileUtils.rm(fullFilePath) if(File.exists?(fullFilePath))
      # Put the new content in place
      #$stderr.debugPuts(__FILE__, __method__, "STATUS", "Copying file #{fileName.inspect} to: #{fullFilePath.inspect}")
      genbConf = BRL::Genboree::GenboreeConfig.load()
      # NOTE: fullFilePath contains the actual path to the storage location on disk,
      # including any dirs/filenames that need to be escaped to make their actual storage location.
      # - As an actual path, this can be used directly by unix commands like "mv", "grep", "cat" etc.
      # - BUT when used as argument to a Genboree Ruby script IT MUST BE ESCAPED.
      #   . don't worry, the argument will be automatically unescaped by Genboree Ruby script before being
      #     made available
      #   . i.e. this approach ensures any dirs or files build using with escape sequences in their actual names
      #     (as is done here!) will end up being themselves escaped when handed to a Genboree Ruby script
      unless(@localFileStorageHelperUpload)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "This request is not coming from the local storage helper, so we're moving the file into place using the old way (Tempfile versus StringIO)")  
        if(content.is_a?(Tempfile))
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Content is a tempfile")
          @doMove = true
          `mv -f #{Shellwords.escape(content.path)} #{Shellwords.escape(content.path)}_genboree.hideFromthin ; chmod 664 #{Shellwords.escape(content.path)}_genboree.hideFromthin`
          submitLocalFileProcessJob(fileUpdateArray, "#{content.path}_genboree.hideFromthin", fullFilePath, extract)
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Content not a tempfile")
          @doMove = false
          File.open(fullFilePath, 'w') { |file|
            while(chunk = content.read(READ_BUFFER_SIZE))
              file.write(chunk)
            end
          }
          `chmod 660 #{Shellwords.escape(fullFilePath)}`
          # Manually set permissions here to avoid defaults of a Tempfile
          FileUtils.chmod(0664, fullFilePath)
          postProcessForNonTempFile(fileUpdateArray, "#{content.path}_genboree.hideFromthin", fullFilePath, extract)
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "This request is coming from the local storage helper, so we're going to use file size as a metric (instead of Tempfile / StringIO difference)") 
        #if(File.size(content) > MAX_LOCAL_SIZE)
        if(true) # Used in cases where we need to send all files to localFileProcessor (prod, unless our newest changes fix current issues with file move occurring AFTER sha is computed)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Content is greater than 8 megs, so we're going to run a localFileProcessor job")
          @doMove = true
          #`mv -f #{Shellwords.escape(content)} #{Shellwords.escape(content)}_genboree.hideFromthin ; chmod 664 #{Shellwords.escape(content)}_genboree.hideFromthin`
          `chmod 660 #{Shellwords.escape(content)}`
          submitLocalFileProcessJob(fileUpdateArray, content, fullFilePath, extract)
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Content is less than 8 megs, so we're going to move it into place directly")
          @doMove = false
          `mv #{Shellwords.escape(content)} #{Shellwords.escape(fullFilePath)}`
          `chmod 660 #{Shellwords.escape(fullFilePath)}`
          # Manually set permissions here to avoid defaults of a Tempfile
          #FileUtils.chmod(0664, fullFilePath)
          postProcessForNonTempFile(fileUpdateArray, nil, fullFilePath, extract)
        end
      end
      return retVal
    end
    
    # Handles post processing operations for files (Non TempFile) after they they have been written to the target dir
    # @param [Array] fileUpdateArray
    # @param [String] src
    # @param [String] fullFilePath
    # @param [Boolean] extract
    def postProcessForNonTempFile(fileUpdateArray, src, fullFilePath, extract)
      # File is a database file. Expose it and compute sha1
      if(!fileUpdateArray.empty?)
        dbName = fileUpdateArray[0]
        fileId = fileUpdateArray[1]
        gbUploadId = fileUpdateArray[2]
        gbUploadFalseValueId = fileUpdateArray[3]
        gbPartialEntityId = fileUpdateArray[4]        
        gc = BRL::Genboree::GenboreeConfig.load()
        dbu = BRL::Genboree::DBUtil.new(gc.dbrcKey, nil, nil)
        dbu.setNewDataDb(dbName)
        dbu.updateFile2AttributeForFileAndAttrName(fileId, gbUploadId, gbUploadFalseValueId)
        dbu.updateFile2AttributeForFileAndAttrName(fileId, gbPartialEntityId, gbUploadFalseValueId)
        stdin, stdout, stderr = Open3.popen3("sha1sum #{Shellwords.escape(fullFilePath)}") 
        sha1sum = stdout.readlines[0].split(' ')[0]
        dbu.insertFileAttrValue(sha1sum) 
        gbSha1AttrId = dbu.selectFileAttrNameByName('gbDataSha1').first['id'] 
        gbSha1ValueId = dbu.selectFileAttrValueByValue(sha1sum).first['id'] 
        dbu.insertFile2Attribute(fileId, gbSha1AttrId, gbSha1ValueId)
        dbu.clear()
      else # File is a project file or non database file   
        # This file does not require any 'exposing' nor does it require sha1
      end
      # For extract=true, we will submit the localFileProcess job since we do not want to do extraction within the server process.
      if(extract)
        submitLocalFileProcessJob(fileUpdateArray, src, fullFilePath, extract)
      end
    end
    
    # Submits a job to move the file from the tmp area to the target dir.
    # Job also computes SHA1 of the file to store in database
    # @param [Array] fileUpdateArray
    # @param [String] src
    # @param [String] fullFilePath
    # @param [Boolean] extract
    def submitLocalFileProcessJob(fileUpdateArray, src, fullFilePath, extract)
      gc = BRL::Genboree::GenboreeConfig.load()
      dbu = BRL::Genboree::DBUtil.new(gc.dbrcKey, nil, nil)
      userRec = dbu.selectUserById(@userId).first
      unless(userRec)
        raise "Error: no user record exists for user ID #{@userId} - are you trying to upload a file as gbSuperUser? This is not allowed!"
      end
      settings = {}
      if(!fileUpdateArray.empty?)
        settings = {
          'dbName' => fileUpdateArray[0],
          'fileId' => fileUpdateArray[1],
          'gbUploadId' => fileUpdateArray[2],
          'gbUploadFalseValueId' => fileUpdateArray[3],
          'gbPartialEntityId' => fileUpdateArray[4],
          'extract' => extract,
          'source' => src,
          'fullFilePath' => fullFilePath,
          'groupName' => @groupName,
          'refseqName' => @dbName,
          'fileName' => @fileName,
          'doMove' => @doMove,
          'computeSHAAndSetAttr' => true
        }
      else
        settings = {
          'extract' => extract,
          'source' => src,
          'fullFilePath' => fullFilePath,
          'computeSHAAndSetAttr' => false,
          'doMove' => @doMove
        }
      end
      settings['suppressEmail'] = ( @suppressEmail ? true : false ) # Set by the class/resource that is mixing in this module
      settings['gbPrequeueHost'] = @genbConf.internalHostnameForCluster
      payload = {
        'inputs' => [],
        'outputs' => [],
        'context' => {
          'toolIdStr' => 'localFileProcessor',
          'queue' => 'gb',
          'userId' => @userId,
          'toolTitle' => 'Process Local File',
          'userLogin' => userRec['name'],
          'userLastName' => userRec['lastName'],
          'userFirstName' => userRec['firstName'],
          'userEmail' => userRec['email'],
          'gbAdminEmail' => gc.gbAdminEmail
        },
        'settings' => settings
      }
      rackEnv = fileUpdateArray[5] rescue nil
      apiCaller = WrapperApiCaller.new(@genbConf.machineName, '/REST/v1/genboree/tool/localFileProcessor/job?', @userId)
      # Need to make sure rackEnv is set since we are going to make internal API call to submit LocalFileProcessor job
      apiCaller.initInternalRequest(rackEnv, @genbConf.machineNameAlias) if(rackEnv)
      apiCaller.put(payload.to_json)
      if(!apiCaller.succeeded?)
        raise apiCaller.respBody
      else
        localFileProcessorJobId = JSON.parse(apiCaller.respBody)['data']['text']
        begin
          self.relatedJobIds << localFileProcessorJobId
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "CANNOT_SET_ATTR", "The object that is using this method does not have @relatedJobIds as an attribute. ")
        end
      end
    end


    # This method filters the index file by the specified sub dir string
    #
    # [+subDirStr+]
    # [+returns+]
    def filterIndexBySubdir(subDirStr)
      filteredData = []
      @data.each { |fileRec|
        if(fileRec['fileName'].index(subDirStr+'/') == 0)
          filteredData << fileRec
        end
      }
      return JSON.pretty_generate(filteredData)
    end

    # Helper method to determine if the passed filename should be ignored from the process.
    # This checks if the file is a directory, the indexFileName or in the fileKillList
    # [+fileName+]  The name of the file to check
    #
    # [+returns+] true if it should be ignore, false if the file should be used (in whatever process we are doing)
    def ignoreFile?(fileName)
      ignoreFile = (fileName == @indexFileName or File.directory?(fileName) or fileName =~ /\.GENB_DELETED/)
      unless(ignoreFile)
        # Check our entries in the file kill list if we are still valid
        @fileKillList.each { |filePattern, ignore|
          if(ignore and File.fnmatch?(filePattern, fileName))
            ignoreFile = true
            break
          end
        }
      end

      return ignoreFile
    end

    #--------------------------------------------------------------------------
    # HELPER Class Methods
    #--------------------------------------------------------------------------
    # Determine if file index record indicates if the file should be hidden
    def FileManagement.isHidden?(fileIndexRec)
      retVal = false
      if(fileIndexRec.key?('hide'))
        if(fileIndexRec['hide'].is_a?(String)) # else assume already true or false literals
          retVal = (fileIndexRec['hide'].strip =~ /^(?:true|yes)$/i ? true : false)
        else
          retVal = fileIndexRec['hide']
        end
      end
      return retVal
    end
    

    # Is the file list empty
    # - Not only checks if empty, but also can treat lists with all hide flags as empty too
    # [+fileList+]    The array of file index records to consider
    # [+countHidden+] [optional; default=false]
    # [+returns+]     true if list is empty or has only hidden file records
    def FileManagement.isFileListEmpty?(fileList, countHidden=false)
      retVal = false
      if(fileList.empty?)
        retVal = true
      elsif(!countHidden) # then we need to see if all files in list are hidden
        retVal = true
        fileList.each { |fileIndexRec|
          if(!FileManagement.isHidden?(fileIndexRec))
            retVal = false
            break
          end
        }
      else
        retVal = false
      end
      return retVal
    end

    # Update file record archive status based on recTime
    def FileManagement.adjustArchiveStateByTime(recTime, fileRecToAdjust)
      retVal = false
      timeDiffSecs = Time.now.to_i - recTime.to_i
      if(timeDiffSecs > AUTOARCHIVE_THRESHOLD)
        # We need to auto-archive this. Set archived flag as well.
        fileRecToAdjust['archived'] = true
        fileRecToAdjust['autoArchive'] = true
        retVal = true
      end
      return retVal
    end

    def FileManagement.validatePropertyValue(property, value, options={})
      retVal = :OK
      # Define default options
      if(options.nil?)
        options[:allowSubDirs] = false
      end
      case property
      when 'date'
        # TODO: validate date text looks like a data
      when 'hide'
        # TODO: validate looks like 'true' or 'false'
      # etc for all aspects of files
      end
      return retVal
    end
  end
end ; end ; end ; end
