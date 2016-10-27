#!/usr/bin/env ruby

require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/abstract/resources/project'

module BRL ; module Genboree
  class ProjectManagement
    # To save some typing, we'll create a shorter alias for the Abstract::Resources namespace.
    Abstract = BRL::Genboree::Abstract::Resources

    ERR_CODES = {
                  :OK => true,
                  :INVALID_NAME => "The project name uses characters that are not allowed.",
                  :USES_RESERVED_WORD => "Project name uses a reserved word; do not use 'genb^^' as part of project names.",
                  :ALREADY_EXISTS => "Trying to create a top-level project that already exists in Genboree; try a different project name.",
                  :DOESNT_EXIST => "Project doesn't exist.",
                  :FATAL => "Severe error occured trying to create project.",
                  :DEPTH_NOT_SAME => "Renaming a sub-project cannot change the depth (level or degree of nesting) of the sub-project.",
                  :PATHS_NOT_SAME => "Renaming a sub-project cannot move the sub-project from one branch to a different branch.",
                  :ACCESS_DENIED => "User does not have sufficient access to the group to modify its projects.",
                  :SESS_GROUP_NOT_SYNC => "The project's group doesn't match the current group (e.g. in the web session)."
                }
    PROJ_SUBDIRS = [ 'genb^^required', 'genb^^optional', 'genb^^additionalPages', 'genb^^additionalFiles' ]
    PROJ_EMPTY_FILES =  [
                          'genb^^required/description.part', 'genb^^required/title.part',
                          'genb^^optional/customLinks.json', 'genb^^optional/quickLinks.json',
                          'genb^^optional/updates.json', 'genb^^optional/content.part',
                          'genb^^additionalPages/projectAdditionalPages.json',
                          'genb^^additionalFiles/projectFiles.json'
                        ]



    # TODO: this class has lost many many methods. Check all .rb and all .rhtml
    # to see if they called some of those methods and fix the calling code.

    # Supports the creation of top-level projects as well as sub-projects
    # (nested projects).
    # - sub-projects have names of the form "<proj>/<subProj>" in general
    #   (so "<proj>/<subProj>/<subSubProj>" is possible); a parent project
    #   can have any number of sub-projects.
    # - sub-projects are subordinate to their parent project and may have
    #   limited representation in the Genboree database (for example: currently
    #   sub-projects have no entry in the 'projects' table)
    # - this method will create parent projects iff they don't exist
    # - context is presumed to contain the :dbu, :groupId, and :userId keys, whose value
    #   are valid DBUtil instance connected to the main genboree database, the group
    #   where the project will live, and the userId of the user who is performing these
    #   actions
    #
    # TAC => Added overrideGroupId to be able to specify the group that the proj is added to
    def self.createNewProject(projName, context, overrideGroupId=nil)
      retVal = :OK
      dbu, userId = context[:dbu], context[:userId]
      groupId = (overrideGroupId.nil?) ? context[:groupId] : overrideGroupId
      projName.strip!
      begin
        # First, check the user's access and that we're doing this from a sensible
        # place (e.g. groupId from session matches project's group)
        retVal = Abstract::Project.checkAccess(projName, context[:groupId], context[:userId])
        if(retVal == :OK)
          subProjects = projName.split(/\//)
          topLevelProject = subProjects.shift
          # 1) Ensure projName is a valid-looking project name
          noReserved = Abstract::Project.validateProjectName(projName, dbu)
          if(noReserved == :OK)
            # 2) Read Genboree config file:
            projBaseDir = context.genbConf.gbProjectContentDir
            # 3) Process top-level project.
            # - If no sub-projects in projName then we are creating ONLY a top-level project.
            #   In this case we currently do NOT allow top-level projects with the
            #   same name.
            # - If there are 1+ sub-projects, then the top-level project MUST already
            #   exist ; if the sub-project already exists, then nothing will be done
            projects = dbu.getProjectsByName(topLevelProject)
            if(subProjects.empty?)
              # Making new top-level project. Cannot already exist.
              if(projects.nil? or projects.empty?)
                # new top-level project ok, doesn't exist.
                ProjectManagement.createProjectTree(projBaseDir, topLevelProject, context)
                # insert new record for top-level project into projects table
                rowsChanged = dbu.insertProject(projName, groupId)
                retVal = :FATAL if(rowsChanged.nil? or rowsChanged < 1)
              else
                retVal = :ALREADY_EXISTS
              end
            else # Creating a sub-project or nested set of sub-projects.
              # Make sure top-level project already exists
              retVal = :DOESNT_EXIST if(projects.nil? or projects.empty?)
            end

            if(retVal == :OK) # If we didn't encounter a problem with the top-level project then:
              # 4) Create sub-project (may be nested...will create all)
              projBaseDir = "#{projBaseDir}/#{CGI.escape(topLevelProject)}"
              while(!subProjects.empty?)
                subProject = subProjects.shift
                # create dir tree
                ProjectManagement.createProjectTree(projBaseDir, subProject, context)
                # prep for any sub-projects by growing projBaseDir
                projBaseDir = "#{projBaseDir}/#{CGI.escape(subProject)}"
              end
            end
          else # project name uses a reserved word somewhere or is an invalid name somehow
            retVal = noReserved
          end
        end
      rescue => err
        $stderr.puts "-"*50
        $stderr.puts  "ERROR: ProjectManagement.createNewProject(p,c) => problem creating project.\n" +
                      "- Exception: #{err.message}\n" +
                      err.backtrace.join("\n")
        $stderr.puts "-"*50
        retVal = :FATAL
      end
      return retVal
    end

    # This method will rename a project or sub-project.
    # If renaming a sub-project, the new name must be at the same level as the old.
    # - sub-projects have names of the form <proj>/<subProf> or <proj>/<subProj>/<subSubProj>
    # - context is presumed to contain the :dbu, :groupId, and :userId keys, whose value
    #   are valid DBUtil instance connected to the main genboree database, the group
    #   where the project will live, and the userId of the user who is performing these
    #   actions
    def self.renameProject(projName, newProjName, context)
      retVal = :OK
      dbu, groupId = context[:dbu], context[:groupId]
      projName.strip!
      begin
        # First, check the user's access and that we're doing this from a sensible
        # place (e.g. groupId from session matches project's group)
        retVal = Abstract::Project.checkAccess(projName, context[:groupId], context[:userId])
        if(retVal == :OK)
          newProjName.strip!
          subProjects = projName.split(/\//)
          topLevelProject = subProjects.shift
          newSubProjects = newProjName.split(/\//)
          newTopLevelProject = newSubProjects.shift
          # 1) Is there the same degree of depth in the two project names?
          if(subProjects.size == newSubProjects.size)
            # 2) Prefixes must match (can't hop to other branches)
            pathsMatch = ProjectManagement.checkPathsMatch(topLevelProject, subProjects, newTopLevelProject, newSubProjects)
            if(pathsMatch)
              # 2) Ensure projName doesn't involve reserved names:
              noReserved = Abstract::Project.validateProjectName(newProjName, dbu)
              if(noReserved == :OK)
                # 3) Read Genboree config file:
                projBaseDir = context.genbConf.gbProjectContentDir
                # 4) Check that old dir already exists
                oldProjDir = Abstract::Project.constructProjDir(projName, context.genbConf)
                if(File.exist?(oldProjDir))
                  # 5) Check that the new dir doesn't already exist
                  newProjDir = Abstract::Project.constructProjDir(newProjName, context.genbConf)
                  unless(File.exist?(newProjDir))
                    # 6) Change dir name & remake the symlink
                    FileUtils.mv(oldProjDir, newProjDir)
                    projLink = "#{projBaseDir}/#{projName}"
                    FileUtils.rm_f(projLink)
                    newProjLink = "#{projBaseDir}/#{newProjName}"
                    FileUtils.ln_s(newProjDir, newProjLink) unless(newProjDir == newProjLink) # if same, then escaping not needed
                    # 7) If renaming the top-level dir, then we need to update the database also
                    if(subProjects.empty?)
                      # Get project id
                      projects = dbu.getProjectsByName(projName, groupId) # <-- should only return 1 record since project names are even globally unique
                      projId = projects.first['id']
                      # Update project
                      rowsChanged = dbu.updateProjectNameById(newProjName, projId)
                      retVal = :FATAL if(rowsChanged.nil? or rowsChanged < 1)
                    end
                  else
                    retVal = :ALREADY_EXISTS
                  end
                else # old proj dir doesn't exist
                  retVal = :DOESNT_EXIST
                end
              else # new name uses a reserved word
                retVal = noReserved
              end
            else
              retVal = :PATHS_NOT_SAME
            end
          else # new name doesn't have the same depth as old name
            retVal = :DEPTH_NOT_SAME
          end
        end
      rescue => err
        $stderr.puts "-"*50
        $stderr.puts  "ERROR: ProjectManagement.renameProject(p,c) => problem renaming project.\n" +
                      "- Exception: #{err.message}\n" +
                      err.backtrace.join("\n")
        $stderr.puts "-"*50
        retVal = :FATAL
      end
      return retVal
    end

    # This method deletes a project or sub-project.
    # - sub-projects have names of the form <proj>/<subProf> or <proj>/<subProj>/<subSubProj>
    # - deletion will "remove" all nested sub-projects below projName as well
    # - context is presumed to contain the :dbu, :groupId, and :userId keys, whose value
    #   are valid DBUtil instance connected to the main genboree database, the group
    #   where the project will live, and the userId of the user who is performing these
    #   actions
    def self.deleteProject(projName, context)
      retVal = :OK
      dbu, groupId = context[:dbu], context[:groupId]
      projName.strip!
      begin
        # First, check the user's access and that we're doing this from a sensible
        # place (e.g. groupId from session matches project's group)
        retVal = Abstract::Project.checkAccess(projName, context[:groupId], context[:userId])
        if(retVal == :OK)
          # 1) Get subproj info
          subProjects = projName.split(/\//)
          topLevelProject = subProjects.shift
          # 2) Get the project's dir:
          projDir = Abstract::Project.constructProjDir(projName, context.genbConf)
          projBaseDir = context.genbConf.gbProjectContentDir
          if(File.exist?(projDir))
            # 3) "Delete" proj dir.
            # NOTE: We do NOT delete project directory * symlink in case the deletion was accidental. We do rename them though.
            newSuffix = ".GENB_DELETED.#{Time.now.to_i}.#{rand(100000)}"
            newProjDir = "#{projDir}#{newSuffix}"
            projLink = "#{projBaseDir}/#{projName}"
            newProjLink = "#{projLink}#{newSuffix}"
            File.rename(projDir, newProjDir)
            FileUtils.rm_f(projLink)
            FileUtils.ln_s(newProjDir, newProjLink)

            # 4) If deleting the top-level dir, then we need to update the database also
            if(subProjects.empty?)
              # Get project Id for top-level proj
              projects = dbu.getProjectsByName(topLevelProject, groupId) # <-- should only return 1 record since project names are even globally unique
              projId = projects.first['id']
              # Update project
              rowsChanged = dbu.deleteProjectById(projId)
              retVal = :FATAL if(rowsChanged.nil? or rowsChanged < 1)
            end
          else
            retVal = :DOESNT_EXIST
          end
        end
      rescue => err
        $stderr.puts "-"*50
        $stderr.puts  "ERROR: ProjectManagement.deleteProject(p,c) => problem deleting project.\n" +
                      "- Exception: #{err.message}\n" +
                      err.backtrace.join("\n")
        $stderr.puts "-"*50
        retVal = :FATAL
      end
      return retVal
    end

    def self.moveProjectById(projId, targetGroupId, context)
      retVal = :OK
      dbu = context[:dbu]
      begin
        # ensure that user is admin of both groups
        hasAccessToSourceGroup = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(context[:userId], context[:groupId], 'o', dbu)
        hasAccessToTargetGroup = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(context[:userId], targetGroupId, 'o', dbu)
        if (hasAccessToTargetGroup and hasAccessToSourceGroup)
          # Update project
          rowsChanged = dbu.updateProjectGroupById(projId, targetGroupId)
          retVal = :FATAL if(rowsChanged.nil? or rowsChanged < 1)
        else
          retVal = :ACCESS_DENIED
        end
      rescue => err
        $stderr.puts "-"*50
        $stderr.puts  "ERROR: ProjectManagement.moveProjects => problem moving project.\n" +
                      "- Exception: #{err.message}\n" +
                      err.backtrace.join("\n")
        $stderr.puts "-"*50
        retVal = :FATAL
      end
      return retVal
    end

    # This method creates a new project and copies the content from a source project
    #
    # +srcProjId+:: Int, Id of the source project containing the content that should be copied
    # +destProjName+:: String, the name of the new project
    # +targetGroupId+:: Int, Id of the group that the project will be added to
    # +context+:: must contain userId, dbu
    def self.copyProject(srcProjId, destProjName, targetGroupId, context)
      retVal = :OK
      dbu = context[:dbu]
      begin
        projRow = dbu.getProjectById(srcProjId)
        # ensure that user is admin of both groups
        hasAccessToSourceProj = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(context[:userId], projRow['groupId'], 'o', dbu)
        hasAccessToTargetGroup = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(context[:userId], targetGroupId, 'o', dbu)
        if(hasAccessToTargetGroup and hasAccessToSourceProj)
          retVal = ProjectManagement.createNewProject(destProjName, context, targetGroupId)
          if(retVal == :OK)
            srcProjName = projRow['name']
            retVal = ProjectManagement.copyProjectTree(srcProjName, destProjName)
          end
        else
          retVal = :ACCESS_DENIED
        end
      rescue => err
        $stderr.puts "-"*50
        $stderr.puts  "ERROR: ProjectManagement.copyProject => problem copying project.\n" +
                      "- Exception: #{err.message}\n" +
                      err.backtrace.join("\n")
        $stderr.puts "-"*50
        retVal = :FATAL
      end
      return retVal
    end

    # --------------------------------------------------------------------------
    # HELPERS
    # --------------------------------------------------------------------------
    # Checks if the path to the last nested project match
    # - this asserts the no-branch-hopping criterion for renaming
    def self.checkPathsMatch(topLevelProject, subProjects, newTopLevelProject, newSubProjects)
      retVal = true
      # if renaming top-level project, then everything is ok
      unless(subProjects.empty? and newSubProjects.empty?)
        oldPath = CGI.escape(topLevelProject)
        subProjects.each_index {|ii|
          break if(ii == subProjects.size-1)
          oldPath = "#{oldPath}/#{CGI.escape(subProjects[ii])}"
        }
        newPath = CGI.escape(newTopLevelProject)
        newSubProjects.each_index {|ii|
          break if(ii == newSubProjects.size-1)
          newPath = "#{newPath}/#{CGI.escape(newSubProjects[ii])}"
        }
        retVal = (oldPath == newPath)
      end
      return retVal
    end

    # Creates a single project tree under baseDir.
    # Doesn't look for nor create subprojects.
    # Used by createNewProjects to create the top-level project AND any
    # sub-projects if present via repeated calls (one for each nested project)
    def self.createProjectTree(baseDir, projName, context)
      # create main project dir via escaped name
      escProjName = CGI.escape(projName)
      newProjDir = "#{baseDir}/#{escProjName}"
      unless(File.exist?(newProjDir)) # if exists, probably sub-proj that is already made previously; if not it will be made now
        FileUtils.mkdir_p(newProjDir)
        # symlink unescaped name
        newProjLink = "#{baseDir}/#{projName}"
        FileUtils.ln_s(newProjDir, newProjLink) unless(newProjDir == newProjLink)
        # create standard subdirs
        PROJ_SUBDIRS.each { |subdir|
          FileUtils.mkdir_p("#{newProjDir}/#{subdir}")
        }
        # populate with empty context
        PROJ_EMPTY_FILES.each { |eFile|
          FileUtils.touch("#{newProjDir}/#{eFile}")
        }
        File.open("#{newProjDir}/genb^^required/title.part", "w") { |file|
          file.puts CGI.escapeHTML(projName)
        }
        File.open("#{newProjDir}/genb^^required/description.part", "w") { |file|
          file.puts "<i>[[ Put description for the project '#{CGI.escapeHTML(projName)}' here ]]</i>"
        }
      end
      return true
    end

    # Copies recursively the entire project tree under srcProjName.
    # Used by copyProjects
    # This method assumes that both projects exist
    #
    # NOTE: This method OVERWRITES the files in the destination project
    #
    # +srcProjName+:: string, destination project name, unescaped project dir name
    # +destProjName+:: string, destination project name, unescaped project dir name
    # +returns+:: status
    def self.copyProjectTree(srcProjName, destProjName)
      retVal = :OK
      if(srcProjName.strip == '' or destProjName.strip == '')
        retVal = :FATAL
      else
        # get baseDir defined in config file
        genbConf = BRL::Genboree::GenboreeConfig.load()
        baseDir = genbConf.gbProjectContentDir
        # create main project dir via escaped name
        escSrcProjName = CGI.escape(srcProjName)
        escDestProjName = CGI.escape(destProjName)
        newDestProjDir = "#{baseDir}/#{escDestProjName}"
        srcProjDir = "#{baseDir}/#{escSrcProjName}"
        if(File.exist?(srcProjDir) and File.exist?(newDestProjDir))
          # Copy all the files to the new project
          FileUtils.cp_r("#{srcProjDir}/.", newDestProjDir, :remove_destination => true)
        else
          retVal = :'Not Found'
        end
      end
      return retVal
    end

    # Validates a project name
    # +returns+ status code
    def self.validateNewProjectName(dbu, projectName)
      nameValid = Abstract::Project.validateProjectName(projectName, dbu)
      if(retVal == :OK)
        nameExists = ProjectManagement.projectNameExists(dbu, projectName)
        retVal = :ALREADY_EXISTS if(nameExists)
      end
      return retVal
    end

    # TODO: move this to Project Class method?
    # Checks that a project name isn't already used
    # +returns+ boolean
    def self.projectNameExists(dbu, projectName)
      retVal = false
      projects = dbu.getProjectsByName(projectName)
      if(projects.nil? or projects.empty?)
        retVal = false
      else
        retVal = true
      end
      return retVal
    end

    def self.getErrMsg(errCode)
      return ERR_CODES[errCode]
    end
  end
end ; end
