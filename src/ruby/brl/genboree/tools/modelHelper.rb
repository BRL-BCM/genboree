require 'uri'
require 'cgi'
require 'json'
require 'erubis'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'

module BRL ; module Genboree ; module Tools
  module ModelHelper
    # ------------------------------------------------------------------
    # MODULE CONSTANTS
    # ------------------------------------------------------------------
    # Map of entity type (or entity collection type) as symbol to a Hash
    # of attribute names which should be removed from any lists of attributes
    DEFAULT_ATTR_KILL_LIST = {
      :trks => {

      }
    }

    # ------------------------------------------------------------------
    # MODULE METHODS
    # - available to objects in the BRL::Genboree::Tools names space
    # - assumes usage via mixin to a WorkbenchJobHelper or WorkbenchRulesHelper class
    # ------------------------------------------------------------------
    #
    # getTrksAttrNames()
    # - returns unique list of attribute names associated with any/all of the entities provided
    # [+entityType+] - A Symbol indicating the  type of entity in entities Array. Not all types supported
    #                  (add support if missing & needed). Raises exception if called with unsupported type.
    # [+entityUrls+] - Array of full API URLs to 1+ entities to get the attributes for
    # [+anyOrAll+] - :any => the attribute can be in any track; :all => the attribute must be in all tracks
    # [+killList+] - Hash of attributes which will be skipped. Defaults to DEFAULT_ATTR_KILL_LIST[:entityType]
    # [+returns+] - Array of attribute names
    def getAttrNames(entityType, entityUrls, anyOrAll=:any, killList=nil)
      retVal = nil
      # Check entityType supported or raise exception
      unless(DEFAULT_ATTR_KILL_LIST.key?(entityType))
        raise ArgumentError, "ERROR: unsupported entity-type #{entityType.inspect}. Do you need to add appropriate support code to #{File.basename(__FILE__)}?"
      else # entityType ok
        # Check all URLs look like they refer to entityType entities
        entitiesOk = true
        entityUrls.each { |entityUrl|
          if(entityUrl !~ %r{/#{entityType}/})
            raise ArgumentError, "ERROR: one or more entityUrls provided is not of type #{entityType.inspect}."
          end
        }
        # Call appropriate method to get attributes for entity type
        case entityType
          when :trks
            retVal = getTrksAttrNames(entityUrls, anyOrAll, killList)
          else
            raise ArgumentError, "ERROR: unsupported entity-type #{entityType.inspect}. Do you need to add appropriate support code to #{File.basename(__FILE__)}?"
        end
      end
      return retVal
    end

    # ------------------------------------------------------------------
    # "protected" methods
    # - not meant to be called directly; do not override
    # - helpers for generally useful methods above
    # ------------------------------------------------------------------
    def getTrksAttrNames(entityUrls, anyOrAll=:any, killList=DEFAULT_ATTR_KILL_LIST[:trks])
      attrNames = {}
      # Get superuser API key for this host (will be used to look up any per-user API credential info)
      suDbrc = @superuserApiDbrc || BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf)
      # Make ApiCaller for this host, for any superuser calls (start with call to get auth info for host)
      suApiCaller = BRL::Genboree::REST::ApiCaller.new(suDbrc.host, '/usr/')
      # TODO: use table to get access info for this user to indicated hostname

      return attrNames
    end
  end # module ModelHelper
end ; end end # module BRL ; module Genboree ; module Tools
