require 'brl/util/util'
require 'escape_utils'
require 'uri_template'
require 'brl/sites/geneReviews/geneReview'
require 'brl/genboree/kb/kbDoc'

module BRL ; module Genboree ; module KB ; module Helpers ; module Targeted
  # Create a very basic KbDoc from GeneReview raw XML or xmlHash (a la BRL::Sites::GeneReviews::GeneReview
  # To promote proper usage, new() is private ; use the factory methods to instantiate.
  class BasicGeneReviewKbDoc 
    URL_TEMPLATE = URITemplate.new('http://www.ncbi.nlm.nih.gov/pubmed/?term=GeneReviews[Book]+and+{grId}&report={rpt}')
    DEFAULT_OPTS = {}
    DOCID_CONF   =
      { :prop => 'GeneReview', :method => :simpleKeys, :keys => ['PubmedBookArticle', 'BookDocument', 'ArticleIdList', 'ArticleId' ] }
    SUBPROP_CONFS = [
      { :prop => 'PMID',              :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'PMID' ] },
      { :prop => 'Book Publisher',    :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'Book', 'Publisher', 'PublisherName' ] },
      { :prop => 'Book Title',        :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'Book', 'BookTitle' ] },
      { :prop => 'Book First Year',   :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'Book', 'BeginningDate', 'Year' ] },
      { :prop => 'Book Recent Year',  :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'Book', 'EndingDate', 'Year' ] },
      { :prop => 'Book Editors',      :method => :authors,    :keys => [ 'PubmedBookArticle', 'BookDocument', 'Book', 'AuthorList', 'Author' ] },
      { :prop => 'Book Medium',       :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'Book', 'Medium' ] },
      { :prop => 'Title',             :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'ArticleTitle' ] },
      { :prop => 'Language',          :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'Language' ] },
      { :prop => 'Authors',           :method => :authors,    :keys => [ 'PubmedBookArticle', 'BookDocument', 'AuthorList', 'Author' ] },
      { :prop => 'Type',              :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'PublicationType' ] },
      { :prop => 'Abstract',          :method => :labeledAbstract, :keys => [ 'PubmedBookArticle', 'BookDocument', 'Abstract', 'AbstractText' ] },
      { :prop => 'Copyright',         :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'Abstract', 'CopyrightInformation' ] },
      { :prop => 'Sections',          :method => :sections,   :keys => [ 'PubmedBookArticle', 'BookDocument', 'Sections', 'Section' ] },
      { :prop => 'Contribution Date', :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'ContributionDate' ] },
      { :prop => 'Revision Date',     :method => :simpleKeys, :keys => [ 'PubmedBookArticle', 'BookDocument', 'DateRevised' ] },
      { :prop => 'Grants',            :method => :grants,     :keys => [ 'PubmedBookArticle', 'BookDocument', 'GrantList', 'Grant' ] },
      { :prop => 'Synonyms',          :method => :items,      :keys => [ 'PubmedBookArticle', 'BookDocument', 'ItemList' ], :opts => { :listType => 'Synonyms' } },
      { :prop => 'Url-XML',           :method => :url,        :keys => [ 'PubmedBookArticle', 'BookDocument', 'ArticleIdList', 'ArticleId' ], :opts => { :type => :xml } },
      { :prop => 'Url-Page',          :method => :url,        :keys => [ 'PubmedBookArticle', 'BookDocument', 'ArticleIdList', 'ArticleId' ], :opts => { :type => :page }  }
    ]

    attr_accessor :xml
    attr_accessor :xmlHash
    attr_reader :kbDoc

    # FACTORY. Instantiate class from raw GeneReview XML.
    def self.fromXml(xml, opts={})
      raise ArgumentError, "ERROR: xml must be a non-empty String." unless(xml.is_a?(String) and xml =~/\S/)
      grKbDoc = new()
      grKbDoc.xml = xml
      grKbDoc
    end

    # FACTORY. Instantiate class from xmlHash, as produced by
    #   BRL::Sites::GeneReviews::GeneReview
    def self.fromXmlHash(xmlHash, opts={})
      raise ArgumentError, "ERROR: xmlHash must be a non-empty Hash, like Crack::XML produces from XML." unless(xmlHash.is_a?(Hash) and !xmlHash.empty?)
      grKbDoc = new()
      grKbDoc.xmlHash = xmlHash
      grKbDoc
    end

    # CLASS METHOD. Lists all the paths in the doc. Mainly for inspection/exploration.
    # @return [Array<String>] A list list of full paths that can be present in the KbDoc.
    #   Some may be missing if the XML record doesn't have them.
    def self.paths()
      paths = []
      docIdProp = DOCID_CONF[:prop]
      paths << docIdProp
      SUBPROP_CONFS.each { |conf|
        paths << "#{docIdProp}.#{conf[:prop]}"
      }
      return paths
    end

    # Get back a very simple and flat BRL::Genboree::KB::KbDoc version of the file.
    # @return [BRL::Genboree::KB::KbDoc] A simple, flat KbDoc representing the GeneReview record.
    #   Note all properties may be present. All values will be Strings.
    def as_kbDoc()
      sanityChecks()
      unless(@xmlHash) # then need to make an xmlHash from the xml we have
        # Create GeneReview object using already-available XML
        geneReview = BRL::Sites::GeneReviews::GeneReview.fromXml(@xml, @opts)
        @xmlHash = geneReview.retrieve
      end
      # Init the doc, setting root prop
      doc = initDoc()
      if(doc)
        # Add subprops
        rootProp = doc.getRootProp()
        SUBPROP_CONFS.each { |conf|
          begin
            prop = conf[:prop]
            val = extract(conf)
            if(prop and val and val.to_s =~ /\S/)
              doc.setPropVal("#{rootProp}.#{prop}", val)
            else
              $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Failed to find good val for #{conf[:keys].join(' => ')}. Found val = #{val.inspect}")
            end
          rescue => err
            $stderr.debugPuts(__FILE__, __method__, 'ERROR', "While looking to find val for #{conf[:keys].join(' => ')}. Error class: #{err.class} ; Error message: #{err.message} ; Error trace:\n#{err.backtrace.join("\n")}")
          end
        }

      end
      return doc
    end

    # ---------------------------------------------------------------
    # INTERNAL METHODS
    # ----------------------------------------------------------------

    # PRIVATE CONSTRUCTION new(). Use Factory constructors.
    class << self
      private :new
    end

    def initialize(opts={})
      @opts = DEFAULT_OPTS.merge(opts)
      @xml = @xmlHash = @kbDoc = nil
    end



    def sanityChecks()
      unless( (@xmlHash.is_a?(Hash) and !@xmlHash.empty?) or (@xml.is_a?(String) and @xml =~/\S/) )
        raise ArgumentError, "ERROR: must have set xmlHash to a Hash (like that produced by Crack::XML) or have set raw xml to a non-empty String."
      end
    end

    def initDoc()
      @kbDoc = BRL::Genboree::KB::KbDoc.new({})
      docIdVal = extract(DOCID_CONF)
      if(docIdVal)
        @kbDoc.setPropVal( DOCID_CONF[:prop], docIdVal )
      else
        @kbDoc = nil
        $stderr.debugPuts(__FILE__, __method__, 'ERROR', "Could not extract docId using expected keys: #{DOCID_CONF[:keys].join(" => ")}.")
      end
      return @kbDoc
    end

    def extract(extractConf)
      return self.send(extractConf[:method], extractConf[:keys], @xmlHash, extractConf[:opts])
    end

    def simpleKeys(keys, root, opts={})
      subdoc = root
      keys.each { |key|
        begin
          subdoc = subdoc[key]
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "No such key #{key.inspect} at this point. subdoc is:\n\n#{subdoc.inspect}\n\n")
          subdoc = nil
          break
        end
      }
      return subdoc
    end

    def authors(keys, root, opts={})
      retVal = ''
      # Get the array of  objects
      xmlAuthors = simpleKeys(keys, root, opts)
      if(xmlAuthors)
        xmlAuthors = [ xmlAuthors ] if(xmlAuthors.is_a?(Hash)) # if only 1, array-ize
        xmlAuthors.each { |xmlAuthor|
          retVal << "#{xmlAuthor['Initials']} #{xmlAuthor['LastName']}, "
        }
        retVal.strip!
        retVal.chomp!(',')
      end

      return retVal
    end

    def sections(keys, root, opts={})
      retVal = ''
      # Get the array of objects
      xmlSections = simpleKeys(keys, root, opts)
      if(xmlSections)
        xmlSections = [ xmlSections ] if(xmlSections.is_a?(Hash)) # if only 1, array-ize
        xmlSections.each { |xmlSection|
          retVal << "#{xmlSection['SectionTitle']}, "
        }
        retVal.strip!
        retVal.chomp!(',')
      end

      return retVal
    end

    def grants(keys, root, opts={})
      retVal = ''
      # Get the array of objects
      xmlGrants = simpleKeys(keys, root, opts)
      if(xmlGrants)
        xmlGrants = [ xmlGrants ] if(xmlGrants.is_a?(Hash)) # if only 1, array-ize
        xmlGrants.each { |xmlGrant|
          retVal << "#{xmlGrant['GrantId']}, #{xmlGrant['Agency']}, #{xmlGrant['Country']}; "
        }
        retVal.strip!
        retVal.chomp!(';')
      end

      return retVal
    end

    def labeledAbstract(keys, root, opts={})
      retVal = ''
      # Get the array of objects
      xmlAbstractTexts = simpleKeys(keys, root, opts)
      if(xmlAbstractTexts)
        xmlAbstractTexts = [ xmlAbstractTexts ] if(xmlAbstractTexts.is_a?(Hash)) # if only 1, array-ize
        xmlAbstractTexts.each { |xmlAbstractText|
          if(xmlAbstractText.respond_to?(:attributes))
            attrs = xmlAbstractText.attributes
            label = attrs['Label']
          else
            label = nil
          end
          label = '[Unlabeled]' if(label.nil?)
          retVal << "#{label}: #{xmlAbstractText} "
        }
        retVal.strip!
      end

      return retVal
    end

    def items(keys, root, opts={})
      retVal = ''
      listType = opts[:listType]
      # Get the array of objects
      xmlItemLists = simpleKeys(keys, root, opts)
      if(xmlItemLists)
        xmlItemLists = [ xmlItemLists ] if(xmlItemLists.is_a?(Hash)) # if only 1, array-ize
        xmlItemLists.each { |xmlItemList|
          if(xmlItemList['ListType'] == listType)
            items = xmlItemList['Item']
            items = [ items ] unless(items.is_a?(Array))
            retVal = items.join('; ')
            break
          end
        }
        retVal.strip!
        retVal.chomp!(';')
      end

      return retVal
    end

    def url(keys, root, opts={})
      subdoc = root
      docIdVal = simpleKeys(keys, root, opts)
      rpt = (opts[:type] == :xml ? 'xml' : 'abstract')
      urlVal = URL_TEMPLATE.expand(:grId => docIdVal, :rpt => rpt)
      return urlVal
    end
  end
end ; end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers ; module Targeted
