require 'nokogiri'
require 'json'
require 'brl/util/util'
require 'brl/genboree/kb/kbDoc'

module BRL ; module Genboree ; module KB ; module Helpers ; module Targeted
  # Create a very basic KbDoc from GeneReview raw XML or xmlHash (a la BRL::Sites::GeneReviews::GeneReview
  # To promote proper usage, new() is private ; use the factory methods to instantiate.
  class BasicOrphanetKbDoc
    DEFAULT_OPTS = { :dataVersion => nil }
    XML_STR_KEYS = [ 'Clinical Signs', 'Disorders', 'Epidemiology - Age of Onset and Death', 'Epidemiology - Prevalences', 'Genes Associations', 'Linear Classification' ]
    ROOT_PROP = 'Orphanet'
    DATA_VERSION_PROP = 'Orphanet.Data Version'
    # Some Orphanet records talk about OrphaNumbers that don't exist in the actual Disorders record set.
    # - To deal with that, we'll try to dig up disorder info from the VARIOUS record sections, starting with
    #   'Disorders' (if present) and then others in order of likelihood of having this common info.
    COMMON_DISORDER_INFO = {
      :xmlDataKeys => [ 'Disorders', 'Linear Classification', 'Epidemiology - Prevalences', 'Epidemiology - Age of Onset and Death', 'Clinical Signs' ],
      :disorderInfoConfs => [
        { :prop => 'Name',          :xmlDataKey => :any, :method => :cssText,  :css => 'Disorder > Name' },
        { :prop => 'Url-Page',      :xmlDataKey => :any, :method => :cssText,  :css => 'Disorder > ExpertLink' },
        { :prop => 'Disorder Type', :xmlDataKey => :any, :method => :cssText,  :css => 'Disorder > DisorderType > Name' },
        { :prop => 'Synonyms',      :xmlDataKey => 'Disorders', :method => :section,  :subItems => {
            :item => 'Synonym', :itemsCss => 'Disorder > SynonymList > Synonym', :itemIdCss => :text } }
      ]
    }
    # Build up kbDoc by extracting this info for each disorder
    SUBPROP_CONFS = [
      { :prop => 'Clinical Signs',  :xmlDataKey => 'Clinical Signs', :method => :section, :subItems => {
          :item => 'Sign', :itemsCss => 'Disorder > DisorderSignList > DisorderSign', :itemIdCss => 'ClinicalSign > Name', :subProps => [
            { :prop => 'Frequency', :method => :cssText, :css => 'SignFreq > Name' }
          ] }
      },
      # This needs special treatment. For generic disorders, it currently extracts 1000s of subordinate disorder for which it is the parent.
      # { :prop => 'Classifications', :xmlDataKey => 'Linear Classification', :method => :section, :subItems => {
      #     :item => 'Classification', :itemsCss => 'Disorder > DisorderDisorderAssociationList > DisorderDisorderAssociation', :itemIdCss => 'Name', :opts => { :emptyId => :skip } }
      # },
      { :prop => 'Epidemiology',  :xmlDataKey => 'Epidemiology - Prevalences', :method => :section, :subProps => [
          { :prop => 'Prevalences', :method => :section, :subItems => {
              :item => 'Prevalence ID', :itemsCss => 'Disorder > PrevalenceList > Prevalence', :itemIdCss => [ { :css => :root, :attr => 'id' }, { :css => 'PrevalenceClass', :attr => 'id', :prefix => 'Qualification ID ' } ], :opts => { :emptyId => :skip }, :subProps => [
                  { :prop => 'Prevalence',    :method => :cssText, :css => 'PrevalenceClass > Name' },
                  { :prop => 'Type',          :method => :cssText, :css => 'PrevalenceType > Name' },
                  { :prop => 'Qualification', :method => :cssText, :css => 'PrevalenceQualification > Name' },
                  { :prop => 'Geographic',    :method => :cssText, :css => 'PrevalenceGeographic > Name' },
                  { :prop => 'Status',        :method => :cssText, :css => 'PrevalenceValidationStatus > Name' }
                ]
              }
          }
        ]
      },
      { :prop => 'Epidemiology',  :xmlDataKey => 'Epidemiology - Age of Onset and Death', :method => :section, :subProps => [
          { :prop => 'Ages of Onset and Death', :method => :section, :subProps => [
              { :prop => 'Ages of Onset', :method => :section, :subItems => {
                  :item => 'Average Age of Onset', :itemsCss => 'Disorder > AverageAgeOfOnsetList > AverageAgeOfOnset', :itemIdCss => 'Name', :opts => { :emptyId => :skip } }
              },
              { :prop => 'Ages of Death', :method => :section, :subItems => {
                  :item => 'Average Age of Death', :itemsCss => 'Disorder > AverageAgeOfDeathList > AverageAgeOfDeath', :itemIdCss => 'Name', :opts => { :emptyId => :skip } }
              }
            ]
          },
          { :prop => 'Types of Inheritance', :method => :section, :subItems => {
              :item => 'Type of Inheritance', :itemsCss => 'Disorder > TypeOfInheritanceList > TypeOfInheritance', :itemIdCss => 'Name', :opts => { :emptyId => :skip } }
          }
        ]
      },
      { :prop => 'Gene Associations', :xmlDataKey => 'Gene Associations', :method => :complex, :opts => { :complexMethod => :geneAssociations } }
    ]
    PATHS = [
      'Orphanet',
      'Orphanet.Name',
      'Orphanet.Synonyms',
      'Orphanet.Synonyms.Synonym',
      'Orphanet.Url-Page',
      'Orphanet.Clinical Signs',
      'Orphanet.Clinical Signs.Sign',
      'Orphanet.Clinical Signs.Sign.Frequency',
      'Orphanet.Disorder Type',
      'Orphanet.Epidemiology',
      'Orphanet.Epidemiology.Ages of Onset and Death',
      'Orphanet.Epidemiology.Ages of Onset and Death.Ages of Death',
      'Orphanet.Epidemiology.Ages of Onset and Death.Ages of Death.Average Age of Death',
      'Orphanet.Epidemiology.Ages of Onset and Death.Ages of Onset',
      'Orphanet.Epidemiology.Ages of Onset and Death.Ages of Onset.Average Age of Onset',
      'Orphanet.Epidemiology.Prevalences',
      'Orphanet.Epidemiology.Prevalences.Prevalence',
      'Orphanet.Epidemiology.Prevalences.Prevalence.Geographic',
      'Orphanet.Epidemiology.Prevalences.Prevalence.Qualification',
      'Orphanet.Epidemiology.Prevalences.Prevalence.Status',
      'Orphanet.Epidemiology.Prevalences.Prevalence.Type',
      'Orphanet.Epidemiology.Types of Inheritance',
      'Orphanet.Epidemiology.Types of Inheritance.Type of Inheritance',
      'Orphanet.Gene Associations',
      'Orphanet.Gene Associations.Gene',
      'Orphanet.Gene Associations.Gene.Associations',
      'Orphanet.Gene Associations.Gene.Associations.Association',
      'Orphanet.Gene Associations.Gene.Associations.Association.Status',
      'Orphanet.Gene Associations.Gene.Loci',
      'Orphanet.Gene Associations.Gene.Loci.Locus',
      'Orphanet.Gene Associations.Gene.Name',
      'Orphanet.Gene Associations.Gene.Synonyms',
      'Orphanet.Gene Associations.Gene.Synonyms.Synonym',
      'Orphanet.Gene Associations.Gene.Type'
    ]
    MODEL_TSV = "#name\tdomain\tdefault\titem list\trequired\tunique\tidentifier\tindex\tcategory\tfixed\tNotes\tIs Facet?\tConcept\tJSON-LD Flag\tRelation to Object\tObject Type\tcomments\nOrphanet\tstring\t\t\tTRUE\tTRUE\tTRUE\tTRUE\n- Name\tstring\t\t\tTRUE\t\t\tTRUE\n- Url-Page\turl\n- Disorder Type\tstring\n* Synonyms\t[valueless]\t\tTRUE\t\t\t\t\tTRUE\tTRUE\n*- Synonym\tstring\t\t\tTRUE\tTRUE\tTRUE\tTRUE\n* Clinical Signs\t[valueless]\t\tTRUE\t\t\t\t\tTRUE\tTRUE\n*- Sign\tstring\t\t\tTRUE\tTRUE\tTRUE\tTRUE\n*-- Frequency\tstring\n- Epidemiology\t[valueless]\t\t\t\t\t\t\tTRUE\tTRUE\n-- Ages of Onset and Death\t[valueless]\t\t\t\t\t\t\tTRUE\tTRUE\n--* Ages of Death\t[valueless]\t\tTRUE\t\t\t\t\tTRUE\tTRUE\n--*- Average Age of Death\tstring\t\t\tTRUE\tTRUE\tTRUE\n--* Ages of Onset\t[valueless]\t\tTRUE\t\t\t\t\tTRUE\tTRUE\n--*- Average Age of Onset\tstring\t\t\tTRUE\tTRUE\tTRUE\n-* Prevalences\t[valueless]\t\tTRUE\t\t\t\t\tTRUE\tTRUE\n-*- Prevalence ID\tstring\t\t\tTRUE\tTRUE\tTRUE\n-*-- Prevalence\tstring\n-*-- Geographic\tstring\n-*-- Qualification\tstring\n-*-- Status\tstring\n-*-- Type\tstring\n-* Types of Inheritance\t[valueless]\t\tTRUE\t\t\t\t\tTRUE\tTRUE\n-*- Type of Inheritance\tstring\t\t\tTRUE\tTRUE\tTRUE\n* Gene Associations\t[valueless]\t\tTRUE\t\t\t\t\tTRUE\tTRUE\n*- Gene\tstring\t\t\tTRUE\tTRUE\tTRUE\n*-- Name\tstring\n*-- Type\tstring\n*-* Synonyms\t[valueless]\t\tTRUE\t\t\t\t\tTRUE\tTRUE\n*-*- Synonym\tstring\t\t\tTRUE\tTRUE\tTRUE\n*-* Loci\t[valueless]\t\tTRUE\t\t\t\t\tTRUE\tTRUE\n*-*- Locus\tstring\t\t\tTRUE\tTRUE\tTRUE\n*-* Associations\t[valueless]\t\tTRUE\t\t\t\t\tTRUE\tTRUE\n*-*- Association\tstring\t\t\tTRUE\tTRUE \tTRUE\n*-*-- Status\tstring\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t"

    attr_reader :orphaNum
    attr_accessor :xmlStrHash
    attr_reader :kbDoc

    # FACTORY. Instantiate class from a Hash of XML Strings, as provided by
    #   BRL::Sites::Orphanet::OrphanetImporterExporter#orphaData
    def self.fromXmlStrHash(orphaNum, xmlStrHash, opts={})
      raise ArgumentError, "ERROR: xmlStrHash must be a non-empty Hash have some or all of the expected keys (#{XML_STR_KEYS.join(', ')}) mapped to the relevant XML string (note that 'Disorders' is required). xmlStrHash class: #{xmlStrHash.class} ; xmlStrHash keys: #{xmlStrHash.keys.inspect}" unless( xmlStrHash.is_a?(Hash) and !xmlStrHash.empty?) # and xmlStrHash.key?('Disorders'))
      onKbDoc = new(orphaNum, opts)
      onKbDoc.xmlStrHash = xmlStrHash
      onKbDoc
    end

    # CLASS METHOD. Lists all the paths in the doc. Mainly for inspection/exploration.
    # @todo implement this
    # @return [Array<String>] A list list of full paths that can be present in the KbDoc.
    #   Some may be missing if the XML record doesn't have them.
    def self.paths()
      return PATHS
    end

    def self.model()
      require 'brl/genboree/kb/converters/nestedTabbedModelConverter'
      converter = BRL::Genboree::KB::Converters::NestedTabbedModelConverter.new()
      return converter.parse(MODEL_TSV)
    end

    # Get back a very simple and flat BRL::Genboree::KB::KbDoc version of the file.
    # @return [BRL::Genboree::KB::KbDoc] A simple, flat KbDoc representing the GeneReview record.
    def as_kbDoc()
      # Init the doc, setting root prop
      doc = initDoc()
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Init Doc:\n\n#{JSON.pretty_generate(doc)}")
      if(doc)
        # Add subprops
        rootProp = doc.getRootProp()
        SUBPROP_CONFS.each { |conf|
          begin
            prop = conf[:prop]
            extract(conf, rootProp)
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Done adding #{prop.inspect} to #{rootProp.inspect} ; Doc Now: :\n\n#{JSON.pretty_generate(doc)}\n\n----------- END DOC ------------")
          rescue => err
            $stderr.debugPuts(__FILE__, __method__, 'ERROR', "While filling content for #{prop.inspect} to #{rootProp.inspect}. Error class: #{err.class} ; Error message: #{err.message} ; Error trace:\n#{err.backtrace.join("\n")}")
          end
        }

      end
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "DONE DOC: :\n\n#{JSON.pretty_generate(doc)}\n\n----------- END DOC ------------")
      return doc
    end

    # ---------------------------------------------------------------
    # INTERNAL METHODS
    # ----------------------------------------------------------------

    # PRIVATE CONSTRUCTION new(). Use Factory constructors.
    class << self
      private :new
    end

    def initialize(orphaNum, opts={})
      @orphaNum = orphaNum
      @opts = DEFAULT_OPTS.merge(opts)
      @dataVersion = @opts[:dataVersion]
      @xml = @xmlHash = @kbDoc = nil
    end

    def sanityChecks()
    end

    def initDoc()
      @kbDoc = BRL::Genboree::KB::KbDoc.new({})
      @kbDoc.nilGetOnPathError = true
      # Initialize root prop
      @kbDoc.setPropVal(ROOT_PROP, @orphaNum)
      @kbDoc.setPropVal( DATA_VERSION_PROP, @dataVersion) if(@dataVersion)

      # Location common disorder info. Because some disorders don't have info in the "Disorders" record set
      # (yes that is weird), we'll visit the various sections to try to "build up" the commons disorder info
      # if "Disorders" or some preceding section didn't already have that info.
      #
      # Consider each common bit of disorder info
      COMMON_DISORDER_INFO[:disorderInfoConfs].each { |conf|
        prop = conf[:prop]
        propPath = "#{ROOT_PROP}.#{prop}"
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Looking for #{prop.inspect} so we can fill #{propPath.inspect} ...")
        # Do we have this info already?
        haveInfo = false
        if(conf[:method] == :cssText)
          val = @kbDoc.getPropVal(propPath)
          haveInfo = (val and val.to_s =~ /\S/)
        elsif(conf[:method] == :section and conf[:subItems].is_a?(Hash))
          items = @kbDoc.getPropItems(prop)
          haveInfo = (items and items.size > 0)
        elsif(conf[:method] == :section and conf[:subProps].is_a?(Array))
          raise "ERROR: Common disorder info should either be simple values or possibly items lists, not full nested sub-docs. That is better dealth with using a non-common conf that applies to a specific kind of record (specific xmlDataKey). The offending common disorder conf is:\n\n#{conf.inspect}\n\n"
        end
        # If we already have it in the doc, more on. Else look for it in order of record section.
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "... #{'NOT' unless(haveInfo)} FOUND")
        unless(haveInfo)
          # We'll be temporarily pointing generic conf to specific section. Save the generic value.
          genericDataKey = conf[:xmlDataKey]
          COMMON_DISORDER_INFO[:xmlDataKeys].each { |xmlDataKey|
            # Point generic conf at the particular section:
            conf[:xmlDataKey] = xmlDataKey
            # Try to find our info
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "    -> Look in #{xmlDataKey.inspect}")
            found = extract(conf, ROOT_PROP)
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "    ->     Found: #{found.inspect}")
            break if(found)
          }
          # Restore conf's :xmlDataKeys value for cleanliness
          conf[:xmlDataKey] = genericDataKey
        end
      }

      return @kbDoc
    end

    def extract(extractConf, propPath=nil, kbDoc=@kbDoc, xmlDoc=nil)
      retVal = nil
      opts = extractConf[:opts] || {}
      prop = extractConf[:prop]
      propPath = (propPath.nil? ? ROOT_PROP : "#{propPath}.#{prop}")
      method = extractConf[:method]
      unless(xmlDoc) # Then get top-level XML from named section and parse it now
        xmlStr = @xmlStrHash[ extractConf[:xmlDataKey] ]
        #$stderr.puts "--------- XML STR -------------\n\n#{xmlStr}\n\n"
        xmlDoc = Nokogiri::XML(xmlStr)
      end
      #$stderr.debugPuts(__FILE__, __method__, 'Debug', "#{propPath.inspect} ; method: #{method.inspect} ; xmlDoc class: #{xmlDoc.class}")
      # Dispatch
      if(method == :cssText)
        retVal = cssText(xmlDoc, kbDoc, propPath, extractConf[:css], opts)
      elsif(method == :section)
        retVal = section( xmlDoc, kbDoc, propPath, { :subItems => extractConf[:subItems], :subProps => extractConf[:subProps] }, opts )
      elsif(method == :complex)
        complexMethod = opts[:complexMethod]
        retVal = self.send(complexMethod, xmlDoc, kbDoc, propPath, opts)
      end
      return retVal
    end

    def cssText(xmlDoc, kbDoc, propPath, css, opts)
      val = nil
      elems = xmlDoc.css(css)
      if(elems and elems.first)
        val = elems.first.text
        if( (val and val =~ /\S/) or opts[:keepIfEmpty])
          kbDoc.setPropVal(propPath, val)
        end
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "propPath: #{propPath.inspect} ; val: #{val.inspect} ; css: #{css.inspect} ; elems:\n\n#{elems.to_s}\n\n")
      end
      return val
    end

    def section(xmlDoc, kbDoc, propPath, contentConf, opts)
      # Add the section property
      kbDoc.setPropVal(propPath, '')
      # Add either subProps or subItems
      if(contentConf[:subProps])
        contentConf[:subProps].each { |propConf|
          extract(propConf, propPath, kbDoc, xmlDoc)
        }
        if( kbDoc.getPropProperties(propPath).empty? and !opts[:keepIfEmpty])
          unless(kbDoc.getPropVal(propPath) =~ /\S/)
            kbDoc.delProp(propPath)
          end
        end
      elsif(contentConf[:subItems])
        kbDoc.setPropItems(propPath, [])
        addItems(xmlDoc, kbDoc, propPath, contentConf[:subItems])
        unless( !kbDoc.getPropItems(propPath).empty? or opts[:keepIfEmpty])
          kbDoc.delProp(propPath)
        end
      end

      assess = kbDoc.getPropItems(propPath)
      return (assess and !assess.empty?)
    end

    def geneAssociations(xmlDoc, kbDoc, propPath, opts)
      # Gene List Info
      geneList = { }
      glElems = xmlDoc.css( 'Disorder > GeneList > Gene' )
      glElems.each { |glElem|
        if(glElem.attr('id'))
          glRec = geneList[glElem.attr('id')] = {
            :name => nil,
            :sym => nil,
            :type => nil,
            :synonyms => [],
            :loci => [],
            :assocs => []
          }
          # Type
          glElem.css('GeneType > Name').each { |typeElem|
            glRec[:type] = typeElem.text
          }
          # Synonyms
          glElem.css('SynonymList > Synonym').each { |synElem|
            glRec[:synonyms] << synElem.text
          }
          # Loci
          glElem.css('LocusList > Locus > GeneLocus').each { |locusElem|
            glRec[:loci] << locusElem.text
          }
        end
      }
      # Association Info
      alElems = xmlDoc.css( 'Disorder > DisorderGeneAssociationList > DisorderGeneAssociation' )
      alElems.each { |alElem|
        # Gene id
        geneElems = alElem.css('Gene')
        if(geneElems and !geneElems.empty?)
          # Gene info
          geneElem = geneElems.first
          geneId = geneElem.attr('id')
          glRec = geneList[geneId]
          glRec[:name] = geneElem.css('> Name').text
          glRec[:sym] = geneElem.css('> Symbol').text
          # Assoc
          glRec[:assocs] << {
            :type => alElem.css('DisorderGeneAssociationType > Name').text,
            :status => alElem.css('DisorderGeneAssociationStatus > Name').text
          }
        end
      }
      # KbDoc
      geneList.each_key { |geneId|
        geneRec = geneList[geneId]
        geneDoc = BRL::Genboree::KB::KbDoc.new({})
        geneDoc.setPropVal('Gene', geneRec[:sym])
        # Name
        geneDoc.setPropVal('Gene.Name', geneRec[:name]) if(geneRec[:name].to_s =~ /\S/)
        # Type
        geneDoc.setPropVal('Gene.Type', geneRec[:type]) if(geneRec[:type].to_s =~ /\S/)
        # Synonyms
        unless(geneRec[:synonyms].empty?)
          geneDoc.setPropItems('Gene.Synonyms', [])
          geneRec[:synonyms].each { |synonym|
            synDoc = BRL::Genboree::KB::KbDoc.new({})
            synDoc.setPropVal('Synonym', synonym)
            geneDoc.addPropItem('Gene.Synonyms', synDoc)
          }
        end
        # Loci
        unless(geneRec[:loci].empty?)
          geneDoc.setPropItems('Gene.Loci', [])
          geneRec[:loci].each { |locus|
            locusDoc = BRL::Genboree::KB::KbDoc.new({})
            locusDoc.setPropVal('Locus', locus)
            geneDoc.addPropItem('Gene.Loci', locusDoc)
          }
        end
        # Associations
        unless(geneRec[:assocs].empty?)
          geneDoc.setPropItems('Gene.Associations', [])
          geneRec[:assocs].each { |assoc|
            assocDoc = BRL::Genboree::KB::KbDoc.new({})
            assocDoc.setPropVal('Association', assoc[:type])
            assocDoc.setPropVal('Association.Status', assoc[:status])
            geneDoc.addPropItem('Gene.Associations', assocDoc)
          }
        end

        # Add geneDoc to items list
        kbDoc.addPropItem(propPath, geneDoc)
      }

      assess = kbDoc.getPropItems(propPath)
      return (assess and !assess.empty?)
    end

    def addItems(xmlDoc, kbDoc, propPath, itemsConf)
      elems = xmlDoc.css(itemsConf[:itemsCss])
      itemRootProp = itemsConf[:item]
      itemIdCss = itemsConf[:itemIdCss]
      itemIdCss = [ itemIdCss ] unless(itemIdCss.is_a?(Array))
      elems.each { |elem|
        itemDoc = BRL::Genboree::KB::KbDoc.new({})
        itemId = nil
        itemIdCss.each { |itemIdConf|
          if(itemIdConf == :text) # just the text of the already obtained elem
            if(elem.text and elem.text =~ /\S/)
              itemId = elem.text
            end
          elsif(itemIdConf.is_a?(String))
            idElem = elem.css(itemIdConf).first
            if(idElem and idElem.text and idElem.text =~ /\S/)
              itemId = idElem.text
            end
          elsif(itemIdConf.is_a?(Hash))
            css = itemIdConf[:css]
            if(css == :root) # The xml item itself is the thing we need, not something below it
              idElem = elem
            else # need some sub-elem below the xml item itself
              idElem = elem.css(css).first
            end

            if(idElem)
              if(itemIdConf[:attr])
                itemId = idElem.attr(itemIdConf[:attr])
              else
                itemId = idElem.text
              end
              # Prefix?
              if(itemId and itemIdConf[:prefix])
                itemId = "#{itemIdConf[:prefix]}#{itemId}"
              end
            end
          end
          break if(itemId)
        }

        skipEmptyId = ( itemsConf[:opts] and itemsConf[:opts][:emptyId] )
        if( itemId or !skipEmptyId )
          # Set root prop & val
          itemDoc.setPropVal(itemRootProp, itemId)
          # Add subprops or subitems if any
          if(itemsConf[:subProps])
            itemsConf[:subProps].each { |propConf|
              extract(propConf, itemRootProp, itemDoc, elem)
            }
          elsif(itemsConf[:subItems])
            addItems(elem, itemDoc, itemRootProp, itemsConf[:subItems])
          end
        end

        # Add itemDoc to items list
        kbDoc.addPropItem(propPath, itemDoc)
      }
    end
  end
end ; end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Helpers ; module Targeted
