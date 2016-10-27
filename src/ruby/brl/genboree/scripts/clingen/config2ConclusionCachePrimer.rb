#!/usr/bin/env ruby

require 'cgi'
require 'json'
require 'brl/genboree/dbUtil'
require 'brl/db/dbrc'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/rest/apiCaller'

class Config2ConclusionCache
  
  CONCLUSION_CACHE_DOCUMENT_TEMPLATE = {
    "ConclusionCacheID" => {
      "value" => "",
      "properties" => {
        "Evidence Doc" => {
          "value" => "",  
          "properties" => {
            "Version" => {
              "value" => ""
            }
          }
        },
        "Guideline" => {
          "value" => ""
        },
        "Type" => {
          "value" => ""
        },
        "FinalCall" => {
          "value" => ""
        },
        "ReasonerOutput" => {
          "value" => ""
        },
      }
    }
  }
  
  def initialize(jsonConfigFile)
    @jsonConfig = JSON.parse(File.read(jsonConfigFile))
    @configCollURL = @jsonConfig['configCollURL']
    dbrc = BRL::DB::DBRC.new()
    configUrlHost = URI.parse(@configCollURL).host
    configUrlDbrcRec = dbrc.getRecordByHost(configUrlHost, "API-GB_CACHE_USER")
    @configUrlApiUser = configUrlDbrcRec[:user]
    @configUrlApiPass = configUrlDbrcRec[:password]
    @sourceRegCollURL = nil
    @conclusionCacheCollURL = nil
    @coll2Docs = {}
  end

  def getConfigDocIds()
    uriObj = URI.parse(@configCollURL)
    apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}/docs?detailed=false",  @configUrlApiUser, @configUrlApiPass)
    apiCaller.get()
    raise "Could not retrieve docs.\nAPI Response: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
    docs = apiCaller.parseRespBody['data']
    docIds = []
    identifier = docs.first.keys[0]
    docs.each {|doc|
      docId = doc[identifier]['value']
      docIds.push(docId)
    }
    return docIds
  end
  
  def getConfigDoc(docId)
    retVal = nil
    uriObj = URI.parse(@configCollURL)
    apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}/doc/{docId}?",  @configUrlApiUser, @configUrlApiPass)
    apiCaller.get({:docId => docId})
    if(!apiCaller.succeeded?)
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not retrieve config doc: #{docId}\n\n#{apiCaller.respBody.inspect}")
      $stderr.puts "Moving to next config doc..."
    else
      retVal =  apiCaller.parseRespBody['data']
    end
    return retVal
  end
  
  def establishCreds(sourceRegUrl, conclusionCacheUrl)
    @sourceRegCollURL = sourceRegUrl
    @conclusionCacheCollURL = conclusionCacheUrl
    
    # Standard setup stuff
    dbrc = BRL::DB::DBRC.new()
    sourceRegHost = URI.parse(@sourceRegCollURL).host
    sourceRegDbrcRec = dbrc.getRecordByHost(sourceRegHost, "API-GB_CACHE_USER")
    @sourceRegApiUser = sourceRegDbrcRec[:user]
    @sourceRegApiPass = sourceRegDbrcRec[:password]
    
    conclusionCacheHost = URI.parse(@conclusionCacheCollURL).host
    conclusionCacheDbrcRec = dbrc.getRecordByHost(conclusionCacheHost, "API-GB_CACHE_USER")
    @concCacheApiUser = conclusionCacheDbrcRec[:user]
    @concCacheApiPass = conclusionCacheDbrcRec[:password]
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
      docIds = []
      if(docs.size > 0)
        identifier = docs.first.keys[0]
        docs.each {|doc|
          docId = doc[identifier]['value']
          docIds.push(docId)
        }
        @coll2Docs[url] = docIds
        retVal = docIds
      end
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
    return ( apiCaller.succeeded? ? apiCaller.parseRespBody['data'] : nil )
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
end

