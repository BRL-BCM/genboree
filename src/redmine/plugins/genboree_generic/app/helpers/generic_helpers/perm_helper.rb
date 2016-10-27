
module GenericHelpers
  module PermHelper
    # ----------------------------------------------------------------
    # BEFORE_FILTERS - useful before_filter methods for your controller
    # ----------------------------------------------------------------

    # Get a map of permission=>value for the user.
    def userPerms(pluginId, project=@project, user=User.current)
      # @param [Symbol] pluginId Permission context: the id of the plugin for which we want permission info.
      # @param [Project] project Optional. Permission context: the project object for which we want permission info.
      #   Defaults to @@project@ which should be set by now.
      # @param [User] user Optional. The user for which we want permission info. Defaults to @User.current@
      @userPerms    = pluginUserPerms(pluginId, project, user)
      @userPermsJS  = pluginUserPerms(pluginId, project, user, :as => :javascript)
    end

    # ----------------------------------------------------------------

    # Get all the permissions available for a given plugin.
    # @param [Symbol] pluginId Permission context: the id of the plugin for which we want permission info.
    # @return [Array<Symbol,String,Permission>] Array of permissions as {Symbols}, {Strings}, or Redmine {Permission} objects
    def pluginPerms(plugin, opts={ :as => :permObj })
      retVal = []
      # Get all Permission objects for the plugin
      perms = Redmine::AccessControl.permissions.find_all { |perm| perm.project_module == plugin }
      # Get as type wanted
      if(opts[:as] == :symbol)
        retVal = perms.collect() { |perm| perm.name }
      elsif(opts[:as] == :string)
        retVal = perms.collect() { |perm| perm.name.to_s }
      else # as Permission object
        retVal = perms
      end
      return retVal
    end

    # Get a map of permission=>boolean for a user in the context of a particular plugin and project.
    # @param [Symbol] pluginId Permission context: the id of the plugin for which we want permission info.
    # @param [Project] project Optional. Permission context: the project object for which we want permission info.
    #   Defaults to @@project@ which should be set by now.
    # @param [User] user Optional. The user for which we want permission info. Defaults to @User.current@
    # @param [Hash{Symbol,Object}] Optional. The options Hash to override default behavior. Can be used to have
    #   this method return a Javascript hash in a string, for embedding permissions map in browser pages rather
    #   than the default Ruby hash.
    # @return [Hash{Symbol,Boolean}] The permission map for the user in the context of plugin and project.
    def pluginUserPerms(plugin, project=@project, user=User.current, opts={ :as => :hash})
      retVal = nil
      # Get all permission symbols for the plugin
      perms = pluginPerms(plugin, :as => :symbol)
      # Find if user allowed in project for each permission
      permMap = {}
      perms.each { |perm|
        userAllowed = user.allowed_to?(perm, project)
        permMap[perm] = userAllowed
      }
      # Get as type wanted
      if(opts[:as] == :javascript)
        js = "var pluginUserPerms = {"
        permMap.each_key { |perm|
          js << " #{perm} : #{permMap[perm]},"
        }
        js.chomp!(',')
        js << ' } ;'
        retVal = js
      else # as :hash
        retVal = permMap
      end
      return retVal
    end
  end
end
