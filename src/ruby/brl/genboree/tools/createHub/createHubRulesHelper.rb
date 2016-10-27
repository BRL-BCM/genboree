require 'uri'
require 'tempfile'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/helpers/sniffer'
require 'brl/genboree/tools/workbenchRulesHelper'
require 'brl/genboree/tools/workbenchFormHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackEntityListApiUriHelper'
require 'brl/genboree/rest/helpers/classApiUriHelper'

include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class CreateHubRulesHelper < WorkbenchRulesHelper

    TOOL_ID = 'createHub'

    def rulesSatisfied?(wbJobEntity, sectionsToSatisfy=[ :inputs, :outputs, :context, :settings ], toolIdStr=@toolIdStr)
      # Apply basic rules from the rules file (counts, basic types, other simple things)
      rulesSatisfied = super(wbJobEntity, sectionsToSatisfy, toolIdStr)
      if(rulesSatisfied)
        @inputs = wbJobEntity.inputs
        @outputs = wbJobEntity.outputs
        @user = wbJobEntity.context['userLogin']
        @userId = wbJobEntity.context['userId']
        @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)

        #CHECK 1: Check for user permissions
        permissions = true
        @pureGrpUris = Hash.new{|hh, kk| hh[kk] = {"role" => nil}}  
        @pureDbUris = Hash.new {|hh, kk| hh[kk] = {"dbPublic" => false, "gbKeyPublic" => nil}}
        @inputs.each{ |input|
          grpUri = @grpApiHelper.extractPureUri(input)
          @pureGrpUris[grpUri] 
          dburi = @dbApiHelper.extractPureUri(input)
          @pureDbUris[dburi]
        }
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "DBURIS: #{@pureDbUris.inspect}")
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "GRPURIS: #{@pureGrpUris.inspect}")
        
        # Check whether all the dbs are public and unlocked WITH gbKey public.
        # Permissions are waived if so, i.e, if the databases are already public and unlocked with gbKey public.
        @privateDbs = Array.new()
        @lockedDbs = Array.new() 

        # Get the private dbs if any
        @pureDbUris.each_key{ |dbUri|
          dbUriObj = URI.parse(dbUri)
          apiCaller = ApiCaller.new(dbUriObj.host, dbUriObj.path, @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            resp = apiCaller.parseRespBody["data"]
            pub = resp["public"]
            if(pub) # db is public
             @pureDbUris[dbUri]["dbPublic"] = pub
            else
             @privateDbs << dbUri
            end
          else
            wbJobEntity.context['wbErrorMsg'] = "API call failed get request at #{@dbApiHelper.extractName(dbUri)}. Check: #{apiCaller.respBody.inspect}"
          end
        }
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "PRIVATE DBS: #{@privateDbs.inspect}")        
        #Get the unlocked, but gbKey not public database resoures 
        @pureGrpUris.each_key{ |grpUri|
          grpUriObj = URI.parse(grpUri)
          apiCaller = ApiCaller.new(grpUriObj.host, "#{grpUriObj.path}/unlockedResources?", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            apiCaller.parseRespBody()
            apiCaller.apiDataObj.each{ |res|
            url = res["url"]
            if(@pureDbUris.key?(url))
              @pureDbUris[url]["gbKeyPublic"] = res["public"]
              @lockedDbs << url if(!res["public"]) #the resource that is unlocked but the gbKey is not public
            end
            }
          else
            wbJobEntity.context['wbErrorMsg'] = "API call failed a get request at unlockedResources. Check: #{apiCaller.respBody.inspect}"
          end
        }
        # get the locked resources
        @pureDbUris.each_key { |dburi|
          @lockedDbs << dburi if(@pureDbUris[dburi]["gbKeyPublic"].nil?) # Locked resource
        }

        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "LOCKEDDBS: #{@lockedDbs.inspect}")
        
        #get user roles for each unique grpUri
        @pureGrpUris.each_key{ |grpUri|
          grpUriObj = URI.parse(grpUri)
          apiCaller = ApiCaller.new(grpUriObj.host, "#{grpUriObj.path}/usr/#{@user}/role?connect=no", @hostAuthMap)
          apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            resp = apiCaller.parseRespBody["data"]
            @pureGrpUris[grpUri]["role"] = resp["role"]
          else
            wbJobEntity.context['wbErrorMsg'] = "API call failed to get the user roles. Check: #{apiCaller.respBody.inspect}"
          end
        }
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "ROLES: #{@pureGrpUris.inspect}")
        # Check permissions if private Dbs are to be made public
        unless(@privateDbs.empty?)
          errorMsg = ""
          @privateDbs.each{|priv|
            groupuri = @grpApiHelper.extractPureUri(priv)
            if(@pureGrpUris[groupuri]["role"] != "administrator")
              permissions = false
              errorMsg = "FORBIDDEN: You have no permission to make the database #{@dbApiHelper.extractName(priv)} public."
              break
            end
          }
        end
        # Check permissions if dbs are to be unlocked
        if(permissions and !@lockedDbs.empty?)
             @lockedDbs.each{|locked|
              groupuri = @grpApiHelper.extractPureUri(locked)
              if(@pureGrpUris[groupuri]["role"] != "administrator")
                permissions = false
                errorMsg = "FORBIDDEN: You have no permission to unlock the database #{@dbApiHelper.extractName(locked)}."
                break
              end
          }
        end

        unless(permissions)
          rulesSatisfied = false
          wbJobEntity.context['wbErrorMsg'] = errorMsg
        end

        if(permissions)
          # Now, get the track options from the user
          # Also validate the file inputs
          trkHash = Hash.new { |hh,kk| hh[kk] = {} }
          @fileHash = Hash.new { |hh, kk| hh[kk] = {} }
          @genBigFiles = Array.new() # holds trk uris for which bigbed/bigwig are to be generated
          @genIndexFiles = Array.new() # holds file uris for which the index files are to be generated
          @fileRecs = Array.new()
          @compressedTypes = Array.new()
          checkIndexSatisfied = true # For index file write access check
          wbErrorMsg = ""
          @expinputs = Array.new()
          @inputs.each { |input|
            dbUri = @dbApiHelper.extractPureUri(input)
            # For tracks
            if(@trkApiHelper.extractName(input))
              trkHash[dbUri][@trkApiHelper.extractName(input)] = true
              @expinputs << input
            # For class
            elsif(classApiHelper.extractName(input)) 
              className = classApiHelper.extractName(input)
              uriD = dbUri.dup()
              uri = URI.parse(uriD)
              rcscUri = uri.path.chomp("?")
              rcscUri << "/trks?connect=false&class=#{CGI.escape(className)}"
              apiCaller = ApiCaller.new(uri.host, rcscUri, @hostAuthMap)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              if(apiCaller.succeeded?)
                resp = apiCaller.respBody()
                retVal = JSON.parse(resp)
                tracks = retVal['data']
                tracks.each { |track|
                  trkHash[dbUri][track['text']] = true
                  trkUri = "#{dbUri.chomp("?")}/trk/#{CGI.escape(track['text'])}?"
                  @expinputs << trkUri
                }
              else
                wbJobEntity.context['wbErrorMsg'] = "API call failed while expanding inputs from the class resource. Check: #{apiCaller.respBody.inspect}"
              end
            # For entity lists
            elsif(input =~ /trks\/entityList/) 
              uri = URI.parse(input)
              rcscUri = uri.path
              apiCaller = ApiCaller.new(uri.host, rcscUri, @hostAuthMap)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              if(apiCaller.succeeded?)
                resp = apiCaller.respBody()
                retVal = JSON.parse(resp)
                tracks = retVal['data']
                tracks.each { |track|
                  trkHash[dbUri][@trkApiHelper.extractName(track['url'])] = true
                  @expinputs << track['url']
                }
               else
                wbJobEntity.context['wbErrorMsg'] = "API call failed to expand inputs from the track entity list. Check: #{apiCaller.respBody.inspect}"
              end 
            # For file entity lists
            elsif(input =~ /files\/entityList/)
              uri = URI.parse(input)
              rcscUri = uri.path
              apiCaller = ApiCaller.new(uri.host, rcscUri, @hostAuthMap)
              apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller.get()
              if(apiCaller.succeeded?)
                resp = apiCaller.respBody()
                retVal = JSON.parse(resp)
                files = retVal['data']
                files.each { |file|
                  fileurl = file['url']
                  checkIndexSatisfied, wbErrorMsg = checkFileFormat(fileurl)
                  @expinputs << fileurl
                }
              else
                wbJobEntity.context['wbErrorMsg'] = "API call failed to exapnd inputs from file entity list. Check: #{apiCaller.respBody.inspect}"
              end 
            # For files
            else
              checkIndexSatisfied, wbErrorMsg = checkFileFormat(input)
              @expinputs << input
            end
            if(!checkIndexSatisfied) #File validation not passed
              rulesSatisfied = false
              wbJobEntity.context['wbErrorMsg'] = wbErrorMsg
              break
            end
          }
          wbJobEntity.settings['trkHash'] = trkHash
          wbJobEntity.settings['fileHash'] = @fileHash
          wbJobEntity.settings['fileRecs'] = @fileRecs
          wbJobEntity.settings['compressedTypes'] = @compressedTypes
          wbJobEntity.settings['pureDbUris'] = @pureDbUris
          wbJobEntity.settings['privateDbs'] = @privateDbs
          wbJobEntity.settings['lockedDbs'] = @lockedDbs
          wbJobEntity.settings['genIndexFiles'] = @genIndexFiles
          wbJobEntity.inputs = @expinputs
        end
          
        # ------------------------------------------------------------------
        # CHECK SETTINGS
        # ------------------------------------------------------------------
        if(sectionsToSatisfy.include?(:settings))
          # Check :settings together with info from :outputs :
          unless( sectionsToSatisfy.include?(:outputs) and  sectionsToSatisfy.include?(:inputs) )
            raise ArgumentError, "Cannot validate just :settings for this tool without info provided in both :inputs and :outputs."
          end
            rulesSatisfied = true
            baseWidget = wbJobEntity.settings['baseWidget']
            if(baseWidget)# will be empty if there are no track inputs
              #$stderr.debugPuts(__FILE__, __method__, "BASEWIDGET:", "#{baseWidget}")
              wbJobEntity.settings.keys.each{ |key|
                if(key =~ /#{baseWidget}/)
                  trkuri = key.split("|")[1]
                  trktype = wbJobEntity.settings[key]
                  makeBigWigOrBed, error = makeBigWigOrBed(trkuri, trktype)
                  unless(makeBigWigOrBed)
                    rulesSatisfied = false
                    unless(error.nil?)
                      wbJobEntity.context['wbErrorMsg'] = error
                    else
                      wbJobEntity.context['wbErrorMsg'] = "FORBIDDEN: No sufficient permissions to generate #{trktype} for the track #{@trkApiHelper.extractName(trkuri)}."
                    end
                    break
                  end
                end
              }
            end
            wbJobEntity.settings['genBigFiles'] = @genBigFiles 
        end #sectionsToSatisfy.include?
      end
      $stderr.debugPuts(__FILE__, __method__, "SETTINGS:", "#{wbJobEntity.settings.inspect}")
      return rulesSatisfied
    end

    # Checks the user write access if neither bigwig or bigbed is present.  
    # [+returns+] boolean
    def makeBigWigOrBed(trkUri, trkType)
      canGenbigfiles = true
      errorMsg = nil
      uriObj = URI.parse(trkUri)
      host = uriObj.host
      grp = @grpApiHelper.extractName(trkUri)
      grpUri = @grpApiHelper.extractPureUri(trkUri) 
      apiCaller = ApiCaller.new(host, "#{uriObj.path}", @hostAuthMap)
      apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller.get()
      if(apiCaller.succeeded?)
        trk = JSON.parse(apiCaller.respBody)['data']
        if(trk[trkType] == 'none') # If the trackType chosen by the user is not present.
          # Check for group access. Job rejected if no write access to generate bigbed/bigwig
          if(@pureGrpUris[grpUri]["role"] == "administrator" or @pureGrpUris[grpUri]["role"] == "author") 
            @genBigFiles << trkUri
            canGenbigfiles = true
          else
            canGenbigfiles = false
          end
        end
      else
        errorMsg = "API call failed to get track information. Check: #{apiCaller.respBody.inspect}"
      end
      return canGenbigfiles, errorMsg
    end

    # Checks input file formats and corresponding index file formats
    # Checks whether index files are present for input files
    # If not, then checks for user permissions to generate index files
    # [+returns+] boolean
    # [+returns+] String
    def checkFileFormat(fileuri)
      fileFormatSatisfied = true
      errorMessage = nil
      uriObj = URI.parse(fileuri)
      host = uriObj.host
      grp = @grpApiHelper.extractName(fileuri)
      grpuri = @grpApiHelper.extractPureUri(fileuri)
      name = File.basename(@fileApiHelper.extractName(fileuri))
      dbName = @dbApiHelper.extractName(fileuri)
      # First get the compressionType
      apiCaller1 = ApiCaller.new(host, "#{uriObj.path}/compressionType?", @hostAuthMap)
      apiCaller1.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
      apiCaller1.get()
      if(apiCaller1.succeeded?)
        compressionType = apiCaller1.parseRespBody['data']['text']
        if(compressionType != 'text') # compressed files are forwarded to the wrapper
          fileFormatSatisfied = true
          @compressedTypes << fileuri
          @fileRecs << {  :id => '', :label => name , :type => :text, :size => '12', :value=> 'COMPRESSED', :title => "#{host} - #{grp} - #{dbName}", :disabled => true}
        else # get the sniffer Type
          apiCaller2 = ApiCaller.new(host, "#{uriObj.path}/sniffedType?", @hostAuthMap)
          apiCaller2.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
          apiCaller2.get()
          if(apiCaller2.succeeded?)
             #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Not compressed ..............")
            sniffedType = apiCaller2.parseRespBody['data']['text']
            if(sniffedType == 'bam')
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "BAM file detected...............")
              #Check for the corresponding index file - absent/present, if present sniff
              rsrcPath = "#{uriObj.path}.bai"
              @fileRecs << {  :id => '', :label => name , :type => :text, :size => '10', :value=> 'BAM', :title => "#{host} - #{grp} - #{dbName}", :disabled => true}
              @fileHash[fileuri] = sniffedType 
              apiCaller3 = ApiCaller.new(host, "#{rsrcPath}?", @hostAuthMap)
              apiCaller3.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller3.get()
              if(apiCaller3.succeeded?)#index file is present, sniff for bai
                apiCaller4 = ApiCaller.new(host, "#{rsrcPath}/sniffedType?", @hostAuthMap)
                if(apiCaller4.succeeded?)
                  sniffed = apiCaller4.parseRespBody['data']['text']
                  if(sniffed != 'bai')
                    fileFormatSatisfied = false
                    errorMessage = "INVALID_FILE_FORMAT: The index file, #{name}.bai is not a valid BAI file."
                  else
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "BAI sniffing passed...............")
                  end
                end
              end
            elsif(sniffedType == 'vcf-bgzipped')
              rsrcPath = "#{uriObj.path}.tbi"
              @fileRecs << {  :id => '', :label => name , :type => :text, :size => '10', :value=> 'VCF', :title => "#{host} - #{grp} - #{dbName}", :disabled => true}
              @fileHash[fileuri] = 'vcfTabix'
              apiCaller3 = ApiCaller.new(host, "#{rsrcPath}?", @hostAuthMap)
              apiCaller3.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
              apiCaller3.get()
              if(apiCaller3.succeeded?)#index file is present, sniff for tbi
                apiCaller4 = ApiCaller.new(host, "#{rsrcPath}/sniffedType?", @hostAuthMap)
                if(apiCaller4.succeeded?)
                  sniffed = apiCaller4.parseRespBody['data']['text']
                  if(sniffed != 'tbi')
                    fileFormatSatisfied = false
                    errorMessage = "INVALID_FILE_FORMAT: The index file, #{name}.tbi is not a valid BAI file."
                  else
                    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "TBI sniffing passed..................")
                  end
                end
              end
            else  
              fileFormatSatisfied = false
              errMessage = "INVALID_INPUT: Input file, #{name} is neither a BAM nor bgzipped VCF. Check the file format specifications to create hub and please resubmit your job." 
            end #sniffedType
            if(fileFormatSatisfied and !apiCaller3.succeeded?) #Index file is absent, check permissions to generate one.
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "No index file for #{fileuri}. ............")
              if(@pureGrpUris[grpuri]["role"] == "administrator" or @pureGrpUris[grpuri]["role"] == "author") # Check for group access. Job rejected if no write access to create index files
                @genIndexFiles << fileuri
             else
                fileFormatSatisfied = false
                errMessage = "PERMISSION DENIED. No write access to generate index files."
             end
            end
          else
            fileFormatSatisfied = false
            errMessage = "API failed to check the format type for the file, #{name}. Details: #{apiCaller2.respBody.inspect}. "
          end         
        end
      else
        fileFormatSatisfied = false
        errMessage = "API failed to check the compression type for the file, #{name}. Details: #{apiCaller1.respBody.inspect}. " 
      end 
      return fileFormatSatisfied, errMessage
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
      else # Look for warnings
        publicWarning = false
        errorMsg = ""
        # Warning 1:
        # The databases are to be unlocked and/or made public by user choice.
        if(!@privateDbs.empty? or !@lockedDbs.empty?)
          combined = @privateDbs + @lockedDbs
          errorMsg = "Following input databases will be unlocked and/or made public, for UCSC and WashU Genome Browser to access track data." 
          errorMsg << "<ul>"
          combined.uniq.each{ |uniqDb|
            errorMsg << "<li>#{@dbApiHelper.extractName(uniqDb)}</li>"
          }
          errorMsg << "</ul>"
          errorMsg << "\nAre you sure you want to proceed?"
          publicWarning = true
        end
        if(publicWarning)
          wbJobEntity.context['wbErrorMsg'] = errorMsg
          wbJobEntity.context['wbErrorMsgHasHtml'] = true
        else
          warningsExist = false
        end
      end
      # Clean up helpers, which cache many things
      @trkApiHelper.clear() if(!@trkApiHelper.nil?)
      @dbApiHelper.clear() if(!@dbApiHelper.nil?)
      @grpApiHelper.clear() if(!@grpApiHelper.nil?)
      @fileApiHelper.clear() if(!@fileApiHelper.nil?)
      return warningsExist
    end
  end
end ; end; end # module BRL ; module Genboree ; module Tools
