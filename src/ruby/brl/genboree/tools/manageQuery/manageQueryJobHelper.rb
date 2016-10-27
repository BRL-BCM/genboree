require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require "brl/genboree/tools/workbenchJobHelper"

module BRL ; module Genboree ; module Tools
  class ManageQueryJobHelper < WorkbenchJobHelper

    TOOL_ID = 'manageQuery'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    # The job for creating a query is a simple db insert so
    # instead of creating a TaskWrapper, just perform the create
    def runInProcess()
      success = false

      begin
        # We will have the group and db human readable names, as well as dbrcKey
        # 1. Create DBUtil with dbrcKey, nil
        dbUtil = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil)

        # 2. Find the refseq, DBUtil#selectRefseqByName(dbName unescaped)
        refseq = dbUtil.selectRefseqByName(Rack::Utils.unescape(@workbenchJobObj.context['db']))
        if(refseq.nil? or refseq.empty?)
          # We should never have this error, but check to be safe
          # Error: We could not connect or find the user dataDb, this is needed for any query func.
          raise RuntimeError.new("User database for '#{Rack::Utils.unescape(@workbenchJobObj.settings['db'])}' could not be found!")
        else
          refseq = refseq.first()
        end

        # 3. With refseq name, set dataDbName, needed for queries DBUtil#setNewDataDb
        dbUtil.setNewDataDb(refseq['databaseName'])

        # 4. Make sure our query is accessible from the db
        query = dbUtil.getQueryByName(Rack::Utils.unescape(@workbenchJobObj.settings['queryName']))
        if(query.nil? or query.empty?)
          raise ArgumentError.new("The query '#{Rack::Utils.unescape(@workbenchJobObj.settings['queryName'])}' could not be found in the database! ")
        else
          query = query.first()
        end

        # 5. Now check that we have access to modify the query
        user = dbUtil.getUserByName(@workbenchJobObj.context['userLogin'])
        if(user.nil? or user.empty?)
          # We should never have this error, but check to be safe
          raise RuntimeError.new("The user '#{@workbenchJobObj.context['userLogin']}' could not be found in the database!")
        else
          user = user.first()
        end

        group = dbUtil.selectGroupByName(Rack::Utils.unescape(@workbenchJobObj.context['group']))
        if(group.nil? or group.empty?)
          # We should never have this error, but check to be safe
          raise RuntimeError.new("The group '#{Rack::Utils.unescape(@workbenchJobObj.context['group'])}' could not be found in the database!")
        else
          group = group.first()
        end

        groupAccess = dbUtil.getAccessByUserIdAndGroupId(user['userId'], group['groupId'])
        if(groupAccess.nil?)
          # We should never have this error, but check to be safe
          raise RuntimeError.new("Access could not be retrieved for user '#{@workbenchJobObj.context['userLogin']}' and group '#{Rack::Utils.unescape(@workbenchJobObj.settings['group'])}'!")
        else
          groupAccess = groupAccess[0]
        end

        # First check our user access to this refseq, read only ('r') means no query create!
        # Access rules:
        #   1) If user only has 'r' access, just return, nothing to do
        #   2) If user is admin, all is possible (delete/modify without ownership)
        #   3) If user is NOT admin, must be owner of the query
        if((groupAccess != 'o') and (user['userId'] != query['user_id']))
          msg = ""
          if(query['user_id'] == -1)
            msg << "'#{Rack::Utils.unescape(@workbenchJobObj.settings['queryName'])}' is a shared query. "
            msg << "A shared query can only be modified by an administrator."
          else
            msg << "User '#{@workbenchJobObj.context['userLogin']}' does not own the query '#{Rack::Utils.unescape(@workbenchJobObj.settings['queryName'])}'. "
            msg << "A query can only be modified by the query owner or an administrator."
          end

          raise SecurityError.new(msg)
        end

        # All resources are available and user has permission to alter them
        result = 0
        if(@workbenchJobObj.context['action'] == 'delete')
          result = dbUtil.deleteQueryById(query['id'])
        elsif(@workbenchJobObj.context['action'] == 'update')
          # If the query is not shared, no one owns it. If we are not sharing, then the query owner remains the same
          uid = (@workbenchJobObj.settings['queryShared'].nil? or @workbenchJobObj.settings['queryShared'] == 'off') ? query['user_id'] : -1
          name = @workbenchJobObj.settings['queryName']
          desc = @workbenchJobObj.settings['queryDesc']
          queryStr = @workbenchJobObj.settings['queryObjStr']
          result = dbUtil.updateQuery(query['id'], name, desc, queryStr, uid)
        else
          raise RuntimeError.new("Action '#{@workbenchJobObj.context['action']}' not supported for queries!")
        end

        # Make sure everything was performed without error
        # NOTE: This will return successful even if no values were changed (in the case the user updates with the
        #   same values. This is acceptable as the server successfully performed what the user asked, however some might
        #   consider this an error. If so, perhaps some logic in the client UI can be added to check# consider this an error.
        #   If so, perhaps some logic in the client UI can be added to check if anything has changed before an update is allowed
        if(result.nil?)
          raise RuntimeError.new("An error occurred while trying to modify the query '#{@workbenchJobObj.settings['queryName']}'!")
        end

        # If we made it here, we were successful
        @workbenchJobObj.context['wbAcceptedName'] = :'OK'
        success = true
      rescue SecurityError => e
        # Use the SecurityError to indicate a :Forbidden
        @workbenchJobObj.context['wbErrorName'] = :'Forbidden'
        @workbenchJobObj.context['wbErrorMsg'] = e.message + ' Please contact your Genboree administrator.'
      rescue ArgumentError => e
        # Use the ArgumentError to indicate a :Not Found, no query
        @workbenchJobObj.context['wbErrorName'] = :'Not Found'
        @workbenchJobObj.context['wbErrorMsg'] = e.message
      rescue RuntimeError => e
        # Any excepion here should be of a server error nature
        @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
        @workbenchJobObj.context['wbErrorMsg'] = e.message + ' Please contact your Genboree administrator.'
        @workbenchJobObj.context['wbErrorDetails'] = e.backtrace.join("<br/>\n")
      end
      return success
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
