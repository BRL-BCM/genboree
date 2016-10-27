
require 'tempfile'
require 'fileutils'
require 'brl/util/textFileUtil'
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/abstract/resources/abstractProjectComponent'
require 'brl/genboree/abstract/resources/fileManagement'
require 'brl/genboree/abstract/resources/dataIndexFile'

module BRL ; module Genboree ; module Abstract ; module Resources
  # Class representing the list of files related to a particular project
  class ProjectFiles < AbstractProjectComponent
    # Mixin the generic file management functionality
    include BRL::Genboree::Abstract::Resources::FileManagement
    include BRL::Genboree::Abstract::Resources::DataIndexFile

    # The type of data stored in the data file managed by DataIndexFile.
    DATA_FORMAT = :JSON

    # The name of the file that has the data contents or the index of contents
    DATA_FILE = 'genb^^additionalFiles/projectFiles.json'
    # The auto-archive threshold (2 weeks in seconds)
    AUTOARCHIVE_THRESHOLD = 2 * 7 * 24 * 60 * 60
    # The minimum number of files in the current files list
    MIN_CURRENT_FILES = 5

    # Array of the non-archived files [index records]
    attr_accessor :currentFiles
    # Array of the archived files [index records]
    attr_accessor :archivedFiles
    # Directory where all the files of this project live
    attr_accessor :filesDir
    # Name of the index file (no path)
    attr_accessor :indexFileName
    # Hash of base file names that should not be exposed as project files
    attr_accessor :fileKillList
    # rack env set from the resource
    attr_accessor :rackEnv
    # suppress email for jobs submitted by FileManagement#writeFile()
    attr_accessor :suppressEmail

    def initialize(groupId, projName, genbConf=nil)
      super(groupId, projName, genbConf)
      @currentFiles = []
      @archivedFiles = []
      @filesDir = Dir.new(File.dirname(@dataFileName))
      @indexFileName = File.basename(DATA_FILE)
      @fileKillList = { @indexFileName => true, '.svn' => true, 'projectAdditionalFiles.json' => true, '.tmp-uploadInProgress' => true }
      processFileIndex()
      @suppressEmail = false
    end

    # Constructs a relative URL path [link] to the file mentioned in the file record
    # for use in href attribute of HTML tags.
    # [+returns+] Relative URL path as String
    def getUrlPath(projFileRec)
      # filename on disk escaped, so double escaped here (1st) make valid url (2) b/c name on disk is escaped
      return "/projects/#{CGI.escape(@escName)}/genb^^additionalFiles/#{CGI.escape(CGI.escape(projFileRec['fileName']))}"
    end

    # This method adds a file to a project.  By default it won't overwrite, but you can set allowOverwrite to allow it
    #
    # [+fileName+]  The unique file name identifying the file.
    # [+content+]   The contents of the file.
    # [+context+]   A context +Hash+ containing the aforementioned keys.
    # [+returns+]   :OK or some failure symbol. Not an HTTP response code though.
    def writeProjectFile(fileName, content, context, allowOverwrite=false)
      retVal = :Accepted
      # First, check the user's access and that we're doing this from a sensible
      # place (e.g. groupId from session matches project's group)
      retVal = Project.checkAccess(@projName, @groupId, context[:userId])
      if(retVal == :OK)
        # Should return :Accepted [for upload]
        retVal = writeFile(fileName, content, allowOverwrite)
      end
      return retVal
    end

    # This method 'deletes' a particular project file. For future abilitity to undelete,
    # the 'delete' will be done by backing up the file and compressing it.
    # - sub-projects have names of the form <proj>/<subProj> or <proj>/<subProj>/<subSubProj>
    # - context is presumed to contain the :dbu, :groupId, and :userId keys, whose value
    #   are valid DBUtil instance connected to the main genboree database, the group
    #   where the project will live, and the userId of the user who is performing these
    #   actions
    # This method will update the file index, both as represented within this object and
    # in the index file on disk, and "delete" the actual project file.
    #
    # [+fileLabel+] The unique file label identifying the file to delete.
    # [+context+] A context +Hash+ containing the aforementioned keys.
    # [+returns+] :OK or some failure symbol. Not an HTTP response code though.
    def deleteProjectFile(fileLabel, context)
      retVal = :OK
      # First, check the user's access and that we're doing this from a sensible
      # place (e.g. groupId from session matches project's group)
      retVal = Project.checkAccess(@projName, @groupId, context[:userId])
      if(retVal == :OK)
        retVal = deleteFile(fileLabel)
      end
      return retVal
    end

    # This method modifies the info/settings associated with a project file.
    # - Sub-projects have names of the form <proj>/<subProj> or <proj>/<subProj>/<subSubProj>
    # - This can also be used to rename a file or provide the file with a new (but unique) label.
    # The internal representations of the file index will also be updated fully.
    #
    # [+fileLabel+] The unique file label identifying the file to update info for.
    # [+infoHash+] A +Hash+ keyed by +Strings+ indicating the file field(s) to change
    #              to the value mapped to the +String+. The following fields are supported:
    #              - 'autoArchive' -> true or false
    #              - 'archived' -> true or false
    #              - 'date' -> Time object
    #              - 'description' -> String
    #              - 'fileName' -> new filename (dir will be the same)
    #              - 'fileLabel' -> new label (must be unique for this project)
    # [+context+] A +Hash+ containing the :dbu, :groupId, and :userId keys and genbConf, whose value
    #             are valid DBUtil instance connected to the main genboree database, the group
    #             where the project will live, and the userId of the user who is performing these
    #             actions and a GenboreeConfig instance with the file already loaded.
    # [+returns+] :OK or some failure symbol. Not an HTTP response code though.
    def updateProjectFileInfo(fileLabel, infoHash, context)
      retVal = :OK
      # First, check the user's access and that we're doing this from a sensible
      # place (e.g. groupId from session matches project's group)
      retVal = Project.checkAccess(@projName, @groupId, context[:userId])
      if(retVal == :OK)
        retVal = updateFileInfo(fileLabel, infoHash)
      end
      return retVal
    end

    # Represent as an ExtJS TreeNode config object. When converted to JSON (via #to_json)
    # this will result in a JSON string that is compliant with ExtJS's TreeNode config object.
    # We don't convert it to JSON here because you may be building a larger tree of which this is only
    # a sub-branch.
    #
    # Here it results in a "Files" folder that has each file as a file leaf node that is a link.
    #
    # [+expanded+]  [optional; default=false] true if the node should start off expanded, false otherwise
    # [+returns+] A Hash representing the component, often having an Array for the :children key (which is an Array of Hashes defining child nodes...)
    def to_extjsTreeNode(expanded=false)
      if(!self.empty?)
        # Create the files list node
        retVal = { :text => "Files", :leaf => false, :cls => "folder", :expanded => expanded, :allowDrag => false, :allowDrop => false }
        # Add children
        retVal[:children] = []
        unless(FileManagement.isFileListEmpty?(@currentFiles))
          # Add a folder for current project files
          retVal[:children] << { :text => "Current", :href => nil, :leaf => false, :cls => "folder", :expanded => expanded, :allowDrag => false, :allowDrop => false }
          # Add each current file
          retVal[:children].first[:children] = []
          @currentFiles.each { |fileIndexRec|
            next if(fileIndexRec.nil? or fileIndexRec.has_value?(nil) or FileManagement.isHidden?(fileIndexRec))
            retVal[:children].first[:children] << {
              :text => CGI.escapeHTML(CGI.stripHtml(fileIndexRec['label'])),
              :href => self.getUrlPath(fileIndexRec),
              :leaf => true, :cls => "file", :allowDrag => false, :allowDrop => false
            }
          }
        end
        unless(FileManagement.isFileListEmpty?(@archivedFiles))
          # Add a folder for archived project files
          retVal[:children] << { :text => "Archived", :leaf => false, :cls => "folder", :expanded => expanded, :allowDrag => false, :allowDrop => false }
          # Add each archived file
          retVal[:children].last[:children] = []
          @archivedFiles.each { |fileIndexRec|
            next if(fileIndexRec.nil? or fileIndexRec.has_value?(nil) or FileManagement.isHidden?(fileIndexRec))
            retVal[:children].last[:children] << {
              :text => CGI.escapeHTML(CGI.stripHtml(fileIndexRec['label'])),
              :href => self.getUrlPath(fileIndexRec),
              :leaf => true, :cls => "file", :allowDrag => false, :allowDrop => false
            }
          }
        end
      else
        retVal = {}
      end
      return retVal
    end

  end
end ; end ; end ; end