# Start the script
raise "\n\nERROR: script takes 1 arg: location to json config file with URL to config collection i.e.:\n  ruby ./config2ConclusionCachePrimer.rb {path to json config} \n\n" unless(ARGV.size == 1)
# Gather args
raise "File: #{ARGV[0]} does not exist. " if(!File.exists?(ARGV[0]))
$stderr.puts "************************************"
$stderr.debugPuts(__FILE__, __method__, "STATUS", "Beginning script run\n")
summaryHash = {}
begin
  ccpObj = Config2ConclusionCache.new(ARGV[0])
  configDocIds = ccpObj.getConfigDocIds()
  configDocIds.each {|configDocId|
    configDoc = ccpObj.getConfigDoc(configDocId)
    next if(configDoc.nil?)
    configDoc = BRL::Genboree::KB::KbDoc.new(configDoc)
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Processing config doc: #{configDoc.getPropVal('Configuration')}")
    sourceRegUrl = configDoc.getPropVal('Configuration.EvidenceSource')
    concCacheUrl = configDoc.getPropVal('Configuration.ConclusionCache')
    #next if(concCacheUrl =~ /genboree/ or concCacheUrl =~ /valine/) # Skip prod caches for now.
    ccpObj.establishCreds(sourceRegUrl, concCacheUrl)
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Credentials established for #{sourceRegUrl.inspect} and #{concCacheUrl.inspect}")
    # Get the ids of all the docs in the SourceRegistry collection and then get each document seperately
    docIds = ccpObj.getSourceRegDocIdList()
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Retrieved doc list")
    # Loop over each id and get the document
    # -- while looping over each document, collect the item list under SourceRegistry.EvidenceSources.EvidenceSource.Guidelines
    docIds.each {|docId|
      summaryHash[docId] = {}
      sourceRegDoc = ccpObj.getSourceRegDoc(docId)
      srDoc = BRL::Genboree::KB::KbDoc.new(sourceRegDoc)
      evidenceSources = srDoc.getPropItems("SourceRegistry.EvidenceSources")
      evidenceSources.each {|es|
        esDoc = BRL::Genboree::KB::KbDoc.new(es)
        esValue = esDoc.getPropVal('EvidenceSource')
        summaryHash[docId][esValue] = []
        evidenceCollUrl = esDoc.getPropVal('EvidenceSource.Evidence').gsub(/\/$/, "")
        transformUrl = esDoc.getPropVal('EvidenceSource.Transform')
        evidenceDocIds = ccpObj.getEvidenceDocs(evidenceCollUrl)
        next if(evidenceDocIds.nil?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Retrieved evidence doc ids")
        evidenceDocIds.each {|evidenceDocId|
          summObj = {}
          evidenceUrl = "#{evidenceCollUrl.chomp("?")}/doc/#{CGI.escape(evidenceDocId)}"
          summObj[:transformUrl] = transformUrl
          summObj[:evidenceUrl] = evidenceUrl
          summObj[:guidelines] = []
          guidelines = esDoc.getPropItems('EvidenceSource.Guidelines')
          next if(guidelines.nil?)
          guidelines.each {|gdoc|
            guidelineDoc = BRL::Genboree::KB::KbDoc.new(gdoc)
            guidelineUrl = guidelineDoc.getPropVal('Guideline').gsub(/\/$/, "")
            statusObj = {}
            statusObj[:guidelineUrl] = guidelineUrl
            updateRequired = true
            conclusionDoc = nil
            # Use guidelineUrl and evidenceUrl to search doc in ConclusionCache collection
            conclusionDocs = ccpObj.getConclusionDoc(evidenceUrl, guidelineUrl)
            if(conclusionDocs and conclusionDocs.size > 0)
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Conclusion doc found")
              conclusionDoc = BRL::Genboree::KB::KbDoc.new(conclusionDocs[0])
              version = conclusionDoc.getPropVal('ConclusionCacheID.Evidence Doc.Version')
              headVer = ccpObj.getEvidenceDocHeadVer(conclusionDoc.getPropVal('ConclusionCacheID.Evidence Doc'))
              # Extract version and match against version in conclusion doc
              if(version.to_i == headVer)
                updateRequired = false 
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Head version of evidence document matches version in conclusion document. Update NOT required.")
              else
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Head version of evidence document does NOT match version in conclusion document.")
              end
            else
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Conclusion doc not found")
            end
            if(updateRequired)
              # Run reasoner
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Update required.")
              type = guidelineDoc.getPropVal('Guideline.type')
              statusObj[:status] = ccpObj.runReasoner(evidenceUrl, guidelineUrl, transformUrl, conclusionDoc, type)
            else
              statusObj[:status] = :ReasonerRunNotRequired
            end
            summObj[:guidelines].push(statusObj)
          }
          summaryHash[docId][esValue].push(summObj)
        }
      }
    }
  }
  $stderr.debugPuts(__FILE__, __method__, "STATUS", "[SUCCESS]")
  # Print the summary report
  $stdout.puts "DocID\tEvidenceSource\tEvidenceURL\tTransformURL\tGuidelineURL\tStatus"
  summaryHash.each_key { |sourceRegDocId|
    summaryHash[sourceRegDocId].each_key { |evidenceSource|
      summItems = summaryHash[sourceRegDocId][evidenceSource]
      summItems.each {|summObj|
        evidenceUrl = summObj[:evidenceUrl]  
        transformUrl = summObj[:transformUrl]
        guidelines = summObj[:guidelines]
        guidelines.each {|gobj|
          guidelineUrl = gobj[:guidelineUrl]
          status = gobj[:status]
          $stdout.puts "#{sourceRegDocId}\t#{evidenceSource}\t#{evidenceUrl}\t#{transformUrl}\t#{guidelineUrl}\t#{status.to_s}"
        }
      }
    }
  }
rescue => err
  $stderr.debugPuts(__FILE__, __method__, "ERROR", err)
  $stderr.debugPuts(__FILE__, __method__, "TRACE", err.backtrace.join("\n"))
  # @todo: send email?
  $stderr.debugPuts(__FILE__, __method__, "STATUS", "[FAILED]")
  exit(10)
end

$stderr.puts "************************************"
