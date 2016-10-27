#!/usr/bin/env ruby
require 'fileutils'
require 'md5'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/graphics/geneImageCreator'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  #++
  ####################################################################################
  # This is a utility class with the single task of creating a bar chart of scores for
  # annotations. It is primarily gene-component-oriented and uses libraries written by
  # Sriram Raghuram to do the drawing.
  #
  # Obtaining the data is currently an API call as well.
  #
  # TODO: Improvements:
  # 1. Replace data acquisition with direct calls rather than http-mediated API call.
  # 2. Implement disk-based caching. Check for image file first, only generate if must.
  # 3. Consider limited memory (LRU) memory caching as well, if necessary
  ####################################################################################
  class TracksImage < BRL::REST::Resources::GenboreeResource

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/ep/([^/\?]+)</tt>
    #
    # CHANGE:
    # - score track resource request (format="annoBarGraph", roiAnnoName=____, roiTrack={url}
    # CHANGE:
    # - trk/{trk}?format=annoBarGraph type request.
    # - pattern: %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/image}
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trks/image}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 7          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        # CHANGE:
        # - @repFormat will have specific image type requested (annoBarGraph)
        #@annoName = Rack::Utils.unescape(@uriMatchData[2])
        @annoName = @nvPairs['roiAnnoName'].to_s
        #@scrTrack = @nvPairs['scrTrack'].to_s
        trackHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
        @scrTrackGrp = trackHelper.grpApiUriHelper.extractName(@rsrcURI.to_s)
        @scrTrackDB = trackHelper.dbApiUriHelper.extractName(@rsrcURI.to_s)
        @scrTrackPrefix = trackHelper.dbApiUriHelper.extractPureUri(@rsrcURI.to_s)
        # CHANGE:
        # edacc stuff goes away
        #@institution = @nvPairs['remc'].to_s
        #@sample = @nvPairs['sample'].to_s
        #@experiment = @nvPairs['experiment'].to_s
        #@imageSet = @nvPairs['imageSet'].to_s
        @configString = @nvPairs['configString'].to_s
        @imageFormat = @repFormat
        @roiTrack = URI.unescape(@nvPairs['roiTrack'].to_s)
        #if(@scrTrack.empty? or @sample.empty? or @experiment.empty?)
        if(@annoName.empty? or @roiTrack.empty?)
          initStatus = :'Bad Request'
          @statusMsg = "MISSING_PARAMS: one or more required parameters are missing. The roiTrack, the annotation name and the image format must be present and correctly escaped"
        end
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      @statusName = initOperation()
      setResponse() if(@statusName == :OK)
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def shortenMD5(name, maxSize=200)
      if (name.size >= maxSize) then
        return "#{name[0,maxSize-32]}#{Digest::MD5.hexdigest(name)}"
      else
        return name
      end
    end


    def initImageCacheInfo()
      # CHANGE:
      # - make generic for any scr + roi track combo in any DB:
      #   - {baseDir}/{grp}/{grp}/db/{db}/trk/{trk}/roiTrk/{roiTrkURIpath}/______

      # - construct path to image file
      baseDir = @genbConf.gbTrackImagesDir
      unless(baseDir.nil? or baseDir.empty?)
        @pngCacheDir = "#{@genbConf.gbTrackImagesDir}/grp/#{@scrTrackGrp}/db/#{@scrTrackDB}/trks/#{CGI.escape(@roiTrack)}"
      else
        @pngCacheDir = @genbConf.geneImagesDir
      end

      comboDirName = @trackList.sort.map{|xx| CGI.escape(xx)}.join(",")
      comboDirName = shortenMD5(comboDirName)
      @pngCacheDir = "#{@pngCacheDir}/#{comboDirName}"
      @annoNameFirstChar = @annoName[0].chr
      # CHANGE: add "format" to image file name (e.g. ".annoBargraph.png")
      if(@configString.nil? or @configString.empty?) # No customization of gene image so check for cached version
        @cachePngFile = "#{@pngCacheDir}/#{CGI.escape(@annoNameFirstChar)}/#{CGI.escape(@annoName)}^^#{CGI.escape(@imageFormat.to_s)}.png"
      else # custom gene elements chosen hence different filename format
        @cachePngFile = "#{@pngCacheDir}/#{CGI.escape(@annoNameFirstChar)}/#{CGI.escape(@annoName)}^^#{CGI.escape(@imageFormat.to_s)}.png^^#{MD5.hexdigest(@configString)}.png"
      end
    end

    def writeToCache(pngBlob)
      FileUtils.mkdir_p(File.dirname(@cachePngFile))
      outFile = File.open(@cachePngFile, "w+")
      outFile.write(pngBlob)
      outFile.close()
    end

    def setResponse(statusName=@statusName, statusMsg=@statusMsg)
      retVal = nil
      if(@nvPairs['payload'].nil? or @nvPairs['payload'].empty?) then
        entities = parseRequestBodyAllFormats('TextEntityList')
        if(entities.nil?) then
          # If we have an @apiError set, use it, else set a generic one.
          @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: To call PUT on this resource, the payload must be a TextEntityList") if(@apiError.nil?)
        elsif(entities == :'Unsupported Media Type')
          # If we have an @apiError set, use it, else set a generic one.
          @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not a TextEntityList") if(@apiError.nil?)
        else
          @trackList = []
          entities.each_with_index { |entity,ee|
            if(!entity.respond_to?(:text) or entity.text.nil? or entity.text.empty?)
              @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_NAME: Track ##{ee} -> Does not have a proper value in the 'text' column or is missing the required 'text' column altogether.")
              break
            else # Collect all attribute names
              # Need to this only once
              if(entity.text =~ /:/) then
                @trackList << "#{@scrTrackPrefix}/trk/#{CGI.escape(entity.text)}"
              else
                @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_NAME: Track #{entity.text} -> Does not have a ':' in the track name.")
                break
              end
            end
          }
        end
      else
        @trackList = @nvPairs["payload"].split(/,/).map{|xx| "#{@scrTrackPrefix}/trk/#{xx}"}
      end
      case @repFormat
      when :ANNO_AVG_BAR_GRAPH
        # Check if cached
        initImageCacheInfo()
        # - file exist and not empty?
        if(File.exist?(@cachePngFile) and File.size(@cachePngFile) > 0)
          # - get PNG data
          @pngData = File.read(@cachePngFile)
        else  # create PNG
          # - create drawer instance
          #$stderr.debugPuts(__FILE__, __method__, "tImer","cache file #{@cachePngFile} missing")
          giCreator = BRL::Genboree::Graphics::GeneImageCreator.new(nil, "Type", "Name", @genbConf, @hostAuthMap)
          # TODO: set this to do an internal request
          giCreator.rackEnv = @req.env
          # - get PNG data
          @pngData = giCreator.createImage(@annoName, @trackList, @roiTrack, @imageFormat, @configString)
          # - save into cached dir
          writeToCache(@pngData)
        end
        # Return PNG data
        # - set content type and content length, etc
        @resp.status = HTTP_STATUS_NAMES[:OK]
        @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:SCORE_CHART_PNG]
        @resp.body = @pngData
        retVal = @resp
      else  # Can't provide representation in requested format
        @statusName = :'Unsupported Media Type'
        @statusMsg = "BAD_REP: The format requested (#{@repFormat.inspect}) is missing or not supported."
      end
      return retVal
  end
end # class TrackImages
end ; end ; end # module BRL ; module REST ; module Resources
