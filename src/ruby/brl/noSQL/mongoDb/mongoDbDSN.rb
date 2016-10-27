#!/bin/env ruby
require 'json'
require 'yaml'
require 'mongo'
require 'brl/util/util'
require 'brl/noSQL/mongoDb/mongoDbConnection'

module BRL ; module NoSQL ; module MongoDb
  class MongoDbDSN

    # Parses a NoSQL:MongoDB type DSN driver string (aka more correctly as a "connection string"),
    #   extracting the AVPs and returning a Hash-of-two-Hashes containing the core connection
    #   info (in @:connInfo@) and any extra options (in @:opts).
    # Possible keys within the @:connInfo@ sub-hash are the usual:
    # * @:host@ - database host, if available ; mutually exclusive with @socket@
    # * @:port@ - database port, if available ; mutually exclusive with @socket@ ;
    #     default is 27017 if @host@ present but no @port@.
    # * @:socket@ - database socket file path, if available ; mutually exclusive
    #     with @host@ and @port@
    # While the @:opts@ sub-hash will contain any Mongo-driver-specific extra options.
    # @see BRL::NoSQL::MongoDB::MongoDbConnection::DEFAULT_OPTS For some notes about Mongo-driver-specific
    #   extra options.
    # @note If @database@ is present in the MongoDB DSN string, it will be purposefully skipped
    #   and ignored when parsed.
    # @param [String] dsn The DSN driver string. Expected to start with @NoSQL:MongoDB:@
    #   and then the semi-colon separated attribute value pairs.
    # @return [Hash{Symbol=>Hash}] A Hash of Hashes with two top-level keys containing connection info
    #   (@:connInfo@) and any extra opts (@:opts@), respectively.
    # @raise [ArgumentError] If @dsn@ doesn't look like a valid DSN driver string
    def self.parse(dsn)
      retVal = { :connInfo => {}, :opts => {} }
      # Has correct prefix?
      if(dsn =~ /^NoSQL:MongoDB:(.+)$/)
        allAvps = $1.strip
        avpStrs = allAvps.split(/;/)
        # Process each AVP in the DSN. Put well-known connection-related keys in the
        # :connInfo hash, and put rest of AVPs in the :opts hash assuming they are extra options.
        avpStrs.each { |avpStr|
          avpStr.strip!
          if(avpStr =~ /^([^=]+)=(.+)$/)
            attr, value = $1.strip, $2.strip
            if(attr =~ /host/i)
              raise ArgumentError, "ERROR: The DSN string provided has both a 'host' and 'socket' AVP. This is not allowed." if(value !~ /localhost/i and retVal[:connInfo].key?(:socket))
              retVal[:connInfo][:host] = value
            elsif(attr =~ /port/i)
              raise ArgumentError, "ERROR: The DSN string provided has both a 'port' and 'socket' AVP. This is not allowed." if(retVal[:connInfo].key?(:socket))
              if(value =~ /^\d+$/)
                retVal[:connInfo][:port] = value.to_i
              else
                raise ArgumentError, "ERROR: The DSN string provided hasa non-integer port value?? (#{value.inspect})"
              end
            elsif(attr =~ /socket/i)
              raise ArgumentError, "ERROR: The DSN string provided has both a 'socket' and a non-localhost 'host' and/or 'port' AVP. Only a host of 'localhost' is allowed with 'socket' and even then it is optional. This is not allowed." if((retVal[:connInfo].key?(:host) and retVal[:connInfo][:host] !~ /localhost/i) or retVal[:connInfo].key?(:port))
              retVal[:connInfo][:socket] = value
            elsif(attr =~ /database/i)
              next  # skip/remove, databases are to be obtained as needed
            else # capture any others in :opts
              retVal[:opts][attr.to_sym] = value.autoCast(false)
            end
          else
            raise ArgumentError, "ERROR: The DSN string provided doesn't seem well formed. Found an AVP that doesn't appear to be {attr}={value} format: #{avpStr.inspect}." unless(avpStr.nil? or avpStr.empty?) # probably from a leading ; or two ;; in a row. Skip these.
          end
        }
        retVal[:connInfo] = MongoDbConnection.ensureMinConnInfo(retVal[:connInfo])
      else
        raise ArgumentError, "ERROR: The DSN string provided doesn't look like a MongoDB DSN. Should start with 'NoSQL:MongoDB:', but doesn't."
      end
      return retVal
    end

    # Builds a DSN string (or better: a connection string) from a connection info {Hash}.
    #   This can be used for debugging or for creating ~normalized DSN strings which
    #   can be used as cache/hash keys because the DSN is built the same way each time.
    #   DSNs from conf files or code may or may not match ones already in the cache/hash,
    #   so this normalization approach can be useful.
    # For normalizing existing DSN strings from elsewhere, generally one would first do a {#parse},
    #   and then call this {#makeDSN} in order to build a normalized version.
    # @see parse For more notes about expected contents of @connInfo@ and @opts@.
    # @param [Hash] connInfo The connection info hash, often from parsing a DSN via {#parse} or built manually in code.
    # @param [Hash] opts A Hash of any extra driver opts to be set. They will be added to the end of the DSN.
    # @return [String] The DSN aka connection string corresponding to @connInfo@
    def self.makeDSN(connInfo, opts={})
      dsnStr = "NoSQL:MongoDB:"
      # Ensure have minimum connection info (part of ~normalization anyway)
      connInfo = MongoDbConnection.ensureMinConnInfo(connInfo)
      # host/port or socket first
      if(connInfo.key?(:socket))
        if(!connInfo.key?(:port) and (!connInfo.key?(:host) or (connInfo[:host] =~ /localhost/i)))
          dsnStr << "host=localhost;socket=#{connInfo[:socket]};"
        else
          raise ArgumentError, "ERROR: The connInfo has both a non-localhost host and/or port info as well as a 'socket' key. Only a host of 'localhost' is allowed with 'socket' and even then it is optional. Port and socket cannot be both provided. This is not allowed."
        end
      elsif(connInfo.key?(:host) or connInfo.key?(:port))
        # We know here that there is no :socket specified. Just deal with host/port
        dsnStr << "host=#{connInfo[:host]};" if(connInfo.key?(:host))
        dsnStr << "port=#{connInfo[:port]};" if(connInfo.key?(:port))
      end
      # rest of options, sorted by key (except database, it will be removed if present here)
      if(opts)
        opts.keys.sort { |aa,bb| cmp = (aa.to_s.downcase <=> bb.to_s.downcase) ; cmp = (aa <=> bb) if(cmp == 0) ; cmp }.each { |key|
          unless(key == :host or key == :port or key == :socket or key == :database)
            dsnStr << "#{key}=#{opts[key]};"
          end
        }
      end
      dsnStr.chomp!(";")
      return dsnStr
    end
  end # class MongoDbDSN
end ; end ; end # module BRL ; module NoSQL ; module MongoDb
