#!/usr/bin/env ruby
require 'brl/util/bufferedJsonReader' # @todo move this
require 'brl/genboree/rest/resources/kbDocs' # for MAX_DOCS constant
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/kb/helpers/dataCollectionHelper'
require 'brl/activeSupport/activeSupport'

module BRL; module Genboree; module Tools; module Scripts
  class KbBulkUploadWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "Upload KB documents in bulk. Divides what would be too large of a "\
                        "request for the API to handle into multiple smaller requests.",
      :authors      => [ "Aaron Baker (ab4@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    SUPPORTED_FORMATS = BRL::Genboree::REST::Data::KbDocEntity::FORMATS
    # Define maximum for use of 'json' gem, above which we switch to 'json/stream'
    MAX_SIZE = 6442450 # 3 * 1024^3 / 500 -- memory limit / conservative file-size-to-memory ratio

    # @see BRL::Genboree::Tools::ToolWrapper
    def processJobConf()
      @exitCode = 0
      begin
        # prepare report file -- a tabular format with header:
        # uri, uncomp_basename, index, message
        delim = "\t"
        header = ["uri", "uncompressed_name", "index", "error_message"]
        reportPath = "#{@scratchDir}/#{@jobId}-report.tsv"
        reportFh = File.open(reportPath, "w")
        @reporter = Reporter.new(reportFh, header, delim)
        @reporter.outputs = @outputs
        @reporter.grpApiHelper = @grpApiHelper
        @reporter.dbApiHelper = @dbApiHelper
        @reporter.kbApiHelper = @kbApiHelper
        @reporter.fileApiHelper = @fileApiHelper
        # verify format setting is recognized
        @format = @settings['format'].upcase.gsub(" ", "_").to_sym rescue nil
        if(@format.nil? or !SUPPORTED_FORMATS.include?(@format))
          @exitCode = 22
          raise BRL::Genboree::GenboreeError.new(:"Unsupported Media Type", "The provided format #{@settings['format'].inspect} is not in the list of accepted formats: #{SUPPORTED_FORMATS.join(", ")}")
        end
        @suppressSuccessEmails = @settings['suppressSuccessEmails']
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @errInternalMsg = @errUserMsg = err.message
        else
          @exitCode = 20
          @errInternalMsg = @errUserMsg = "Unhandled exception"
        end
      end
      return @exitCode
    end

    # Upload input files to the output collection
    # @param [Array<String>] @inputs filepaths with possibly compressed contents
    # @param [Array<String>] @outputs contains a URL to a collection the input files should be uploaded to
    # @see BRL::Genboree::Tools::ToolWrapper
    def run()
      @exitCode = 0
      begin
        # download inputs files and schedule them for clean up
        @fileApiHelper.sleepBase = 30
        uriPartition = @fileApiHelper.downloadFilesInThreads(@inputs, @userId, @scratchDir)
        localPaths = uriPartition[:success].values
        @removeFiles = localPaths
        BRL::ActiveSupport.restoreJsonMethods()
        # setup data collection helper
        # @todo remove this by not requiring use of dch! use docValidator!
        gbHost = @kbApiHelper.extractHost(@outputs.first)
        gbGroup = @grpApiHelper.extractName(@outputs.first)
        gbKbName = @kbApiHelper.extractName(@outputs.first)
        dbu = BRL::Genboree::DBUtil.new("DB:#{gbHost}", nil, nil)
        kbRecs = dbu.selectKbByNameAndGroupName(gbKbName, gbGroup)
        if(kbRecs.nil?)
          raise BRL::Genboree::GenboreeError.new(:"Not Found", "Could not retrieve KB information for host: #{gbHost}, group:#{gbGroup}, and kb:#{gbKbName}")
        end
        mdbName = kbRecs.first['databaseName']
        mongoDbrcRec = @suDbDbrc.getRecordByHost(@genbConf.machineName, :nosql)
        mdb = BRL::Genboree::KB::MongoKbDatabase.new(mdbName, mongoDbrcRec[:driver], { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password] })
        uriObj = URI.parse(@outputs.first)
        @dch = mdb.dataCollectionHelper(CGI.unescape(File.basename(uriObj.path)))

        # get full file paths to upload as mapping of compressed files to list of uncompressed
        # files contained in it
        compPartition = BRL::Util::Expander.extract_files(localPaths)

        # deserialize files into entities
        # discard per-file entities to save memory
        uncompPartition = { :success => {}, :fail => {} }
        uriPartition[:success].each_key { |uri|
          begin
            # per uri error checking
            @reporter.uri = uri
            @reporter.basename = nil
            compPath = uriPartition[:success][uri]
            uncompFiles = nil
            if(compPartition[:success].key?(compPath))
              uncompFiles = compPartition[:success][compPath]
            elsif(compPartition[:fail].key?(compPath))
              message = compPartition[:fail][compPath].message
              raise BRL::Genboree::GenboreeError.new(:"Bad Request", message)
            else
              message = "Could not extract archive"
              raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", message)
            end
            @reporter.n_files += uncompFiles.size
            uncompFiles.each { |uncompPath|
              uncompBasename = File.basename(uncompPath)
              @reporter.basename = uncompBasename
              begin
                # per uncompressed file error checking
                # set entities with a method depending on uncompressed file size
                entities = nil
                uncompFh = File.open(uncompPath)
                if(File.size(uncompPath) > MAX_SIZE)
                  raise BRL::Genboree::GenboreeError.new(:"Not Implemented", "Unfortunately, we do not support file uploads larger than #{MAX_SIZE} for non JSON formats.") if(@settings['format'] !~ /json/i)
                  # deserialize with 'json/stream' to save memory and upload
                  bjr = BRL::Util::BufferedJsonReader.new(uncompFh)
                  begin
                    # second argument's serialized limit should be sufficient to result in only 1 serialization for web server upload
                    numEntities = bjr.each(100, BRL::REST::Resources::KbDocs::MAX_BYTES - BRL::Util::BufferedJsonReader::CHUNK_SIZE) { |objs|
                      status = uploadKbDocs(objs)
                      objs.clear()
                    }
                    # if each ends up yielding nothing, then @reporter.n_upload == 0
                  rescue ::JSON::Stream::MemoryError => err
                    msg = "Parsing exceeded the available #{::JSON::Stream::MyParser::MAX_MEMORY * 1024} bytes of memory; please consider an alternative model for the data"
                    raise BRL::Genboree::GenboreeError.new(:"Bad Request", msg)
                  rescue ::JSON::Stream::ParserError => err
                    msg = "Could not parse contents as JSON: #{err.message}"
                    raise BRL::Genboree::GenboreeError.new(:"Bad Request", msg)
                  end
                else
                  # deserialize with 'json' gem and upload
                  entities = deserializeHelper(uncompFh.read)
                  if(entities.nil? or entities.is_a?(Exception))
                    message = entities.is_a?(Exception) ? ": #{entities.message}" : nil
                    raise BRL::Genboree::GenboreeError.new(:"Bad Request", "Could not parse file #{uncompBasename.inspect} as format #{@format.inspect}#{message}")
                  end
                  status = uploadKbDocs(entities.map{|xx| xx.doc})
                end
                uncompPartition[:success][uncompPath] = nil
              rescue => err
                # per uncompress file rescue
                @reporter.error(err)
                uncompPartition[:fail][uncompPath] = err
                unless(err.is_a?(BRL::Genboree::GenboreeError))
                  @exitCode = 27
                end
              ensure
                uncompFh.close
              end
            }
          rescue => err
            # per uri file rescue
            @reporter.error(err)
            unless(err.is_a?(BRL::Genboree::GenboreeError))
              @exitCode = 27
            end
          end
        }
        success = @reporter.finish(@userId)
        unless(success)
          @exitCode = 25
          raise BRL::Genboree::GenboreeError.new(:"Internal Server Error", "Could not upload file explaining why certain documents could not be uploaded to #{@outputs.first}")
        end

        if(@reporter.n_upload == 0)
          @exitCode = 24
          @errInternalMsg = @errUserMsg = "None of the KB documents in your inputs were successfully uploaded"
        end
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @errInternalMsg = @errUserMsg = err.message
        else
          @exitCode = 21
          @errInternalMsg = @errUserMsg = "Unhandled exception"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "ERROR", err.backtrace.join("\n") + "\n")
        end
      end
      return @exitCode
    end

    # Validate, generate content, and upload kbDocs
    # @param [Hash] docs
    # @note @dch must be set to a BRL::Genboree::KB::DataCollectionHelper instance that will be used
    #   to perform validation and content generation, and @kbApiHelper must be set to a
    #   BRL::Genboree::REST::Helpers::KbApiUriHelper instance that will be used to perform the upload
    # @return [Hash] with keys
    #   [Integer] :valid the number of valid documents
    #   [Integer] :uploaded the number of uploaded documents
    def uploadKbDocs(docs)
      retVal = { :valid => 0, :uploaded => 0}
      @reporter.n_docs += docs.size

      # validate documents
      docsPartition = @dch.saveDocs(docs, @userLogin, { :save => false, :doingMemoization => true })

      # count validation errors
      @reporter.recordInvalid(docsPartition[:invalid], docs.size)

      # upload kbDocs in sets
      # indexes is parallel with values; indexes gives the original index in the docs array;
      #   uploadPartition indexes are those for the values array, not the docs array
      # @todo instruct server to skip validation (it has been done already)
      validIndex2EntityIndex = docsPartition[:valid].keys.sort() # @todo use ordered hash
      validDocs = []
      validIndex2EntityIndex.each{|ii| validDocs << docsPartition[:valid][ii]}
      retVal[:valid] = validDocs.size
      @reporter.n_valid += retVal[:valid]
      # Get the 'gbSys' key (password) from the .dbrc file. This will allows us to override the validation on the server side.
      dbrc = BRL::DB::DBRC.new()
      dbrcRec = dbrc.getRecordByHost(@genbConf.machineName, "GBSYS")
      uploadPartition = @kbApiHelper.uploadKbDocEntities(@outputs.first, validDocs, @userId, { :gbSysKey => dbrcRec[:password], :validate => false })

      # count upload errors
      @reporter.recordNoUpload(uploadPartition[:fail], validIndex2EntityIndex)
      retVal[:uploaded] = uploadPartition[:success].inject(0) { |sum, successRange| sum += successRange.size }
      @reporter.n_upload += retVal[:uploaded]

      return retVal
    end

    # Deserialize serializedStr as either a KbDocEntityList or a single KbDocEntity then
    #   return a KbDocEntityList regardless
    def deserializeHelper(serializedStr)
      retVal = nil
      entities = BRL::Genboree::REST::Data::KbDocEntityList.deserialize(serializedStr, @format, exceptionPassThrough=true, opts={:docType => :data})
      if(entities.is_a?(Exception) or entities == :"Unsupported Media Type")
        entity = BRL::Genboree::REST::Data::KbDocEntity.deserialize(serializedStr, @format, exceptionPassThrough=true, opts={:docType => :data})
        if(entity.is_a?(Exception) or entity == :"Unsupported Media Type")
          retVal = entity
        else
          entities = BRL::Genboree::REST::Data::KbDocEntityList.new(doRefs=false, [entity])
        end
      end
      retVal = entities
      return retVal
    end

    # @see BRL::Genboree::Tools::ToolWrapper
    def prepSuccessEmail()
      emailer = getEmailerConfTemplate()
      additionalInfos = [@reporter.formatReport(), @reporter.formatErrors()]
      emailer.additionalInfo = additionalInfos.join("\n")
      if(@suppressSuccessEmails)
        return nil
      else
        return emailer
      end
    end

    # @see BRL::Genboree::Tools::ToolWrapper
    def prepErrorEmail()
      emailer = getEmailerConfTemplate()
      additionalInfos = [@reporter.formatReport(), @reporter.formatErrors()]
      emailer.additionalInfo = additionalInfos.join("\n")
      emailer.exitStatusCode = @exitCode.to_s
      emailer.errMessage = @errUserMsg
      return emailer
    end
  end

  # Separate stateful status reporting from functional, stateless job execution
  # Methods defined here should be thought of as hooks for certain events that happen during the script execution
  # Currently this exact interface must be followed, but @todo make calls to Reporter instance only if the
  #   instance responds to the method -- i.e. a hook is defined. Certain hooks only make sense in the context
  #   of other ones, though
  class Reporter
    MAX_ERRORS = 11 # number of errors to report in email, including a header line
    # @param [String] delim a delimiter to use for rows in the emailErrors table
    attr_accessor :delim
    # @param [Array<Array>] emailErrors in memory table error data
    attr_accessor :emailErrors
    # @param [IO] reportFh a file to write error report to
    attr_accessor :reportFh
    attr_accessor :n_files
    attr_accessor :n_docs
    attr_accessor :n_valid
    attr_accessor :n_upload
    attr_accessor :outputs
    attr_accessor :grpApiHelper
    attr_accessor :dbApiHelper
    attr_accessor :kbApiHelper
    attr_accessor :fileApiHelper

    # @param [String] uri the input uri the entities being uploaded came from
    def uri=(uri)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Processing files associated with URI #{uri.inspect}")
      @uri = uri
    end
    attr_reader :uri

    # @param [String] basename the file associated with the uri that the entities came from
    def basename=(basename)
      unless(basename.nil?)
        # only report status if we arent merely cleaning the name after a file is processed
        unless(@basename.nil?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{@n_docs} documents found so far, of those #{@n_valid} are valid and of those #{@n_upload} were uploaded")
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Processing documents in #{basename.inspect}")
        @basename = basename
      end
    end
    attr_reader :basename

    def initialize(reportFh, header, delim="\t")
      @reportFh = reportFh
      @emailErrors = []
      @delim = delim
      @reportFh.write("##{header.join(delim)}\n")
      @emailErrors = [header]
      @n_files = @n_docs = @n_valid = @n_upload = 0

      @emailLabelsOrder = [:n_files, :n_docs, :n_valid, :n_upload]
      @emailLabels = {
        :n_files => "Number of KB-document-containing files processed",
        :n_docs => "Number of KB documents with validation attempted",
        :n_valid => "Number of valid documents",
        :n_upload => "Number of documents saved to KB"
      }
    end

    def recordInvalid(index2Err, nDocsInBatch)
      # @todo write invalid errors sorted by entity index followed by upload failures
      #   sorted by entity index or interleave sorted by entity index?
      indexes = index2Err.keys.sort
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{index2Err.size} invalid documents in #{@basename.inspect}")
      indexes.each { |index|
        error = index2Err[index]
        entityIndex = @n_docs - nDocsInBatch + index
        message = error.message
        backtrace = error.backtrace
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Invalid entity #{entityIndex}: #{message}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "\n" + backtrace.join("\n")) if(backtrace.respond_to?(:join))
        recordErrors(@reportFh, @emailErrors, [@uri, @basename, entityIndex, message], @delim)
      }
    end

    def recordNoUpload(range2Err, validIndex2EntityIndex)
      sortedRanges = range2Err.keys.sort{|xx,yy| xx.first <=> yy.first}
      uploadErrors = 0
      sortedRanges.each { |range|
        error = range2Err[range]
        message = error.message
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Upload failed for range #{@n_docs}+#{range.inspect}: #{message}")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "\n" + error.backtrace.join("\n"))
        range.each { |validIndex|
          index = validIndex2EntityIndex[validIndex]
          entityIndex = @n_docs + index
          recordErrors(@reportFh, @emailErrors, [@uri, @basename, entityIndex, message], @delim)
          uploadErrors += 1
        }
      }
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{uploadErrors} valid documents failed upload")
    end

    def finish(userId)
      success = true # we may not upload a file at all
      # Upload a file reporting errors if the number of errors is large
      @reportFh.close()
      @reportUrl = nil
      if(@emailErrors.size == MAX_ERRORS)
        dbUrl = @kbApiHelper.getGenboreeDb(@outputs.first)
        @reportUrl = "#{dbUrl.chomp("?")}/file/#{CGI.escape(File.basename(@reportFh.path))}"
        uriObj = URI.parse("#{@reportUrl}/data")
        success = @fileApiHelper.uploadFile(uriObj.host, uriObj.path, userId, @reportFh.path)
      end
      return success
    end

    def error(err)
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not process documents in #{@basename.inspect}")
      $stderr.debugPuts(__FILE__, __method__, "ERROR", err.message)
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "\n" + err.backtrace.join("\n") + "\n")
      if(err.is_a?(BRL::Genboree::GenboreeError))
        recordErrors(@reportFh, @emailErrors, [@uri, @basename, nil, err.message], @delim)
      else
        # any per-file unhandled exception is an error
        @exitCode = 27
        recordErrors(@reportFh, @emailErrors, [@uri, @basename, nil, "Unhandled exception"], @delim)
      end
    end

    # Record information in a CSV-style file
    # @param [IO] an open file handle for writing
    # @param [Array<String>] tokens to write to the file
    # @param [String] delim how to delimit tokens in the file
    # @return [NilClass]
    def recordErrorInFile(fh, tokens, delim="\t")
      fh.write([tokens.join(delim), "\n"])
    end

    # Record information in a Array-of-Arrays for use in an email string
    # @param [Array<Array<String>>] array pre-formatting CSV-like data
    # @param [Array<String>] tokens to add to array if size permits
    # @param [Fixnum] maxSize limit on array size
    # @return [Array] array as modified (if at all)
    def recordErrorInMemory(array, tokens, maxSize=MAX_ERRORS)
      array << tokens if (array.size < maxSize)
      return array
    end

    # @see recordErrorInFile
    # @see recordErrorInMemory
    def recordErrors(fh, array, tokens, delim="\t", maxSize=MAX_ERRORS)
      # both for the file format and for the email (TSVs), \t and \n must be escaped
      raise ArgumentError.new("Why are you trying to use \\n as a column delimiter?") if(delim == "\n")
      escapedDelim = delim.inspect.gsub("\"", "")
      # TODO: We should figure out a better way of dealing with \n chars in tokens.
      #       Escaped \n chars are ugly in an error message. especially for the new metadata validation messages. 
      #       It'd be better to put some kind of pipe delimiter or something.
      tokens = tokens.map{|token| token.to_s.gsub(delim, escapedDelim).gsub("\n", "\\n")}
      recordErrorInFile(fh, tokens, delim)
      recordErrorInMemory(array, tokens, maxSize)
    end

    # Format a pair of hashes for an email report (highly generic)
    # @param [Hash<Symbol, String>] field2Label map field internal name to a nice display label
    # @param [Hash<Symbol, String>] field2Value map field internal name to its value
    # @param [Array<Symbol>] fieldOrder the order of fields to be printed in the report
    # @return [String] a nicely formatted report string for the user
    def formatReport(field2Label=@emailLabels, field2Value={:n_files => @n_files, :n_docs => @n_docs, :n_valid => @n_valid, :n_upload => @n_upload}, fieldOrder=@emailLabelsOrder)
      report = nil
      if(field2Label.nil? or field2Label.empty? or field2Value.nil? or field2Value.empty?)
        report = nil
      else
        max = 0
        fieldOrder = field2Label.keys() if(fieldOrder.nil?)
        fieldOrder.each { |field|
          label = field2Label[field]
          max = label.size if(label.size> max)
        }
        lines = []
        fieldOrder.each { |field|
          label = field2Label[field]
          value = field2Value[field]
          padding = " " * (max - label.size)
          lines << "#{label}:#{padding} #{value}"
        }
        report = lines.join("\n")
        end
      return report
    end

    # report first MAX_ERRORS errors found while processing documents and a Genboree file location where
    #   an additional errors are explained (tool-specific)
    # @param [Array<Array<String>>] errorLines list of columns describing error with first entity as a header
    # @param [String] fileUrl the file location to base a location string on
    # @param [String] delim a delimiter to use to join error line columns
    # @return [String] a string explaning errors while processing documents
    def formatErrors(errorLines=@emailErrors, fileUrl=@reportUrl, delim="\t")
      # format errorLines
      retVal = ""
      if(errorLines.nil? or errorLines.size == 1)
        retVal = ""
      else
        # format fileUrl, if provided
        if(fileUrl)
          header = "\nA full report of all documents that could not be uploaded may be found at:\n"
          gbLocString = BRL::Genboree::Tools::ToolWrapper.formatFileUrlLocation(fileUrl, {:header => header, :grpApiHelper => @grpApiHelper, :dbApiHelper => @dbApiHelper, :fileApiHelper => @fileApiHelper})
          retVal << gbLocString << "\n"
        end

        if(fileUrl)
          # then there are errors in excess of those in errorLines
          retVal << "\nThe first #{errorLines.size-1} errors in your submission are detailed below:\n"
        else
          # then errorLines contains ALL errors
          retVal << "\nAll #{errorLines.size-1} errors in your submission are detailed below:\n"
        end
        errorLines.each { |errorLine|
          retVal << (errorLine.join(delim) + "\n")
        }
      end
      return retVal
    end

  end
end; end; end; end

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::KbBulkUploadWrapper)
end
