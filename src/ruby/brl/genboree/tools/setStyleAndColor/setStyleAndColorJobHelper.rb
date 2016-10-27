require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require "brl/genboree/tools/workbenchJobHelper"
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL ; module Genboree ; module Tools
  class SetStyleAndColorJobHelper < WorkbenchJobHelper

    TOOL_ID = 'setStyleAndColor'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    
    def runInProcess()
      success = true
      begin
        settings = @workbenchJobObj.settings
        #$stderr.puts "settings: #{settings.inspect}"
        trkHash = settings['trkHash']
        btnType = settings['btnType']
        userId = settings['userId']
        count = 0
        colorPayload = {}
        stylePayload = {}
        if(btnType == 'Save' or btnType == 'Set As Default')
          trkHash.keys.sort.each { |dbUri|
            trkHash[dbUri].keys.sort.each { |trk|
              colorPayload[trk] = settings["colorInput_#{count}"]
              stylePayload[trk] = settings["trkSettings|#{count}|Style"]
              count += 1  
            }
            dbUriObj = URI.parse(dbUri)
            rsrcPath = "#{dbUriObj.path}/trks"
            # First set color
            rsrcPath << ( btnType == 'Save' ? '/color?' : '/defaultColor?' )
            apiCaller = ApiCaller.new(dbUriObj.host, rsrcPath, @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            #$stderr.puts "colorPayload: #{colorPayload.inspect}"
            apiCaller.put( {'data' => { 'hash' => colorPayload } }.to_json )
            if(!apiCaller.succeeded?)
              raise JSON.parse(apiCaller.respBody)['status']['msg']
            end
            # Set style
            rsrcPath = "#{dbUriObj.path}/trks"
            rsrcPath << ( btnType == 'Save' ? '/style?' : '/defaultStyle?' )
            apiCaller.setRsrcPath(rsrcPath)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            apiCaller.put( {'data' => { 'hash' => stylePayload } }.to_json )
            if(!apiCaller.succeeded?)
              raise JSON.parse(apiCaller.respBody)['status']['msg']
            end
            colorPayload.clear()
            stylePayload.clear()
          }
        elsif(btnType == 'Reset to default') # Nuke all user specific settings
          trkHash.keys.sort.each { |dbUri|
            dbUriObj = URI.parse(dbUri)
            rsrcPath = "#{dbUriObj.path}/trks/color?"
            apiCaller = ApiCaller.new(dbUriObj.host, rsrcPath, @hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv) 
            apiCaller.delete()
            if(!apiCaller.succeeded?)
              raise JSON.parse(apiCaller.respBody)['status']['msg']
            end
            rsrcPath = "#{dbUriObj.path}/trks/style?"
            apiCaller.setRsrcPath(rsrcPath)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv) 
            apiCaller.delete()
            if(!apiCaller.succeeded?)
              raise JSON.parse(apiCaller.respBody)['status']['msg']
            end
          }
        end
      rescue => err
        success = false
        @workbenchJobObj.context['wbErrorMsg'] = "#{err.message}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
