require 'brl/util/util'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/apiCaller'

module BRL; module Genboree; module REST; module Helpers

# Provide functions that operate on the /REST/v1/grp/{grp}/redminePrj/{redminePrj} resource subtree
class RedminePrjApiUriHelper < ApiUriHelper

  # @interface
  EXTRACT_SELF_URI = %r{^(.+?/redminePrj/([^/\?]+))}
  NAME_EXTRACTOR_REGEXP = %r{^.+?/redminePrj/([^/\?]+)} # same but without outer match group

  # Map resource type symbol to a Regexp whose first match group will extract that resource
  #   from a URL (and removing any query string) and whose second match group will extract
  #   the name of that resource
  REGEXPS = {
    :redminePrj => EXTRACT_SELF_URI,
    :wiki => %r{^(.+?/redminePrj/[^/\?]+/wiki/([^/\?]+)\.json)},
    :rawContent => %r{^(.+?/redminePrj/[^/\?]+/rawcontent/([^\?]+))}
  }

  # @todo set @host, etc. variables
  def setupRedminePrj()
  end

  # @todo set @host, etc. variables
  def setupRedminePrjByComponents()
  end

  # --------------------------------------------------
  # RedminePrj - {{
  # --------------------------------------------------
  # @todo distinction between a Genboree Redmine project URL and simply Redmine project URL
  #   e.g. /REST/v1/grp/{grp}/redminePrj/{redminePrj} vs. /projects/{redminePrj}

  # Get the URL for a Redmine project from a Genboree Redmine Project URL
  def getRedminePrjUrl(gbRedminePrjUrl)
    rv = getRedminePrj(gbRedminePrjUrl)
    if(rv[:success])
      rv[:obj] = rv[:obj]["url"]
    end
    return rv
  end

  # Get a URL to a Redmine Project at a given @host@ based on path components
  def getGbRedminePrjUrl(host, group, project)
    return "http://#{host}#{getGbRedminePrjPath(group, project)}"
  end

  # Get a URL path to a Redmine Project based on path components
  def getGbRedminePrjPath(group, project)
    return "/REST/v1/grp/#{CGI.escape(group)}/redminePrj/#{CGI.escape(project)}"
  end

  # Retrieve a Redmine project/Genboree group association
  # @see [ApiUriHelper#makeRequest]
  def getRedminePrj(redminePrjUrl)
    rv = nil
    if(REGEXPS[:redminePrj].match(redminePrjUrl))
      rv = makeRequest(:get, redminePrjUrl)
    else
      rv = getHelperRespObj
      rv[:msg] = "The URL #{redminePrjUrl.inspect} is not a URL for a Redmine Project"
    end
    return rv
  end

  # Remove a Redmine project/Genboree group association
  def deleteRedminePrj(redminePrjUrl)
    rv = nil
    if(REGEXPS[:redminePrj].match(redminePrjUrl))
      rv = makeRequest(:delete, redminePrjUrl)
    else
      rv = getHelperRespObj
      rv[:msg] = "The URL #{redminePrjUrl.inspect} is not a URL for a Redmine Project"
    end
    return rv
  end

  # }} -

  # --------------------------------------------------
  # Wiki - {{
  # --------------------------------------------------

  def getWikis(redminePrjUrl)
    rv = nil
    wikiIndexUrl = getWikiIndexUrlByPrjUrl(redminePrjUrl)
    if(!wikiIndexUrl.nil?)
      rv = makeRequest(:get, wikiIndexUrl)
    else
      rv = getHelperRespObj
      rv[:msg] = "The URL #{redminePrjUrl.inspect} is not a URL for a Redmine Project"
    end
    return rv
  end

  # Get a URL to a Redmine Project Wiki at a given @host@ based on path components
  def getWikiUrl(host, group, project, wiki)
    return "http://#{host}#{getWikiPath(group, project, wiki)}"
  end

  # Get a URL path to a Redmine Project Wiki based on path components
  def getWikiPath(group, project, wiki)
    return "#{getGbRedminePrjPath(group, project)}/wiki/#{CGI.escape(wiki)}.json"
  end

  # Get a URL to a Redmine Project Wiki based on a Redmine Project URL
  # @return [NilClass, String] a URL to the wiki belonging to the project at @prjUri@
  #   or nil if @prjUri@ is not actually a URI to a Redmine Project
  def getWikiUrlByPrjUrl(prjUri, wiki)
    rv = nil
    matchData = REGEXPS[:redminePrj].match(prjUri)
    if(matchData)
      prjUri = $1
      rv = "#{prjUri}/wiki/#{CGI.escape(wiki)}.json"
    end
    return rv
  end

  # Get a URL to the index of wikis in a Redmine Project
  def getWikiIndexUrlByPrjUrl(prjUri)
    getWikiUrlByPrjUrl(prjUri, "index")
  end

  # Get the Redmine Project Wiki object at @wikiUrl@
  # @see [ApiUriHelper#makeRequest]
  def getWiki(wikiUrl)
    rv = nil
    if(REGEXPS[:wiki].match(wikiUrl))
      rv = makeRequest(:get, wikiUrl)
    else
      rv = getHelperRespObj
      rv[:msg] = "The URL #{wikiUrl.inspect} is not a URL for a Redmine Project Wiki"
    end
    return rv
  end
  
  # Get the Redmine Project Wiki object at @wikiUrl@ or create it if it doesnt exist
  # @return [Hash] the wiki object at rv[:obj] wrapped with request context; see [ApiUriHelper#makeRequest] 
  def getOrCreateWiki(wikiUrl)
    rv = getWiki(wikiUrl)
    if(rv[:resp].respond_to?(:code) and rv[:resp].code == "404")
      # then we could not retrieve the wiki, make it
      matchData = REGEXPS[:redminePrj].match(wikiUrl) # succeeds if getWiki didnt error
      redminePrjUrl = matchData[1]
      matchData = REGEXPS[:wiki].match(wikiUrl) # succeeds if getWiki didnt error
      title = matchData[2]
      rv = createWikiWithTitle(redminePrjUrl, title)
    end
    return rv
  end

  # Update/create the Redmine Project Wiki at @wikiUrl@ to be @wikiObj@
  # @see [ApiUriHelper#makeRequest]
  def putWiki(wikiUrl, wikiObj)
    rv = nil
    if(REGEXPS[:wiki].match(wikiUrl))
      rv = makeRequest(:put, wikiUrl, wikiObj)
    else
      rv = getHelperRespobj
      rv[:msg] = "The URL #{wikiUrl.inspect} is not a URL for a Redmine Project Wiki"
    end
    return rv
  end

  # Upload a Wiki that belongs to a parent
  # @param [String] wikiUrl the wiki to upload content for
  # @param [String] text the text of the wiki
  # @param [Hash] parentObj the object containing an identifier to the parent
  # @return @see getHelperRespObj
  def putWikiTextAndParent(wikiUrl, text, parentObj)
    rv = getHelperRespObj
    parentId = parentObj.getNestedAttr("wiki_page.id")
    if(parentId.nil?)
      rv[:msg] = "Cannot access parent Wiki identifier from parentObj=#{parentObj.inspect}"
    else
      obj = {
        "wiki_page" => {
          "text" => text,
          "parent_id" => parentId
        }
      }
      rv = putWiki(wikiUrl, obj)
    end
    return rv
  end

  def createWikiWithTitle(redminePrjUrl, title)
    obj = {
      "wiki_page" => {
        "title" => title,
        "text" => "h1. #{title}"
      }
    }
    wikiUrl = getWikiUrlByPrjUrl(redminePrjUrl, title)
    putWiki(wikiUrl, obj)
  end

  # Set the @text@ of the Redmine Project Wiki at @wikiUrl@
  # @see [ApiUriHelper#makeRequest]
  def editWikiText(wikiUrl, text)
    obj = {
      "wiki_page" => { 
        "text" => text
      }
    }
    putWiki(wikiUrl, obj)
  end

  # @todo what if no wiki with the given parentId
  # @note all puts must have wiki page.text set in the payload object
  #   so we have to do this tedious get then put
  def setWikiParentById(wikiUrl, parentId)
    rv = nil
    respObj = getWiki(wikiUrl)
    if(respObj[:success])
      wikiObj = JSON.parse(respObj[:resp].body)['data']
      wikiObj['wiki_page']['parent_id'] = parentId
      rv = putWiki(wikiUrl, wikiObj)
    else
      # then respObj already has error set, reuse it
      rv = respObj
    end
    return rv
  end

  def unsetWikiParent(wikiUrl)
    setWikiParentById(wikiUrl, nil)
  end

  # @note will create parent if it does not exist
  def setWikiParentByTitle(wikiUrl, parentTitle)
    rv = nil
    if(REGEXPS[:wiki].match(wikiUrl))
      redminePrjUrl = extractPureUri(wikiUrl)
      parentWikiUrl = getWikiUrlByPrjUrl(redminePrjUrl, parentTitle)
      respObj = makeRequest(:get, parentWikiUrl)
      if(respObj[:success])
        # then parent wiki exists, get its id
        parentObj = JSON.parse(respObj[:resp].body)['data']
        parentId = parentObj['wiki_page']['id']

        # and update the wiki
        rv = setWikiParentById(wikiUrl, parentId)
      elsif(respObj[:resp].code == "404")
        # then parent wiki does not exist, make it
        respObj = createWikiWithTitle(wikiUrl, parentTitle)
        parentObj = JSON.parse(respObj[:resp].body)['data']
        parentId = parentObj['wiki_page']['id']

        # and update the wiki
        rv = setWikiParentById(wikiUrl, parentId)
      else
        # then some other error
        # @todo 
        rv = respObj
      end
    else
      rv = getHelperRespObj
      rv[:msg] = "The URL #{wikiUrl.inspect} is not a URL for a Redmine Project Wiki"
    end
    return rv
  end

  def deleteWiki(wikiUrl)
    if(REGEXPS[:wiki].match(wikiUrl))
      rv = makeRequest(:delete, wikiUrl)
    else
      rv = getHelperRespObj
      rv[:msg] = "The URL #{wikiUrl.inspect} is not a URL for a Redmine Project Wiki"
    end
    return rv
  end

  # }} -

  # --------------------------------------------------
  # Raw Content - {{
  # --------------------------------------------------

  # Get the URL for a rawcontent resource based on the URL components
  def getRawContentUrl(host, group, redminePrj, rawContentPath)
    return "http://#{host}#{getRawContentPath(group, redminePrj, rawContentPath)}"
  end

  # Get the URL path for a rawcontent resource based on the URL components
  # @note method name refers to (by convention) url path while argument refers to 
  #   a file in the raw content area
  def getRawContentPath(group, redminePrj, rawContentPath)
    validateRawContentPath(rawContentPath)
    escRawContentPath = escapePath(rawContentPath)
    return "/REST/v1/grp/#{CGI.escape(group)}/redminePrj/#{CGI.escape(redminePrj)}#{escRawContentPath}"
  end

  # Get the URL for a rawcontent based on a redminePrj url
  # @param [String] redminePrjUrl a URL to a Redmine Project
  # @param [String] rawContentPath the unescaped filepath of the raw content file
  # @return [String] the rawContentUrl or nil if arguments are invalid
  def getRawContentUrlByPrjUrl(redminePrjUrl, rawContentPath)
    rv = nil
    pathIsValid = (validateRawContentPath(rawContentPath) rescue nil).nil?
    if(pathIsValid and (matchData = REGEXPS[:redminePrj].match(redminePrjUrl)))
      escRawContentPath = escapePath(rawContentPath)
      redminePrjUrl = matchData[1] # removes query, terminal slash
      return "#{redminePrjUrl}/rawcontent#{escRawContentPath}"
    end
    return rv
  end

  # Verify a rawcontent filepath is valid
  # @param [String] rawContentPath the filepath of the rawcontent NOT a URL path
  # @raise subclass of ArgumentError if the rawContentPath is invalid
  # @todo resolve ambiguity in filepath versus URL path in variable name refereces "rawContentPath"
  def validateRawContentPath(rawContentPath)
    raise RedminePrjApiError.new("rawContentPath must begin with \"/\"") unless(rawContentPath[0..0] == "/")
  end

  # Get the contents of a Redmine raw content file
  # @param [String] rawContentUrl @see getRawContentUrl
  # @todo this is not the best way to retrieve large files, if the raw content resource starts being
  #   used for large files this should be revisited
  def getRawContent(rawContentUrl)
    rv = nil
    if(REGEXPS[:rawContent].match(rawContentUrl))
      rv = makeRequest(:get, rawContentUrl)
    else
      rv = getHelperRespObj
      rv[:msg] = "The URL #{rawContentUrl.inspect} is not a URL for a Redmine rawcontent file"
    end
    return rv
  end

  # Upload raw content data or modify an existing raw content data
  # @param [String] rawContentUrl @see getRawContentUrl
  # @param [IO] ioObj an IO object whose contents will be uploaded to the rawContentUrl
  # @note you probably will want to rewind your ioObj before calling this method but
  #   we do not enforce this for flexibility's sake
  def putRawContentIo(rawContentUrl, ioObj)
    rv = nil
    if(REGEXPS[:rawContent].match(rawContentUrl))
      rv = makeRequest(:put, rawContentUrl, ioObj, payloadIsJson=false)
    else
      rv = getHelperRespObj
      rv[:msg] = "The URL #{rawContentUrl.inspect} is not a URL for a Redmine rawcontent file"
    end
    return rv
  end

  # Upload raw content data with a file
  # @param [String] filepath the path to a file to upload
  # @see #putRawContentIo
  def putRawContentFile(rawContentUrl, filepath)
    rv = nil
    File.open(filepath) { |fh|
      rv = putRawContentIo(rawContentUrl, fh)
    }
    return rv
  end

  # Escape a rawContentPath for use in a URL
  def escapePath(rawContentPath)
    rawContentPath.split("/").map { |token| CGI.escape(token) }.join("/")
  end

  # }} -

end

class RedminePrjApiError < ArgumentError
end

end; end; end; end
