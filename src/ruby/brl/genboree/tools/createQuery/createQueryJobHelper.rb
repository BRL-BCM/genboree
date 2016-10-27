require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class CreateQueryJobHelper < WorkbenchJobHelper

    TOOL_ID = 'createQuery'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    def fillClientContext(wbJobEntity)
      wbJobEntity = super(wbJobEntity)
      template = wbJobEntity.inputs[0]

      unless(template.nil?)
        # Template provided, our rules helper ensures that the passed template is queryable, so we just
        # need to fill the context with the tmpl, tmplGroup and tmplDb to make it easier on the client
        rsrc = nil
        priority = 0
        template = URI.parse(template).path()

        if(template.match(%r{^/REST/v\d+/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)(?:$|/([^/\?]+)$)}))
          # Special case, we assume that if a user specified Track, they meant TrackAnnos
          template << "/annos"
        end

        # Now check all our resources to see if our template matches any
        BRL::REST::Resources.constants.each{ |constName|
          const = BRL::REST::Resources.const_get(constName.to_sym)
          if(const.pattern().match(template))
            if(const.priority > priority)
              priority = const.priority
              rsrc = constName
            end
          end
        }

        unless(rsrc.nil?)
          # We should always have the resource, but just in case
          wbJobEntity.context['tmpl'] = rsrc
        end
      end

      return wbJobEntity
    end

    # The job for creating a query is a simple db insert so
    # instead of creating a TaskWrapper, just perform the create
    def runInProcess()
      success = false

      # Get required server information that the job will need
      settings = @workbenchJobObj.settings
      context = @workbenchJobObj.context

      # We will have the group and db human readable names, as well as dbrcKey
      begin
        # 1. Create DBUtil with dbrcKey, nil
        dbUtil = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil)

        # 2. Find the refseq, DBUtil#selectRefseqByName(dbName unescaped)
        refseq = dbUtil.selectRefseqByName(Rack::Utils.unescape(context['db']))
        if(refseq.nil? or refseq.empty?)
          # We should never have this error, but check to be safe
          # Error: We could not connect or find the user dataDb, this is needed for any query func.
          raise RuntimeError.new("User database for '#{Rack::Utils.unescape(context['db'])}' could not be found!")
        else
          refseq = refseq.first()
        end

        # 3. With refseq name, set dataDbName, needed for queries DBUtil#setNewDataDb
        dbUtil.setNewDataDb(refseq['databaseName'])

        # 4. Now do query specific stuff - Need user, group and user access
        # TODO: Do I need to be escaping here? I don't think this is escaped coming to me...
        user = dbUtil.getUserByName(context['userLogin'])
        if(user.nil? or user.empty?)
          # We should never have this error, but check to be safe
          raise RuntimeError.new("The user '#{context['userLogin']}' could not be found in the database!")
        else
          user = user.first()
        end

        group = dbUtil.selectGroupByName(Rack::Utils.unescape(context['group']))
        if(group.nil? or group.empty?)
          # We should never have this error, but check to be safe
          raise RuntimeError.new("The group '#{Rack::Utils.unescape(context['group'])}' could not be found in the database!")
        else
          group = group.first()
        end

        groupAccess = dbUtil.getAccessByUserIdAndGroupId(user['userId'], group['groupId'])
        if(groupAccess.nil?)
          # We should never have this error, but check to be safe
          raise RuntimeError.new("Access could not be retrieved for user '#{context['userLogin']}' and group '#{Rack::Utils.unescape(settings['group'])}'!")
        else
          groupAccess = groupAccess[0]
        end

        # First check our user access to this refseq, read only ('r') means no query create!
        if(groupAccess == 'r')
          raise SecurityError.new("User '#{context['userLogin']}' does not have write access to the '#{Rack::Utils.unescape(settings['group'])}' group!")
        end

        # Check to see if a query already exists for our name
        query = dbUtil.getQueryByName(Rack::Utils.unescape(settings['queryName']))
        if(!query.nil? and !query.empty?)
          raise ArgumentError.new("The query name '#{Rack::Utils.unescape(settings['queryName'])}' is already in use! ")
        end

        # We can write to the group and we have a unique name, create the query
        uid = (settings['queryShared'].nil? or settings['queryShared'] == 'off') ? context['userId'] : -1
        query = dbUtil.insertQuery(settings['queryName'], settings['queryDesc'], settings['queryObjStr'], uid)
        raise RuntimeError.new("An error occurred while trying to insert the query '#{settings['queryName']}' into the database! ") if(query.nil?)

        # If we made it here, we were successful
        @workbenchJobObj.context['wbAcceptedName'] = :'Created'
        success = true
      rescue SecurityError => e
        # Use the SecurityError to indicate a :Forbidden
        success = false
        @workbenchJobObj.context['wbErrorName'] = :'Forbidden'
        @workbenchJobObj.context['wbErrorMsg'] = e.message + ' Please contact your Genboree administrator.'
      rescue ArgumentError => e
        # Use the ArgumentError to indicate a :Conflict (existing query)
        success = false
        @workbenchJobObj.context['wbErrorName'] = :'Conflict'
        @workbenchJobObj.context['wbErrorMsg'] = e.message
      rescue RuntimeError => e
        # Any excepion here should be of a server error nature
        success = false
        @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
        @workbenchJobObj.context['wbErrorMsg'] = e.message + ' Please contact your Genboree administrator.'
        @workbenchJobObj.context['wbErrorDetails'] = e.backtrace.join("<br/>\n")
      end
      return success
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
