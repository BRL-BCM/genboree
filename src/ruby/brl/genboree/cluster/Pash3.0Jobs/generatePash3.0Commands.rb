#!/usr/bin/env ruby

require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'

module BRL; module Genboree; module Pash

class Pash3CommandGenerator
  @@genomeTopDirectory = "/usr/local/brl/data/pash-targets"
  @@doAlignment = false

  attr_accessor :sequenceFile
  attr_accessor :genomeName # full path under the root of the genome directories
  attr_accessor :dataType
  attr_accessor :topPercent
  attr_accessor :numberOfTopMatches
  attr_accessor :mapFile
  
  def initialize()
    @sequenceFile = nil
    @genomeName = nil
    @dataType = nil
    @percentMatches = nil
    @numberOfTopMatches = nil
    @mapFile = nil
    @maxMappings = 1
  end

  def loadOptions()
    genboreeConfig = BRL::Genboree::GenboreeConfig.new()
    genboreeConfig.loadConfigFile()
    if (!genboreeConfig.genomeTopDirectory.nil?) then
      @@genomeTopDirectory = genboreeConfig.genomeTopDirectory
    end
  end

  def checkArguments()
    if (@sequenceFile==nil) then
      $stderr.puts "sequence file not specified"
      return 1
    end
    if (@genomeName==nil) then
      $stderr.puts "genome name not specified"
      return 1
    end
    if (@dataType==nil) then
      $stderr.puts "sequence type not specified"
      return 1
    end
    if (@topPercent==nil) then
      $stderr.puts "topPercent not specified"
      return 1
    end
    if (@numberOfTopMatches==nil) then
      $stderr.puts "number of top matches not specified"
      return 1
    end
    if (@mapFile.nil?) then
      $stderr.puts "map file not specified"
      return 1
    end
  end

  def generateCommands()
    loadOptions()
    if(checkArguments() == 1) then
      return []
    end
    commandList = ["env", "pwd"]

    # create scratch space
    commandList.push("mkdir scratch")
    commandList.push "ls -latr"
    # generate basic Pash command line
    pashCommandLine = "date; "
    pashCommandLine << "time pash-3.0.exe -v #{File.basename(@sequenceFile)} -h #{@@genomeTopDirectory}/#{@genomeName}/ref.fa -k 13 -n 21 -S . -s 22 -G 2 -d 100"
    pashCommandLine << " -o #{@mapFile}.allIdentities -N #{@maxMappings} -L #{@@genomeTopDirectory}/#{@genomeName}/k13.n21.95p.il"
    pashCommandLine << "> log.#{@mapFile} 2>&1"  
    pashCommandLine << "; filterMappings.exe -P 0.9 -p #{@mapFile}.allIdentities -o #{@mapFile}; sleep 2; bzip2 #{@mapFile}.allIdentities"
    commandList.push(pashCommandLine)
    return commandList
  end
end

end; end; end
