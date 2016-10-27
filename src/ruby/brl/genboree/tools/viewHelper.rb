#!/usr/bin/env ruby

require 'brl/util/util'
require 'erubis'
require 'erubis/preprocessing'
require 'brl/genboree/genboreeUtil'
require 'brl/dataStructure/cache' # for BRL::DataStructure::LimitedCache
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/tools/toolConf'

include BRL::Genboree::REST

# Make sure _decode(), _p(), _P(), _?() etc are all available in the Erubis::Context
module Erubis
  class Context
    include Erubis::PreprocessingHelper
  end
end

# For static content (fragments whose HTML is generated just the first time and
# then used from cache from then on)
class StaticContent
  attr_accessor :rhtml, :content, :digest

  def initialize(rhtml, content, digest)
    @rhtml, @content, @digest = rhtml, content, digest
  end
end

module BRL ; module Genboree ; module Tools
  module ViewHelper
    # Added to the begining of all view rhtml:
    RHTML_PREAMBLE = <<-EOS
      require 'brl/util/util'
      # Automatically make form helper methods available:
      require 'brl/genboree/tools/workbenchFormHelper'
      WorkbenchFormHelper = BRL::Genboree::Tools::WorkbenchFormHelper
      # Automatically make view helper methods available (*this* module's methods!):
      require 'brl/genboree/tools/viewHelper'
      self.extend(BRL::Genboree::Tools::ViewHelper)

      # Default Erubis preamble:
      _buf = '' ;
    EOS

    # Add to the end of all view rhtml:
    RHTML_POSTAMBLE = <<-EOS

      # Default Erubis postamble
      _buf.to_s ;
    EOS

    # ------------------------------------------------------------------
    # MODULE/CLASS METHODS
    # ------------------------------------------------------------------
    #cattr_reader :genbConf
    @@genbConf = nil
    def self.genbConf()
      return @@genbConf
    end

    #cattr_reader :toolViewRoot
    @@toolViewRoot = nil
    def self.toolViewRoot()
      return @@toolViewRoot
    end

    #cattr_reader :toolViewDefault
    @@toolViewDefault = nil
    def self.toolViewDefault()
      return @@toolViewDefault
    end

    #cattr_reader :toolViewCaches
    @@toolViewCaches = nil
    def self.toolViewCaches()
      return @@toolViewCaches
    end

    def ViewHelper.included(includer)
      ViewHelper.init()
    end

    def ViewHelper.extended(extender)
      ViewHelper.init()
    end

    def ViewHelper.init()
      if(@@toolViewCaches.nil?)
        # First, take this opportunity to update GenboreeConfig if it has been modified.
        if(@@genbConf.is_a?(BRL::Genboree::GenboreeConfig))
          refresh = @@genbConf.reload()
        else
          @@genbConf = BRL::Genboree::GenboreeConfig.load()
          refresh = true
        end
        # Second, update certain key values from config file (so we don't have to
        # get them through method_missing/Hash#[] calls all them time).
        if(refresh or @@toolViewRoot.nil? or @@toolViewDefault.nil?)
          @@toolViewRoot = @@genbConf.toolViewRoot
          @@toolViewDefault = @@genbConf.toolViewDefault
          @@toolViewRegexp = /^#{@@toolViewRoot}\/([^\/]+)\/uis(\/.*)([^\/]+)\.rhtml$/
          # Track maximum size of caches (in objects, not MB)
          @@maxCachedToolViews ||= {}
          @@maxCachedToolViews[:full] = @@genbConf.maxCachedToolViews.to_i
          @@maxCachedToolViews[:frag] = @@genbConf.maxCachedToolViewFragments.to_i
          @@maxCachedToolViews[:staticFrag] = @@genbConf.maxCachedToolViewStaticFragments.to_i
          # Track dir patterns for finding views
          @@toolViewDirPatterns ||= {}
          @@toolViewDirPatterns[:full] = "#{@@toolViewRoot}/*/uis/*.rhtml"
          @@toolViewDirPatterns[:frag] = "#{@@toolViewRoot}/*/uis/fragments/*.rhtml"
          # !!! We do not pre-cache static frags! They require an evaluate context
          # !!! (which must be static/constant) and are thus cached upon first access
          # Make sure caches are initialized
          @@toolViewCaches ||= {}
          @@toolViewCaches[:full] ||= BRL::DataStructure::LimitedCache.new(@@maxCachedToolViews[:full])
          @@toolViewCaches[:frag] ||= BRL::DataStructure::LimitedCache.new(@@maxCachedToolViews[:frag])
          @@toolViewCaches[:staticFrag] ||= BRL::DataStructure::LimitedCache.new(@@maxCachedToolViews[:staticFrag])
        end
        # Third, take this opportunity to refresh our in-memory cached versions
        # of any tool views and view fragments.
        ViewHelper.precache()
      end
    end

    def ViewHelper.precache()
      t1 = Time.now
      # Find and cache tool views and tool view fragments
      @@toolViewDirPatterns.each_key { |viewType|
        dirPattern = @@toolViewDirPatterns[viewType]
        Dir.glob(dirPattern) { |path|
          if(path =~ @@toolViewRegexp)
            key = "#{$1}/uis#{$2}#{$3}"
            ViewHelper.cacheRhtml(@@toolViewCaches[viewType], key, path)
          else # bad path
            raise "ERROR: found a file #{path.inspect} that doesn't match expected pattern #{@@toolViewRegexp.source}."
          end
        }
      }
    end

    def ViewHelper.cacheRhtml(cache, key, rhtmlPath)
      # Create rhtml object (use new() rather than load_file() since we don't need to cache
      # on disk...we're caching these in MEMORY! But we have to save the filename manually)
      # and cache with respect to rhtml file's mtime
      rhtmlFile = File.open(rhtmlPath)
      rhtmlSize = File.size(rhtmlPath)
      rhtmlContent = rhtmlFile.read(rhtmlSize)
      rhtmlFile.close
      rhtml = Erubis::FastEruby.new(rhtmlContent, :preamble => RHTML_PREAMBLE, :postamble => RHTML_POSTAMBLE)
      rhtml.filename = rhtmlPath
      # Force insert the object into cache; either first time or due to mtime; regardless we know we want to insert/update.
      cached = cache.insertObject(key, rhtml, File.mtime(rhtmlPath))
      return cached
    end

    # Static Rhtml is pre-rendered [% %] and [%= %] blocks ONCE, upon the first access
    # using the (obviously static) context. This is faster than re-rendering the page over and over
    # dynamically with the same context contents. Because context is the same, just render once and be done.
    # Thereafter, dish up the static content from cache.
    # - This is ~3-4x faster even on initial access
    # - This is 30-40x faster on subsequent accesses
    def ViewHelper.cacheStaticRhtml(cache, key, rhtmlPath, preppedContext)
      # evaluate() will change theContext, so we need to determine the content digest BEFORE call evaluate
      # that way we'll be able to compare digests of theContext coming from the static rhtml fragments
      # to see if the content for the fragment has changed (we already handle changes to the fragment
      # code itself by looking at the file mtime...but content for static fragments comes from help dialogs
      # so we need to consider that too so we can notice any content changes)
      digest = SHA1.hexdigest(preppedContext.to_s)
      # Create rhtml object (use new() rather than load_file() since we don't need to cache
      # on disk...we're caching these in MEMORY! But we have to save the filename manually)
      # and cache with respect to rhtml file's mtime
      rhtmlFile = File.open(rhtmlPath)
      rhtmlSize = File.size(rhtmlPath)
      rhtmlContent = rhtmlFile.read(rhtmlSize)
      rhtmlFile.close
      rhtml = Erubis::FastEruby.new(rhtmlContent, :preamble => RHTML_PREAMBLE, :postamble => RHTML_POSTAMBLE)
      rhtml.filename = rhtmlPath
      preprocessedRhtml = rhtml.evaluate(preppedContext)
      # Force insert the object into cache. Might be due to mtime might be due to digest, regardless
      # we want to insert/update no matter what.
      cached = cache.insertObject(key, StaticContent.new(rhtml, preprocessedRhtml, digest), File.mtime(rhtmlPath))
      return cached
    end

    # ------------------------------------------------------------------
    # INSTANCE METHODS (if mixed in via include() or extend())
    # ------------------------------------------------------------------

    # Warning: we will modify theContext object here
    def prepContext(theContext)
      # Ensure context has these for any cascade rendering (else will be unavailable at next nested level)
      theContext[:genbConf] = @genbConf if(@genbConf)
      if(@toolIdStr)
        theContext[:toolIdStr] = @toolIdStr
        theContext[:toolConf] = BRL::Genboree::Tools::ToolConf.new(@toolIdStr, @genbConf)
      end
      theContext[:dbu] = @dbu if(@dbu)
      theContext[:rackEnv] = @req.env if(@req and @req.env)
      return theContext
    end

    # Checks if a user has access to a tool by checking if th user is part of the 'access group'
    # [+userId+] Genboree user id
    # [+toolConfObj+] toolConfig obj
    # [+hostAuthMap+] auth map for multi-host authentication (optional)
    # [+returns+] boolean: true or false (true: has access; false otherwise)
    def checkAccess(userId, toolConfObj, hostAuthMap=nil)
      retVal = false
      if(toolConfObj.respond_to?(:getSetting)) # is a tool conf obj
        groupUri = toolConfObj.getSetting('ui', 'groupAccessUri')
        if(!groupUri.nil?)
          uriObj = URI.parse(groupUri)
          host = uriObj.host
          hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, userId) unless(hostAuthMap)
          authRec = BRL::Genboree::Abstract::Resources::User.getAuthRecForUserAtHost(host, hostAuthMap)
          if(!authRec.nil? and !authRec.empty?)
            apiCaller = ApiCaller.new(host, "#{uriObj.path}?", hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias)
            apiCaller.get()
            retVal = apiCaller.succeeded? ? true : false
          end
        else # no groupAccessUri is set. Permission granted.
          retVal = true
        end
      else
        raise "Unknown type for toolConfObj."  
      end
      return retVal
    end

    def keyForTool(toolIdStr, uiType, viewType)
      key = case viewType
        when :frag
          "#{toolIdStr}/uis/fragments/#{uiType}.frag"
        when :staticFrag
          "#{toolIdStr}/uis/staticFragments/#{uiType}.frag"
        else
          "#{toolIdStr}/uis/#{uiType}"
      end
      return key
    end

    def renderFrag(toolIdStr, uiType, theContext={})
      return renderView(toolIdStr, uiType, :frag, theContext)
    end

    def renderStaticFrag(toolIdStr, uiType, theContext={})
      return renderStaticView(toolIdStr, uiType, theContext)
    end

    def renderDialogContent(toolIdStr, uiType, theContext={})
      return renderView(toolIdStr, uiType, :full, theContext)
    end

    def renderView(toolIdStr, uiType, viewType, theContext={})
      cache = @@toolViewCaches[viewType]
      # Determine appropriate key, taking into account that a tool-specific
      # view may not exist and thus a default one should be used.
      #
      # Try tool-specific key
      key = keyForTool(toolIdStr, uiType, viewType)
      # Path to tool-specific file
      path = "#{@@toolViewRoot}/#{key}.rhtml"
      # Is this a key in the cache, if so, everything good. If not...find appropriate key
      if(cache.key?(key) and File.exist?(path)) # Must be in cache AND still exist. Otherwise maybe in cache but since DELETED (b/c not needed)
        rhtml = cache.getObject(key)
        # mtime of file when put into cache:
        lastMtime = cache.getInsertTime(key)
      else # not in cache (or no longer exists), set it up to be cached or the default to be used
        rhtml = nil
        # - If no such file, then use default-related key (i.e. no tool override, use defaults:
        unless(File.exist?(path))
          # key involving the 'default' tool:
          key = keyForTool(@@toolViewDefault, uiType, viewType)
          # path to default version of file:
          path = "#{@@toolViewRoot}/#{key}.rhtml"
        end
      end

      # Are we cached and is version in cache as new as one on disk?
      currMtime = File.mtime(path)
      if(rhtml.nil? or currMtime > lastMtime) # then either not cached or version on disk newer than in cache
        # Cache the file:
        rhtml = ViewHelper.cacheRhtml(cache, key, path)
      end

      # Now it is in cache one way or another. Generate (or get) the html:
      self.prepContext(theContext)
      return rhtml.evaluate(theContext)
    end

    def renderStaticView(toolIdStr, uiType, theContext={})
      self.prepContext(theContext)
      digest = SHA1.hexdigest(theContext.to_s)
      cache = @@toolViewCaches[:staticFrag]
      # Determine appropriate key, taking into account that a tool-specific
      # view may not exist and thus a default one should be used.
      #
      # Try tool-specific key
      toolSpecificKey = "#{toolIdStr}/uis/staticFragments/#{uiType}.frag"
      # Path to tool-specific file
      path = "#{@@toolViewRoot}/#{toolSpecificKey}.rhtml"
      # Is this a key in the cache, if so, everything good. If not...find appropriate key
      if(cache.key?(toolSpecificKey))
        cacheEntry = cache.getObject(toolSpecificKey)
        # mtime of file was stored as the 'cache record insert time':
        lastMtime = cache.getInsertTime(toolSpecificKey)
      else # not in cache, set it up to be cached
        cacheEntry = nil
      end

      # - If no such file, then use default-related key (i.e. no tool override, use defaults):
      #   . note that we cache static fragments by the TOOL specific key even
      #     if we're using the default fragment to generate the content.
      #   . we DON'T cache static fragments according to a "default" tool because then ALL
      #     tools would have the SAME STATIC content built for them; no, instead we want
      #     tool-specific static content.
      unless(File.exist?(path))
        path = "#{@@toolViewRoot}/#{@@toolViewDefault}/uis/staticFragments/#{uiType}.frag.rhtml"
      end

      # Are we cached and is version in cache as new as one on disk?
      currMtime = File.mtime(path)
      if(cacheEntry.nil? or currMtime > lastMtime or cacheEntry.digest != digest) # then either not cached or version on disk newer than in cache
        # Cache the file:
        # - Note that unlike renderView, we cache according to the TOOL-SPECIFIC key, not a key that is tool OR 'default'
        cacheEntry = ViewHelper.cacheStaticRhtml(cache, toolSpecificKey, path, theContext)
      end

      # Now it is in cache one way or another. Generate final html
      return cacheEntry.content
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
