#!/usr/bin/env ruby

require 'cgi'
require 'json'
require 'brl/genboree/dbUtil'
require 'brl/db/dbrc'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/rest/apiCaller'

class Config2EvidenceCachePopulation
  
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
  
  #CA2EVIDENCE_CACHE_DOCUMENT_TEMPLATE = {
  #  "EvidenceCacheID" => {
  #    "value" => "",
  #    "properties" => {
  #      #"Evidence Doc" => {
  #      #  "value" => ""
  #      #},
  #      #"Guideline" => {
  #      #  "value" => ""
  #      #},
  #      #"CanonicalAllele" => {
  #      #  "value" => ""
  #      #},
  #      "EvidenceDocVersion" => {
  #        "value" => 0
  #      },
  #      "Type" => {
  #        "value" => ""
  #      },
  #      "FinalCall" => {
  #        "value" => ""
  #      }
  #    }
  #  }
  #}
  
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
  
  def establishCreds(sourceRegUrl, conclusionCacheUrl, ca2EvidenceCacheUrl)
    @sourceRegCollURL = sourceRegUrl
    @conclusionCacheCollURL = conclusionCacheUrl
    @ca2EvidenceCacheCollURL = ca2EvidenceCacheUrl
    
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
    
    ca2EvidenceCacheHost = URI.parse(@ca2EvidenceCacheCollURL).host
    ca2EvidenceCacheDbrcRec = dbrc.getRecordByHost(ca2EvidenceCacheHost, "API-GB_CACHE_USER")
    @ca2EvidenceCacheApiUser = ca2EvidenceCacheDbrcRec[:user]
    @ca2EvidenceCacheApiPass = ca2EvidenceCacheDbrcRec[:password]
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
  
  def uploadCA2EvidenceCacheDocs(docs)
    retVal = false
    uriObj = URI.parse(@ca2EvidenceCacheCollURL)
    host = uriObj.host
    apiCaller = BRL::Genboree::REST::ApiCaller.new(host, "#{uriObj.path}/docs", @ca2EvidenceCacheApiUser, @ca2EvidenceCacheApiPass)
    apiCaller.put( {  }, docs.to_json )
    if(!apiCaller.succeeded?)
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not upload CA2evidenceCache docs\nAPI Response: #{apiCaller.respBody.inspect}") 
    else
      retVal = true
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "CA2EvidenceCache docs uploaded.")
    end
    return retVal 
  end
  

  
  def getEvidenceDoc(url)
    uriObj = URI.parse(url)
    apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}",  @sourceRegApiUser, @sourceRegApiPass)
    apiCaller.get()
    raise "Could not find evidence doc: #{url}.\nAPI Response: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
    return apiCaller.parseRespBody['data']
  end
  
  
  def getEvidenceDocs(collUrl, docIds)
    uriObj = URI.parse(collUrl)
    apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}/docs?detailed=true&matchValues={mv}",  @sourceRegApiUser, @sourceRegApiPass)
    apiCaller.get( { :mv => docIds.join(",") })
    raise "Could not retrieve evidence docs in collection: #{collUrl}.\nAPI Response: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
    return apiCaller.parseRespBody['data']
  end
   
   
  def getEvidenceDocIds(url)
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
      if(docs.size > 0)
        docIds = []
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
  
  def getEvidenceDocHeadVer(url)
    uriObj = URI.parse(url)
    apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}/ver/HEAD?versionNumOnly=true",  @sourceRegApiUser, @sourceRegApiPass)
    apiCaller.get()
    raise "Could not find evidence doc: #{url}.\nAPI Response: #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
    return apiCaller.parseRespBody['data']['number']
  end
  
  def getSourceRegDocIdList()
    uriObj = URI.parse(@sourceRegCollURL)
    apiCaller = BRL::Genboree::REST::ApiCaller.new(uriObj.host, "#{uriObj.path}/docs?detailed=false", @sourceRegApiUser, @sourceRegApiPass)
    #$stderr.puts "apiCaller:\n#{apiCaller.inspect}"
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
raise "\n\nERROR: script takes 1 arg: location to json config file with URLs to SourceRegistry and CA2EvidenceCache collections i.e.:\n  ruby ./ca2EvidenceCachePrimer.rb {path to json config} \n\n" unless(ARGV.size == 1)
# Gather args
raise "File: #{ARGV[0]} does not exist. " if(!File.exists?(ARGV[0]))
$stderr.puts "************************************"
$stderr.debugPuts(__FILE__, __method__, "STATUS", "Beginning script run\n")
summaryHash = {}

