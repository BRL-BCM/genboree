#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/databaseEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # Databases - exposes information about a collection of user databases within a group (currently just the names of
  # the databases within the group).
  #
  # Data representation classes used:
  # * BRL::Genboree::REST::Data::TextEntityList
  # * BRL::Genboree::REST::Data::TextEntity
  class Databases < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this service
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/dbs</tt>
    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/dbs}                 # Look for /REST/v1/grp/{grp}/dbs URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/service is
    # highly specific and should be examined early on, or whether it is more generic and
    # other services should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 3          # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    # Process a GET operation on this resource.
    # [+returns+] <tt>Rack::Response</tt> instance
    def get()
      initStatus = initOperation()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        initStatus = initGroup()
        if(initStatus == :OK)
          # Get refseqs in the group:
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "@groupId: #{@groupId.inspect} ; publicGroupId: #{@genbConf.publicGroupId.inspect} ; @groupAccessStr: #{@groupAccessStr.inspect}" )
          if(@groupId == @genbConf.publicGroupId.to_i and (@groupAccessStr == 'p' or @groupAccessStr == 'r'))
            # Group is special Public group.
            # Then need BOTH refseqs explicitly in special Public group (old way) AND
            # all those refseqs which are flagged as public and which are unlocked (new way)
            refseqRows =  ( @dbu.selectPublicRefseqsByGroupId(@groupId) or [] )
            refseqRows += ( @dbu.selectPublicUnlockedRefseqs() or [] )
          elsif(@groupAccessStr == 'p')
            # Not the special 'Public' group, but is a public type access. Include only the 'public unlocked' dbs
            refseqRows = @dbu.selectPublicUnlockedRefseqsByGroupId(@groupId)
          else
            # Regular user group database auth access
            refseqRows = @dbu.selectRefseqsByGroupId(@groupId)
          end
          refseqRows = [] if(refseqRows.nil?)
          # Ensure we don't have duplicates (mainly due to old special Public group style access
          seenRefSeqIds = {}
          refseqRows.delete_if { |row|
            retVal = false
            refSeqId = row['refSeqId']
            if(seenRefSeqIds.key?(refSeqId))
              retVal = true
            else
              retVal = false
              seenRefSeqIds[refSeqId] = true
            end
            retVal
          }
          # Sort by user's database name
          refseqRows.sort! {|aa,bb| aa['refseqName'].downcase <=> bb['refseqName'].downcase }
          # Transform db records to return data
          refBase = makeRefBase("/REST/#{VER_STR}/grp/#{Rack::Utils.escape(@groupName)}/db")
          bodyData = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
          refseqRows.each { |row|
            refseqName = row['refseqName']
            # connect entity to more detailed info
            if(@detailed)
              # Add stuff
              # Check for a gbKey
              entity = BRL::Genboree::REST::Data::DetailedDatabaseEntity.new(@connect, refseqName, row['refseq_species'], row['refseq_version'], row['description'], row['refSeqId'], row['unlockKey'], true)
            else
              entity = BRL::Genboree::REST::Data::TextEntity.new(@connect, refseqName)
            end
            entity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(refseqName)}")
            bodyData << entity
          }
          @statusName = configResponse(bodyData)
          refseqRows.clear() if(refseqRows)
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
  end # class Databases
end ; end ; end # module BRL ; module REST ; module Resources
