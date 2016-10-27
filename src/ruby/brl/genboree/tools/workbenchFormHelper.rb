require 'uri'
require 'cgi'
require 'json'
require 'erubis'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/entityList'
require 'brl/genboree/rest/wrapperApiCaller'

module BRL ; module Genboree ; module Tools
  class WorkbenchFormHelper

    def self.addToFormContext(contextHash)
      return WorkbenchFormHelper.addToFormSection('wbFormContext', contextHash)
    end

    def self.addToFormSettings(contextHash)
      return WorkbenchFormHelper.addToFormSection('wbFormSettings', contextHash)
    end

    def self.addToFormSection(formVar, hashToAdd)
      buff = ''
      hashToAdd.each_key { |key|
        valueAsJson = hashToAdd[key].to_json
        buff << "#{formVar}.set('#{key}', #{valueAsJson}) ;\n"
      }
      return buff
    end

    def self.overflowMsgFromContext(contextHash)
      wbMsg = ''
      if(contextHash['wbErrorMsg'].nil? or contextHash['wbErrorMsg'].empty?)
        wbMsg = contextHash['wbAcceptMsg']
      else
        wbMsg = contextHash['wbErrorMsg']
      end

      wbMsg = [ wbMsg ] if(wbMsg.is_a?(String))

      wbMsgHasHtml = contextHash['wbErrorMsgHasHtml'] || contextHash['wbMsgHasHtml']
      wbMsgPrefHeight = contextHash['wbErrorMsgPrefHeight'] || contextHash['wbMsgPrefHeight']
      heightCss = ''
      if(!wbMsgPrefHeight)
        wbMsg.each { |msgLine|
          errorSize = msgLine.size
          if((wbMsgHasHtml and (msgLine.scan(/<li[^>]*>|<br[^>]*>|<p[^>]*>/).size > 5 or errorSize > 300)) or (!wbMsgHasHtml and errorSize > 600))
            heightCss = 'height: 110px; overflow-y: auto;' # ExtJs won't display if >125px.
          end
        }
      else
        heightCss = "height: #{wbMsgPrefHeight}; overflow: auto; "
      end
      buff = "<ul style='#{heightCss}'>"

      wbMsg.each { |warning|
        warning = CGI.escapeHTML(warning) unless(wbMsgHasHtml)
        buff << "<li>#{warning}</li>"
      }
      buff << "</ul>"
      return buff
    end

    def self.toggleTrackNameDisplayFunction()
      return "
        function toggleTrackNameDisplay(isChecked)
        {
          var trackType = Ext.get('lffType').dom ;
          var trackSubType = Ext.get('lffSubType').dom ;
          if(isChecked)
          {
            trackType.enable() ;
            trackSubType.enable() ;
          }
          else
          {
            trackType.disable() ;
            trackSubType.disable() ;
          }
        }
      "
    end

    # [+includeMultipleDirs+]  bool: if true, the name will include everything up to the end of uri, as opposed to the next '/'
    def self.getHostFromURI(uri, escapeHTML=false)
      if(uri.nil?)
        host = nil
      else
        uriObj = URI.parse(uri) rescue nil
        if(uriObj)
          host = uriObj.host
          host = CGI.escapeHTML(host) if(escapeHTML)
        end
      end
      return host
    end

    # [+includeMultipleDirs+]  bool: if true, the name will include everything up to the end of uri, as opposed to the next '/'
    def self.getNameFromURI(rsrcType, uri, escapeHTML=false, includeMultipleDirs=false)
      if(uri.nil?)
        name = nil
      else
        if(includeMultipleDirs)
          nameRe = /\/#{rsrcType}\/([^ \t\n\?]+)/
        else
          nameRe = /\/#{rsrcType}\/([^\/ \t\n\?]+)/
        end
        uri =~ nameRe
        unless($1.nil?)
          name = CGI.unescape($1) if($1)
          name = CGI.escapeHTML(name) if(escapeHTML)
        end
      end
      return name
    end

    def self.simplifyURI(uriStr)
      suri = uriStr.gsub(%r{/REST/v\d+/}, "")
      return suri.gsub(%r{\?.*}, "")
    end

    def self.parseQuery(uri)
      uri = URI.parse(uri.to_s) unless(uri.is_a?(URI))
      return CGI.parse(uri.query)
    end

    def self.renderButton(button)
      buff = ''
      onClick = ""
      buttonType = button[:type]
      inputType = (buttonType == :submit ? 'submit' : 'button')
      value = (button[:value] || buttonType.to_s.capitalize)
      postambleHTML = button[:postambleHTML]
      # Add other attributes, whatever they are
      button.each_key { |attribute|
        next if([:value, :postambleHTML, :onClick, :type].include?(attribute))
#        next if(attribute == :value or attribute == :postambleHTML or attribute == :onClick)
        buff << "#{attribute}=\"#{button[attribute]}\""
      }

      # Set the onClick based on button type and val
      if(buttonType == :cancel)
        onClick = "onClick=\"closeToolWindows() ;\""
      elsif(button[:onClick].nil?)
        onClick = ''
      else
        onClick = "onClick = \"#{button[:onClick]}\""
      end
      retVal = %Q^ <input type="#{inputType}" value="#{ value }" class="wbButton" #{ buff } #{onClick} >\n#{postambleHTML} ^
      return retVal
    end

    # Default rendering of a dialog feedback message (such as context['wbErrorMsg'] but not only).
    # Will wrap the msgType in the appropriate div and span for display
    # in a colored box with appropriate icon. msgHtml can just be simple text or
    # something more involved.
    def self.renderWbMsg(msgType, msgHtml)
      buff = "<div class=\"wbDialogFeedback #{msgType}\">\n"
      buff << "  <span class=\"wbErrorMsg\">#{msgHtml}</span>\n"
      buff << "</div>\n<br>"
      return buff
    end

    # Default rendering for tool dialog info, such as the tool overview text at the
    # top of a help or tool setting dialog. Wraps infoHtml in appropriate <div> for
    # presentation. infoHtml can be simple text or something more involved.
    def self.renderWbToolInfo(infoHtml)
      return "<div class='wbToolDialogInfo'>#{infoHtml}\n<br>&nbsp;<br></div>"
    end

    def self.buildEntitiesListMap(uris, entityType, userId, rackEnv)
      retVal = Hash.new { |hh, kk| hh[kk] = [] }
      entityListRegExp = %r{^/REST/v1/grp/[^/\?]+/db/[^/\?]+/#{Abstraction::EntityList::ENTITY_TYPE_TO_ENTITYLIST_TYPE[entityType]}/entityList/[^/\?]+}
      entityRegExp = %r{^/REST/v1/grp/[^/\?]+/db/[^/\?]+/#{entityType}/[^/\?]+}
      uris.each { |uri|
        uriObj = URI.parse(uri)
        if(uriObj.path =~ entityRegExp) # Matches the entity type we want. Not a list.
          retVal[:none] << uri
        elsif(uriObj.path =~ entityListRegExp)
          # We need a genboree config object
          genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])
          # Get contents of list
          apiCaller = WrapperApiCaller.new(uriObj.host, uriObj.path, userId)
          apiCaller.initInternalRequest(rackEnv, genbConf.machineNameAlias) if(rackEnv)
          apiCaller.get()
          if(apiCaller.succeeded?)
            resp = JSON.parse(apiCaller.respBody)['data']
            resp.each { |entity|
              entityName = grp = db = nil
              entityUrl = entity['url']
              retVal[uri] << entityUrl
            }
          else
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "API Call to get entity list failed.\n  - Http Resp: #{apiCaller.httpResponse.inspect}\n  - API URI path: #{uriObj.is_a?(URI) ? uriObj.path : "n/a"}")
          end
        end
      }
      return retVal
    end

    def self.renderInlineScriptFrag(srcPaths)
      if(!srcPaths.is_a?(Array))
        srcPaths = [srcPaths]
      end
      # To avoid asynchronous loading of external scripts by Ext, we need to provide all our query js as inline here
      buff = "<script>\n"
      srcPaths.each { |srcPath|
        if(File.exists?(srcPath))
          File.open(srcPath) { |file|
            file.each_line { |line|
              buff << line
            }
          }
        else
          buff << "Ext.Msg.show({title: 'Error', msg: 'Error in page.  Unable to load file #{srcPath}', icon: Ext.MessageBox.ERROR, buttons: Ext.Msg.OK });\n"
        end
      }
      buff << "</script>\n"
      return buff
    end
  end
end ; end end # module BRL ; module Genboree ; module Tools
