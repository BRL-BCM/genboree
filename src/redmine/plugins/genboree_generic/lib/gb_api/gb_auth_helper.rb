require 'brl/cache/helpers/domainAliasCacheHelper'
require 'brl/cache/helpers/dnsCacheHelper'

module GbApi

  # Class for helping with Genboree based authorization. Can get host name of
  #   Genboree instance providing authentication services to this Redmine, can get
  #   user login/pass authentication tuples for a given Redmine user login, etc.
  class GbAuthHelper
    include BRL::Cache::Helpers::DomainAliasCacheHelper
    include BRL::Cache::Helpers::DNSCacheHelper

    attr_reader :gbAuthHost

    # CONSTRUCTOR. Will determine the host of the Genboree instance providing
    #   authentication services to this Redmine.
    def initialize( rackEnv )
      #$stderr.puts "rackEnv keys from gbAuthHelper new:\n\n#{rackEnv.keys.join("\n")}\n\nhas :currRmUser?\n\n#{rackEnv[:currRmUser].inspect}\n\n"
      @rackEnv = rackEnv
      @gbAuthHost = gbAuthHost()
    end

    # Get Genboree user's auth tuple based on Redmine login info, a target Genboree host,
    #   and project context.
    # @param [Project] project A Redmine {Project} model object corresponding to the project that the
    #   API call is being done within/for. Probably comes from @@project@ in the Controller, which should be
    #   retrieved [once! not over and over] via @Project.find@.
    # @param [String] gbTargetHost The host name of the Genboree to which an API request will be made. May
    #   be same or different than @@authHost@.
    # @param [User] rmUser The Redmine {User} model object corresponding to the Redmine user for which you need
    #   the Genboree authentication tuple. Should provide @@currRmUser@ from controller or similar, but to support
    #   shim users and other interesting scenarios, can override the default.
    # @return [Array] A two-column {Array} (tuple) with the user's Genboree login/pass. If this is an anonymous/public access
    #   within {project} because the project is public AND either it's the anonymous user or because user is a non-member then
    #   this array will be @[:anon, :anon]@. If the user is unknown or {project} is private and the user is not a member then
    #   this array will be @[nil, nil]@
    def authPairForUserAndHostInProjContext(project, gbTargetHost, rmUser=@rackEnv[:currRmUser])
      authPair = [ nil, nil ]
      rmLogin = rmUser.login
      if( (rmUser.type == 'AnonymousUser' or ( !rmUser.member_of?(project) and project.is_public ) ) )
        # Accessing project by virtual of it being public AND the user is anonymous/public user or is a logged in  non-member
        authPair = [:anon, :anon]
      elsif(rmUser.member_of?(project))
        authPair = authPairForUserAndHost(gbTargetHost, rmUser)
      else
        authPair = [ nil, nil ]
      end
      return authPair
    end

    # Get Genboree user's auth tuple based on Redmine login info and a target Genboree host. Regardless of project.
    # @param gbTargetHost (see #authPairForUserAndHostInProjContext)
    # @param rmUser (see #authPairForUserAndHostInProjContext)
    # @return [Array] A two-column {Array} (tuple) with the user's Genboree login/pass. If the user is unknown or
    # the anonymous user then this array will be @[nil, nil]@
    def authPairForUserAndHost(gbTargetHost, rmUser=@rackEnv[:currRmUser])
      authPair = [ nil, nil ]
      rmLogin = rmUser.login
      # Get a GbDbConnection for its mysql
      gbUser = gbUser( rmLogin )
      # Get user recs for local
      gbLocalUserRec = gbUser.userRecByGbLogin(rmLogin)
      if(gbLocalUserRec)
        gbUserId = gbLocalUserRec['userId']
        # Is gbKbHost same as genboree auth host backing Redmine?
        canonGbAuthHost = self.class.canonicalAddress(@gbAuthHost)
        canonGbAuthHostAlias = self.class.getDomainAlias(canonGbAuthHost, :canonicalIps)
        gbKbHostCanonical = self.class.canonicalAddress(gbTargetHost)
        gbKbHostCanonicalAlias = self.class.getDomainAlias(gbKbHostCanonical, :canonicalIps)
        if( (canonGbAuthHost == gbKbHostCanonical) or
          (canonGbAuthHost == gbKbHostCanonicalAlias) or
          (canonGbAuthHostAlias == gbKbHostCanonical) or
          (canonGbAuthHostAlias == gbKbHostCanonicalAlias))
          authPair[0] = gbLocalUserRec['name']
          authPair[1] = gbLocalUserRec['password']
        else # Must be remote ... need query external host access
          externalHostAccessRecs = gbUser.allExternalHostInfoByGbUserId(gbUserId)
          externalHostAccessRecs.each { |rec|
            remoteHost = rec['host']
            canonicalAddress = self.class.canonicalAddress(remoteHost)
            # Do we know of an *alias* for this remote host?
            canonicalAlias = self.class.getDomainAlias(canonicalAddress, :canonicalIps)
            if( (canonicalAddress == gbKbHostCanonical) or
              (canonicalAddress == gbKbHostCanonicalAlias) or
              (canonicalAlias == gbKbHostCanonical) or
              (canonicalAlias == gbKbHostCanonicalAlias))
              authPair[0] = rec['login']
              authPair[1] = rec['password']
              break
            end
          }
        end
      end

      return authPair
    end

    # @return [String] Host name of the Genboree instance providing authorization services
    # for this Redmine.
    def gbAuthHost()
      unless(@gbAuthHost)
        retVal = nil
        gbAuthSrcs = AuthSourceGenboree.where( :name => "Genboree" )
        if(gbAuthSrcs and !gbAuthSrcs.empty?)
          gbAuthSrc = gbAuthSrcs.first
          @gbAuthHost = gbAuthSrc.host
        end
      end
      return @gbAuthHost
    end

    # Get a {GbDb::GbUser} to the Genboree instance providing authorization services for this Redmine
    # @todo This is a BLOCKING call, since that's how it gets genboree auth info currently.
    # @todo Convert this to use the NON-BLOCKING mode feature, and update code that uses it (e.g. in async GbApi methods)
    # @return [GbApi::GbDbConnection] A connection object.
    def gbUser( login=nil )
      if( login.blank? )
        login = @rackEnv[:currRmUser].login rescue nil
      end
      dbHost = gbAuthHost()
      gbUser = GbDb::GbUser.byLogin(@rackEnv, login, { :dbHost => dbHost, :emCompliant => false } )
      return gbUser
    end
  end
end
