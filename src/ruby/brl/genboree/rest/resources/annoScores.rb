#!/usr/bin/env ruby
require 'fileutils'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/graphics/barGlyph'
require 'brl/genboree/graphics/geneImageCreator'
require 'brl/util/util'


#--
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
  class AnnoScores < BRL::REST::Resources::GenboreeResource
    IMAGE_SET_DIR_MAP = {
      'freeze1' => 'geneImagesDir',
      'freeze2' => 'geneImagesDir_2',
      'freeze3' => 'geneImagesDir_3',
      'freeze4' => 'geneImagesDir_4',
      'miRNA3' => 'miRNAImagesDir_3',
      'miRNA4' => 'miRNAImagesDir_4'
    }

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
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/image}
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
        @annoName = @nvPairs['roiAnnoName'].to_s
        trackHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@dbu, @genbConf, {:rackEnv => @rackEnv})
        @roiTrackGrp = trackHelper.grpApiUriHelper.extractName(@rsrcURI.to_s)
        @roiTrackDB = trackHelper.dbApiUriHelper.extractName(@rsrcURI.to_s)
        @roiTrackName = trackHelper.extractName(@rsrcURI.to_s)
        @roiTrack = "#{trackHelper.extractPureUri(@rsrcURI.to_s)}?gbKey=#{trackHelper.extractGbKey(@rsrcURI)}"
        @configString = @nvPairs['configString'].to_s
        @imageFormat = @repFormat
        @scrTracks = @nvPairs['scrTracks'].split(/,/)
        if(@annoName.empty?)
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

    def initImageCacheInfo()
      # - construct path to image file
      baseDir = @genbConf.gbTrackImagesDir
      unless(baseDir.nil? or baseDir.empty?)
        @pngCacheDir = "#{@genbConf.gbTrackImagesDir}/grp/#{CGI.escape(@roiTrackGrp)}/db/#{CGI.escape(@roiTrackDB)}/trk/#{CGI.escape(@roiTrackName)}/#{File.md5Shorten(CGI.escape(@scrTracks.join(",")))}"
      else
        @pngCacheDir = @genbConf.geneImagesDir
      end      
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
      case @repFormat
      when :ANNO_BAR_GRAPH, :ANNO_AVG_BAR_GRAPH,:SAMPLE_BAR_GRAPH, :SAMPLE_AVG_BAR_GRAPH
        if(@scrTracks.nil? or @scrTracks.empty?) then
          
          suffix = ""
          if(@repFormat.to_s =~ /AVG/) then suffix = "(s)" end
          if([:ANNO_BAR_GRAPH, :ANNO_AVG_BAR_GRAPH].member?(@repFormat)) then
            @pngData = BRL::Genboree::Graphics::BarGlyphDrawer.drawMessage("Empty Score Track#{suffix}")
          else
            @pngData = BRL::Genboree::Graphics::BarGlyphDrawer.drawMessage("Sample#{suffix} not\nlinked to\ntrack")
          end
        else
          # Check if cached
          initImageCacheInfo()
          # - file exist and not empty?
          if(File.exist?(@cachePngFile) and File.size(@cachePngFile) > 0)
            # - get PNG data
            @pngData = File.read(@cachePngFile)
          else  # create PNG
            # - create drawer instance
            giCreator = BRL::Genboree::Graphics::GeneImageCreator.new(nil, "Type", "Name", @genbConf,@hostAuthMap)
            # TODO: set this to do an internal request
            giCreator.setRackEnv(@req.env)
            # - get PNG data
            @pngData = giCreator.createImage(@annoName, @scrTracks, @roiTrack, @imageFormat, @configString)
            # - save into cached dir
            writeToCache(@pngData)
          end
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
  end # class AnnoScores
end ; end ; end # module BRL ; module REST ; module Resources
