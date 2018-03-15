require 'brl/util/util'
require 'brl/sites/emBioOntology'
require 'plugins/genboree_kbs/app/helpers/em_helpers'

module GenboreeKbHelper
  
  
  class AsyncBioportalHelper
    

    attr_accessor :ontArray
    
    attr_accessor :subtreeArray
    
    attr_accessor :searchStr
    
    attr_accessor :prefixSearch
    
    attr_accessor :limit
    
    attr_accessor :domainInfoStr
    
    attr_accessor :env
    
    def initialize(ontArray=nil, subtreeArray=nil, searchStr=nil, prefixSearch=nil, limit=nil)
      @ontArray = ontArray
      @subtreeArray = subtreeArray
      @searchStr = searchStr
      @prefixSearch = prefixSearch
      @limit = limit
      @domainInfoStr = nil
    end
    
    def start(queryType=:singleOntology)
      if(queryType == :singleOntology)
        bioOntObj = BRL::Sites::EMBioOntology.fromUrl(@domainInfoStr, { :proxyHost => ENV['PROXY_HOST'], :proxyPort => ENV['PROXY_PORT'] })
        bioOntObj.debug = true
      else
        bioOntObj = BRL::Sites::EMBioOntology.new(@ontArray, @subtreeArray, nil, { :proxyHost => ENV['PROXY_HOST'], :proxyPort => ENV['PROXY_PORT'] })
        bioOntObj.debug = true
      end
      bioOntObj.requestTermsByNameViaSubtree(@searchStr, @prefixSearch, @limit)
      bioOntObj.callbackObj = self
    end
    
    
    # This method is called as a callback from the EMBioOntology class after the final response is done being constructed.
    def prepareFinalResp(respObj)
      resp = []
      status = 200
      if(respObj.nil?)
        resp = {}
        status = 404
      else
        ii = 0
        respObj.each { |obj|
          ii += 1
          id = obj['@id'] ? obj['@id'] : ""
          type = obj['@type'] ? obj['@type']  : ""
          synonym = "[NONE]"
          if(obj['synonym'] and obj['synonym'].is_a?(Array))
            synonym = obj['synonym'].join(",")
          end
          definition = "[NONE]"
          if(obj['definition'] and obj['definition'].is_a?(Array))
            definition = obj['definition'].join("</br>")
          end
          prefLabel = obj['prefLabel']
          resp.push( { 'prefLabel' => prefLabel, 'id' => id, 'type' => type, 'definition' => definition, 'synonym' => synonym, 'divId' => Time.now.to_f} )
          break if(ii == @limit)
        }
        
      end
      # Now we send out response to client
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "sending response to client") 
      sendAsyncResponse(resp, status)
    end
  
    # This method instantiates the EMDeferrable class and 'triggers' the response cascade by calling 'async.callback'.call()
    #  - Once the response headers are sent out, the EM framework calls the each() in the Deferreable class that we instantiate here.
    def sendAsyncResponse(resp, status)
      headers = {}
      headers['Content-Type'] = "text/plain"
      body = EMHTTPDeferrableBody.new()
      body.call_dequeue = false
      body.responseMessage = resp.to_json
      body.callSucceedAfterYieldingResponseMessage = true
      @env['async.callback'].call [status, headers, body]
    end
    
    
  end  
  
end