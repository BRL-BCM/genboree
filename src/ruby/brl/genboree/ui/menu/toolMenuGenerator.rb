require 'stringio'
require 'json'
require 'find'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/ui/menu/menuHelper'

module BRL ; module Genboree ; module UI ; module Menu
  class ToolMenuGenerator
    # This class includes MenuHelper which manages the caching of the output string
    include BRL::Genboree::UI::Menu::MenuHelper

    # Initialize the object to set instance vars
    def initialize()
      @prefix = "wb"
      @wbtoolbarId = @@genbConf.wbToolbarId
      (@menuId, @toolbarId) = @wbtoolbarId.split("/")
      # menuRoot is the filesystem path to the menu config files
      @menuRoot = "#{@@menuConfRoot}/#{@menuId}"
      # Define a cacheKey which is used to identify and access the cached object
      # It should be constructed from configuration parts that identify the unique menu
      # cacheKeySuffix defines that the object was created from this class ToolMenuGenerator
      # as opposed to a different class that might also include MenuHelper
      @cacheKeySuffix = "HTMLToolMenu"
      # cacheKey is the string used to identify and access the cached object
      @cacheKey = "#{@menuRoot}/#{@prefix}#{@toolbarId}-#{@cacheKeySuffix}"
    end

    # This method returns the full HTML source as a string.
    #
    # [+menuObj+] +Array+: Ruby Array of Hashes containing menu configuration which will be converted to HTML
    # [+returns+] +String+: HTML
    def formatMenu(menuObj)
      # The HTML Site Map TOC
      htmlStr = "<div>"
      htmlStr << formatToolbarItems(menuObj, 1)
      htmlStr << "</div>"
      return htmlStr
    end

    # Format an array of items into HTML toolbar items
    #
    # [+items+] Array of Hashes
    # [+level+] +Integer+
    # [+returns+] +String+: HTML 
    def formatToolbarItems(items, level)
      htmlStr = "<ul class=\"wbToolMapMenu\">"
      unless(items.nil? or items.empty?)
        formattedItems = []
        items.each { |item|
          formattedItem = formatToolbarItem(item, level)
          formattedItems << formattedItem if(formattedItem and !formattedItem.empty?)
        }
        htmlStr << formattedItems.join("")
      end
      htmlStr << "</ul>"
      return htmlStr
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

    # Format a Toolbar item
    # May be a menu, submenu or a tool button
    # determine what it is and call the right formatting method
    #
    # [+item+] Hash
    # [+level+] Integer
    # [+returns+] +String+: HTML 
    def formatToolbarItem(item, level)
      htmlStr = ""
      if(!item['items'].nil?)
        # It's a menu
        htmlStr << formatToolbarDir(item, level) unless(item['hidden'])
      else
        # handle leaf nodes here
        if(!item['idStr'].nil?)
          htmlStr << formatToolbarTool(item, level) unless(item['hidden'])
        elsif(!item['menuTitle'].nil?)
          # Could be a menu Title
          htmlStr << "'<span class=\"menu-title\">#{item['menuTitle']}:</span>'"
        end
      end
      return htmlStr
    end

    # Format a toolbar Subdir Item (not leaf node)
    # item should be an menu or submenu node, a hash containing idStr, text
    #
    # This method should use a set of defined defaults for each attribute
    # but any attribute is overridable if it's defined in the item
    #
    # [+item+] Hash
    # [+level+] Integer
    # [+returns+] +String+: HTML
    def formatToolbarDir(item, level)
      # The top level has spacers
      htmlStr = "<li class=\"wbToolMapMenu\">"
      # text
      htmlStr << "#{item["text"]}:"

      if(!item['items'].empty?)
        # The menu attribute is not overridable
        htmlStr << formatToolbarItems(item["items"], level+1)
      end
      htmlStr << "</li>"

      return htmlStr
    end

    # Format Toolbar tool button (leaf node)
    # item should be an tool node, a hash containing idStr, text
    #
    # This method should use a set of defined defaults for each attribute
    # but any attribute is overridable if it's defined in the item
    #
    # [+item+] Hash
    # [+level+] Integer
    # [+returns+] +String+: HTML 
    def formatToolbarTool(item, level)
      htmlStr = "<li class=\"wbToolMapTool\">"
      
      # text
      itemText = item["text"]
      
      # id
      if(item.has_key?('id'))
        itemIdStr = item["id"]
      else
        itemIdStr = item["idStr"]
      end
      
      # tooltip 
      if(item.has_key?('tooltip'))
        if(item['tooltip'].is_a?(String))
          tooltipStr = item['tooltip'].gsub(/<br>/, " ")
        end
      else
        # Make the title from 'text' if it's not there
        tooltipStr = item['text']
      end

      htmlStr << "<a name=\"#{itemIdStr}\" href=\"\##{itemIdStr}\" onclick=\"showDialogWindow('#{itemIdStr}','#{itemText}')\">"
      htmlStr << "<span class=\"wbToolMapToolTitle\">#{itemText}</span>"
      htmlStr << "</a>"
      if(!tooltipStr.empty?)
        htmlStr << " -<span class=\"wbToolMapToolDesc\"> #{tooltipStr}</span>"
      end
      htmlStr << "</li>"

      return htmlStr
    end

  end
end ; end ; end ; end # module BRL ; module Genboree ; module UI ; module Menu
