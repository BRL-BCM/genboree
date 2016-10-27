require 'brl/genboree/abstract/resources/abstractStreamer'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/producers/nestedTabbedModelProducer'
require 'brl/genboree/kb/producers/nestedTabbedDocProducer'
require 'brl/genboree/kb/producers/fullPathTabbedModelProducer'
require 'brl/genboree/kb/producers/fullPathTabbedDocProducer'
require 'brl/genboree/kb/helpers/viewsHelper'
require 'brl/genboree/rest/resources/kbViews'

module BRL ; module Genboree ; module Abstract ; module Resources

  # This class is used to stream the downloading of documents instead of giving back the response as one large payload
  # The instance of this class is handed off to rack and it uses the each() to stream chunks of data to the proxy server
  class KbDocsStreamer < BRL::Genboree::Abstract::Resources::AbstractStreamer
    MAX_DOCS = 500
    MAX_SIZE = 64 * 1024
    KEYS_TO_CLEAN = ['_id', :_id]

    attr_accessor :format, :model, :viewCursor, :viewType, :viewName, :viewsHelper, :dataHelper, :wrapInGenbEnvelope

    # @param [Mongo::Cursor] docsCursor from some already-performed query
    # @param [Boolean] detailed if false only return the document ids
    # @param [String] idPropName root identifier property for collection that cursor has
    #   queried over
    # @param [Integer, NilClass] limit the maximum number of documents to yield or nil if no limit
    # @param [BRL::Genboree::KB::Helpers::ViewsHelper] viewsHelper if viewName has been set
    #   for some restructuring of the retrieved documents, use the viewsHelper to perform
    #   the restructuring
    def initialize(docsCursor, detailed, idPropName, limit, viewsHelper=nil)
      super()
      @docsCursor = docsCursor
      @detailed = detailed
      @idPropName = idPropName
      @limit = limit
      @viewCursor = nil
      @viewType = 'flat'
      @viewName = nil
      @format = :JSON
      @viewsHelper = viewsHelper
      @dataHelper = dataHelper
      @wrapInGenbEnvelope = true
      unless(self.class.method_defined?(:child_each))
        alias :child_each :each
        alias :each :parent_each
      end
    end

    # Method used by rack to stream back data in chunks instead of sending as one large payload
    def each()
      buff = ""
      producer = nil
      if(@format == :TABBED or @format == :TABBED_PROP_PATH)
        producer = BRL::Genboree::KB::Producers::FullPathTabbedDocProducer.new(@model)
      elsif(@format == :TABBED_PROP_NESTING)
        producer = BRL::Genboree::KB::Producers::NestedTabbedDocProducer.new(@model)
      else
        if(@format == :JSON_PRETTY)
          if(@wrapInGenbEnvelope)
            buff << "{\n  \"data\":\n   [\n"
          else
            buff << "[\n"
          end
        else
          if(@wrapInGenbEnvelope)
            buff << "{\"data\":["
          else
            buff << "["
          end
        end
      end
      currNum = 0
      docCount = 0
      firstDoc = true
      viewProps = [ { 'value' => @idPropName } ]
      if(@viewName)
        if(!BRL::Genboree::KB::Helpers::ViewsHelper::IMPLICIT_VIEWS_DEFS.key?(@viewName))
          @viewCursor.each { |doc| # Only has one doc, actually
            doc = BRL::Genboree::KB::KbDoc.new( doc )
            viewPropsList = doc['name']['properties']['viewProps']['items']
            @viewType = doc.getPropVal('name.type')
            viewPropsList.each {|propObj|
              viewPropValue = propObj['prop']['value']
              viewPropLabel = nil
              if(propObj['prop'].key?('properties') and propObj['prop']['properties'].key?('label'))
                propObjKbDoc = BRL::Genboree::KB::KbDoc.new( propObj )
                viewPropLabel = propObjKbDoc.getPropVal('prop.label') 
              end
              viewPropObj = { "value" => viewPropValue }
              viewPropObj['label'] = viewPropLabel if(viewPropLabel)
              viewProps << viewPropObj
            }
          }
        end
        @detailed = true # For views, we will need the full document
      end
      docCount = 0
      @docsCursor.each { |doc|
        doc = BRL::Genboree::KB::KbDoc.new( doc )
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Streaming doc with ID #{doc.getPropVal(@idPropName)}" )
        unless(@detailed) # ensure we only have the identifier (mainly for the all-docs/no-matching case)
          oldDoc = BRL::Genboree::KB::KbDoc.new(doc)
          newDoc = BRL::Genboree::KB::KbDoc.new()
          newDoc.setPropVal(@idPropName, oldDoc.getPropVal(@idPropName))
          doc = newDoc
        end
        if(@format.to_s =~ /json/i)
          unless(firstDoc)
            buff << ",\n"
          end
        end
        # Clean the document by removing unwanted keys from the response
        docKb = BRL::Genboree::KB::KbDoc.new(doc)
        docKb.cleanKeys!(KEYS_TO_CLEAN)
        doc.cleanKeys!(KEYS_TO_CLEAN)
        doc = @dataHelper.transformIntoModelOrder(doc, { :doOutCast => true, :castToStrOK => true }) if(@detailed) #Transform the doc order into model order if full representation is requested.
        # If @viewName is not nil, we may need to generate the docs as a custom view
        # A view essentially defines a set of properties to show alongwith the document identifier property instead of all the properties
        if(@viewName.nil?)
          if(@format == :JSON_PRETTY)
            buff << JSON.pretty_generate(doc).gsub(/^/, "        ") # This makes it look better on the client side
          elsif(@format == :JSON)
            buff << JSON.generate(doc)
          else
            producer.produce(doc) { |line| buff << "#{line}\n" }
          end
        else
          transformedDoc = @viewsHelper.transformDoc(docKb, viewProps, @idPropName, @viewType)
          if(@format == :JSON_PRETTY)
            buff << JSON.pretty_generate(transformedDoc).gsub(/^/, "        ")
          elsif(@format == :JSON)
            buff << JSON.generate(transformedDoc)
          else
            addHeader = ( docCount == 0 ? true : false )
            buff << @viewsHelper.tabbedDoc(transformedDoc, viewProps, @viewType, addHeader) # Cannot use the producer since 'flat' view docs have no root property neither do they follow the model schema
          end
        end
        currNum += 1
        docCount += 1
        if(docCount >= MAX_DOCS or buff.size >= MAX_SIZE)
          yield buff
          buff = ""
          docCount = 0
        end
        break if(@limit and @limit > 0 and currNum >= @limit)
        firstDoc = false
      }
      if(@format == :JSON_PRETTY)
        if(@wrapInGenbEnvelope)
          buff << "\n   ],\n  \"status\":\n   {\n     \"msg\": \"OK\"\n   }\n}"
        else
          buff << "\n ]"
        end
      elsif(@format == :JSON)
        if(@wrapInGenbEnvelope)
          buff << "],\"status\":{\"msg\": \"OK\"}}"
        else
          buff << "]"
        end
      end
      yield buff if(!buff.empty?)
    end # def each()
  end # class KbDocsStreamer < BRL::Genboree::Abstract::Resources::AbstractStreamer
end ; end ; end ; end # module BRL ; module Genboree ; module Abstract ; module Resources
