require 'brl/rackups/thin/genboreeRESTRackup'

# hack in modules/classes assumed by GenboreeRESTRackup#loadResources
module BRL; module REST; module Extensions
end; end; end
module BRL; module Genboree; module Tools; class WorkbenchJobHelper
end; end; end; end

module BRL; module Genboree; module REST; module Utilities

  # Utility functions for classifying URLs to their associated resources (leveraging existing web server handling of this task)
  # Unfortunately this means that this code can only be used where the web server can be loaded (all of its gems, etc.)
  # @todo rename
  class Classifier

    def initialize
      resourcePaths = ["brl/rest/resources", "brl/genboree/rest/resources"] # no extension or tools
      ::GenboreeRESTRackup.new(resourcePaths) # load and sort resources by priority into class variable
    end

    # Classify a URL by providing a RSRC_TYPE associated with it or nil if it cannot be classified
    # @param [String] url
    # @return [String, NilClass]
    def classifyUrl(url)
      uriObj = URI.parse(url)
      rsrcClass = ::GenboreeRESTRackup.resources.find { |resource|
        uriObj.path =~ resource.pattern()
        $~ # nil unless matches
      }
      return rsrcClass::RSRC_TYPE
    end
  end
end; end; end; end
