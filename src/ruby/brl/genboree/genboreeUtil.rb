#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# #############################################################################
require 'thread'
require 'cgi'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class
require 'brl/util/logger'
require 'brl/db/dbrc'
require 'brl/genboree/constants'

#=== *Purpose* :
#  Namespace for BRL's directly-related Genboree Ruby code.
module BRL ; module Genboree
  BLANK_RE = /^\s*$/
  COMMENT_RE = /^\s*#/
  HEADER_RE = /^\s*\[/
  DOT_RE = /^\.$/
  DIGIT_RE = /^\-?\d+$/
  NUM_SCR_RE = /^\-?\d+(?:\.\d+)?(?:e(?:\+|\-)?\d+)?$/i
  BAD_SCI_RE = /^e(?:\+|\-)\d+/i
  STRAND_RE = /^[\+\-\.]$/
  PHASE_RE = /^[012\.]$/
  MATCH_ALL_RE = /^.*$/
  TRACKNAME_RE = /^([^:]+):([^:]+)$/

  GROUP_ID_X_HEADER = "X-GENBOREE-GROUP-ID"
  DATABASE_ID_X_HEADER = "X-GENBOREE-DATABASE-ID"
  GROUP_NAME_X_HEADER = "X-GENBOREE-GROUP-NAME"
  DATABASE_NAME_X_HEADER = "X-GENBOREE-DATABASE-NAME"
  PROJECT_ID_X_HEADER = "X-GENBOREE-PROJECT-ID"
  PROJECT_NAME_X_HEADER = "X-GENBOREE-PROJECT-NAME"

  FATAL, OK, OK_WITH_ERRORS, FAILED, USAGE_ERR = 1,0,10,20,16
  USAGE_ERROR = USAGE_ERR
  NEG_ORDER, POS_ORDER = 0,1
  MAX_NUM_ERRS = 150
  MAX_EMAIL_ERRS = 25
  MAX_EMAIL_SIZE = 30_000

  # For reference: lff fields:
  # classID, tName, typeID, subtype, refName, rStart, rEnd, orientation, phase, scoreField, tStart, tEnd
  CLASSID, TNAME, TYPEID, SUBTYPE, REFNAME, RSTART, REND, STRAND, PHASE, SCORE, TSTART, TEND =
      0,1,2,3,4,5,6,7,8,9,10,11

  class GenboreeConfig < Hash
    DEF_CONFIG_FILE = (ENV.key?("GENB_CONFIG") ? ENV["GENB_CONFIG"] : '/usr/local/brl/local/apache/genboree.config.properties')

    # Set up a cached version of the config instance for speed. But the load()
    # method below MUST check if file has changed since we last cached it.
    # - a "Class Instance" variable used like this GenboreeConfig.cache
    # - only the GenboreeConfig.load() class method will take advantage of this caching.
    # - not thread friendly, be careful!!
    class << self
      attr_accessor :cache, :cacheLock
    end
    @cache = nil
    @cacheLock = Mutex.new

    # Real instance variables:
    attr_accessor :configFile, :propTable, :lastMtime

    def initialize(configFile=DEF_CONFIG_FILE)
      @configFile = configFile
      @propTable = {}
      @lastMtime = nil
    end

    # Because class-level variables are shared across ALL threads, this method
    # had to be written VERY carefully, assuming that at ANY point a different thread could interupt
    # and leave things in an inconsistent state. Therefore there is a bunch of testing to see if things
    # are really there and really populated with non-default values. These tests are fast.
    def self.load(configFile=DEF_CONFIG_FILE)
      retVal = nil
      #$stderr.puts "DEBUG: before mutex"
      GenboreeConfig.cacheLock.synchronize {
        #$stderr.puts "  DEBUG: in  mutex"
        # Get cache record using configFile path as key
        if(GenboreeConfig.cache)
          #$stderr.puts "    DEBUG: have a cache"
          cacheRec = GenboreeConfig.cache[configFile]
          if(cacheRec and !cacheRec.empty? and cacheRec[:mtime]) # have cached config object, can we use it?
            #$stderr.puts "      DEBUG: got cacheRec => #{cacheRec.inspect}"
            mtimeOfConfigFile = File.mtime(configFile)
            if(cacheRec[:mtime] >= mtimeOfConfigFile and cacheRec[:obj] and !cacheRec[:obj].propTable.empty?) # cache version is ok
              #$stderr.puts "         DEBUG: cacheObj and mtime are good; obj: #{cacheRec[:obj].inspect} ; objProps: #{cacheRec[:obj].propTable.inspect}"
              retVal = cacheRec[:obj]
            else # cache out of date or in middle of loading by someone else (another thread?)
              retVal = nil
            end
          end
        else # no cache yet
          GenboreeConfig.cache = Hash.new { |hh,kk| hh[kk] = {} }
          retVal = nil
        end
        # If retVal still nil, either not cached yet or cache is out of data
        unless(retVal)
          retVal = self.new(configFile)
          retVal.loadConfigFile()
          GenboreeConfig.cache[configFile][:mtime], GenboreeConfig.cache[configFile][:obj] = File.mtime(configFile), retVal
        end
      }
      #$stderr.puts "DEBUG: after  mutex. Retval is: #{retVal.inspect} ; props: #{retVal.propTable.inspect}"
      return retVal
    end

    def clear()
      @propTable.clear() unless(GenboreeConfig.cache and GenboreeConfig.cache.object_id == self.object_id)
    end

    # Reload the config file, but only if has newer mod time than when we
    # last loaded the file.
    def reload()
      retVal = false
      if(@lastMtime.nil? or @propTable.empty? or (File.mtime(@configFile) > @lastMtime))
        loadConfigFile()
        retVal = true
      end
      return retVal
    end

    def loadConfigFile()
      raise "ERROR: The genboree config file (#{@configFile.inspect}) is missing or unreadable! Cannot load configuration." if(@configFile.nil? or @configFile.empty? or !File.exist?(@configFile) or !File.readable?(@configFile))
      # Grab the settings from the properties file
      @lastMtime = File.mtime(@configFile)
      File.open(@configFile) { |cfile|
        @propTable = BRL::Util::PropTable.new(cfile)
      }
      # Dup and untaint values for web-use
      @propTable.each_key {|kk| @propTable[kk] = @propTable[kk].dup.untaint }
      return
    end

    def method_missing(meth, *args)
      if(meth.to_s =~ /=$/)
        @propTable[$`.to_s] = args[0].to_s
      elsif(args.empty?)
        @propTable[meth.to_s]
      else
        raise NoMethodError, "#{meth}"
      end
    end

    # Parses a time interval from the conf file and returns a start and end time based on the system time
    # Example: 18:20,600 -- the period lasts from 6:20pm to 4:20am
    #  - assumes a 24hr clock
    #
    # This method returns the current relevant time interval. i.e. the current interval or upcoming if we're not within the interval.
    # Examples: 18:20,600 -- the period lasts from 6:20pm to 4:20am
    #  Now is 13:00, return [Today: 18:20, Tomorrow: 04:20] # Before
    #  Now is 19:00, return [Today: 18:20, Tomorrow: 04:20] # During
    #  Now is 03:00, return [Yesterday: 18:20, Today: 04:20] # During
    #  Now is 05:00, return [Today: 18:20, Tomorrow: 04:20] # Before
    #
    # Examples: 08:20,600 -- the period lasts from 10:20am to 8:20pm
    #  Now is 09:00, return [Today: 10:20, Today: 20:20] # Before
    #  Now is 19:00, return [Today: 10:20, Today: 20:20] # During
    #  Now is 22:00, return [Tomorrow: 10:20, Tomorrow: 20:20] # Before
    #
    # [+timeInterval+]  string, the hh:mm, minutes
    # [+returns+]       array of Time objects, [start, end] or nil if there was a problem
    def self.getTimePeriod(timeInterval)
      retVal = nil
      tt = Time.now
      # parses out the bits using regexp
      timeInterval.strip
      timeInterval =~ /^([0-2]?\d):([0-5]\d),\s?(\d+)$/
      if(!$1.nil?)
        hh = $1
        mm = $2
        mins = $3
        # computes a start Time instance (today @ 6:20pm)
        startTime = Time.mktime(tt.year, tt.month, tt.day, hh, mm, 0, 0)
        # computes an end Time instance (start time + period length)
        endTime = startTime + (mins.to_i * 60)
        if(tt < startTime)
          # Could still be in the previous time period
          if(tt < (endTime - 86400) )
            # We're still within the previous time period so use that one
            startTime -= 86400
            endTime -= 86400
          end
        else # Time is after the start
          # If we're past the end, return the next time period
          if(tt > endTime)
            startTime += 86400
            endTime += 86400
          end
        end
        # returns Array of start and end times
        retVal = [startTime, endTime]
      end
      return retVal
    end
  end

  #=== *Purpose* :
  #  Simple class representing a closed range ( [first, last] ).
  class FullClosedWindow
    attr_accessor :first, :last, :count

    # * *Function*: Creates instance of BRL::Genboree::FullClosedWindow
    # * *Usage*   : <tt>  closedWinObj = BRL::Genboree::FullClosedWindow(first, last)  </tt>
    # * *Args*    :
    #   - +first+  ->  Start of closed range.
    #   - +last+   ->  End of closed range.
    # * *Returns* :
    #   - +FullClosedWindow+  ->  Object instance.
    # * *Throws* :
    #   - +none+
    # --------------------------------------------------------------------------
    def initialize(first, last, count=nil)
      @first = first
      @last = last
      @count = (count.nil?() ? 1 : count)
    end
  end # END: class FullClosedWindow

  def commify(num)
    if(num.kind_of?(Numeric))
      num = num.to_s
    end
    return num.gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/, '\1,\2')
  end

  def setLowPriority()
    begin
      Process.setpriority(Process::PRIO_USER, 0, 19)
    rescue
    end
    return
  end

  # Desc: Gets an HTTP X-Header from either an Apache request object or from
  #       a CGI object (well, from ENV in that case). CGI object would be more portable.
  # [+reqOrCgi+] - Apache request (mainly backwards compatibility) or CGI object
  # [+hdrKey+] - HTTP header name to get value for
  # _returns_ - The value for the requested X-HEADER or nil
  def getXHdrVal(reqOrCgi, hdrKey)
    retVal = nil
    unless(reqOrCgi.nil? or hdrKey.nil?)
      if(reqOrCgi.class.to_s == "Apache::Request") # This .to_s approach means we don't actually -need- to have Apache::Request class available...
        inHeaders = reqOrCgi.headers_in
        hdrVal = inHeaders[hdrKey]
        retVal = hdrVal if(!hdrVal.nil? and !hdrVal.empty?)
      else # assume it's a CGI instance and thus have ENV set up
        envHdrKey = "HTTP_#{hdrKey.tr('-', '_')}"
        retVal = ENV[envHdrKey]
      end
    end
    return retVal
  end

  def getGroupIdXHeader(reqOrCgi)
    return getXHdrVal(reqOrCgi, GROUP_ID_X_HEADER)
  end

  def getDatabaseIdXHeader(reqOrCgi)
    return getXHdrVal(reqOrCgi, DATABASE_ID_X_HEADER)
  end

  def getGroupNameXHeader(reqOrCgi)
    return getXHdrVal(reqOrCgi, GROUP_NAME_X_HEADER)
  end

  def getDatabaseNameXHeader(reqOrCgi)
    return getXHdrVal(reqOrCgi, DATABASE_NAME_X_HEADER)
  end

  def getProjectIdXHeader(reqOrCgi)
    return getXHdrVal(reqOrCgi, PROJECT_ID_X_HEADER)
  end

  def getProjectNameXHeader(reqOrCgi)
    return getXHdrVal(reqOrCgi, PROJECT_NAME_X_HEADER)
  end

  # Desc: Sets an HTTP X-Header via either an Apache request object or from
  #       a CGI object. CGI object would be more portable but requires BRL's
  #       extension to the CGI class which adds the ability to accumulate
  #       out-headers (regular CGI objects can't seem to do that...?) from
  #       brl/util/util.rb
  # [+reqOrCgi+] - Apache request (mainly backwards compatibility) or CGI object
  # [+hdrKey+] - HTTP header name to set value for
  # [+hdrVal+] - HTTP header name to set value for
  # _returns_ - true if set ok, false if not
  def setXHdr(reqOrCgi, hdrKey, hdrVal)
    retVal = false
    unless(reqOrCgi.nil? or hdrKey.nil? or hdrKey.empty?)
      if(reqOrCgi.class.to_s == "Apache::Request") # This .to_s approach means we don't actually -need- to have Apache::Request class available...
        reqOrCgi.headers_out[hdrKey] = hdrVal.to_s
      else # assume it's a CGI instance...must be BRL extension of builtin CGI class
        envHdrKey = hdrKey.tr('-', '_')
        reqOrCgi.setRespHeader(hdrKey, hdrVal)
      end
      retVal = true
    end
    return retVal
  end

  def setGroupIdXHeader(reqOrCgi, groupId)
    return setXHdr(reqOrCgi, GROUP_ID_X_HEADER, groupId)
  end

  def setDatabaseIdXHeader(reqOrCgi, refSeqId)
    return setXHdr(reqOrCgi, DATABASE_ID_X_HEADER, refSeqId)
  end

  def setGroupNameXHeader(reqOrCgi, groupName)
    return setXHdr(reqOrCgi, GROUP_NAME_X_HEADER, groupName)
  end

  def setDatabaseNameXHeader(reqOrCgi, dbName)
    return setXHdr(reqOrCgi, DATABASE_ID_X_HEADER, dbname)
  end

  def setProjectIdXHeader(reqOrCgi, projId)
    return setXHdr(reqOrCgi, PROJECT_ID_X_HEADER, projId)
  end

  def setProjectNameXHeader(reqOrCgi, projName)
    return setXHdr(reqOrCgi, PROJECT_NAME_X_HEADER, projId)
  end

  def loadValidRefSeqs(fileName, logger=nil)
    validRefSeqs = {}
    refSeqFile = fileName
    refReader = BRL::Util::TextReader.new(refSeqFile)
    lineArray = []
    refReader.each { |line|
      line.strip!
      # Skip blank lines, comment lines, [header] lines
      next if(line =~ BLANK_RE or line =~ COMMENT_RE or line =~ HEADER_RE)
      fields = line.split("\t")    # record lines are TAB delimited
      # all that should be in the file are lff [reference] records
      # Validate reference_point record
      valid = BRL::Genboree::validateRefSeq(fields)
      unless(valid == true) # then it is an array of error messages
        logger.addNewError("ERROR: Bad Ref Seq Record at line #{refReader.lineno}:", valid) unless(logger.nil?)
        next
      else
        validRefSeqs[fields[0].strip] = fields[2].to_i
      end
    }
    refReader.close()
    return validRefSeqs
  end

  def validateRefSeq(fields)
    retVal = []
    strippedFields = fields.map { |field| field.strip}
    unless(strippedFields.size == 3)
      retVal << "Not an LFF [reference] record. It only has #{strippedFields.size} but should have 3."
    end
#    unless(strippedFields[1].downcase.strip == 'chromosome')
#      retVal << "2nd Column must be the keyword 'Chromosome', which means 'Top Level Ref Sequence Entrypoint'"
#    end
    unless(strippedFields[2] =~ DIGIT_RE and (strippedFields[2].to_i > 0))
      retVal << "3rd Column must be an integer that is the RefSeq length."
    end
    if(retVal.empty?)
      fields = nil
      fields = strippedFields
      return true
    else
      return retVal
    end
  end

  # * *Function*: Sucks in all the LFF records in the file into a data structure
  # *             organized by targetID, track name, and then by sorted
  #               start position
  # * *Usage*   : <tt>  BRL::Genboree::loadLFFIntoTrackHash(lffFile, logger)  </tt>
  # * *Args*    :
  #   - +none+
  # * *Returns* :
  #   - +none+
  # * *Throws* :
  #   - +StandardError+ -> If the LFF file doesn't exist.
  # --------------------------------------------------------------------------
  def readLFFRecords(lffFileName, logger=nil, doValidate=true, validTrackName=nil)
    if(FileTest.exists?(lffFileName))
      reader = BRL::Util::TextReader.new(lffFileName)
    else
      raise "ERROR: ---- File #{lffFileName} does not exist! ----"
    end
    recordCount = 0
    lffRecords = {}
    tooManyErrs = false
    errCount = 0

    reader.each { |line|
      line.strip!
      next if((line =~ BLANK_RE) or (line =~ COMMENT_RE) or (line =~ HEADER_RE))
      fields = line.split("\t")

      if(fields.length == 3)    # Is it reference? SKIP
        next
      elsif(fields.length == 7)  # Assembly section? SKIP
        next
      else                      # Assume Annotation section. PROCESS
        trackName = "#{fields[TYPEID]}:#{fields[SUBTYPE]}"    # make track name
        next unless(validTrackName.nil? or (trackName == validTrackName))
        if(doValidate)
          valid = BRL::Genboree::validateAnnotation(fields)  # Validate the LFF annotation
        else # It had better be correct....
          # Fix score column if it starts with just 'e'...which means 1e, presumably
          if(fields[9] =~ BAD_SCI_RE) then fields[9] = "1#{fields[9]}" end
          # Fix score column if it is just '.'
          if(fields[9] =~ DOT_RE) then fields[9] = '0.0' end
          valid = true
        end
        unless(valid == true) # then it is an array of error messages
          errCount += 1
          logger.addNewError("ERROR: Bad Annotation Record at line #{reader.lineno}:", valid) unless(logger.nil?)
          if(errCount >= MAX_NUM_ERRS)
            tooManyErrs = true
            break
          else
            next
          end
        end
        fields[SCORE] = fields[SCORE].to_f
        # If we have only 10 fields, make last two '.'
        if(fields.length == 10) then fields[TSTART] = fields[TEND] = '.' end
        # Fix it so that start is < end for everything. Keep "strand" (aka orientation) for
        # the directional relationship.
        fields[RSTART] = fields[RSTART].to_i
        fields[REND] = fields[REND].to_i
        if(fields[RSTART] > fields[REND])
          fields[RSTART], fields[REND]  =  fields[REND], fields[RSTART]
        end
        fields[TSTART] = fields[TSTART].to_i if(fields[TSTART] != '.')
        fields[TEND] = fields[TEND].to_i if(fields[TEND] != '.')
        if((fields[TSTART] != '.') and (fields[TEND] != '.'))
          if(fields[TSTART] > fields[TEND])
            fields[TSTART], fields[TEND]  =  fields[TEND], fields[TSTART]
          end
        end
        chrom = fields[REFNAME]
        lffRecords[chrom] = {} unless(lffRecords.key?(chrom))
        lffRecords[chrom][trackName] = [] unless(lffRecords[chrom].key?(trackName))
        lffRecords[chrom][trackName] << fields
        recordCount += 1
      end
    }
    reader.close()
    if(tooManyErrs) then return false
    else
      return lffRecords
    end
  end

  def validateAnnotation(fields, queryIDRE=MATCH_ALL_RE, validRefSeqs=nil)
    retVal = []
    strippedFields = fields.collect{|field| field.strip}
    # Is the size right? If not, stop right here.
    unless((strippedFields.size == 10) or (strippedFields.size >= 12 and strippedFields.size <= 15))
      retVal << "This LFF record has #{strippedFields.size} fields."
      retVal << "LFF records are <TAB> delimited and have either 10 or 12 fields."
      retVal << "Enhanced LFF records can have 13 or 14 fields."
      retVal << "Space characters are not tabs."
    else # right number of fields, check them
      # Do we know about this entrypoint? If not, error and skip annotation.
      unless(validRefSeqs.nil?)
        if(!@validRefSeqs.key?(strippedFields[4]))
          retVal << "referring to unknown reference sequence entrypoint '#{fields[4]}'"
        else # found correct refseq, but is coords ok?
          if(strippedFields[6].to_i > validRefSeqs[strippedFields[4]])
            retVal << "end of annotation (#{fields[4]}) is beyond end of reference seqeunce (#{@validRefSeqs[strippedFields[4]]})."
            retVal << "annotation was truncated."
            strippedFields[6] = validRefSeqs[strippedFields[4]]
          end
          if(strippedFields[5].to_i > validRefSeqs[strippedFields[4]])
            retVal << "start of annotation (#{fields[4]}) is beyond end of reference seqeunce (#{@validRefSeqs[strippedFields[4]]})."
            retVal << "annotation was truncated."
            strippedFields[5] = validRefSeqs[strippedFields[4]]
          end
        end
      end
      # Check start coord.
      unless(strippedFields[5].to_s =~ DIGIT_RE and (strippedFields[5].to_i >= 0))
        retVal << "the start column contains '#{fields[5]}' and not a positive integer."
        retVal << "reference sequence coordinates should start at 1."
        retVal << "bases at negative or fractional coordinates are not supported."
      else
        strippedFields[5] = strippedFields[5].to_i
        if(strippedFields[5] == 0)  # Looks to be 0-based, half-open
          strippedFields[5] = 1     # Now it's 1-based, fully closed
        end
      end
      # Check the end coord.
      unless(strippedFields[6].to_s =~ DIGIT_RE and (strippedFields[6].to_i >= 0))
        retVal << "the end column contains '#{fields[6]}' and not a positive integer."
        retVal << "reference sequence coordinates start at 1."
        retVal << "bases at negative or fractional coordinates are not supported."
      else
        strippedFields[6] = strippedFields[6].to_i
        if(strippedFields[6] == 0)  # Looks to be 0-based, half-open
          strippedFields[6] = 1     # Now it's 1-based, fully closed
        end
      end
      # Fix score column if it starts with just 'e'...which means 1e, presumably
      if(strippedFields[9] =~ BAD_SCI_RE) then fields[9] = strippedFields[9] = "1#{strippedFields[9]}" end
      # Fix score column if it is just '.'
      if(strippedFields[9] =~ DOT_RE) then fields[9] = strippedFields[9] = '0' end
      # Check that the name column is not too long.
      if(fields[1].length > 200) then retVal << "the name '#{fields[1]}' is too long." end
      # Check the strand column.
      unless(strippedFields[7] =~ STRAND_RE) then retVal << "the strand column contains '#{fields[7]}' and not +, -, or ."  end
      # Check the phase column.
      unless(strippedFields[8] =~ PHASE_RE) then retVal << "the phase column contains '#{fields[8]}' and not 0, 1, 2, or ." end
      # Normalize start < end
      strippedFields[5] = [strippedFields[5].to_i, strippedFields[6].to_i].min
      strippedFields[6] = [strippedFields[5].to_i, strippedFields[6].to_i].max
      # Check the score
      unless(strippedFields[9] =~ NUM_SCR_RE) then
        retVal << "the score column contains '#{fields[9]}' and not an integer or real number or ."
      end
      # Check tstart/tend coords.
      if(fields.length >= 12)
        unless(strippedFields[10] =~ DOT_RE or (strippedFields[10] =~ DIGIT_RE and (strippedFields[10].to_i >= 0)))
          retVal << "the tstart column contains '#{fields[10]}' and not a positive integer or '.'"
          retVal << "sequence coordinates start at 1."
          retVal << "bases at negative or fractional coordinates are not supported."
        else
          strippedFields[10] = strippedFields[10].to_i unless(strippedFields[10] =~ DOT_RE)
          if(strippedFields[10] == 0)  # Looks to be 0-based, half-open
            strippedFields[10] = 1     # Now it's 1-based, fully closed
          end
        end
        unless(strippedFields[11] =~ DOT_RE or (strippedFields[11] =~ DIGIT_RE and (strippedFields[11].to_i >= 0)))
          retVal << "the tend column contains '#{fields[11]}' and not a positive integer or '.'"
          retVal << "sequence coordinates start at 1."
          retVal << "bases at negative or fractional coordinates are not supported."
        else
          strippedFields[11] = strippedFields[11].to_i unless(strippedFields[11] =~ DOT_RE)
          if(strippedFields[11] == 0)  # Looks to be 0-based, half-open
            strippedFields[11] = 1     # Now it's 1-based, fully closed
          end
        end
        # Normalize tstart < tend
        strippedFields[10] = [strippedFields[10].to_i, strippedFields[11].to_i].min
        strippedFields[11] = [strippedFields[10].to_i, strippedFields[11].to_i].max
      end
      # Check query name matches ID ok
      unless(strippedFields[1] =~ MATCH_ALL_RE)
        retVal << "the base query name can't be determined."
        retVal << "query names should look like <name> or <name>.<ver>"
        retVal << "in latter case, the \".<ver>\" will be stripped off"
      end
      # Check if any fields are empty that shouldn't be.
      anyEmpty = false
      fields.each_with_index { |field, ii|
        if(field.strip =~ BLANK_RE)
          anyEmpty = true unless(ii==12 or ii=13)
          break
        elsif(field.strip =~ DOT_RE and (ii != 8) and (ii != 7))
          fields[ii] = nil
        end
      }
      if(anyEmpty) then retVal <<  "some of the fields are empty and this is not allowed." end
    end
    if(retVal.empty?)  # everything ok
      fields = strippedFields
      return true
    else
      return retVal
    end
  end

  # * *Function*: Sorts the array of LFF record IDs if @doSort is set. Sorting is
  #   by refSeq name and then by start position. It is not a huge waste of
  #   time to unnecessarily sort already sorted data.
  # * *Usage*   : <tt>  merger.sortLFFRecordIDs()  </tt>
  # * *Args*    :
  #   - +none+
  # * *Returns* :
  #   - +none+
  # * *Throws* :
  #   - +none+
  # --------------------------------------------------------------------------
  def sortLFFRecords(lffRecords)
    # Sort data for each target ref sequence
    lffRecords.keys.each { |targID|
      # Sort data for each track name on this target
      lffRecords[targID].keys.each { |trackName|
        lffRecords[targID][trackName].sort! { |record1, record2|
          compareVal = (record1[RSTART] <=> record2[RSTART])
          if(compareVal == 0)  # Tie. Resolve by the end of the annotation
            compareVal = (record1[REND] <=> record2[REND])
            if(compareVal == 0 and (record1[TSTART] !~ DOT_RE) and (record2[TSTART] !~ DOT_RE)) # Tie. Resolve by the start of annotation in the query
              compareVal = (record1[TSTART] <=> record2[TSTART])
              if(compareVal == 0 and (record1[TEND] !~ DOT_RE) and (record2[TEND] !~ DOT_RE))  # Tie. Resolve by the end of annotation in the query
                compareVal = (record1[TEND] <=> record2[TEND])
                if(compareVal == 0)    # Tie. Resolve by higher score
                  compareVal = (record2[SCORE] <=> record1[SCORE])
                  if(compareVal == 0)  # Tie. Resolve by lexico query name
                    compareVal = (record1[TNAME] <=> record2[TNAME])
                    if(compareVal == 0)  # Tie. So sensibe resolution. Do it by string hash val.
                      compareVal = (record1.to_s.hash <=> record2.to_s.hash)
                    end
                  end
                end
              end
            end
          # else, no tie resolution necessary
          end
          compareVal
        }
      }
    }
    return lffRecords
  end

  class GenboreeUtil
    #---------------------------------------------------------------------------
    # * *Function*: Returns database connection object, default connection to 'genboree'
    #
    # * *Usage*   : <tt> GenboreeUtil.connect( 'some_annot_dbname' ) </tt>
    # * *Args*    :
    #   - +annot+ -> Optional.  Default connects to 'genboree', otherwise connects to database specified here
    # * *Returns* :
    #   - +connection+ -> Return connection object created from DBUtil
    # * *Throws* :
    #   - +none+
    #---------------------------------------------------------------------------
    def self.connect(annot=nil)
      dbrc_file = ENV['DB_ACCESS_FILE'].dup.untaint
      genbConfig = BRL::Genboree::GenboreeConfig.new()
      genbConfig.loadConfigFile()
      return BRL::Genboree::DBUtil.new( genbConfig.dbrcKey, annot, dbrc_file )
    end

    def self.getSuperuserDbrc(genbConf=nil, dbrcFile=nil, dbrcRecType=:api)
      dbrc = nil
      genbConf = BRL::Genboree::GenboreeConfig.load() unless(genbConf)
      if(dbrcFile.nil? or !File.exist?(File.expand_path(dbrcFile)) or !File.readable?(File.expand_path(dbrcFile))) # Then not provided or provided one no good.
        # First, try genbConf
        dbrcFile = genbConf.dbrcFile
        if(dbrcFile.nil? or !File.exist?(File.expand_path(dbrcFile)) or !File.readable?(File.expand_path(dbrcFile))) # Not set right in conf
          # Try standard ENV['DBRC_FILE'] variable
          dbrcFile = ENV['DBRC_FILE']
          if(dbrcFile.nil? or !File.exist?(File.expand_path(dbrcFile)) or !File.readable?(File.expand_path(dbrcFile))) # Not set
            # Try old standard ENV['DB_ACCESS_FILE'] variable
            dbrcFile = ENV['DB_ACCESS_FILE']
            if(dbrcFile.nil? or !File.exist?(File.expand_path(dbrcFile)) or !File.readable?(File.expand_path(dbrcFile))) # Not set
              # Try home directory?
              dbrcFile = File.expand_path('~/.dbrc')
            else
              dbrcFile = nil
            end
          end
        end
      end
      # Create dbrc rec
      if(dbrcFile)
        localHostName = genbConf.machineName
        dbrc = BRL::DB::DBRC.new(dbrcFile, "#{dbrcRecType.to_s.upcase}:#{localHostName}")
      end
      return dbrc
    end

    # Get hash of groups->databases->tracks for userId
    def self.getGroupsDatabasesTracksForUser(userId, templateVersion=nil)
      dbu = nil
      t0 = Time.now
      retVal = Hash.new {|hh,groupName| hh[groupName] = Hash.new { |gg, refseqName| gg[refseqName] = Hash.new { |ll, trackName| ll[trackName] = true } } }
      begin
        dbu = BRL::Genboree::GenboreeUtil.connect()
        # Get the table of groups and databases for this user
        resultSet = dbu.getGroupsDbsByUserIdAndTemplateVersion(userId, templateVersion)
        # Go through each record in the table, connect to the database, and add the info
        gdtRow = groupName = refseqName = databaseName = ftypes = ftypeRow = nil
        resultSet.each { |gdtRow|
          groupName = gdtRow['groupName']
          refseqName= gdtRow['refseqName']
          refSeqId = gdtRow['refSeqId']
          # Get real db name from the user's db name
          databaseName = gdtRow['databaseName']
          # Connect to that database so we can get all the tracks
          dbu.setNewDataDb(databaseName)
          # Get the ftypeIds for tracks the user has access to    #
          begin
            #accessibleTrackIds = BRL::Genboree::GenboreeDBHelper.getAccessibleTrackIds(refSeqId, userId, true, dbu)
            accessibleTracks = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(refSeqId, userId, true, @@dbu)
            accessibleTracks.each_key { |trackName|
              retVal[groupName][refseqName][trackName] = true
            }
          rescue => innerErr
            $stderr.puts "GenboreeUtil#getGroupsDatabasesTracksForUser() => inner error while getting group->database->track list for user id '#{userId}' (probably missing database on host). Will try to continue"
            $stderr.puts innerErr
            $stderr.puts innerErr.backtrace.join("\n")
          end
        }
        # $stderr.puts "#{'%'*60}\n#{retVal.inspect}\n#{'%'*60}"
      rescue => err
        $stderr.puts "GenboreeUtil#getGroupsDatabasesTracksForUser() => error while getting group->database->track list for user id '#{userId}'"
        $stderr.puts err
        $stderr.puts err.backtrace.join("\n")
      ensure
        unless(dbu.nil?)
          dbu.clearCaches()
          dbu.clear()
          dbu = nil
        end
      end
      $stderr.puts "GenboreeUtil#getGroupsDatabasesTracksForUser() => TOTAL TIME #{Time.now-t0} sec to get all groups->databases->tracks for userId '#{userId}'"
      return retVal
    end

    def self.getTemplateVersionByRefSeqId(refSeqId)
      retVal = nil
      begin
        dbu = BRL::Genboree::GenboreeUtil.connect()
        # Get the table of groups and databases for this user
        resultSet = dbu.selectTemplateVersionByRefSeqID(refSeqId)
        retVal = resultSet.first[0] unless(resultSet.nil? or resultSet.empty?)
      rescue => err
        $stderr.puts "GenboreeUtil#getTemplateVersionByRefSeqId() => error while getting genome template for refSeqId '#{refSeqId}'"
        $stderr.puts err.backtrace.join("\n")
      ensure
        dbu.clear() unless(dbu.nil?)
      end
      return retVal
    end

    # Log error in noticeable way
    def self.logError(msg, err=nil, *vars)
      $stderr.puts "-"*50 + "\n#{Time.now}"
      $stderr.puts msg
      unless(err.nil?)
        $stderr.puts err
        $stderr.puts err.backtrace.join("\n")
      end
      unless(vars.nil? or vars.empty?)
        $stderr.puts "Vars:"
        vars.each { |var| $stderr.puts "  - #{var.respond_to?(:pretty_inspect) ? var.pretty_inspect : var}" }
      end
      $stderr.puts "-"*50
      return
    end
  end

  # Class used for standardizing errors in Genboree.
  class GenboreeError < RuntimeError
    # The type of error, Use valid http status names if the error is going to be handled by API framework.
    attr_accessor :type
    # The short message giving some detail about the error.
    attr_accessor :message
    # The exception or error object the is caught [optional]
    attr_accessor :error
    # Flag indicating whether to write the error to stderr [optional]
    attr_accessor :logError

    def initialize(type, message, error=nil, logError=false)
      @type, @message, @error, @logError = type, message, error, logError
      set_backtrace( (caller[1,caller.size] || []) )
      if(@logError)
        BRL::Genboree::GenboreeUtil.logError("GenboreeError: type: #{type} msg: #{message}", @error)
      end
    end
  end
end ; end
