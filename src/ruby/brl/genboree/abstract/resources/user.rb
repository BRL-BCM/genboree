#!/usr/bin/env ruby

require 'brl/util/util'
require 'brl/cache/helpers/domainAliasCacheHelper'
require 'brl/cache/helpers/dnsCacheHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'

#--
# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

#--
module BRL ; module Genboree ; module Abstract ; module Resources
#++
  # Group - This abstraction class implements behaviors related to Users.
  class User
    # ------------------------------------------------------------------
    # MIX-INS
    #------------------------------------------------------------------
    # Uses the global domain alias cache and methods
    include BRL::Cache::Helpers::DomainAliasCacheHelper
    include BRL::Cache::Helpers::DNSCacheHelper

    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------
    #
    # Roles by permission
    ROLES_TO_PERMISSIONS = {
      'r' =>  { 'administrator' => true, 'author' => true, 'subscriber' => true },
      'w' =>  { 'administrator' => true, 'author' => true, 'subscriber' => false },
      'o' =>  { 'administrator' => true, 'author' => false, 'subscriber' => false }
    }
    # Permissions by role
    PERMISSIONS_TO_ROLES = {
      'administrator' => { 'r' => true, 'w' => true, 'o' => true },
      'author'        => { 'r' => true, 'w' => true, 'o' => false },
      'subscriber'    => { 'r' => true, 'w' => false, 'o' => false },
      'public'        => { 'r' => true, 'w' => false, 'o' => false }
    }

    #
    # TODO: insert an externalHostAccess record.
    #       - insert for both the canoncialName of host AND any domain alias of host AND any domain alias of canoncialName (if different

    # Get userId for a given login (name)
    # @param  [DBUtil] dbu an instance of {DBUtil}, ready to do DB work. Can be nil, but less efficient since one will
    #    have to be created
    # @param  [String] login the Genboree login/username to get the local db userId for
    # @return [Fixnum, nil] the userId matching the login or nil if not a known logic
    def self.getUserIdForLogin(dbu, login)
      retVal = nil
      if(login)
        # init
        genbConf = BRL::Genboree::GenboreeConfig.load()
        dbu ||= BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
        localUserRecs = dbu.getUserByName(login)
        if(localUserRecs and !localUserRecs.empty?) # then valid local user
          retVal = localUserRecs.first['userId']
        end
      end
      return retVal
    end

    # Get userName/login for a given userId
    # @param  [DBUtil] dbu an instance of {DBUtil}, ready to do DB work. Can be nil, but less efficient since one will
    #    have to be created
    # @param  [Fixnum] userId the Genboree userId to get the local userName for
    # @return [Fixnum, nil] the userId matching the login or nil if not a known logic
    def self.getLoginForUserId(dbu, userId)
      retVal = nil
      if(userId)
        # init
        genbConf = BRL::Genboree::GenboreeConfig.load()
        dbu ||= BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
        localUserRecs = dbu.getUserByUserId(userId)
        if(localUserRecs and !localUserRecs.empty?) # then valid local user
          retVal = localUserRecs.first['name']
        end
      end
      return retVal
    end

    # Get Array of host names to which we know user has Genboree access to.
    # - will include "this" host, as well as any external Genboree hosts the user
    #   has let us know about (registered if you will)
    # - as noted in brl/genboree/db/tables/core.rb, we make simplifying assumptions:
    #   . the domain name for a Genboree instance corresponds to an IP address that can be used instead
    #   . the host name retrieved for that IP address is the Genboree instance's domain name
    #   . i.e. ipOf(name) = ipof(nameOf(ipOf(name)))
    #   . i.e. no IP-multihosting!
    # - therefore because the table has a unique key on userId+canonicalAddress, there will be no "duplicate" (or "equivalent") entries.
    # - ideally, we're only entering in canonical host address into externalHostAccess, but just in case...
    # [+dbu+] Instance of DBUtil, ready to do DB work. Can be nil, but less efficient since one will
    #         have to be created
    # [+userId+] Id of the user
    def self.getHostsForUserId(dbu, userId)
      retVal = []
      if(userId > 0)  # Do not do "superuser" (id 0) or invalid ids
        # init
        genbConf = BRL::Genboree::GenboreeConfig.load()
        dbu ||= BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
        localUserRecs = dbu.getUserByUserId(userId)
        if(localUserRecs and !localUserRecs.empty?) # then valid local user
          # add the local host to the list
          retVal << genbConf.machineName
          # add any known external hosts user has access to
          externalHostAccessRecs = dbu.getExternalHostsByUserId(userId)
          externalHostAccessRecs.each { |rec|
            retVal << rec['host']
          }
        end
      end
      return retVal
    end

    # Get Hash of host-names to 3-column Array record with login & password & hostType (:internal | :external) for that host.
    # - will include "this" host, as well as any external Genboree hosts the user
    #   has let us know about (registered if you will)
    # [+dbu+] Instance of DBUtil, ready to do DB work. Can be nil, but less efficient since one will
    #         have to be created
    # [+userId+] Id of the user
    # [+includeAliasEntry+] If overridden as true, make sure user has entry for machineName AND machineNameAlias (not jsut machineName)
    def self.getHostAuthMapForUserId(dbu, userId, includeAliasEntry=true)
      retVal = {}
      if(userId)
        userId = userId.to_i unless(userId.is_a?(Fixnum))
        genbConf = BRL::Genboree::GenboreeConfig.load()
        if(userId > 0)  # Do not do "superuser" (id 0) or invalid ids
          dbu ||= BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
          localUserRecs = dbu.getUserByUserId(userId)
          if(localUserRecs and !localUserRecs.empty?) # then valid local user
            # add the local host to the list
            localUserRec = localUserRecs[0]
            machineNameCanonical = self.canonicalAddress(genbConf.machineName)
            retVal[machineNameCanonical] = [ localUserRec['name'], localUserRec['password'], :internal ]
            # add the local host alias to the list [if there is one]
            if(includeAliasEntry and genbConf.machineNameAlias)
              machineNameCanonical = self.canonicalAddress(genbConf.machineNameAlias)
              retVal[machineNameCanonical] = [ localUserRec['name'], localUserRec['password'], :internal ]
            end
            localUserRec.clear()
            # add any known external hosts user has access to
            externalHostAccessRecs = dbu.getAllExternalHostInfoByUserId(userId)
            externalHostAccessRecs.each { |rec|
              remoteHost = rec['host']
              canonicalAddress = self.canonicalAddress(remoteHost)
              # What if remote Genboree domain has gone away (out of DNS)? Then just skip.
              if(canonicalAddress)
                authRec = [ rec['login'], rec['password'], :external ]
                retVal[canonicalAddress] = authRec
                # Do we know of an *alias* for this remote host?
                canonicalAlias = self.getDomainAlias(canonicalAddress, :canonicalIps)
                if(canonicalAlias and canonicalAlias != canonicalAddress)
                  # Yes, we do. Make sure it is in host auth map too with same login as the non-alias
                  retVal[canonicalAlias] = authRec
                end
              end
            }
          end
        elsif(genbConf.gbSuperuserId == userId)
          dbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc()
          machineNameCanonical = self.canonicalAddress(genbConf.machineName)
          retVal[machineNameCanonical] = [ dbrc.user, dbrc.password, :internal ]
          if(includeAliasEntry and genbConf.machineNameAlias)
            machineNameCanonical = self.canonicalAddress(genbConf.machineNameAlias)
            retVal[machineNameCanonical] = [ dbrc.user, dbrc.password, :internal ]
          end
        end
      end
      return retVal
    end

    # Retrieve authentication information from host via the hostAuthMap, resolving host aliases
    #   and excessive HTTP context
    # @param [String] host the host to get authentication information for
    # @param [Hash] hostAuthMap mapping of host to 3-tuple containing login, password (hash?),
    #   and :internal or :external symbol
    # @return [NilClass, Array] 3-tuple described in hostAuthMap or nil if the host cannot be found
    def self.getAuthRecForUserAtHost(host, hostAuthMap, genbConf=nil)
      authRec = nil
      # Strip of the port address from the host (if present)
      host.gsub!(/\:\d+$/, '')
      # 1. Get canonical address for host
      canonicalAddress = self.canonicalAddress(host)
      # 2. Look for record via canonicalAddress
      authRec = hostAuthMap[canonicalAddress]
      # 3. If not there, fall back on entry for host itself
      authRec = hostAuthMap[host] unless(authRec)
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "host: #{host.inspect}\n      canonicalAddress: #{canonicalAddress.inspect} ; authRec: #{authRec.inspect} ; hostAuthMap: #{hostAuthMap.inspect}")
      # If have authRec, use it. Else try domain alias of host if available.
      unless(authRec)
        aliasAddress = self.getDomainAlias(host)
        if(aliasAddress != host) # First: tries in the forward direction
          # 1. Get canonical address for host
          canonicalAddress = self.canonicalAddress(aliasAddress)
          # 2. Look for record via canonicalAddress
          authRec = hostAuthMap[canonicalAddress]
        else # Second: host may BE the alias, but hostAuthMap uses the non-alias.
          # Need to examine ALL non-aliases to see if any are keys in hostAuthMap
          nonAliases = []
          domainAliases = self.getDomainAliases()
          # Collect non-aliases whose alias is host:
          domainAliases.each_key { |nonAlias|
            aliasName = domainAliases[nonAlias]
            nonAliases << nonAlias if(aliasName == host)
          }
          # Examine the non-aliases to see if they are in hostAuthMap
          nonAliases.each { |nonAlias|
            # 1. Get canonical address for nonAlias
            canonicalAddress = self.canonicalAddress(nonAlias)
            # 2. Look for record via canonicalAddress
            authRec = hostAuthMap[canonicalAddress]
            # 3. If found, then stop, else keep looking over all nonAliases whose value is host
            break if(authRec and authRec[0] and authRec[1])
          }
        end
      end
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG 2", "host: #{host.inspect}\n      canonicalAddress: #{canonicalAddress.inspect} ; authRec: #{authRec.inspect} ; hostAuthMap: #{hostAuthMap.inspect}")
      return authRec
    end

    # This method creates a group and adds the specified user as the administrator.
    # NOTE: If name isn't unique a fatal Db error will be thrown.
    #
    # [+dbu+] Instance of DBUtil, ready to do DB work.
    # [+groupName+] Name of a Genboree user group.
    # [+userId+] Id of the user who will be [the first] owner of the group.
    # [+description+] [optional; default=""] The group description.
    # [+returns+] GroupId of the record that was just created.
    def self.createGroupForUser(dbu, groupName, userId, description='')
      groupId = 0
      rowsInserted = dbu.insertGroup(groupName, description)
      if(rowsInserted == 1)
        groupId = dbu.genbDbh.func(:insert_id)
      end
      if(groupId > 0)
        # Add the user to the new group as administrator
        rowsInserted = dbu.insertUserIntoGroupById(userId, groupId, 'o')
      end
      unless(rowsInserted > 0 and groupId > 0)
        raise "There has been an error in createGroupForUser(dbu, #{groupName}, #{userId}"
      end
      return groupId
    end

    def self.hasPublicDatabases(dbu, groupId)
      groupRow = dbu.selectGroupByName(groupName)
      unless(groupRow.empty?)
        retVal = true
      end
      groups = dbu.getGroupNamesByUserId(userId)
    end

    def self.getGroupListForUser(dbu, userId, includePublic=false)
      groups = dbu.getGroupNamesByUserId(userId)
      if(includePublic)
        publicGroups = dbu.getPublicGroups()
        # Merge the 2 lists
        groups = (groups + publicGroups).uniq_by { |row| row['groupId'] }
      end
      return groups
    end

    def self.gbAuditor?(dbu, userId)
      retVal = false
      auditorValueRecs = dbu.selectUserValueByUserIdAndAttributeName(userId, 'gbAuditor')
      if(auditorValueRecs and !auditorValueRecs.empty?)
        auditorValueRec = auditorValueRecs.first
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "auditorValueRec: #{auditorValueRec.inspect}")
        auditorValue = auditorValueRec['value'].strip
        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "auditorValue: #{auditorValue.inspect} ; match? #{auditorValue =~ /^(?:true|yes)$/i}")
        retVal = true if(auditorValue =~ /^(?:true|yes)$/i)
      end
      return retVal
    end
  end
end ; end ; end ; end
