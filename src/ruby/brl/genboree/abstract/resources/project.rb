
require 'json'
require 'brl/util/util'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/projectTitleImage'
require 'brl/genboree/abstract/resources/projectTitle'
require 'brl/genboree/abstract/resources/projectDescription'
require 'brl/genboree/abstract/resources/projectCustomContent'
require 'brl/genboree/abstract/resources/projectQuickLinks'
require 'brl/genboree/abstract/resources/projectLinks'
require 'brl/genboree/abstract/resources/projectNews'
require 'brl/genboree/abstract/resources/projectFiles'
require 'brl/genboree/abstract/resources/projectPages'

# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

module BRL ; module Genboree ; module Abstract ; module Resources
  CachedProjInfo = Struct.new(:projId, :state, :projNameToPath, :parentProjName, :fullParentProjName, :escParentProjName, :escFullParentProjName)

  # ProjectModule - This Module implements behaviors related user Projects and is mixed into certain other classes
  module ProjectModule
    # This method fetches all key-value pairs from the associated +project+
    # AVP tables.  Project is specified by project id.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+project+] DB id of the project to query AVPs for.
    # [+returns+] A +Hash+ of the AVP pairs associated with this project.
    def getAvpHash(dbu, projectId)
      retVal = {}
      project2attrRows = dbu.selectProject2AttributesByProjectId(projectId)
      unless(project2attrRows.nil? or project2attrRows.empty?)
        project2attrRows.each { |row|
          keyRows = dbu.selectProjectAttrNameById(row['projectAttrName_id'])
          key = keyRows.first['name'] unless (keyRows.nil? or keyRows.empty?)
          valueRows = dbu.selectProjectAttrValueById(row['projectAttrValue_id'])
          value = valueRows.first['value'] unless (valueRows.nil? or valueRows.empty?)
          retVal[key] = value
        }
      end
      return retVal
    end

    # This method completely updates all of the associated AVP pairs for
    # the specified +project+.  This method examines existing AVPs and changes
    # values as appropriate, but also looks for any pairs that exist in the
    # DB but not the new +Hash+, and removes those relationships, making it
    # possible to delete AVP pairs by removing them from the +Hash+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+projectId+] DB Id of the +project+ for which to update the AVPs.
    # [+newHash+] A +Hash+ representing all of the AVP pairs to associate with
    #   the specified +project+.  This includes existing AVP pairs that are not
    #   to be changed.  Only updated, new, or missing AVP pairs will be handled.
    # [+returns+] +true+ when everything has succeeded, +false+ when any errors
    #   have occurred (check standard error for details).
    def updateAvpHash(dbu, projectId, newHash)
      retVal = true
      newHash = {} if(newHash.nil?)
      begin
        oldHash = getAvpHash(dbu, projectId)
        if(oldHash.nil? or oldHash.empty?)
          # AVP hash didn't exist before, insert all keys and values
          newHash.each { |attrName,attrValue|
            insertAvp(dbu, projectId, attrName, attrValue)
          }
        else
          # AVP hash exists, check all key/value pairs for changes
          oldHash.each_key { |oldKey|
            oldVal = oldHash[oldKey]
            if(newHash.include?(oldKey))
              if(newHash[oldKey] != oldVal)
                rowsUpdated = insertAvp(dbu, projectId, oldKey, newHash[oldKey], :update)
              end
              newHash.delete(oldKey)
            else
              keyRow = dbu.selectProjectAttrNameByName(oldKey)
              key = keyRow.first
              rowsDeleted = dbu.deleteProject2AttributesByProjectIdAndAttrNameId(projectId, key['id'])
            end
          }
          # All remaining values in newHash will be insertions
          newHash.each { |newKey, newVal|
            insertAvp(dbu, projectId, newKey, newVal)
          }
        end
      rescue => e
        dbu.logDbError("ERROR: Unknown DB error occurred during BRL::Abstract::Resources::Project.updateAvpHash()", e)
        retVal = false
      end
      return retVal
    end

    # This method inserts a new AVP pairing into the +project+ associated AVP tables.
    # You can also update an existing relationship between a +project+ and a
    # +projectAttrName+ by setting the +mode+ parameter to the symbol +:update+.
    #
    # [+dbu+] Instance of +DBUtil+, ready to do DB work.
    # [+projectId+] DB Id of the +project+ for which to associate with this AVP.
    # [+attrName+] A +String+ of the attribute name to use.
    # [+attrValue+] A +String+ of the attibute value to use.
    # [+mode+] A symbol of either +:insert+ or +:update+ to set the mode to use.
    # [+returns+] Number of rows affected in the DB.  +1+ when successful, +0+ when not.
    def insertAvp(dbu, projectId, attrName, attrValue, mode=:insert)
      retVal = nil
      # Test for uniqueness of attribute to be inserted
      attrNameExists = dbu.selectProjectAttrNameByName(attrName)
      nameId = valId = nil
      if(attrNameExists.nil? or attrNameExists.empty?)
        nameInsert = dbu.insertProjectAttrName(attrName)
        nameId = dbu.getLastInsertId(:mainDB)
      else
        nameId = attrNameExists.first['id']
      end

      # Test for uniqueness of value to be inserted
      attrValExists = dbu.selectProjectAttrValueByValue(attrValue)
      if(attrValExists.nil? or attrValExists.empty?)
        attrValInsert = dbu.insertProjectAttrValue(attrValue)
        valId = dbu.getLastInsertId(:mainDB)
      else
        valId = attrValExists.first['id']
      end

      # Create the AVP link using the project2attribute table
      if(projectId and nameId and valId)
        if(mode == :update)
          retval = dbu.updateProject2AttributeForProjectAndAttrName(projectId, nameId, valId)
        else
          retVal = dbu.insertProject2Attribute(projectId, nameId, valId)
        end
      end

      return retVal
    end
  end # module ProjectModule

  # Abstraction of a Genboree Project. Implements some fundamental
  # behaviors concerning projects.
  #
  # Currently in Genboree, projects have globally unique names because
  # the top-level project name must be globally unique, regardless of Genboree
  # group containing the project. This will likely change in the future.
  # _As a precaution, this class has placeholders for providing the +groupId+
  # to the constructor, which will be required when we fix the limitation. Right
  # now however, it is not required and will be automatically filled in
  # by the constructor for now.
  #
  # NOTE: this file requires all the project sub-component classes. So
  # if you need to play with those directly, it's easiest just to require
  # this one file in order to bring them all in.
  class Project
    ENTITY_TYPE = 'projects'
    # The state bit that indicates the project is published
    PUBLIC_STATE = BRL::Genboree::Constants::PUBLIC_STATE # should be 256
    # Array of regexps that project names can't match
    RESERVED_WORDS = [ /genb\^\^/, /GENB_DELETED/, /^\.svn$/, /\.\./, /^\./, /^\-/, /^\s+$/ ]
    # Pattern to check project names against to make sure they are valid
    PROJ_NAME_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._\- \/]*$/

    # Id of the project
     attr_accessor :projectId
    # The project's full name
    attr_accessor :projName
    # Generic field for the name (should be same as projName)
    attr_accessor :entityName
    # The id of the group this project is in
    attr_accessor :groupId
    # A loaded +GenboreeConfig+ instance
    attr_accessor :genbConfig
    # A +DbUtil+ instance, setup to connect to the main Genboree database
    attr_accessor :dbu
    # Id of user on behalf of whom we're doing things
    # The base dir where all projects' file trees are stored
    attr_accessor :baseProjDir
    # The root directory where this project is stored...will have subdirs, maybe even
    # whole subdir trees below it
    attr_accessor :projDir
    # The backup directory for this project, for use when "deleting" a project
    attr_accessor :bakDir
    # The name of the top-level project as extracted from this project's name
    attr_accessor :topLevelProject
    # The array [maybe empty] of sub-projects that are part of this project's name
    attr_accessor :subProjectElems
    # An array of the sub-project directories immediately below this project. It will not
    # be their fully qualified names (which would start with this project's name), but rather the
    # relative sub-project names.
    attr_accessor :subProjects
    # When composing links (say when generating hrefs in the ExtJs tree representations of this project's components)
    # should we be adding the 'isPublic=YES' parameter or not. Default is false.
    attr_accessor :isPublicAccess
    # Hash for storing only attribute names and values
    attr_accessor :attributesHash
    # Array of entity attributes names (Strings) that we care about (default is nil == no filter i.e. ALL attributes)
    attr_accessor :attributeList
    # Corresponding row from MySQL table, if applicable
    attr_accessor :entityRow

    # CONSTRUCTOR.
    # This will do some set up of this Project object's state, including things like reading the genboree
    # config file, getting a +DbUtil+ instance, getting the top-level project's name, etc.
    #
    # [+projId+]  If a +String+, then assumed to be the project's name; else if +Fixnum+ then assumed to be project's id.
    # [+groupId+] The id for the group containing this project; should _always_ supply this to be forward compatible
    #             with an upcoming change that will make project names unique only within a group.
    # [+genbConfig+]  [optional; default=nil] If provided, use the already-loaded GenboreeConfig class rather than loading and parsing again (and again and again if iterating over subprojects...)
    # [+dbu+]         [optional; default=nil] If provided, use the already-instantiated DBUtil class rather than creating and initializing one again (an expensive initialization, relatively). Good performance tuning option, like when recursing over subprojects.
    def initialize(projId, groupId, genbConfig=nil, dbu=nil, userId=nil)
      @genbConfig = (genbConfig or BRL::Genboree::GenboreeConfig.load())
      @projectId = projId
      @groupId = groupId
      @userId = userId
      @isPublicAccess = false
      @cachedInfo = CachedProjInfo.new()
      @attributesHash = @attributeList = @entityRow = nil
      # DbUtil instance
      @dbu = (dbu or BRL::Genboree::DBUtil.new(@genbConfig.dbrcKey, nil, @genbConfig.dbrcFile))
      # Get project info from actual project table record
      if(projId.is_a?(String)) # then projId arg is a project name (or possible full subproject name)
        @projName = projId
      else # projId arg is the actual project id, but will certainly need the name so we get it now from the database
        @cachedInfo.projId = projId
        projectTableRow = @dbu.getProjectById(@cachedInfo.projId)
        @projName = projectTableRow.first['name']
        @state = projectTableRow.first['state']
        projectTableRow.clear
      end
      # Sub-projects & Top level project
      @subProjectElems = @projName.split(/\//)
      @topLevelProject = @subProjectElems.shift
      # Get proj dir info
      @baseProjDir = @genbConfig.gbProjectContentDir
      @projDir = "#{@baseProjDir}/#{projNameToPath()}"
      @bakDir = "#{@projDir}/genb^^BAK/"
      @subProjects = findSubProjects()
      # We only actually create the objects representing the various components of this
      # project when actually asked, to reduce overhead of reading their data files and parsing, etc,
      # unnecessarily.
      @titleImgObj = @titleObj = @descObj = @customContentObj = @newsObj = @linksObj = @quickLinksObj = @filesObj = @pagesObj = nil
    end

    def updateAttributes(attributeList=@attributeList, mapType='full', aspect='map')
      initAttributesHash()
      updateAttributesHash(attributeList, mapType, aspect)
    end

    def initAttributesHash()
      @attributesHash = Hash.new { |hh, kk| hh[kk] = {} }
    end

    # Requires @dbu to be connected to the right db
    # [+idList+] An array of [bio]SampleIds
    # [+attributeList+] - [optional; default=nil] Only get info for attributes in this array (should be array of attribute name Strings)
    # [+mapType+] type of map requested [Default: Full]
    # [+aspect+] type of aspect requested [Default: map]
    # [+returns] nil
    def updateAttributesHash(attributeList=@attributeList, mapType='full', aspect='map')
      # Get the @entityRow, if not gotten yet
      if(!@projName.is_a?(String))
        if(@entityRow.nil? or @entityRow.empty?)
          @entityRow = @dbu.selectProjectById(@projectId)
          unless(@entityRow and !@entityRow.empty?)
            raise "ERROR: could not find database record corresponding to id #{@refSeqId.inspect}"
          end
        end
        @projName = @entityRow.first['name']
      end
      # Get the attribute info for this group.
      attributesInfoRecs = @dbu.selectCoreEntityAttributesInfo(self.class::ENTITY_TYPE, [@projName], attributeList, "Error in #{File.basename(__FILE__)}##{__method__}: Could not query user database for entity metadata.")
      if(aspect == 'map')
        attributesInfoRecs.each { |rec|
          if(mapType == 'full')
            @attributesHash[rec['entityName']][rec['attributeName']] = rec['attributeValue']
          elsif(mapType == 'attrNames')
            @attributesHash[rec['entityName']][rec['attributeName']] = nil
          elsif(mapType == 'attrValues')
             @attributesHash[rec['entityName']][rec['attributeValue']] = nil
          else
            raise "Unknown mapType: #{mapType.inspect}"
          end
        }
      elsif(aspect == 'names')
        attributesInfoRecs.each { |rec|
          @attributesHash[rec['attributeName']][nil] = nil
        }
      elsif(aspect == 'values')
        attributesInfoRecs.each { |rec|
          @attributesHash[rec['attributeValue']][nil] = nil
        }
      else
        raise "Unknown aspect: #{aspect.inspect}"
      end
      return true
    end

    # The project ACTUALLY exists if its projDir exists. Otherwise, it's
    # an object representing a "virtual" (not yet created...perhaps about to?) project.
    # - really a project must also have its top-level project in the projects table in the database,
    #   etc; but this is a fast and simple test that works even if we won't be needing to contact the database
    # [+returns+] true if project 'exists' (its dir exists at least); false otherwise
    def exist?()
      return File.exist?(@projDir)
    end
    alias_method :'exists?', :'exist?'

    # Get this project's name as a partial file system path.
    # [+returns+] A partial file system path based on the project name
    def projNameToPath()
      @cachedInfo.projNameToPath = Project.projNameToPath(@projName) unless(@cachedInfo.projNameToPath)
      return @cachedInfo.projNameToPath
    end

    # Is this project published? Based on the state bits.
    # [+returns+] true if published, else false
    def isPublished?()
      return self.state() & PUBLIC_STATE == PUBLIC_STATE
    end

    # Are there backups for this project? i.e. stuff that could be undeleted?
    # [+returns+] true if some backups exist, else false
    def hasBackups?()
      return (File.exist?("#{@bakDir}/genb^^required/") and
              File.exist?("#{@bakDir}/genb^^optional/") and
              Dir.new("#{@bakDir}/genb^^required/").entries.size >= 3 and
              Dir.new("#{@bakDir}/genb^^optional/").entries.size >= 3)
    end

    # Get the parent project name.
    # [+getFullName+] [optional; default=false] If true, it will get the full name of the parent project; if false, then just the relative name of the parent
    # [+getEscaped+]  [optional; default=false] If true, the parent's name will be properly escaped; if false, then the unescaped name will be returned.
    # [+returns+]     The name of the parent of this project, or +nil+ if none.
    def parentProjName(getFullName=false, getEscaped=false)
      if(@subProjectElems.empty?) # if it is empty, then it's a top-level project with no parent...
        retVal = nil
      else
        unless(@cachedInfo.parentProjName)
          parentProjElems = @subProjectElems.dup
          parentProjElems.pop
          parentProjElems.unshift(@topLevelProject)
          @cachedInfo.fullParentProjName = parentProjElems.join("/")
          @cachedInfo.parentProjName = parentProjElems.pop
          @cachedInfo.escFullParentProjName = Project.projNameToPath(@cachedInfo.fullParentProjName)
          @cachedInfo.escParentProjName = Project.projNameToPath(@cachedInfo.parentProjName)
        end
        retVal = (getFullName ?
                    (getEscaped ? @cachedInfo.escFullParentProjName : @cachedInfo.fullParentProjName) :
                    (getEscaped ? @cachedInfo.escParentProjName : @cachedInfo.parentProjName)
                 )
      end
      return retVal
    end

    # Create a backup of this project. Currently, only the components in
    # the genb^^required/ and genb^^optional/ subdirs are backed up.
    # TODO: also backup/restore the projectFiles' index file now that managing that as well.
    # [+returns+] true
    def createBackup()
      # Remove BAK subdir if it's there
      FileUtils.rm_rf(@bakDir)
      # Make BAK subdirs
      FileUtils.mkdir_p(["#{@bakDir}/genb^^required/", "#{@bakDir}/genb^^optional/"])
      # Cp key dirs in to BAK subdir
      Find.find("#{@projDir}/genb^^required/", "#{@projDir}/genb^^optional/") { |path|
        basename = File.basename(path)
        relPath = path.gsub(/#{@projDir}/, "")
        if(basename =~ /^\.svn/ and File.directory?(path))
          Find.prune
        elsif(basename !~ /^(?:genb\^\^required|genb\^\^optional)$/)
          FileUtils.cp_r(path, "#{@bakDir}/#{relPath}")
          Find.prune
        else
          #$stderr.puts "SKIP: #{path}"
        end
      }
      return true
    end

    # Restores a backup of this project. Currently, only the components in
    # the genb^^required/ and genb^^optional/ subdirs are backed up.
    # TODO: also backup/restore the projectFiles' index file now that managing that as well.
    # [+returns+] true
    def restoreBackup()
      if(hasBackups?)
        # Cp key dirs back to base dir
        FileUtils.cp_r("#{@bakDir}/genb^^required/", @projDir)
        FileUtils.cp_r("#{@bakDir}/genb^^optional/", @projDir)
        FileUtils.rm_rf("#{@bakDir}")
      end
      return true
    end

    # Get project id. For many/most operations, this is not required.
    # Getting it from the name required a database query that can
    # be avoided in many cases. So we only get it when needed and even
    # then we cache the result. This saves a bunch of unneeded database queries
    # when recursing over a big subproject tree.
    # [+returns+] The project id.
    def projId()
      unless(@cachedInfo.projId)
        projectTableRows = @dbu.getProjectsByName(@topLevelProject, @groupId)
        projectTableRow = projectTableRows.first
        @cachedInfo.projId = projectTableRow['id']
        @cachedInfo.state = projectTableRow['state'] unless(@cachedInfo.state) # get the state while we're here
        projectTableRows.clear
      end
      @cachedInfo.projId
    end

    # Set the project id manually (not recommended)
    def projId=(projId)
      @cachedInfo.projId = projId
      return @cachedInfo.projId
    end

    # Get project state bits. For many/most operations, this is not required.
    # Getting it from the name required a database query that can
    # be avoided in many cases. So we only get it when needed and even
    # then we cache the result. This saves a bunch of unneeded database queries
    # when recursing over a big subproject tree.
    # [+returns+] The project id.
    def state()
      unless(@cachedInfo.state)
        projectTableRows = @dbu.getProjectsByName(@topLevelProject, @groupId)
        projectTableRow = projectTableRows.first
        @cachedInfo.projId = projectTableRow['id'] unless(@cachedInfo.projId)  # get the projId while we're here
        @cachedInfo.state = projectTableRow['state']
        projectTableRows.clear
      end
      @cachedInfo.state
    end

    # Set the project id manually (not recommended)
    def state=(state)
      @cachedInfo.state = state
      return @cachedInfo.state
    end

    # Get component object by componentType.
    #
    # [+componentType+] A string corresponding to a component type.
    # [+returns+]       An object representing that component of this project.
    #                   Will be an instance of a subclass of BRL::Genboree::Abstract::Resources::AbstractProjectComponent
    def getComponent(componentType)
      retVal = nil
      componentType = componentType.to_s
      case componentType
        when 'projectTitle', 'title'
          retVal = titleComponent()
        when 'projectDesc', 'description'
          retVal = descComponent()
        when 'projectContent', 'customContent'
          retVal = customContentComponent()
        when 'projectQuickLinks', 'quickLinks'
          retVal = quickLinksComponent()
        when 'projectCustomLinks', 'links'
          retVal = linksComponent()
        when 'projectNews', 'news'
          retVal = newsComponent()
        when 'projectFiles', 'files'
          retVal = filesComponent()
        when 'projectPages', 'pages'
          retVal = projectPages()
        when 'projectTitleImage', 'titleImage'
          retVal = titleImgComponent()
        when 'subProjects'
          retVal = @subProjects
      end
      return retVal
    end

    # Get the ProjectTitleImage component for this project, creating it first if needed.
    # [+returns+] An instance of ProjectTitleImage
    def titleImgComponent()
      return ( @titleImgObj ||= ProjectTitleImage.new(self, @groupId, @genbConfig) )
    end

    # Get the ProjectTitle component for this project, creating it first if needed.
    # [+returns+] An instance of ProjectTitle
    def titleComponent()
      return ( @titleObj ||= ProjectTitle.new(self, @groupId, @genbConfig) )
    end

    # Get the ProjectDescription component for this project, creating it first if needed.
    # [+returns+] An instance of ProjectDescription
    def descComponent()
      return ( @descObj ||= ProjectDescription.new(self, @groupId, @genbConfig) )
    end

    # Get the ProjectCustomContent component for this project, creating it first if needed.
    # [+returns+] An instance of ProjectCustomContent
    def customContentComponent()
      return ( @customContentObj ||= ProjectCustomContent.new(self, @groupId, @genbConfig) )
    end

    # Get the ProjectQuickLinks component for this project, creating it first if needed.
    # [+returns+] An instance of ProjectQuickLinks
    def quickLinksComponent()
      return ( @quickLinksObj ||= ProjectQuickLinks.new(self, @groupId, @genbConfig) )
    end

    # Get the ProjectLinks component for this project, creating it first if needed.
    # [+returns+] An instance of ProjectLinks
    def linksComponent()
      return ( @linksObj ||= ProjectLinks.new(self, @groupId, @genbConfig) )
    end

    # Get the ProjectNews component for this project, creating it first if needed.
    # [+returns+] An instance of ProjectNews
    def newsComponent()
      return ( @newsObj ||= ProjectNews.new(self, @groupId, @genbConfig) )
    end

    # Get the ProjectFiles component for this project, creating it first if needed.
    # [+returns+] An instance of ProjectFiles
    def filesComponent()
      return ( @filesObj ||= ProjectFiles.new(self, @groupId, @genbConfig) )
    end

    # Get the ProjectPages component for this project, creating it first if needed.
    # [+returns+] An instance of ProjectPages
    def pagesComponent()
      return ( @pagesObj ||= ProjectPages.new(self, @groupId, @genbConfig) )
    end

    # Updates the publication state of this project to be +publishMode+.
    # [+publishMode+] A String indicating how to update the publications status. Either 'Publish' or 'Retract'.
    # [+returns+]     true if published, else false
    def updatePublication(publishMode)
      if(@dbu)
        if(publishMode == 'Publish')
          state = self.state() | PUBLIC_STATE
        elsif(publishMode == 'Retract')
          state = self.state() ^ PUBLIC_STATE
        end
        @dbu.updateProjectStateById( self.projId(), state )
        self.state = state
      end
      return isPublished?()
    end

    # Check if user can access this project with at least accessLevel permission.
    #
    # [+userId+]  Genboree user id to check access for.
    # [+accessLevel+] [optional; default='w'] The minimum level of access to check for.
    #                                         Possible values are 'r', 'w', 'o' (latter is owner/admin level)
    # [+returns+] :OK if allowed or :ACCESS_DENIED if not; this is compatible with them places it
    def checkAccess(userId, accessLevel='w')
      return Project.checkAccess(@projName, @groupId, userId, accessLevel, @dbu)
    end

    # Gets an array of subprojects directly below this project, based on subdir structure.
    # [+returns+] Array of 0 or more subprojects
    def findSubProjects()
      entries = []
      if(File.exist?(@projDir))
        # 3) Go through each entry in the dir and remove non-subdirs
        entries = Dir.entries(@projDir)
        entries.delete_if { |entry|
          ( !File.directory?("#{@projDir}/#{entry}") or
            File.symlink?("#{@projDir}/#{entry}") or
            entry =~ /^\.\.?$/ or
            entry =~ /^\.svn/ or
            entry =~ /^genb\^\^/ or
            entry =~ /\.GENB_DELETED\./
          )
        }
        # Unescape any dirs found to reveal the real names
        entries.map! { |xx| CGI.unescape(xx) }
      end
      return entries
    end

    # Represent the subprojects of this project as an ExtJS TreeNode config object. When converted to JSON (via #to_json)
    # this will result in a JSON string that is compliant with ExtJS's TreeNode config object.
    # We don't convert it to JSON here because you may be building a larger tree of which this is only
    # a sub-branch.
    #
    # Here it results in a "SubProjects" folder that has each subproject as a file leaf node that is a link.
    #
    # [+recurse+]   [optional; default=true]  if true, then will recurse into each subproject to find its
    #               subprojects, and into each of those, etc, etc.
    # [+expanded+]  [optional; default=false] true if the node should start off expanded, false otherwise
    # [+returns+]   A Hash representing the component, often having an Array for the :children key (which is an Array of Hashes defining child nodes...)
    def subProjectsAsExtjsTreeNode(recurse=true, expanded=false)
      retVal = nil
      # Only generate this if there are subprojects
      unless(@subProjects.nil? or @subProjects.empty?)
        # Create the subprojects node
        retVal = { :text => "SubProjects", :leaf => false, :cls => "folder", :expanded => expanded, :allowDrag => false, :allowDrop => false }
        # Add children
        retVal[:children] = []
        # Sort the list of sub projects alphabetically
        @subProjects.sort! { |aa, bb| cmpVal = (aa.downcase <=> bb.downcase) ; cmpVal = aa <=> bb if(cmpVal == 0) ; cmpVal }
        # 2. For each subproject, put a folder or file entry, then recurse into it if directed
        @subProjects.each { |subProject|
          subprojLongName = "#{@projName}/#{subProject}"
          if(recurse)
            # Make the tree for this subproject, recursing into its subprojects if any
            subProjectObj = Project.new(subprojLongName, @groupId, @genbConfig, @dbu)
            if( subProjectObj.linksComponent().empty? and
                subProjectObj.quickLinksComponent().empty? and
                subProjectObj.filesComponent().empty? and
                subProjectObj.subProjects.empty?)
              cls = 'file'
              leaf = true
            else
              cls = 'folder'
              leaf = false
            end
            # Folder for sub project, named after project itslef
            subProjNode = {
              :text => CGI.escapeHTML(subProject),
              :leaf => leaf,
              :href => "project.jsp?projectName=#{Project.projNameToPath(subprojLongName)}" + (@isPublicAccess ? '&isPublic=YES' : ''),
              :cls => cls, :expanded => false, :allowDrag => false, :allowDrop => false
            }
            retVal[:children] << subProjNode
            subProjectTreeCreator = BRL::Genboree::ProjectTreeBrowser.new(subProjectObj, @groupId)
            # Need to set a non-0 depth, but don't actually need to track the depth; it's enough to say it's not the top-level
            subProjectTreeCreator.depth = 2
            # Make tree
            subProjectTree = subProjectTreeCreator.generateTree()
            subProjNode[:children] = subProjectTree
          else # no recursing, just need file and link for each direct subproject
            retVal[:children] << { :text => "<i>(None yet.)</i>",
              :href => "/projects/#{Project.projNameToPath(subprojLongName)}",
              :leaf => true, :cls => "file", :allowDrag => false, :allowDrop => false
            }
          end
        }
      end
      return retVal
    end

    #------------------------------------------------------------------
    # HELPER CLASS METHODS
    #------------------------------------------------------------------
    # Check if user can access this project with at least accessLevel permission.
    #
    # [+userId+]  Genboree user id to check access for.
    # [+accessLevel+] [optional; default='w'] The minimum level of access to check for.
    #                                         Possible values are 'r', 'w', 'o' (latter is owner/admin level)
    # [+returns+] :OK if allowed or :ACCESS_DENIED if not; this is compatible with them places it
    def self.checkAccess(projName, groupId, userId, accessLevel='w', dbu=nil)
      # First, look for superuser
      genbConfig = BRL::Genboree::GenboreeConfig.load()
      if(userId.to_i == genbConfig.gbSuperuserId.to_i)
        retVal = :OK
      else
        # Checking access to a project is the same as checking access to the group the project is in, right now.
        if(dbu.nil?)
          dbu = BRL::Genboree::DBUtil.new('genboree', nil, genbConfig.dbrcFile)
        end
        retVal = :OK
        userAllowedToEdit = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(userId, groupId, accessLevel, dbu)
        retVal = :ACCESS_DENIED unless(userAllowedToEdit)
      end
      return retVal
    end

    # Get the full path to this project's storage directory
    # [+returns+] A file system path to the dir for the project.
    def self.constructProjDir(projName, genbConfig)
      projBaseDir = genbConfig.gbProjectContentDir
      # 3) Check that dir already exists
      projDir = "#{projBaseDir}/#{Project.projNameToPath(projName)}"
      return projDir
    end

    # Get this project's name as a file system path
    # [+returns+] A partial path, based on the project name.
    def self.projNameToPath(projName)
      retVal = CGI.escape(projName)
      retVal.gsub!(/%2F/, '/')
      return retVal
    end

    # Checks that a project name doesn't use illegal chars and doesn't use a reserved word.
    # [+projName+]  The project name to evaluate.
    # [+dbu+]     [optional] If provided, then the DBUtil instance will be used to ask database questions. Otherwise will create an instance.
    #             This is a performance benefit not to have to create an instance (which involves reading config file too)
    # [+returns+]   true if ok, false if not ok
    def self.validateProjectName(projName, dbu=nil, genbConfig=nil)
      retVal = :OK
      if(dbu.nil?)
        genbConfig ||= BRL::Genboree::GenboreeConfig.load()
        dbu = BRL::Genboree::DBUtil.new('genboree', nil, genbConfig.dbrcFile)
      end
      if((projName =~ PROJ_NAME_PATTERN) == nil)
        retVal = :INVALID_NAME
      else
        usesReserved = false
        RESERVED_WORDS.each { |reservedRE|
          usesReserved = (projName =~ reservedRE)
          if(usesReserved)
            retVal = :USES_RESERVED_WORD
            break
          end
        }
      end
      return retVal
    end

    # Gets a groupId based on a project id or project name.
    # This will *ONLY* work while project names are globally unique.
    #
    # [+projId+]  If +Fixnum+, the id of the project; if +String+, the project name.
    # [+dbu+]     [optional] If provided, then the DBUtil instance will be used to ask database questions. Otherwise will create an instance.
    #             This is a performance benefit not to have to create an instance (which involves reading config file too)
    # [+genbConfig+] [optional] A _loaded_ instance of GenboreeConfig. If not provided
    #                           the configuration file will be read [again...?]
    # [+returns+] The groupId.
    def self.getGroupId(projId, dbu=nil, genbConfig=nil)
      retVal = nil
      if(dbu.nil?)
        genbConfig ||= BRL::Genboree::GenboreeConfig.load()
        dbu = BRL::Genboree::DBUtil.new('genboree', nil, genbConfig.dbrcFile)
      end
      if(projId.is_a?(String)) # then given a project name...get project id.
        projElems = projId.split(/\//)
        topLevelProj = projElems.shift
        projId = Project.getProjId(topLevelProj, nil, dbu, genbConfig)
      end
      projectRow = dbu.getProjectById(projId)
      retVal = projectRow.first['groupId'] if(projectRow)
      return retVal
    end

    # Gets a projId based on a project name and a a group id
    # This will *ONLY* work without also providing a non-nil groupId while project names are globally unique.
    #
    # [+projName+]  The project name.
    # [+groupId+]   The id of the group the project is in. Optional only while project names are
    #               globally unique--you should always provide an id here, for future proofing...
    # [+dbu+]     [optional] If provided, then the DBUtil instance will be used to ask database questions. Otherwise will create an instance.
    #             This is a performance benefit not to have to create an instance (which involves reading config file too)
    # [+genbConfig+] [optional] A _loaded_ instance of GenboreeConfig. If not provided
    #                           the configuration file will be read [again...?]
    # [+returns+]   The project id.
    def self.getProjId(projName, groupId, dbu=nil, genbConfig=nil)
      retVal = nil
      if(dbu.nil?)
        genbConfig ||= BRL::Genboree::GenboreeConfig.load()
        dbu = BRL::Genboree::DBUtil.new('genboree', nil, genbConfig.dbrcFile)
      end
      projElems = projName.split(/\//)
      topLevelProj = projElems.shift
      projectRows = dbu.getProjectsByName(topLevelProj, groupId)
      retVal = projectRows.first['id'] if(projectRows and !projectRows.empty?)
      return retVal
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module Abstract ; module Resources
