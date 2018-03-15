#!/usr/bin/env ruby
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/resources/kbCollection'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/rest/data/kbDocRevisionEntity'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/propSelector'

module BRL; module REST; module Resources

  class KbDocPropRevisions < BRL::REST::Resources::GenboreeResource
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbDocPropRevisions'
    REJECTION_SET_REG_EXPS = [ /\[FIRST\],/, /\[LAST\],/, /\[\d+\],/,  /\.</, /\{\s*\}/]

    def cleanup()
      super()
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/doc/([^/\?]+)/prop/([^/\?]+)/revs$}
    end

    def self.priority()
      return 7
    end

    def initOperation()
      # check class parent validators
      initStatus = super()
      raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
      @groupName  = Rack::Utils.unescape(@uriMatchData[1])
      @kbName     = Rack::Utils.unescape(@uriMatchData[2])
      @collName   = Rack::Utils.unescape(@uriMatchData[3])
      @docName    = Rack::Utils.unescape(@uriMatchData[4])
      @propPath   = Rack::Utils.unescape(@uriMatchData[5])
      initStatus  = initGroupAndKb()
      raise BRL::Genboree::GenboreeError.new(initStatus, "Unable to initialize access to resource") unless(200..299).include?(HTTP_STATUS_NAMES[initStatus])
      if(matchRejectionSet?(@propPath))
        raise BRL::Genboree::GenboreeError.new(:"Bad Request", "property path cannot contain: square braces with indices (FIRST/LAST) or '<'. If you are trying to access an item or a property under an item, use curly braces with a value {value} to indicate the value of the item you are interested in.")
      end
      @sortOpt = ( @nvPairs['sort'] and @nvPairs['sort'] == "ASC") ? Mongo::ASCENDING : Mongo::DESCENDING 
      # validate path against model for this collection
      @mh = @mongoKbDb.modelsHelper()
      @modelDoc = @mh.modelForCollection(@collName)
      raise BRL::Genboree::GenboreeError.new(:"Not Found", "Model document not found for this collection.") unless(@modelDoc)
      @modelDoc = @modelDoc.getPropVal('name.model')
      @dataHelper = @mongoKbDb.dataCollectionHelper(@collName) rescue nil
      @revHelper = @mongoKbDb.revisionsHelper(@collName) rescue nil
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@propPath: #{@propPath.inspect}")
      docNameValidation = docNameCast(@docName, @modelDoc, @dataHelper)
      if(docNameValidation and docNameValidation[:result] == :VALID) # looks compatible and has now been casted appropriately
        @docName = docNameValidation[:castValue] # use casted value
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME NOW: #{@docName.inspect}")
        @doc = @dataHelper.getByIdentifier(@docName, { :doOutCast => true, :castToStrOK => true })
        unless(@doc)
          raise BRL::Genboree::GenboreeError.new(:"Not Found", "The document #{@docName} was not found in the collection #{@collName}")
        end
      else
        @statusName = :'Bad Request'
        @statusMsg = "INVALID_DOCID: The docID #{@docName.inspect} is not valid according to the collection model: it is incompatible with the domain of the document identifier property."
      end
      return initStatus
    end

    def get()
      begin
        initStatus = initOperation() # error if not ok
        propHash = {}
        propSel = BRL::Genboree::KB::PropSelector.new(@doc)
        entity = nil
        # Get the list of property paths to match against since sub doc could have been inserted as part of updating one of the parent properties
        propsPathsToSelectorMap = @revHelper.getPropPathsForRevQuery(@propPath)
        queryPropPaths = propsPathsToSelectorMap.keys
        # Get the docRef of the doc first. We will use this in our query
        docRef = @dataHelper.getDocRefFromDocName(@modelDoc['name'], @docName)
        orList = []
        it = @revHelper.getRevisionDocsForSubDoc(docRef, queryPropPaths, @sortOpt)
        # Once we have out cursor, we need to loop over the documents and compile the list of value objects only for the property of interest (which may be buried under parent properties for some cases)
        respEntity = BRL::Genboree::REST::Data::KbDocRevisionEntityList.new(@connect)
        authorIdHash = {}
        it.each {|doc|
          doc.delete("_id") if(doc.key?("_id"))
          kbDoc = BRL::Genboree::KB::KbDoc.new(doc)
          # When presenting a descending list [DEFAULT], break if we encounter a deleted subdoc.
          # When presenting an ascending list, clear the array if we encounter a deleted subdoc
          if(@sortOpt == Mongo::DESCENDING)
            if(kbDoc.getPropVal('revisionNum.deletion'))
              break
            end
          else
            if(kbDoc.getPropVal('revisionNum.deletion'))
              respEntity.array.clear()
              next
            end
          end
          subDocPath = kbDoc.getPropVal('revisionNum.subDocPath')
          if(subDocPath != "/#{@propPath}")
            contentDoc = getContentDocForPropPath(kbDoc, subDocPath, propsPathsToSelectorMap)
            next if(contentDoc.nil?)
            kbDoc.setPropVal('revisionNum.content', contentDoc)
          end
          # Change the author from the login to the full name
          author = kbDoc.getPropVal('revisionNum.author')
          if( !authorIdHash.key?(author) )
            authorInfo = @dbu.selectUserByName(author)[0]
            name = "#{authorInfo["firstName"]} #{authorInfo["lastName"]}"
            authorIdHash[author] = name
          end
          kbDoc.setPropVal('revisionNum.author', authorIdHash[author])
          respEntity << BRL::Genboree::REST::Data::KbDocRevisionEntity.new(@connect, kbDoc)
        }
        @statusName = configResponse(respEntity)
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
    
    
    ################### Helpers ##################################

    def matchRejectionSet?(prop)
      retVal = false
      REJECTION_SET_REG_EXPS.each { |regExp|
        if(prop =~ regExp)
          retVal = true
          break
        end
      }
      return retVal
    end
    
    # Gets the content doc for the property of interest (@propPath)
    def getContentDocForPropPath(kbDoc, subDocPath, propsPathsToSelectorMap)
      retVal = nil
      selectorPath = propsPathsToSelectorMap[subDocPath]
      spCmps = selectorPath.split(".")
      ps = nil
      pathToProp = nil
      if(subDocPath == "/")
        ps = BRL::Genboree::KB::PropSelector.new(kbDoc.getPropVal('revisionNum.content'))
        pathToProp = spCmps[0..spCmps.size-1].join(".")
      else
        contentDoc = kbDoc.getPropVal('revisionNum.content')
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "contentDoc:\n#{JSON.pretty_generate(contentDoc)}")
        ps = BRL::Genboree::KB::PropSelector.new({spCmps[0] => contentDoc})
        if(spCmps[1] == "[]")
          pathToProp = spCmps[0..spCmps.size-1].join(".")
        else
          pathToProp = spCmps[1..spCmps.size-1].join(".")
        end
      end
      begin
        contentObj = ps.getMultiObj(pathToProp)[0]
        if( pathToProp =~ /\}$/ )
          itemIdentifier = spCmps[spCmps.size-2]
          retVal = contentObj[itemIdentifier] if(contentObj and !contentObj.empty?)
        else
          propOfInterest = spCmps[spCmps.size-1]
          retVal = contentObj[propOfInterest]  if(contentObj and !contentObj.empty?)
        end
      rescue => err
        # Nothing to do. Property of interest doesnt exist in the parent prop. Most likely the property of interest was added later on to the parent and we are seeing a revision of the parent prior to adding the property of interest
      end
      return retVal
    end
    
    
    # @todo - should this move to DataCollectionHelper?? Doc it have access to modelhelper etc for the collection? YES!
    def docNameCast(docName, model, dataHelper)
      docNameValidation = nil
      idPropName = dataHelper.getIdentifierName()
      # Empty payload is fine to create a NEW doc. Cannot already exist though!
      # Need to cast @docName to match model
      mv = dataHelper.modelValidator(false, false)
      docNameValidation = mv.validVsDomain(docName, model, [ idPropName ], { :castValue => true })
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DOC NAME cast results: #{docNameValidation.inspect}")
      return docNameValidation
    end
  
  end

  
end; end; end
