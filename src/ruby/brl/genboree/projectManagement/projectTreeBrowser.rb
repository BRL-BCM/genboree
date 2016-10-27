
require 'stringio'
require 'json'
require 'brl/util/util'
require 'brl/genboree/abstract/resources/project'

module BRL ; module Genboree
  # This class is for generating an ExtJS compatible TreePanel JSON array of tree nodes.
  class ProjectTreeBrowser
    # The Project object
    attr_accessor :projectObj
    # Depth of this project (say within a parent project's tree)
    attr_accessor :depth
    # The array of tree nodes/leaves
    attr_accessor :tree

    # CONSTRUCTOR
    def initialize(project, groupId, depth=0)
      if(project.is_a?(BRL::Genboree::Abstract::Resources::Project))
        @projectObj = project
      else # a project name or project id
        @projectObj = BRL::Genboree::Abstract::Resources::Project.new(project, groupId)
      end
      @depth = depth
      @tree = []
    end

    # HTML tags needed for using the ExtJs TreePanel. Ideally, these go in the <head>
    # block, but can appear in <body> if absolutely have to (high up as possible).
    # This will actually make the tree too, in theory, by calling generateTree() to get the child node info.
    def htmlHeadTags()
      retVal = <<-EOS
        <style type="text/css">
          .x-tree-node-leaf img.linknode { background-image:url(/images/silk/link.png); }
          .x-tree-node-leaf img.folder_up { background-image:url(/images/silk/folder_up.png); }
        </style>

        <script type="text/javascript">
          var ProjectTree = function() {
            return {
              init : function() {
                // Create tree in appropriate div
                var tree = new Ext.tree.TreePanel('projectTreeDiv', {
                  animate : true,
                  enableDD : false,
                  lines : false,
                  singleExpand : true,
                  loader : new Ext.tree.TreeLoader(), // No dataUrl here, just register a tree loader to get createNode() method
                  rootVisible : false
                }) ;
                var root = new Ext.tree.AsyncTreeNode( {
                  text : 'Project Links & Files',
                  expanded: true,
                  draggable : false,
                  id : 'projectTreeRootNode',
                  cls : '',
                  children : #{generateTree().to_json}
                }) ;
                tree.setRootNode(root) ;
                // Render tree
                tree.render() ;
                // root.expand(false, false) ;
              }
            } ;
          }() ;
          Ext.EventManager.onDocumentReady(ProjectTree.init, ProjectTree, true) ;
        </script>
      EOS
      return retVal
    end

    # Makes the json string representing the nodes and leaves of the tree
    # as needed by ExtJs' TreePanel say.
    # [+recurseSubProjects+]  [optional; default=true] Whether or not to recurse into the subprojects and make their trees too
    #                         otherwise just do the immediate subprojects.
    # [+returns+] Array of project tree nodes
    def generateTree(recurseSubProjects=true)
      @tree = []
      # First, let's determine if we have a parent node we need to represent
      relParentProjName = @projectObj.parentProjName()
      if(relParentProjName and (@depth < 1)) # if not parent project name, then top-level project and don't do this...
        escFullParentProjName = @projectObj.parentProjName(true, true)
        # Create node linking to parent project
        @tree << {
          :text => relParentProjName,
          :href => "project.jsp?projectName=#{escFullParentProjName}" + (@projectObj.isPublicAccess ? '&isPublic=YES' : ''),
          :leaf => true, :cls => 'leaf', :iconCls => 'folder_up',
          :expanded => false, :allowDrag => false, :allowDrop => false
        }
      end
      # Determine what tree components we have and don't have
      linksOnly = (!@projectObj.linksComponent().empty? and @projectObj.quickLinksComponent().empty? and @projectObj.filesComponent().empty? and @projectObj.subProjects.empty?)
      filesOnly = (!@projectObj.filesComponent().empty? and @projectObj.quickLinksComponent().empty? and @projectObj.linksComponent().empty? and @projectObj.subProjects.empty?)
      subprojsOnly = (!@projectObj.subProjects.empty? and @projectObj.filesComponent().empty? and @projectObj.quickLinksComponent().empty? and @projectObj.linksComponent().empty?)
      @tree << @projectObj.quickLinksComponent().to_extjsTreeNode((@depth < 1)) unless(@projectObj.quickLinksComponent().empty?)
      @tree << @projectObj.linksComponent().to_extjsTreeNode(linksOnly) unless(@projectObj.linksComponent().empty?)
      @tree << @projectObj.filesComponent().to_extjsTreeNode(filesOnly) unless(@projectObj.filesComponent().empty?)
      unless(@projectObj.subProjects.empty?)
        # Try to make a subproject tree
        subprojTree = @projectObj.subProjectsAsExtjsTreeNode(recurseSubProjects, subprojsOnly)
        @tree << subprojTree
      end
      return @tree
    end
  end
end ; end
