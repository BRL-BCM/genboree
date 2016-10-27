require 'stringio'
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'pp'

module BRL ; module Genboree ; module UI ; module Menu
  class MenuGenerator
    SubMenuObj = Struct.new(:obj, :toolIds)

    attr_accessor :idPrefix, :btnIdSuffix, :menuIdSuffix, :iconClsSuffix, :ctCls
    attr_accessor :toolIdsById

    def initialize(options={})
      @idPrefix = (options[:idPrefix] || 'gb')
      @btnIdSuffix = (options[:btnIdSuffix]) || 'MenubarBtn'
      @menuIdSuffix = (options[:menuIdSuffix] || 'Menu')
      @iconClsSuffix = (options[:iconClsSuffix] || @menuIdSuffix)
      @ctCls = (options[:ctCls] || "#{@idPrefix}#{@btnIdSuffix}")
    end

    def generate(jsonStr, indentLevel=0)
      conf = JSON.parse(jsonStr)
      menuObj = {}
      # Create top level menubar button
      text = conf['text']
      cleanText = text.gsub(/[^A-Za-z0-9_\-]/, '')
      menuObj['text']     = text
      menuObj['id']       = (conf['id']       || "#{@idPrefix}#{cleanText}#{@btnIdSuffix}")
      menuObj['iconCls']  = (conf['iconCls']  || "#{@idPrefix}#{cleanText}#{@iconClsSuffix}")
      menuObj['ctCls']    = (conf['ctCls']    || @ctCls)
      menuObj['toolIds']  = []
      subMenuObj = menuObj['menu']     = generateSubMenu(conf['menu'], menuObj['id'], text)
      # add ids of each menu obj in ['items']
      if(subMenuObj.key?('items'))
        subMenuObj['items'].each { |item|
          if(item.key?('toolIds'))
            menuObj['toolIds'] += item['toolIds']
          else # item must be a leaf, just add its id
            menuObj['toolIds'] << item['id'] if(item.key?('id'))
          end
        }
      end
      return menuObj
    end

    # Recursive. Creates the cascading menus.
    def generateSubMenu(conf, ownerId=nil, parentText=nil)
      menuObj = {}
      if(conf)
        # Attributes for the menu in general:
        menuObj['ownerToolbarBtnId'] = ownerId if(ownerId)
        menuObj['ignoreParentClicks'] = true
        if(parentText)
          text = parentText
          cleanText = (text.nil? ? nil : text.gsub(/[^A-Za-z0-9_\-]/, ''))
          menuObj['id'] = "#{@idPrefix}#{cleanText}#{@menuIdSuffix}"
        end
        # Each item in the menu:
        menuObj['items'] = []
        conf.each { |subMenuConf|
          subMenuObj = {}
          subMenuText = subMenuConf['text']
          cleanSubMenuText = subMenuText.gsub(/[^A-Za-z0-9_\-]/, '')
          #$stderr.puts " building iconCls: #{@idPrefix.inspect}\t#{cleanSubMenuText.inspect}\t#{@iconClsSuffix.inspect}"
          subMenuObj['id']        = (subMenuConf['id']        || "#{@idPrefix}#{cleanSubMenuText}#{@menuIdSuffix}")
          subMenuObj['text']      = subMenuText
          subMenuObj['iconCls']   = (subMenuConf['iconCls']   || "#{@idPrefix}#{cleanSubMenuText}#{@iconClsSuffix}")
          subMenuObj['ctCls']     = (subMenuConf['ctCls']     || @ctCls)
          subMenuObj['icon']      = subMenuConf['icon'] if(subMenuConf.key?('icon'))
          subMenuObj['disabled']  = subMenuConf['disabled'] if(subMenuConf.key?('disabled'))
          subMenuObj['needsListeners'] = '%%NEEDS_STANDARD_LISTENERS%%' if(subMenuConf['needsListeners'])
          if(subMenuConf.key?('tooltip'))
            tooltip = {}
            tooltipConf = subMenuConf['tooltip']
            tooltip['title']        = (tooltipConf['title']         || "")
            tooltip['html']         = (tooltipConf['html']          || "")
            tooltip['showDelay']    = (tooltipConf['showDelay']     || 1500)
            tooltip['dismissDelay'] = (tooltipConf['dismissDelay']  || 10000)
            # Other possible tooltip goodies:
            # // trackMouse: false,
            # // autoHide: false,
            # // tools: [ {id: 'close', handler: function(evt, toolbar, panel, cfg) { panel.hide() ; } }]
            subMenuObj['tooltip'] = tooltip
          end
          # Recursive step:
          if(subMenuConf.key?('menu'))
            subMenuObj['toolIds'] = []
            subSubMenuObj = subMenuObj['menu'] = generateSubMenu(subMenuConf['menu'])
            # add ids of each menu obj in ''items']
            if(subSubMenuObj.key?('items'))
              subSubMenuObj['items'].each { |item|
                if(item.key?('toolIds'))
                  subMenuObj += item['toolIds']
                else # item must be a leaf, just add its id
                  # add this item id to subMenuObj's toolIds
                  subMenuObj['toolIds'] << item['id'] if(item.key?('id'))
                end
              }
            end
          end
          menuObj['items'] << subMenuObj
        }
      end
      return menuObj
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module UI ; module Menu
