#!/usr/bin/env ruby
require 'fileutils'
require 'erubis'
require 'find'

require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/ui/menu/extJsMenuGenerator'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
  class UIMenuResources < BRL::REST::Resources::GenboreeResource
    # TODO: allow menu-as-path
    # TODO: allow no-top-level tool bar??
    # TODO: return Not Found properly

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] +Regexp+:
    def self.pattern()
      return %r{^/REST/#{VER_STR}/genboree/ui/menu/([^/\?]+)$}
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 3          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      @statusName = super()
      @menuIdStr = Rack::Utils.unescape(@uriMatchData[1])
      # Flag for setting output readability
      @readable = (@nvPairs['readable'] == 'yes' or @nvPairs['readable'] == 'true')
      @prefix = (!@nvPairs['prefix'].nil?) ? @nvPairs['prefix'] : 'wb' # default for workbench
      # This resource currently defaults to javascript output but may support other formats in the future
      @responseFormat = :JS
      return @statusName
    end

    # Process a GET operation on this resource.
    #
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      #$stderr.puts "DEBUG => #{self.class}##{__method__} START #{t=Time.now}"
      initStatus = initOperation()
      # If something wasn't right, represent as error
      if(initStatus == :OK)
        # Set the response to the javascript output
        # Do things manually because bodyText is just plain String with JS (not a formal Entity),
        @resp.status = HTTP_STATUS_NAMES[:OK]
        @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[@responseFormat]
        # Initialize our menuGenerator object with options
        menuGenerator = BRL::Genboree::UI::Menu::ExtJsMenuGenerator.new(@menuIdStr, @prefix, @readable)
        # Render menu, get's it from cache if it's there
        @resp.body = menuGenerator.renderMenu()
        if(@resp.body.respond_to?(:size))
          @resp['Content-Length'] = @resp.body.size.to_s
        end
      else
        @resp = representError()
      end
      return @resp
    end
  end # class
end ; end ; end # module BRL ; module REST ; module Resources
