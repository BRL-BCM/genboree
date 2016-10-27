require 'cgi'
require 'brl/genboree/rest/helpers/apiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'

module BRL ; module Genboree ; module REST ; module Helpers
  class DatabaseApiUriHelper < ApiUriHelper
    # Each resource specific API Uri Helper subclass should redefine this:
    NAME_EXTRACTOR_REGEXP = %r{^(?:http://[^/]+)/REST/v\d+/grp/[^/]+/db/([^/\?]+)}
    EXTRACT_SELF_URI = %r{^(.+?/db/[^/\?]+)}     # To get just this resource's portion of the URL, with any suffix stripped off
    ID_COLUMN_NAME = 'refSeqId'

    attr_accessor :grpApiUriHelper

    def initialize(dbu=nil, genbConf=nil, reusableComponents={})
      @grpApiUriHelper = nil
      super(dbu, genbConf, reusableComponents)
    end

    def init(dbu=nil, genbConf=nil, reusableComponents={})
      super(dbu, genbConf, reusableComponents)
      @grpApiUriHelper = GroupApiUriHelper.new(dbu, genbConf, reusableComponents) unless(@grpApiUriHelper)
    end

    # INTERFACE. Subclasses must override this to look for resuable bits.
    def extractReusableComponents(reusableComponents={})
      super(reusableComponents)
      reusableComponents.each_key { |compType|
        case compType
        when :grpApiUriHelper
          @grpApiUriHelper = reusableComponents[compType]
        end
      }
    end

    # ALWAYS call clear() when done. Else memory leaks due to possible
    # cyclic references.
    def clear()
      super()
      @grpApiUriHelper.clear() if(@grpApiUriHelper)
      @grpApiUriHelper = nil
    end

    # Get database version
    # To protect the legacy code, hostAuthMap defaults to nil. If provided, an API call will be made to get the versions
    def dbVersion(uri, hostAuthMap=nil)
      version = nil
      if(uri)
        # First, try from cache
        version = getCacheEntry(uri, :dbVersion)
        if(version.nil?)
          # If not cached, try to retrieve it
          #
          # Get refseq table row if hostAuthMap nil (protect legacy code)
          unless(hostAuthMap)
            row = tableRow(uri)
            if(row and !row.empty?)
              version = row['refseq_version']
              setCacheEntry(uri, :dbVersion, version)
            end
          else # Could be an external machine, make an API call
            dbUri = URI.parse(extractPureUri(uri))
            dbName = extractName(uri)
            apiCaller = BRL::Genboree::REST::ApiCaller.new(dbUri.host, "#{dbUri.path}/version?", hostAuthMap)
            apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
            begin
              apiCaller.get()
              resp = JSON.parse(apiCaller.respBody())
              version = resp['data']['text']
              setCacheEntry(uri, :dbVersion, version)
            rescue => err
              $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not get db version for hostAuthMap: #{hostAuthMap.inspect} at Genboree host #{dbUri.host.inspect} for db: #{dbName.inspect}. Received a #{apiCaller.httpResponse.class}")
            end
          end
        end
      end
      return version
    end

    # Is db's version equal to version?
    def dbVersionEquals?(uri, versionStr)
      retVal = false
      if(uri and versionStr)
        dbVer = dbVersion(uri)
        if(dbVer)
          dbVer = dbVer.downcase
          retVal = (dbVer == versionStr.downcase)
        end
      end
      return retVal
    end

    # Are any of the genome version strings empty?
    def anyDbVersionsEmpty?(uris)
      retVal = false
      if(uris)
        uris.each { |uri|
          dbVer = dbVersion(uri)
          if(dbVer.nil? or dbVer.strip.empty?)
            retVal = true
            break
          end
        }
      end
      return retVal
    end

    # Do ALL db versions match?
    def dbsVersionsMatch?(uris, emptyMatchesAny=true, hostAuthMap=nil)
      retVal = false
      if(uris)
        if(uris.size == 1)
          retVal = true
        else
          lastVersion = nil
          uris.each { |uri|
            unless(uri.nil?)
              dbVer = dbVersion(uri, hostAuthMap)
              dbVer = dbVer.to_s.strip.downcase
              if(lastVersion.nil? or (dbVer.empty? and emptyMatchesAny) or (lastVersion.empty? and emptyMatchesAny))
                retVal = true
              else
                if(dbVer != lastVersion)
                  retVal = false
                  break
                else
                  retVal = true
                end
              end
              lastVersion = dbVer
            else
              retVal = false
              break
            end
          }
        end
      end
      return retVal
    end

    # Do user have access to db?
    def accessibleByUser?(uri, userId, accessCodes)
      return @grpApiUriHelper.accessibleByUser?(uri, userId, accessCodes)
    end

    # Does user have access to ALL dbs?
    def allAccessibleByUser?(uris, userId, accessCodes)
      return @grpApiUriHelper.allAccessibleByUser?(uris, userId, accessCodes)
    end

    def getUrlFromRefSeqId(refSeqId)
      groupAndRefseqNames = @dbu.selectGroupAndRefSeqNameByRefSeqId(refSeqId)
      grpName = groupAndRefseqNames.first['groupName']
      dbName = groupAndRefseqNames.first['refseqName']
      return "http://#{@genbConf.machineName}/REST/v1/grp/#{CGI.escape(grpName)}/db/#{CGI.escape(dbName)}?"
    end

    # Get entrypoints from database
    # - hostAuthMap required to do query on behalf of user to whatever genboree host
    # - NOT CACHED, due to possible huge memory requirements. Always dynamic API call.
    # Returns a Hash of chrName => chrLength
    def getEntrypoints(uri, hostAuthMap)
      frefHash = {}
      if(uri)
        dbUri = URI.parse(extractPureUri(uri))
        dbName = extractName(uri)
        apiCaller = BRL::Genboree::REST::ApiCaller.new(dbUri.host, "#{dbUri.path}/eps?connect=no", hostAuthMap)
        apiCaller.initInternalRequest(@rackEnv, @genbConf.machineNameAlias) if(@rackEnv)
        begin
          hr = apiCaller.get()
          raise unless(apiCaller.succeeded?)
          apiCaller.parseRespBody()
          apiCaller.apiDataObj['entrypoints'].each { |epRec|
            frefHash[epRec['name']] = epRec['length']
          }
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not get db entrypoints from Genboree host #{dbUri.host.inspect} for db: #{dbName.inspect}.")
        end
      end
      return frefHash
    end

    # ------------------------------------------------------------------
    # Feedback helpers
    # ------------------------------------------------------------------
    # Get dbName => dbVersion hash
    def dbVersionsHash(uris)
      versionsHash = {}
      if(uris)
        uris.each { |uri|
          # DB name
          name = extractName(uri)
          # Db version for track
          dbVer = dbVersion(uri)
          versionsHash[name] = dbVer
        }
      end
      return versionsHash
    end

    # Get database => canAccess [boolean] Hash
    def accessibleDatabasesHash(uris, userId, accessCodes)
      accessibleDatabasesHash = {}
      if(uris and userId and accessCodes)
        uris.each { |uri|
          # Database name
          name = extractName(uri)
          # Store whether accessible
          accessibleDatabasesHash[name] = accessibleByUser?(uri, userId, accessCodes)
        }
      end
      return accessibleDatabasesHash
    end

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    # Set the database as the active data db in the handle
    def setNewDataDb(uri)
      retVal = false
      if(uri)
        # Get name of database
        refSeqId = self.id(uri)
        # Get MySQL database name
        databaseNameRows = @dbu.selectDBNameByRefSeqID(refSeqId)
        if(databaseNameRows and !databaseNameRows.empty?)
          databaseName = databaseNameRows.first['databaseName']
          # Set as active data db in handle
          @dbu.setNewDataDb(databaseName)
          retVal = true
        end
      end
      return retVal
    end

    # Get appropriate database entity table row (refseq row)
    def tableRow(uri)
      row = nil
      if(uri)
        # First, try from cache
        row = getCacheEntry(uri, :tableRow)
        if(row.nil?)
          # If not cached, try to retrieve it
          #
          # Get name of database
          name = extractName(uri)
          if(name)
            # Get refseq rows
            # Get group name first, we may have multiple dbs with the same name under different groups
            groupRefSeq = @grpApiUriHelper.tableRow(uri)
            if(!groupRefSeq.nil? and !groupRefSeq.empty?)
              groupId = groupRefSeq['groupId']
              rows = @dbu.selectRefseqByNameAndGroupId(name, groupId)
              if(rows and !rows.empty?)
                row = rows.first
                # Cache table row
                setCacheEntry(uri, :tableRow, row)
              end
            end
          end
        end
      end
      return row
    end
  end # class DatabaseApiUriHelper < ApiUriHelper
end ; end ; end ; end # module BRL ; module Genboree ; module REST ; module Helpers
