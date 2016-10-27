#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'

include GSL
include BRL::Genboree::REST

class GeneToEnsemble

  def initialize(optsHash)
    @geneList  = File.expand_path(optsHash['--geneList'])
    @output    = File.expand_path(optsHash['--outputDir'])
    
    system("mkdir #{@output}")
    @ensembleToGene = {}
  end
   
  
  ##Building mapping between Official gene names and their respective ensemble ids
  def buildMap()
    ##Reading ENSEMBL file and buuilding hash of offical gene name and ensembl ids
    fileHandler = File.open("/cluster.shared/data/groups/brl/atlas/Homo_sapiens.GRCh37.65.gtf")
    fileHandler.each{|line|
      line.strip!
      column = line.split(/\t/)
      avps = column[8].split(/;/)
      gene_id = avps[0].split(/\s/)
      gene_name = avps[3].split(/\s/)
      ensemblID = gene_id[2].gsub(/"/,'')
      officialID = gene_name[2].gsub(/"/,'')
      @ensembleToGene[officialID] = ensemblID
    }
    fileHandler.close
  end
  
  ##Reading input file and mapping them ensemble ids
  def readGeneList()
    counts = 0
    countConvert = 0
    fileWriter2 = File.open("#{@output}/unMappedIDs.txt","w+")
    fileWriter = File.open("#{@output}/mappedIDs.txt","w+")
    fileHandler = File.open(@geneList)
    fileHandler.each{|line|
      line.strip!
      columns = line.split(/\t/)
      if(@ensembleToGene.key?(columns[1]))
        countConvert +=1 
        fileWriter.puts "#{columns[1]}\t#{@ensembleToGene[columns[1]]}"
      else
        fileWriter2.puts columns[1]
      end
      counts += 1
      }
    fileHandler.close
    fileWriter.close
    $stdout.puts "total number of input genes = #{counts}"
    puts "total number of mapped genes = #{countConvert}"
  end


  ##help section defined
  def GeneToEnsemble.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
      PROGRAM DESCRIPTION:
        Converts offical gene name to ensemble ids
      COMMAND LINE ARGUMENTS:
        --geneList     | -g => geneList tab delimited(2nd column OFFICIAL gene name)
        --outputDir    | -o => outputDir name
        --help         | -h => [Optional flag]. Print help info and exit.
      usage:
            
        ";
      exit;
  end # 
      
  # Process Arguements form the command line input
  def GeneToEnsemble.processArguements()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ 
                  ['--geneList'        ,'-g', GetoptLong::REQUIRED_ARGUMENT],
                  ['--outputDir'       ,'-o', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--help'            ,'-H', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    GeneToEnsemble.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash
    Coverage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end 
  
end

begin
optsHash = GeneToEnsemble.processArguements()
performQCUsingFindPeaks = GeneToEnsemble.new(optsHash)
performQCUsingFindPeaks.buildMap()
performQCUsingFindPeaks.readGeneList()
rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
end

