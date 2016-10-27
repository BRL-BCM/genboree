
require 'json'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/abstract/resources/abstractProjectComponent'

module BRL ; module Genboree ; module Abstract ; module Resources
  # Class representing the list of the custom pages related to a particular project.
  # TODO: this is a placeholder. Add parsing of page index file, etc.
  class ProjectPages < AbstractProjectComponent
    # The name of the file that has the data contents or the index of contents
    DATA_FILE = 'genb^^additionalPages/projectPages.json'
    # The type of data stored in the data file
    DATA_FORMAT = :JSON
  end
end ; end ; end ; end
