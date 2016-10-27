#!/usr/bin/env ruby

require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'

module BRL; module Genboree; module Pash

class PashCommandGenerator
  @@genomeTopDirectory = "/usr/local/brl/data/pash-targets"
  @@minDiskSpace = 200000 # 200GB
  @@doAlignment = false

  attr_accessor :sequenceFile
  attr_accessor :genomeName # full path under the root of the genome directories
  attr_accessor :dataType
  attr_accessor :topPercent
  attr_accessor :numberOfTopMatches
  attr_accessor :minDiskSpace
  attr_accessor :mapFile

  def initialize()
    sequenceFile = nil
    genomeName = nil
    dataType = nil
    percentMatches = nil
    numberOfTopMatches = nil
    mapFile = nil
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
    if (@minDiskSpace.nil?) then
      @minDiskSpace = @@minDiskSpace
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
    commandList.push("mkdir  scratch")
    commandList.push "ls -latr"
    # generate basic Pash command line
    pashCommandLine = "date; "
    pashCommandLine << " pash.rb -q #{File.basename(@sequenceFile)} -T #{@@genomeTopDirectory}/#{@genomeName} -S scratch "
    pashCommandLine << " -o #{@mapFile} "
    pashCommandLine << "-r #{@dataType} > log.#{@mapFile} 2>&1"
    commandList.push(pashCommandLine)
    # that's it for now
    # bzip2 all pash output files
    #commandList.push("bzip2 #{File.basename(@sequenceFile)}.*onto*")
    # remember, this command will run on the cluster node
    return commandList
  end
end

end; end; end