begin
  ecpObj = Config2EvidenceCachePopulation.new(ARGV[0])
  configDocIds = ecpObj.getConfigDocIds()
  configDocIds.each { |configDocId|
    ca2EvidenceHash = Hash.new {|hh,kk| hh[kk] = Hash.new {|ii,mm| ii[mm] = {} }}
    # Get the ids of all the docs in the SourceRegistry collection and then get each document seperately
    configDoc = ecpObj.getConfigDoc(configDocId)
    next if(configDoc.nil?)
    configDoc = BRL::Genboree::KB::KbDoc.new(configDoc)
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Processing config doc: #{configDoc.getPropVal('Configuration')}")
    sourceRegUrl = configDoc.getPropVal('Configuration.EvidenceSource')
    concCacheUrl = configDoc.getPropVal('Configuration.ConclusionCache')
    ca2EvCacheUrl = configDoc.getPropVal('Configuration.CA2EvidenceCache')
    #next if(concCacheUrl =~ /genboree/ or concCacheUrl =~ /valine/ or ca2EvCacheUrl =~ /genboree/) # Skip prod caches for now.
    ecpObj.establishCreds(sourceRegUrl, concCacheUrl, ca2EvCacheUrl)
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Credentials established for #{sourceRegUrl.inspect} and #{concCacheUrl.inspect}")
    docIds = ecpObj.getSourceRegDocIdList()
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Retrieved doc list")
    # Loop over each id and get the document
    # -- while looping over each document, collect the item list under SourceRegistry.EvidenceSources.EvidenceSource.Guidelines
    docIds.each {|docId|
      sourceRegDoc = ecpObj.getSourceRegDoc(docId)
      srDoc = BRL::Genboree::KB::KbDoc.new(sourceRegDoc)
      evidenceSources = srDoc.getPropItems("SourceRegistry.EvidenceSources")
      sc = 1
      evidenceSources.each {|es|
        #break if(sc == 10)
        esDoc = BRL::Genboree::KB::KbDoc.new(es)
        evidenceCollUrl = esDoc.getPropVal('EvidenceSource.Evidence').gsub(/\/$/, "")
        evidenceDocIds = ecpObj.getEvidenceDocIds(evidenceCollUrl)
        next if(evidenceDocIds.nil?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Retrieved evidence doc ids")
        evidenceDocIds.each_slice(10) {|evidenceDocIdSubset|
          evidenceDocs = ecpObj.getEvidenceDocs(evidenceCollUrl, evidenceDocIdSubset)
          evidenceDocs.each {|evidenceDoc|
            evidenceDoc = BRL::Genboree::KB::KbDoc.new(evidenceDoc)
            evidenceDocId = evidenceDoc.getPropVal('Allele evidence')
            evidenceUrl = "#{evidenceCollUrl.chomp("?")}/doc/#{CGI.escape(evidenceDocId)}"
            canAllele = evidenceDoc.getPropVal('Allele evidence.Subject')
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
                conclusionDocs = ecpObj.getConclusionDoc(evidenceUrl, guidelineUrl)
                if(conclusionDocs and conclusionDocs.size > 0)
                  $stderr.debugPuts(__FILE__, __method__, "STATUS", "Conclusion doc found")
                  conclusionDoc = BRL::Genboree::KB::KbDoc.new(conclusionDocs[0])
                  version = conclusionDoc.getPropVal('ConclusionCacheID.Evidence Doc.Version')
                  type = guidelineDoc.getPropVal('Guideline.type')
                  finalCall = conclusionDoc.getPropVal('ConclusionCacheID.FinalCall')
                  gHash = { :version => version, :type => type, :finalCall => finalCall }
                  ca2EvidenceHash[canAllele][evidenceUrl][guidelineUrl] = gHash
                else
                  $stderr.debugPuts(__FILE__, __method__, "CACHE_MISSING", "Conclusion doc not found.")
                  version = ecpObj.getEvidenceDocHeadVer(evidenceUrl)
                  type = guidelineDoc.getPropVal('Guideline.type')
                  finalCall = "Undetermined"
                  gHash = { :version => version, :type => type, :finalCall => finalCall }
                  ca2EvidenceHash[canAllele][evidenceUrl][guidelineUrl] = gHash
                end
              }
            end
          }
        }
        sc += 1
      }
    }
    cc = 1
    # Go through the data structure and construct the CA2EvidenceCache docs one at a time
    uploadDocs = []
    ca2EvidenceHash.each_key { |ca|
      ca2EvidenceDoc = BRL::Genboree::KB::KbDoc.new(Config2EvidenceCachePopulation::CA2EVIDENCE_CACHE_DOCUMENT_TEMPLATE.deep_clone)
      ca2EvidenceDoc.setPropVal('CanonicalAllele', ca)
      evidenceDocs = []
      ca2EvidenceHash[ca].each_key { |eu|
        evidenceDocObj = BRL::Genboree::KB::KbDoc.new(Config2EvidenceCachePopulation::EVIDENCE_DOC_OBJ.deep_clone)
        evidenceDocObj.setPropVal('Evidence Doc', eu)
        finalCalls = []
        ca2EvidenceHash[ca][eu].each_key { |gu|
          gdoc = BRL::Genboree::KB::KbDoc.new(Config2EvidenceCachePopulation::GUIDELINE_DOC_OBJ.deep_clone)
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
      #$stderr.puts "doc:\n\n#{ca2EvidenceDoc.inspect}" if(cc == 1)
      uploadDocs.push(ca2EvidenceDoc)
      if(uploadDocs.size >= 50)
        ecpObj.uploadCA2EvidenceCacheDocs(uploadDocs)
        uploadDocs.clear
      end
      cc += 1
    }
    if(uploadDocs.size > 0)
      ecpObj.uploadCA2EvidenceCacheDocs(uploadDocs)
      uploadDocs.clear
    end
    ca2EvidenceHash = nil
  }
  
  $stderr.debugPuts(__FILE__, __method__, "STATUS", "[SUCCESS]")
rescue => err
  $stderr.debugPuts(__FILE__, __method__, "ERROR", err)
  $stderr.debugPuts(__FILE__, __method__, "TRACE", err.backtrace.join("\n"))
  # @todo: send email?
  $stderr.debugPuts(__FILE__, __method__, "STATUS", "[FAILED]")
  exit(10)
end

$stderr.puts "************************************"
