
require 'json'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/abstract/resources/abstractProjectComponent'

module BRL ; module Genboree ; module Abstract ; module Resources
  # Class representing the title of a particular project
  class ProjectTitle < AbstractProjectComponent
    # The name of the file that has the data contents or the index of contents
    DATA_FILE = 'genb^^required/title.part'
    # The type of data stored in the data file
    DATA_FORMAT = :TXT

    # Represent as an ExtJS TreeNode config object. When converted to JSON (via #to_json)
    # this will result in a JSON string that is compliant with ExtJS's TreeNode config object.
    # We don't convert it to JSON here because you may be building a larger tree of which this is only
    # a sub-branch.
    #
    # Here it results in a single leaf node with the title.
    #
    # [+expanded+]  [optional; default=false] true if the node should start off expanded, false otherwise
    # [+returns+] A Hash representing the component
    def to_extjsTreeNode(expanded=false)
      # Create the title node
      retVal = { :text => @dataStr, :leaf => true, :cls => "file", :expanded => false, :allowDrag => false, :allowDrop => false }
      return retVal
    end
  end
end ; end ; end ; end
