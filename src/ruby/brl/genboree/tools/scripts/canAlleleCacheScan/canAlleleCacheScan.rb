#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'sha1'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/util/expander'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/convertText'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class CanAlleleCacheScan < BRL::Genboree::Tools::ToolWrapper
    
    CA2EVIDENCE_CACHE_DOCUMENT_TEMPLATE = {
      "CanonicalAllele" => {
        "value" => "",
        "properties" => {
          "Evidence Docs" => {
            "items" => []
          }
        }
      }
    }
    
    EVIDENCE_DOC_OBJ = {
      "Evidence Doc" => {
        "value" => "",
        "properties" => {
          "FinalCalls" => {
            "items" => []
          }
        }
      }
    }
    
    GUIDELINE_DOC_OBJ = {
      "Guideline" => {
        "value" => "",
        "properties" => {
          "type" => {
            "value" => ""
          },
          "FinalCall" => {
            "value" => ""
          },
          "Version" => {
            "value" => ""
          }
        }
      }
    }
  
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used for scanning/updating the Conclusion/Ca2Evidence Caches for the pathogenicity calculator.",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        @targetUri = @outputs[0]
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        @deleteSourceFiles = @settings['deleteSourceFiles']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @toolScriptPrefix = @context['toolScriptPrefix']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        # Set up settings options
        @sourceRegCollURL = @settings['SourceRegistry']
        @conclusionCacheCollURL = @settings['ConclusionCache']
        @ca2EvidenceCacheCollURL = @settings['CA2EvidenceCache']
        @caSearchResults = @settings['CASearchResults']
        sourceRegHost = URI.parse(@sourceRegCollURL).host
        sourceRegDbrcRec = dbrc.getRecordByHost(sourceRegHost, "API-GB_CACHE_USER")
        @sourceRegApiUser = sourceRegDbrcRec[:user]
        @sourceRegApiPass = sourceRegDbrcRec[:password]
        
        conclusionCacheHost = URI.parse(@conclusionCacheCollURL).host
        conclusionCacheDbrcRec = dbrc.getRecordByHost(conclusionCacheHost, "API-GB_CACHE_USER")
        @concCacheApiUser = conclusionCacheDbrcRec[:user]
        @concCacheApiPass = conclusionCacheDbrcRec[:password]
        
        ca2EvidenceCacheHost = URI.parse(@ca2EvidenceCacheCollURL).host
        ca2EvidenceCacheDbrcRec = dbrc.getRecordByHost(ca2EvidenceCacheHost, "API-GB_CACHE_USER")
        @ca2EvidenceCacheApiUser = ca2EvidenceCacheDbrcRec[:user]
        @ca2EvidenceCacheApiPass = ca2EvidenceCacheDbrcRec[:password]
        @coll2Docs = {}
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    def run()
      begin
        @caUrlHash = {}
        @inputs.each {|input|
          @caUrlHash[SHA1.hexdigest(input)] = nil
        }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "@caUrlHash: #{@caUrlHash.inspect}")
        ca2EvidenceHash = Hash.new {|hh,kk| hh[kk] = Hash.new {|ii,mm| ii[mm] = {} }}
        # Get the ids of all the docs in the SourceRegistry collection and then get each document seperately
        docIds = getSourceRegDocIdList()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Retrieved doc list: #{docIds.inspect}")
        # Loop over each id and get the document
        # -- while looping over each document, collect the item list under SourceRegistry.EvidenceSources.EvidenceSource.Guidelines
        docIds.each {|docId|
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Processing docId: #{docId.inspect}")
          sourceRegDoc = getSourceRegDoc(docId)
          srDoc = BRL::Genboree::KB::KbDoc.new(sourceRegDoc)
          evidenceSources = srDoc.getPropItems("SourceRegistry.EvidenceSources")
          sc = 1
          evidenceSources.each {|es|
            esDoc = BRL::Genboree::KB::KbDoc.new(es)
            esValue = esDoc.getPropVal('EvidenceSource')
            evidenceCollUrl = esDoc.getPropVal('EvidenceSource.Evidence').gsub(/\/$/, "")
            transformUrl = esDoc.getPropVal('EvidenceSource.Transform')
            evidenceDocIds = getEvidenceDocs(evidenceCollUrl)
            evidenceDocIds.each {|evidenceDocId|
              evidenceUrl = "#{evidenceCollUrl.chomp("?")}/doc/#{CGI.escape(evidenceDocId)}"
              evidenceDoc = BRL::Genboree::KB::KbDoc.new(getEvidenceDoc(evidenceUrl))
              canAllele = evidenceDoc.getPropVal('Allele evidence.Subject')
              #$stderr.debugPuts(__FILE__, __method__, "STATUS", "canAllele: #{canAllele.inspect}")
              next if(!@caUrlHash.key?(SHA1.hexdigest(canAllele)))
              #$stderr.debugPuts(__FILE__, __method__, "STATUS", "Canonical Allele present in inputs")
              if(!ca2EvidenceHash.key?(canAllele))
                ca2EvidenceHash[canAllele]
              end
              ca2EvidenceHash[canAllele][evidenceUrl]
              guidelines = esDoc.getPropItems('EvidenceSource.Guidelines')
              if(guidelines.nil? or guidelines.empty?)
                # Do nothing. 'guideline' hash will remain as empty. "FinalCalls" list will be empty       
              else
                guidelines.each {|gdoc|
                  guidelineDoc = BRL::Genboree::KB::KbDoc.new(gdoc)
                  guidelineUrl = guidelineDoc.getPropVal('Guideline').gsub(/\/$/, "")
                  conclusionDoc = nil
                  # Use guidelineUrl and evidenceUrl to search doc in ConclusionCache collection
                  conclusionDocument = getConclusionDoc(evidenceUrl, guidelineUrl)
                  if(conclusionDocument) # A previous conclusion document exists. Check if it's up to date
                    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Conclusion doc found")
                    newDoc = false
                    conclusionDoc = BRL::Genboree::KB::KbDoc.new(conclusionDocument)
                    version = conclusionDoc.getPropVal('ConclusionCacheID.Evidence Doc.Version')
                    headVer = getEvidenceDocHeadVer(conclusionDoc.getPropVal('ConclusionCacheID.Evidence Doc'))
                    # Extract version and match against version in conclusion doc
                    type = conclusionDoc.getPropVal('ConclusionCacheID.Type')
                    if(version.to_i == headVer)
                      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Head version of evidence document matches version in conclusion document. Reasonser run not required.")
                    else
                      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Head version of evidence document does NOT match version in conclusion document. Reasoner run required.")
                      status = runReasoner(evidenceUrl, guidelineUrl, transformUrl, conclusionDoc, type)
                      if(status == :ReasonerRunCompletedAndDocUploaded) # Everything went OK. 
                        updatedConclusionDocument = getConclusionDoc(evidenceUrl, guidelineUrl)
                        conclusionDoc = BRL::Genboree::KB::KbDoc.new(updatedConclusionDocument)
                        version = conclusionDoc.getPropVal('ConclusionCacheID.Evidence Doc.Version')
                      else # Something went wrong. Use the older cache
                        # version will remain the same as before
                      end
                    end
                    finalCall = conclusionDoc.getPropVal('ConclusionCacheID.FinalCall')
                    gHash = { :version => version, :type => type, :finalCall => finalCall }
                    ca2EvidenceHash[canAllele][evidenceUrl][guidelineUrl] = gHash
                  else # There is no conclusion document. Run the reasoner
                    $stderr.debugPuts(__FILE__, __method__, "CACHE_MISSING", "Conclusion doc not found. Reasoner run required.")
                    finalCall = nil
                    version = nil
                    status = runReasoner(evidenceUrl, guidelineUrl, transformUrl, conclusionDoc, type)
                    if(status == :ReasonerRunCompletedAndDocUploaded) # Everything went OK. 
                      updatedConclusionDocument = getConclusionDoc(evidenceUrl, guidelineUrl)
                      conclusionDoc = BRL::Genboree::KB::KbDoc.new(updatedConclusionDocument)
                      version = conclusionDoc.getPropVal('ConclusionCacheID.Evidence Doc.Version')
                      finalCall = conclusionDoc.getPropVal('ConclusionCacheID.FinalCall')
                    else # Something went wrong. Will use 'undetermined' for final call
                      finalCall = "Undetermined"
                      version = getEvidenceDocHeadVer(evidenceUrl)
                    end
                    type = guidelineDoc.getPropVal('Guideline.type')
                    gHash = { :version => version, :type => type, :finalCall => finalCall }
                    ca2EvidenceHash[canAllele][evidenceUrl][guidelineUrl] = gHash
                  end
                }
              end
            }
            sc += 1
          }
        }
        uploadDocs(ca2EvidenceHash)
      rescue => err
        @err = err
        @errUserMsg = err.message
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      end
      return @exitCode
    end
    
    def getEvidenceDoc(url)
      uriObj = URI.parse(url)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}",  @sourceRegApiUser, @sourceRegApiPass)
      apiCaller.get()
      raise "Could not find evidence doc: #{url}.\nAPI Response: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
      return apiCaller.parseRespBody['data']
    end
    
    
    def uploadDocs(ca2EvidenceHash)
      # Go through the data structure and construct the CA2EvidenceCache docs one at a time
      ca2EvidenceHash.each_key { |ca|
        ca2EvidenceDoc = BRL::Genboree::KB::KbDoc.new(CA2EVIDENCE_CACHE_DOCUMENT_TEMPLATE.deep_clone)
        ca2EvidenceDoc.setPropVal('CanonicalAllele', ca)
        evidenceDocs = []
        ca2EvidenceHash[ca].each_key { |eu|
          evidenceDocObj = BRL::Genboree::KB::KbDoc.new(EVIDENCE_DOC_OBJ.deep_clone)
          evidenceDocObj.setPropVal('Evidence Doc', eu)
          finalCalls = []
          ca2EvidenceHash[ca][eu].each_key { |gu|
            gdoc = BRL::Genboree::KB::KbDoc.new(GUIDELINE_DOC_OBJ.deep_clone)
            gdoc.setPropVal('Guideline', gu)
            type = ca2EvidenceHash[ca][eu][gu][:type]
            finalCall = ca2EvidenceHash[ca][eu][gu][:finalCall]
            version = ca2EvidenceHash[ca][eu][gu][:version]
            gdoc.setPropVal('Guideline.type', type)
            gdoc.setPropVal('Guideline.FinalCall', finalCall)
            gdoc.setPropVal('Guideline.Version', version)
            finalCalls.push(gdoc)
          }
          evidenceDocObj.setPropItems('Evidence Doc.FinalCalls', finalCalls)
          evidenceDocs.push(evidenceDocObj)
        }
        ca2EvidenceDoc.setPropItems('CanonicalAllele.Evidence Docs', evidenceDocs)
        # We have the CA2EvidenceCache document to upload
        uploadCA2EvidenceCacheDoc(ca2EvidenceDoc)
      }
    end
    
    def uploadCA2EvidenceCacheDoc(doc)
      retVal = false
      uriObj = URI.parse(@ca2EvidenceCacheCollURL)
      host = uriObj.host
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "#{uriObj.path}/doc/{doc}", @ca2EvidenceCacheApiUser, @ca2EvidenceCacheApiPass)
      docId = doc['CanonicalAllele']['value']
      apiCaller.put( { :doc => docId }, doc.to_json )
      if(!apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not upload CA2evidenceCache doc: #{docId.inspect}\nAPI Response: #{apiCaller.respBody.inspect}") 
      else
        retVal = true
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "CA2EvidenceCache: #{docId} uploaded.")
      end
      return retVal 
    end

    def runReasoner(evidenceUrl, guidelineUrl, transformUrl, conclusionDoc, type)
      retVal = :ReasonerRunFailed
      host = URI.parse(@sourceRegCollURL).host
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "/REST/v1/genboree/tool/reasonerV2a1/job?", @sourceRegApiUser, @sourceRegApiPass)
      $stderr.puts "\n\nRunning reasoner for:\n---evidenceUrl: #{evidenceUrl}\n---guidelineUrl: #{guidelineUrl}\n---transformUrl: #{transformUrl}\n\n"
      inputs = [evidenceUrl, transformUrl]
      outputs = []
      settings = { "rulesDoc" => guidelineUrl}
      context = {}
      payload = { "inputs" => inputs, "outputs" => outputs, "settings" => settings, "context" => context }
      #$stderr.puts "payload:\n#{payload.inspect}"
      apiCaller.put( {}, payload.to_json )
      if(apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "API-SUCCESS", "Reasoner ran successfully.")
        retVal = :ReasonerRunCompletedAndDocUploaded
        reasonerOutputDoc = BRL::Genboree::KB::KbDoc.new(apiCaller.parseRespBody['data'])
        evidenceDocVer = getEvidenceDocHeadVer(evidenceUrl)
        if(conclusionDoc) # Doc exists. We will update it
          # only update Evidence Doc version, FinalCall and ReasonerOutput
          conclusionDoc.setPropVal('ConclusionCacheID.Evidence Doc.Version', evidenceDocVer)
          conclusionDoc.setPropVal('ConclusionCacheID.FinalCall', reasonerOutputDoc.getPropVal('Reasoner output.FinalCall'))
          conclusionDoc.setPropVal('ConclusionCacheID.ReasonerOutput', reasonerOutputDoc)
        else # We will insert a new ConclusionCacheDoc
          conclusionDoc = BRL::Genboree::KB::KbDoc.new(CONCLUSION_CACHE_DOCUMENT_TEMPLATE.deep_clone)
          conclusionDoc.setPropVal('ConclusionCacheID.Evidence Doc', evidenceUrl)
          conclusionDoc.setPropVal('ConclusionCacheID.Evidence Doc.Version', evidenceDocVer)
          conclusionDoc.setPropVal('ConclusionCacheID.Guideline', guidelineUrl)
          conclusionDoc.setPropVal('ConclusionCacheID.Type', type)
          conclusionDoc.setPropVal('ConclusionCacheID.FinalCall', reasonerOutputDoc.getPropVal('Reasoner output.FinalCall'))
          conclusionDoc.setPropVal('ConclusionCacheID.ReasonerOutput', reasonerOutputDoc)
        end
        # Upload ConclusionCache document
        uploadStatus = uploadConclusionDoc(conclusionDoc)
        unless(uploadStatus)
          retVal = :ReasonerRunCompletedButDocUploadFailed
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "API-ERROR", apiCaller.respBody.inspect)
      end
      return retVal
    end
     
     
    def uploadConclusionDoc(conclusionDoc)
      retVal = false
      uriObj = URI.parse(@conclusionCacheCollURL)
      host = uriObj.host
      apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "#{uriObj.path}/doc/{doc}", @concCacheApiUser, @concCacheApiPass)
      docId = conclusionDoc.getPropVal('ConclusionCacheID')
      apiCaller.put( { :doc => docId }, conclusionDoc.to_json )
      if(!apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not upload conclusion cache doc (Empty docId means new document): #{docId.inspect}\nAPI Response: #{apiCaller.respBody.inspect}") 
      else
        retVal = true
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "ConclusionCache: #{docId} uploaded. (Empty docId means new document)")
      end
      return retVal 
    end
     
    def getEvidenceDocHeadVer(url)
      uriObj = URI.parse(url)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}/ver/HEAD?versionNumOnly=true",  @sourceRegApiUser, @sourceRegApiPass)
      apiCaller.get()
      raise "Could not find evidence doc: #{url}.\nAPI Response: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
      return apiCaller.parseRespBody['data']['number']
    end
     
    def getEvidenceDocs(url)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Retrieving evidence docs for #{url.inspect}")
      retVal = nil
      if(@coll2Docs.key?(url))
        retVal = @coll2Docs[url]
      else
        uriObj = URI.parse(url)
        #$stderr.debugPuts(__FILE__, __method__, "STATUS", "uriObj: #{uriObj.inspect}")
        apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}/docs?detailed=false", @sourceRegApiUser, @sourceRegApiPass)
        apiCaller.get()
        raise "Could not get evidence docs: #{url}.\nAPI Response: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
        docs = apiCaller.parseRespBody['data']
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Retrieved evidence doc ids. Size: #{docs.size}")
        docIds = []
        if(!docs.empty?)
          identifier = docs.first.keys[0]
          docs.each {|doc|
            docId = doc[identifier]['value']
            docIds.push(docId)
          }
        end
        @coll2Docs[url] = docIds
        retVal = docIds
      end
      return retVal 
    end
     
    def getSourceRegDoc(docId)
      uriObj = URI.parse(@sourceRegCollURL)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}/doc/{doc}", @sourceRegApiUser, @sourceRegApiPass)
      apiCaller.get( { :doc => docId } )
      raise "Could not find evidence doc: #{docId}.\nAPI Response: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
      return apiCaller.parseRespBody['data']
    end
     
    def getConclusionDoc(evidenceUrl, guidelineUrl)
      uriObj = URI.parse(@conclusionCacheCollURL)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Checking conclusion doc for:\n--evidenceUrl: #{evidenceUrl.inspect}\n--guidelineUrl: #{guidelineUrl.inspect}\n\n")
      rsrcPath = "#{uriObj.path}/docs?detailed=true&matchProps={matchProps}&matchValues={matchValues}&matchMode=exact&matchLogicOp=and"
      apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, rsrcPath, @concCacheApiUser, @concCacheApiPass)
      apiCaller.get( { :matchProps => "ConclusionCacheID.Evidence Doc,ConclusionCacheID.Guideline", :matchValues => "#{evidenceUrl},#{guidelineUrl}" } )
      return ( apiCaller.succeeded? ? apiCaller.parseRespBody['data'][0] : nil )
    end
     
     
    def getSourceRegDocIdList()
      uriObj = URI.parse(@sourceRegCollURL)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}/docs?detailed=false", @sourceRegApiUser, @sourceRegApiPass)
      #$stderr.puts "@sourceRegApiUser: #{@sourceRegApiUser.inspect}; @sourceRegApiPass: #{@sourceRegApiPass.inspect}"
      apiCaller.get()
      raise "Unable to retrieve doc ids for SourceRegistry collection.\nApi response: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
      docs = apiCaller.parseRespBody['data']
      docIds = []
      if(!docs.empty?)
        identifier = docs.first.keys[0]
        docs.each {|doc|
          docIds.push(doc[identifier]['value'])
        }
      else
        raise "No Docs found in SourceRegistry collection."
      end
      return docIds
    end

    # Send success email
    # [+returns+] emailObj
    def prepSuccessEmail()
      additionalInfo = "\nThe Conclusion and Evidence cache scan is complete and the collections have been updated with the latest reasoner outputs.\n\n"
      additionalInfo << "Click on the link below to go the entry page:\n#{@caSearchResults}\n\n" if(@caSearchResults and !@caSearchResults.empty?)
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      if(@suppressEmail)
        return nil
      else
        return successEmailObject
      end
    end

    # Send failure/error email
    # [+returns+] emailObj
    def prepErrorEmail()
      additionalInfo = "     Error:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      if(@suppressEmail)
        return nil
      else
        return errorEmailObject
      end
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::CanAlleleCacheScan)
end
