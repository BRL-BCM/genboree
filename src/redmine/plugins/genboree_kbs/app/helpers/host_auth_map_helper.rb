require 'brl/cache/helpers/domainAliasCacheHelper'
require 'brl/cache/helpers/dnsCacheHelper'

module GenboreeKbHelper
  class HostAuthMapHelper
    include BRL::Cache::Helpers::DomainAliasCacheHelper
    include BRL::Cache::Helpers::DNSCacheHelper

    # Get user auth for Genboree hosting the GenboreeKB data
    def self.getHostAuthMapForUserAndHostName(localUserRecs, gbKbHost, gbAuthHost, dbconn)
      retVal = {}
      userInfo = [nil, nil]
      localUserRec = localUserRecs.first
      userId = localUserRec['userId']
      # Is gbKbHost same as genboree auth host backing Redmine?
      canonGbAuthHost = self.canonicalAddress(gbAuthHost)
      canonGbAuthHostAlias = self.getDomainAlias(canonGbAuthHost, :canonicalIps)
      gbKbHostCanonical = self.canonicalAddress(gbKbHost)
      gbKbHostCanonicalAlias = self.getDomainAlias(gbKbHostCanonical, :canonicalIps)
      if( (canonGbAuthHost == gbKbHostCanonical) or
          (canonGbAuthHost == gbKbHostCanonicalAlias) or
          (canonGbAuthHostAlias == gbKbHostCanonical) or
          (canonGbAuthHostAlias == gbKbHostCanonicalAlias))
        userInfo[0] = localUserRec['name']
        userInfo[1] = localUserRec['password']
      else # Must be remote ... need query external host access
        externalHostAccessRecs = dbconn.getAllExternalHostInfoByUserId(userId)
        externalHostAccessRecs.each { |rec|
          remoteHost = rec['host']
          canonicalAddress = self.canonicalAddress(remoteHost)
          # Do we know of an *alias* for this remote host?
          canonicalAlias = self.getDomainAlias(canonicalAddress, :canonicalIps)
          if( (canonicalAddress == gbKbHostCanonical) or
              (canonicalAddress == gbKbHostCanonicalAlias) or
              (canonicalAlias == gbKbHostCanonical) or
              (canonicalAlias == gbKbHostCanonicalAlias))
            userInfo[0] = rec['login']
            userInfo[1] = rec['password']
            break
          end
        }
      end
      return userInfo
    end
  end
end