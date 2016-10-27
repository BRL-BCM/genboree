#!/usr/bin/env ruby
require 'sha1'
require 'brl/rest/resource'
require 'brl/genboree/dbUtil'
require 'brl/db/dbrc'
require 'brl/cache/helpers/domainAliasCacheHelper'
require 'brl/cache/helpers/dnsCacheHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/abstract/resources/abstractStreamer'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/rest/em/deferrableBodies/abstractDeferrableBody'
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/helpers/apiUriHelper'
require 'brl/genboree/rest/apiCaller'

module BRL  #:nodoc:
module REST #:nodoc:
# == Preamble
# Exposing new Genboree entities in the API involves implementing a
# REST Resource class for them within the <tt>{BRL::REST::Resources}[link:BRL/REST/Resources.html]</tt>
# namespace. Because some kind of representation of Genboree-stored data is needed, an
# implemention of a data (or representation) class for them within the
# <tt>{BRL::Genboree::REST::Data}[link:BRL/Genboree/REST/Data.html]</tt> namespace is also needed.
#
# == Exposing Genboree Resources
# Singular resources should have separate classes than collections of resources.
#
# Resource classes are automatically discovered by the API framework by looking in
# the <tt>{BRL::REST::Resources}[link:BRL/REST/Resources.html]</tt> for files
# and then for classes inheriting from <tt>{BRL::REST::Resource}[link:BRL/REST/Resource.html]</tt>.
#
# Because they inherit common core functionality from the
# <tt>{BRL::REST::Resource}[link:BRL/REST/Resource.html]</tt> and the
# <tt>{BRL::REST::Resources::GenboreeResource}[link:BRL/REST/Resources/GenboreeResource.html]</tt>
# abstract classes, the framework will obtain standard information from the class.
# The framework will use some of that (e.g. <tt>BRL::REST::Resource#pattern</tt>
# and <tt>BRL::REST::Resource#priority</tt>) to decide what resource class will
# handle a request, will access the standard class constants and object attributes,
# and will call standard methods at the appropriate times.
#
# <b>Tasks for exposing new Genboree resources:</b>
# * Create a _resource_ class within
#   <tt>{BRL::REST::Resources}[link:BRL/REST/Resources.html]</tt> (store the code
#   in a file under <tt>brl/genboree/rest/resources/</tt>)
#   * it must inherit from
#     <tt>{BRL::REST::Resources::GenboreeResource}[link:BRL/REST/Resources/GenboreeResource.html]</tt>
# * Create a <em>data representation</em> class within
#   <tt>{BRL::Genboree::REST::Data}[link:BRL/Genboree/REST/Data.html]</tt> (store
#   code in a file under <tt>brl/genboree/rest/data/</tt>)
#   * it must inherit from
#     <tt>{BRL::Genboree::REST::Data::AbstractEntity}[link:BRL/Genboree/REST/Data/AbstractEntity.html]</tt>
#
# <b>Tasks for modifying an existing Genboree resource:</b>
# * To add/modify an HTTP method, look for the appropriate resource class file under
#   <tt>brl/genboree/rest/resources/</tt> and implement or modify the corresponding
#   <tt>#get</tt>, <tt>#put</tt>, <tt>#delete</tt>, etc method as necessary.
# * If changes to the representations supported by the Genboree resource are needed,
#   look for the appropriate representation class file under <tt>/brl/genboree/rest/data/</tt>.
module Resources

  # == Purpose: Abstract Genboree Resource class.
  # Inherits common, but non-Genboree specific aspects from
  # BRL::REST::Resource; which means
  # these instance variables are available:
  # <tt>@req</tt>::           The HTTP request object (<tt>Rack::Request</tt> instance )
  # <tt>@resp</tt>::          The HTTP response object (<tt>Rack::Response</tt> instance)
  # <tt>@reqMethod</tt>::     The HTTP method (as a downcase symbol)
  # <tt>@uriMatchData</tt>::  The +MatchData+ object resulting from matching <tt>#pattern</tt> against a URI
  #
  # == Overview
  # All resource classes must inherit from this class. Furthermore, where appropriate
  # for standard methods, the <tt>#super</tt> method should be called to have this partent class
  # do proper setup of any new object or properly do its part in any processing (although this is
  # rare, usually methods are overridden completely).
  #
  # This abstract class provides default implementations for many standard methods which
  # can be used or which can be overridden if special handling is required by a subclass.
  #
  # === Commonly available instance variables
  # When the resource subclass is instantiated and calls <tt>#super</tt>,
  # <tt>{BRL::REST::Resources::GenboreeResource}[link:BRL/REST/Resources/GenboreeResource.html]</tt>
  # initializes several default instance variables. Additionally, the subclass's implementation of
  # <tt>#get</tt>, <tt>#put</tt>, or <tt>#delete</tt> will first call <tt>#initOperation</tt>,
  # which configures, extracts, and makes available quite a few standard instance variables that
  # the subclasses should make use of themselves as needed (and certainly should not extract and
  # store themselves if aready available).
  #
  # * <em><b>Refer to the attributes documented for this class to see what is available</b></em>
  # * <em><b>Refer to the documentation of <tt>#initOperation</tt> and, to a lesser extent,
  #   the other methods of this class for more information.</b></em>
  # * <em>As with the <tt>{BRL::REST::Resource}[link:BRL/REST/Resource.html]</tt>
  #   abstract class, this class will never match any request URI</em>
  #
  # === Available Helper Methods (for common init or to get cerain key common information for API work)
  # This super class and thus the resource-specific subclasses include (mixin) the BRL::Genboree::REST::Helpers
  # module. This adds all the methods defined in that module to this class as instance methods. Those methods are
  # commonly used by several resource-specific classes, although no subclass makes use of all of them.
  #
  # Make note of the instance variables the methods below make available; often they are the whole point of calling
  # the method in the first place.
  #
  # The Helpers methods added are:
  # BRL::Genboree::REST::Helpers#initUser()::                       Initialize user related info (provides @rsrcUserId).
  # BRL::Genboree::REST::Helpers#initGroup()::                      Initialize group related info (provides @groupId, @groupDesc, @groupAccessStr)
  # BRL::Genboree::REST::Helpers#initGroupAndDatabase()::           Initialize group and database related info (provides @groupId, @groupDesc, @groupAccessStr, @refseqRow, @refSeqId, @databaseName)
  # BRL::Genboree::REST::Helpers#initGroupAndProject()::            Initialize group and project related info (provides @groupId, @groupDesc, @groupAccessStr, @topLevelProjs, @projName, @projBaseDir, @escProjName, @projDir)
  # BRL::Genboree::REST::Helpers#initProjOperation()::              Initializes an operation on a project. Calls BRL::Genboree::REST::Helpers#initProjOperation() and also provides @aspect, @context
  # BRL::Genboree::REST::Helpers#initProjectObj()::               Creates a BRL::Genboree::ProjectMainPage instance for managing elements of a Project (provides @projMainPageObj).
  # BRL::Genboree::REST::Helpers#getFrefRows()::                    Get fref (entrypoint) rows for a particule user database.
  # BRL::Genboree::REST::Helpers#getTrackClassInfo()::              Get map of dbName->fytpeid->classNames.
  # BRL::Genboree::REST::Helpers#getTrackDescUrlInfo()::            Get 3 column array of track description, url, and urlLabel
  # BRL::Genboree::REST::Helpers#makeDetailedTrackEntity()::        Create a BRL::Genboree::REST::Data::DetailedTrackEntity for a track.
  # BRL::Genboree::REST::Helpers#makeClassesListEntity()::          Get list of classes associated with a track (from all the related databases in dbRecs) as a BRL::Genboree::REST::Data::TextEntityList
  # BRL::Genboree::REST::Helpers#makeAttributesListEntity(dbRecs):: Get list of attribute names associated with each track (from all the related databases in dbRecs) as a BRL::Genboree::REST::Data::TextEntityList
  # BRL::Genboree::REST::Helpers#prepDownloadErrorFile()::          Prepare an error file where we'll record any download problems.
  #

  class GenboreeResource < BRL::REST::Resource
    TRY_SCHEMES = [ "http", "https" ]
    # ------------------------------------------------------------------
    # MIX-INS
    # ------------------------------------------------------------------

    # Uses the global domain alias cache and methods
    include BRL::Cache::Helpers::DomainAliasCacheHelper
    include BRL::Cache::Helpers::DNSCacheHelper
    include BRL::Genboree::REST::Helpers  # Mixin some helper functions (common to several Genboree resource classes)

    class << self
      # Set up class instance variables
      attr_accessor :buildersLoaded, :buildersFileMap
      GenboreeResource.buildersLoaded = false
      GenboreeResource.buildersFileMap = {}
    end

    def self.inherited(childClass)
      # Static Block: require all builders here to ensure that
      # certain methods will work when a builder does not exist for the resource
      # Try to lazy-load (require) each file found in the resourcePaths.
      # We need to ENSURE we will only use the FIRST source file for a given extensionPath.
      # While a given extensionPath source file may be found under multiple topLevel paths,
      # (and consider that the SAME extensionPath may be found via different topLevel paths due to symlinks)
      # the FIRST one is the ONLY one we're allowed to use. This is standard convention for
      # RUBYLIB, PERL5LIB, PYTHONPATH, PATH, LD_LIBRARY_PATH, etc.
      # - Thus, the code below will note in GenboreeRESTRackup.resourceFileMap where a given extension was found.
      unless(GenboreeResource.buildersLoaded or ((GenboreeRESTRackup rescue nil) and GenboreeRESTRackup.classDiscoveryDone[self]))
        # $stderr.debugPuts(__FILE__, __method__, "LOAD", "inherited by #{childClass.inspect}")
        begin
          if(GenboreeRESTRackup rescue nil)
            # Must set this first, else requires in the things we are about to require can unnecessarily ALSO
            #   try to discover resources when they are required (probably due to their "require'ing" this exact file,
            #   each such require of this file would trigger resource discovery [as we have seen], ouch!)
            #   Wastes a lot of time doing redundant discovery.
            GenboreeResource.buildersLoaded = true
            # Record that we've done this class's discovery. Must do before start requiring.
            # - Must use already-defined global store of this info to prevent dependency requires while trying to define this class
            #   re-entering this discovery block over and over and over.
            GenboreeRESTRackup.classDiscoveryDone[self] = true
          end
          $LOAD_PATH.sort.each { |topLevel|
            if( (GenboreeRESTRackup rescue nil).nil? or GenboreeRESTRackup.skipLoadPathPattern.nil? or topLevel !~ GenboreeRESTRackup.skipLoadPathPattern )
              builderFiles = Dir["#{topLevel}/brl/genboree/rest/data/builders/*.rb"]
              #$stderr.puts "   - #{Time.now} #{builderFiles.size} in toplevel: #{topLevel}"
              builderFiles.sort.each{ |builderFile|
                extension = "brl/genboree/rest/data/builders/#{File.basename(builderFile, ".rb")}"
                unless(GenboreeRESTRackup.resourceFileMap[extension])
                  begin
                    #$stderr.puts "    . #{Time.now} Loading #{builderFile}"
                    require builderFile
                    GenboreeRESTRackup.resourceFileMap[extension] = builderFile
                  rescue => err
                    BRL::Genboree::GenboreeUtil.logError("Error: brl/genboree/rest/resources/genboreeResource => uncaught error during require block ", err)
                  end
                end
              }
            end
          }
          # $stderr.debugPuts(__FILE__, __method__, "LOAD", "registered builder classes")
        rescue => err
          BRL::Genboree::GenboreeUtil.logError("ERROR: brl/genboree/rest/resources/genboreeResource => uncaught error during static block", err)
        end
      end
    end

    # ------------------------------------------------------------------
    # Accessors/Properties
    # ------------------------------------------------------------------

    # The current Genboree configuration settings, as a helpful <tt>BRL::Genboree::GenboreeConfig</tt> instance. Config file properties can be accessed as methods.
    attr_accessor :genbConf
    # An instance of <tt>BRL::Genboree:DBUtil</tt> which is used to connect to databases and perform DB operations.
    attr_accessor :dbu
    # @return [Hash] the dbrc record for connecting to mongo
    attr_accessor :mongoDbrcRec
    # The IP address of the remote client making the request
    attr_accessor :remoteAddr
    # The complete request URI as a useful +URI+ object.
    attr_accessor :reqURI
    # The portion of the URI corresponding to the Genboree resource (i.e. full URI minus auth param bits)
    attr_accessor :rsrcURI
    # The path portion of the URI, the part that will be matched against <tt>BRL::REST::Resource#pattern</tt>
    attr_accessor :rsrcPath
    # The query string portion of the URI only (i.e. query string minus auth param bits)
    attr_accessor :rsrcQuery
    # The representation format to use, as extacted from the <tt>format</tt> name-value pair or to the default set by the class (<tt>:JSON</tt>).
    attr_accessor :repFormat
    # The format to use for the response, as extacted from the <tt>responseFormat</tt> name-value pair. Used to override the repFormat.
    attr_accessor :responseFormat
    # Boolean indicating whether the request does or doesn't want entity 'connections' information (from the 'connect' parameter) in the representation (i.e. +refs+ links)
    attr_accessor :connect
    # Boolean indicating whether the request is for a 'detailed' representation of the resource or not. Some resources will respond with different representations using this modifier.
    attr_accessor :detailed
    # The value of the required 'gbLogin' name-value parameter
    attr_accessor :gbLogin
    # The optional key value used for accessing 'unlockable' resources identified in genboree.unlockableGroupEntities
    attr_accessor :gbKey
    # +Hash+ of all the name-value pairs provided in the request URI
    attr_accessor :nvPairs
    # Genboree +userId+ of the user making the API request
    attr_accessor :userId
    # Email of the user making the API request (the email Genboree has for them)
    attr_accessor :userEmail
    # Current state of the return status. Starts off as <tt>:OK</tt>. Can be any valid HTTP response code's _official name_. Must be set by subclasses if other HTTP response status needs to be returned.
    attr_accessor :statusName
    # Current state of the return status message. Set this to an informative message if the <tt>#statusName</tt> becomes anything other than OK. The first word of the message should be some sort of tag/identifiier of the type of problem (but more specific than the HTTP response code name.
    attr_accessor :statusMsg
    # Boolean indicating whether to activate debug logging or not. Doesn't currently discriminate much of anything.
    attr_accessor :debug
    # Error status for the resources, set to a GenboreeError object containing the error information
    attr_accessor :apiError
    # Will be set to true if the gbKey matches the resource
    attr_accessor :gbKeyVerified
    # Access to the fiber (~thread) for this request...can be used for feeding long/large responses in specific cases.
    attr_accessor :fiber
    # Are we doing the request as the special Genboree superuser?
    attr_accessor :isSuperuser
    # The size of the request body after reading all of it by #readAllReqBody
    attr_accessor :allBodySize
    # Special 'gbSys' user authorization for high risk operations like skipping validation for kb docs upload
    attr_accessor :gbSysAuth

    # @return [Boolean] indicating if the resource representation should include internal db record
    #   id [numbers] when preparing responses.
    attr_accessor :dbIds

    # [Deprecated, use @superuserDbDbrc or @superuserApiDbrc] dbrc object for holding info for all internal machines. Will be same as @superuserApiDbrc.
    attr_accessor :dbrc
    # Official host name for this local Genboree instance
    attr_accessor :localHostName
    # Dbrc for superuser API auth info for local Genboree instance
    attr_accessor :superuserApiDbrc
    # Dbrc for superuser DB auth info for local Genboree instance
    attr_accessor :superuserDbDbrc
    # Hash of canonical address of hostName -> [login, password, hostType] for the user doing the request [if appropriate]
    attr_accessor :hostAuthMap
    # Is a Genboree audit access being requested (via gbAudit=yes in the query string)
    attr_accessor :gbAudit
    # Is the authenticated user a Genboree Auditor?
    attr_accessor :isGbAuditor
    # Can be used by a resource (which submits tool job) to suppress email sent by the job.
    attr_accessor :suppressEmail
    # Wrap response in default "data" envelope?
    attr_accessor :gbEnvelope
    # @return [String] The original request scheme, at least from the immediate downstream proxy
    attr_accessor :origReqScheme

    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------

    # Default is true, but may be used to lock down a resource
    UNLOCKABLE = true
    # Map HTTP methods for complete access. Specific resources will use this
    # or one of the other maps to determine which roles have access to which
    # aspects of a resource (only used for complex/specific resources like "track"...in
    # most resource classes these "PERMISSIONS_" maps are not used).
    PERMISSIONS_ALL_ACCESS =
      {
      :o => {:get => true, :put => true, :delete => true, :head => true, :options => true},
      :w => {:get => true, :put => true, :delete => true, :head => true, :options => true},
      :r => {:get => true, :put => true, :delete => true, :head => true, :options => true}
    }
    # Map HTTP methods for read-only access meaning "can only do GET"
    PERMISSIONS_R_GET_ONLY =
      {
      :o => {:get => true, :put => true, :delete => true, :head => true, :options => true},
      :w => {:get => true, :put => true, :delete => true, :head => true, :options => true},
      :r => {:get => true, :head => true, :options => true},
      :p => {:get => true, :head => true, :options => true}
    }
    # Map HTTP methods for read-only access meaning "can only do GET"
    PERMISSIONS_RW_GET_ONLY =
      {
      :o => {:get => true, :put => true, :delete => true, :head => true, :options => true},
      :w => {:get => true, :head => true, :options => true},
      :r => {:get => true, :head => true, :options => true},
      :p => {:get => true, :head => true, :options => true}
    }
    # Map HTTP methods for "can only do GET" regardless of access level
    PERMISSIONS_ALL_READ_ONLY =
    {
      :o => {:get => true, :head => true, :options => true},
      :w => {:get => true, :head => true, :options => true},
      :r => {:get => true, :head => true, :options => true},
      :p => {:get => true, :head => true, :options => true}
    }

    QUERYABLE = false
    TEMPLATE_URI = nil
    NON_LIFTABLE_FORMATS = {:FWIG => true, :VWIG => true, :WIG => true, :VCF => true}
    RSRC_TYPE = 'rsrc'

    # CONSTRUCTOR.
    # Called by the framework; matches constructor interface of
    # <tt>{BRL::REST::Resource}[link:BRL/REST/Resource.html]</tt>. Subclasses almost never override this.
    # [+req+]           <tt>Rack::Request</tt> instance
    # [+resp+]          <tt>Rack::Request</tt> instance (can be modified/used as template)
    # [+uriMatchData+]  +MatchData+ object resulting from matching the URI against <tt>#pattern</tt>
    def initialize(req, resp, uriMatchData)
      super(req, resp, uriMatchData)
      # Hash keyed by @gbLogins seen and authenticated (including gbSuperuser) already during this request.
      # - Passed forward for internal requests (via @rackEnv) to avoid unnecessary re-auth.
      # - login => Hash with key user-state info, normally determined by initUserInfo().
      @rackEnv['genboree.authenticatedUserInfo'] = Hash.new { |hh,kk| hh[kk] = {} } unless(@rackEnv['genboree.authenticatedUserInfo'].is_a?(Hash))
      @debug = false
      @layout = nil
      @gbLogin, @reqURI, @rsrcURI, @rsrcQuery, @genbConf, @dbu, @apiError = nil
      @dbrc, @localHostName, @superuserApiDbrc, @superuserDbDbrc, @hostAuthMap = nil
      @reqHost = nil
      @internalApiCaller = nil
      @externalApiCallerHash = {}
      @repFormat = :JSON # default
      @nvPairs = {}
      @suppressEmail = false
      @statusName = @statusMsg = :OK
      @gbKeyVerified = false
      @isSuperuser = false
      @gbAudit = @isGbAuditor = false
      @gbSysAuth = false
      @fiber = false
      @gbEnvelope = true
    end

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call +super()+
    # so any parent cleanup() will be done also.
    #
    # [+returns+] +nil+
    def cleanup()
      super()
      @nvPairs.clear() if(@nvPairs and @nvPairs.respond_to?(:clear))
      @dbu.clearCaches() if(@dbu)
      @dbu = @nvParis = @genbConf = @reqURI = @rsrcURI = @rsrcQuery = @repFormat = nil
      @remoteAddr = @statusName = @statusMsg = @detailed = @connect = @debug = nil
      @gbLogin = @userId = @userEmail = @rsrcPath = @rsrcHost = @reqHost = nil
      @dbrc, @localHostName, @superuserApiDbrc, @superuserDbDbrc, @hostAuthMap = nil
      @groupAccessStr = @refSeqId = @apiError = nil
      @layout = nil
      @gbSysAuth = false
      @gbKeyVerified = @isSuperuser = @fiber = false
      # Aggressive cleanup for hostAuthMap:
      if(@hostAuthMap and !@hostAuthMap.empty? and @hostAuthMap.respond_to?(:each_key))
        # Clear tuple Array at each key
        @hostAuthMap.each_key { |host|
          tuple = @hostAuthMap[host]
          tuple.clear() if(tuple and tuple.is_a?(Array))
        }
        # Clear hostAuthMap itself
        @hostAuthMap.clear()
      end
    end

    # Initialize the processing of an HTTP operation on a Genboree resource.
    #
    # Typically, this should be the first call any subclass' <tt>#get</tt>,
    # <tt>#put</tt>, or <tt>#delete</tt> makes. Although in some cases, a helper
    # method that calls this _plus_ does some other common (and usualy category
    # specific) stuff is called.
    #
    # This method sets up some key instance variables and populates others from the HTTP request.
    # * It reads and makes available the Genboree config file.
    # * Based on the request, it populates <tt>#reqURI</tt>, <tt>#remoteAddr</tt>,
    #   <tt>#rsrcURI</tt>, <tt>#rsrcQuery</tt>, <tt>#rsrcHost</tt>, <tt>#repFormat</tt>,
    #   <tt>#connect</tt>, <tt>#detailed</tt>.
    # * It creates a <tt>BRL::Genboree::DBUtil</tt> instance which has an active connection
    #   to main Genboree database and which can be used to connect to Genboree user databases or other DBRC-available databases.
    #
    # [+returns+] HTTP response code name as symbol (:OK and :Accepted are success;
    #             most others indicate some kind of error)
    def initOperation()
      retVal = :OK
      # Get the acceptable time window from config file:
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      # Get some info about request, etc
      @reqURI = URI::parse(@req.url) # Get full incoming URI, including query string, etc

      @rsrcHost = @reqHost = @reqURI.host if(!@reqURI.nil?)
      @reqURI.query = '' if(@reqURI.query.nil?)
      @remoteAddr = @req.env['REMOTE_ADDR']
      @origReqScheme = @req.env['HTTP_X_FORWARDED_PROTO'].to_s.downcase

      # Did nginx leave the body in a file for us, stripping it out of actual request paylaod
      @xBodyFile = @req.env['HTTP_X_BODY_FILE'].to_s
      @xBodyFile = nil if(@xBodyFile.empty?)
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@req.env:\n\n#{@req.env.inspect}\n\n")

      # Parse url into component pieces
      url = @reqURI.to_s
      @rsrcURI = url.gsub(/&?gb(?:Token|Login|Time)=.+$/, '')
      @rsrcQuery = @reqURI.query.gsub(/&?gb(?:Token|Login|Time)=.+$/, '')
      uri = URI.parse(url)
      if(@combinedParams)
        @nvPairs = @combinedParams
      else
        @nvPairs = Rack::Utils.parse_query(uri.query)      # parse query string into NVPs
      end
      # Replace any '+' chars in the URL with '%20' because API resources use %20
      @rsrcPath = uri.path.gsub(/\+/, '%20')
      # Do we need to use a different @rsrcHost or leave it the same as @reqHost?
      useHost = @nvPairs['useHost']
      if(useHost and !useHost.empty?)
        @rsrcHost = useHost # use useHost parameter if available, otherwise use host used to make this API request
      end
      rFormat = @nvPairs['format']
      @repFormat = rFormat.to_s.upcase.to_sym if(!rFormat.nil? and rFormat =~ /\S/)
      respFormat = @nvPairs['responseFormat']
      @responseFormat = respFormat.to_s.upcase.to_sym unless(respFormat.nil?)
      @repType = @nvPairs['repType'].to_s.strip
      @repType = nil if(@repType.empty?)
      rDebug = @nvPairs['debug']
      @debug = true if(rDebug and rDebug.to_s =~ /^(?:true|yes)$/i)
      rConnect = @nvPairs['connect']
      @connect = true unless(rConnect and rConnect.to_s =~ /^(?:false|no)$/i)
      rDbIds = @nvPairs['dbIds'].to_s.strip
      @dbIds = false unless(rDbIds and rDbIds.to_s =~ /^(?:true|yes)$/i)
      rDetailed = @nvPairs['detailed']
      @detailed = rDetailed.nil? ? false : rDetailed.to_s.to_bool(false)
      @layout = @nvPairs['layout'] # May be nil (often)
      # Init DBRC info
      # - Official host name for local Genboree instance
      @localHostName = @genbConf.machineName
      # - local superuser API dbrc info (must have dbrc entry API:{localHostName})
      @superuserApiDbrc = @dbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf)
      # - local superuser DB dbrc info (must have dbrc entry DB:{localHostName})
      @superuserDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @genbConf.dbrcFile, :db)
      # Extract rsrcURI (everything without terminal &gb* NVPs)
      # Is it valid? This will also grab key gb* param info and setup some other key instance variables (@dbu, @genbConf, @repFormat param, etc)
      # - this will also fill in @hostAuthMap if we have a authenticated gbLogin (but not in the case of gbKey...)
      retVal = valid?()
      setGenericParams()
      return retVal
    end

    def setGenericParams()
      @gbSysAuth = isGbSysAuth() if(@nvPairs.key?('gbSysKey'))
      if(@nvPairs.key?('suppressEmail') and @nvPairs['suppressEmail'] =~ /^(?:yes|true)/i )
        @suppressEmail = true
      end
      if(@nvPairs.key?('gbEnvelope') and @nvPairs['gbEnvelope'] =~ /^(?:no|false)/i )
        @gbEnvelope = false
      end
    end

    # Process a HEAD operation.
    # [+returns+] <tt>Rack::Response</tt> instance
    def head()
      @statusName = initOperation()
      if(@statusName == :OK)
        @resp.status = HTTP_STATUS_NAMES[checkResource()]
        @resp.body = ""
        @resp['Content-Type'] = ''
      else
        @resp.status = HTTP_STATUS_NAMES[@statusName]
      end
      @resp['Content-Length'] = "0"
      return @resp
    end

    # [+returns+] boolean
    def isGbSysAuth()
      dbrc = BRL::DB::DBRC.new()
      retVal = false
      begin
        dbrcRec = dbrc.getRecordByHost(@genbConf.machineName, 'GBSYS')
        if(dbrcRec)
          pass = dbrcRec[:password]
          if(@nvPairs['gbSysKey'].strip == pass)
            retVal = true
          end
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", err)
      end
      return retVal
    end

    # Must be implemented by child resource. Used for a head request.
    # [+returns+] The <tt>#statusName</tt>.
    def checkResource()
      return :'Not Implemented'
    end

    # Configure a standard successful Genboree API response based on status
    # of serialization of entity instance, the request format parameter, and
    # the official HTTP response code name. Subclasses never override this.
    #
    # <em>NOTE: it is important that <tt>#statusName</tt> and <tt>#statusMsg</tt>
    # instance variables have been set to appropriate values before this method is called.</em>
    #
    # [+entity+]          Subclass of BRL::Genboree::REST::Data::AbstractEntity
    #                     to use in the response. It will be serialized according to its
    #                     BRL::Genboree::REST::Data::AbstractEntity#serialized method, and its
    #                     BRL::Genboree::REST::Data::AbstractEntity::contentTypeFor class
    #                     method will be used for the response content-type.
    # [+successCodeName+] HTTP response code name as a +Symbol+ to use for this successful response.
    # [+returns+]         The <tt>#statusName</tt>. Should be +successCodeName+ unless there
    #                     was a problem serializing the +entity+.
    def configResponse(entity, successCodeName=:OK)
      # Handle serialization with a layout if one was supplied (will be ignored
      # for all @repFormat types other than :LAYOUT).  If no layout was supplied,
      # and @repFormat is :LAYOUT, serialization will fail.
      respFormat = (@responseFormat.nil?) ? @repFormat : @responseFormat
      entity.doWrap = @gbEnvelope
      if(@layout)
        serializeStatus = entity.serialize(respFormat, @layout)
      else
        serializeStatus = entity.serialize(respFormat)
      end
      # Did we do some kind of serialization (even if expected serialization problem)
      if(serializeStatus and entity.serialized)
        # Is serialization OK or did something go wrong? If serialization went wrong, use the
        # serialization status as the HTTP response code. If it went ok, use the
        # successCodeName desired by the calling code as the HTTP response code.
        if(serializeStatus == :OK)
          @resp.status = HTTP_STATUS_NAMES[successCodeName]
        else
          @resp.status = HTTP_STATUS_NAMES[serializeStatus]
        end
        @resp['Content-Length'] = entity.serialized.size.to_s if(entity.serialized.respond_to?(:size))
        # Check responseFormat
        @resp['Content-Type'] = entity.class.contentTypeFor(respFormat)
        @resp.body = entity.serialized
      else # serialization error
        @resp.status = HTTP_STATUS_NAMES[:'Internal Server Error']
        @resp.body = "FATAL ERROR trying to serialize your data...could not prepare payload!"
        @resp['Content-Length'] = @resp.body.size
      end
      @statusName = successCodeName
      return @statusName
    end

    # HELPERS
    # Validate client token using info available to server. Try original request scheme first to
    #   avoid unnecessarily checking all schemes (since always get http from nginx, we don't know if user
    #   used http or https in their URL when making token...unless nginx accurately tells us).
    def checkToken(gbToken, pwordDigest, gbTime)
      # Check all possible tokens
      positionOfCharAfterHostname = @rsrcURI.index("/", "http://".length+1)  # in case of https we add 1
      positionOfCharAfterHostname = @rsrcURI.length if positionOfCharAfterHostname.nil?
      rsrcUriHostname = @rsrcURI[(@rsrcURI.index("/")+2)..(positionOfCharAfterHostname-1)]
      rsrcUriSuffix   = @rsrcURI[positionOfCharAfterHostname..-1]
      allowedHostnames = [ rsrcUriHostname ]
      if not @genbConf.gbAllowedHostnames.nil?
        if @genbConf.gbAllowedHostnames.kind_of?(Array)
          allowedHostnames += @genbConf.gbAllowedHostnames
        else
          allowedHostnames << @genbConf.gbAllowedHostnames
        end
        allowedHostnames.uniq!
      end          
      allowedHostnames.each { |hostname|
        ["http://", "https://"].each { |prefix|
          rsrcURI = prefix + hostname + rsrcUriSuffix
          serverToken = SHA1.hexdigest(rsrcURI + pwordDigest + gbTime.to_s)
          return true if(serverToken == gbToken)        # --> OK: everything ok. Get format and debug if possible
        }
      }
      return false
    end
    # Checks if the incoming request is valid and if the authentication information
    # provided is correct. Plus it sets up a number of useful instance variables.
    # - this will also fill in @hostAuthMap if we have a authenticated gbLogin (but not in the case of gbKey...
    #
    # Used by <tt>#initOperation</tt> to do most of the heavy lifting.
    #
    # If a problem with the request is encountered it will set <tt>#statusName</tt>
    # and <tt>#statusMsg</tt> to appropriate values so they can be returned in the response.
    #
    # [+returns+] <em>:OK</em> or an HTTP response code name as a +Symbol+ if something bad happened.
    def valid?()
      retVal = :OK
      loginAuthenticated = nil
      gbToken = @nvPairs['gbToken']
      @gbLogin = @nvPairs['gbLogin']
      # Need a dbu instance from here on.
      @dbu = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil, nil)
      # Try to get gbKey, if available from (a) request or (b) if publically available
      # - If user-specific login / token access doesn't work, we're going to try gbKey based access
      @gbKey = @nvPairs['gbKey'] or @nvPairs['context']
      unless(@gbKey and @gbKey.to_s =~ /\S/)
        # Maybe gbKey for this resource or one of its parents is public (i.e. "automatically discoverable")?
        @gbKey = BRL::Genboree::Abstract::Resources::UnlockedGroupResource.getAnyPublicKey(@dbu, @rsrcPath)
      end
      # Need both gbLogin and gbToken for authenticated access, else try via gbKey
      unless(@gbLogin.nil? or @gbLogin.empty? or gbToken.nil? or gbToken.empty? or gbToken.size != 40)
        # Have we already authenticated this user for this request?
        # - For example, maybe this is an INTERNAL request using SAME user info as ORIGINATING request
        #   (which has already been authenticated)
        # - For this to be the case, we need to have noted the login of the already-auth'd user and passed it forward
        #   into this subordinate internal API call (Rack provides us a nice way to do this)
        # $stderr.debugPuts(__FILE__, __method__, "DEBUG", "    @rackEnv[genboree.authenticatedUserInfo] prev auth'd users: #{@rackEnv['genboree.authenticatedUserInfo'].keys.sort.join(", ") rescue '<<!RESCUED!>>'} ; (curr @gbLogin: #{@gbLogin.inspect})")

        if(@rackEnv['genboree.authenticatedUserInfo'].key?(@gbLogin))
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "     ************ ALREADY AUTH'D #{@gbLogin.inspect} !!! (skipping re-auth) ***************" )
          gbAuthenticatedUserInfo = @rackEnv['genboree.authenticatedUserInfo'][@gbLogin]
          initUserInfo(gbAuthenticatedUserInfo[:userInfoHash])
          @statusName = @statusMsg = loginAuthenticated = :OK
        else
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "     ************ _NOT_ ALREADY AUTH'D #{@gbLogin.inspect} !!! (diff user for internal request, must redo auth!) ****************")
          # Is time within acceptable window...i.e. authToken still valid given time in url and time now?
          gbTime = @nvPairs['gbTime'] # b/c parsed with CGI.parse, each key points to an Array of values
          unless(gbTime.nil? or gbTime.empty?)
            gbTime = gbTime.to_i
            timeWindowSize = @genbConf.apiTimeWindow.to_i
            serverTime = Time.now.to_i
            timeOk = ((serverTime - gbTime).abs <= timeWindowSize)
            if(timeOk)
              initUserInfoStatus = initUserInfo()
              if(initUserInfoStatus == :OK)
                # Have we seen this token before? Check the replay cache table restAuthTokens,
                # It's ok if token is reused we'll increment reqCount to record number of requests
                # Insert or update on duplicate token
                @dbu.insertOrUpdateRestAuthRec(gbToken, gbTime, @userId, @remoteAddr, @reqMethod, @rsrcPath, 1)
                pwordDigest = SHA1.hexdigest(@gbLogin + @pword)

                # Check token. Will try @origReqScheme first if available from nginx proxy.
                tokenOK = checkToken(gbToken, pwordDigest, gbTime)
                if(tokenOK)
                  @statusName = @statusMsg = loginAuthenticated = :OK
                  existingUserInfoHash = makeUserInfoHash()
                  @rackEnv['genboree.authenticatedUserInfo'][@gbLogin] = { :hostAuthMapObjId => @hostAuthMap.object_id, :userInfoHash => existingUserInfoHash }
                else # bad token
                  BRL::Genboree::GenboreeUtil.logError( "BAD TOKEN:" +
                                                        "\n  req method: #{@reqMethod.inspect}" +
                                                        "\n  req uri: #{@req.url.inspect}" +
                                                        "\n  req params: #{@nvPairs.inspect}" +
                                                        "\n  http rsrc uri: #{@rsrcURI.inspect}" +
                                                        "\n  rsrc params: #{@rsrcQuery.inspect}" +
                                                        "\n  rep format: #{@repFormat.inspect}" +
                                                        "\n  client token: #{gbToken}" +
                                                        "\n  pwordDigest: #{pwordDigest}" +
                                                        "\n  gbTime: #{gbTime.to_s}",
                                                        nil)
                  @statusName = :'Bad Request'
                  @statusMsg =  "BAD_TOKEN: The gbToken provided is not correct for: this URL, the timestamp, the indicated user, and user's password info stored on the server. " +
                                "It is also possible the URL components are not escaped properly or some other construction error. Refer to documentation." +
                                "\n  Req Method: #{@reqMethod.inspect}" +
                                "\n  Req URI: #{@req.url.inspect}" +
                                "\n  Req Params: #{@nvParis.inspect}" +
                                "\n  Rsrc URI: #{@rsrcURI.inspect}" +
                                "\n  Rsrc Params: #{@rsrcQuery.inspect}" +
                                "\n  Rep Format: #{@repFormat.inspect}"
                end
              end
            else # Time window for this token is expired
              @statusName = :'Bad Request'
              @statusMsg = "EXPIRED: The time window for the token has expired. Is your system clock approximately correct? Or did you compose the URL many hours ago?"
            end
          else # No gbTime value??
            @statusName = :'Bad Request'
            @statusMsg = "BAD_API_URL: The POSIX time (gbTime) is missing from the URL."
          end
        end
      else
        # noop
        # no login info provided ; access must be some other way or denied
      end
      # If things are OK so far (login authenticated ok, or doing some other kind of access), then
      # examine gbKey situation (in case login doesn't have access themselves, but they have the gbKey)
      if(@statusName == :OK)
        # Could be try to access a resource using a GBKEY. Even if they gave login info, we'll
        # use this to see if they can have access even if their login does not. If no login at all, then
        # it's either gbKey access or public resource or reject.
        if(@gbKey and @gbKey =~ /\S/)
          # Check resource has GBKEY.
          # Is the gbKey provided (or found) going to work to access @rsrcPath?
          gbKeyAccessStatus = ( BRL::Genboree::Abstract::Resources::UnlockedGroupResource.hasAccessViaKey(@dbu, @rsrcPath, @gbKey) ? :OK : :'Bad Request' )
          if(gbKeyAccessStatus == :OK)  # Key provided and matches resource
            unless(loginAuthenticated)  # If not a regular user login (gbKey only for example) then force this to a read-only type access
              # some instance vars that are required by resources
              @groupAccessStr = 'r' # default access should be read
              @userId = 0           # default user id
              #$stderr.debugPuts(__FILE__, __method__, "AUTH", "A valid gbKey was provided.")
            else
              # noop # loginAuthenticated, so use that
              #$stderr.debugPuts(__FILE__, __method__, "AUTH", "Have both a valid user credentials and a valid gbKey (to fall back on if user doesn't have access themselves).")
            end
            @gbKeyVerified = true
            @statusMsg = @statusName = :OK
          elsif(gbKeyAccessStatus == :'Bad Request') # bad gbKey; either the login better have access or the resource better be public
            @gbKeyVerified = false
            @statusMsg = @statusName = :OK
            unless(loginAuthenticated)
              # some instance vars that are required by resources
              @groupAccessStr = 'p' # default access should be read
              @userId = 0           # default user id
              #$stderr.debugPuts(__FILE__, __method__, "AUTH", "The gbkey is invalid for the resource and no user credentials provided. Try Public-resource mode as last resort.")
            end
          else # probably :Unauthorized or something (gbKey wrong or not allowed for method)
            unless(loginAuthenticated) # If have real login, we'll be relying on that; if not, cannot give access.
              @statusName = gbKeyAccessStatus
              @statusMsg = "UNAUTHORIZED: The resource is private and you did not provide appropriate access information."
            end
          end
        else # no gbKey info to worry about (provided or discovered) ; just ensure loginAuthenticated is good
          if(loginAuthenticated)
            @statusName = @statusMsg = loginAuthenticated
          else
            # Noop
            # @statusName stays :OK !
            # - Seems odd, but necessary to allow access to explicitly public resources
            # - i.e. resources like database and tracks that can be public themselves (no gbKey stuff)
            # - So the access control here is looking for:
            #  (a) reasons to reject the access outright
            #  (b) valid login-based access
          end
        end
      end
      return @statusName
    end # def valid?()

    # Prepares a 'Not Implemented' HTTP response, with an informative and Genboree-API
    # compliant response body. Can be used as the entire HTTP method handler or can be
    # called once some processing has be done, but it turns out what is being asked for
    # is not [yet] implemented.
    #
    # Sets the <tt>#statusName</tt> and <tt>#statusMsg</tt> if needed, sets up the 'Allow' HTTP response header,
    # sets the Content-Length and Content-Type headers, and sets the appropirate response status number.
    # Calls <tt>#representError</tt> to do much of this.
    #
    # [+returns+] The HTTP response object (<tt>Rack::Response</tt> instance) it configured (same object as <tt>#resp</tt>)
    def notImplemented()
      initStatus = (@gbLogin ? :OK : self.initOperation()) # init only if not init'd yet...if it is, process according to whether implemented or what methods missing using OK
      unless(initStatus == :OK)
        @statusName = initStatus
        @resp = representError()
      else  # --> Even if OK, this abstract class doesn't implement anything...UNimplemented/Method Missing error!
        methods = self.class::HTTP_METHODS.keys
        if(methods.empty?)
          @statusName = :'Not Implemented'
        else
          @statusName = :'Method Not Allowed'
          allow = ''
          methods.each_index { |ii|
            allow << "#{methods[ii].to_s.upcase}"
            allow << ", " unless(ii >= (methods.size - 1))
          }
          @resp['Allow'] = allow
        end
        @statusMsg = "#{@statusName.to_s.upcase.gsub(/ /, '_')}: The '#{@reqMethod.to_s.upcase}' operation is not implemented for the #{@rsrcURI.inspect} resource."
        @resp = representError()
      end
      return @resp
    end

    # This method is a specialized version of the called when processing requests that
    # require responses in a specialized foride Entity Types in the Request
    # body encoded in a different (typically JSON) format.  This method functions by
    # following a try-fail-repeat paradigm and therefore will result in worse
    # performance than the standard parseRequestBodyForEntity() method and thus should
    # only be used in the special cases mentioned.
    #
    # [+entityTypes+]   AbstractEntity subclasses, can be a single Entity or an Array of Entities
    # [+returns+]       entity - subclass of an AbstractEntity Object or :'Unsupported Media Type'
    def parseRequestBodyAllFormats(entityTypes, format=nil)
      entityTypes = entityTypes.to_a unless(entityTypes.is_a?(Array))
      reqBody = self.readAllReqBody()
      begin
        entity = self.class.parseRequestBodyAllFormats(entityTypes, reqBody, format)
      rescue Exception => err
        @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "There was an error parsing the request body using all formats, please check the entity type.", err, true)
        entity = :'Unsupported Media Type'
      end
      return entity
    end

    # This method is a specialized version of the called when processing requests that
    # require responses in a specialized foride Entity Types in the Request
    # body encoded in a different (typically JSON) format.  This method functions by
    # following a try-fail-repeat paradigm and therefore will result in worse
    # performance than the standard parseRequestBodyForEntity() method and thus should
    # only be used in the special cases mentioned.
    #
    # [+entityTypes+]   AbstractEntity subclasses, can be a single Entity or an Array of Entities
    # [+returns+]       entity - subclass of an AbstractEntity Object or :'Unsupported Media Type'
    def self.parseRequestBodyAllFormats(entityTypes, reqBody, format=nil)
      entity = nil
      formats = (format.is_a?(Array) ? format : [ format ]) # Want as Array since really it is a list of POSSIBLE formats to consider
      if(!reqBody.empty?)
        entityTypes.each { |entityType|
          # Get class for entityType:
          entityClass = BRL::Genboree::REST::Data.const_get(entityType)
          # What are formats to consider (should just be one given or all formats for that class)
          possibleFormats = (format ? formats : entityClass::FORMATS)
          possibleFormats.each { |currFormat|
            next if(format and format != currFormat) # if known format, skip the other various formats
            begin
              entity = BRL::Genboree::REST::Data.const_get(entityType).deserialize(reqBody, currFormat)
              raise "entity is nil", caller if(entity.nil?)
            rescue Exception => err
              BRL::Genboree::GenboreeUtil.logError("Error in self.parseRequestBodyAllFormats():", err)
              entity = :'Unsupported Media Type'
            end
            break unless(entity == :'Unsupported Media Type')
          }
          break unless(entity == :'Unsupported Media Type')
        }
      end
      return entity
    end

    # Genoboree Resources sometimes accept different Entity Types in the Request body.
    # This method uses the list of different Entity types that a resource accepts and returns
    # the Entity object that matches
    #
    # @param [Array] entityTypes AbstractEntity subclasses, can be a single Entity or an Array of Entities. Only the FIRST one to match (work) will be used, so put the most specific ones first, else ones that are compatible subsets will match more specific/detailed payloads.
    # @param [Hash] opts Options hash with entity specific options
    # @return [Object] entity subclass of an AbstractEntity Object or :'Unsupported Media Type' or @nil@ if the request body/payload is empty
    def parseRequestBodyForEntity(entityTypes, opts={})
      $stderr.debugPuts(__FILE__, __method__, "TIME", "BEGIN - #{__method__}")
      entityTypes = entityTypes.to_a unless(entityTypes.is_a?(Array))
      reqBody = self.readAllReqBody()
      $stderr.debugPuts(__FILE__, __method__, "TIME", "after readAllReqBody; @allBodySize=#{@allBodySize}")
      entity = nil
      begin
        if(!reqBody.empty?)
          entityTypes.each { |entityType|
            $stderr.debugPuts(__FILE__, __method__, "TIME", "before #{entityType.to_s} deserialize")
            entity = BRL::Genboree::REST::Data.const_get(entityType).deserialize(reqBody, @repFormat, true, opts) # We can handle a BRL::Genboree::GenboreeError as a return type, so 3rd param true.
            $stderr.debugPuts(__FILE__, __method__, "TIME", "after #{entityType.to_s} deserialize")
            break unless(entity == :'Unsupported Media Type' or entity.is_a?(BRL::Genboree::GenboreeError))
          }
        end
      rescue Exception => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          entity = @apiError = err
        else
          entity = @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "There was an error parsing the request body, please check the format and entity type. (#{err.class}: #{err.message}) ", err, true)
        end
      end
      # At this point either parsing worked for one of the entity types or it failed for all or nasty exception was raised.
      # Caller is expecting an actual entity or :'Unsupported Media Type'. Save any BRL::Genboree::GenboreeError that fell through
      # the entityTypes.each loop in case the caller wants to examine it for more detail.
      if(entity.is_a?(BRL::Genboree::GenboreeError))
        @apiError = entity
        entity = :'Unsupported Media Type'
      end
      return entity
    end

    # Prepare @statusName and @statusMsg based on the error class: BRL::Genboree::GenboreeError
    #   instances are anticipated and do not need to be logged. Other error classes should be
    #   logged and the user should not recieve information about our server internals
    #   (ruby, stacktrace, etc.)
    # @param [Exception] err the error to log and prepare response for
    # @return [NilClass]
    def logAndPrepareError(err)
     if(err.is_a?(BRL::Genboree::GenboreeError))
        @statusName = err.type
        @statusMsg = err.message
      else
        $stderr.debugPuts(__FILE__, __method__, "API_ERROR", "#{err.message}\n#{err.backtrace.join("\n")}\n")
        @statusName = :"Internal Server Error"
        adminStr = ((@genbConf.is_a?(BRL::Genboree::GenboreeConfig) and @genbConf.send(:gbAdminEmail)) ? ": please contact the administrator at #{@genbConf.send(:gbAdminEmail)}." : "") rescue ""
        @statusMsg = "ERROR: Unhandled exception" << adminStr
      end
      @apiError = BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
      return nil
    end

    # Sets up an HTTP error type response by configuring <tt>#resp</tt> (a <tt>Rack::Response</tt> object)
    # appropriately, based on <tt>#statusName</tt>, <tt>#statusMsg</tt>, and <tt>#repFormat</tt>.
    #
    # [+returns+] The configured HTTP response object (<tt>Rack::Response</tt> instance); same one as <tt>#resp</tt>
    def representError()
      # Added this to catch unknown @statusName
      if(!HTTP_STATUS_NAMES.key?(@statusName))
        @statusMsg = "UNKNOWN ERROR: statusName => '#{@statusName.inspect}' being seen by GenboreeResource::representError. Will report as Internal Server Error."
        if(@apiError)
          @statusMsg << "Internal apiError details:\n  type: #{@apiError.type}\n  message: #{@apiError.message}\n  backtrace:\n  #{@apiError.backtrace.join("\n")}"
        else
          @statusMsg << "Internal apiError is nil."
        end
        @statusName = :'Internal Server Error'
      end
      body = BRL::Genboree::REST::Data::AbstractEntity.representError(@repFormat, @statusName, @statusMsg)
      @resp.status = HTTP_STATUS_NAMES[@statusName]
      @resp['Content-Length'] = body.size.to_s
      @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity.contentTypeFor(@repFormat)
      @resp.body = body
      return @resp
    end

    # INTERFACE: process an operation on this resource
    # Log request information in a database table
    # [+returns+] <tt>Rack::Request</tt> instance
    def process()
      # setup apiRecord for initial insert
      # @todo can we restructure to not intialize these once here and once in initOperation->valid? ?
      #   may also remove need for rsrcType (cant see which rsrcPath being processed until it is finished
      #   which is bad for getting information about currently running processes and those that time out)
      genbConf = BRL::Genboree::GenboreeConfig.load()
      dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)

      # parts from parent initialize
      uriObj = URI.parse(@req.url)
      query = Rack::Utils.parse_query(uriObj.query)
      userName = nil
      if(query.key?("gbKey"))
        userName = "gbKey"
      elsif(!query.key?("gbLogin"))
        userName = "public"
      else
        userName = query["gbLogin"]
      end
      # APIRECORD SMEAR: Don't insert apiRecord calls for INTERNAL "api" calls
      # * In fact, we'll try to skip as much of the apiRecord-related stuff as we can,
      #   although it's kind of smeared throughout this method.
      unless(@rackEnv['genboree.internalReq'])
        # fill in record parts we have access to before initOperation
        apiRecord = BRL::Genboree::DB::Tables::API::newApiRecordHash()
        apiRecord["reqStartTime"] = Time.now
        apiRecord["memUsageStart"] = (BRL::Util::MemoryInfo::getMemUsagekB / 1024).to_i
        apiRecord["machineName"] = genbConf.machineName
        apiRecord["rsrcType"] = self.class::RSRC_TYPE

        apiRecord["userName"] = userName
        apiRecord["method"] = @reqMethod
        apiRecord["clientIp"] = @rackEnv["HTTP_X_REAL_IP"]
        matchData = /thin\.(\d+)\.log/.match(@rackEnv["rack.errors"].path) rescue nil
        apiRecord["thinNum"] = matchData.nil? ? nil : matchData[1].to_i
        apiRecord["byteRange"] = @rackEnv["HTTP_RANGE"]
        apiRecord["userAgent"] = @rackEnv["HTTP_USER_AGENT"]
        apiRecord["referer"] = @rackEnv["HTTP_REFERER"]
        insertId = dbu.insertApiRecord(apiRecord)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Initial insert apiRecordId #{insertId}")
      end # unless(@rackEnv['genboree.internalReq'])
      begin
        @resp = super()  # Call an instance method matching the reqMethod
      rescue => err
        logAndPrepareError(err)
      end
      if(@apiError.is_a?(BRL::Genboree::GenboreeError))
        @statusName = @apiError.type
        @statusMsg = @apiError.message
        @resp = representError()
      elsif(!@apiError.nil?)
        # @apiError should be a BRL::Genboree::GenboreeError but if it isn't
        # Let it be known that there was still an error.
        @statusMsg = "UNKNOWN ERROR: apiError => #{@apiError.inspect}, statusName => #{@statusName.inspect}, statusMsg => #{@statusMsg.inspect}"
        @statusName = :'Internal Server Error'
        @resp = representError()
      end
      # APIRECORD SMEAR: Don't insert apiRecord calls for INTERNAL "api" calls
      # * In fact, we'll try to skip as much of the apiRecord-related stuff as we can,
      #   although it's kind of smeared throughout this method.
      unless(@rackEnv['genboree.internalReq'])
      # fill in parts after initOperation
        apiRecord["rsrcPath"] = @rsrcPath
        apiRecord["queryString"] = @rsrcQuery

        # fill in parts from request
        if(@resp.body.respond_to?(:size))
          apiRecord["contentLength"] = (@resp.body.size.to_i / 1024 ) # in KiB
        end
        apiRecord["respCode"] = @resp.status

        # fill in final processing info
        apiRecord["memUsageEnd"] = (BRL::Util::MemoryInfo::getMemUsagekB / 1024).to_i
        apiRecord["reqEndTime"] = Time.now
        nUpdated = dbu.updateApiRecord(insertId, apiRecord)

        # setup deferrable to fill in content length when it is done (streammer stuff is obsolete
        #   and body.callback shows poorer planning/design)
        if(@resp.body.is_a?(BRL::Genboree::REST::EM::DeferrableBodies::AbstractDeferrableBody))
          @resp.body.addListener(:finish, Proc.new { |event, body|
            rs = dbu.updateApiRecord(insertId, {"contentLength" => body.totalBytesSent / 1024} )
          })
        elsif(@resp.body.is_a?(BRL::Genboree::Abstract::Resources::AbstractStreamer) and !insertId.nil?)
          @resp.body.callback = apiRecordProc(@dbu, insertId)
        elsif(@resp.body.is_a?(BRL::Genboree::Abstract::Resources::StreamerDelegator) and !insertId.nil?)
          @resp.body.callback = apiRecordProc(@dbu, insertId)
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Final insert apiRecordId #{insertId}")
      end # unless(@rackEnv['genboree.internalReq'])

      return @resp
    end

    # Prepare a callback function for the apiRecord once a streaming request is finished
    # @param [BRL::DB::DBUtil] dbu a database method handle with an open connection
    # @param [Integer] id the apiRecord id field value whose contentLength should be updated
    # @return [Proc] a callback function with suitable enclosure for the streamer classes
    # @see process
    # @todo hopefully can remove this odd approach for simpler addListener one when supplant AbstractStreamer.
    def apiRecordProc(dbu, id)
      method = :updateApiRecord
      Proc.new { |size|
        args = [id, {"contentLength" => size / 1024}]
        dbu.send(method, *args)
      }
    end

    # Read all of an HTTP request body into a +String+ object. Works if
    # framework has it as a +StringIO+ or a +File+ due to size. Be careful using this,
    # if the body was buffered to disk due to size, should you really be reading it all
    # into memory?? Use responsibly.
    # [+return+]  The whole of the request body, as a +String+.
    def readAllReqBody()
      retVal = ''
      unless(@req.body.nil?)
        # Ensure we're reading from the very beginning
        @req.body.rewind() if(@req.body.respond_to?(:rewind))
        retVal = @req.body.read() # It is required that @req.body responds to "read" (and each, gets) and not be closed. This is the SPEC for rack.input
        retVal.strip!
      end
      @allBodySize = retVal.size
      return retVal
    end

    def estimateBodySize()
      retVal = nil
      if(@req.body)
        if(@req.body.respond_to?(:size))
          retVal = @req.body.size
        elsif(@req.body.lstat)
          retVal = @req.body.lstat.size
        end
      end
      return retVal
    end

    def makeUserInfoHash()
      retVal = {}
      retVal[:groupAccessStr] = @groupAccessStr
      retVal[:userId] = @userId
      retVal[:userEmail] = @userEmail
      retVal[:pword] = @pword
      retVal[:hostAuthMap] = @hostAuthMap
      retVal[:gbAudit] = @gbAudit
      retVal[:isGbAuditor] = @isGbAuditor
      retVal[:isSuperuser] = @isSuperuser
      return retVal
    end

    def initUserInfo(existingUserInfoHash=nil)
      @statusName = :OK
      @gbLogin = @nvPairs['gbLogin']
      # If we have this info at our fingertips, we'll use it rather than figuring it out and making requests.
      #  - if we already have everything we need for this user, probably is internal call or something
      if(existingUserInfoHash)
        @groupAccessStr = existingUserInfoHash[:groupAccessStr]
        @userId = existingUserInfoHash[:userId]
        @userEmail = existingUserInfoHash[:userEmail]
        @pword = existingUserInfoHash[:pword]
        @hostAuthMap = existingUserInfoHash[:hostAuthMap]
        @gbAudit = existingUserInfoHash[:gbAudit]
        @isGbAuditor = existingUserInfoHash[:isGbAuditor]
        @isSuperuser = existingUserInfoHash[:isSuperuser]
      else # Must check user carefully in full and set up proper user context
        unless(@gbLogin.nil? or @gbLogin.empty?)
          @gbLogin.strip!
          if(@gbLogin =~ /^Public$/i)  # Process access as Public user
            @groupAccessStr = 'p' # public access
            @userId = 0
            @userEmail = nil
            @pword = ''
          else                      # Process access as a "regular" user
            # This "regular" user can be a Genboree user from the database,
            # OR Genboree itself via the configured superuser. The superuser
            # is authenticated differently to allow it to manipulate Genboree
            # independently of there being an actual Genboree login account for the
            # superuser (really one should NOT be needed, nor is it a good idea).
            #
            # Are we the superuser?
            if(@gbLogin == @superuserApiDbrc.user) # Yes, superuser is doing API stuff
              # Check authentication info against entry in .dbrc file
              #
              # 1. Superuser config info
              @userId = @genbConf.gbSuperuserId.to_i
              @userEmail = @genbConf.gbSuperuserEmail
              # 2. Get password from dbrc record (will be used to verify token sent via API)
              @pword = @superuserApiDbrc.password
              # 3. Setup @hostAuthMap (just the 1 record for the local Genboree instance)
              @hostAuthMap = { self.class.canonicalAddress(@localHostName) => [ @superuserApiDbrc.user, @superuserApiDbrc.password, :internal ] }
              @isSuperuser = true
            else                          # No, it's a regular Genboree user
              # Get users matching this username
              users = @dbu.getUserByName(@gbLogin) # should connect to main database now
              unless(users.nil? or users.empty?)
                # 1. Not superuser
                @isSuperuser = false
                # 2. Set official password/user info and such. Will be checked against what is provided in request.
                @userId = users.first['userId']
                @userEmail = users.first['email']
                @pword = users.first["password"] # TODO: This should be cleared from mem once passwords are stored as SHA1 digests of <user><pass>
                # 3. Set up @hostAuthMap
                @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
              else # no such user?
                @statusName = :'Not Found'
                @statusMsg = "NO_USR: The username (gbLogin) provided doesn't exist (or perhaps is encoded incorrectly?)"
              end
            end
          end
          # Is this user a Genboree Auditor and requesting an audit? If so, they have wider access (read-only) in certain areas.
          @gbAudit = @nvPairs['gbAudit']
          @gbAudit = ((!@gbAudit.nil? and (@gbAudit.to_s =~ /^\s*(?:true|yes)\s*/i)) ? true : false)
          if(@gbAudit)  # requesting an audit; is user an auditor?
            @isGbAuditor = Abstraction::User.gbAuditor?(@dbu, @userId)
            if(@isGbAuditor)
              @groupAccessStr = 'r'
            else  # Not an auditor; nullify audit request and proceed as normal user.
              @gbAudit = false
            end
          end
        else # No gbLogin provided?
          @statusName = :'Bad Request'
          @statusMsg = "BAD_API_URL: The username (gbLogin) is missing from the URL."
        end # unless(@gbLogin.nil? or @gbLogin.empty?)
      end # if(existingUserInfoHash)
      return @statusName
    end

    # [+accessMap+] Hash-of-Hashes, typically one of the pre-defined PERMISSIONS_* ones in the constants at
    #               the top of this file, which maps groupAccessStr as Symbols (:r, :w, :o) to request methods
    #               as Symbols (:get, :put, :delete, :head, :options, (etc/whatever)) to true|false values. This
    #               map will be used to return true or false depending on the current request's values for
    #               @groupAccessStr and @reqMthod.
    def accessAllowed?(accessMap)
      # If accessMap is nil then we're going to skip the
      # checking and allow it through, relying on usual group/database/track enforcement or whatever.
      retVal = true
      if(accessMap.is_a?(Hash))
        # We have the ACCESS_BY_ROLE. If not present, then not allowed.
        retVal = false
        groupAccessSym = @groupAccessStr.to_sym
        methodMap = accessMap[groupAccessSym]
        if(methodMap.is_a?(Hash) and methodMap[@reqMethod])
          retVal = true
        end
      end
      return retVal
    end

    # ------------------------------------------------------------------
    # CLASS METHODS
    # ------------------------------------------------------------------
    # Helper method to determine whether a resource
    # is queryable.  Will return QUERYABLE from the class
    # calling the method.
    def self.queryable?()
      rsrc = getBuilderConstant()
      if(rsrc)
        return rsrc::QUERYABLE
      else
        return false
      end
    end

    # Helper method to get the proper response format
    # when applying a query.
    # [+path+] File path for dealing with Database File calls.  Not used for anything else.
    # [+returns+] The resource's response format
    def self.getRespFormat(path=nil)
      rsrc = getBuilderConstant()
      return rsrc::RESPONSE_FORMAT
    end

    # Helper method to provide an example URI for requesting
    # a resource through the API.
    def self.templateURI()
      retVal = (self::TEMPLATE_URI.nil?)? nil : self::TEMPLATE_URI
      return retVal
    end

    # Helper method to instantiate a constant representing the analogous Builder
    # class to the Resource calling the method; used as a means of accessing
    # Builder Class constants.  This needs to be done with some string manipulation
    # in order to properly create constant.  Also, since the Builders are set up to be 'discoverable'
    # earlier in this class, this method can potentially be called by a class that does
    # not have an analogous builder, so we need to check the array of constants
    # in the Builder module to ensure it exists first.
    def self.getBuilderConstant()
      rsrcName = self.to_s.split("::").pop
      builderName = "#{rsrcName}Builder"
      builders = BRL::Genboree::REST::Data::Builders.constants
      if(builders.include?(builderName))
        rsrc = BRL::Genboree::REST::Data::Builders.const_get(builderName.to_sym)
        retVal = rsrc
      else
        # A Builder doesn't exist for the resource in question,
        # queryable needs to return nil by default
        retVal = nil
      end

      return retVal
    end

    # Helper method to provide DISPLAY_NAMES constant stored in a resources builder
    # through the API.
    # [+dbu+] Usable instance of dbUtil. For getting attribute names when
    #         group and database have been initialized.
    # [+fileName+] Used only for calls to DatabaseFile resource
    # [+returns+] An array of hashes
    def self.getAllAttributesWithDisplayNames(dbu=nil, fileName=nil)
      builder = getBuilderConstant()
      if(builder)
        retVal = builder::DISPLAY_NAMES.dup
        unless(dbu.nil?)
          rows = dbu.selectAll(:userDB, builder::AVP_TABLES['names'], 'ERROR:GenboreeResource.getAllAttributesWithDisplayNames()')
          unless(rows.nil? or rows.empty?)
            rows.each{|row|
              attrName = row['name']
              retVal << { attrName => attrName }
            }
          end
        end
      else
        retVal = nil
      end

      return retVal
    end
  end # class GenboreeResource
end ; end ; end # module BRL ; module REST ; module Resources
