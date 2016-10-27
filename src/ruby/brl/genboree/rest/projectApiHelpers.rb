#!/usr/bin/env ruby
require 'uri'
require 'rack'
require 'brl/util/util'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/projectManagement/projectManagement'
require 'brl/genboree/rest/data/textEntity'

module BRL      #:nodoc:
module Genboree #:nodoc:
module REST     #:nodoc:

# == Project-Specific Helper methods
# Assortment of helper methods used to do some Project-related manipulations
# using the API. This module is mixed into resource subclasses doing this kind of task.
#
# Most of the initialization of appropriate state (instance variables)
# for dealing with Projects is done via methods within BRL::Genboree::REST::Helpers.
#
# <i>NOTE: try to avoid adding to this grab-bag module. Instead, create Classes and
# Modules within BRL::Genboree::REST::Abstract::Resources that implement the
# necessary behaviors to mix-in or to directly call.</i>
module ProjectApiHelpers

  # Create a new project. Should create the project, handle errors and return appropriate response
  #
  # If @projName is available, then the name of the new project came directly from
  # a rsrcPath. If not available then the rsrcPath refers _generically_ to the collection of "projects" and
  # we're PUT-ing the new project indicated in the response body into that collection.
  #
  # [+reqBodyEntity+] [optional; default=''] The BRL::Genboree::REST::Data::TextEntity object
  #             resulting from parsing the request body. Contains the name of the new project.
  #             Only needed if @projName is not available and thus we're PUT-ing to the generic collection of projects.
  # [+returns+] +Array+ containing @statusName, @statusMsg
  def createProject(reqBodyEntity='')
    newProjName = ''
    if(@projName) # from project.rb, project name in URI
      newProjName = @projName
      if(reqBodyEntity != '')
        unless(reqBodyEntity.text == @projName) # Ensure the names match
          @statusName = :'Unsupported Media Type'
          @statusMsg = "The project name '#{@projName}' could not be found, and the project name in the request body '#{reqBodyEntity.text}' does not match"
        end
      end
    else
      if(reqBodyEntity.text)
        newProjName = reqBodyEntity.text
      else
        @statusName = :'Unsupported Media Type'
        @statusMsg = "Could not get project name from request"
      end
    end
    if(newProjName != '' and @statusName != :'Unsupported Media Type')
      createStatus = BRL::Genboree::ProjectManagement.createNewProject(newProjName, @context)
      if(createStatus == :OK)
        @statusName = :'Created'
        @statusMsg = "Created: The project #{newProjName.inspect} has been created."
      else
        case createStatus
          when :ALREADY_EXISTS
            @statusName = :'Conflict'
            @statusMsg = "ALREADY_EXISTS: Cannot create #{newProjName.inspect} because a project with that name already exists."
          when :DOESNT_EXIST
            @statusName = :'Not Found'
            @statusMsg = "NO_PRJ: The parent project does not exist. Cannot create the sub-project unless the parents already exist."
          when :USES_RESERVED_WORD
            @statusName = :'Bad Request'
            @statusMsg = "USES_RESERVED_WORD: The new project name contains a reserved word and is not allowed."
          else # Unknown error, just convert retVal to a generic error
            @statusName = :'Internal Server Error'
            @statusMsg = "FATAL: (#{createStatus.inspect}) Server error occurred trying to create the project #{newProjName.inspect} in user group #{@groupName.inspect}."
        end
      end
    end
    return [@statusName, @statusMsg]
  end # def createProject()

  # Copy a project. The target project name must be globally unique, but may or may not
  # be in the same user group as the source. The Project indicated in the rsrcPath
  # is copied to the resource provided in the +RefEntity+ represented in the request body.
  # It should handle errors and return an appropriate API response code and message.
  #
  # This method calls the methods that:
  # - parse the req body for source project URL
  # - validate the source project URL
  # - create and copy the project
  #
  # [+reqBodyEntity+] The BRL::Genboree::REST::Data::RefEntity object
  #                   resulting from parsing the request body. The copy target.
  # [+returns+]       +Array+ containing @statusName, @statusMsg
  def copyProject(reqBodyEntity)
    # If the resource is a project copy it's contents
    # It would be useful to have a method that determines or validates the resourse type
    # parseProjectUrl returns status and data if OK see comments for method
    @statusName, hostName, @pldGroupName, @pldProjName = parseProjectUrl(reqBodyEntity.url)
    if(@statusName != :OK)
      @statusMsg = "The resource you have specified in the request body is not valid"
    end
    # Validate the URI in the request body
    # - Check that the host is the same
    if(hostName != @rsrcHost)
      @statusName = :'Not Implemented'
      @statusMsg = "The resource you have specified in the request body has a different host name.  This functionality is not implemented."
    else
      # - Check that the group exists
      groupRows = dbu.selectGroupByName(@pldGroupName)
      if(groupRows.nil? or groupRows.empty?)
        @statusName = :'Bad Request'
        @statusMsg = "The resource you have specified in the request body has a group that could not be found."
      else
        # - Check that the user is admin of the group
        pldGroupId = groupRows.first['groupId']
        userHasAccessToSource = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(@userId, pldGroupId, 'o', @dbu)
        unless(userHasAccessToSource)
          @statusName = :'Forbidden'
          @statusMsg = "You do not have access to the requested group in the request body."
        else
          # - Check that the project exists and that the project is part of the group
          projRow = dbu.getProjectsByName(@pldProjName, pldGroupId)
          if(projRow.nil? or projRow.empty?)
            @statusName = :'Bad Request'
            @statusMsg = "The resource you have specified in the request body has a project that could not be found."
          else
            srcProjId = projRow.first['id']
          end
        end
      end
    end
    if(@statusName == :OK and srcProjId > 0)
      # The copyProject method creates the new project and copies project data
      copyStatus = BRL::Genboree::ProjectManagement.copyProject(srcProjId, @projName, @groupId, @context)
      if(copyStatus == :OK)
        @statusName = :'Created'
        @statusMsg = "The project #{@projName} has been created and the contents have been copied from project #{@pldPrjName}"
      else # Need to be able to handle both create errors or copy errors
        case copyStatus
          when :ALREADY_EXISTS
            @statusName = :'Conflict'
            @statusMsg = "ALREADY_EXISTS: Cannot create #{newProjName.inspect} because a project with that name already exists."
          when :DOESNT_EXIST
            @statusName = :'Not Found'
            @statusMsg = "NO_PRJ: The parent project does not exist. Cannot create the sub-project unless the parents already exist."
          when :SOURCE_NOT_FOUND
            @statusName = :'Bad Request'
            @statusMsg = "NO_PRJ: The source project does not exist. Check the resource specified in the body of the request."
          when :ACCESS_DENIED
            @statusName = :Forbidden
            @statusMsg = "You do not have access to the requested project."
          when :USES_RESERVED_WORD
            @statusName = :'Bad Request'
            @statusMsg = "USES_RESERVED_WORD: The new project name contains a reserved word and is not allowed."
          else # Unknown error, just convert retVal to a generic error
            @statusName = :'Internal Server Error'
            @statusMsg = "FATAL: (#{copyStatus.inspect}) Server error occurred trying to copy the project #{@pldProjName.inspect} to #{@projName.inspect} in user group #{@groupName.inspect}."
        end
      end
    end
    return [@statusName, @statusMsg]
  end

  # Updates the referenced Project, which is to say it renames it.
  # Checks usual rules about project uniqueness and renaming only at the same level, etc.
  #
  # [+reqBodyEntity+] The BRL::Genboree::REST::Data::TextEntity object
  #                   resulting from parsing the request body. Contains the project's new name.
  # [+returns+] +Array+ containing @statusName, @statusMsg
  def updateProject(reqBodyEntity)
    if(reqBodyEntity.is_a?(BRL::Genboree::REST::Data::TextEntity))
      # Get new name from the TextEntity in the body
      newProjName = reqBodyEntity.text
      # Rename project
      retVal = BRL::Genboree::ProjectManagement.renameProject(@projName, newProjName, @context)
      if(retVal == :OK)
        @statusName = :'Moved Permanently'
        @statusMsg = "RENAMED: Project #{@projName.inspect} successfully renamed to #{newProjName.inspect}."
        @projName = newProjName
      else
        case retVal
          when :ALREADY_EXISTS
            @statusName = :'Conflict'
            @statusMsg = "ALREADY_EXISTS: Cannot rename #{@projName.inspect} to #{newProjName} because a project with that name already exists."
          when :DOESNT_EXIST
            @statusName = :'Not Found'
            @statusMsg = "NO_PRJ: There is no project #{@projName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
          when :USES_RESERVED_WORD
            @statusName = :'Bad Request'
            @statusMsg = "USES_RESERVED_WORD: The new project name contains a reserved word and is not allowed."
          when :PATHS_NOT_SAME
            @statusName = :'Bad Request'
            @statusMsg = "PATHS_NOT_SAME: Cannot use rename to move a sub-project to a different branch/path."
          when :DEPTH_NOT_SAME
            @statusName = :'Bad Request'
            @statusMsg = "DEPTH_NOT_SAME: Cannot use rename to change the depth of the sub-project in this branch/path."
          else # Unknown error, just convert retVal to a generic error
            @statusName = :'Internal Server Error'
            @statusMsg = "FATAL: (#{retVal.inspect}) Server error occurred trying to rename the project #{@projName.inspect} in user group #{@groupName.inspect} to #{newProjName.inspect}."
        end
      end
    else # new project name is empty, not allowed
      @statusName = :'Bad Request'
      @statusMsg = "BAD_REP: The new project name can not be determined from the request body.  Failed to update project: #{@projName.inspect}"
    end
    return [@statusName, @statusMsg]
  end

  # Parse the resource path in +url+ to extract the group and project name, when
  # the URL is provided via a +RefEntity+ for example.
  #
  # Used by #copyProject.
  # [+url+]     A URL +String+ indicating a specific Genboree Project.
  # [+returns+] Array of +[status, hostName, groupName, projName]+
  def parseProjectUrl(url)
    retStatus = :OK
    hostName, groupName, projName = nil
    uri = URI.parse(url)
    if(uri.nil?)
      retStatus = :"Unsupported Media Type"
    else
      path = uri.path
      hostName = uri.host
      #path =~ BRL::Genboree::REST::Resources::Project.pattern()
      path =~ %r{^/REST/v1/grp/([^/\?]+)/prj/([^/\?]+)$}
      # Refer to pattern to see match data
      if($~)
        groupName, projName = $~[1], $~[2]
      else
        retStatus = :"Unsupported Media Type"
      end
    end
    return [retStatus, hostName, groupName, projName]
  end
end ; end ; end ; end # module BRL ; module Genboree ; module REST
