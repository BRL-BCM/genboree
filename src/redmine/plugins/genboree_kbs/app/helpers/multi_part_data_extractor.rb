
class MultiPartDataExtractor
  # How much of file to examine in each tick?
  CHUNK_SIZE = (32 * 1024)
  # How much context to keep from chunk to chunk when looking for disposition headers?
  #   This is necessarily longer than the mount typically kept which is computed dynamically from the boundary length.
  KEEP_SIZE_HEADER = 256

  # @return [boolean] Was the indicated multipart section found? This means
  #   (a) we found the multipart boundary, (b) we found the correct disposition line, (c) we found the blank line
  #   separating headers from data, and (d) we found the boundary that marks the end of the data.
  attr_reader :multipartFound
  # @return [String,nil] IF the appropraite disposition line was found AND it had a 'filename=""' attribute,
  #   then the value of that filename attribute is exposed here.
  attr_reader :formFileName
  attr_accessor :io

  
  def initialize(io, args)
    $stderr.puts "STATUS: CUSTOM CONSTRUCTOR CALLED BY EM: args:\n  #{args.inspect}"
    # Context args
    @io = io
    @boundary = args[:boundary]
    @formDataName = args[:formDataName]
    @outFileName = args[:outFileName]
    @chunkSize = (args[:chunkSize] or CHUNK_SIZE)
    @callbkObj = args[:callbkObj] # This is called once the file has been extracted. 
    # Some sanity checks etc before get too far:
    @boundary = @boundary.to_s.strip
    @formDataName = @formDataName.to_s.strip
    @chunkSize = @chunkSize.to_i
    if(@boundary and @boundary =~ /\S/)
      @boundaryRE = /(?:\r\n|^)#{Regexp.escape(@boundary)}/
      @boundarySize = @boundary.size
      @boundaryStopRE = /\r\n#{Regexp.escape(@boundary)}\-\-/
      # From iteration to iteration, we keep enough buffer to contain a full boundard stop/terminate sequence.
      #   Thus we will not miss a boundary (or terminator) if chunking cuts it.
      @keepSize = @boundary.size + 3
      # Min chunk size is thus dictated by this, regardless of arguments.
      @chunkSize = @keepSize unless(@chunkSize > @keepSize)
    else
      raise ArgumentError, "Missing or empty :boundary value!"
    end
    raise ArgumentError, "Missing or empty :formDataName value!" unless(@formDataName and @formDataName =~ /\S/)
    raise ArgumentError, "Missing or empty :outFileName value!" unless(@outFileName and @outFileName =~ /\S/)
    raise ArgumentError, "Chunk size cannot be less than #{KEEP_SIZE_HEADER}!" unless(@chunkSize >= KEEP_SIZE_HEADER)
    # Regex for finding form data name
    @formDataNameRE = /^(Content-Disposition.+name\s*=\s*"#{Regexp.escape(@formDataName)}"[^\r\n]*)\r\n/
    # Output file for data
    @dataOutFile = File.open(@outFileName, "w+")
    # Buffer to examine
    @buff = ''
    # Position of 1st buffer byte in file
    @buffPos = 0
    # Location of relevant data
    @dataFileStart, @dataFileEnd = nil, nil
    # Scan mode
    @phase = :findBoundary
    # We set multipartFound to true when we've gound the correct section (still may have 0 data bytes, but that's allowed)
    @multipartFound = false
    # IF the Content-disposition line for the relevant multipart has a "filename=''", the value will be here.
    @formFileName = nil
    $stderr.puts "  - Init state:\n    . @keepSize, @chunkSize = #{@keepSize.inspect}, #{@chunkSize.inspect}\n    . @boundaryRE = #{@boundaryRE.source}\n    . @boundaryStopRE = #{@boundaryStopRE.source}\n    . @formDataNameRE = #{@formDataNameRE.source}"
    $stderr.puts "-"*60
  end

  # ------------------------------------------------------------------
  # STATE HANDLERS
  # - Each state is a method
  # - The return value in each case is a Symbol specifying the next state.
  #   . Yes, even for self->self transitions.
  #   . Yes, Rubyists would do self.call(nextStateSymbol). Meh, I use a dispatcher.
  # - Successful state transition path is [only]:
  #     findBoundary -> findName -> findHeadersEnd -> findEndOfData -> saveData -> done
  #   . This transition path must be exercised as some point as file is examined.
  #   . If "done" (the terminal state) is reached by any other path, it's due to some failure
  #     when scanning the [possibly corrupt/incorrect/incomplete] multipart file.
  # ------------------------------------------------------------------

  # Run next transition (dispatcher). One phase == one EM tick. EM effectively ends up
  #   calling this, which does the 1 next transition, and notes the next transition before
  #   returning back to EM.
  # @return [Symbol] The next transition.
  def runPhase()
    retVal = case @phase
      when :findBoundary
        findBoundary()
      when :findName
        findName()
      when :findHeadersEnd
        findHeadersEnd()
      when :findEndOfData
        findEndOfData()
      when :saveData
        saveData()
      else
        :done
    end
    return retVal
  end

  # STATE: Find start-of-multipart via boundary
  #  Next States: :findBoundary [self], :findName, :done
  def findBoundary()
    #$stderr.puts "  OK. BOUNDARY: Find multipart start boundary ( io pos: #{@io.pos} ; buffPos: #{@buffPos} ; buff size: #{@buff.size} )"
    retVal = :findBoundary
    # Look for boundary in buffer
    bBuffIdx = @buff.index(@boundaryRE)
    # Look for the stop/terminate boundary in buffer
    sBuffIdx = @buff.index(@boundaryStopRE)
    # Did we see the boundary?
    if(bBuffIdx)
      # Must not be because we saw the terminator boundary at this position.
      #   - Must be before any terminator or no terminator see at all.
      if(sBuffIdx.nil? or bBuffIdx < sBuffIdx)
        # Start of boundary in file:
        bFilePos = bBuffIdx + @buffPos
        # Next line after boundary in file (\r\n line endings remember):
        nlFilePos = bFilePos + @boundarySize + 2
        # Now arrange to look for form field name starting at this pos in the file
        keepSomeBuffer(0, nlFilePos)
        @io.seek(nlFilePos, File::SEEK_SET)
        $stderr.puts "    - OK. FOUND! at buff pos: #{bFilePos.inspect} ; next line file pos: #{nlFilePos.inspect}"
        retVal = :findName
      else # bBuffIdx == sBuffIdx probably ... anyway, terminate since we don't look past this
        $stderr.puts "    - FAIL. SAW TERMINATOR! all done looking (not found?? MISSING boundary)"
        @dataFileStart = @dataFileEnd = nil
        retVal = :done
      end
    else # didn't see boundary, arrange to keep looking
      keepSomeBuffer(@keepSize)
      retVal = :findBoundary
    end
    return retVal
  end

  # STATE: Find Content-Disposition line within current multipart
  #  Next States: :findName[self], :findHeadersEnd, :findBoundary, :done
  def findName()
    #$stderr.puts "  OK. NAME: Find relevant content-disposition line. ( io pos: #{@io.pos} ; buffPos: #{@buffPos} ; buff size: #{@buff.size} )"
    retVal = :findName
    lookToNextMultipart = false
    # Look for name="{form_widget_id}" as it were
    nBuffIdx = @buff.index(@formDataNameRE)
    matchString = $1
    # Look for the blank line that separates multipart headers from the multipart's data
    sBuffIdx1 = @buff.index(/\r\n\r\n/)
    # Look for the stop/terminate boundary in buffer
    sBuffIdx2 = @buff.index(@boundaryStopRE)
    # Did we see the form data name of interest?
    if(nBuffIdx)
      # Must not be that we saw terminator before form data name line
      if(sBuffIdx2.nil? or nBuffIdx < sBuffIdx2)
        # Must not be because we saw the blank line FIRST and the header after (in some other multipart or something)
        if(sBuffIdx1.nil? or nBuffIdx < sBuffIdx1)
          # Start of form field name line in file:
          nFilePos = nBuffIdx + @buffPos
          # Now arrange to look for blank line that separates multipart headers from multipart's data
          keepSomeBuffer(0, nFilePos)
          @io.seek(nFilePos, File::SEEK_SET)
          # Try to extract the filename="" value, if present
          if(matchString)
            matchString =~ /filename\s*=\s*"([^\r\n"]+)"/
            @formFileName = $1
          end
          $stderr.puts "    - OK. FOUND! at buff pos: #{nBuffIdx.inspect} ; filename = #{@formFileName.inspect} ; start header end search here: #{nFilePos.inspect}"
          retVal = :findHeadersEnd
        else # saw blank line before the form field name line of interest
          # So not the right mulitpart...find next one (which we're pretty sure is in the buffer currently, yeah?)
          lookToNextMultipart = true
        end
      else
        $stderr.puts "    - FAIL. SAW TERMINATOR! all done looking (not found or corrupt?? MISSING content disposition line of interest)"
        @dataFileStart = @dataFileEnd = nil
        retVal = :done
      end
    elsif(sBuffIdx1) # Didn't find line of interest, but found blank line that separates multipart headers from multipart's data
      # So not the right multipart...find next one.
      lookToNextMultipart = true
    elsif(sBuffIdx2)
      $stderr.puts "    - FAIL. SAW TERMINATOR! all done looking (not found or corrupt?? MISSING content disposition line of interest)"
      @dataFileStart = @dataFileEnd = nil
      retVal = :done
    else # didn't see form field name or blank line that separates multipart headers from multipart's data
      # We need to keep more than usual due to potentially long Content-Disposition line
      keepSomeBuffer(KEEP_SIZE_HEADER)
      retVal = :findName
    end

    # We saw a blank line before finding the form data name line of interest. Move to next multipart.
    if(lookToNextMultipart)
      # Can start from where we found the blank line
      sFilePos = sBuffIdx1 + @buffPos + 4
      # Arrange to look for next multipart, since this is not the one we want
      keepSomeBuffer(0, sFilePos)
      @io.seek(sFilePos, File::SEEK_SET)
      $stderr.puts "    - OK. WRONG MULTIPART! hit blank line first, search for next multipart starting at #{sFilePos.inspect}"
      retVal = :findBoundary
    end

    return retVal
  end

  # STATE: Find end of current multipart's headers (and thus start of data)
  #  Next States: :findHeadersEnd [self], :findEndOfData, :done
  def findHeadersEnd()
    #$stderr.puts "  OK. HEADERS END: Correct multipart. Find its header<->data separator. ( io pos: #{@io.pos} ; buffPos: #{@buffPos} ; buff size: #{@buff.size} )"
    retVal = :findHeadersEnd
    # Look for blank line the indicates end of a multipart's headers
    blBuffIdx = @buff.index(/\r\n\r\n/)
    # Look for the stop/terminate boundary in buffer
    sBuffIdx = @buff.index(@boundaryStopRE)
    # Did we find it?
    if(blBuffIdx)
      # Must not be that we saw terminator before header<->data separator.
      if(sBuffIdx.nil? or blBuffIdx < sBuffIdx)
        # Next line after headers end is beginning of data
        nlFilePos = @buffPos + blBuffIdx + 4
        # This is the start of the data!
        @dataFileStart = nlFilePos
        # Arrandge to start scanning for data end
        keepSomeBuffer(0, nlFilePos)
        @io.seek(nlFilePos, File::SEEK_SET)
        $stderr.puts "    - OK. FOUND! at buff pos: #{blBuffIdx.inspect} ; start end-of-data search here: #{nlFilePos.inspect}"
        @multipartFound = true
        retVal = :findEndOfData
      else
        $stderr.puts "    - FAIL. SAW TERMINATOR! all done looking (not found or corrupt?? MISSING header<->data separator line after multipart headers)"
        @dataFileStart = @dataFileEnd = nil
        retVal = :done
      end
    elsif(sBuffIdx) # Didn't find blank line, but did find terminator; bad multipart? Dunno, but done.
      $stderr.puts "    - FAIL. SAW TERMINATOR! all done looking (not found or corrupt?? MISSING header<->data separator line after multipart headers)"
      @dataFileStart = @dataFileEnd = nil
      retVal = :done
    else # arrange to keep looking
      keepSomeBuffer(@keepSize)
      retVal = :findHeadersEnd
    end

    return retVal
  end

  # STATE: Find end of current multipart's data (i.e. the boundary, preceeded by \r\n)
  #  Next States: :findEndOfData [self], :saveData, :done
  def findEndOfData()
    #$stderr.puts "  OK. END OF DATA: Correct multipart, saw headers. Find end-of-data. ( io pos: #{@io.pos} ; buffPos: #{@buffPos} ; buff size: #{@buff.size} )"
    retVal = :findEndOfData
    # Look for boundary in buffer (could be boundary of next multipart or terminator, don't care)
    bBuffIdx = @buff.index(@boundaryRE)
    # Did we see the boundary?
    if(bBuffIdx)
      # Start of boundary in file:
      bFilePos = @buffPos + bBuffIdx
      # This is the end of relevant multipart's data (byte after the end)!
      @dataFileEnd = bFilePos
      $stderr.puts "    - OK. FOUND! at buff pos: #{bBuffIdx.inspect} ; data start/end = #{@dataFileStart.inspect} / #{@dataFileEnd.inspect}"
      # Arrange to save data
      retVal = :saveData
    else # didn't see boundary, arrange to keep looking
      keepSomeBuffer(@keepSize)
      retVal = :findEndOfData
    end

    return retVal
  end

  # STATE: Use start of data found in findHeadersEnd and end of data found in findEndOfData to save data to file
  #  Next States: :saveData [self], :done
  def saveData()
    #$stderr.puts "  OK. SAVING DATA: Correct multipart, saw headers, know data is from #{@dataFileStart} to #{@dataFileEnd}. ( io pos: #{@io.pos} ; buffPos: #{@buffPos} ; buff size: #{@buff.size} )"
    retVal = :saveData
    if(@dataFileStart.nil? or @dataFileEnd.nil?)
      # Shouldn't have arrived here since this is signal for a :done transition earlier than here. But ok.
      $stderr.puts "  BUG. CAN'T SAVE DATA: null file start and/or end (#{@dataFileStart.inspect}, #{@dataFileEnd.inspect})"
      retVal = :done
    elsif( (@dataFileStart and @dataFileStart < 0) or (@dataFileEnd and @dataFileEnd < 0) )
      raise ArgumentError, "   BUG! file start and/or end indexes have become <0 (#{@dataFileStart.inspect}, #{@dataFileEnd.inspect})"
    else
      if(@dataFileStart >= @dataFileEnd) # mainly for when equal because empty data section
        retVal = :done
      else # need to read & save some data
        # Determine how much to read & save this tick
        readLen = @dataFileEnd - @dataFileStart
        readLen = @chunkSize if(readLen > @chunkSize)

        # Seek to where we're suppose to read from next
        @io.seek(@dataFileStart, File::SEEK_SET)

        # Get and save data
        dataToSave = @io.read(readLen)
        @dataOutFile.write(dataToSave)

        # Determine new dataFileStart (needed to read last chunk properly)
        @dataFileStart = @dataFileStart + readLen

        # Are we done?
        if(@dataFileStart >= @dataFileEnd)
          retVal = :done
        else
          retVal = :saveData
        end
      end
    end

    return retVal
  end

  # ------------------------------------------------------------------
  # HELPERS
  # ------------------------------------------------------------------

  # Arranges to keep some amount of the existing @buff--to ensure we don't miss a key
  #   string that was cut in the middle--according to args. Will *automatically* compute
  #   the new position of the buffer (@@buffPos@) in the file, thus ensuring we ALWAYS
  #   know the offset of the buffer in the underlying file no matter how much of the
  #   previous buffer was kept.
  # @param [Fixnum] keep How much of the current buffer to keep as context. Not <0.
  # @param [Fixnum] knownNewPos Optional and generally ONLY used when @keep@ is 0 ;
  #   gives the KNOWN new seek position for the underlying file. Used when the calling
  #   code wants to simply start reading fresh [after matching a key string probably]
  #   from a know exact file position it determined.
  # @return None.
  def keepSomeBuffer(keep, knownNewPos=nil)
    if(keep < @buff.size) # if "keep same" or "keep more", just leave buffer alone
      if(knownNewPos) # usually used when keep is 0
        @buffPos = knownNewPos
      else
        # Update positon of our [new] buffer in the file based on what we're keeping
        @buffPos += (@buff.size - keep)
      end
      # Keep enough to not miss boundary terminator
      @buff = @buff.slice( (-1 * keep), keep)
    end
  end

  # Called when we need to clean up our resources. Generally when all done scanning our file
  #   (see unbind() which is called automatically when we detach() from watching the IO object)
  #   Or if some rescue block is reached (see notify_readable() which ensures this is called even
  #   on error).
  def clean()
    # Close file being scanned
    unless(@io.nil? or (@io.closed? rescue nil))
      @io.close rescue nil
    end
    # Close output file
    unless(@dataOutFile.nil? or (@dataOutFile.closed? rescue nil))
      @dataOutFile.close rescue nil
    end
  end

  
  def notify_readable()
    #$stderr.puts "in notify_readable" 
    # If we're in saveData mode, it will do it's own chuning as it saves data bytes from the correct multipart.
    # Else we need a new chunk to scan
    if(@phase != :saveData)
      #$stderr.puts "reading chunk..." 
      # Read a chunk
      chunk = @io.read(@chunkSize) rescue nil
      if(chunk and chunk.size > 0)
        # ... Do stuff with line/chunk of data you read (but don't do TOO much)...
        # Add to end of buffer:
        @buff << chunk
        #$stderr.puts "#{Time.now} READ CHUNK: #{chunk.size} bytes ; buff size now: #{@buff.size} ; buff starts at #{@buffPos.inspect}"
        # Execute phase on buffer:
        nextPhase = runPhase()
      else
        # nil or 0-size chunk, EOF assume
        $stderr.puts "#{Time.now} STATUS: EOF. All done searching & saving (if was found)."
        nextPhase = :done
      end
    else # saveData mode does it's own chunking
      nextPhase = runPhase()
    end

    # Keep going or what? If so, what's the next phase of processing?
    if(nextPhase == :done)
      done = true
    else
      @phase = nextPhase
      done = false
    end

    # If we're all done, shutdown. Else arrange to keep a bit of buffer to use with next chunk.
    if(done)
      EM.next_tick {
        unbind()
      }
    else
      keepSomeBuffer(@keepSize)
      EM.next_tick { notify_readable }
    end

    # Prove async file reading via some add_timer calls
    #prove()
  rescue Exception => err # begin-rescue shorthand for this method
    # Look we need to be really sure we shutdown properly if possible. AND, separately that we clean up our stuff.
    $stderr.puts "EXCEPTION IN NOTIFY: #{err.class} => #{err.message.inspect} ; trace:\n#{err.backtrace.join("\n")}"
    clean() rescue nil
    # @to do call back error rescue nil
  end

  # EM INTERFACE. When a watcher detaches from an IO it is watching, EM will eventually call this to help you
  #   arrange clean-up and such
  def unbind()
    $stderr.puts "STATUS: unbinding ; called clean up"
    clean()
    $stderr.puts "STATUS: calling @callbkObj.call()"
    @callbkObj.uploadFile() # return control to calling class which will now do any call back related operations.
  end


  # If you uncomment the prove() call in notify_readable(), this can be used to demostrate that indeed
  #   each phase is run in 1 tick and between phases, EM can arrange to do other things.
  def prove()
    # First, tell EM that the IO object is NOT readable so it WON'T call our notify_readable() handler
    self.notify_readable = false
    EM.add_timer(5) {
      # Arrange for it to become readable in 5 secs so processing can resume
      self.notify_readable = true
    }

    # Arrange for EM to do some other things while multipart processing is paused.
    1.upto(1) { |ii|
      EM.add_timer(ii) {
        unless(notify_readable?)
          $stderr.puts "#{' '*20} (((((( PAUSING (#{ii.inspect}). ...do other stuff...  ))))))"
          $stderr.puts "-"*60
        end
      }
    }
  end
end