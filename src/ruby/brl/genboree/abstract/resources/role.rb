#!/usr/bin/env ruby

#==
# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

#--
module BRL ; module Genboree ; module Abstract
#++

# To aid in the exposure and representations of Genboree resources, and to
# improve organization a bit, resource-specific classes and modules here
# implement behaviors specific to that resource.
#
# The idea is have "Helper" classes and modules without throwing all
# the methods in together in a generic Helper module (e.g. like BRL::Genboree::REST::Helpers).
#
# Also to provide a means for sharing common behaviors in different areas of
# the Genboree related code, rather than having area-specific Helper methods that
# are cumbersome to use elsewhere outside of that area (e.g. like BRL::Genboree::REST::ProjectApiHelpers)
#
# Either modules (should be named ____Helper) with methods to be mixed into other classes
# or classes likely containing useful class methods that can be called from anywhere, should
# be placed here.
module Resources
  # Role - This class implements behaviors related to Roles, especially roles of users within user groups.
  class Role
    # Defines the Role Names assigned to the userGroupAccess value stored in DB table usergroup
    ROLE_NAMES = {'r' => 'subscriber', 'w' => 'author', 'o' => 'administrator', 'p' => 'public'}
    # Invert of ROLE_NAMES
    ACCESS_LEVELS = {'subscriber' => 'r', 'author' => 'w', 'administrator' => 'o'}

    # Translates userGroupAccess used in the database to User Role as used in Genboree.
    # See Role.accessFromRole() for reverse mappings.
    #
    # [+userGroupAccess+] +String+; must be a key in ROLE_NAMES
    # [+returns+] Role name +String+
    def self.roleFromAccess(userGroupAccess)
      ug = userGroupAccess.to_s.downcase.strip
      if(ROLE_NAMES.key?(ug))
        ROLE_NAMES[ug]
      else
        raise "Invalid userGroupAccess #{userGroupAccess.inspect}"
      end
    end

    # Translates Role as used in Genboree to userGroupAccess used in DB.
    # See Role.roleFromAccess() for reverse mappings.
    #
    # [+userGroupAccess+] +String+; must be a role name, a key of ACCESS_LEVELS
    # [+returns+] +String+; access level char.
    def self.accessFromRole(role)
      rl = role.to_s.downcase.strip
      if(ACCESS_LEVELS.key?(rl))
        ACCESS_LEVELS[rl]
      else
        raise "invalid role #{role.inspect}"
      end
    end

    # Get the ROLE_NAMES hash.
    #
    # [+upCase+] +boolean+; true will return capitalized names
    # [+returns+] the ROLE_NAMES hash
    def self.getRoleNames(upCase=false)
      if(upCase)
        ROLE_NAMES.each { |key, rn| rn.upcase! }
      else
        ROLE_NAMES
      end
    end

    # This method gets the role for a user in a group.
    #
    # [+dbu+] Instance of DbUtil, ready to do DB work.
    # [+userId+] +Integer+; the user's id.
    # [+groupId+] +Integer+; the user group's id.
    # [+returns+] Role name or +nil+ if the user isn't in the group
    def self.getRoleByUserIdAndGroupId(dbu, userId, groupId)
      currentAccessRow = dbu.getAccessByUserIdAndGroupId(userId, groupId)
      return (currentAccessRow.nil? or currentAccessRow.empty?) ? nil : self.roleFromAccess(currentAccessRow['userGroupAccess'])
    end

    # This method will insert or update a usergroup record.
    # - Only group administrators (accessLevel == 'o') should have access to this method (not enforced here)
    #
    # [+dbu+] Instance of DbUtil, ready to do DB work.
    # [+userId+] +Integer+; the user's id.
    # [+groupId+] +Integer+; the user group's id.
    # [+roleName+] +String+ should be a genboree group role name (a key of ROLE_NAMES)
    # [+permissionBits+] [optional; default=nil] This is currently unimplemented so won't update in DB
    # [+returns+] Status as used in BRL::Genboree::REST::GenboreeResource#statusName; a +Symbol+ where :OK indicates success.
    def self.addUserGroupAccessToDb(dbu, userId, groupId, roleName, permissionBits=nil)
      retVal = :OK
      accessLevel = BRL::Genboree::Abstract::Resources::Role.accessFromRole(roleName)
      # if user is already in the group, update their permissions
      currentAccessRow = dbu.getAccessByUserIdAndGroupId(userId, groupId)
      if(currentAccessRow.nil?)
        rowsChanged = dbu.insertUserIntoGroupById(userId, groupId, accessLevel)
        retVal = :'Failed insertUserIntoGroupById' if(rowsChanged.nil? or rowsChanged < 1)
      else
        currentAccess = currentAccessRow['userGroupAccess']
        if(currentAccess != accessLevel)
          rowsChanged = dbu.updateAccessByUserIdAndGroupId(userId, groupId, accessLevel)
          retVal = :"Failed updateAccessByUserIdAndGroupId" if(rowsChanged.nil? or rowsChanged < 1)
        else
          # do nothing, user is already in group with specified access
          retVal = :OK
        end
      end
      return retVal
    end

    # Deletes a usergroup record.
    # - Only group administrators (accessLevel == 'o') should have access to this method (not enforced here)
    #
    # [+dbu+] Instance of DbUtil, ready to do DB work.
    # [+userId+] +Integer+; the user's id.
    # [+groupId+] +Integer+; the user group's id.
    # [+roleName+] +String+ should be a genboree group role name (a key of ROLE_NAMES)
    # [+returns+] Status as used in BRL::Genboree::REST::GenboreeResource#statusName; a +Symbol+ where :OK indicates success.
    def self.deleteUserGroupAccessFromDb(dbu, userId, groupId)
      retVal = :OK
      rowsChanged = dbu.deleteUserFromGroup(userId, groupId)
      retVal = :"Failed deleteAccessByUserIdAndGroupId" if(rowsChanged.nil? or rowsChanged < 1)
      return retVal
    end

  end
end ; end ; end ; end
