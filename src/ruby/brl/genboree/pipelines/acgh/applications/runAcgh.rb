#!/usr/bin/env ruby

require 'getoptlong'
require 'rubygems'
require 'rein'
require 'cgi'
require 'json'
require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/fileFormats/lffHash'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class RunCreatePipeLine

  
DEFAULTUSAGEINFO ="

      Usage: runAcgh.rb Agilent Pipeline Version: #{BRL::Genboree::Pipelines::Acgh::AGILENT_PIPELINE_VERSION}
      Transform a agilent aCGH file into a lff file, segment the file, intersect the segments with set of tracks, change color of results, 
      upload the probes and segments into a genboree db, generate vgp images and create a project page.
      
  
      Mandatory arguments:
      -f,    --agilentFileName               Agilent aCGH file.
      -u,    --userId			   Genboree's user id.
      -r,   --refSeqId			   Genboree's database id.
      -g,   --genboreeGroupId               Genboree's Group Id.
      -s,   --agilentSegmentStddev          Standard deviation used with the segmentation tool.
      -m,   --agilentMinProbes              Number of probes used with the segmentation tool.
      -t,   --listOfIntersectionTracks      A semicolon separated list of tracks to use. The tracks should be present in the database and should be order by priority.
      -c,   --listOfGainColors              A coma separated list of Colors of gain segments should correspond to the number of tracks.
      -l,   --listOfLossColors              A coma separated list of Colors of loss segments should correspond to the number of tracks.
      -d,   --scratchDir                    Path to directory where operations would be performed.
      -b,  --baseProjectName               project name (main project).
      -p,    --projectId			   sub project name normally a patient id.
      -a,   --agilentClass		   class name for the probes.
      -i,   --agilentType		   type name for the probes.
      -e,  --agilentSubtype		   subtype name for the probes.
      -x,   --segmentClassName	           class name for the segments.
      -y,   --segmentType                   type name for the segments.
      -z,  --segmentSubtype                subtype name for the segments.
      Optional arguments:
      -1    --defaultPropFile,              a json file with default values for the vgp.
      -q    --nuberOfGenomicPanels          number of genomic panels to generate default 3 
      -n    --printCommandsOnly,            a flag that force to print the commands instead of executing them.
      -w,   --pipeLineFile,		   the name of the pipeLine file a default would be used if not provided.
      -v,   --version             Display version.
      -h,   --help, 			   Display help
      
"


    def self.printUsage(additionalInfo=nil)
      puts DEFAULTUSAGEINFO
      puts additionalInfo unless(additionalInfo.nil?)
      if(additionalInfo.nil?)
        exit(0)
      else
        exit(15)
      end
    end
    
    def self.printVersion()
      puts BRL::Genboree::Pipelines::Acgh::AGILENT_PIPELINE_VERSION
      exit(0)
    end

    def self.parseArgs()
          
      methodName = "runCreatePipeLine"

optsArray = [
                    ['--agilentFileName', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--agilentSegmentStddev', '-s', GetoptLong::REQUIRED_ARGUMENT],
                    ['--agilentMinProbes', '-m', GetoptLong::REQUIRED_ARGUMENT],
                    ['--listOfIntersectionTracks', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--listOfGainColors', '-c', GetoptLong::REQUIRED_ARGUMENT],
                    ['--listOfLossColors', '-l', GetoptLong::REQUIRED_ARGUMENT],
                    ['--userId', '-u', GetoptLong::REQUIRED_ARGUMENT],
                    ['--refSeqId', '-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--scratchDir', '-d', GetoptLong::REQUIRED_ARGUMENT],
                    ['--baseProjectName', '-b', GetoptLong::REQUIRED_ARGUMENT],
                    ['--projectId', '-p', GetoptLong::REQUIRED_ARGUMENT],
                    ['--agilentClass', '-a', GetoptLong::REQUIRED_ARGUMENT],
                    ['--agilentType', '-i', GetoptLong::REQUIRED_ARGUMENT],
                    ['--agilentSubtype', '-e', GetoptLong::REQUIRED_ARGUMENT],
                    ['--segmentClassName', '-x', GetoptLong::REQUIRED_ARGUMENT],
                    ['--segmentType', '-y', GetoptLong::REQUIRED_ARGUMENT],
                    ['--segmentSubtype', '-z', GetoptLong::REQUIRED_ARGUMENT],
                    ['--genboreeGroupId', '-g', GetoptLong::REQUIRED_ARGUMENT],
                    ['--defaultPropFile', '-1', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--printCommandsOnly', '-n', GetoptLong::NO_ARGUMENT],
                    ['--pipeLineFile', '-w', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--nuberOfGenomicPanels', '-q', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--version', '-v',   GetoptLong::NO_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]


      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      
      if(optsHash.key?('--help'))
        printUsage()
      elsif(optsHash.key?('--version'))
        printVersion()
      end
      printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)

      return optsHash
    end



    def self.runCreatePipeLine(optsHash)
      
    defaultPropFile = nil
    pipeLineFile = nil
    numberOfGenomicPanels = 3
    
    defaultPropFile = optsHash['--defaultPropFile'] if(optsHash.has_key?('--defaultPropFile') and !optsHash['--defaultPropFile'].nil?)
    pipeLineFile = optsHash['--pipeLineFile'] if(optsHash.has_key?('--pipeLineFile') and !optsHash['--pipeLineFile'].nil?)
    numberOfGenomicPanels = optsHash['--nuberOfGenomicPanels'] if(optsHash.has_key?('--nuberOfGenomicPanels') and !optsHash['--nuberOfGenomicPanels'].nil?)  

      pipeLine = CreatePipeLine.new(  optsHash['--agilentFileName'], optsHash['--agilentSegmentStddev'], optsHash['--agilentMinProbes'],
                                      optsHash['--listOfIntersectionTracks'], optsHash['--listOfGainColors'], optsHash['--listOfLossColors'], optsHash['--userId'],
                                      optsHash['--refSeqId'], optsHash['--baseProjectName'], optsHash['--projectId'], optsHash['--scratchDir'], optsHash['--agilentClass'],
                                      optsHash['--agilentType'], optsHash['--agilentSubtype'], optsHash['--segmentClassName'], optsHash['--segmentType'],
                                      optsHash['--segmentSubtype'], optsHash['--genboreeGroupId'], pipeLineFile, defaultPropFile, numberOfGenomicPanels)


      Dir.chdir(optsHash['--scratchDir'])

      if(optsHash.has_key?('--printCommandsOnly'))
        mode = "printOnly"
      end    
       
    
      ReadACGHJsonFile.new(pipeLine.jsonFileWithPipeLine, optsHash['--scratchDir'], mode)

      unless(optsHash.has_key?('--printCommandsOnly') )    
        filesToCompress = pipeLine.allFiles    
        filesToCompress.each{|myFile|
           Acgh.compressFile(myFile)
          }
      end

    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::RunCreatePipeLine.parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::RunCreatePipeLine.runCreatePipeLine(optsHash)
