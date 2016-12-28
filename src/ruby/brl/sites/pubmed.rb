require 'nokogiri'
require 'open-uri'
require 'brl/sites/abstractSite'
require 'brl/sites/doi'

module BRL; module Sites

  # @todo proxy and url construction could be reused from bioOntology, since its
  # not clear if Pubmed will be cached, defer for now
  class Pubmed < AbstractSite

    HOST = "www.ncbi.nlm.nih.gov"
    DEFAULT_QUERY = {"report" => "medline", "format" => "text"}

    # map medline codes to ruby symbols (more readable, english names)
    # @see https://www.nlm.nih.gov/bsd/mms/medlineelements.html
    MEDLINE_MAP = {
      "AB" => :abstract,
      "AD" => :affiliation,
      "AID" => :articleId,
      "AU" => :name,
      "DP" => :publicationDate,
      "GR" => :grants,
      "IP" => :issueNumber,
      "JT" => :journalTitle,
      "LID" => :locationId,
      "MH" => :meshHeadings,
      "OID" => :ontologyId, # @todo :otherId
      "OTO" => :ontologyName, # @todo :otherTermOwner
      "OT" => :ontologyTerms, # @todo :otherTerm
      "PG" => :pages,
      "PMC" => :pmcid,
      "PMID" => :pmid,
      "TA" => :journalAbbrv,
      "TI" => :title,
      "VI" => :volumeNumber
    }

    # @see https://www.nlm.nih.gov/bsd/mms/medlineelements.html
    # @return The list of supported keys. Can retrieve values for these via pubmedObj[:fieldSymbol] following instantiation.
    FIELD_LIST = {
      :abstract => "The article's abstract",
      :articleId => "Identifier of the Pubmed Record in the publisher's system",
      :authorList => "Author list as Array of Hash records which give author name AND affiliation.",
      :authorsStr => "Comma-separated list of authors in form: Last FM, Last FM, Last FM",
      :citationStr => "Full article citation string or 'reference', suitable for bibliographies and such.",
      :issueNumber => "The issue in which the article was published",
      :journalStr => "Journal abbreviation plus issue, volume, pages information as a nice string.",
      :journalTitle => "The title of the journal itself (full journal name).",
      :journalAbbrv => "The standard journal abbreviation.",
      :locationId => "The DOI number, if available (may not be for non-US publications).",
      :ontologyList  => "Hash of ontology Hash records providing ontologyID, name, and matching term list.",
      :pages => "The pages where the article appears",
      :pmid => "PMID as returned from Pubmed service. String. Separate from @pmid, which is the value you set for this object.",
      :publicationDate => "When the article was published, as a string",
      :title => "The title of the article",
      :volumeNumber => "The volume in which the article was published."
    }

    # collect fields into nested objects, implying a coupling of 2 or more fields
    # values MUST be the same as those in MEDLINE_MAP
    # symbols belonging to keys are those fields that are sufficient to trigger creation of
    #   a new nested object; those belonging to items may appear multiple times in one nested object
    BRL_NEST = {
      :authorList => {
        :keys => [:name, :affiliation],
        :items => []
      },
      :ontologyList => {
        :keys => [:ontologyId, :ontologyName],
        :items => [:ontologyTerms]
      }
    }

    medline_nest = {}
    BRL_NEST.each_key{|parent|
      children = BRL_NEST[parent][:keys] + BRL_NEST[parent][:items]
      children.each{|child|
        medline_nest[child] = parent
      }
    }
    MEDLINE_NEST = medline_nest

    # use KEYS to find out which fields are available
    KEYS = MEDLINE_MAP.collect{|code| MEDLINE_MAP[code]}

    attr_reader :pmid
    attr_reader :respBody
    attr_reader :parsedBody
    attr_accessor :debug

    def pmid=(pmid)
      @pmid = pmid
      @parsedBody = requestRecordsByPmid(pmid)
      return pmid
    end

    # @see parent for information on proxy caching
    def initialize(pmid, opts={})
      super(opts)
      @pmid = pmid
      @respBody = nil
      requestRecordsByPmid if(@pmid)
      @debug = false
    end

    # @return [String, nil]
    def rawRecord()
      return @respBody
    end

    # @return [Hash, nil] The raw pubmed record object, after parsing response from NLM
    def recordObj()
      retVal = nil
      if(@pmid)
        requestRecordsByPmid() unless(@parsedBody)
        retVal = @parsedBody
      end
      return retVal
    end

    # @param [Symbol] fieldKey The pubmed field you want the data for. Includes derived fields
    #   that combine info into useful/common strings like citations, author lists, etc. (@see keys)
    # @return [String, Object, nil] The value of the field, or nil if not available or no pubmed record.
    def [](fieldKey) # there is no []=() currently (ever?)
      retVal = nil
      if(@parsedBody)
        retVal =
          case fieldKey
          when :authorList, :ontologyList
            # Correct for non-uniform storage of authorList and ontologyList when only one author or inffo for 1 ontology, sigh.
            list = @parsedBody[fieldKey]
            ( list.is_a?(Array) ? list : (list.nil? ? list : [ list ]) )
          when :authorsStr
            authorListStr()
          when :citationStr
            citationStr()
          when :doi
            if(@parsedBody.key?(:articleId) and @parsedBody[:articleId].key?(:doi))
              @parsedBody[:articleId][:doi]
            else
              nil
            end
          when :doiPubUrl
            if(@parsedBody.key?(:articleId) and @parsedBody[:articleId].key?(:doi))
              DOI.resolverUrl(@parsedBody[:articleId][:doi])
            else
              nil
            end
          when :doiMetaUrl
            if(@parsedBody.key?(:articleId) and @parsedBody[:articleId].key?(:doi))
              DOI.metaUrl(@parsedBody[:articleId][:doi])
            else
              nil
            end
          when :ontologyStr
            ontList = self[:ontologyList]
            retVal = ( ontList.nil? ? nil : ontologyListStr(ontList) )
          when :url
            buildUrl(HOST, buildPath(@pmid), {}, false) # query={}, proxy=false
          when :journalStr
            journalStr()
          else
            @parsedBody[fieldKey]
          end
      end
    end

    # @return the list of known keys.
    def keys(descMap=false)
      return (descMap ? FIELD_LIST : FIELD_LIST.keys)
    end

    # ------------------------------------------------------------------
    # HELPERS - Mainly for internal use by this class's methods
    # ------------------------------------------------------------------

    # Get information from HOST about a publication given by a pubmed ID
    # @param [String, Fixnum] pmid the pubmed ID to get records for
    # @return [nil, Hash<Symbol, String|Array>] brl symbols for associated medline
    #   fields mapped to value(s) for that field (see @note) or nil if error
    # @note medline records either have a new code or are a continuation of a previous
    #   code, if the new code is the same as a previous code, @parsedBody will contain
    #   an array for the associated brlSym (e.g. abstract contains many lines
    #   of text but only a single string mapped at brlSym, but author contains many
    #   records and has an array mapped at brlSym)
    def requestRecordsByPmid(pmid=@pmid)
      retVal = nil
      begin
        if(@parsedBody and @parsedBody[:pmid] and (@parsedBody[:pmid].to_s.strip() == @pmid))
          retVal = @parsedBody
        else
          url = buildUrl(HOST, buildPath(pmid), DEFAULT_QUERY)
          respSize = get(url)
          retVal = parse()
        end
      rescue => err
        retVal = nil
        logError(err)
      end
      return retVal
    end

    # Compose a string representing author information
    # @return [NilClass, String] composed string with author information or nil if no authors
    def authorListStr(authorList=@parsedBody[:authorList])
      retVal = nil
      begin
        authorList = [ authorList ] unless(authorList.is_a?(Array))
        unless(authorList.nil?)
          authorNames = authorList.collect{ |hh| hh[:name] }
          retVal = authorNames.join(", ")
        end
      rescue => err
        retVal = nil
        logError(err)
      end
      return retVal
    end

    # Compose a string represnting journal information based on "summary (text)"
    # format from pubmed, e.g. Proc Natl Acad Sci U S A. 2014 Jul 29;111(30):11151-6.
    # @param [Hash] parsedBody @see parseRespBody
    # @return [String] composed string with journal information
    # @todo transform symbols into constants?
    def journalStr(parsedBody=@parsedBody)
      retVal = nil
      begin
        journal = parsedBody[:journalAbbrv]
        date = parsedBody[:publicationDate]
        issue = parsedBody[:issueNumber]
        volume = parsedBody[:volumeNumber]
        pages = parsedBody[:pages]
        if(journal)
          retVal = journal
          if(date)
            retVal += ". #{date}"
            if(issue)
              retVal += ";#{issue}"
              if(volume)
                retVal += "(#{volume})"
                if(pages)
                  retVal += ":#{pages}"
                end
              end
            end
          end
        end
      rescue => err
        retVal = nil
        logError(err)
      end
      return retVal
    end

    # Compose a string representing a reference to an article
    # @param [Hash] parsedBody @see parseRespBody
    # @note assumes @parsedBody is set (by parseRespBody)
    def citationStr(parsedBody=@parsedBody)
      retVal = nil
      begin
        authorComp = authorListStr(parsedBody[:authorList])
        titleComp = parsedBody[:title]
        journalComp = journalStr(parsedBody)
        refComps = [authorComp, titleComp, journalComp]
        refComps.delete_if{|comp| comp.nil?}
        refComps.each{|comp| comp.chop!() if(comp[-1..-1] == ".")}
        refStr = refComps.join(". ")
        unless(refStr.empty?)
          retVal = refStr + "."
        end
      rescue => err
        retVal = nil
        logError(err)
      end
      return retVal
    end

    # Compose a string of the ontologyList nested object ("{}" and "..." for templating, everything else literal):
    #   [{ontologyId}] {ontologyTerm}, {ontologyTerm}, ... ; [{ontologyId}] {ontologyTerm}, ...
    def ontologyListStr(ontologyList=self.[](:ontologyList))
      retVal = nil
      ontComps = ontologyList.map { |ontologyItem|
        "[#{ontologyItem[:ontologyId]}] #{ontologyItem[:ontologyTerms].join(", ")}"
      }
      retVal = (ontComps.empty? ? nil : ontComps.join(" ; "))
      retVal.strip!
      return retVal
    end

    # -----------------------------------------------------------------------------------

    # Construct URL path based on pubmed id
    # @param [String] pmid the pubmed id to construct path for
    # @return [String] url path (beginning with '/')
    def buildPath(pmid=@pmid)
      retVal = "/pubmed/#{pmid}"
      return retVal
    end

    # Provide wrapper around open-uri#open to handle errors if needed
    # @param [String] url the url to open
    # @return [Fixnum] size of response body
    # @note response body is acessible through @respBody
    def get(url, headers={})
      @respBody = ''
      url.gsub!("http://", "https://")
      $stderr.debugPuts(__FILE__, __method__, "PUBMED", "making request at #{url}")
      open(url, headers){|ff|
        @respBody = ff.read()
      }
      return @respBody.size
    end

    def createNestedObj(parent_key)
      child_keys = BRL_NEST[parent_key][:keys]
      child_items = BRL_NEST[parent_key][:items]
      # then setup nested object
      # @todo this implementation only provides 1 level of nesting
      nestedObj = {}
      child_keys.each{|child_key|
        nestedObj[child_key] = nil
      }

      child_items.each{|child_item|
        nestedObj[child_item] = []
      }
      return nestedObj
    end

    def commitNestedObj!(parsedBody, nestedObjs, parent_key)
      nestedObj = nestedObjs.delete(parent_key)
      if(parsedBody.key?(parent_key))
        parsedBody[parent_key] = [parsedBody[parent_key]] unless(parsedBody[parent_key].is_a?(Array))
        parsedBody[parent_key].push(nestedObj)
      else
        parsedBody[parent_key] = nestedObj
      end
      return nestedObj
    end

    # First parse a MEDLINE record into a naive intermediate form, then perform any further field specific parsing
    # MEDLINE is a flat, line-based representation of data. Note three types of data
    # 
    # (1) Data appears as a field id and the field value over one or more lines e.g. the "abstract" field:
    #   AB  - BACKGROUND: Interactions between the epigenome and structural genomic variation
    #         are potentially bi-directional. In one direction, structural variants may cause 
    #         ...
    # These are parsed into a simple string: @parsedBody[:abstract] == "BACKGROUND: ..."
    #
    # (2) Some data fields may appear multiple times e.g. the article subject MeSH terms:
    #   MH - Adult
    #   MH - Cardiovascular Diseases/etiology/*mortality
    #   ...
    # These are parsed into an array of strings: @parsedBody[:mesh] == ["Adult", "Cardio..."]
    #
    # (3) And some data are best considered as objects with multiple related fields appearing together in subsequent lines
    # e.g. author-related fields:
    #   AU - Foa EB
    #   AD - Department of Anesthesiology, University of Virginia Health Sciences Center Charlottesville 22908, USA. med2p@virginia.edu
    #   AU - Smith AB 3rd
    #   AD - Departamento de Farmacologia, Facultad de Medicina, Universidad Complutense de Madrid (UCM), 28040 Madrid, Spain.
    #   ...
    # These are parsed into an object @parsedBody[:authorList] == [ 
    #   {:name => "Foa EB", :affiliation => "Department..."},
    #   {:name => "Smith AB 3rd", :affiliation => "Departamento..."},
    #   ...
    # ]
    # sets @parsedBody
    # @return [Hash] records whose keys are given in KEYS
    # @see requestRecordsByPmid
    def parse()
      # parse medline records into 
      @parsedBody = parseRespBody()
      @parsedBody[:articleId] = parseArticleId(@parsedBody[:articleId])
      return @parsedBody
    end

    # Parse @respBody, a mildly wrapped xml document of medline records
    # @see parse
    def parseRespBody()
      maxSplitColumn = 4 # medline records with a code have a dash in the 5th column
      @parsedBody = {}

      # parse xml into medlineRec lines
      htmlDoc = Nokogiri::XML(@respBody)
      medlineStr = ''
      htmlDoc.xpath("//pre").each{|ii| medlineStr += "\n" + ii.content}
      medlineRecs = medlineStr.split("\n")

      # check for errors
      # based on observation of error response body like:
      #   id: 25141396 Error occurred: The following PMID is not available: 25141396
      smallRespSize = 5
      if(medlineRecs.size <= smallRespSize)
        if(/Error occurred/.match(medlineStr))
          raise PubmedError.new("Error reported by Pubmed: #{medlineStr}")
        end
      end

      # @see requestRecordsByPmid for explanation of medlineRec procesing logic
      prevCode = "" # for multi-line records, code is not reprinted
      newCode = false # if a code appears multiple times, treat as separate records instead of multi-line records
      ii = 0
      nestedObjs = {}
      medlineRecs.each{|medlineRec|
        # split on the first dash, extracting text and code
        text = nil
        code = nil
        splitIndex = medlineRec.index("-")
        if(splitIndex and splitIndex <= maxSplitColumn)
          code = medlineRec[0...splitIndex].strip()
          text = medlineRec[splitIndex+1...medlineRec.length].strip()
          newCode = true
        else
          code = (prevCode.empty? ? nil : prevCode)
          text = medlineRec.strip()
          newCode = false
        end
        if(code)
          brlSym = (MEDLINE_MAP.key?(code) ? MEDLINE_MAP[code] : code.upcase().to_sym())
        end
        if(code and text)
          # then process the record
          if(MEDLINE_NEST.key?(brlSym))
            # then this record belongs to a nested object, handle differently
            parent_key = MEDLINE_NEST[brlSym]

            # create new nested object if necessary
            unless(nestedObjs.key?(parent_key))
              nestedObjs[parent_key] = createNestedObj(parent_key)
            end

            # commit a nested object
            if(nestedObjs.key?(parent_key) and !nestedObjs[parent_key][brlSym].nil? and
               newCode and BRL_NEST[parent_key][:keys].include?(brlSym))
              # i.e. when we have seen ANY of the "keys" twice, its time to
              # commit the nested object and start fresh
              # then destroy existing nested object and commit it
              nestedObj = commitNestedObj!(@parsedBody, nestedObjs, parent_key)
              nestedObjs[parent_key] = createNestedObj(parent_key)
            end

            # create/append to child objects
            if(BRL_NEST[parent_key][:keys].include?(brlSym))
              if(nestedObjs[parent_key][brlSym].nil?)
                nestedObjs[parent_key][brlSym] = text
              elsif(nestedObjs[parent_key][brlSym].is_a?(String))
                nestedObjs[parent_key][brlSym] += " #{text}"
              else
                $stderr.debugPuts(__FILE__, __method__, "DEBUG", "unrecognized class of #{nestedObjs[parent_key][brlSym].class} for line #{ii}")
              end
            elsif(BRL_NEST[parent_key][:items].include?(brlSym))
              # then key is initialized to an array
              nestedObjs[parent_key][brlSym].push(text)
            else
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "#{brlSym} does not belong to :keys or :items of #{nestedObjs[parent_key]} for line #{ii}!")
            end

          else
            # then this record is not nested, use default behavior
            if(@parsedBody.key?(brlSym))
              if(newCode)
                @parsedBody[brlSym] = [@parsedBody[brlSym]] unless(@parsedBody[brlSym].is_a?(Array))
                @parsedBody[brlSym].push(text)
              else
                if(@parsedBody[brlSym].is_a?(Array))
                  @parsedBody[brlSym][-1] += " #{text}"
                elsif(@parsedBody[brlSym].is_a?(String))
                  @parsedBody[brlSym] += " #{text}"
                else
                  $stderr.debugPuts(__FILE__, __method__, "DEBUG", "unrecognized class of #{@parsedBody[brlSym].class} for line #{ii}")
                end
              end
            else
              @parsedBody[brlSym] = text
            end
          end
          prevCode = code
        end
        ii += 1
      }
      # commit any remaining nested objects
      nestedObjs.keys().each{|parent_key|
        nestedObj = commitNestedObj!(@parsedBody, nestedObjs, parent_key)
      }
      return @parsedBody
    end

    # Transform intermediate representation of articleId (AID) fields to final parsed result
    #   AID - S0272-7358(05)00023-1 [pii]
    #   AID - 10.1016/j.cpr.2005.02.002 [doi]
    #   AID - NBK7050 [bookaccession]
    # @param [Array<String>] contents of AID tags in Medline records (after parseRespBody)
    # @return [Hash] map of article ids by type:
    #   [String] :doi the doi number
    #   [String] :pii the publisher identifier number
    #   [Array<String>] :other any other article identifiers
    # @see parse
    def parseArticleId(aids)
      rv = { :doi => nil, :pii => nil, :other => [] }
      doiRe = /(.*)\s*\[doi\]/
      piiRe = /(.*)\s*\[pii\]/ # dont know if some piis have spaces in them, leave match generic
      aids.each { |aid|
        if(doiRe.match(aid))
          rv[:doi] = $1.strip
        elsif(piiRe.match(aid))
          rv[:pii] = $1.strip
        else
          rv[:other].push(aid)
        end
      }
      return rv
    end

    # Log errors that may occur while making requests to HOST
    # @param [Object] err
    # @return [NilClass]
    def logError(err)
      begin
        $stderr.debugPuts(__FILE__, __method__, "PUBMED_ERROR", "err.class=#{err.class}")
        $stderr.debugPuts(__FILE__, __method__, "PUBMED_ERROR", "message=#{err.message}")
        $stderr.debugPuts(__FILE__, __method__, "PUBMED_ERROR", "backtrace=\n#{err.backtrace.join("\n")}")
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "PUBMED_ERROR", "an error occured while logging a previous error!")
      end
      return nil
    end
  end
  class PubmedError < RuntimeError; end;
end; end
