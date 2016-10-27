#!/usr/bin/env ruby
require 'fileutils'
require 'roo'
require 'erubis'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/util/util'

DEBUG = 0

def processArguments()
  # We want to add all the prop_keys as potential command line options
  optsArray = [
    ['--miRNAReadCountFile','-i', GetoptLong::REQUIRED_ARGUMENT],
    ['--sampleDescriptionFile','-s', GetoptLong::REQUIRED_ARGUMENT],
    ['--outputFolder','-o', GetoptLong::REQUIRED_ARGUMENT], 
    ['--factorName','-f', GetoptLong::REQUIRED_ARGUMENT],
    ['--descriptor1','-d', GetoptLong::REQUIRED_ARGUMENT],
    ['--descriptor2','-t', GetoptLong::REQUIRED_ARGUMENT]
  ]
  progOpts = GetoptLong.new(*optsArray)
  usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
  optsHash = progOpts.to_hash
  return optsHash
end

def usage(msg='')
  unless(msg.empty?)
    puts "\n#{msg}\n"
  end
  puts "

  PROGRAM DESCRIPTION:
  Compute fold change of input miRNA expression using the DESeq2 package in R

  COMMAND LINE ARGUMENTS:
  --miRNAReadCountFile        |  -i => exceRpt_miRNA_ReadCounts.txt
  --sampleDescriptionFile     |  -s => exceRpt_miRNA_ReadCounts_coldata.txt
  --outputFolder              |  -o => output_folder
  --factorName                |  -f => factor name (under which both descriptors fall)
  --descriptor1               |  -d => descriptor 1
  --descriptor2               |  -t => descriptor 2

  usage:
  computeFoldChange.rb -i exceRpt_miRNA_ReadCounts.txt -s exceRpt_miRNA_ReadCounts_coldata.txt -o outputFolder -f disease -d AD -t CONTROL
  ";
  exit(110);
end

class FoldChange
  attr_reader :optsHash, :outputDirectory

  #initialize data elements
  def initialize(settingsHash)
    @genbConf = BRL::Genboree::GenboreeConfig.load()
    @optsHash=settingsHash
    @miRNAReadCountFile = File.expand_path(@optsHash["--miRNAReadCountFile"])
    @sampleDescriptionFile = File.expand_path(@optsHash["--sampleDescriptionFile"])    
    @outputDirectory = File.expand_path(@optsHash["--outputFolder"]) 
    @factorName = @optsHash["--factorName"]
    @descriptor1 = @optsHash["--descriptor1"]
    @descriptor2 = @optsHash["--descriptor2"]
    #create output directory
    FileUtils.mkdir_p @outputDirectory
  end

  def computeFoldChange()
    rFile = "#{@outputDirectory}/#{File.basename(@miRNAReadCountFile)}.diffExp.R"
    @outputFile = "#{@outputDirectory}/#{File.basename(@miRNAReadCountFile)}.foldChange.txt"

    erb = Erubis::FastEruby.new( File.read(@genbConf.DESeq2RTemplate) )
    script = erb.evaluate( {
      :outputDirectory => @outputDirectory,
      :miRNAReadCountFile => @miRNAReadCountFile,
      :sampleDescriptionFile => @sampleDescriptionFile,   
      :outputFile => @outputFile,
      :factorName => @factorName,
      :descriptor1 => @descriptor1,
      :descriptor2 => @descriptor2
    } )
    script.gsub!("#{@descriptor1}|#{@descriptor2}", "#{@descriptor1.gsub("(", "\\\\\\\\\\\\\\\\(").gsub(")", "\\\\\\\\\\\\\\\\)")}|#{@descriptor2.gsub("(", "\\\\\\\\\\\\\\\\(").gsub(")", "\\\\\\\\\\\\\\\\)")}") 
    rFileHandler = File.open(rFile, "w")
    rFileHandler.puts "
    #{script}
    "
    rFileHandler.close()
    #run R command
    rstatus = `R --vanilla < #{rFile}`
    puts $?.inspect
    puts rstatus
    if($?.exitstatus != 0)
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "Fold change computation did not succeed\n#{rstatus}\nPlease check logs")
      exit(113)
    end
  end

end

begin
  #check for proper usage and exit if necessary
  settingsHash=processArguments()
  #initialize input data
  fc = FoldChange.new(settingsHash)
  #perform alpha diversity pipeline via work function
  fc.computeFoldChange()
  exit 0
rescue => err
  $stderr.debugPuts(__FILE__, __method__, "ERROR", "Fold change computation did not succeed\n#{err.message}")
  $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err.backtrace.join("\n")}")
  exit(115)
end
