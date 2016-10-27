require 'brl/genboree/kb/propSelector'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/resources/kbDocs'
require 'brl/genboree/rest/data/kbDocEntity'
require 'brl/genboree/rest/wrapperApiCaller'

module BRL; module Genboree; module REST; module Helpers

  class KbApiUriHelper < ApiUriHelper
    # Each resource specific API Uri Helper subclass should redefine these:
    NAME_EXTRACTOR_REGEXP =  %r{^http://[^/]+/REST/v\d+/grp/[^/]+/kb/([^/\?]+)} # To get just the name of the resource from the URL
    EXTRACT_SELF_URI = %r{^(.+/kb/[^/\?]+)} # To get just this resource's portion of the URL, with any suffix stripped off

    # similar to EXTRACT_TYPE from parent but more specific to kb-related resources
    # symbol names matching the names of resources or the entity type is desirable,
    #   in fact these are most often exactly the return value of the resources' pattern()
    # as with the resource pattern() calls, more specific resources should have higher priority,
    #   or come first in this list
    REGEXP_TO_TYPE = [
      [ %r{/REST/[^/\?]+/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/doc/([^/\?]+)}, :kbDoc ],
      [ %r{/REST/[^/\?]+/grp/([^/\?]+)/kb/([^/\?]+)/(?:trRulesDoc|transform)/([^/\?]+)}, :kbTransform ]
    ]

    TYPE_TO_REGEXP = {}
    REGEXP_TO_TYPE.each{ |regexp, type| 
      TYPE_TO_REGEXP[type] = regexp
    }

    def init(dbu=nil, genbConf=nil, reusableComponents={})
      super(dbu, genbConf, reusableComponents)
      @grpApiUriHelper = GroupApiUriHelper.new(dbu, genbConf, reusableComponents) unless(@grpApiUriHelper)
    end

    # Classify a kb-related URI into a known resource type
    # @param [String] uri the uri to classify
    # @todo very similar to extractType
    def classifyUri(uri)
      retVal = nil
      REGEXP_TO_TYPE.each{ |regexp, type|
        if(regexp.match(uri))
          retVal = type
          break
        end
      }
      return retVal
    end

    # If an input URI is a KbDoc, extract its doc ID
    # @param [String] uri 
    # @return [NilClass, String] the document ID or nil of the uri is not a KbDoc URI
    # @todo re-match redundant; also assumes REGEXP_TO_TYPE match groups wont change
    def getDocId(uri)
      retVal = nil
      type = classifyUri(uri)
      if(type == :kbDoc)
        regexp = TYPE_TO_REGEXP[type]
        matchData = regexp.match(uri)
        retVal = matchData[4]
      end
      return retVal
    end

    # Get the Genboree database URI associated with the input kb uri
    # @param [String] uri a uri to a Genboree kb
    # @return [String, NilClass] a url to the kb's associated db or nil if failure
    #   probably due to input not being a kb uri
    def getGenboreeDb(uri)
      retVal = nil
      kbName = extractName(uri)
      if(kbName.nil?)
      else
        grpUri = @grpApiUriHelper.extractPureUri(uri)
        retVal = "#{grpUri}/db/#{CGI.escape("KB:#{kbName}")}"
      end
      return retVal
    end

    # Upload kbDocs with size constraints and reattempts to a collection
    # @param [String] collectionUri the collection to upload documents to
    # @param [Array<BRL::Genboree::REST::Data::KbDocEntity>] the entities to upload
    # @param [Fixnum] userId the internal userId for the user to perform the uploads as
    # @param [Hash] opts Hash to supply the function with additional instructions
    # @return [Hash] mapping of entity ranges to success/failure and reason for error
    #   :success => [ (i1..i2), ... ]
    #   :fail => { (i3..i4) => error, ... }
    def uploadKbDocEntities(collectionUri, entities, userId, opts={})
      retVal = { :success => [], :fail => {} }
      uriObj = URI.parse(collectionUri)
      rsrcPath = "#{uriObj.path}/docs?detailed=false"
      rsrcPath << "&gbSysKey=#{CGI.escape(opts[:gbSysKey])}&validate=false" if(opts.key?(:gbSysKey) and opts.key?(:validate) and opts[:validate] == false) 
      apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(uriObj.host, rsrcPath, userId)
      batchSize = (entities.size > BRL::REST::Resources::KbDocs::MAX_DOCS ? BRL::REST::Resources::KbDocs::MAX_DOCS : entities.size)
      initialBatchSize = batchSize
      currTotalSize = 0
      currNumDocs = 0
      startIndex = 0
      nSer = 0 # ser = serialization attempts
      maxSer = 25
      while(startIndex < entities.size and batchSize > 0)
        endIndex = startIndex + batchSize
        range = (startIndex...endIndex)
        currEntities = entities[range]
        raise RuntimeError.new("Range does not intersect entity indexes; range=#{range.inspect} ; entities.size=#{entities.size}") if(currEntities.empty?)
        range = startIndex .. startIndex + currEntities.size - 1 # update to effective range
        entityList = BRL::Genboree::REST::Data::KbDocEntityList.new(false, currEntities)
        serialized = entityList.to_json
        nSer += 1
        if(serialized.size > BRL::REST::Resources::KbDocs::MAX_BYTES)
          # decrease size of batchSize and try again (this approach will decrease at LEAST by 1)
          factor = BRL::REST::Resources::KbDocs::MAX_BYTES / serialized.size.to_f
          batchSize = (factor * batchSize).floor
          if(batchSize == 0)
            # then the single document serialization exceeds the byte limit, mark as error and move on
            msg = "Cannot upload document because it exceeds server byte limit of #{BRL::REST::Resources::KbDocs::MAX_BYTES} bytes"
            retVal[:fail][startIndex..startIndex] = BRL::Genboree::GenboreeError.new(:"Bad Request", msg)
            startIndex += 1
            batchSize = BRL::REST::Resources::KbDocs::MAX_DOCS
            nSer = 0
          end
          if(nSer >= maxSer)
            # then we could not find a small enough serialization for decreasing batch sizes, mark as error and move on
            msg = "Cannot upload document(s) because they exceed server byte limit of #{BRL::REST::Resources::KbDocs::MAX_BYTES} bytes"
            # range here safe b/c of batchSize == 0 check above
            retVal[:fail][startIndex..endIndex-1] = BRL::Genboree::GenboreeError.new(:"Bad Request", msg)
            startIndex += batchSize
            batchSize = BRL::REST::Resources::KbDocs::MAX_DOCS
            nSer = 0
          end
        else
          # try to upload this batch of documents
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Default payload was too large, batch size decreased to #{batchSize.inspect} from #{initialBatchSize}") if(batchSize != initialBatchSize)
          currTotalSize += serialized.size
          currNumDocs += batchSize
          attempt = 0
          base = 10
          growth = 2
          sleepTime = base * growth ** attempt
          maxAttempts = 10
          success = false
          resp = nil
          while(!success and (attempt < maxAttempts))
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Attempt \##{attempt+1}/#{maxAttempts} to upload #{range} of #{entities.size} kbDocs to the #{collectionUri} collection")
            resp = apiCaller.put(template={}, serialized)
            if(apiCaller.succeeded?)
              success = true 
            else
              # reattempt if failure is transient
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Attempt failure; response code: #{resp.code}")
              if(REATTEMPT_HTTP_CODES.include?(resp.code.to_i))
                attempt += 1
                sleepTime *= growth
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sleeping for #{sleepTime} seconds")
                sleep(sleepTime)
              else
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Refusing to reattempt because response code is not in #{REATTEMPT_HTTP_CODES.inspect}")
                attempt = maxAttempts
                break
              end
            end
          end

          if(success)
            if(resp.code.to_s.strip == "206")
              # then some of the documents were not uploaded successfully, but others were
              respBody = apiCaller.parseRespBody()
              propSel = BRL::Genboree::KB::PropSelector.new(respBody['data'])
              invalidIndexes = propSel.getMultiPropValues("docs.invalid.[].id.payloadIndex")
              invalidMsgs = propSel.getMultiPropValues("docs.invalid.[].id.msg")
              raise "Could not parse response from server: error messages could not be paired with payload indexes" if(invalidIndexes.size != invalidMsgs.size)
              invalidMsgs.each_index{ |ii|
                msg = invalidMsgs[ii]
                index = invalidIndexes[ii]
                entityIndex = range.first + index
                retVal[:fail][(entityIndex..entityIndex)] = BRL::Genboree::GenboreeError.new(:"Bad Request", msg)
              }

              validIndexes = propSel.getMultiPropValues("docs.valid.[].id.payloadIndex")
              validIndexes.each { |index|
                retVal[:success].push((index..index))
              }
            else
              retVal[:success].push(range)
            end
          elsif(attempt >= maxAttempts)
            # get last failure information
            respBody = apiCaller.parseRespBody() rescue nil
            status = nil
            msg = nil
            if(respBody.is_a?(Hash))
              status = (respBody['status'] and respBody['status']['statusCode'])
              msg = (respBody['status'] and respBody['status']['msg'])
            end
            status = resp.code if(status.nil?)
            msg = Rack::Utils::HTTP_STATUS_CODES[status.to_i] if(msg.nil?)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Upload failed after #{maxAttempts} attempts: status #{status.inspect}; message #{msg.inspect}")
            retVal[:fail][range] = BRL::Genboree::GenboreeError.new(status, msg)
          end
          # after finishing this batch, reset batchSize because the next set will have a different serialized size
          startIndex += batchSize
          batchSize = BRL::REST::Resources::KbDocs::MAX_DOCS
          nSer = 0
        end # serialization if/else
      end # while loop
      return retVal
    end

    # Get url for model with an associated collection url
    # @param [String] collUrl a url to a collection
    # @return [String] modelUrl a url to the model of the collection
    def collUrlToModelUrl(collUrl)
      uriObj = URI.parse(collUrl)
      return "#{uriObj.scheme}://#{uriObj.host}#{uriObj.path}/model"
    end

    # Get model for collection given by a url
    # @param [String] collUrl a URL to a collection
    # @param [Fixnum] userId internal userId for a user to act as to get the model
    # @return [BRL::Genboree::KB::KbDoc] the collection's model
    # @todo generic reattempt? could reattempt at least on 502 (thin restart, etc.)
    def getModelForCollection(collUrl, userId)
      retVal = nil
      modelUrl = collUrlToModelUrl(collUrl)
      uriObj = URI.parse(modelUrl)
      apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(uriObj.host, uriObj.path, userId)     
      resp = apiCaller.get()
      if(apiCaller.succeeded?)
        retVal = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody()['data'])
      else
        retVal = nil
      end
      return retVal
    end

  end
end; end; end; end
