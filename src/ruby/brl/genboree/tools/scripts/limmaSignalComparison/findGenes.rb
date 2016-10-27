#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/pash/annotationIndex.rb'
require 'fileutils'

class GenenMiRNA
  DEBUG = false
  
  def initialize(optsHash)
    @file1 = File.expand_path(optsHash['--file1'])
    @file2 = File.expand_path(optsHash['--file2'])
    @annotationIndex = BRL::Pash::AnnotationIndex.new()
    @geneHash = {}
    @geneStruct = Struct.new("Gene", :chrom, :chromStart, :chromStop, :rank)
    @probeHashNew = Hash.new {|k,v| k[v] =[]}
  end
  
  ##Reading probe file and adding annotations in hash using annotationIndex
  def readProbeFile()
    file = File.open(@file1)
    geneName = ""
    arrayStart = []
    arrayStop = []
    rank = 1
    file.each {|line|
      line.strip!
      column = line.split(/\t/)
      @probeHashNew["#{column[4]}_#{column[5]}_#{column[6]}_#{rank}"].push(column[5].to_i, column[6].to_i)
      @annotationIndex.addAnnotation(column[4], column[5].to_i, column[6].to_i, rank)
      rank += 1
    }
     
    end
  
  ##hash of genes existing in ATLAS
  def atlasGenes
    @atlasHash = {}
    file = File.open("/cluster.shared/data/groups/brl/atlas/genesDataFreeze2.txt")
    file.each {|probe|
      probe.strip!
      probes = probe.split(/\t/)
      probeName = probes[0].split(/\./)[0]
      @atlasHash[probeName] =0
      }
    file.close
  end
  
   
  ##Reading gene file and finding overlap regions
  def readWholeGeneFile()
    atlasGenes()
    file = File.open(@file2)
    fileOutput = File.open("output", "w+")
    arrayRank = []
    file.each {|line|
        found = true
        alreadyFound = false
        column = line.split(/\t/)
        geneName = column[1].split(/\:/)[1]
        if(@atlasHash.key?(geneName))
	  overlappingAnnos = @annotationIndex.getOverlappingAnnotations(column[4], column[5].to_i, column[6].to_i )
	  if (overlappingAnnos != nil) then
	    minRank = overlappingAnnos[0].info.to_i
	    overlappingAnnos.each {|anno|
	      if (anno.info.to_i<minRank) then
		minRank=anno.info
	      end
	    }
	    fileOutput.puts  "#{column[1]}\t#{minRank}"
	  end
        end
        }
      fileOutput.close
      
      ##Sorting and formatting of output file
      system("sort -k2n output| cut -d':' -f2|uniq |sort -k1 |uniq |sort -k2n > sorted_geneList")
      switchColumns("sorted_geneList", "sorted_geneList.xls")
  end
  
  # this step occurs early, so we don't create illogical dependencies between project links and meaningful analysis
  def switchColumns(sortedGeneList, sortedGeneListXls)
    fileW = File.open("#{sortedGeneListXls}.temp", "w")
    fileReader = File.open(sortedGeneList)
    fileReader.each {|gene|
      gene.chomp!
      c = gene.split(/\t/)
      fileW.puts "#{c[1]}\t#{c[0]}"
    }
    fileW.close
    fileReader.close
    system("sort -k1n #{sortedGeneListXls}.temp > #{sortedGeneListXls}")
  end
  
  
  def GenenMiRNA.processArguments()
    # We want to add all the prop_keys as potential command line options
    optsArray =	[ ['--file1',       '-f', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--file2',       '-s', GetoptLong::OPTIONAL_ARGUMENT]
              	]

    progOpts = GetoptLong.new(*optsArray)
    optsHash = progOpts.to_hash
    GenenMiRNA.usage() if(optsHash.key?('--help'));

    unless(progOpts.getMissingOptions().empty?)
      GenenMiRNA.usage("USAGE ERROR: some required arguments are missing")
    end

    GenenMiRNA.usage() if(optsHash.empty?);
    return optsHash
  end
   
   
   def GenenMiRNA.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

  PROGRAM DESCRIPTION:
    Finds whole genes and its coreesponding mirna by finding the overlapping regions
   
  COMMAND LINE ARGUMENTS:
    --file1         | -f => Input gene lff file
    --file2         | -s => Input mirna lff file
    --help          | -h => [Optional flag]. Print help info and exit.

 usage:
 
  ";
      exit;
  end # 
  
   
end
optsHash = GenenMiRNA.processArguments()
performQCUsingFindPeaks = GenenMiRNA.new(optsHash)
performQCUsingFindPeaks.readProbeFile()
performQCUsingFindPeaks.readWholeGeneFile()
exit(0)

