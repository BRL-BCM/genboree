
module GenericHelpers
  module PermHelper
    # To have controller methods available in Views, Rails requires them to be declared as helper_methods.
    # Of course wherever they get included needs to also have the helper_method() method. Controllers
    #   and AbstractController::Helpers do. This should handle other cases appropriately.
    def self.included( obj )
      if( obj.respond_to?( :helper_method) )
        obj.helper_method :'userAllowed?', :'userAllowedByControllerAction?'
        obj.helper_method :'userHasRole?', :userRoles
        obj.helper_method :'roleHasPerm?'
      end
    end

    # ----------------------------------------------------------------
    # BEFORE_FILTERS - useful before_filter methods for your controller
    # ----------------------------------------------------------------

    # Ask directly if user has a *specific permission* within a project.
    # @note Consider using #userAllowedByControllerAction if you want a method that asks directly
    #   "can the current user do the current controller-action", without having to know a specific permission.
    #   It's better for a generic "ok to proceed, purely based on permissions?"
    # @note Does NOT examine in project is public or not. Redmine's permission infrastructure already does that.
    # @note The default args are configured such that userAllowed??( permission ) works well after the "find_project" before_filter
    #   and within a real Rails session.
    # @param [Symbol, Array<Symbol>] permissions The user must have this permission--or ANY of these permissions if an Array is provided--
    #   in the project.
    # @param [Project] project Optional, default from find_project before_filter. The project within which user needs to have the Role.
    # @param [User] user Optional, default {@currRmUser}. The user to check for role within project.
    # @return [Boolean] Indicating whether user has the desired permission or not.
    def userAllowed?( permissions, project=@project, user=(@currRmUser or User.current) )
      permissions = [ permissions ] unless( permissions.is_a?(Array) )
      return user.roles_for_project( project ).any? { |role| !( role.permissions & permissions ).empty?  }
    end

    # Given the current controller-action, does the user have permission for that controller-action in the
    #   context of the given Project? Project public/private is NOT consulted.
    # @note This is close to what redmine does already except it is PURELY about permissions and WILL NOT
    #   consult the project's public/private status like Redmine does for Anonymous and Non Member roles
    #   (which are 2 types of public access).
    # @note Useful when the project should not be public but offers services to which even Anonymous roles
    #   are allowed.
    # @note The default args are configured such that userAllowedByControllerAction?() just works when used within
    #   a controller-action method and after the find_project before_filter. It just works.
    # @note When used within a Controller, NO ARGUMENTS are needed, because it uses the "controller_name" and
    #   "action_name" variables supplied by Rails in all controllers. Just works.
    # @note If using this to allow public access to certain functionality in a private project, it is the
    #   FIRST THING you controller-action should do. If access is NOT ALLLOWED, you should refuse access correctly
    #   via either (1) rendering a custom view with nice & themed refusal message or (2) slightly works at least
    #   use standard Redmine rejection via "render_403 :message => :permission_denied" or simply "authorize"
    # @note If using this to allow public access to certain functionality in a private project, DO NOT USE WITH
    #   Redmine's "authorize" which will apply Redmine's regular access controler and will reject Anonymous
    #   or Non Member access to your private project because it treats those as project-must-be-public-for-these-Roles.
    # @param [Symbol] controllerName Optional, default provided by Controller class that included this module. The
    #   standard Rails controller {Symbol} within which you're trying to determine access.
    # @param [Symbol] actionName Optional, default provided by Controller class that included this module. The standard
    #   Rails action {Symbol} for which you're trying to determine access.
    # @param [Project] project Optional, default from find_project before_filter. The project within which user needs to
    #   SOME permssion that would grant access.
    # @param [User] user Optional, default {@currRmUser}. The user to check for access within project via SOME permssion.
    # @return [Boolean] Whether the user has access to the controller-action given the Project context.
    def userAllowedByControllerAction?( controllerName=controller_name, actionName=action_name, project=@project, user=(@currRmUser or User.current) )
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "controllerName: #{controllerName.inspect} ;;; action: #{actionName.inspect} ;;; project: #{@project.inspect};;;;user: #{user.inspect}")
      fqActionStr = "#{controllerName}/#{actionName}"
      allowed = Redmine::AccessControl.permissions.select { |permission|
        permission.actions.include?( fqActionStr )
      }.any? { |permission|
        user.roles_for_project( project ).any? { |role|
          role.permissions.include?(permission.name)
        }
      }
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "allowed????: #{allowed.inspect}")
      return allowed
    end


    # Downgrade user's Role w.r.t. project FOR THIS REQUEST ONLY. We'll do this by manipulating
    #   The Redmine membership info which is still IN MEMORY and set their Role for this
    #   project specifically as the Anonymous Role. Of course we won't Save that membership, it's just
    #   for downgrading during this request!
    def downgradeUserRole( newRoleName='Anonymous', project=@project, user=(@currRmUser or User.current) )
      newRoles = Role.where( :name => newRoleName )
      unless( newRoles.empty? )
        # Get the Role object to dowgrade user to
        newRole = newRoles.first
        # Pretend to get the current roles for project using the Redmine method.
        # - But really just using this to property initialize @membership_by_project_id within user instance.
        user.roles_for_project( project )

        # Now force the membership by altering @membership_by_project_id directly.
        # - We'll need to make sure we've got ACCESS to @membership_by_project_id ...
        #   it's not an accessor or anything by default
        # 1. Ensure User @membership_by_project_id variable is available as accessor
        unless( user.respond_to?( :membership_by_project_id ) )
          #  1.1 If not, add it via monkey-patching the User class
          User.send( :attr_accessor, :'membership_by_project_id' )
        end
        # 2. Create new TEMPORARY (request only) Member object. (won't save)
        #    for project and user.
        tempMember = Member.new
        tempMember.project_id = project.id
        tempMember.user_id = user.id
        # 2.2 Set Member#roles array to contain our newRow
        tempMember.roles = [ newRole ]
        # 3. Add/Replace Member in @membership_by_project_id
        user.membership_by_project_id[ project.id ] = tempMember
        $stderr.debugPuts(__FILE__, __method__, 'STATUS', "User #{user.login.inspect} DOWNGRADED to #{newRoleName.inspect} Role in Project #{project.name.inspect} for *CURRENT REQUEST*")
      else
        newRole = nil
      end
      return newRole
    end

    # Does the user have the given Role within the project?
    # @note They could have more than one, that's fine, but is @roleName@ one of them?
    #   Generally just one, but ONLY by convention of Administrators. Redmine supports mulitple roles
    #   per project per user. Consider can have both "node_owner" for vbr and "consortium member" for exRNA (illustratively).
    # @note Roles are NOT permissions! You should NOT in 98.7% of cases do anything based on Roles.
    # @note The default args are configured such that userHasRole?( roleName ) works well after the "find_project" before_filter
    #   and within a real Rails session. The args can be supplied when there is no project--global plugin settings code mayber--
    #   or you need to do things for a different user (shim user, you are implementing Administrator functionality, etc).
    # @param [String] roleName The unique {Role#name} for the Role the user must have in the project
    # @param [Project] project Optional, default from find_project before_filter. The project within which user needs to have the Role.
    # @param [User] user Optional, default {@currRmUser}. The user to check for role within project.
    # @return [Boolean] Whether user has the Role in the Project or not.
    def userHasRole?( roleName, project=@project, user=(@currRmUser or User.current) )
      return userRoles( project, user ).any? { |role| role.name == roleName }
    end

    # Get list of Roles that User has within a Project.
    # @note Generally just one, but ONLY by convention of Administrators. Redmine supports mulitple roles
    #   per project per user. Consider can have both "node_owner" for vbr and "consortium member" for exRNA (illustratively).
    # @note Roles are NOT permissions! You should NOT in 98.7% of cases do anything based on Roles.
    # @note The default args are configured such that userRoles() works well after the "find_project" before_filter
    #   and within a real Rails session. The args can be supplied when there is no project--global plugin settings code mayber--
    #   or you need to do things for a different user (shim user, you are implementing Administrator functionality, etc).
    # @param [Project] project Optional, default from find_project before_filter. The project to find user Roles for.
    # @param [User] user Optional, default {User.current}. The user to find Roles for.
    # @return [Array<Role>] List of Roles user has in project, if any.
    def userRoles( project=@project, user=(@currRmUser or User.current) )
      return user.roles_for_project( project )
    end

    # Get a map of permission=>value for the user.
    def userPerms(pluginId, project=@project, user=(@currRmUser or User.current) )
      # @param [Symbol] pluginId Permission context: the id of the plugin for which we want permission info.
      # @param [Project] project Optional. Permission context: the project object for which we want permission info.
      #   Defaults to @@project@ which should be set by now.
      # @param [User] user Optional. The user for which we want permission info. Defaults to @@currRmUser@
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
    # @param [User] user Optional. The user for which we want permission info. Defaults to @@currRmUser@
    # @param [Hash{Symbol,Object}] Optional. The options Hash to override default behavior. Can be used to have
    #   this method return a Javascript hash in a string, for embedding permissions map in browser pages rather
    #   than the default Ruby hash.
    # @return [Hash{Symbol,Boolean}] The permission map for the user in the context of plugin and project.
    def pluginUserPerms(plugin, project=@project, user=(@currRmUser or User.current), opts={ :as => :hash})
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

    # Checks whether a role has a particular permission
    # @param [String] roleName name of the role
    # @param [Symbol] permSym redmine permission
    # @return [Boolean] retVal
    def roleHasPerm?( roleName, permSym )
      retVal = false
      roles = Role.where( :name => roleName )
      if( roles and !roles.empty?  and roles.size == 1 )
        role = roles.first
        retVal = role.permissions.include?( permSym )
      end
      return retVal
    end


  end
end
