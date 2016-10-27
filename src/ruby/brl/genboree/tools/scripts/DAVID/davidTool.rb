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

class DavidTool

  def initialize(optsHash)
    @geneList  = File.expand_path(optsHash['--geneList'])
    @outputDir = File.expand_path(optsHash['--outputDir'])
  end
   
  
  ##Convert official gene name to ENSEMBL ids
  def convertIds()
    cmd = "geneToEnsemble.rb -g #{@geneList} -o #{@outputDir}"
    system(cmd)
  end
  
  ## calling all the 4 DAVID api
  def tableReport()
    cmd = "tableReport.pl #{@outputDir}"
    system(cmd)
  end
  
  def chartReport()
    cmd = "chartReport.pl #{@outputDir}"
    system(cmd)
  end
  
  def geneClusterReport
    cmd = "geneClusterReport.pl #{@outputDir}"
    system(cmd)
  end
  
  def termClusterReport()
    cmd = "termClusterReport.pl #{@outputDir}"
    system(cmd)
  end
    
  


  ##help section defined
  def DavidTool.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
      PROGRAM DESCRIPTION:
        Converts gene official name list to ENSEMBL ids and then call DAVID api
      COMMAND LINE ARGUMENTS:
        --geneList     | -g => geneList
        --outputDir    | -o => outputDir
        --help         | -h => [Optional flag]. Print help info and exit.
      usage:
            ruby davidTool -g /home/tandon/test13
        ";
      exit;
  end # 
      
  # Process Arguements form the command line input
  def DavidTool.processArguements()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ 
                  ['--geneList'        ,'-g', GetoptLong::REQUIRED_ARGUMENT],
                  ['--outputDir'       ,'-o', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'            ,'-H', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    DavidTool.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash
    Coverage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end 
  
end

begin
optsHash = DavidTool.processArguements()
performQCUsingFindPeaks = DavidTool.new(optsHash)
performQCUsingFindPeaks.convertIds()
performQCUsingFindPeaks.tableReport()
performQCUsingFindPeaks.chartReport()
performQCUsingFindPeaks.geneClusterReport()
performQCUsingFindPeaks.termClusterReport()
exitStatus = 0
rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      exitStatus = 118
end

