
require 'json'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/abstract/resources/abstractProjectComponent'

module BRL ; module Genboree ; module Abstract ; module Resources
  # Class representing the list of quicklinks related to a particular project
  class ProjectQuickLinks < AbstractProjectComponent
    # The name of the file that has the data contents or the index of contents
    DATA_FILE = 'genb^^optional/quickLinks.json'
    # The type of data stored in the data file
    DATA_FORMAT = :JSON

    # Represent as an ExtJS TreeNode config object. When converted to JSON (via #to_json)
    # this will result in a JSON string that is compliant with ExtJS's TreeNode config object.
    # We don't convert it to JSON here because you may be building a larger tree of which this is only
    # a sub-branch.
    #
    # Here it results in a "Quick Links" folder that has each quick link as a file leaf node that is a link.
    #
    # [+expanded+]  [optional; default=false] true if the node should start off expanded, false otherwise
    # [+returns+]   A Hash representing the component, often having an Array for the :children key (which is an Array of Hashes defining child nodes...)
    def to_extjsTreeNode(expanded=false)
      if(!self.empty?)
        # Create the quicklinks list node
        retVal = { :text => "Quick Links", :leaf => false, :cls => "folder", :expanded => expanded, :allowDrag => false, :allowDrop => false }
        # Add children
        retVal[:children] = []
        @data.each { |qlinkHash|
          next if(qlinkHash.nil? or qlinkHash.has_value?(nil))
          retVal[:children] << { :text => CGI.escapeHTML(CGI.stripHtml(qlinkHash['linkText'])), :href => qlinkHash['url'], :leaf => true, :cls => "leaf", :iconCls => "linknode", :allowDrag => false, :allowDrop => false }
        }
      else
        retVal = {}
      end
      return retVal
    end
  end
end ; end ; end ; end
