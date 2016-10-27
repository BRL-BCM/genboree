
require 'json'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/abstract/resources/abstractProjectComponent'

module BRL ; module Genboree ; module Abstract ; module Resources
  # Class representing the title of a particular project
  class ProjectTitleImage < AbstractProjectComponent
    # The name of the file that has the data contents or the index of contents
    DATA_FILE = 'genb^^optional/titleGraphic'
    # The type of data stored in the data file
    DATA_FORMAT = :IMG

    # The name of the title graphic file that was found
    attr_accessor :imgFileName
    # The full path to the title graphic file found
    attr_accessor :imgFilePath

    # CONSTUCTOR. Will read & parse component's data file for ready availability from the state variables.
    # [+project+] The project to which this component belongs. Either a BRL::Genboree::Abstract::Resources::Project instance,
    #             the _full_ name of the project, or the id of the project
    # [+groupId+] [optional; default=nil] The groupId that the project belongs to. NOT required if project is a Resources::Project instance
    # [+genbConf+]  [optional] A _loaded_ GenboreeConfig instance
    def initialize(project, groupId=nil, genbConf=nil)
      setup(project, groupId, genbConf)
      getImageFilePath()
    end

    # The image component is empty if there was no title graphic found
    # [+returns+] true if empty, false if not empty
    def empty?()
      return (@imgFileName.nil? or @imgFilePath.nil?)
    end

    # Tries to find the title graphic if any and return a path to it.
    # Sets instance variables @imgFileName and @imgFilePath.
    #
    # [+returns+] Path to the title graphic file or nil if no correctly named file is found.
    def getImageFilePath()
      # Check for a title graphics
      # (1) Check for PNG
      @imgFileName = "#{DATA_FILE}.png"
      @imgFilePath = "#{@projectObj.projDir}/#{@imgFileName}"
      imgFileExists = (File.exist?(@imgFilePath) and File.readable?(@imgFilePath))
      # (2) Else check for JPG
      unless(imgFileExists)
        @imgFileName = "#{DATA_FILE}.jpg"
        @imgFilePath = "#{@projectObj.projDir}/#{@imgFileName}"
        imgFileExists = (File.exist?(@imgFilePath) and File.readable?(@imgFilePath))
        unless(imgFileExists) # then no title graphic
          @imgFileName = @imgFilePath = nil
        end
      end
      @imgFileName.gsub!(/genb\^\^optional\//, '') unless(@imgFileName.nil?)
      return @imgFilePath
    end

    # Get the relative url to the title image.
    # [+returns+] The URL as a String or nil if no title image.
    def getImageUrl()
      retVal = nil
      if(@imgFileName)
        retVal = "/projects/#{@escName}/genb^^optional/#{@imgFileName}"
      end
    end
  end
end ; end ; end ; end
