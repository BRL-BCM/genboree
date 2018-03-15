#!/usr/bin/env ruby

require 'uri'
require 'brl/extensions/bson'
require 'bson'
require 'diffy'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/kbDocVersionEntity'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/kb/producers/fullPathTabbedDocProducer'

module BRL ; module REST ; module Resources

  class KbDocVersions < BRL::REST::Resources::GenboreeResource
  
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbDocVersions'
    SUPPORTED_ASPECTS = {
      "count" => true
    }
    DEFAULT_VERSION_REC_FIELDS = [
      'versionNum.value',
      'versionNum.properties.timestamp.value',
      'versionNum.properties.author.value',
      'versionNum.properties.docRef.value'
    ]
    CONTENT_BASE_MONGO_PATH = 'versionNum.properties.content.value'

    attr_accessor :versionsHelper, :docIdentProp, :docDbRef, :docDataCollHelper

    def cleanup()
      super()
      @docIentProp = @versionsHelper = @groupName = @kbName = @collName = @docName = nil
    end

    def self.pattern()
      # In addtion to an 'aspect', also supports specifying some specific version record fields via 'versionFields' and, separately,
      #   some specific content fields via 'contentFields'; both use KbDoc prop paths. Furthermore, can specify whether to get
      #   the full sub-trees ('valueObj') or just the value ('valueOnly') for the version fields via 'versionFieldsValue' and,
      #   separately, for the content fields via 'contentFieldsValue'.
      #   The versionFields or contentFields values are CSV--if you have internal commas within the field names, you need to
      #   escape them with a real backslash (i.e. TWO-character sequence \, will protect them in the CSV) when building your URL.
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/doc/([^/\?]+)/vers(?:$|/([^/\?]+)$)}
    end

    def self.priority()
      return 8
    end

    def initOperation()
      $stderr.debugPuts(__FILE__, __method__, 'TIME', "Entered.") ; tt = Time.now
      initStatus = super()
      if(initStatus == :OK)
        @docIentProp = @versionsHelper = nil
        @groupName = Rack::Utils.unescape(@uriMatchData[1]).to_s.strip
        @kbName = Rack::Utils.unescape(@uriMatchData[2]).to_s.strip
        @collName = Rack::Utils.unescape(@uriMatchData[3]).to_s.strip
        @docName = Rack::Utils.unescape(@uriMatchData[4]).to_s.strip
        @aspect = (@uriMatchData[5].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[5])
        @sortOpt = ( @nvPairs['sort'] and @nvPairs['sort'].upcase == "DESC") ? Mongo::DESCENDING  : Mongo::ASCENDING
        # Look for doc limits
        @limit = @nvPairs['limit'].to_s.to_i
        @limit = nil if(@limit <= 0)
        # Look for doc skip (with limit, this can do pageination)
        @skip = @nvPairs['skip'].to_s.to_i
        @skip = nil if(@skip <= 0)
        # Look for minDocVersion (only count version >= this version)
        @minDocVersion = @nvPairs['minDocVersion'].to_s.to_i
        @minDocVersion = nil if(@minDocVersion <= 0)
        initStatus = initGroupAndKb()
        initStatus = initColl() if( initStatus == :OK )

        $stderr.debugPuts(__FILE__, __method__, 'TIME', "Init'd operation. Examining #{@docName.inspect} from the #{@collName.inspect} coll. Specific 'aspect' is: #{@aspect.inspect}. The 'viewFields' is deprecated for this request. Rather we examine [later] for 'versionFields' and 'contentFields', and currently allow devs to ask for EITHER the full 'valueObj' UNDER these fields or the value AT the field specifically vai 'valueOnly' (although indicated separately for the versionRec fields and content fields). Init done with status #{initStatus.inspect} in #{Time.now.to_f - tt.to_f}sec") ; tt = Time.now

        # Get the model only once. If we pass collName to various helpers that could take the actual model
        #   instead, the model will be dynamically retrieved EVERY CALL TO HELPER METHOD (bad when iterating). So
        #   best to have model on hand.
        @modelsHelper = @mongoKbDb.modelsHelper() rescue nil
        @model = @modelsHelper.getModel( @collName )
        $stderr.debugPuts(__FILE__, __method__, 'TIME', "Also got relevant model in #{Time.now.to_f - tt.to_f}sec ; model for #{@collName.inspect} is a #{@model.class} w/keys #{@model.keys.inspect rescue '[FAILED]'}") ; tt = Time.now
      end
      return initStatus
    end

    # Validate and intialize path-related elements found in the pattern
    # @raises [BRL::Genboree::GenboreeError] if group is unaccessible or if objects
    #   associated with path elements are not found
    # @return [BSON::DBRef] The DBRef object for the doc. Contains collection name under 'namespace',
    #   has the _id value under 'object_id', and is generally useful for follow-up steps (unlike the plain _id value)
    def initPath()
      $stderr.debugPuts(__FILE__, __method__, 'TIME', "Entered.") ; tt = Time.now
      # validate user access to this resource
      @statusName = initOperation()
      if(@statusName != :OK)
        defaultMsg = 'Unable to authorize access to this resource'
        @statusMsg = (@statusMsg.nil? or @statusMsg.empty? ? defaultMsg : @statusMsg) 
        err = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        raise err
      else
        # @todo where does initGroupAndKb leave the access?

        # get collection handle
        if(@mongoDch.nil?)
          @statusName = :'Not Found'
          @statusMsg = "NO_COLL: can't get document named #{@docName.inspect} because appears "\
                       "to be no data collection #{@collName.inspect} in the #{@kbName.inspect} "\
                       "GenboreeKB within group #{@groupName.inspect} (check spelling/case, etc)."
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        else
          tt = Time.now
          # get document info from collection
          @docIdentProp = @mongoDch.getIdentifierName()
          @docDbRef = @mongoDch.dbRefFromRootPropVal( @docName ) rescue nil
          $stderr.debugPuts(__FILE__, __method__, 'TIME', "Used @mongoDch to get the doc root-prop name (#{@docIdentProp.inspect}) and the DOC @BSON::DBRef (#{@docDbRef.inspect}) in #{Time.now.to_f - tt.to_f}sec") ; tt = Time.now
          # get a VersionsHelper instance but DON'T get the head version doc yet; may not need the whole thing
          @versionsHelper = @mongoKbDb.versionsHelper(@collName) rescue nil
          $stderr.debugPuts(__FILE__, __method__, 'TIME', "Instantiated @versionHelper for other methods to use also in #{Time.now.to_f - tt.to_f}sec") ; tt = Time.now

          unless( @docDbRef.is_a?( BSON::DBRef ) )
            @statusName = :'Not Found'
            @statusMsg = "NO_DOC: there is no document with the identifier #{@docName.inspect} "\
                         "in the #{@collName.inspect} collection in the #{@kbName.inspect} "\
                         "GenboreeKB within group #{@groupName.inspect} (check spelling/case, "\
                         "etc; also consider if it has been deleted)."
            raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          end

          #$stderr.debugPuts(__FILE__, __method__, 'TIME', "Will be returning just the versionNum.docRef value #{@docDbRef.inspect} from this initPath() in #{Time.now.to_f - tt.to_f}sec") ; tt = Time.now
        end
      end
      return @docDbRef
    end

    def buildAllOutputFields( atLeastDefaults=true )
      # Do we have specific versionFields and/or versionFieldsValue specifiers?
      @versionFields = buildVersionRecOutputFields( 'versionFields', 'versionFieldsValue' )
      @versionFields = self.class::DEFAULT_VERSION_REC_FIELDS if( atLeastDefaults and (!@versionFields or @versionFields.empty?) )
      # Do we have specific contentFields and/or contentFieldsValue specifiers?
      if( @nvPairs.key?( 'contentFields' ))
        @contentFields = buildContentOutputFields( 'contentFields', 'contentFieldsValue' )
      else # try more vague and now deprecated "viewFields" which was used to mean *content's* properties ; it didn't have concept of specifying kind of content for the field(s)
        @contentFields = buildContentOutputFields( 'viewFields', 'contentFieldsValue' )
      end

      # Combine into all fields
      @desiredFields = ( ( @versionFields or [] ) + (@contentFields or [] ) ).uniq

      return ( ( @desiredFields and !@desiredFields.empty? ) ? @desiredFields : nil )
    end

    # @todo detailed = false for just version numbers
    # @todo VERY SLOW. Needs to be improved like KbDocVersion was. initOperation and initPath() is shared between them and has undergone good optimization.
    def get()
      begin
        @docDbRef = initPath()
        # finally, get versions of the document
        if( @versionsHelper.nil? )
          @statusName = :"Internal Server Error"
          @statusMsg = "Failed to access versions collection for data collection #{@collName}"
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end
        if(@aspect)
          if(SUPPORTED_ASPECTS.key?(@aspect))
            if(@aspect == 'count')
              count = @versionsHelper.versionCount( @docDbRef, nil, { :minDocVersion => @minDocVersion } )
              doc = BRL::Genboree::KB::KbDoc.new( { "count" => { "value" => count } } )
              entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
              @statusName = configResponse(entity) # sets @resp
            end
          else
            @statusName = :"Bad Request"
            @statusMsg = "Aspect: #{@aspect.inspect} is not supported."
            raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          end
        else # Not specific aspect, but list of versions.
          opts = { :sort => ['versionNum.value', @sortOpt] }
          if(@limit)
            opts[:limit] = @limit
          end
          if(@skip)
            opts[:skip] = @skip
          end
          # If @viewFields present, convert the paths into mongo paths
          # @todo viewFields should be for VERSION doc fields only. Doesn't really allow customization of fields.
          # @todo Rather can do what KbDocVersion does: (1) recognize 'versionFields' + 'versionFieldsValue' and
          #   'contentFields' + 'contentFieldsValue' like that class does; (2) employ buildVersionRecOutputFields()
          #   and buildContentOutputFields() methods like it does to dig out and process these fields if supplied.
          fields = buildAllOutputFields( true )
          opts[:fields] = fields if( fields and !fields.empty? )
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "allVersions() opts: #{opts.inspect}")
          versionsList = @versionsHelper.allVersions(@docDbRef, nil, opts)
          if(versionsList.nil?)
            @statusName = :"Internal Server Error"
            @statusMsg = "Failed to get versions for document #{@docName}"
            raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          end
          if(@detailed)
            versionEntityList = BRL::Genboree::REST::Data::KbDocVersionEntityList.from_json(versionsList)
          else
            versionEntityList = BRL::Genboree::REST::Data::KbDocEntityList.new(@connect)
            versionsList.each { |verObj|
              doc = BRL::Genboree::KB::KbDoc.new( { "text" => { "value" => verObj['versionNum']['value'] } } )
              entity = BRL::Genboree::REST::Data::KbDocEntity.new(@connect, doc)
              versionEntityList << entity
            }
          end
          @statusName = configResponse(versionEntityList) # sets @resp
        end
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end

    # ----------------------------------------------------------------
    # HELPERS
    # ----------------------------------------------------------------

    def buildVersionRecOutputFields( fieldsNvPairsKey, contentNvPairsKey )
      # Get a base model for a version record doc (there is no formal model doc stored for version or revision records)
      model = @versionsHelper.class.getModelTemplate( @collName )
      mongoBasePath = ''

      return buildOutputFields( fieldsNvPairsKey, contentNvPairsKey, model, mongoBasePath )
    end

    def buildContentOutputFields( fieldsNvPairsKey, contentNvPairsKey )
      model = @model
      mongoBasePath = CONTENT_BASE_MONGO_PATH
      $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "field names key: #{fieldsNvPairsKey.inspect} ; fields content type key: #{contentNvPairsKey.inspect} ; mongoBasePath: #{mongoBasePath.inspect} ; model is a #{model.class} with keys: #{model.keys.inspect rescue '[NONE!]'}")

      return buildOutputFields( fieldsNvPairsKey, contentNvPairsKey, model, mongoBasePath )
    end

    def buildOutputFields( fieldsNvPairsKey, contentNvPairsKey, model, mongoPathBase=nil )
      # Do we have specific versionFields and/or versionFieldsContent specifiers?
      if( @nvPairs.key?( fieldsNvPairsKey ) )
        # What content are we after for these fields fo the version record, the value itself or the whole value object?
        if( @nvPairs[contentNvPairsKey].to_s.strip =~ /^valueObj$/i )
          contentType = :valueObj
        else # not supplied or is valueOnly or is unrecognized, so use default of valueOnly
          contentType = :valueOnly
        end
        # Mask internal commas (which are provided \-escaped), split by commas, then restore
        retVal = @nvPairs[fieldsNvPairsKey].to_s.gsub("\\,", "\v").split(/,/).map! { |field| field.gsub(/\v/, ',') }
        retVal.map! { |field|
          $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "convert field #{field.inspect} to a mongo path using the supplied model (#{model.class})")
          field = @modelsHelper.modelPath2DocPath( field, model )
          # Add base path. Generally for building paths into the actual DOC CONTENT part.
          if( !mongoPathBase.to_s.empty? )
            field = "#{mongoPathBase.strip.chomp('.')}.#{field}"
          end
          # Make field path correct depending on if we want the value itself or the whole [recursive] value object
          if( contentType == :valueObj ) # then need to strip off the terminal .value
            field.sub!( /\.value$/, '' )
          end
          field
        }
        retVal = nil if(retVal.empty?)
      else
        retVal = nil
      end

      return retVal
    end
  end
end ; end ; end
