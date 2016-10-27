#!/bin/env ruby
require 'json'
require 'yaml'
require 'uri'
require 'cgi'
require 'mongo'
require 'brl/util/util'
require 'brl/noSQL/mongoDb/mongoDbConnection'

module BRL ; module NoSQL ; module MongoDb
  include Mongo
  class MongoDbURI

    # Parses a NoSQL:MongoDB type URI connection string, similar to what is used by {MongoClient.from_uri}
    #   but with some additional processing to get opts out of the query string (which {MongoClient.from_uri}
    #   can't do.). Info is extracted and returned in a Hash-of-three-Hashes containing the core connection
    #   info (in @:connInfo@), any extra options (in @:opts), and any default authentication info (in @:auth@)
    # Possible keys within the @:connInfo@ sub-hash are the usual:
    # * @:host@ - database host, if available ; mutually exclusive with @socket@
    # * @:port@ - database port, if available ; mutually exclusive with @socket@ ;
    #     default is 27017 if @host@ present but no @port@.
    # * @:socket@ - database socket file path, if available ; mutually exclusive
    #     with @host@ and @port@
    # While the @:opts@ sub-hash will contain any Mongo-driver-specific extra options.
    # And the @:auth@ sub-hash will oontain these keys, if the info is present in the URI:
    # * @:user@ - default username for Mongo database authentication
    # * @:pass@ - default password for Mongo database authentication
    # @see BRL::NoSQL::MongoDB::MongoDbConnection::DEFAULT_OPTS For some notes about Mongo-driver-specific
    #   extra options.
    # @note If @database@ is present in the MongoDB URI string, it will be purposefully skipped
    #   and ignored when parsed.
    # @note Any @opts@ provided as name-value pairs in the query string will have their values
    #   "auto-cast" to the most reasonable non-String type if appropriate. See {String#autoCast}
    # @param [String] uri The URI connection string. Expected to start with @mongodb://@ and look like
    #   a URI, with username & password info in the standard place in a URI. Query string can contain any
    #   specific options, as AVPs.
    # @return [Hash{Symbol=>Hash}] A Hash of Hashes with three top-level keys containing connection info
    #   (@:connInfo@), any extra opts (@:opts@), and any default auth info (@:auth@), respectively.
    # @raise [ArgumentError] If uri doesn't look like a valid mongodb URI driver string.
    # @raise [URI::InvalidURIError] If uri isn't even a valid URI string.
    def self.parse(uri)
      retVal = { :connInfo => {}, :opts => {}, :auth => {} }
      # Has correct prefix?
      if(uri =~ /^mongodb:\/\//i)
        uriObj = URI.parse(uri)
        nvPairs = (uriObj.query ? CGI.parse(uriObj.query) : {})
        # Auth info, if any
        retVal[:auth][:user] = uriObj.user if(uriObj.user)
        retVal[:auth][:pass] = uriObj.password if(uriObj.password)
        # Connection info.
        if(!uriObj.port.nil? and nvPairs.key?("socket") and nvPairs["socket"].first =~ /\S/)
          raise ArgumentError, "ERROR: The URI connection string provided has both socket info and a port. This is not allowed."
        elsif(uriObj.host !~ /localhost/i and nvPairs.key?("socket") and nvPairs["socket"].first =~ /\S/)
          raise ArgumentError, "ERROR: The URI connection string provided has a non-localhost host and socket info. Sockets are ONLY valid when host is 'localhost'."
        elsif(uriObj.port.nil? and uriObj.host =~ /localhost/i and nvPairs.key?("socket") and nvPairs["socket"].first =~ /\S/)
          # Then we have a socket properly on the localhost.
          retVal[:connInfo][:socket] = nvPairs["socket"].first
        elsif(uriObj.host or uriObj.port) # then have a host and/or port and no socket info
          retVal[:connInfo][:host] = uriObj.host if(uriObj.host)
          retVal[:connInfo][:port] = uriObj.port if(uriObj.port)
        else # missing enough info
          raise ArgumentError, "ERROR: The URI connection string provided is missing sufficient connection info. Either provide a 'socket' AVP with the host set to 'localhost', or provide a host and/or port [with no socket AVP]."
        end
        # Opts. From the query string
        nvPairs.each_key { |attr|
          next if(attr.nil? or attr =~ /socket/i) # CGI.parse() can produce a nil=>nil nvPair
          retVal[:opts][attr.to_sym] = nvPairs[attr].first.autoCast(false)
        }
        retVal[:connInfo] = MongoDbConnection.ensureMinConnInfo(retVal[:connInfo])
      else
        raise ArgumentError, "ERROR: The URI string provided doesn't look like a MongoDB URI. Should start with 'mongodb://', but doesn't."
      end
      return retVal
    end

    # Builds a URI string from a connection info {Hash}.
    #   This can be used for debugging or for creating ~normalized URI strings which
    #   can be used as cache/hash keys because the URI is built the same way each time.
    #   URIs from conf files or code may or may not match ones already in the cache/hash,
    #   so this normalization approach can be useful.
    # For normalizing existing URI strings from elsewhere, generally one would first do a {#parse},
    #   and then call this {#makeURI} in order to build a normalized version.
    # @see parse For more notes about expected contents of @connInfo@, @opts@, and defaultAuthInfo.
    # @param [Hash] connInfo The connection info hash, often from parsing a URI via {#parse} or built manually in code.
    # @param [Hash] defaultAuthInfo A Hash with two default authentication-related keys: @:user@ and @:pass@.
    # @param [Hash] opts A Hash of any extra driver opts to be set. They will be added to the end of the URI.
    # @return [String] The URI connection string
    # @raise [ArgumentError] If some inappropriate content is found in any of the parameters.
    def self.makeURI(connInfo, opts={}, defaultAuthInfo={})
      uriStr = "mongodb://"
      # Ensure have minimum connection info (part of ~normalization anyway)
      connInfo = MongoDbConnection.ensureMinConnInfo(connInfo)
      # Auth info, if any
      if(defaultAuthInfo and (defaultAuthInfo.key?(:user) or defaultAuthInfo.key?(:pass)))
        if(defaultAuthInfo.key?(:user) and defaultAuthInfo.key?(:pass))
          uriStr << "#{defaultAuthInfo[:user].strip}:#{defaultAuthInfo[:pass].strip}@"
        else
          raise ArgumentError, "ERROR: the defaultAuthInfo parameter must have BOTH :user and :pass keys, if it is provided."
        end
      end
      # Host info
      if(connInfo.key?(:socket))
        uriStr << "localhost?"
      elsif(connInfo.key?(:host))
        uriStr << connInfo[:host].strip
        uriStr << ":#{connInfo[:port]}" if(connInfo.key?(:port))
        uriStr << "?"
      end
      # Now add query string
      # - socket first, if present
      uriStr << "&socket=#{connInfo[:socket].strip}" if(connInfo[:socket])
      # - now items in opts, sorted
      opts.keys.sort { |aa,bb| cmp = (aa.to_s.downcase <=> bb.to_s.downcase) ; cmp = (aa <=> bb) if(cmp == 0) ; cmp }.each { |key|
        unless(key == :host or key == :port or key == :socket or key == :database)
          uriStr << "&#{key}=#{opts[key].to_s.strip}"
        end
      }
      return uriStr
    end
  end # class MongoDbURI
end ; end ; end # module BRL ; module NoSQL ; module MongoDb
