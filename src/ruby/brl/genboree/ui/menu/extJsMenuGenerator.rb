require 'stringio'
require 'json'
require 'find'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/ui/menu/menuHelper'

module BRL ; module Genboree ; module UI ; module Menu
  class ExtJsMenuGenerator
    # This class includes MenuHelper which manages the cacheing of the output string
    include BRL::Genboree::UI::Menu::MenuHelper

    # Initialize the object to set instance vars
    #
    # [+menuId+]    +String+: Id of the menu, corresponds to directory containing menu.js file and dir-tree of menu.json config files
    # [+prefix+]    +String+: used to prefix text names in js output
    # [+readable+]  +Boolean+: Flag for setting javascript readability
    # [+configOptions+]  +Hash+: Hash of configuration options
    def initialize(menuId, prefix, readable=false, configOptions={})
      @prefix = prefix
      @readable = readable
      # menuRoot is the filesystem path to the menu config files
      @menuRoot = "#{@@menuConfRoot}/#{menuId}"
      # The default JS file (menu.js) defines pre/post ambles, and button listeners
      # JS file should have the object buttonListenerObj defined which will be used for all the button listeners
      # A different JS file can be used if specified in configOptions
      if(configOptions['menuJsWrapperFile'])
        jsWrapperFile = configOptions['menuJsWrapperFile']
      else
        jsWrapperFile = @@genbConf.menuJsWrapperFile
      end
      menuJsFile = "#{@menuRoot}/#{jsWrapperFile}"
      if(File.exist?(menuJsFile) and File.readable?(menuJsFile))
        reader = File.open(menuJsFile, "r")
        jsStr = reader.read.strip
        reader.close()
      end
      # Parse the JS file up to <%= for the preamble
      # Parse the text between <%= and %> for the toolbarId
      # Parse everything after %> for the postamble
      tagStartIndex = jsStr.index('<%=')
      tagEndIndex = jsStr.index('%>')
      @extJsPreamble = jsStr[0, tagStartIndex]
      @toolbarId = jsStr[tagStartIndex+4..tagEndIndex-2]
      @extJsPostamble = jsStr[tagEndIndex+2..-1]
      # buttonListenerObj should be defined in the menu.js file
      # and should have the camel-case menuId as Namespace
      @buttonListenerJs = "#{menuId.gsub(/^./) {|aa| aa.upcase}}.buttonListenerObj"
      # Define a cacheKey which is used to identify and access the cached object
      # It should be constructed from configuration parts that identify the unique menu
      # cacheKeySuffix defines that the object was created from this class ExtJsMenuGenerator
      # as opposed to a different class that might also include MenuHelper
      @cacheKeySuffix = "ExtJsMenu"
      # cacheKey is the string used to identify and access the cached object
      @cacheKey = "#{@menuRoot}/#{@prefix}#{@toolbarId}-#{@cacheKeySuffix}"
      # Append any optional configuration options so that different versions of the menu are cached as seperate objects
      @cacheKey += "-readable" if(@readable)
    end


    # This method returns the full ExtJs Javascript source as a string.
    #
    # [+menuObj+] +Array+: Ruby Array of Hashes containing menu configuration which will be converted to Javascript
    # [+returns+] +String+: Javascript
    def formatMenu(menuObj)
      # ExtJs Preamble
      jsStr = @extJsPreamble
      # The ExtJs Toolbar
      jsStr << "new Ext.Toolbar("
      jsStr << "{"
      jsStr << "  id: '#{@prefix}#{@toolbarId}',"
      jsStr << "  enableOverflow: true,"
      jsStr << "  monitorResize: true,"
      jsStr << "  renderTo: '#{@prefix}#{@toolbarId}Div',"
      jsStr << "  items: ["
      jsStr << formatExtJsToolbarItems(menuObj, 1)
      jsStr << "  ]"
      jsStr << "}) ;"
      # ExtJs Postamble
      jsStr << @extJsPostamble
      # If the readable flag is set, do formatting here
      if(@readable)
        # Write to temp file, and call beautifier utility
        rr = String.generateUniqueString()
        jsFilename = "/tmp/#{rr}_tmpExtJsMenubar.js"
        File.open(jsFilename, 'w') {|ff| ff.write(jsStr) }
        beautifyCmd = "#{@@genbConf.jsbeautifyCmd} #{jsFilename}"
        jsStr = `#{beautifyCmd}`
        File.delete(jsFilename)
      end
      return jsStr
    end

    # Format an array of items into ExtJs toolbar items
    #
    # [+items+] Array of Hashes
    # [+level+] +Integer+
    # [+returns+] +String+: Javascript
    def formatExtJsToolbarItems(items, level)
      jsStr = ''
      unless(items.nil? or items.empty?)
        formattedItems = []
        items.each { |item|
          formattedItem = formatExtJsToolbarItem(item, level)
          formattedItems << formattedItem if(formattedItem and !formattedItem.empty?)
        }
        jsStr = formattedItems.join(', ')
      end
      return jsStr
    end

    # Retrieve a comma seperated list of tool Ids contained in all submenus
    #
    # [+item+] +Hash+: Menu node
    # [+returns+] +String+: comma seperated list of tool ids
    def listToolIds(item)
       getToolIds(item).map!{|ii| "'#{ii}'"}.join(', ')
    end

    # Retrieve array of tool Ids contained in all submenus
    #
    # [+item+] +Hash+: Menu node
    # [+returns+] +Array+: Array of tool ids
    def getToolIds(item)
      idArr = []
      if(item['items'].nil?)
        idArr << item['idStr']
      else
        item['items'].each { |subitem|
          subArr = getToolIds(subitem)
          idArr << subArr if(!subArr.empty?)
        }
      end
      return idArr.flatten
    end

    # Format an ExtJs Toolbar item
    # May be a menu, submenu or a tool button
    # determine what it is and call the right formatting method
    #
    # [+item+] Hash
    # [+level+] Integer
    # [+returns+] +String+: Javascript
    def formatExtJsToolbarItem(item, level)
      jsStr = ""
      if(!item['items'].nil?)
        # It's a menu
        jsStr = formatExtJsToolbarDir(item, level) unless(item['hidden'])
      else
        # handle leaf nodes here
        if(!item['idStr'].nil?)
          jsStr = formatExtJsToolbarTool(item, level) unless(item['hidden'])
        elsif(!item['menuTitle'].nil?)
          # Could be a menu Title
          jsStr = "'<span class=\"menu-title\">#{item['menuTitle']}:</span>'"
        elsif(!item['hSpacer'].nil?)
          # Horizontal Spacer
          jsStr = "'-'"
        end
      end
      return jsStr
    end

    # Format an ExtJs toolbar Subdir Item (not leaf node)
    # item should be an menu or submenu node, a hash containing idStr, text
    #
    # This method should use a set of defined defaults for each attribute
    # but any attribute is overridable if it's defined in the item
    #
    # [+item+] Hash
    # [+level+] Integer
    # [+returns+] +String+: Javascript
    def formatExtJsToolbarDir(item, level)
      # The top level has spacers
      jsStr = (level == 1) ? "  new Ext.Toolbar.Spacer(),new Ext.Toolbar.Spacer()," : ""
      # Array of attributes value pairs that will be joined to form javascript
      jsAttrArr = []
      # Configuration attributes
      confItemAttr = ['tooltip']
      # Required attributes contained in the item hash
      reqItemAttr = ['idStr', 'text', 'items']
      # Required attributes - All Tool buttons have these and they can be generated
      # programmatically with default values or they can be overridden with values from menu.json
      reqJsAttr = ['id', 'text', 'ctCls', 'iconCls']
      # text
      jsAttrArr << "text: '#{item["text"]}'"
      # id
      itemId = '' # Save this because we'll need it later
      if(item.has_key?('id'))
        itemId = item["id"]
      else
        itemId = "#{@prefix}#{item["idStr"]}ToolbarBtn"
      end
      jsAttrArr << "id: '#{itemId}'"
      # ctCls
      if(item.has_key?('ctCls'))
        jsAttrArr << "ctCls: '#{item["ctCls"]}'"
      else
        jsAttrArr << "ctCls: '#{@prefix}ToolbarBtn'"
      end
      # iconCls
      if(item.has_key?('iconCls'))
        jsAttrArr << "iconCls: '#{item["iconCls"]}'"
      else
        jsAttrArr << "iconCls: '#{@prefix}#{item["idStr"].gsub(/%../, '').gsub(/^./) {|aa| aa.upcase }}Menu'"
      end

      # tooltip - should have a title and html
      if(item.has_key?('tooltip'))
        if(item['tooltip'].is_a?(String))
          # Convert it to the standard hash with title and html
          tooltipStr = item['tooltip']
          item['tooltip'] = {}
          item['tooltip']['html'] = "<br>#{tooltipStr}"
          item['tooltip']['title'] = item['text']
        end
        # Make the title from 'text' if it's not there
        item['tooltip']['title'] = item['text'] if(!item['tooltip'].has_key?('title'))
        jsAttrArr << "tooltip: { title: #{item['tooltip']['title'].to_json}, html: #{item['tooltip']['html'].to_json} }"
      end

      # toolIds
      jsAttrArr << "toolIds: [ #{listToolIds(item)} ]"
      # Optional attributes are blindly added to the item from menu.json
      # Common optional attributes include 'disabled', 'tooltip', 'iconCls'
      item.each_key { |attr|
        # Ignore the required attributes because we just did them
        if(!reqJsAttr.include?(attr) and !reqItemAttr.include?(attr) and !confItemAttr.include?(attr))
          # If value is a string, wrap in single quotes and escape single quotes
          jsAttrArr << "#{attr}: '#{item[attr]}'"
        end
      }
      if(!item['items'].empty?)
        # The menu attribute is not overridable
        menuAttrStr =  "menu: {"
        menuAttrStr << "  id: '#{item["idStr"]}Menu',"
        menuAttrStr << "  ownerToolbarBtnId: '#{itemId}',"
        menuAttrStr << "  ignoreParentClicks: true,"
        menuAttrStr << "  items: ["
        menuAttrStr << formatExtJsToolbarItems(item["items"], level+1)
        menuAttrStr << "  ]"
        menuAttrStr << "}"
        jsAttrArr << menuAttrStr
      else
        # If the items array is empty (subdir is missing), hide the submenu
        # This is used on live to deactivate pre-release menus
        jsAttrArr << "hidden: true"
      end

      # Join the attributes into a comma seperated string
      jsStr << "{ #{jsAttrArr.join(', ')} }"
      return jsStr
    end

    # Format an ExtJS Toolbar tool button (leaf node)
    # item should be an tool node, a hash containing idStr, text
    #
    # This method should use a set of defined defaults for each attribute
    # but any attribute is overridable if it's defined in the item
    #
    # [+item+] Hash
    # [+level+] Integer
    # [+returns+] +String+: Javascript
    def formatExtJsToolbarTool(item, level)
      # Array of attributes value pairs that will be joined to form javascript
      jsAttrArr = []
      # Configuration attributes
      confItemAttr = ['itemType']
      # Required attributes contained in the item hash
      reqItemAttr = ['idStr', 'text']
      # Required attributes - All Tool buttons have these and they can be generated
      # programmatically with default values or they can be overridden with values from menu.json
      reqJsAttr = ['id', 'text', 'ctCls', 'listeners', 'tooltip', 'iconCls']
      # text
      jsAttrArr << "text: '#{item["text"]}'"
      # id
      if(item.has_key?('id'))
        jsAttrArr << "id: '#{item["id"]}'"
      else
        jsAttrArr << "id: '#{item["idStr"]}'"
      end
      # ctCls
      if(item.has_key?('ctCls'))
        jsAttrArr << "ctCls: '#{item["ctCls"]}'"
      else
        jsAttrArr << "ctCls: '#{@prefix}ToolbarBtn'"
      end
      # iconCls
      if(item.has_key?('iconCls'))
        jsAttrArr << "iconCls: '#{item["iconCls"]}'"
      else
        jsAttrArr << "iconCls: '#{@prefix}#{item["idStr"].gsub(/%../, '').gsub(/^./) {|aa| aa.upcase }}MenuItem'"
      end
      #listeners
      if(item["itemType"] == "CheckItem")
        jsAttrArr << "handler: checkHandler"
      else # button
        if(item.has_key?('listeners'))
          jsAttrArr << "listeners: #{item["listeners"]}"
        else
          jsAttrArr << "listeners: #{@buttonListenerJs}"
        end
      end
      # tooltip - should have a title and html
      if(item.has_key?('tooltip'))
        if(item['tooltip'].is_a?(String))
          # Convert it to the standard hash with title and html
          tooltipStr = item['tooltip']
          item['tooltip'] = {}
          item['tooltip']['html'] = "<br>#{tooltipStr}"
          item['tooltip']['title'] = item['text']
        end
        # Make the title from 'text' if it's not there
        item['tooltip']['title'] = item['text'] if(!item['tooltip'].has_key?('title'))
        jsAttrArr << "tooltip: { title: #{item['tooltip']['title'].to_json}, html: #{item['tooltip']['html'].to_json} }"
      else
        jsAttrArr << "tooltip: { title: #{item['text'].to_json} }"
      end

      # Optional attributes are blindly added to the item from menu.json
      # Common optional attributes include 'disabled', 'iconCls'
      item.each_key { |attr|
        # Ignore the required attributes because we just did them
        # Also ignore the configuration attributes that aren't actual attributes understood by extjs
        if(!reqJsAttr.include?(attr) and !reqItemAttr.include?(attr) and !confItemAttr.include?(attr))
          # If value is a string, wrap in single quotes and escape single quotes
          jsAttrArr << "#{attr}: #{item[attr].to_json}"
        end
      }

      # If handler is defined in the json object, use it otherwise use default
      if(item["itemType"] == "DateItem")
        handlerStr = (item.has_key?('handler')) ? item["handler"] : 'datePickerHandler'
        jsAttrArr << "menu: new Ext.menu.DateMenu({ handler : #{handlerStr} }) "
      end
      if(item["itemType"] == "ColorItem")
        handlerStr = (item.has_key?('handler')) ? item["handler"] : 'colorPickerHandler'
        jsAttrArr << "menu: new Ext.menu.ColorMenu({ handler: #{handlerStr} }) "
      end

      jsStr = "{ #{jsAttrArr.join(', ')} }"

      # Wrap the special itemTypes in the proper ExtJs constructor
      if(item["itemType"] == "CheckItem")
        jsStr = "new Ext.menu.CheckItem(" << jsStr << ")"
      end

      return jsStr
    end

  end
end ; end ; end ; end # module BRL ; module Genboree ; module UI ; module Menu
