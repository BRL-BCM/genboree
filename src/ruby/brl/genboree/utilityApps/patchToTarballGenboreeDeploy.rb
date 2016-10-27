#!/usr/bin/env ruby

require 'brl/util/textFileUtil'
require 'brl/util/util'


	
class PatchToTarballGenboreeDeployment
  DEBUG = true
  def initialize(optsHash)
		#)readsFile, offsetsFile, allSeqFile, snpOutputFile)
		@optsHash = optsHash
		setParameters()
	end  
  
  def setParameters()
    @patchFile = @optsHash['--patchFile']
    @outputDir = @optsHash['--outputDir']
    @temporaryDir = @optsHash['--temporaryDir']
    puts "analyzing patch file #{@patchFile} with top level dirs #{@topLevelDirs}; tarball #{@patchFile}.tgz will be generated in #{@outputDir}; will use #{@temporaryDir} as temporary directory"
  end
  
  def convert()
    system("dos2unix #{@patchFile}"
    patchFileReader  =  BRL::Util::TextReader.new(@patchFile)
    myPid = Process.pid
    myTime = Time.now.to_s.gsub(" ","_")
    @tmpDir =""
    @tmpDir << @temporaryDir
    @tmpDir << "/" << myPid.to_s << "." << myTime
    tarballPath= "#{@tmpDir}/#{File.basename(@patchFile)}"
    system("mkdir -p #{tarballPath}")
    system("mkdir -p #{@outputDir}")
    $stderr.puts "created directory #{@tmpDir}" if (DEBUG)
    revisionHash = {}
    l = nil
    currentSVNRevision = nil
    currentSVNFile = nil
    patchFileReader.each {|l|
      next if (l=~/^\s*$/)
      if (l =~/PATCH NAME:\s*(\S+)$/) then
        puts "patch name:\t#{$1}"
      elsif (l=~/DATE:\s*(\S+)$/) then
        puts "patch date:\t#{$1}"
      elsif (l =~/DEV NAME:\s*(\S+)$/) then
        puts "developer:\t#{$1}"
      elsif (l =~ /DEPLOYED @:(.*)$/ ) then
        puts "deployed at:\t#{$1}"
      elsif (l=~/DESC:(.*)$/) then
        puts "description:\t#{$1}"
      elsif (l=~/REVISION:\s*(\d+)(\s|$)/) then
        currentSVNRevision = $1
        puts "set current revision to:\t#{currentSVNRevision}"
      elsif (l=~/(svn:\/\/proline.brl.bcm.tmc.edu\/(.*))$/) then
        currentSVNFile = $1
        currentRelativePath = File.dirname($2)
        currentFile = File.basename($2)
        if (currentSVNRevision == nil) then
          puts "no revision provided for svn-controlled file #{currentSVNFile}"
        else
          puts "adding file #{currentSVNFile} with revision #{currentSVNRevision}"
          if (!revisionHash.key?(currentSVNRevision)) then
            revisionHash[currentSVNRevision]=[currentSVNFile]
          else
            revisionHash[currentSVNRevision].push(currentSVNFile)
          end
          # create the output directory
          $stderr.puts "current relative path #{currentRelativePath}" if (DEBUG)
          # copy the patch file into the output directory
          mkdirCommand = "mkdir -p #{tarballPath}/#{currentRelativePath}"
          $stderr.puts "mkdirCommand = #{mkdirCommand}" if (DEBUG)
          system(mkdirCommand)
          svnCommand = "svn export --force -r #{currentSVNRevision} #{currentSVNFile} #{tarballPath}/#{currentRelativePath}/#{currentFile}"
          $stderr.puts "about to execute #{svnCommand}"
          system(svnCommand)
        end
      else
        puts "#smth else\t#{l.strip}"
      end
    }
    patchFileReader.close()
    tarCommand = "cd #{@tmpDir}; tar zcvf #{File.basename(@patchFile)}.tgz #{File.basename(@patchFile)}; cd -"
    $stderr.puts "about to execute tar command #{tarCommand}" if (DEBUG)
    system(tarCommand)
    system("mv #{@tmpDir}/#{File.basename(@patchFile)}.tgz #{@outputDir}")
    $stderr.puts "removing temporary directory #{@tmpDir}" if (DEBUG)
    system("rm -rf #{@tmpDir}")
  end
  
  def PatchToTarballGenboreeDeployment.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--patchFile',      '-p', GetoptLong::REQUIRED_ARGUMENT],
									['--outputDir',      '-c', GetoptLong::REQUIRED_ARGUMENT],
									['--temporaryDir',   '-s', GetoptLong::REQUIRED_ARGUMENT],
									['--help',           '-h', GetoptLong::NO_ARGUMENT]
								]
		
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		PatchToTarballGenboreeDeployment.usage() if(optsHash.key?('--help'));
		
		unless(progOpts.getMissingOptions().empty?)
			PatchToTarballGenboreeDeployment.usage("USAGE ERROR: some required arguments are missing") 
		end
	
		PatchToTarballGenboreeDeployment.usage() if(optsHash.empty?);
		return optsHash
	end
	
	def PatchToTarballGenboreeDeployment.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Analyzes a Genboree deployment patch file, retrieves the proper versions, and generates a tarball containing
  ONLY the affected files, and displays various notes and messages. 

COMMAND LINE ARGUMENTS:
  --patchFile      |-p   => Genboree patch file.
  --outputDir      |-c   => output directory
  --temporaryDir   |-s   => scratch directory
  --help           |-h   => [optional flag] Output this usage info and exit

USAGE:
  patchToTarballGenboreeDeploy.rb  -p 2000-01-01.y2kPatch -c . -s /tmp/ 
";
			exit(2);
		
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = PatchToTarballGenboreeDeployment.processArguments()
# Instantiate analyzer using the program arguments
patchToTarballConverter = PatchToTarballGenboreeDeployment.new(optsHash)
# Analyze this !
patchToTarballConverter.convert()
exit(0);
