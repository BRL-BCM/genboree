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
    def initialize()
      @gbAuthHost = gbAuthHost()
    end

    # Get Genboree user's auth tuple based on Redmine login info, a target Genboree host,
    #   and project context.
    # @param [Project] project A Redmine {Project} model object corresponding to the project that the
    #   API call is being done within/for. Probably comes from @@project@ in the Controller, which should be
    #   retrieved [once! not over and over] via @Project.find@.
    # @param [String] gbTargetHost The host name of the Genboree to which an API request will be made. May
    #   be same or different than @@authHost@.
    # @param [User] rmUser OPTIONAL. The Redmine {User} model object corresponding to the Redmine user for which you need
    #   the Genboree authentication tuple. By default @User.current@, but to support shim users and other interesting
    #   scenarios, can override the default.
    # @return [Array] A two-column {Array} (tuple) with the user's Genboree login/pass. If this is an anonymous/public access
    #   within {project} because the project is public AND either it's the anonymous user or because user is a non-member then
    #   this array will be @[:anon, :anon]@. If the user is unknown or {project} is private and the user is not a member then
    #   this array will be @[nil, nil]@
    def authPairForUserAndHostInProjContext(project, gbTargetHost, rmUser=User.current)
      authPair = [ nil, nil ]
      rmLogin = rmUser.login
      if( (rmUser.type == 'AnonymousUser' or !rmUser.member_of?(project) and project.is_public) )
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
    def authPairForUserAndHost(gbTargetHost, rmUser=User.current)
      authPair = [ :nil, :nil ]
      rmLogin = rmUser.login
      # Get a GbDbConnection for its mysql
      gbDbConn = gbDbConn()
      # Get user recs for local
      gbLocalUserRec = gbDbConn.userRecByGbLogin(rmLogin)
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
          externalHostAccessRecs = gbDbConn.allExternalHostInfoByGbUserId(gbUserId)
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

    # Get a {GbDbConnection} to the Genboree instance providing authorization services for this Redmine
    # @return [GbApi::GbDbConnection] A connection object.
    def gbDbConn()
      gbAuthHost = gbAuthHost()
      dbconn = GbApi::GbDbConnection.new(gbAuthHost)
      return dbconn
    end
  end
end