#!/usr/bin/env ruby

require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/dataStructure/cache' # for BRL::DataStructure::LimitedCache

module BRL ; module Genboree ; module UI ; module Menu
  module MenuHelper
    # ------------------------------------------------------------------
    # MODULE/CLASS METHODS
    # ------------------------------------------------------------------
    @@genbConf = nil
    def self.genbConf()
      return @@genbConf
    end

    @@menuConfRoot = nil
    def self.menuConfRoot()
      return @@menuConfRoot
    end

    def self.menuCache()
      return @@menuCache
    end

    def MenuHelper.included(includer)
      MenuHelper.init()
    end

    def MenuHelper.extended(extender)
      MenuHelper.init()
    end

    def MenuHelper.init()
      # First, take this opportunity to update GenboreeConfig if it has been modified.
      if(@@genbConf.is_a?(BRL::Genboree::GenboreeConfig))
        refresh = @@genbConf.reload()
      else
        @@genbConf = BRL::Genboree::GenboreeConfig.load()
        refresh = true
      end
      # Second, update certain key values from config file (so we don't have to
      # get them through method_missing/Hash#[] calls all them time).
      if(refresh or @@menuConfRoot.nil?)
        @@menuConfRoot = @@genbConf.menuConfBaseDir
        @@menuJsonFile = @@genbConf.menuConfFile
        # Track maximum size of caches (in objects, not MB)
        @@maxCachedMenus = @@genbConf.maxCachedMenus.to_i
        # Make sure cache are initialized
        @@menuCache ||= BRL::DataStructure::LimitedCache.new(@@maxCachedMenus)
      end
    end

    # ------------------------------------------------------------------
    # INSTANCE METHODS (if mixed in via include() or extend())
    # ------------------------------------------------------------------

    # This method returns the full menu as a String.
    # It determines if the menu should be generated from the files or can be retrieved from cache.
    # If the menu is generated from files, the String will be stored in memory cache
    #
    # [+returns+] +String+: Javascript representation of the menu
    def renderMenu()
      maxMtime = findMaxMtime(@menuRoot)
      cacheMtime = @@menuCache.getInsertTime(@cacheKey)
      # Now can decide if need to regen or not
      if(cacheMtime.nil? or maxMtime > cacheMtime) # need to regen, something has changed
        menuObj = generateMenuObj("#{@menuRoot}/#{@toolbarId}")
        menuStr = formatMenu(menuObj)
        # Cache the menu in memory
        @@menuCache.cacheObject(@cacheKey, menuStr, maxMtime)
      else # nothing changed, use in-mem cache version
        menuStr = @@menuCache.getObject(@cacheKey)
      end
      return menuStr
    end

    # A very generic method that finds the most recent touched time
    # of a dir or file in a dir tree
    #
    # [+menuRoot+] +String+: Root of the dir tree that we're interested in
    # [+returns+] +Time+: the most recent mtime time
    def findMaxMtime(menuRoot)
      maxMtime = File.mtime(menuRoot)
      Find.find(menuRoot) { |path| # find dirs and files
        pathMtime = File.mtime(path)
        maxMtime = pathMtime if(pathMtime > maxMtime)
      }
      return maxMtime
    end

    # This method recursively generates the generic menu structure from
    # A directory tree of config files
    #
    # [+menuId+] +String+: Root of the dir tree that we're interested in
    # [+prefix+] +String+:
    # [+returns+] +Array+: A generic ruby object of the Menu tree
    def generateMenuObj(menuRoot, prefix='')
      menuData = nil
      jsonStr = ''
      confFile = "#{menuRoot}/#{@@menuJsonFile}"
      menuData = [] # Array of object that will be returned
      begin
        # The directory doesn't have to have a config file if it only contains submenus
        # Get the subdirs in menuRoot
        if(File.exist?(menuRoot) and File.readable?(menuRoot))
          # REMOVE: Dir.chdir(menuRoot)
          # Get the subdirs as an array of hashes like those in menu.conf
          subDirArr = Dir.glob("#{menuRoot}/*/").map { |dd| File.basename(dd) }.sort
          # Open the menu.json file
          if(File.exist?(confFile) and File.readable?(confFile))
            # load the json
            jsonStr = File.read(confFile)
            menuData = JSON.parse(jsonStr)
            # Loop through the items, adding submenus if they are defined
            menuData.each { |menuItem|
              # only do this if text is set
              if(!menuItem['text'].nil? and !menuItem['text'].empty?)
                escMenuText = CGI.escape(menuItem['text'])
                # Menus are commonly definined with just 'text'
                # idStr will be derived from text if it isn't defined
                if(menuItem['idStr'].nil?)
                  menuItem['idStr'] = escMenuText
                  # Initialize 'items' because this is a menu item
                  # unless there's an href attribute, and no idStr it's a link button not a dir
                  menuItem['items'] = [] if(menuItem['href'].nil?)
                end
                # Drop the item from the subDirArr because that gets processed later and we're doing the item now.
                subDirArr.delete(escMenuText)
                subMenuRoot = "#{menuRoot}/#{escMenuText}"
                subMenuData = generateMenuObj(subMenuRoot)
                menuItem['items'] = subMenuData if(!subMenuData.empty?)
              end
            }
          end
          # Now process what's left in subDirArr (submenus with no special configuration)
          if(!subDirArr.empty?)
            subDirArr.each { |menuItem|
              itemData = {
                'idStr' => menuItem,
                'text' => CGI.unescape(menuItem)
              }
              subMenuRoot = "#{menuRoot}/#{menuItem}"
              subMenuData = generateMenuObj(subMenuRoot)
              itemData['items'] = subMenuData if(!subMenuData.nil?)
              # Add the item to menuData
              menuData.push(itemData)
            }
          end
        end
      rescue => err
        puts "Exception: processing dir #{menuRoot}: #{err}"
        puts err.backtrace
      end
      return menuData
    end

  end
end ; end ; end ; end # module BRL ; module Genboree ; module UI ; module Menu
