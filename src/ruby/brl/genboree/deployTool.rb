#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'            # For GetoptLong class (command line option parse)
require 'fileutils'
require 'brl/util/util'         # For to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/util/logger'
require 'brl/genboree/genboreeUtil'

module BRL ; module Genboree

class DeploymentTool
  # ----------------------------------------------------------------------------
  # CONSTANTS
  # ----------------------------------------------------------------------------
  GZIP = BRL::Util::TextWriter::GZIP_OUT
  PROP_KEYS = %w{
                  input.genboreeTopLevel
                  input.projectTopLevel
                  input.configTopLevel
  							  input.excludeFile
  							  input.includeFile
  							  input.projectFile
  							  output.logDir
  							}

  # ----------------------------------------------------------------------------
  # ATTRIBUTES
  # ----------------------------------------------------------------------------
  attr_accessor :logger, :logFileName
  # ----------------------------------------------------------------------------
  # OBJECT METHODS
  # ----------------------------------------------------------------------------
  
  def initialize(optsHash)
  	@propTable = BRL::Util::PropTable.new(File.open(optsHash['--propFile']))
  	# If options supplied on command line instead, use them rather than those in propfile
  	PROP_KEYS.each { |propName|
  		argPropName = "--#{propName}"
  	  @propTable[propName] = optsHash[argPropName] unless(optsHash[argPropName].nil?)
  	}
  	# Verify the proptable contains what we need
  	@propTable.verify(PROP_KEYS)
  	setParameters()
  	# Initialize some variables
  	@logger = BRL::Util::Logger.new()
  	@logger.logFileName = @logFileName
  	@logger.addNewError("#{Time.now.to_s}: BEGIN DEPLOYMENT: Deployer initialized.")
  end # END: def initialize(optsHash)

	def setParameters()
	  @genbTopLevel = @propTable['input.genboreeTopLevel'].strip
	  @genbTopLevel += '/' unless(@genbTopLevel =~ /\/$/)
	  @projTopLevel = @propTable['input.projectTopLevel'].strip
	  @projTopLevel += '/' unless(@projTopLevel =~ /\/$/)
	  @configTopLevel = @propTable['input.configTopLevel'].strip
	  @configTopLevel += '/' unless(@configTopLevel =~ /\/$/)
	  @excludeFileName = @propTable['input.excludeFile']
	  @includeFileName = @propTable['input.includeFile']
	  @projectFileName = @propTable['input.projectFile']
	  @logDir = @propTable['output.logDir']
	  makeLogFileName()
		return
	end # END: def setParameters()
	
	def makeLogFileName()
	  @logFileName = @logDir +'/deployTool.' + Time.now.strftime("%d-%m-%Y@%H:%M:%S") + '.log.gz'
	  return @logFileName
	end
	
	def deploy()
	  @logger.addNewError("#{Time.now.to_s}: BEGIN: deploy files to projects")
	  # Get the list of projects to deploy to
	  getProjectDirs()
    # For each projectDir
    @projectDirList.each { |projectSubDir|
	    @logger.addNewError("    #{Time.now.to_s}: DOING: project dir '#{projectSubDir}'")
	    # Init ALL file lists
	    @fileList = {}
	    getIncludeFileList(projectSubDir)
	    @excludeList = {}
	    getExcludeFileList(projectSubDir)
	    removeExcludedFiles()	    
      # For each include file
      @fileList.each_key { |srcFile|
        srcFile =~ /^.+\/([^\/]+)$/
        fileName = srcFile.gsub(@genbTopLevel, '')
        if(fileName.nil? or fileName.empty?)
          @logger.addNewError("\n\nERROR: can't get file name from '#{srcFile}'. Skipping.\n\n")
          next
        end
        destFile = @projTopLevel + projectSubDir + fileName
        # Make sure the directory and subdirs are present
        FileUtils::mkdir_p(File::dirname(destFile))
        # Force hard link file into project dir
        FileUtils::ln(srcFile, destFile, { :force => true } )
        # Touch src file also (should force compilation)
        FileUtils::touch(srcFile)
        # Touch hardlink
        FileUtils::touch(destFile)
        @logger.addToActiveError("        #{srcFile} -> #{destFile}")
      }
    }
	  @logger.addNewError("#{Time.now.to_s}: END: deploy files to projects")
	  return
	end
	
	def getProjectDirs()
	  @logger.addNewError("#{Time.now.to_s}: BEGIN: get project dir list")
    @projectDirList = []
	  # Open project dir file
	  reader = BRL::Util::TextReader.new(@projectFileName)
	  # For each line, treat it as a file-glob pattern and save the list of files
	  reader.each { |line|
	    line.strip!
	    line += '/' unless(line =~ /\/$/)
	    @projectDirList << line
	  }
	  # Close file
	  reader.close
	  @logger.addNewError("#{Time.now.to_s}: END: get project dir list")
	  return
	end
	
	def getIncludeFileList(projectSubDir)
	  @logger.addNewError("#{Time.now.to_s}: BEGIN: read file list")
	  # Open include file
	  includeFileName = @configTopLevel + projectSubDir + @includeFileName
	  reader = BRL::Util::TextReader.new(includeFileName)
	  # For each line, treat it as a file-glob pattern and save the list of files
	  reader.each { |line|
	    line.strip!
	    Dir::glob(line).each { |fileName|
	      fileName.strip!
	      next if(fileName =~ /^\.+$/)
	      @fileList[fileName] = nil
	    }
	  }
	  # Close file
	  reader.close
	  @logger.addNewError("#{Time.now.to_s}: END: read file list")
	  return
	end
	
	def getExcludeFileList(projectSubDir)
	  @logger.addNewError("#{Time.now.to_s}: BEGIN: read exclude file list")
	  # Open exclude file
	  excludeFileName = @configTopLevel + projectSubDir + @excludeFileName
	  reader = BRL::Util::TextReader.new(excludeFileName)
	  # For each line, treat it as a file-glob pattern and save the list of files
	  reader.each { |line|
	    line.strip!
	    @excludeList[line] = nil
	  }
	  # Close file
	  reader.close
	  @logger.addNewError("#{Time.now.to_s}: END: read exclude file list")
	  return
	end
	
	def removeExcludedFiles()
	  @logger.addNewError("#{Time.now.to_s}: BEGIN: remove excluded files")
	  @excludeList.each_key { |fileName|
	    @fileList.delete(fileName)
	    @logger.addToActiveError("        #{fileName}")
	  }
	  @logger.addNewError("#{Time.now.to_s}: END: remove excluded files")
	  return
	end
	
	def writeLog()
	  @logger.addNewError("#{Time.now.to_s}: Writing log file before quitting")
	  @logger.writeToFile(GZIP)
	  @logger.close
	  return
	end
	
	def clear()
	  self.writeLog()
    return
	end
	
	alias_method :close, :clear
	
	# ----------------------------------------------------------------------------
	# CLASS METHODS
	# ----------------------------------------------------------------------------
	
  def DeploymentTool.processArguments
		optsArray =	[	['--propFile', '-p', GetoptLong::REQUIRED_ARGUMENT],
									['--help', '-h', GetoptLong::NO_ARGUMENT]
								]
		# We want to add all the prop_keys as potential command line options
		PROP_KEYS.each { |propName|
			argPropName = "--#{propName}"
			optsArray << [argPropName, GetoptLong::OPTIONAL_ARGUMENT]
		}
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		DeploymentTool.usage() if(optsHash.empty? or optsHash.key?('--help'));
		return optsHash
	end

	def DeploymentTool.usage(msg='')
 		puts "\n#{msg}\n" unless(msg.empty?)
  	puts "
  
  PROGRAM DESCRIPTION:
  Deploys updated CORE Genboree files (*.jsp, *.incl) to specific project
  sub-dirs.
  
  Lists of file patterns, excluded files, and project sub-dir locations are
  provided in separate files.
  
  A configuration properties file for basic parameters is required.
  
  COMMAND LINE ARGUMENTS:
    -p    => Properties file with configuration parameters.
    -h    => [optional flag] Output this usage info and exit
  
  USAGE:
  deployTool -p deploy.properties
  ";
  	exit(BRL::Genboree::USAGE_ERROR);
  end # def Deploymenttool.usage(msg='')
end # class DeploymentTool

end ; end 

# ##############################################################################
# MAIN
# ##############################################################################
begin
  # Get command line args
  optsHash = BRL::Genboree::DeploymentTool.processArguments()
  # Init deployment object, read properties file, set params
  deployer = BRL::Genboree::DeploymentTool.new(optsHash)
  # Deploy files to project dirs
  deployer.deploy()
  # Clean up
  deployer.clear
rescue => err
  $stderr.puts "\n\nERROR: serious failure during deployement.\n\nError message: '#{err.message}'\n\nStacktrace:\n\n" + err.backtrace.join("\n")
  exit(136)
end

exit(0)

	
