#!/usr/bin/env ruby
require 'find'
require 'brl/util/textFileUtil'
require 'brl/util/util'


	
class TarballGenboreeDeployment
  DEBUG = true
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end  
  
  def setParameters()
    @patchFile = @optsHash['--patchFile']
    @topLevelDirsFile = @optsHash['--topLevelDirs']
    puts "deploying patch file #{@patchFile} with top level dirs #{@topLevelDirsFile}"
  end
  
  def convert()
    # build the directory equivalence hash
    dirsReader = BRL::Util::TextReader.new(@topLevelDirsFile)
    dirsHash = {}
    dirsReader.each {|l|
      next if l=~/^\s*$/
      $stderr.puts "l=#{l.strip}" if (DEBUG)
      l =~ /^(\S+)\s+(\S+)$/
      $stderr.puts "adding correspondence #{$1}-->#{$2}"
      dirsHash[$1] = $2
    }
    dirsReader.close()
    # unpack the tarball
    if (@patchFile !~ /^(.*)\.tgz/) then
      $stderr.puts "wrong patch file supplied"
      exit(1)
    end
    patchName = $1
    $stderr.puts "patch: ##{patchName}" if (DEBUG)
    system("tar zxvf #{@patchFile}")
    Find.find(patchName) {|path|
      if (File.file?(path)) then
        $stderr.puts "processing file #{path}"
        if (path !~/(brl-repo.*)$/) then
          $stderr.puts "wrong patch file, #{path} does not contain brl-repo"
          exit(1)
        end
        canonicalPath = File.dirname($1)
        canonicalFile = File.basename ($1)
        $stderr.puts "canonical path #{canonicalPath} canonical file #{canonicalFile}" if (DEBUG)
        found = false
        k = nil
        dirsHash.keys.each {|k|
          if (canonicalPath.index(k)==0)  then
            found = true
            break
          end
        }
        if (!found) then
          $stderr.puts "canonical path not found in #{@topLevelDirsFile}"
          exit(1)
        end
        inTargetPath = canonicalPath[k.size, canonicalPath.size]
        cpCommand = "mkdir -p #{dirsHash[k]}/#{inTargetPath}; cp -rf #{path} #{dirsHash[k]}/#{inTargetPath}"
        while (cpCommand =~ /\/\//)
          cpCommand = cpCommand.gsub("//","/")
        end
        $stderr.puts "executing cp command #{cpCommand}"
        system(cpCommand )
      end
    }
    return
    patchFileReader  =  BRL::Util::TextReader.new(@patchFile)
    myPid = Process.pid
    myTime = Time.now.to_s.gsub(" ","_")
    @tmpDir =""
    @tmpDir << @temporaryDir
    @tmpDir << "/" << myPid.to_s << "." << myTime
    tarballPath= "#{@tmpDir}/#{File.basename(@patchFile)}"
    system("mkdir -p #{tarballPath}")
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
  
  def TarballGenboreeDeployment.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--patchFile',      '-p', GetoptLong::REQUIRED_ARGUMENT],
									['--topLevelDirs',   '-t', GetoptLong::REQUIRED_ARGUMENT],
									['--help',           '-h', GetoptLong::NO_ARGUMENT]
								]
		
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		TarballGenboreeDeployment.usage() if(optsHash.key?('--help'));
		
		unless(progOpts.getMissingOptions().empty?)
			TarballGenboreeDeployment.usage("USAGE ERROR: some required arguments are missing") 
		end
	
		TarballGenboreeDeployment.usage() if(optsHash.empty?);
		return optsHash
	end
	
	def TarballGenboreeDeployment.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Analyzes a Genboree deployment tarball file, and based on a directory correspondence file,
  copies files in the proper locations. NOTE: IT IS YOUR RESPONSIBILITY TO TAKE DOWN THE SERVER
  (IF NECESSARY), TO COMPILE THE CODE, AND TO RESTART THE SERVER.

COMMAND LINE ARGUMENTS:
  --patchFile      |-p   => Genboree patch tarball.
  --topLevelDirs   |-t   => directory correspondence file
  --help           |-h   => [optional flag] Output this usage info and exit

USAGE:
  tarballGenboreeDeploy.rb  -p 3.1.2008.patch.test -t topLevelDirs
";
			exit(2);
		
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = TarballGenboreeDeployment.processArguments()
# Instantiate analyzer using the program arguments
patchToTarballConverter = TarballGenboreeDeployment.new(optsHash)
# Analyze this !
patchToTarballConverter.convert()
exit(0);
