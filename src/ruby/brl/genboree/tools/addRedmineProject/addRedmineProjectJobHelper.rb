require 'brl/sites/redmine'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/tools/workbenchJobHelper'

module BRL; module Genboree; module Tools
  class AddRedmineProjectJobHelper < WorkbenchJobHelper
    TOOL_ID = "addRedmineProject"

    # @interface
    def runInProcess
      success = false
      begin
        # Get selected redmine configuration info
        configFile = @genbConf.gbRedmineConfs
        configRedmines = nil
        if(configFile.nil?)
          raise "Missing configuration file for Redmine projects: add gbRedmineConfs to the Genboree configuration file"
        else
          if(File.exists?(configFile))
            configRedmines = JSON.parse(File.read(configFile)) rescue nil
            if(configRedmines.nil?)
               raise "The configuration file for Redmine projects at #{configFile.inspect} is not parsable as JSON"
            end
          else
            raise "The Genboree-configured location for Redmine project configurations #{configFile.inspect} does not exist"
          end
        end
  
        # Get redmine URL from selected redmine conf
        redmineUrl = nil
        redmineConf = nil
        redmineLabelSetting = "redmineLabel"
        selectedRedmine = @workbenchJobObj.settings[redmineLabelSetting]
        if(selectedRedmine.nil?)
          # @todo move to rules helper?
          raise "Missing setting #{redmineLabelSetting.inspect} from job configuration"
        end
        if(configRedmines.key?(selectedRedmine))
          redmineConf = configRedmines[selectedRedmine]
        else
          raise "The selected Redmine instance labelled #{selectedRedmine.inspect} has not been configured for this Genboree instance"
        end
        redmineHost = redmineConf["host"]
        redminePath = redmineConf["path"]
        raise "The configuration file has an error for the Redmine instance labelled #{selectedRedmine.inspect}" if(redmineHost.nil? or redminePath.nil?)
        redmineUrl = "http://#{redmineHost}#{redminePath}"
  
        # Verify that this Redmine project has the Genboree rawcontent plugin enabled
        redmineObj = BRL::Sites::Redmine.new(redmineUrl)
        hasRawContent = redmineObj.rawContentOk?(@workbenchJobObj.settings['redminePrj'])
        unless(hasRawContent)
          msg = "The Redmine project #{@workbenchJobObj.settings["redminePrj"].inspect} does not have the Genboree rawcontent plugin enabled and thus cannot be used in the Genboree Workbench."
          raise WorkbenchJobError.new(msg, :"Bad Request")
        end
  
        # Make request to register this Redmine project with the group, request may error if 
        #   Redmine project has already been registered to another group
        gbGroupUrl = @workbenchJobObj.outputs[0]
        uriObj = URI.parse(gbGroupUrl)
        redminePrj = @workbenchJobObj.settings['redminePrj']
        gbRedminePrjPath = "#{uriObj.path}/redminePrj/#{CGI.escape(redminePrj)}"
        apiCaller = BRL::Genboree::REST::WrapperApiCaller.new(uriObj.host, gbRedminePrjPath, @userId)
        redminePrjObj = {
          "url" => redmineUrl,
          "projectId" => redminePrj
        }
        resp = apiCaller.put(JSON(redminePrjObj))
        if(apiCaller.succeeded?)
          success = true
        else
          # @todo can we make HTTP_STATUS_NAMES available like in REST resources?
          @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
          @workbenchJobObj.context['wbErrorMsg'] = resp.body
        end
      rescue WorkbenchJobError => err
        success = false
        @workbenchJobObj.context['wbErrorName'] = err.code
        @workbenchJobObj.context['wbErrorMsg'] = err.message
      end
      return success
    end
  end
end; end; end
