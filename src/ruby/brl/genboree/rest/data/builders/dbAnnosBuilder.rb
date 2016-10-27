#!/usr/bin/env ruby

require "brl/genboree/genboreeDBHelper"
require "brl/genboree/rest/helpers"
require "brl/genboree/rest/data/entity"
require "brl/genboree/rest/data/textEntity"
require "brl/genboree/rest/data/builders/builder"
require "brl/genboree/rest/resources/dbAnnos"
#--
module BRL ; module Genboree ; module REST ; module Data
module Builders
#++

  # DbAnnosBuilder
  #  This implementation applies a Boolean Query to all of the annotations in
  # entire database, any track as long as the user has permission to that track.
  class DbAnnosBuilder < Builder
    include BRL::Genboree::REST::Helpers

    PRIMARY_TABLE = "fdata2"

    PRIMARY_ID = "fid"

    SECONDARY_TABLES = { "fref" => "p.rid=fref.rid" , "ftype" => "p.ftypeid=ftype.ftypeid" }

    AVP_TABLES = { "names" => "attNames", "values" => "attValues", "join" => "fid2attribute" } 
    AVP_IDS = [ "fid", "attNameId", "attNameId", "attValueId", "attValueId" ]

    CORE_FIELDS = {
                    "primary" => [
                      "fid",
                      "fstart", 
                      "fstop", 
                      "fbin", 
                      "ftypeid",  
                      "fscore", 
                      "fstrand", 
                      "fphase", 
                      "ftarget_start",
                      "ftarget_stop",
                      "gname",
                      "displayCode",
                      "displayColor", 
                      "groupContextCode" 
                    ],
                    "fref" => [
                      "refname"
                    ],
                    "ftype" => [
                      "fmethod",
                      "fsource"
                    ]
                  }

    # QUERYABLE: Constant for determining whether this resource
    # can be queried upon
    QUERYABLE = true

    # DISPLAY_NAMES: Constant to provide database table names mapped to appropriate
    # display names
    DISPLAY_NAMES = [{"gname" => "Name"}, {"fmethod" => "Type"}, {"fsource" => "Subtype"}, {"refname" => "Entry Point"}, {"fstart" => "Start"}, {"fstop" => "Stop"}, {"fscore" => "Score"}, {"fstrand" => "Strand"}, {"fphase" => "Phase"}, {"ftarget_start" => "Target Start"}, {"ftarget_stop" => "Target Stop"}]

    RESPONSE_FORMAT = "lff"
    # Default assumed format is text/lff
    @format = :LFF
  
    # This overridden method implements a chunked +String+ response instead of
    # the standard +AbstractEntityList+ subclass return that is typically
    # returned by the subclasses of +Builder+.  This is done in order to handle
    # responses containing annotation lists in the range of millions or larger.
    # The memory usage requirements for lists of that size proclude us from
    # building an entity list in memory ahead of time.
    #
    # The following parameters are used differently than in the +Builder+
    # superclass and the return is slightly changed.
    # [+format+] The expected data format.  This +Builder+ currently only
    #   supports the following types:
    #    *  :LFF
    #   These types may be added in the future:
    #    *  :TABBED
    #    *  :LAYOUT
    # [+returns+] This +DBAnnosBuilder+.  This is because the object itself is
    #   built to yield data in blocks (via the DBAnnosBuilder#each() method).
    def applyQuery(query, dbu, refSeqId, userId, detailed=false, format=:LFF, layout=nil)
      # Cache the connection to the DBUtil
      @dbu = dbu

      # Process and set our return format type
      case(format)
      when :LFF, "lff", "text/lff"
        @format = :LFF
      #when :TABBED, "tabbed"
      #  @format = :TABBED
      when :LAYOUT, "layout"
        @format = :LAYOUT
        @layout = layout
        if(@layout.nil?)
          @error = "When specifying the response format as \"layout\", you must also supply a valid JSON layout string using the parameter layout=<json_layout_string>"
          return self
        end
      else
        # Cannot handle this format, exit quickly
        @error = "The specified format (#{format.to_s.downcase}) is not supported"
        return self
      end

      # Create the SQL in a separate method so that subclasses can override
      # this method and add additional constraints if necessary
      @sql = buildSql(JSON.parse(query))

      # Get all dbs
      uploadRows = dbu.selectDBNamesByRefSeqID(refSeqId)
      @allDbs = []
      uploadRows.each{ |uploadRow|
        @allDbs << uploadRow['databaseName']
      }

      # Grab permissions hash
      @accessibleTracks = {}
      @allDbs.each{ |dbName|
        # Use our dbName to grab our refSeqId
        refseqRows = dbu.selectRefseqByDatabaseName(dbName)
        dbRefSeqId = refseqRows.first['refSeqId']
        refseqRows.clear()

        @dbu.setNewDataDb(dbName)
        # Grab ftypeAccess and build our hash
        @accessibleTracks[dbName] = []
        GenboreeDBHelper.getAccessibleTrackIds(dbRefSeqId, userId, true, @dbu).each{ |id|
          @accessibleTracks[dbName] << id
        }
      }

      return self
    end

    # Provided for returning the data streamed in chunks
    # [+yields+] One block of data at a time, for the entire dataset.  This
    #   could be up to millions of rows, or more.  Streaming the data in this
    #   way essentially removes the memory limitation of querying for an
    #   arbitrarily large dataset.
    def each
      # Check if we caught an error early on
      if(@error)
        yield ""
        return
      end

      # Header first
      # NOTE - this will need to change for :LAYOUT or :TABBED. It will not
      #   be a trivial change either as we will have to build the header in an
      #   efficient way so that the performance isn't too degraded.  Most
      #   likely, an extra SQL call will be needed to build the list of 
      #   attributes for the header prior to querying for all of the data.
      if(@format == :LFF)
        yield "#class\tname\ttype\tsubtype\tEntry Point\tstart\tstop\tstrand\tphase\tscore\tqStart\tqStop\tattribute comments\tsequence\tfreestyle comments\n"
      else
        # Process the data with a single pass first to a file, then sort the data
        # using the UNIX 'sort' command, then finally yeild data to the requester.
        # NOTE: This will be much slower than creating a response in LFF format
        # because of the sorting implied by the tabular layout objects.  Perhaps
        # it will be worthwhile to handle the layouts that don't have the 'sort'
        # attribute differently.
        # TODO - Write to a (temp) file, sort with 'sort', then finally yeild data
      end

      # Process each DB one at a time
      @allDbs.each{ |dbName|
        @dbu.setNewDataDb(dbName)

        # Grab all gclass names and cache them
        gclasses = []
        gcRows = @dbu.selectAllFtypeClasses()
        gcRows.each{ |gcRow| gclasses << gcRow.to_h }
        gcRows.clear()

        # Ensure we have access to any data for this DB
        next if(@accessibleTracks[dbName].empty?)

        # Query the database for a result into our buffer
        buffer = ""
        num = 0
        sqlWithPermissions = @sql + " AND p.ftypeid IN (#{@accessibleTracks[dbName].join(",")})"
        @dbu.queryResultsByBlock(sqlWithPermissions, PRIMARY_ID) { |block|
          fids = []
          avp = {}
          minFid = maxFid = nil
          block.each{ |row|
            fids << row['fid']
            avp[row['fid']] = []
            maxFid = row['fid'] if(maxFid.nil? or row['fid'] > maxFid)
            minFid = row['fid'] if(minFid.nil? or row['fid'] < minFid)
          }

          # Grab all fidText rows and cache them
          fidText = {}
          fidTextRows = @dbu.selectAllFidTextByFids(fids)
          fidTextRows.each{ |ftRow|
            key = "#{ftRow['fid']}-#{ftRow['ftypeid']}"
            fidText[key] = []
            if(ftRow['textType'] == "s")
              fidText[key][0] = [] if(fidText[key][0].nil?)
              fidText[key][0] << ftRow['text']
            elsif(ftRow['textType'] == "t")
              fidText[key][1] = [] if(fidText[key][1].nil?)
              fidText[key][1] << ftRow['text']
            end
          }
          fidTextRows.clear()

          # Grab all of our AVPs and cache them
          #avpRows = @dbu.selectAllAVPsByFidBlock(minFid, maxFid)
          avpRows = @dbu.selectAllAVPsByFids(fids)
          avpRows.each{ |avpRow|
            avp[avpRow['fid']] << "#{avpRow['name']}=#{avpRow['value']}"
          }
          avpRows.clear()

          # Finally build our data rows, one at a time
          block.each{ |row|
            # Find our gclasses
            gclassStr = ""
            gclasses.each{ |gcRow| 
              if(gcRow['ftypeid'] == row['ftypeid'])
                gclassStr += (gclassStr.length == 0 ? gcRow['gclass'] : "; #{gcRow['gclass']}")
              end
            }

            # Ensure no nil values for sequence and comments
            key = "#{row['fid']}-#{row['ftypeid']}"
            fidText[key] = [] if(fidText[key].nil?)
            fidText[key][0] = [] if(fidText[key][0].nil?)
            fidText[key][1] = [] if(fidText[key][1].nil?)

            # Finally build a row for our object
            num += 1
            score = (row['fscore'].to_s.split(".")[1]=='0')? row['fscore'].to_i : row['fscore']
            tstart = (row['ftarget_start'].nil?)? '.' : row['ftarget_start']
            tstop = (row['ftarget_stop'].nil?)? '.' : row['ftarget_stop']
            buffer << "#{gclassStr}\t#{row['gname']}\t#{row['fmethod']}\t#{row['fsource']}\t#{row['refname']}\t#{row['fstart']}\t#{row['fstop']}\t#{row['fstrand']}\t#{row['fphase']}\t#{score}\t#{tstart}\t#{tstop}\t#{avp[row['fid']].join("; ")}\t#{fidText[key][0].join("; ")}\t#{fidText[key][1].join("; ")}\n"
            if(buffer.size > MAX_BUFFER_SIZE)
              yield buffer
              buffer = ""
            end
          }
        }

        yield buffer if(buffer.size > 0)
      }
    end

    # In order to make all annotations distinct regardless of database, we have
    # to define a name for the annotations that will be distinct in every
    # database.  Using the fid and gname in combination should be sufficient.
    def getName(dbRow)
      return nil if(dbRow.nil?)

      return "#{dbRow['fid']}-#{dbRow['gname']}"
    end

    # This +Builder+ subclass can handle the same URIs as the 
    # +BRL::REST::Resources::DbAnnos+ class, so this method simply returns the
    # same RegExp from that class.
    def self.pattern()
      return BRL::REST::Resources::DbAnnos.pattern()
    end

    # This method will inspect what type of content we are creating (depending
    # on the value of "format" used) and return an appropriate content type
    def content_type()
      return BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[@format]
    end
  end # class DbAnnosBuilder
end # module Builders
end ; end ; end ; end # module BRL ; Genboree ; REST ; Data
