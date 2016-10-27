#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'ostruct'
require 'brl/util/util'
require 'brl/dataStructure/singletonJsonFileCache'
require 'shellwords'

module BRL ; module Util
  # Helper to efficiently (in O(1) time, in most cases) help determine if a file
  #   format matches the expected type or even attempt to determine the type from
  #   the known ones. In general, Linux command line tools like 'grep' are used to
  #   perform speedy detection, especially via line-anchored regexps via -P and
  #   list-positive-file-match [stops on first match] -l option. O(1) complexity
  #   is generally achieved through the use of 'head' to examine the first N number
  #   of lines rather than the whole file [which is O(N) for negative matches].
  #
  # Although the constructor takes and [optional] file path argument, a single
  # Sniffer instance can be re-used by changing {Sniffer#filePath} accessor.
  class Sniffer
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------

    # The fallback number of records to consider if not overridden using
    #   {#numRecsToConsider} and if not available from the format config json.
    # @return [Fixnum]
    DEFAULT_NUM_RECS = 50_000
    # A default map of detector command exit statuses which
    #   indicate the format was successfully detected. Typically this is ONLY 0, but allows
    #   for interesting cases where multiple exit codes indicate the status was detected, etc.
    #   This is the fallback default and only used if @detectorExitStatuses@ is not explicitly present
    #   in the format config [it should be].
    # @return [Hash{String=>Boolean}]
    DEFAULT_DETECTED_EXIT_STATUSES = { "0" => true }
    # List of formats that can be converted to ASCII. 
    ASCII_CONVERTIBLE_FORMATS = {'UTF' => true} 
    # Local shortcut to {BRL::DataStructure::SingletonJsonFileCache}
    # @return [Class]
    JsonFileCache = BRL::DataStructure::SingletonJsonFileCache

    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------

    # @return [Boolean] indicating whether this class should output verbose stderr
    #   status and debug info. Default is @false@.
    attr_accessor :verbose
    # @return [String,nil] the path to the file to sniff; must be set by the time
    #   any detector methods are called
    attr_accessor :filePath
    # @return [BRL::Genboree::GenboreeConfig] the loaded @GenboreeConfig@ object in
    #   use by this object.
    attr_accessor :gbConf
    # @return [Fixnum, nil] used to override the maximum number of recs to consider
    #   when sniffing/testing, rather than using what is recommended by the format's config.
    #   By default it is @nil@, and the number will come from the format config.
    #   This constraint--applied via 'head'--is key to ensuring O(1) complexity.
    attr_accessor :numRecsToConsider
    # @return [String] the location of the sniffer format configuration file in use.
    attr_reader :snifferConfFile
    # @return [Boolean] indicating if O(1) sniffing should be performed or if whole
    #   file should be examined rather than the first many lines. true by default.
    attr_accessor :o1Complexity

    # ------------------------------------------------------------------
    # INSTANCE METHODS
    # ------------------------------------------------------------------

    # CONSTRUCTOR.
    # @note Although the constructor takes and [optional] file path argument, a single
    #   Sniffer instance can be re-used by changing the {#filePath} accessor to
    #   new file path.
    # @param [String,File] file The file to sniff. If {String}, must be a path to the file; if File,
    #   the path will be determined and the {File} instance left _untouched/modified_.
    # @param [BRL::Genboree::GenboreeConfig] snifferConfFile If provided, an already loaded @GenboreeConfig@
    #   object which will be reused rather than creating and loading a new config object (not used in generic sniffer, only in BRL::Genboree::Helpers)
    def initialize(file=nil, snifferConfFile=nil)
      if(file)
        if(file.is_a?(String))
          @filePath = File.expand_path(file)
        elsif(file.respond_to?(:path))
          @filePath = File.expand_path(file.path)
        else
          raise "ERROR: the file argument is neither a String with the file path nor a File-like object having a path property."
        end
      else
        @filePath = nil
      end
      # Grab sniffer conf file from environment variable SNIFFER_CONF_FILE
      @snifferConfFile = ( snifferConfFile or ENV['SNIFFER_CONF_FILE'] )
      # If SNIFFER_CONF_FILE doesn't point to a readable file (or the variable doesn't exist at all), then we check to see whether the file exists at ~/snifferFormatInfo.json
      unless(@snifferConfFile and File.readable?(@snifferConfFile))
        @snifferConfFile = File.expand_path("~/snifferFormatInfo.json")
        # If the file can't be found there either, then we raise an error
        unless(File.readable?(@snifferConfFile))
          raise "ERROR: There is a problem with finding sniffer conf file (not in SNIFFER_CONF_FILE environment variable or in home directory). Either the SNIFFER_CONF_FILE environment variable is missing or points to a file that cannot be read.\nPath in SNIFFER_CONF_FILE: #{ENV['SNIFFER_CONF_FILE'].inspect}"
        end
      end
      JsonFileCache.cacheFile(:sniffer, @snifferConfFile)
      # Default settings
      @verbose = false
      @numRecsToConsider  = nil
      @o1Complexity       = true
    end

    # Try to detect if {#filePath} is formatted as 'format'.
    # @param [String] format The format to try to detect. Must be one of the top-level keys in the
    #   format config JSON file.
    # @param [OpenStruct] formatConf *Optional*. Mainly for internal use by this class's code, the
    #   specific format config object--as a frozen {OpenStruct}--can be provided if already available.
    #   For performance; saves having to retrieve it over and over (even if just from memory cache, which will minimally
    #   involve a little I/O from the file stat).
    # @return [Boolean] indicating whether {#filePath} appears to be a 'format' file or not.
    # @raise IOError
    def detect?(format, formatConf=getFormatConf(format))
      detectorStatus = runDetector(format, formatConf)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Detector command exited with this status object: #{detectorStatus.inspect}") if(@verbose)
      # Did it "successfully" detect the format?
      successStatusMap = ( formatConf.detectorExitStatuses || DEFAULT_DETECTED_EXIT_STATUSES )
      exitCode = detectorStatus.exitstatus
      return successStatusMap.key?(exitCode.to_s)
    end

    # Try to automatically detect the format of {#filePath} by considering each known format in
    # order of its priority (high->low). [Format priority is set in the format config file and
    # is generally dictated by how expensive it is to look for the format; e.g. many records needed
    # to be sure not to get a false negative, very involved regexp to detect the record, etc, are
    # all 'expensive' and should lower the priority].
    # @return [String] the first format which is detected.
    # @raise IOError
    def autoDetect()
      detectedFormat = nil
      # Consider each known format in order of its priority (high -> low)
      formats = knownFormats()
      formats.each { |format|
        formatConf = getFormatConf(format)
        detected = detect?(format, formatConf)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Format #{format.inspect} detected? #{detect.inspect}") if(@verbose)
        if(detected)
          detectedFormat = format
          break
        end
      }
      return detectedFormat
    end
    
    # Detects the mimeType of the file using the file command
    # @return [String, NilClass] nil if error occurred, string with mime type otherwise
    def mimeType()
      cmdStdout = `file --mime-type #{@filePath}`
      exitObj = $?.dup()
      retVal = nil
      if(exitObj.exitstatus == 0)
        retVal = cmdStdout.split(":")[1].strip.gsub(/\n$/, "")
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "file command for determining mime type failed.\n\nExit Object for file command: #{exitObj.inspect}") unless(@muted)
      end
      return retVal
    end

    # Get the list of known file formats that can be detected. Sorted by priority by default, with option
    #   to alphabetically sort instead.
    # @param [Boolean] sortByPriority Indicating whether to sort by format "priority" or by format name.
    # @return [Array<String>] the list of known file formats that can be detected.
    def knownFormats(sortByPriority=true)
      formatConfs = getFormatConfs()
      if(sortByPriority)
        retVal = formatConfs.keys.sort { |aa, bb| formatConfs[bb]['priority'].to_i <=> formatConfs[aa]['priority'].to_i }
      else
        retVal = formatConfs.keys.sort
      end
      return retVal
    end

    # ------------------------------------------------------------------
    # HELPER METHODS
    # - mainly for internal use but public if needed outside this class as well
    # ------------------------------------------------------------------

    # Run the detector command for @format@ on {#filePath} and return a full
    # command status object.
    # @param (see #detect?)
    # @return [Process::Status,nil] the full status object from running the command or
    #   nil when {#filePath} has not been set yet or is not readable
    # @raise IOError
    def runDetector(format, formatConf=getFormatConf(format))
      statusObj =nil
      if(@filePath and File.readable?(@filePath))
        # Build the appropriate command
        cmd = buildFullCmd(format, formatConf)
        # Run it and return the Process::Status object (so questions can be asked of it in other methods, etc)
        `#{cmd}`
        statusObj = $?
      else
        raise IOError, "ERROR: Either a filePath has not been set or the file is not readable. (@filePath: #{@filePath.inspect})"
      end
      return statusObj
    end

    # Builds the full detector command, taking into account whether this Sniffer
    # instance is set up to do O(1) detection, and appropriately filling in the dynamic fields for
    # the N recs command and detector command as needed.
    # @param (see #detect?)
    # @return [String] the full detector command, including N recs command and a pipe if appropriate,
    #   ready to run or log or whatever
    def buildFullCmd(format, formatConf=getFormatConf(format))
      # Escape file path so that it can be fed into sniffer
      filePath = Shellwords.escape(@filePath)
      # Are we doing O(1) complexity detection or a full-file scan? (O(N) complexity).
      # - O(1) requires we pipe the N Recs command output to the detector command
      # - O(N) requires us to just run the detector on the whole file.
      if(@o1Complexity)
        cmd = buildNRecsCmd(format, filePath, formatConf)
        cmd = "#{cmd} | #{buildDetectorCmd(format, '', formatConf)}"
      else
        cmd = buildDetectorCmd(format, filePath, formatConf)
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Constructed full detector command:\n    #{cmd.inspect}") if(@verbose)
      return cmd
    end

    # Builds the detector-specific command, appropriately filling in the dynamic fields as needed.
    # Will not include the command that produces N records from the file at @filePath@, just
    # the detector command itself.
    # @param [String] format The format to try to detect. Must be one of the top-level keys in the
    #   format config JSON file.
    # @param [String] filePath The path to the file to build the detector for. If planning to pipe
    #   input INTO it from another command, provide empty string ("") here.
    # @param [OpenStruct] formatConf *Optional*. Mainly for internal use by this class's code, the
    #   specific format config object--as a frozen OpenStruct--can be provided if already available.
    #   For performance; saves having to retrieve it over and over (even if just from memory cache, which will minimally
    #   involve a little I/O from the file stat).
    # @return [String] the detector-specific command
    def buildDetectorCmd(format, filePath=@filePath, formatConf=getFormatConf(format))
      # Number of records/lines to consider
      nRecs = ( @numRecsToConsider || formatConf.nRecs || DEFAULT_NUM_RECS)
      detectorCmd = ( formatConf.detectorCmd || '' )
      detectorCmd = detectorCmd.gsub(/\{N_RECS\}/, nRecs.to_s)
      detectorCmd = detectorCmd.gsub(/\{FILE_PATH\}/, filePath.to_s)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Constructed detector-specific command:\n    #{detectorCmd.inspect}") if(@verbose)
      return detectorCmd
    end

    # Builds the N recs-specific command, appropriately filling in the dynamic fields as needed.
    # Will not include the command that does the detection, just the file that appropriately
    # generates N records from @filePath@.
    # @param [String] format The format to get N recs for. Must be one of the top-level keys in the
    #   format config JSON file.
    # @param [String] filePath The path to the file to build the N recs command for.
    # @param [OpenStruct] formatConf *Optional*. Mainly for internal use by this class's code, the
    #   specific format config object--as a frozen OpenStruct--can be provided if already available.
    #   For performance; saves having to retrieve it over and over (even if just from memory cache, which will minimally
    #   involve a little I/O from the file stat).
    # @return [String] the detector-specific command
    def buildNRecsCmd(format, filePath=@filePath, formatConf=getFormatConf(format)) 
      # Number of records/lines to consider
      nRecs = ( @numRecsToConsider || formatConf.nRecs || DEFAULT_NUM_RECS)
      nRecsCmd = ( formatConf.nRecsCmd || '' )
      nRecsCmd = nRecsCmd.gsub(/\{N_RECS\}/, nRecs.to_s)
      nRecsCmd = nRecsCmd.gsub(/\{FILE_PATH\}/, filePath.to_s)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Constructed N-Recs command:\n    #{nRecsCmd.inspect}") if(@verbose)
      return nRecsCmd
    end

    # @return [Hash{String=>Hash}] containing all the known format configurations.
    def getFormatConfs()
      # Get json object from global cache
      return JsonFileCache.getJsonObject(:sniffer, @snifferConfFile)
    end

    # Gets the specific format configuration object for use in methods like the above.
    # @param [String] format The format to get the config object. Must be one of the top-level keys in the
    #   format config JSON file.
    # @return [OpenStruct] the config object as an @OpenStruct@ (basically a @Struct@ and similar to a @Hash@)
    def getFormatConf(format)
      formatConfs = getFormatConfs()
      # Get format specific conf
      formatConf = formatConfs[format]
      raise "ERROR: unknown format #{format.inspect}, cannot detect/sniff." unless(formatConf)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Config for #{format.inspect}:\n    #{formatConf.inspect}") if(@verbose)
      return OpenStruct.new(formatConf).freeze
    end
  end # class Sniffer
end ; end # module BRL ; module Util
