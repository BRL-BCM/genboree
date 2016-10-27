require 'uri'
require 'brl/cache/helpers/dnsCacheHelper'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/helpers/groupApiUriHelper'

module BRL ; module Genboree ; module Tools
  module AccessHelper
    # ------------------------------------------------------------------
    # MIX-INS
    #------------------------------------------------------------------
    # Uses the global domain alias cache and methods
    include BRL::Cache::Helpers::DNSCacheHelper
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------
    CAN_READ_CODES = [ 'r', 'w', 'o' ]
    CAN_WRITE_CODES = [ 'w', 'o' ]
    GRP_ADMIN_CODES = [ 'o' ]

    # ------------------------------------------------------------------
    # MODULE METHODS
    # - available to objects in the BRL::Genboree::Tools names space
    # - assumes usage via mixin to a WorkbenchJobHelper or WorkbenchRulesHelper class
    # ------------------------------------------------------------------
    #
    # Used to populate the host-specific @hostAuthMap Hash using the "context" data
    # in a given workbenchJobObj and also populates the @userLogin instance variable for convenience.
    # - Assumes context['userId'] is properly filled in with user's userId in the
    #   local Genboree instance.
    def initUserInfo(workbenchJobObj=@workbenchJobObj)
      @userId = workbenchJobObj.context['userId'].to_i
      if(@userId == @genbConf.gbSuperuserId.to_i)  # then is a job being done by superuser? (should be rare!)
        # Log this rare scenario
        $stderr.debugPuts(__FILE__, __method__, 'BUG', "Processing a 'superuser' workbench job (class: #{self.class})? Possibly bad code that needs fixing; double check.")
        # Setup @hostAuthMap (just the 1 record for the local Genboree instance)
        @hostAuthMap = { AccessHelper.canonicalAddress(@localHostName) => [ @superuserApiDbrc.user, @superuserApiDbrc.password, :internal ] }
        @userLogin = 'gbSuperuser'
      else  # Need populate @hostAuthMap for regular Genboree user
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
        # Get login for userId
        userRows = @dbu.getUserByUserId(@userId)
        if(userRows and !userRows.empty?)
          @userLogin = userRows.first['name']
        else
          $stderr.debugPuts(__FILE__, __method__, "NOTE", "No user table rows for user with @userId=#{@userId.inspect}. Probably the public 'user' which is not a real user and should have fake userId of 0 (#{@userId == 0}). And @hostAuthMap should be empty in this case (#{@hostAuthMap.empty? rescue nil}).")
        end
      end
      return @hostAuthMap
    end

    # Check if user has at least this level of permission in group mentioned
    # in the resourse URI. This will be done via an API call using @hostAuthMap
    # to the role of the user within the group mentioned in the uri.
    # - If there is no group mentioned, this will return false.
    # - For batch checking, use testUserPermissions(), which is more efficient.
    # [+minPermission+] one of :read, :write, :admin
    # TODO: add support for AUTHOMATIC TRACK accessible checking.
    #       . notice trk uris
    #       . use updated trackApiUriHelper#accessibleByUser() method to check accessible or not
    def testUserPermission(uri, minPermission)
      # Return whether user has the min level of permission
      return @grpApiHelper.accessibleByUser?(uri, @userId, [ minPermission ], @hostAuthMap)
    end

    # Check if user has at least this level of permission in ALL groups mentioned
    # in the resourse URIs. This will be done via an API call using @hostAuthMap
    # to the role of the user within the group mentioned in the uri.
    # - If ANY URL has no group component, this will return raise an exception.
    # - To save a little time, this method will first find the unique set group
    #   resources.
    # [+minPermission+] one of 'r', 'w', 'o'
    # TODO: add support for AUTHOMATIC TRACK accessible checking.
    #       . notice trk uris
    #       . collect unique track uris separately from group uris
    #       . use updated trackApiUriHelper#accessibleByUser() method to check accessible or not
    # TODO: make this more tolerant of multi-host access (gbKey checking would need to be done
    #       via an API query or something for remote resources...local database query won't cut it)
    def testUserPermissions(uris, minPermission)
      retVal = false
      accessOkCount = 0
      # May need to collect unique set of grpUris from uris as we iterate through them
      grpUris = {}
      uris.each { |uri|
        # Does this look like an entity WITHIN/IS a group or ABOVE/OUTSIDE a group?
        # - for example, for hosts the uris end up looking like http://{host}/REST/v1/usr/{usr}/grps
        # - but user entities and other extra-group things also are not necessarily within groups
        if(uri =~ %r{/grp/})
          # First try checking via a gbKey approach.
          # - create group api uri helper
          reusableComponents = { :superuserApiDbrc => @superuserApiDbrc, :superuserDbDbrc => @superuserDbDbrc }
          apiUriHelper = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@dbu, @genbConf, reusableComponents)
          apiUriHelper.rackEnv = @rackEnv
          gbKeyAccessStatus = apiUriHelper.gbKeyAccess(uri, :get)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "GB_KEY: gbKeyAccessStatus=#{gbKeyAccessStatus.inspect} for uri #{uri.inspect}")
          # If the uri can be accessed by its query string gbKey, then make sure minPermission is just :read and you're good.
          if(gbKeyAccessStatus == :OK and minPermission == 'r')
            accessOkCount += 1
          else # See if the user themselves has sufficient Role within the Group indicated in the Uri
            # Get query string, if any
            queryString = @grpApiHelper.extractQuery(uri)
            # Get pure entity URI
            pureUri = @grpApiHelper.extractPureUri(uri)
            # Rebuild uri:
            pureUri = "#{pureUri}?#{queryString}"
            # Store the group URI for batch checking following iteration
            if(pureUri)
              grpUris[pureUri] = nil
            else # no grp component found
              raise "ERROR: #{self.class}##{__method__}() given a uri with no group component. Not allowed."
            end
          end
        else # Currently we'll assume user has access to the extra-group entity because the Workbench showed it to them...
          accessOkCount += 1
        end
      }
      # At this point either ALL have been verified via the gbKey and accessOkCount == uris.size
      # OR we have to go through some group uris to see if the user has access that way.
      if(accessOkCount == uris.size)
        retVal = true
      else
        retVal = @grpApiHelper.allAccessibleByUser?(grpUris.keys, @userId, [ minPermission ], @hostAuthMap) rescue false
      end
      return retVal
    end
  end # AccessHelper
end ; end ; end # module BRL ; module Genboree ; module Tools
