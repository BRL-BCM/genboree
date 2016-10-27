#!/usr/bin/env ruby

# ##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
# ##############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'

# ##############################################################################
# NAMESPACE
# - a.k.a. 'module'
# - This is standard and matches the directory location + "Tool"
# - //brl-depot/.../brl/genboree/toolPlugins/tools/tiler/
# ##############################################################################
module BRL ; module Genboree ; module ToolPlugins ; module Tools ; module TilerTool

  # ##############################################################################
  # HELPER CLASSES
  # ##############################################################################
  TileNameTracker = Struct.new(:annoCount, :tileCount)
  
  # ##############################################################################
  # EXECUTION CLASS
  # ##############################################################################
  class LFFTiler
    # Accessors (getters/setters ; instance variables
    attr_accessor :lffInFile, :maxAnnoSize, :tileSize, :outputType
    attr_accessor :outputSubtype, :tileOverlap, :overlapAsBp, :excludeUnsplitAnnos
    
    # Required: the "new()" equivalent
    def initialize(optsHash=nil)
      self.config(optsHash) unless(optsHash.nil?)
    end
    
    # ---------------------------------------------------------------
    # HELPER METHODS
    # - set up, do specific parts of the tool, etc
    # ---------------------------------------------------------------
    
    # Method to handle tool configuration/validation
    def config(optsHash)
      @lffInFile = optsHash['--lffFile'].strip
      @maxAnnoSize = optsHash['--maxAnnoSize'].to_i
      @tileSize = optsHash.key?('--tileSize') ? optsHash['--tileSize'].to_i : @maxAnnoSize
      @outputType = optsHash['--outputType'].strip.gsub(/\\"/, "'") # '
      @outputSubtype = optsHash['--outputSubtype'].strip.gsub(/\\"/, "'") # '
      @outputClass = optsHash.key?('--outputClass') ? optsHash['--outputClass'].gsub(/\\"/, "'")  : 'Tiles' # '
      @tileOverlap = optsHash.key?('--tileOverlap') ? optsHash['--tileOverlap'].to_f : 50.0
      @minTileSize = optsHash.key?('--minTileSize') ? optsHash['--minTileSize'].to_i : @tileSize
      @overlapAsBp = optsHash.key?('--overlapAsBp')
      @doStripVerNum = optsHash.key?('--stripVerNum')
      @doUniqueTileNames = optsHash.key?('--uniqTileNames')
      @excludeUntiledAnnos = optsHash.key?('--excludeUntiledAnnos')
      @leftAnnoPad = optsHash.key?('--leftAnnoPad') ? optsHash['--leftAnnoPad'].to_i : 0
      @rightAnnoPad = optsHash.key?('--rightAnnoPad') ? optsHash['--rightAnnoPad'].to_i : 0
      
      @tilesLffFile = "#{lffInFile}.tiles.lff"
      @tiledLffFile = "#{lffInFile}.tiled.lff"
      @untiledLffFile = "#{lffInFile}.untiled.lff"
      
      if(@maxAnnoSize < 0)
        raise "\n\nERROR: the maximum annotation size must be a positive integer.\n"
      end
      if(@overlapAsBp)
        if(@tileOverlap >= @maxAnnoSize)
          raise "\n\nERROR: tiles being larger than the maximum annotation size doesn't make sense!\n"
        end
      else # as %
        if(@tileOverlap >= 100.0)
          raise "\n\nERROR: tile overlap cannot be 100.0% or larger!\n"
        end
        @tileOverlap /= 100.0
      end
      $stderr.puts "#{Time.now} PARAMS:\n  - lffInFile => #{@lffInFile}\n  - maxAnnoSize => #{@maxAnnoSize}\n  - tileSize => #{@tileSize}\n  - outputType => #{@outputType}\n  - outputSubtype => #{@outputSubtype}\n  - typeOverlap => #{@tileOverlap}\n  - minTileSize => #{@minTileSize}\n  - overlapAsBp => #{@overlapAsBp}\n  - doStripVerNum => #{@doStripVerNum}\n  - doUniqueTileName => #{@doUniqueTileNames}\n  - excludeUntiledAnnos => #{@excludeUntiledAnnos}\n  - tilesLffFile => #{@tilesLffFile}\n  - tiledLffFile => #{@tiledLffFile}\n  - untiledLffFile => #{@untiledLffFile}\n\n"
    end
    
    # Tiles a single LFF record.
    def tileAnno(lffArray)
      annoWasTiled = false
      origName = lffArray[1]
      currAnnoCount = (@tileNameHash[origName].annoCount += 1)
      lffArray[1] = "#{lffArray[1].strip}_#{currAnnoCount}" if(@doUniqueTileNames)
      # Simple case: tiling not needed (anno is already a 'tile')
      if( (lffArray[6].to_i - lffArray[5].to_i).abs <= @maxAnnoSize )
        currTileCount = (@tileNameHash[lffArray[1]].tileCount += 1)
        lffArray[1] = "#{lffArray[1].strip}.#{currTileCount}"
        lffStr = lffArray.join("\t")
        @tilesWriter.puts lffStr unless(@excludeUntiledAnnos)
        annoWasTiles = false
      else # Else the anno is large and we need to tile it
        annoWasTiled = true
        currTileArray = lffArray.dup
        lffStart = currTileArray[5].to_i
        lffStop = currTileArray[6].to_i
        lffStart, lffStop = lffStop, lffStart if(lffStart > lffStop)
        currTileStart = lffStart
        startStopArray = nil
        currSize = (lffStop - lffStart).abs + 1
        while(currSize > @maxAnnoSize)
          currTileCount = (@tileNameHash[origName].tileCount += 1)
          # Calc & output current tile
          currTileStop = currTileStart + @tileSize - 1
          currTileSize = (currTileStop - currTileStart).abs + 1
          # Figure out the end of the tile (respecting minTileSize)
          if(currTileStop > lffStop) # then we have to consider options for this last tile
            # try using lffStop as the tile stop
            altTileStop = lffStop
            altTileSize = (altTileStop - currTileStart).abs + 1
            if(altTileSize < @minTileSize) # too small
              # try using just the min tile size
              altTileStop = currTileStart + @minTileSize - 1
              altTileSize = (altTileStop - currTileStart).abs + 1
              if(altTileSize >= @minTileSize) # this size is ok
                currTileStop = altTileStop
                currTileSize = altTileSize
              end
            else # size is ok
              currTileStop = altTileStop
              currTileSize = altTileSize
            end
          end
          currTileArray[5] = currTileStart
          currTileArray[6] = currTileStop
          currTileArray[1] = "#{lffArray[1].strip}.#{currTileCount}"
          @tilesWriter.puts currTileArray.join("\t")
          
          # Get start for next tile
          if(@overlapAsBp)
            currTileStart = (currTileStop - @tileOverlap + 1).to_i
          else # as %
            currTileStart = (currTileStop - (currTileSize * @tileOverlap).round + 1).to_i
          end
          currTileStart = lffStart if(currTileStart < lffStart)
          currSize = (lffStop - currTileStart) + 1
        end
        # Output any remainder annotation tile (i.e. likely a partial tile)
        if(currSize > 0)
          currTileCount = (@tileNameHash[origName].tileCount += 1)
          currTileArray[5] = currTileStart
          currTileArray[6] = currTileArray[5] + @tileSize - 1
          currTileSize = (currTileArray[6] - currTileArray[5]).abs + 1
          # Figure out the end of the tile (respecting minTileSize)
          if(currTileArray[6] > lffStop) # then we have to consider options for this last tile
            # try using lffStop as the tile stop
            altTileStop = lffStop
            altTileSize = (altTileStop - currTileArray[5]).abs + 1
            if(altTileSize < @minTileSize) # too small
              # try using just the min tile size
              altTileStop = currTileStart + @minTileSize - 1
              altTileSize = (altTileStop - currTileArray[5]).abs + 1
              if(altTileSize >= @minTileSize) # this size is ok
                currTileArray[6] = altTileStop
                currTileSize = altTileSize
              end
            else # size is ok
              currTileArray[6] = altTileStop
              currTileSize = altTileSize
            end
          end          
          currTileArray[1] = "#{lffArray[1].strip}.#{currTileCount}"
          @tilesWriter.puts currTileArray.join("\t")
        end
      end
      return annoWasTiled
    end
    
    # ---------------------------------------------------------------
    # MAIN EXECUTION METHOD
    # - instance method called to "do the tool"
    # ---------------------------------------------------------------
    # Tiles all LFF records in LFF file.
    def tileAnnos()
      @tileNameHash = Hash.new {|hh,kk| hh[kk] = TileNameTracker.new(0,0) }
      @tilesWriter = BRL::Util::TextWriter.new(@tilesLffFile)
      @tiledWriter = BRL::Util::TextWriter.new(@tiledLffFile)
      @untiledWriter = BRL::Util::TextWriter.new(@untiledLffFile)
      reader = BRL::Util::TextReader.new(@lffInFile)
      reader.each { |line|
        lffArray = line.strip.split(/\t/)
        next if( lffArray.length < 10 or lffArray =~ /^\s*[#\[]/ )
        # Fix the name?
        lffArray[1].gsub!(/\.\d+$/, '') if(@doStripVerNum)
        origClass, origType, origSubtype = lffArray[0], lffArray[2], lffArray[3]
        lffArray[0], lffArray[2], lffArray[3] = @outputClass, @outputType, @outputSubtype
        # Apply paddings
        lffArray[5] = lffArray[5].to_i - @leftAnnoPad
        lffArray[5] = 1 if(lffArray[5] < 1)
        lffArray[6] = lffArray[6].to_i + @rightAnnoPad
        annoWasTiled = tileAnno(lffArray)
        lffArray[0], lffArray[2], lffArray[3] = origClass, origType, origSubtype
        if(annoWasTiled)
          @tiledWriter.puts lffArray.join("\t")
        else # not tiled
          @untiledWriter.puts lffArray.join("\t")
        end
      }
      reader.close()
      @tilesWriter.close()
      @tiledWriter.close()
      @untiledWriter.close()
      return BRL::Genboree::OK
    end
    
    # ---------------------------------------------------------------
    # CLASS METHODS
    # - generally just 2 (arg processor and usage)
    # ---------------------------------------------------------------
    # Process command-line args using POSIX standard
    def LFFTiler.processArguments()
      # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--maxAnnoSize', '-m', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputType', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputSubtype', '-u', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputClass', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--tileSize', '-s', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--tileOverlap', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--minTileSize', '-n', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--leftAnnoPad', '-5', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--rightAnnoPad', '-3', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--excludeUntiledAnnos', '-i', GetoptLong::NO_ARGUMENT],
                    ['--stripVerNum', '-v', GetoptLong::NO_ARGUMENT],
                    ['--uniqTileNames', '-q', GetoptLong::NO_ARGUMENT],
                    ['--overlapAsBp', '-l', GetoptLong::NO_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      LFFTiler.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      LFFTiler.usage() if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end
  
    # Display usage info and quit.
    def LFFTiler.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "
  
  PROGRAM DESCRIPTION:
    
    Tiles across large annotations in the source LFF file according to the
    parameters provided. Untiled (i.e. 'short') annotations can be included in
    the output by default or excluded.
    
    Sensible defaults set the tile size to match the maxAnnoSize and to use
    50% overlap between tilings. These can be overridden.
    
    Creates three output files, based on the LFF file but with these extensions:
      .tiles.lff     => Main output. The created tiles and the 'short' untiled
                        annotations if desired.
      .tiled.lff     => The 'long' annotations that were tiled.
      .untiled.lff   => The 'short' annotations that were not tiled.
    
    NOTES:
    --stripVerNum will remove any .1, .2, .3, etc from the annotation name
    before tiling. These numbers are often used to indicate splice variants.
    Removing them will cause cause any tiles produced to be based on the
    annotation name *without* the version number which can be useful for
    meaningful tile names, especially if the --uniqTileNames option is used.
    This option is applied BEFORE --uniqTileNames.
    
    --uniqTileNames ensures that the names of tiles are based on the the
    source annotation, but will have a unique count added on the end so that
    each tile has a unique name. This is sometimes useful for meaningful tile
    names. This option will ALSO name tiles in order if the source annotation
    names are the same. The tile names will look like:
      annoName_2_3
    where 'annoName' is the source annotation's name, the '2' indicates the 2nd
    annotation within the annoName group is being tiled and '3' indicates the
    third tile. This option will ALSO name *untiled* source annotations unless
    --exlcudeUntiledAnnos is specified (each  will be annoName_X_1, where X is
    the Xth annotation with that name).
    
    FINAL NOTE: the above options work on the order of the annotations IN THE
    FILE; the first encountered annotation within a group is '1', regardless of
    chr, strand, or coordinate. If you want sensible things, it might be wise to
    sort the file to your liking first. For example, by chr and then start and
    then stop; or perhaps sorting - strand annotation groups (eg genes) in
    reverse.    
    
    COMMAND LINE ARGUMENTS:
      --lffFile             | -f  => Source LFF file.
      --maxAnnoSize         | -m  => Maximum annotation size over which tiling
                                     will occur.
      --outputType          | -t  => The output track's 'type'.
      --outputSubtype       | -u  => The output track's 'subtype'.
      --outputClass         | -c  => [Optional] The output track's 'class'.
                                     Defaults to 'Tiles'.
      --tileSize            | -s  => [Optional] Overrides the size of the tiles to
                                     be something other than the maxAnnoSize.
      --tileOverlap         | -o  => [Optional] Overlap of each tile with the
                                     next. Default is 50.0 for 50% overlap.
      --minTileSize         | -n  => [Optional] Set this to specify the minimum
                                     tile size to cover the end of the template
                                     (eg the last 2 bases, say). Default is
                                     'tileSize' if set, else 'maxAnnoSize' so
                                     that all tiles are the SAME size.
      --overlapAsBp         | -l  => [Optional flag] Use overlap number as a
                                     number of base pairs rather than a %.
      --stripVerNum         | -v  => [Optional] Remove .1, .2, .3, etc from the
                                     annotation names prior to tiling.
      --uniqTileNames       | -q  => [Optional] Use Xth annotation within group
                                     and Yth tile for that Xth annotation to
                                     make unique tile names like 'annoName_X_Y'.
      --leftAnnoPad         | -5  => [Optional] Before tiling and even before
                                     *deciding* to tile or not, pre-pad the left
                                     (5') side of the annotation.
      --rightAnnoPad        | -3  => [Optional] Before tiling and even before
                                     *deciding* to tile or not, pre-pad the
                                     right (3') side of the annotation.
      --excludeUntiledAnnos | -i  => [Optional flag] Should untiled ('short')
                                     annotations be excluded in the output. This
                                     makes the output *only* tiles, instead of the
                                     default of outputing both tiles and
                                     acceptable-length annotations.
      --help                | -h  => [Optional flag]. Print help info and exit.
  
    USAGE:
    lffTiler -f myLFF.lff -m 1000 -t Exons -u Tiled > myLFF.tiled.lff
    
  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def LFFTiler.usage(msg='')
  end # class LFFTiler
end ; end ; end ; end ; end # namespace

# ##############################################################################
# MAIN
# ##############################################################################
begin
  # Get arguments hash
  optsHash = BRL::Genboree::ToolPlugins::Tools::TilerTool::LFFTiler.processArguments()
  $stderr.puts "#{Time.now()} TILER - STARTING"
  # Instantiate method
  tiler =  BRL::Genboree::ToolPlugins::Tools::TilerTool::LFFTiler.new(optsHash)
  $stderr.puts "#{Time.now()} TILER - INITIALIZED"
  # Execute tool
  exitVal = tiler.tileAnnos()
rescue Exception => err # Standard capture-log-report handling:
  errTitle =  "#{Time.now()} TILER - FATAL ERROR: The tiler exited without processing all the data, due to a fatal error.\n"
  msgTitle =  "FATAL ERROR: The tiler exited without processing all the data, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
  errstr   =  "   The error message was: '#{err.message}'.\n"
  errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
  puts msgTitle
  $stderr.puts errTitle + errstr
  exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} TILER - DONE" unless(exitVal != 0)
exit(exitVal)
                                                                                                                                                          