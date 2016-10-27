#!/usr/bin/env ruby

require 'cgi'
require 'RMagick'
require 'rvg/rvg'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST
include Magick

module BRL ; module Genboree ; module Graphics

  ####################################################################################
  # This is a utility class with the single task of creating a cytoband image.
  #
  # NOTE: This class leverages the original Cytoband drawing logic from the VGP source
  # (class CytobandDrawingStyle). However, it is separate from that code and has been
  #  modified to provide this functionality. Separate methods have been included from other VGP
  # sources to make this class self-contained. If any defects are found in the drawing
  # code below, it should likely be corrected in the VGP code as well (and vice-versa)
  #
  # [author]Author Michael F Smith, BNI (MFS)
  # [author]Andrew R Jackson, BRL
  # [author]Date 11.20.09
  ####################################################################################
  class CytobandDrawer
    # Struct for anno records with just the cytoband-related info we need
    CytoBandAnno = Struct.new(:gname, :chrom, :start, :stop, :score, :bandType)

    # Some defaults
    HEIGHT = 15
    WIDTH = 300
    DEFAULT_BAND  = "gneg"
    DEFAULT_COLOR = "#CCCCCC"
    # * orientation: a flag denoting drawing orienation 0|'0'|'horz' = horizontal, 1|'1'|'vert' = vertical
    ORIENTATION = 0
    # ARJ: Use these value determine if orientation arg is Horiz or Vert
    HORIZONTAL_VALUES = { 0 => 0, '0' => 0, 'horz' => 0 }
    VERTICAL_VALUES = { 1 => 1, '1' => 1, 'vert' => 1 }
    # ARJ: Pattern used to detect acrocentric chromosome stalks when there is not bandType/gieStain attribute, and thus score is used to determine bandType
    ACRO_SCR_PATTERN = [1.0, -1.0, 1.0, -1.0, -1.0]
    ACRO_PATTERN_REPLACE_BANDS = ['gvar', 'stalk', 'gvar', 'acen']
    # ARJ: Aliases for the 'bandType' attribute, to be searched in order to get the bandType value:
    BAND_TYPE_ALIASES = ['bandType', 'gieStain']
    # ARJ: Aliases for the 'Cyto:Band' track, used to look up probable cytoband tracks (case insensitively) if needed
    CYTOBAND_TRACK_ALIASES = ['cyto:band']
    # Columns we want from fdata when getting our cytoband annos
    ANNO_COLUMNS = [ 'fid', 'gname', 'fstart', 'fstop', 'fscore' ]
    # Minimum arc height to try to draw an arc across. Otherwise, just draw a straight line
    ARC_TOLERANCE = 15
    STALK_INSET_FACTOR = 0.2
    # Map out our banding colors
    BAND_COLORS = {
      "gpos" => "#000000",
      "gpos100" => "#000000",
      "gpos75" => " #444444",
      "gpos66" => "#666666",
      "gpos50" => "#888888",
      "gpos33" => "#AAAAAA",
      "gpos25" => "#CCCCCC",
      "gneg" => "#FFFFFF",
      "gvar" => "#CCCCCC",
      "acen" => "#EEEEEE",
      "stalk" => "#AAAAAA"
    }
    # Map scores to band names, for use as a backup when bandType and gieStain both missing
    SCORES2BANDS = {
      1.0   =>  "gpos100",
      0.75  =>  "gpos75",
      0.66  =>  "gpos66",
      0.5   =>  "gpos50",
      0.33  =>  "gpos33",
      0.25  =>  "gpos25",
      0.0   =>  "gneg",
      -1.0  =>  "acen",
    }

    # Size of pixel margins around the cytoband drawing. Default to 0. Accessors to override.
    attr_accessor :leftMargin
    attr_accessor :rightMargin
    attr_accessor :topMargin
    attr_accessor :bottomMargin

    # CONSTRUCTOR.
    # [+dbu]        A valid DBUtil instance the drawer can use to query the database(s) to look for the cytoband track.
    # [+userDbName+]  Name of the MySQL database containing the user's data. This, and any associated template database,
    #                 will be examined for cytoband-like tracks that can be drawn.
    # [+userId+]    UserId of the Genboree User for whom the drawing will be done. If we have to
    #               go find a cytoband track in the user database (as is the case for createCytobandImageForChrom()),
    #               we will only examine tracks that this user has access to. In the case of createCytobandImageForTrack()
    #               it's assumed the calling code already has done any needed access checks or whatever and simply wants
    #               the given track drawn as a chrom thumbnail.
    # [+genbConf+]  [optional; default=nil] An already-loaded GenboreeConfig object, so we don't have to do unnecessary I/O.
    def initialize(dbu, userDbName, userId, genbConf=nil)
      @dbu = dbu
      @userDbName = userDbName
      @userId = userId
      # Load Genboree Config file if needed
      @genbConf = BRL::Genboree::GenboreeConfig.load() if(genbConf.nil?)
      # Some instance variables used during drawing:
      @rvgGroup = @drawStart = @drawStop = nil
      @drawWidth = WIDTH
      @drawHeight = HEIGHT
      @leftMargin = @rightMargin = @topMargin = @bottomMargin = 0
    end

    #---------------------------------------------------------------------------
    # * *Function*: returns a BLOB of the PNG cytoband image for a given chromosome
    #               This method will make use of the @dbu connection to look for likely
    #               cytoband tracks and use the most likely one. If NO cytoband track candidate
    #               is found, then a whole empty chromosome glyph is drawn.
    #
    # * *Args*    : <tt> CytobandDrawer#createCytobandImage(landmark, drawOpts={}) </tt>
    # [+landmark+]  A landmark String for the region to draw as cytoband image. At a minimum, a chr name is required with the start & stop being optional.
    #               Examples: "chr14", "chr14:450001-540002", "chr14:450000-", "chr14:-678990"
    # [+drawOpts+]  An optional hash with specified drawing parameters. Params include: height, width, orientation
    # [+returns+]   A BLOB (String) of the created PNG formatted cytoband image
    #---------------------------------------------------------------------------
    def createCytobandImageForChrom(landmark, drawOpts={})
      # 1. Look for cytoband-like track
      ftypeHash = findCytobandTrack(@userDbName, @userId)
      # 2. Draw cytoband image using that track
      return createCytobandImageForTrack(landmark, ftypeHash, drawOpts)
    end

    #---------------------------------------------------------------------------
    # * *Function*: returns a BLOB of the PNG cytoband image
    #               This method draws the cytoband thumbnail using the data from the track indicated in
    #               ftypeHash. If there are no annotations for this track in the chromosome (or the region of the chromosome)
    #               then it will be drawn empty.
    #
    # * *Args*    : <tt> CytobandDrawer#createCytobandImage(landmark, ftypeHash, drawOpts={}) </tt>
    # [+landmark+]  A landmark String for the region to draw as cytoband image. At a minimum, a chr name is required with the start & stop being optional.
    #               Examples: "chr14", "chr14:450001-540002", "chr14:450000-", "chr14:-678990"
    # [+ftypeHash+] A Hash representing the track to draw; the Hash is equivalent to an Ftype table record but also containing
    #               a 'dbNames' key whose value is an Array of objects that indicate each database where the track is found
    #               and the corresponding ftypeid of the track within that database. (This is necessary because of user vs template databases).
    #               If nil, then assumes there are no cytoband annos available and will just draw empty thumbnail for landmark.
    # [+drawOpts+]  An optional hash with specified drawing parameters. Params include: height, width, orientation
    # [+returns+]   A BLOB (String) of the created PNG formatted cytoband image
    #---------------------------------------------------------------------------
    def createCytobandImageForTrack(landmark, ftypeHash, drawOpts={})
      # 1. Retrieve indicated cytoband tracks
      # Did we get the right thing in ftypeHash? It's kind of special.
      unless(ftypeHash.nil? or (ftypeHash.is_a?(Hash) and ftypeHash.key?('dbNames')))
        raise ArgumentError.new("ERROR: CytobandDrawer#createCytobandImageForTrack() => ftypeHash arg either isn't a Hash or doesn't have the dbNames key, which is required to query all the databases where we need to annos for the track.")
      end

      # Get our start and stops (from landmark)
      landmark =~ /([^: ]+)\s*(?:\:\s*(\d+))?(?:\:?\s*-\s*(\d+))?/
      @ep, @drawStart, @drawStop = $1, $2, $3     # cases like "chr14" or "chr14:-23559999" and "chr14:123456-" dealt robustly below:
      # Now gather entrypoint info for landmark checking & for downloading the annotations
      @dbu.setNewDataDb(@userDbName)
      frefRows = @dbu.selectFrefsByName(@ep, true)
      if(frefRows.is_a?(Array) and !frefRows.empty?)
        @epLength = frefRows.first['rlength']
        @epRid = frefRows.first['rid']
        # Ensure drawStart is set sensibly
        @drawStart = ((@drawStart.nil? or @drawStart.to_i < 1) ? 1 : @drawStart.to_i)
        # Ensure drawStop is set sensibly
        @drawStop = ((@drawStop.nil? or @drawStop.to_i > @epLength) ? @epLength : @drawStop.to_i)
      else # oh, oh, no such ep?
        raise RuntimeError.new("ERROR: CytobandDrawer#createCytobandImageForTrack() => ERROR: The entrypoint/chromosome [#{@ep.inspect}] specified in the landmark was not found.")
      end

      # Gather annotation records. In addition to several fields of fdata2, we need some specific AVPs as well.
      # - also, we need to get the data across all the databases involved
      # - this will be an Array of CytoBandAnno Structs
      # - note: this method ensure all CytoBandAnnos have something in bandType
      # - if ftypeHash is nil or empty, then allCbAnnoRecords should be empty too...this will draw an empty chrom thumbnail
      if(ftypeHash.nil? or ftypeHash.empty?)
        allCbAnnoRecords = []
      else
        allCbAnnoRecords = getCytobandAnnosFromTrack(ftypeHash)
      end
      # 2. Draw cytoband image
      return createCytobandImage(landmark, allCbAnnoRecords, drawOpts)
    end

    # ------------------------------------------------------------------
    # HELPER METHODS - meant mainly for internal use
    # ------------------------------------------------------------------

    #---------------------------------------------------------------------------
    # * *Function*: Returns an ftypeHash or nil, depending on whether a cytoband-like
    #               track was found or not. Finds cytoband tracks by looking for
    #               each CYTOBAND_TRACK_ALIASES alias in turn.
    #
    # * *Args*    : <tt> CytobandDrawer#findCytobandTrack(userDbName, userId) </tt>
    # [+userDbName+]  Name of the MySQL database containing the user's data. This, and any associated template database,
    #                 will be examined for cytoband-like tracks that can be drawn.
    # [+userId+]    UserId of the Genboree User for whom the drawing will be done. Because we have to
    #               go find a cytoband track in the user database, we will only examine tracks that
    #               this user has access to. This is in contrast to createCytobandImageForTrack() in which it's
    #               assumed the calling code already has done any needed access checks or whatever and simply wants
    #               the given track drawn as a chrom thumbnail.
    # [+returns+]   A Hash is equivalent to an Ftype table record but also containing
    #               a 'dbNames' key whose value is an Array of objects that indicate each database where the track is found
    #               and the corresponding ftypeid of the track within that database. (This is necessary because of user vs template databases)
    #---------------------------------------------------------------------------
    def findCytobandTrack(userDbName, userId)
      @dbu.setNewDataDb(userDbName)
      # Get the refSeqId for userDbName
      refSeqRows = @dbu.selectRefseqByDatabaseName(userDbName)
      if(refSeqRows and !refSeqRows.empty?)
        refSeqId = refSeqRows.first['refSeqId']
      else
        raise ArgumentError.new("ERROR: CytobandDrawer#findCytobandTrack() => couldn't find refseq table rows for '#{userDbName.inspect}' MySQL database name.")
      end

      # Get ftypeHashes for all tracks the user has access to
      ftypeHashes = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(refSeqId, userId, true, @dbu)

      # Go through each CYTOBAND_TRACK_ALIASES alias and looks for a track matching it [case-insensitive]
      ftypeHash = nil
      CYTOBAND_TRACK_ALIASES.each { |cbtAlias|
        cbtAlias.downcase!
        # Go through each ftypeHash record and see if it looks like the aliasalais
        ftypeHashes.each_key { |trackName|
          if(trackName.downcase == cbtAlias)
            ftypeHash = ftypeHashes[trackName]
            break
          end
        }
      }
      ftypeHashes.clear ; ftypeHashes = nil
      return ftypeHash
    end

    #---------------------------------------------------------------------------
    # * *Function*: returns an Array of CytoBandAnno Structs based on the track given
    #               by ftypeHash. The CytoBandAnnos will be properly initialized and
    #               the bandType field filled in based on CYTOBAND_TRACK_ALIASES and then score
    #               as a backup.
    #
    # * *Args*    : <tt> CytobandDrawer#getCytobandAnnosFromTrack(ftypeHash) </tt>
    # [+ftypeHash+] A Hash representing the track to draw; the Hash is equivalent to an Ftype table record but also containing
    #               a 'dbNames' key whose value is an Array of objects that indicate each database where the track is found
    #               and the corresponding ftypeid of the track within that database. (This is necessary because of user vs template databases)
    # [+returns+]   A BLOB (String) of the created PNG formatted cytoband image
    #---------------------------------------------------------------------------
    def getCytobandAnnosFromTrack(ftypeHash)
      allCbAnnoRecords = []    # Array of CytoBandAnno records
      # Need to examine all [both] databases: user and template, if present
      ftypeHash['dbNames'].each { |dbRec|
        @dbu.setNewDataDb(dbRec.dbName)
        # Collect the annotation records for this database, keyed by fid:
        annoRecs = {}
        # 1. Get anno records with relevant columns from the fdata2 tables
        annoRows = @dbu.selectFdataByLandmark(@epRid, dbRec.ftypeid, @drawStart, @drawStop, ANNO_COLUMNS)
        unless(annoRows.empty?)
          # 2. Collect all the fids and organize anno records
          annoRows.each { |annoRow|
            fid = annoRow['fid']
            annoRecs[fid] = CytoBandAnno.new(fid, annoRow['gname'], annoRow['fstart'], annoRow['fstop'], annoRow['fscore'].to_f)
          }
          annoRows.clear() ; annoRows = nil # Free early, in case track was large
          # 3. Get bandType and gieStain AVP values
          # - the rows returned have columns: fid, name, value
          avpRows = @dbu.selectAVPsByFids(BAND_TYPE_ALIASES, annoRecs.keys)
          # 4. Incorporate AVP info to our CytoBandAnnos. We look at each attribute b/c of need for case-insensitive lookup and possible case-duplicates (Cyto:Band vs cyto:band)
          avpRows.each { |avpRow|
            # Get the CytoBandAnno struct out of annoRecs
            annoRec = annoRecs[avpRow['fid']]
            # Set its bandType field by finding first bandType alias that matches
            BAND_TYPE_ALIASES.each { |btAlias|
              if(avpRow['name'].downcase == btAlias.downcase)
                annoRec.bandType = avpRow['value']
                break
              end
            }
          }
          # 5. Accumulate AVP records across databases
          allCbAnnoRecords += annoRecs.values
          avpRows.clear() ; annoRecs.clear()
          avpRows = annoRecs = nil
        end
      }
      # 6. Sort the bands by coords
      allCbAnnoRecords.sort! { |aa, bb|
        retVal = (aa.start <=> bb.start)
        retval = (aa.stop <=> bb.stop) if(retVal == 0)
        retVal
      }
      # 7. Ensure both bandType is filled in for all CytoBandAnno objects
      #    - if bandType-like attribute wasn't available, try using the score as an encoding of band type
      #      else if still can't make a good guess, make it gneg
      #    - try to adjust score-based ones such that a series of 1,-1,1,-1,-1 turns into gvar,stalk,gvar,acen,acen rather than gpos100,acen,gpos100,acen,acen
      prevScrs = []
      allCbAnnoRecords.each_index { |ii|
        cbRec = allCbAnnoRecords[ii]
        if(cbRec.bandType.nil?) # no bandType-like attribute, try using score...but also try to deal with the -1,-1,-1 efffect
          # Add to prevScrs array and shift off first record if it becomes longer than our pattern
          prevScrs << cbRec.score
          prevScrs.shift if(prevScrs.size > ACRO_SCR_PATTERN.size)
          if(prevScrs == ACRO_SCR_PATTERN)  # special score-based decision pattern detected!
            cbRec.bandType = 'acen'
            # Adjust previous records:
            1.upto(ACRO_SCR_PATTERN.size - 1) { |jj|
              adjustRec = allCbAnnoRecords[ii-jj]
              bandIdx = ACRO_PATTERN_REPLACE_BANDS.size - jj
              (adjustRec.bandType = ACRO_PATTERN_REPLACE_BANDS[bandIdx]) if(adjustRec)
            }
            # Reset prev score-based decision pattern tracking
            prevScrs.clear()
          else # going to use score as-is...already updated tracking info by adding curr score to prevScrs, good.
            cbRec.bandType = SCORES2BANDS[cbRec.score]
          end
        else # bandType is ok for this record
          # Reset prev score-based decision pattern tracking
          prevScrs.clear()
        end

        # If still bandType not set after this (guess couldn't look up by score), set them to a default type
        if(cbRec.bandType.nil?)
          cbRec.bandType = DEFAULT_BAND
          # Reset prev score-based decision pattern tracking
          prevScrs.clear()
        else  # there's some band type
          # So, finally, ensure caseness of bandType
          cbRec.bandType.downcase!
        end
      }
      return allCbAnnoRecords
    end

    # ------------------------------------------------------------------
    # DRAWING RELATED METHODS
    # ------------------------------------------------------------------

    #---------------------------------------------------------------------------
    # * *Function*: Utility method to get the color of the band type
    # AVP priority: 1) bandType 2) score
    #
    # [+cytoBandAnno+] A filled-in CytoBandAnno struct
    # [+returns+] String representing the HTML hex color
    #---------------------------------------------------------------------------
    def getColor(cytoBandAnno)
      color = nil
      color = BAND_COLORS[cytoBandAnno.bandType]
      color = BAND_COLORS[SCORES2BANDS[cytoBandAnno.score,to_f]] if(color.nil?)
      return (color || DEFAULT_COLOR)
    end

    #---------------------------------------------------------------------------
    # * *Function*: Draw a regular (non-rounded) chromosome segment.
    #
    # * *Args*    : <tt> draw_regular_segment(startX, startY, stopX, stopY, color) </tt>
    # [+startX+]  The startX pixel coordinate
    # [+startY+]  The startY pixel coordinate
    # [+stopX+]   The stopX pixel coordinate
    # [+stopY+]   The stopY pixel coordinate
    # [+color+]   The RVG color parameter (named or hex)
    # [+returns+] none
    #---------------------------------------------------------------------------
    def drawRegularSegment(startX, startY, stopX, stopY, color)
      borderStrokeWidth = 1
      @rvgGroup.g.styles(:stroke=>color, :fill=>color) { |element|
        element.rect( (stopX - startX).abs, (stopY - startY).abs, startX, startY)
        # draw the left and right border for this annotation
        # left border
        element.line(startX, startY, startX, stopY).styles(:stroke=>'black', :stroke_width=>borderStrokeWidth)
        # right border
        element.line(stopX, startY, stopX, stopY).styles(:stroke=>'black', :stroke_width=>borderStrokeWidth)
      }
    end

    #---------------------------------------------------------------------------
    # * *Function*: Draw a stalk region.
    #
    # * *Args*    : <tt> draw_stalk_region(startX, startY, stopX, stopY, color) </tt>
    # [+startX+]  The startX pixel coordinate
    # [+startY+]  The startY pixel coordinate
    # [+stopX+]   The stopX pixel coordinate
    # [+stopY+]   The stopY pixel coordinate
    # [+color+]   The RVG color parameter (named or hex)
    # * *Returns* :
    #   - +none+
    #---------------------------------------------------------------------------
    def drawStalkRegion(startX, startY, stopX, stopY, color)
      borderStrokeWidth = 1
      @rvgGroup.g.styles(:stroke=>color, :fill=>color) { |element|
        stalkInset = (stopX - startX).abs * STALK_INSET_FACTOR
        element.path("M#{startX},#{startY} H#{stopX},#{startY} C#{stopX - stalkInset},#{startY} #{stopX - stalkInset},#{stopY} #{stopX},#{stopY} H#{startX},#{stopY} C#{startX + stalkInset},#{stopY} #{startX + stalkInset},#{startY} #{startX},#{startY} z").styles(:fill=>color, :stroke=>'black', :stroke_width=>1)
      }
    end

    #---------------------------------------------------------------------------
    # * *Function*: Draw a top-rounded chromosome segment
    #
    # * *Args*    : <tt> draw_top_arc(annotation, trackParameters, color) </tt>
    # [+annotation+]      The LFF style annotation
    # [+trackParameters+] The track specific VGP parameters (e.g. vgpParameters[:tracks][:trackName])
    # [+color+]           The RVG color parameter (named or hex)
    # [+returns+]         none
    #---------------------------------------------------------------------------
    def drawTopArc(startX, startY, stopX, stopY, color)
      # Detemine height
      annotationHeight = (startY - stopY).abs
      # Only try to draw actual arc if below threshold for seeing sensible arc
      if(annotationHeight > ARC_TOLERANCE)
        drawRegularSegment(startX, startY + ARC_TOLERANCE, stopX, stopY, color)
        stopY = startY + ARC_TOLERANCE
        annotationHeight = (startY - stopY).abs
      end
      # Draw a line just like we would in block drawing style
      @rvgGroup.g { |element|
        path = "M#{startX},#{stopY} C#{startX},#{startY - annotationHeight / 3} #{stopX},#{startY - annotationHeight / 3} #{stopX},#{stopY}"
        element.path(path).styles(:fill=>color, :stroke=>'black', :stroke_width=>1)
      }
    end

    #---------------------------------------------------------------------------
    # * *Function*: Draw a bottom-rounded chromosome segment
    #
    # * *Args*    : <tt> draw_bottom_arc(annotation, trackParameters, color) </tt>
    # [+annotation+]      The LFF style annotation
    # [+trackParameters+] The track specific VGP parameters (e.g. vgpParameters[:tracks][:trackName])
    # [+color+]           The RVG color parameter (named or hex)
    # [+returns+]         none
    #---------------------------------------------------------------------------
    def drawBottomArc(startX, startY, stopX, stopY, color)
      annotationHeight = (startY - stopY).abs
      # Only try to draw actual arc if below threshold for seeing sensible arc
      if(annotationHeight > ARC_TOLERANCE)
        drawRegularSegment(startX, startY, stopX, stopY - ARC_TOLERANCE, color)
        startY = stopY - ARC_TOLERANCE
        annotationHeight = (startY - stopY).abs
      end
      # Draw a line just like we would in block drawing style
      @rvgGroup.g { |element|
        path = "M#{startX},#{startY} C#{startX},#{stopY + annotationHeight / 3} #{stopX},#{stopY + annotationHeight / 3} #{stopX},#{startY}"
        element.path(path).styles(:fill=>color, :stroke=>'black', :stroke_width=>1)
      }
    end

    #----------------------------------------------------------------------------
    # * *Function*: Gets the Y position of the given annotation start basepair.
    #
    # * *Args*    : <tt> getAnnotationPixelStart(annotation) </tt>
    # [+annotation+]  a filled in CytoBandAnno struct
    # [+returns+]     Fixnum+ -> The y position of the annotation start basepair
    #----------------------------------------------------------------------------
    def getAnnotationPixelStart(cytoBandAnno)
      return [@leftMargin, getBpPixelPosition(cytoBandAnno.start) + @topMargin]
    end

    #----------------------------------------------------------------------------
    # * *Function*: Gets the Y position of the given annotation stop basepair.
    #
    # * *Args*    : <tt> getAnnotationPixelStop(annotation) </tt>
    #   - +annotation+ -> LFF style annotation
    # * *Returns* :
    #   - +Fixnum+ -> The y position of the annotation stop basepair
    #----------------------------------------------------------------------------
    def getAnnotationPixelStop(cytoBandAnno)
      # The width of the track (chromosome) minus 1px to allow left (or bottom if horz) border to draw
      return [@drawWidth - @rightMargin - 1, getBpPixelPosition(cytoBandAnno.stop) + @topMargin]
    end

    #----------------------------------------------------------------------------
    # * *Function*: Gets the Y position of the given basepair.
    #
    # * *Args*    : <tt> getBpPixelPosition(145_978_211) </tt>
    #   - +basePair+ -> The basepair value of interest (e.g. 145,978,211)
    # * *Returns* :
    #   - +Fixnum+ -> The y position of the basepair
    #----------------------------------------------------------------------------
    def getBpPixelPosition(basePair)
      retVal = ((basePair.to_f - @drawStart) == 0) ? 0 : ((basePair.to_f - @drawStart) / (@drawStop - @drawStart)) * (@drawHeight - (@topMargin + @bottomMargin)) - 1.0
      return (retVal < 0 ? 0 : retVal.to_i)
    end

    # ------------------------------------------------------------------
    # PRIVATE METHODS
    # ------------------------------------------------------------------
    private

    #---------------------------------------------------------------------------
    # * *Function*: returns a BLOB of the PNG cytoband image
    #               Not meant to be called by outside classes because it depends on state having been
    #               set by createCytobandImageForTrack() and createCytobandImageForChrom(). Used by
    #               createCytobandImageForTrack() and createCytobandImageForChrom() to do the actual drawing of whatever annotations
    #               are found. If there are no annotations for this track in the chromosome (or the region of the chromosome)
    #               then it will be drawn empty.
    #
    # * *Args*    : <tt> CytobandDrawer#createCytobandImage(landmark, cytoBandAnnos, drawOpts={}) </tt>
    # [+landmark+]  A landmark String for the region to draw as cytoband image. At a minimum, a chr name is required with the start & stop being optional.
    #               Examples: "chr14", "chr14:450001-540002", "chr14:450000-", "chr14:-678990"
    # [+cytoBandAnnos+]  An Array of CytoBandanno Structs to draw cytoband image. If empty, an empty chromosome [region]
    #                    will be drawn.
    # [+drawOpts+]  An optional hash with specified drawing parameters. Params include: height, width, orientation
    # [+returns+]   A BLOB (String) of the created PNG formatted cytoband image
    #---------------------------------------------------------------------------
    def createCytobandImage(landmark, cytoBandAnnos, drawOpts={})
      # Margins
      @topMargin = drawOpts['topMargin'].to_i if(drawOpts.key?('topMargin'))
      @rightMargin = drawOpts['rightMargin'].to_i if(drawOpts.key?('rightMargin'))
      @bottomMargin = drawOpts['bottomMargin'].to_i if(drawOpts.key?('bottomMargin'))
      @leftMargin = drawOpts['leftMargin'].to_i if(drawOpts.key?('leftMargin'))

      # Always draw in a vertical fashion, transpose later if orientation is horizontal
      orientation = (drawOpts['orientation'] or ORIENTATION)
      if(HORIZONTAL_VALUES.key?(orientation))
        @drawWidth = (drawOpts['height'].to_i or HEIGHT)
        @drawHeight = (drawOpts['width'].to_i or WIDTH)
        # rotate margins
        @topMargin, @rightMargin, @bottomMargin, @leftMargin = *[@rightMargin, @bottomMargin, @leftMargin, @topMargin]
      else # vertical
        @drawWidth = (drawOpts['width'].to_i or WIDTH)
        @drawHeight = (drawOpts['height'].to_i or HEIGHT)
      end

      # Create artificial bands if no data present from track
      if(cytoBandAnnos.empty?)
        # We need regions for p-end, middle, and q-end. Integer division will round fractions down.
        locs = [ 1, (@epLength / 3), (2 * @epLength / 3), @epLength]
        1.upto(locs.length - 1) { |num|
          cytoBandAnnos.push(CytoBandAnno.new("Mq#{num}", @ep, locs[num-1], locs[num], 0, DEFAULT_BAND))
        }
      end

      # Ensure @drawStart is not larger than start of first anno retrieved (it cannot be nil at this point)
      # if drawStart larger, fix first record to start at drawStart
      cytoBandAnnos.first.start = @drawStart if(@drawStart > cytoBandAnnos.first.start)

      # Ensure @drawStop is not smaller than stop of last anno retrieved (it cannot be nil at this point)
      if(@drawStop < cytoBandAnnos.last.stop) # if drawStart smaller, fix last record to stop at drawStop
        cytoBandAnnos.last.stop = @drawStop
      elsif(@drawStop > cytoBandAnnos.last.stop) # if drawStop beyond end of last record, set drawStop to stop of last record
        @drawStop = cytoBandAnnos.last.stop
      end

      # ACTUAL DRAWING CODE:
      # Create a new RVG group to draw inside of
      @rvgGroup = Magick::RVG::Group.new()
      acenDrawn = false
      cytoBandAnnos.each_index { |index|
        cbAnnoRec = cytoBandAnnos[index]
        bandType = cbAnnoRec.bandType
        color = getColor(cbAnnoRec)
        startX, startY = getAnnotationPixelStart(cbAnnoRec)
        stopX, stopY = getAnnotationPixelStop(cbAnnoRec)

        if((index == 0) and (cbAnnoRec.start <= 10))
          # Start of first cytoband should be 1, but less than 10 will catch bad data (0 or 2, spec.)
          # If starting at the beginning, draw a top arc
          drawTopArc(startX, startY, stopX, stopY, color)
        elsif((index == cytoBandAnnos.size - 1) and (cbAnnoRec.stop >= (@epLength - 10)))
          # Start of last cytoband should be length of EP, but a 10 bp buffer should catch bad data
          # If stopping at the end, draw a bottom arc
          drawBottomArc(startX, startY, stopX, stopY, color)
        elsif(bandType == 'acen') # draw acrocentric region properly...will depend on if we've drawn the 5' acen part yet or not
          if(!acenDrawn)
            drawBottomArc(startX, startY, stopX, stopY, color)
            acenDrawn = true
          else
            drawTopArc(startX, startY, stopX, stopY, color)
          end
        elsif(bandType == 'stalk')
          drawStalkRegion(startX, startY, stopX, stopY, color)
        else
          drawRegularSegment(startX, startY, stopX, stopY, color)
        end
      }

      # Create our RVG object to contain our group
      Magick::RVG::dpi = 96
      # Pre-sizing dims
      rvg = RVG.new(@drawWidth, @drawHeight) { |canvas|
        canvas.background_fill = 'white'
        canvas.background_fill_opacity = 0.0
      }
      rvg.use(@rvgGroup)
      image = rvg.draw()
      image.format = 'png'
      image.transpose!() if(HORIZONTAL_VALUES.key?(orientation))

      return image.to_blob()
    end
  end # END CytobandDrawer class
end ; end ; end # END BRL::Util modules
