#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/trackEntity'
require 'brl/genboree/rest/data/trackLinkEntity'
require 'brl/genboree/rest/data/attributeDisplayEntity'
require 'brl/genboree/abstract/resources/track'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # TrackAttribute - exposes information about a specific track attributes.
  #
  # Data representation classes used:
  class TrackAttribute < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true } # TODO: implement a PUT for creating new [empty] track and for renaming tracks
    # Labels, etc, for building more generic strings that are copy-paste-bug free
    RSRC_STRS = { :type => 'trk', :label => 'track', :capital => 'Track', :pluralType => 'trks', :pluralLabel => 'tracks', :pluralCap => 'Tracks' }

    ASPECT_PERMISSIONS =
    {
      '/' => PERMISSIONS_RW_GET_ONLY,
      'value' => PERMISSIONS_R_GET_ONLY,
      'display' => PERMISSIONS_R_GET_ONLY,
      'defaultDisplay' => PERMISSIONS_RW_GET_ONLY
    }

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @refseqRow.clear() if(@refseqRow)
      @ftypeHash.clear() if(@ftypeHash)
      @ftypeHash = @refseqRow = @entityName = @aspect = @aspectObj = @dbName = @refSeqId = @groupId = @groupName = @groupDesc = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/attribute/([^/\?]+)(?:/([^/\?]+))?</tt>
    def self.pattern()
      return %r{^/REST/v1/grp/([^/\?]+)/db/([^/\?]+)/#{self::RSRC_STRS[:type]}/([^/\?]+)/attribute/([^/\?]+)/([^/\?]+)$}     # Look for /REST/v1/grp/{grp}/db/{db}/trk/{trk}/attribute/{attributeName}/[aspect] URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    #
    # This class needs to be a higher priority than BRL::REST::Resources::Track
    # so that 'attribute' will be considered a resource and handled by this class as opposed to a track aspect
    #
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 8  # Allow more specific URI handlers involving tracks etc within the database to match first
    end

    def initOperation()
      initStatus = super()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      @entityName = Rack::Utils.unescape(@uriMatchData[3])
      @attrName = (@uriMatchData[4].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[4])
      @aspect = (@uriMatchData[5].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[5]) # Could be nil, 'value', 'display', 'defaultDisplay'
      if(initStatus == :OK)
        @ftypeHash = nil
        initStatus = initGroupAndDatabase()
        if(initStatus == :OK) # It's ok to be fobidden at this point because that refers to the ability to put/delete to a grp/db resource
          # Check permissions for the aspect
          aspectIndex = (@aspect.nil?) ? '/' : @aspect # Look for the 'root' resource (Track) if there is no aspect provided.
          if(!ASPECT_PERMISSIONS[aspectIndex].nil?)
            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "aspectIndex = #{aspectIndex.inspect} ; @groupAccessStr = #{@groupAccessStr.inspect} ; @reqMethod = #{@reqMethod.inspect}")
            if(!ASPECT_PERMISSIONS[aspectIndex][@groupAccessStr.to_sym][@reqMethod])
              @apiError = BRL::Genboree::GenboreeError.new(:Forbidden, "You do not have access to #{@aspect.inspect} for #{@entityName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
            else
              # Get all the tracks in this user database (includes shared tracks) [that user has access to; superuser has access to everything]
              ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes_fast(@refSeqId, @userId, true, @dbu, true) # will also have dbRec.dbName & dbRec.ftypeid for the dbs (user, template) track is present in
              # Get just the one ftypeRow matching the track
              @ftypeHash = ftypesHash[@entityName]
              ftypesHash.clear() if(ftypesHash)
              if(@ftypeHash.nil? or @ftypeHash.empty?)
                initStatus = @statusName = :'Not Found'
                @statusMsg = "NO_TRK: There is no track #{@entityName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
              else
                @fTypeId = @ftypeHash['ftypeid']
                @aspectObj = getAspectHandler()
              end
            end
          else
            # pemissions haven't been defined for the aspect, or the user is trying to access an aspect that doesn't exist
            initStatus = :'Not Found'
          end
        end
      end
      return initStatus
    end

    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      initStatus = initOperation()
      if(!@attrName.nil?)
        if(initStatus == :OK)
          setResponse()
        end
      else
        @apiError = BRL::Genboree::GenboreeError.new(:'Not Implemented', "The attribute name must be included in the URI. GET is not allowed without an attribute name.")
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a PUT operation on this resource.
    #
    # Accepts either TextEntity or a detailed Track Attribute Entity. TODO
    #
    # _returns_ - Rack::Response instance
    def put()
      putStatus = initOperation()
      # Allow a nil aspect object
      if(!@aspectObj.nil? and putStatus == :OK) # PUT the aspect of trk
        @aspectObj.parsePayload(self.readAllReqBody(), @repFormat)
        if(@aspectObj.hasError?)
          @apiError = @aspectObj.error
        else
          putStatus = @aspectObj.put()
        end
      end
      if (@apiError.nil? and (putStatus == :"Moved Permanently" or putStatus == :Created or putStatus == :OK))
        @statusName = setResponse(putStatus)
      else
        @statusName = putStatus
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    # Process a DELETE operation on this resource.
    # _returns_ - Rack::Response instance
    #
    # The delete method is only intended for user defined settings and serves as a way to restore default display settings
    def delete()
      initStatus = initOperation()
      if(!@aspectObj.nil?) # DELETE the aspect of trk
        rows = @aspectObj.delete()
        if(rows.is_a?(Numeric) and rows > 0)
          entity = BRL::Genboree::REST::Data::TextEntity.new(@connect)
          entity.setStatus(:OK, "DELETED:")
          # convert to <FORMAT>
          @statusName = configResponse(entity)
        else
          # Probably trying to delete a track that doesn't exist
          @statusName = :'Not Found'
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end

    def setResponse(statusName=:OK, statusMsg='')
      entity = @aspectObj.getEntity(@connect, @detailed)
      if(entity.is_a?(BRL::Genboree::REST::Data::AbstractEntity))
        entity.setStatus(statusName, statusMsg)
        @statusName = configResponse(entity, statusName)
      else
        @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "The property #{@aspect.inspect} does not exist yet for the attribute: #{@attrName.inspect} for the track #{@entityName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      end
    end


    # This method defines aspects to the appropriate handler objects
    # +returns+:: AspectHandler or nil if there was no match to @aspect
    def getAspectHandler()
      aspectObj = nil
      aspectObj = case @aspect
        when 'value' then TrackAttributeHandler.new(@dbu, @entityName, @refSeqId, @aspect, @ftypeHash, @userId, @attrName)
        when 'display' then TrackAttributeDisplayHandler.new(@dbu, @entityName, @refSeqId, @aspect, @ftypeHash, @userId, @attrName)
        when 'defaultDisplay' then TrackAttributeDisplayHandler.new(@dbu, @entityName, @refSeqId, @aspect, @ftypeHash, 0, @attrName)
        when nil then @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "This aspect #{@aspect.inspect} can not be found: for #{@attrName.inspect}, #{@entityName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}")
      end
      return aspectObj
    end

  end # class TrackAttribute

end ; end ; end # module BRL ; module REST ; module Resources

# Issues
# - Get /display 404 message is misleading, says "can't find attribute" should say "can't find display"
# - Put /display to an attr not in ftypeAttrNames, get 500
# - permissions
