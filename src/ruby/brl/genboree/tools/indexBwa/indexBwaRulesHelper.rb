require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'uri'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require "brl/genboree/helpers/sniffer"
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class IndexBwaRulesHelper < WorkbenchRulesHelper
    
    TOOL_ID = 'indexBwa'
    
    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        inputs = wbJobEntity.inputs
        outputs = wbJobEntity.outputs
        output = @dbApiHelper.extractPureUri(outputs[0])
        uri = URI.parse(output)
        host = uri.host
        rcscUri = uri.path
        rcscUri = rcscUri.chomp("?")
        
        ## Get Genome Version of output database
        @userId = wbJobEntity.context['userId']
        
        apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        genomeVersion = resp['version'].decapitalize
        wbJobEntity.settings['genomeVersion'] = genomeVersion

        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
          rulesSatisfied = true
          selectedEp = false
          settings = wbJobEntity.settings
          baseWidget = settings['baseWidget']
          settings.keys.each{ |key|
            if(key =~ /#{baseWidget}/)
              selectedEp = true
              break
            end
          }
          unless(selectedEp)
            errorMsg = "INVALID SELECTION: You should select at least one entrypoint to make a custom BWA index."
            wbJobEntity.context['wbErrorMsg'] = errorMsg
            rulesSatisfied = false
          else
            rulesSatisfied = true
          end
 
        end # if(sectionsToSatisfy.include?(:settings))
      end # if(rulesSatisfied)
      return rulesSatisfied
    end

    # It's a good idea to catch any potential errors now instead of relying on the job to do validation because,
    # the job may get queued and the user wouldn't be notified  for an unnecessarily long time that they have something minor wrong with their inputs.
    #
    # [+returns+] boolean
    def warningsExist?(wbJobEntity)
      warningsExist = true
      if(wbJobEntity.context['warningsConfirmed'])
        # The user has confirmed the warnings and wants to proceed
        warningsExist = false
      else # No warnings for now
        outputs = wbJobEntity.outputs
        output = @dbApiHelper.extractPureUri(outputs[0])
        uri = URI.parse(output)
        host = uri.host
        rcscUri = uri.path
        rcscUri = rcscUri.chomp("?")
      
        output.gsub!(/\?$/, '')  
        ## Get Genome Version of output database
        
        apiCaller = ApiCaller.new(host, rcscUri, @hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)['data']
        genomeVersion = resp['version'].decapitalize
        
        @indexBaseName =  CGI.escape(wbJobEntity.settings['indexBaseName'])      
        @outputIndexFile = "#{@indexBaseName}.tar.gz"
        filePath = "#{output}/file/indexFiles/BWA/#{@indexBaseName}/#{CGI.escape(@outputIndexFile)}?"

        ## Look for index in user db or repository db
        if(@fileApiHelper.exists?(filePath, @hostAuthMap))
          ## Index found in user db
          errorMsg = "Bwa Index with same name <b>#{@outputIndexFile}</b> is available in user DB <b>#{CGI.unescape(output)} </b>. Do you want to replace this index? "
          warnings = true
        else
          @roiRepositoryGroup = @genbConf.roiRepositoryGrp
          @roiRepoDb = "#{@roiRepositoryGroup}#{genomeVersion}"
          indexUri = URI.parse(@roiRepoDb)
          rsrcPath = indexUri.path
          @roiDirs = ['wholeGenome', 'eachChr']
          @roiDirs.each { |dirName|
            apiCaller = ApiCaller.new(indexUri.host, "#{rsrcPath}/files/indexFiles/BWA/#{CGI.escape(dirName)}/#{CGI.escape(@outputIndexFile)}", @hostAuthMap)
            apiCaller.get()
            if(apiCaller.succeeded?)
              ## The index is available in common database 
              errorMsg = "BWA Index with name <b>#{@outputIndexFile}</b> is available in repository DB <b>#{CGI.unescape(@roiRepoDb)}</b>. You may consider using the existing index or create a 
new index in your database with the same name.<br> Do you want to continue building the index?"
              warnings = true
            end # if(apiCaller.succeeded?)
          }
        end # if(apiCaller.succeeded?)
        #$stderr.puts "SETTINGS: #{wbJobEntity.settings.inspect}"
        if(warnings)
          wbJobEntity.context['wbErrorMsg'] = errorMsg
          wbJobEntity.context['wbErrorMsgHasHtml'] = true
        else
          warningsExist = false
        end
        $stderr.puts "SETTINGS: #{wbJobEntity.settings.inspect}"
      end # if(wbJobEntity.context['warningsConfirmed']) 
        
      # Clean up helpers, which cache many things
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      return warningsExist
    end # def warningsExist?(wbJobEntity)
  end
end ; end; end # module BRL ; module Genboree ; module Tools
