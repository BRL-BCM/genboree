require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/rest/helpers/apiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'

module BRL ; module Genboree ; module REST ; module Helpers
  class ProjectApiUriHelper < ApiUriHelper
    # Each resource specific API Uri Helper subclass should redefine this:
    NAME_EXTRACTOR_REGEXP = %r{^http://[^/]+/REST/v\d+/grp/[^/]+/prj/([^/\?]+)}
    EXTRACT_SELF_URI = %r{^(.+?/prj/[^/\?]+)}     # To get just this resource's portion of the URL, with any suffix stripped off
    ADDITIONAL_PAGES_API_REGEXP = %r{^(http://[^/]+/REST/v\d+/grp/[^/]+/prj/[^/\?]+/additionalPages/[^/\?]+/[^\?]+)}

    attr_accessor :grpApiUriHelper

    def initialize(dbu=nil, genbConf=nil, reusableComponents={})
      @grpApiUriHelper = nil
      super(dbu, genbConf, reusableComponents)
    end

    def init(dbu=nil, genbConf=nil, reusableComponents={})
      super(dbu, genbConf, reusableComponents)
      @grpApiUriHelper = GroupApiUriHelper.new(dbu, genbConf, reusableComponents) unless(@grpApiUriHelper)
    end

    # INTERFACE. Subclasses must override this to look for resuable bits.
    def extractReusableComponents(reusableComponents={})
      super(reusableComponents)
      reusableComponents.each_key { |compType|
        case compType
        when :grpApiUriHelper
          @grpApiUriHelper = reusableComponents[compType]
        end
      }
    end

    # ALWAYS call clear() when done. Else memory leaks due to possible
    # cyclic references.
    def clear()
      # Call clear() on track abstraction objects
      if(!@cache.nil?)
        @cache.each_key { |uri|
          sampleObj = @cache[uri][:abstraction]
          sampleObj.clear() if(sampleObj and sampleObj.respond_to?(:clear))
        }
      end
      super()
      # grpApiUriHelper is cleared by dbApiUriHelper from whence it came
      @grpApiUriHelper = nil
    end

    # --------------------------------------------------
    # API Request Helpers - {{
    # --------------------------------------------------

    def getPrjUri(grpUri, prj)
      return "#{grpUri}/prj/#{CGI.escape(prj)}"
    end

    # @return [String, NilClass] a project additional pages uri for the Genboree HTTP REST API
    #   or nil if the prjUri is not really a URI to a Genboree project
    def getAdditionalPagesFileApiUri(prjUri, file)
      rv = nil
      if(NAME_EXTRACTOR_REGEXP.match(prjUri))
        fileTokens = file.split("/")
        escTokens = fileTokens.map { |token| CGI.escape(token) }
        fileUriName = escTokens.join("/")
        rv = "#{prjUri}/additionalPages/file/#{fileUriName}"
      end
      return rv
    end

    # @return [String, NilClass] a uri for viewing a project additional pages file 
    #   (but not for use in the HTTP REST API) or nil if the @prjUri@ is not really
    #   a URI to a Genboree project
    def getAdditionalPagesFileHtmlUri(prjUri, file)
      rv = nil
      if(NAME_EXTRACTOR_REGEXP.match(prjUri))
        uriObj = URI.parse(prjUri)
        fileTokens = file.split("/")
        escTokens = fileTokens.map { |token| CGI.escape(token) }
        fileUriName = escTokens.join("/")
        rv = "http://#{uriObj.host}/projects/#{CGI.escape(extractName(prjUri))}/genb%5E%5EadditionalPages/#{fileUriName}"
      end
      return rv
    end

    # Upload an archive of files to a Genboree project additional pages area
    # @param [String] additionalPagesFileUri the location of the Genboree project additional 
    #   pages to upload to
    # @param [String] filepath the local archive to upload to the additional pages area
    # @return [Hash] wrapper @see [ApiUriHelper#makeRequest]
    def uploadAdditionalPagesArchive(additionalPagesFileUri, filepath)
      rv = nil
      if(matchData = ADDITIONAL_PAGES_API_REGEXP.match(additionalPagesFileUri))
        additionalPagesFileUri = matchData[1] # removes query
        uri = "#{additionalPagesFileUri}?extract=true"
        File.open(filepath) { |fh|
          rv = makeRequest(:put, uri, fh, false)
        }
      else
        rv = getHelperRespObj
        rv[:msg] = "The URL #{additionalPagesFileUri.inspect} is not a URL for a Genboree project additional pages area"
      end
      return rv
    end

    # }} -

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
  end # class TrackApiUriHelper < ApiUriHelper
end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module Helpers
