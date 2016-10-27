require 'resolv'
require 'thread'
require 'json'
require 'brl/util/util'
require 'brl/cache/helpers/domainAliasCacheHelper'

module BRL ; module Cache ; module Helpers
  # To be mixed-into (via include) Classes which need access to properly-cached domainAlias info.
  module DNSCacheHelper
    include BRL::Cache::Helpers::DomainAliasCacheHelper

    def self.included(baseClass)
      # Add module methods as baseClass class methods (i.e. to class only...note inner module trick to avoid adding to instances as well)
      baseClass.extend(CacheClassMethods)
    end

    # Inner module with methods to be added to including class (but not its instances)
    # - Note: ONE domain alias cache per Ruby instance, shared by all classes needing this functionality/info
    module CacheClassMethods
      # Determine the canonical address for a host, which ought to the same for the
      # various host aliases by which a host is known. For example:
      # - 'genboree.org' inside BCM is 128.249.225.15
      #   . but there are LOTS of domains pointing to 128.249.225.15: "genboree.org", "brl.bcm.tmc.edu", "www.genboree.org", "snprc.genboree.org"
      # - similarly, it is possible for a single domain to have multiple IPs
      #   . e.g. to split effort amongst various [possibly distributed like google.com] equivalent servers
      # - thus, for use in normalizing equivalent names to a SINGLE address, we use the concept of "canonical address"
      #   . the "canonical address" will be the one that alphabetically sorts to the top.
      #   . usually there is just one address anyay
      # - uses caching for speed.
      def canonicalAddress(host)
        return BRL::Cache::Helpers::DNSCacheHelper.getDomainAlias(host)
      end

      # Checks if 2 addresses match by (a) retrieving the aliases of the hosts and then
      # (b) comparing those aliases via canonical IPs
      def addressesMatch?(queryHost, targetHost)
        target = BRL::Cache::Helpers::DNSCacheHelper.getDomainAlias(targetHost)
        query  = BRL::Cache::Helpers::DNSCacheHelper.getDomainAlias(queryHost)
        return (target == query)
      end

      # Uses canoncical address to check if queryHost matches any of the hosts in the Array targetHosts (should contain a target host and any aliases)
      def canonicalAddressesMatch?(queryHost, targetHosts)
        targetHosts = [ targetHosts ] unless(targetHosts.is_a?(Array))
        canonicalQuery = self.canonicalAddress(queryHost)
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "qHost => cQuery: #{queryHost.inspect} => #{canonicalQuery.inspect}")
        retVal = false
        targetHosts.each { |targetHost|
          canonicalTarget = self.canonicalAddress(targetHost)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "tHost => cTarget: #{targetHost.inspect} => #{canonicalTarget.inspect}")
          if(canonicalTarget == canonicalQuery)
            retVal = true
            break
          end
        }
        return retVal
      end
    end # module CacheClassMethods
  end # module DNSCacheHelper
end ; end ; end # module BRL ; module Genboree ; module CacheHelpers
