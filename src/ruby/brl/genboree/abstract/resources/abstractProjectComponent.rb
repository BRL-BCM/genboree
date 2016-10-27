
require 'brl/activeSupport/time'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/abstract/resources/dataIndexFile'

module BRL ; module Genboree ; module Abstract ; module Resources
  # An abstract parent class for Project component subclasses.
  # Has common attributes, methods. Do no instantiate directly. Inherit from this.
  #
  # NOTE: the 'Project' abstract class requires all the subcomponent classes. So
  # really you just need to require that one to get access to all the subcomponent
  # classes, if you need to play with them directly.
  class AbstractProjectComponent
    # Mixin the index file functionality
    include BRL::Genboree::Abstract::Resources::DataIndexFile

    # Project object corresponding to the project to which this component belongs.
    attr_accessor :projectObj
    # GroupId the project is in (this will assist in removing the globally-unique-projName requirement in the future)
    attr_accessor :groupId
    # Project name (full name, including /-delimited subprojects)
    attr_accessor :projName
    # Project name with name-elements (bits between any '/' chars) escaped
    attr_accessor :escName
    # A _loaded_ GenboreeConfig instance for use getting settings and dir locations
    attr_accessor :genbConf


    # CONSTUCTOR. Will read & parse component's data file for ready availability from the state variables.
    # [+project+]   The project to which this component belongs. Either a BRL::Genboree::Abstract::Resources::Project instance,
    #               the _full_ name of the project, or the id of the project
    # [+groupId+]   [optional; default=nil] The groupId that the project belongs to. NOT required if project is a Resources::Project instance
    # [+genbConf+]  [optional] A _loaded_ GenboreeConfig instance
    def initialize(project, groupId=nil, genbConf=nil)
      setup(project, groupId, genbConf)
      readDataFile()
      parseDataStr()
    end

    # Convert this component [back?] to JSON. If its data file stores the component
    # as JSON, this should reconstruct the contents of the data file essentially.
    # The only difference is for empty data files: The JSON equivalent of an empty String
    # is '""' (i.e. String with "") but you wouldn't want to store that in the data file--
    # nor would you want to parse that via JSON.parse() since strings can't be outside of
    # arrays or hashes in JSON [for some reason].
    # [+returns+] This component as a JSON string. Suitable for including in javascript
    #             portions of web pages and such.
    def to_json()
      retVal = ''
      if(@data)
        begin
          if(@data.is_a?(Hash) or @data.is_a?(Array))
            retVal = JSON.pretty_generate(@data)
          elsif(@data.respond_to?(:to_json))
            retVal = @data.to_json()
          else # fall back on to_s
            retVal = @data.to_s
          end
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "problem with this @data:\n\n#{@data.inspect}\n\n")
          raise err
        end
      else # no @data?
        retVal = 'null'
      end
      return retVal
    end

    def setup(project, groupId, genbConf)
      if(project.is_a?(BRL::Genboree::Abstract::Resources::Project))
        @projectObj = project
      else # a project name or project id
        @projectObj = BRL::Genboree::Abstract::Resources::Project.new(project, groupId)
      end
      @groupId, @projName = @projectObj.groupId, @projectObj.projName
      @isPublicAccess = @projectObj.isPublicAccess
      @escName = @projectObj.projNameToPath()
      @genbConf = (genbConf or BRL::Genboree::GenboreeConfig.load())
      @dataFileName = "#{@projectObj.projDir}/#{self.class::DATA_FILE}"
      @data = @dataStr = nil
    end

  end
end ; end ; end ; end
