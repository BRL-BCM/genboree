
require 'stringio'
require 'brl/util/util'
require 'brl/genboree/abstract/resources/fileManagement'
require 'brl/genboree/abstract/resources/dataIndexFile'

#--
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
  # Class representing the list of files related to a particular database
  class DatabaseFiles
    # mixin that includes most of the generic file management functionality
    include BRL::Genboree::Abstract::Resources::FileManagement
    include BRL::Genboree::Abstract::Resources::DataIndexFile

    # Overridden constants
    # The name of the file that has the data contents or the index of contents
    DATA_FILE = 'databaseFiles.json'
    # The auto-archive threshold (2 weeks in seconds)
    AUTOARCHIVE_THRESHOLD = 2 * 7 * 24 * 60 * 60
    # List of editable fields within a file index record
    EDITABLE_INDEX_FIELDS = [ 'autoArchive', 'archived', 'date', 'description', 'fileName', 'label', 'hide', 'attributes' ]
    # The minimum number of files in the current files list
    MIN_CURRENT_FILES = 5
    # The type of data stored in the data file managed by DataIndexFile.
    DATA_FORMAT = :JSON

    # Each class that uses this module as a mixin should have the following instance vars
    # Array of the non-archived files [index records]
    attr_accessor :currentFiles
    # Array of the archived files [index records]
    attr_accessor :archivedFiles
    # Directory where all the files of this live
    attr_accessor :filesDir
    # Name of the index file (no path)
    attr_accessor :indexFileName
    # Hash of base file names that should not be exposed as files
    attr_accessor :fileKillList
    # Base location of files in grp & db
    attr_accessor :grpDbFileBase

    def initialize(groupName, refseqName, genbConf=nil)
      @atomicModify = true
      @data = []
      @dataStr = ''
      @currentFiles = []
      @archivedFiles = []
      @groupName, @refseqName = groupName, refseqName
      @escGrpName = CGI.escape(@groupName)
      @escRefseqName = CGI.escape(refseqName)
      @genbConf = (genbConf or BRL::Genboree::GenboreeConfig.load())
      #@grpDbFileBase = "#{@genbConf.gbDataFileRoot}/grp/#{@escGrpName}/db/#{@escRefseqName}"
      @grpDbFileBase = self.class.buildFileBase(@escGrpName, @escRefseqName, true, @genbConf)
      @dataFileName = "#{@grpDbFileBase}/#{self.class::DATA_FILE}"
      FileUtils.mkdir_p(@grpDbFileBase)
      @filesDir = Dir.new(@grpDbFileBase)
      @indexFileName = File.basename(DATA_FILE)
      @fileKillList = {
        @indexFileName => true,
        '.svn' => true ,
        '*.idx' => true,
        '*.partial' => true,
        '*.tmp-uploadInProgress' => true
      }

      readDataFile()
      parseDataStr(DATA_FORMAT)
      # Need to process file index to pick up any files that were added to the dir but not the index
      # Needs to be after readDataFile otherwise file gets overwritten
      processFileIndex()
    end

    # Constructs a relative URL path [link] to the file mentioned in the file record
    # for use in href attribute of HTML tags.
    # [+returns+] Relative URL path as String
    def getUrlPath(fileRec)
      filePath = fileRec['fileName']
      escFilePath = filePath.split('/').map { |xx| CGI.escape(xx) }.join('/')
      return "#{@grpDbFileBase}/#{escFilePath}"
    end

    def self.buildFileBase(grpName, refseqName, paramsAreEscaped=false, genbConf=nil, remoteBaseDir=nil)
      retVal = ""
      # If we have both grpName and refseqName, then we can proceed - otherwise, we'll return ""
      if(grpName and refseqName)
        # Escape group name and refseq name if necessary
        escGrpName = (paramsAreEscaped ? grpName : CGI.escape(grpName))
        escRefseqName = (paramsAreEscaped ? refseqName : CGI.escape(refseqName)) 
        # Grab genbConf if we need to 
        genbConf = (genbConf or BRL::Genboree::GenboreeConfig.load())
        # If we have a remote base dir given, then use that instead of local gbDataFileRoot
        if(remoteBaseDir)
          retVal = "#{remoteBaseDir}/grp/#{escGrpName}/db/#{escRefseqName}"
        else
          retVal = "#{genbConf.gbDataFileRoot}/grp/#{escGrpName}/db/#{escRefseqName}"
        end
      end
      return retVal
    end

  end
end ; end ; end ; end
#!/usr/bin/env ruby
