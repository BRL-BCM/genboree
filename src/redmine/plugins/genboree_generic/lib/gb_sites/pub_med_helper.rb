require 'em-http-request'
require 'brl/util/util'
require 'brl/em/emHttpDeferrableBody.rb'
require 'brl/sites/pubMeds/pubMed'



module GbSites
  class PubMedHelper
    attr_accessor :env
  
    def initialize(pmId)
      @pmId = pmId
    end
  
    # Redmine Controller Interface
    # Will be called in next_tick
    def start()
      begin
        pmObj = BRL::Sites::PubMeds::PubMed.fromId(@pmId, :eventmachine => true)
        pmObj.callback(self, :successHandler)
        pmObj.errback(self, :failureHandler)
        pmObj.retrieve()
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", err)
        failureHandler(nil, nil)
      end
    end
  
    def successHandler(xmlHash, infoHash)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "xmlHash#{xmlHash.inspect}")
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "infoHash - #{infoHash.inspect}")
      if(xmlHash.nil?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "in prepareFinalResp but xmlHash is nil.")
        logError(xmlHash, infoHash)
        resp = { 'msg' => "The PubMed document with id: #{@pmId} could not be found. If you believe this PubMed id exists, please contact a project manager to resolve the issue." }
        status = 404
      else
        status = 200
        resp = xmlHash
      end
      sendAsyncResponse(resp, 200)
    end
  
    def failureHandler(xmlHash, infoHash)
      logError(xmlHash, infoHash)
      status = 404
      resp = { 'msg' => "The PubMed document with id: #{@pmId} could not be found. If you believe this PubMed id exists, please contact a project manager to resolve the issue." }
      sendAsyncResponse(resp, status)
    end
  
    def logError(xmlHash, infoHash)
      $stderr.debugPuts(__FILE__, __method__, "GENE_REVIEW_ERROR", "infoHash dump:\n#{JSON.pretty_generate(infoHash)}") 
    end

    def sendAsyncResponse(resp, status)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "sending response to client")
      headers = {}
      headers['Content-Type'] = "text/plain"
      body = BRL::EM::EMHTTPDeferrableBody.new()
      body.call_dequeue = false
      body.responseMessage = JSON.generate(resp)
      body.callSucceedAfterYieldingResponseMessage = true
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "body - #{body.inspect}")
      @env['async.callback'].call [status, headers, body]
    end


  end  
end  
  
