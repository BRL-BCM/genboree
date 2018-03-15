require 'brl/genboree/rest/em/deferrableBodies/abstractMultiPhaseBody'

module BRL ; module Genboree ; module REST ; module EM ; module DeferrableBodies
  class DeferrableFtpFileReaderBody < AbstractMultiPhaseBody
    # What states are there to streaming the data?
    #   * MUST have no-arg methods corresponding to exactly these.
    #     - No-arg, and must return a String (the chunk) even if '' is most appropriate when finishing up or something.
    #   * Processing will automatically begin in your FIRST state in this array.
    #   * SPECIAL: There is ALWAYS :finish state, corresponding to AbstractDeferrableBody#finish.
    #     - You're supposed to implement that (with super() call) to close handles and help free memory!
    #     - You can list it here for completeness/documentation
    STATES = [ :preData, :getData, :postData, :finish ]

    # @return [String] The file path not including Genboree file base (matches Genboree MySQL file record, but needs to be supplemented with file base in order to find file on disk)
    attr_accessor :path
    # @return [String] The full path, including Genboree file base (or other file base, theoretically)
    attr_accessor :fullPath
    # @return [Fixnum] The size of the remote file
    attr_accessor :remoteFileSize
    # @return [Fixnum] The current offset in the file
    attr_accessor :offset
    # @return [IO] IO object for reading chunks from FTP server via curl
    attr_accessor :fileReader
    # @return [BRL::Genboree::StorageHelpers::FtpStorageHelper] object which is used for checking file size of FTP-backed file 
    attr_accessor :ftpStorageHelper
    # @return [StandardError] any error that occurs during chunk-grabbing part of getData() phase
    attr_accessor :err
    # @return [String] backtrace of error found above (joined with newlines)
    attr_accessor :errBacktrace
    # @return [Fixnum] original time found during #initialize (used when doing reattempts for getFileSize)
    attr_accessor :originalTime

    # @return [Array<Symbol>] Array of events fired. Add via addListener(event, listenerProc). Really just here to document:
    #   * :sentChunk => called after a chunk is actively sent or passibly yielded up the chain; can be called MANY times
    #   * :preData => called after the preData setup phase is done
    #   * :getData => called after the data sending phase is done
    #   * :validateSize => called after the validateSize phase is done 
    #   * :postData => called after the postData phase is done
    #   * :finish => called after class's finish() ; the last event fired
    attr_reader :events

    # AUGMENT. Include a super(opts) call.
    def initialize(opts)
      super(opts) # Initialize inherited infrastructure
      # Add pre / get / post data events to @events
      @events += [ :preData, :postData, :getData ]
      # Initialize various instance variables
      @path = opts[:path]
      @fullPath = nil 
      @remoteFileSize = nil
      @ftpStorageHelper = opts[:ftpStorageHelper]
      @offset = 0
      @err = nil
      @errBacktrace = nil
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @originalTime = Time.now.to_i
      $stderr.debugPuts(__FILE__, __method__, "DEBUG-#{self.object_id}", "Initialized deferrable FTP file reader body for #{@path.inspect}\n  - chunkSize: #{@chunkSize.inspect}\n  - offset and total sent: #{@offset.inspect} , #{@totalBytesSent.inspect}")
    end

    # AUGMENT. Implement but include a super() call.
    def finish()
      # Clear out everything
      super()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Beginning finishing phase.")
      @path = nil
      @fullPath = nil
      @offset = nil
      @fileReader.close() rescue nil
      @ftpStorageHelper.closeRemoteConnection() rescue nil
      @ftpStorageHelper = nil
      @err = nil
      @errBacktrace = nil
      @originalTime = nil
      @remoteFileSize = nil
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Ending finishing phase.")
      return
    end

    # IMPLEMENT.
    # STATE: :preData - Phase 1, Pre data spooling set-up.
    #   * Use this to do any set-up or send out any header-row/open-wrapper type text etc.
    #   * Don't set up IO handles in initialize() since calling code may set some post-instantiation
    #     config via the accessors. Do it here.
    #   * MUST ensure proper state-transition happens by setting @state to next state when ready.
    #     Generally this is called once and then does a @state=:getData to go to data sending phase.
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of data. Typically some column header or wrapper-open text.
    def preData()
      chunk = ''
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Beginning pre data spooling phase.")
      # Calculate current time (in seconds)
      currentTime = Time.now.to_i
      # Try to get file size of remote FTP file.
      # If we succeed, we proceed.
      # If we fail, then we will stay in :preData and keep trying until 5 minutes has passed.
      # We will give up at that point and move onto :postData.
      # We take this approach to avoid blocking (we use repeated preData() calls as opposed to one long preData() call waiting for Net::FTP helper to get back to us)
      begin
        # Note that getFileSize is called only once (second parameter) with no retries and that debug statements are muted (third parameter) to avoid spamming the logs
        @remoteFileSize = @ftpStorageHelper.getFileSize(@path, 1)
      rescue Exception => err
        unless(currentTime - @originalTime > 300)
          @state = :preData
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{self.object_id}> We could not successfully retrieve the remoteFileSize for #{@path}. Will move to postData.")
          @remoteFileSize = "nil (didn't successfully grab remoteFileSize)"
          @state = :postData
          notify(:preData)
        end
      end
      # If we've successfully found a value for @remoteFileSize, then we can proceed with the rest of the preliminary setup.
      if(@remoteFileSize)
        $stderr.debugPuts(__FILE__, __method__, 'STATUS', "Remote FTP file size: #{@remoteFileSize.inspect}")
        # Set up full file path
        @fullPath = @ftpStorageHelper.getFullFilePath(@path)
        # We need to escape special characters in url (other than instances of /)
        @fullPath = @fullPath.split("/")
        @fullPath.map! {|currentToken| CGI.escape(currentToken)}
        @fullPath = @fullPath.join("/")
        # Set up IO object on file
        fullFtpPath = "ftp://#{@ftpStorageHelper.updatedHost}#{@fullPath}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Full FTP path is #{fullFtpPath}")
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "")
        #curlCommand = %Q^curl --netrc-file #{@genbConf.netrcFile} "#{fullFtpPath}" 2>/dev/null^
        curlCommand = %Q^curl -sS --netrc-file #{@genbConf.netrcFile} "#{fullFtpPath}"^
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "curlCommand: #{curlCommand.inspect}\n\tcurl to use: #{`which curl`}\n\t#{`curl --version`}")
        begin
          @fileReader = IO.popen(curlCommand)
        rescue Exception => err
          @err = err
          @errBacktrace = err.backtrace.join("\n")
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "<#{self.object_id}> There was some kind of error caused by opening our curl command via IO.popen(). Will move to postData. Details about error: #{@err.inspect} ; #{@err.message}\n\n#{@errBacktrace}")
        end
        if(@fileReader)
          # Next state:
          @state = :getData
          notify(:preData)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Done with pre data spooling phase. Moving to data spooling.")
        else
          # Next state (failure):
          @state = :postData
          notify(:preData)
        end
      end
      return chunk
    end # def preData()

    # IMPLEMENT.
    # STATE: :getData - Phase 2, spool out the doc data
    #   * MUST ensure proper state-transitions happen by setting @state to next state when ready.
    #     Generally when run out of actual data lines to send (so many times @state will be set to :getData
    #     while there is still data to send, so we stay in this state). Then after all data gone out,
    #     you would effect a state transition via @state=:postData
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of bytes to send out. Not too big for memory, not too long to generate (short ticks!), etc.
    def getData()
      chunk = ''
      begin
        # Read a chunk
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Reading chunk of data of size #{@chunkSize} (only prints once every 2000 chunks)") if(@offset == 0 or @offset % (@chunkSize * 2000) == 0)
        chunk = @fileReader.read(@chunkSize)
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Got chunk (size #{chunk.size rescue "[nil chunk!]"} from #{@fileRead.inspect}")
        # If we successfully grabbed a chunk, then let's add its size to @offset (@offset is currently used to verify that file was completely transferred over from FTP server)
        if(chunk)
          @offset += chunk.size
        end
        # If we've reached the end of the file, then we move to postData stage
        if(@fileReader.eof?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> We reached the end of the file - let's move to postData. State: #{@state} ; offset: #{@offset} ; chunk class: #{chunk.class} ; chunk size: #{chunk.size rescue "N/A"}")
          @state = :postData
          notify(:getData)
        else
          # Otherwise, we stay in getData and grab another chunk
          @state = :getData
        end
      rescue Exception => err
        # If an error occurs while reading data, we save information about the error to give to the user at the end of their file
        @err = err
        @errBacktrace = err.backtrace.join("\n")
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "<#{self.object_id}> Error occurred while reading file! Will move to postData. Details about error: #{@err.inspect} ; #{@err.message}\n\n#{@errBacktrace}")
        # We then move onto postData
        @state = :postData
        notify(:getData)
      end
      return chunk
    end # def getData()

    # IMPLEMENT.
    # STATE: :postData - Phase 3, post data spooling.
    #   * MUST ensure proper state-transitions happen by setting @state to next state when ready.
    #     Generally this will be :finish to schedule clean up.
    #   * Don't just "raise" errors without calling scheduleFinish() first to clean up after yourself.
    # @return [String] Chunk of bytes to send out. Typically some footer text, close-wrapper, or even empty string if not applicable.
    def postData()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Done data spooling. Beginning post data spooling phase to send any final bytes.")
      chunk = ''
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Sent #{@offset} bytes. Remote file is #{@remoteFileSize} bytes.")
      # If @offset doesn't equal @remoteFileSize, then our file did not finish transferring. We'll do our best to let the user know by putting a message at the end of his/her file.
      # We can't use headers for letting the user know because they've already been sent out.
      unless(@offset == @remoteFileSize)
        chunk << "An error has occurred! Your file was not successfully transferred, as only #{@offset} bytes were transferred, and the remote file is #{@remoteFileSize} bytes.\n"
        # If we've recorded information about an error that occurred, we will also report that information to the user.
        if(@err)
          chunk << "You can find more information about your error below:\n\n#{@err.inspect} : #{@err.message}\n\nBacktrace: #{@errBacktrace}"
        end
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "<#{self.object_id}> Done post data spooling phase. Should do any final finishing/cleanup next.")
      @state = :finish # really only needed for older yield approach; scheduleSend knows to go directly to scheduleFinish after postData
      notify(:postData)
      return chunk
    end
  end
end ; end ; end ; end ; end
