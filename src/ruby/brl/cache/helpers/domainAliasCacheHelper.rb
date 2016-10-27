require 'thread'
require 'json'
require 'brl/util/util'
require 'brl/util/propTable' # for PropTable class

module BRL ; module Cache ; module Helpers
  # To be mixed-into (via include) Classes which need access to properly-cached domainAlias info.
  module DomainAliasCacheHelper

    # Set up a cached version of the domain_alias_file for speed. But when loading
    # the alias file, it must check if file has been modified since last cached.
    # - a "Class Instance" variable used like this ApiCaller.cache
    # - not thread-friendly so some mutex's etc are used
    # - cache is generic, use keys to access the actual thing you want out of the cache
    class << self
      # Set up class instance variables
      attr_accessor :cache, :cacheLock
      DomainAliasCacheHelper.cache = nil
      DomainAliasCacheHelper.cacheLock = Mutex.new
    end

    def self.included(baseClass)
      # Add module methods as baseClass class methods (i.e. to class only...note inner module trick to avoid adding to instances as well)
      baseClass.extend(CacheClassMethods)
      # Ensure domain alias file has been read in (or read again if changed)
      baseClass.importDomainAliases()
    end

    # Inner module with methods to be added to including class (but not its instances)
    # - Note: ONE domain alias cache per Ruby instance, shared by all classes needing this functionality/info
    module CacheClassMethods
      # Same approach as for GenboreeConfig.load() =>
      def importDomainAliases(fileName=ENV['DOMAIN_ALIAS_FILE'])
        retVal = nil
        DomainAliasCacheHelper.cacheLock.synchronize {
          if(DomainAliasCacheHelper.cache) # then we have a valid cache
            cacheRec = DomainAliasCacheHelper.cache[fileName] # the file name is the key in the cache (can cache other things in this generic cache...)
            if(cacheRec and !cacheRec.empty? and cacheRec[:mtime] and cacheRec[:obj]) # have cached domain alias object, can we use it?
              fileMtime = File.mtime(fileName)
              if(cacheRec[:mtime] >= fileMtime and cacheRec[:obj]) # cache version is ok
                retVal = cacheRec[:obj]
              else # cache out of data or in middle of loading by some other thread
                retVal = nil
              end
            end
          else # no cache yet, initialize
            DomainAliasCacheHelper.cache = Hash.new { |hh,kk| hh[kk] = {} }
            retVal = nil
          end
          # If retVal still nil, either not cached yet or cache is out of date
          unless(retVal)
            # read genboree configuration file (we cannot use genboreeUtil here)
            genbConf = nil
            File.open(ENV["GENB_CONFIG"]) { |cfile|
              genbConf = BRL::Util::PropTable.new(cfile)
            }
            genbConf.each_key {|kk| genbConf[kk] = genbConf[kk].dup.untaint } # Dup and untaint values for web-use
            # grab all info about webserver from the configuration
            namesForWebserver = []
            namesForWebserver << genbConf['machineName']
            namesForWebserver << genbConf['machineNameAlias']
            namesForWebserver << genbConf['gbFQDN']
            if genbConf['gbWebserver'].to_s.downcase == 'true'
              if genbConf['gbAllowedHostnames'].kind_of?(Array)
                namesForWebserver += genbConf['gbAllowedHostnames']
              else
                namesForWebserver << genbConf['gbAllowedHostnames']
              end
            end
            namesForWebserver.delete_if { |x| x.nil? }  # remove nil elements
            namesForWebserver.uniq!
            # Get contents of file, our domain map
            domainMap = JSON.parse(File.read(fileName))
            # find groups of names for different hosts
            hosts_names = [ namesForWebserver ] # the first one is a group of names for the webserver
            domainMap.each { |key,value|
              next if not (key.nil? or value.nil? or key == value)
              found_group = false
              hosts_names.each { |group|
                if group.include?(key)
                  group << value if not group.include?(value)
                  found_group = true
                  break
                elsif group.include?(value)
                  group << key
                  found_group = true
                  break
                end
              }
              hosts_names << [key, value] if not found_group
            } 
            # choose canonical name for each group and create mappings
            mapToCanonicalName = Hash.new
            hosts_names.each { |group|
              canonicalName = nil
              ipNumbers = group.select { |x| x =~ /^\d+\.\d+\.\d+\.\d+$/}
              if ipNumbers.size == 0
                # no IP, just grab first domain name
                canonicalName = group.sort.first
              elsif ipNumbers.include?('127.0.0.1')
                # always take localhost, if present
                canonicalName = '127.0.0.1'
              else
                # choose some IP number
                ipNumbers.sort!
                # we prefer IP from private networks 
                ipNumbers.each { |x|
                  if x =~ /^10\./ or x =~ /^192\.168\./ or x =~ /^172\.(1[6-9]|2[0-9]|3[012])\./
                    canonicalName = x
                    break
                  end
                }
                # take the first one if there is no private ones
                canonicalName = ipNumbers.first if canonicalName.nil?
              end
              group.each { |name|
                mapToCanonicalName[name] = canonicalName
              }
            }  
            # Store instead of the old structure
            retVal = { :domains => mapToCanonicalName, :canonicalIps => mapToCanonicalName }
            DomainAliasCacheHelper.cache[fileName][:mtime] = File.mtime(fileName)
            DomainAliasCacheHelper.cache[fileName][:obj] = retVal
          end
        }
        return retVal
      end

      def getDomainAliases(mapType=:domains)
        aliasMaps = self.importDomainAliases()
        return aliasMaps[mapType]
      end

      def getDomainAlias(hostStr, mapType=:domains)
        retVal = hostStr
        domainAliases = self.importDomainAliases()
        if(domainAliases and domainAliases[mapType] and domainAliases[mapType][hostStr])
          retVal = domainAliases[mapType][hostStr]
        end
        return retVal
      end

      def getAllAliases(hostStr, mapType=:canonicalIps)
        retVal = [ hostStr ]
        domainAliases = self.importDomainAliases()
        if(domainAliases and domainAliases[mapType] and domainAliases[mapType][hostStr])
          retVal = [ hostStr, domainAliases[mapType][hostStr] ] if hostStr != domainAliases[mapType][hostStr]
        end
        return retVal
      end
    end # module CacheClassMethods
  end # module DomainAliasCacheHelper
end ; end ; end # module BRL ; module Genboree ; module CacheHelpers
