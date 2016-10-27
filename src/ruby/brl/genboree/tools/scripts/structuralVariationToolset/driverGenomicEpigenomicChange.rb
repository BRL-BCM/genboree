#!/usr/bin/env ruby
require 'csv'
require 'cgi'
require 'json'
require 'fileutils'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'

include BRL::Genboree::REST


class SVReport

  ##Intitialization of data
  def initialize(optsHash)
    @tracks         = optsHash["--tracks"]
    @scratch        = optsHash["--scratch"]
    @output         = optsHash["--output"]
    @analysis       = optsHash["--analysis"]
    @resolution     = optsHash["--resolution"]
    @lffClass       = optsHash["--lffClass"]
    @lffType        = optsHash["--lffType"]
    @lffSubType     = optsHash["--lffSubType"]
    @radius         = optsHash["--radius"]
    @gbConfFile     = "/cluster.shared/local/conf/genboree/genboree.config.properties"
  
    @grph       = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper   = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @trackhelper= BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)

    @exitCode   = ""
    @success    = false

  end
  
  
  ##Main to call all other functions
  def main()
    begin
      system("mkdir -p #{@scratch}")
      Dir.chdir(@scratch)
      @outputDir = "#{@scratch}/signal-search/#{@analysis}"
      system("mkdir -p #{@outputDir}")
     
      signalComparison()
      filteringZscores()
      lffIntersection
      runSVReportDriver()
      createGeneList()
      convertingXltoCSV
      intersection()
    rescue => err
      $stderr.puts err.backtrace.join("\n")
      sendFailureEmail(err)
    end
  end
  
  ##Running comparisons between two tracks
  ##run the signal comparison between the two wig tracks, no quantile normalization, at 10kb windows
  def signalComparison()
    cmd ="pairWiseSignalSearchTool.rb -f '#{@tracks}' -s #{@scratch} -o #{@outputDir} -F LFF -c false -a #{@analysis} -r #{@resolution} "
    cmd << " -l #{@lffClass} -L #{@lffType} -S #{@lffSubType} -q false> #{@outputDir}/signalComparison.log 2>#{@outputDir}/signalComparison.error.log"
    $stdout.puts cmd
    system(cmd)
    
  end
  
  ##Filtering  according to zscore
  ## determine the areas with z-score >=3 or <=-3.
  def filteringZscores()
    ##uncompressing gz file created by signalComparison()
    puts @outputDir
    expanderObj = BRL::Genboree::Helpers::Expander.new("#{@outputDir}/finalUploadSummary.lff.gz")
    if(compressed = expanderObj.isCompressed?("#{@outputDir}/finalUploadSummary.lff.gz"))
      expanderObj.extract('text')
      fullPathToUncompFile = expanderObj.uncompressedFileName
    end
    
    file = File.open(fullPathToUncompFile, 'r')
    fileOut = File.open("#{@outputDir}/filtered_zScore.lff" , "w+")
    file.each {|line|
      line.strip!
      columns = line.split(/\t/)
      avps = columns[12].split(/\s/)
      zLabel = avps[5].split(/\=/)
      zScore = zLabel[1].chomp(';').to_f
      if(zScore  >= 3.0 or zScore <= -3.0)
        fileOut.puts line
      end
      }
    fileOut.close()
    file.close()   
  end
  
  ##Intersect with the whole gene file; for hg18 is in /cluster.shared/data/groups/brl/fasta/hg18/hg18.wholeGene.lff
  def lffIntersection()
    cmd = "module load glib/2.24.2; lffIntersect.rb -s #{CGI.escape("L:-a")} -f #{CGI.escape("Whole_Gene:RefSeq")} "
    cmd << " -l '/cluster.shared/data/groups/brl/fasta/hg18/hg18.wholeGene.lff,#{@outputDir}/filtered_zScore.lff' -o #{@outputDir}/filtered_intersected -n #{CGI.escape("Whole_Gene:RefSeq")} "
    $stdout.puts cmd
    system(cmd)
  end
  
  ##run tool 4 with the SV track and the whole gene; select only the genes affected by breakpoints from the tool 4 output 
  ##ignore the 1000 genomes list, we don't use it here)
  def runSVReportDriver()
     cmd = "driverSVReport.rb -t \"#{@outputDir}/*.sv.lff\" -g /cluster.shared/data/groups/brl/fasta/hg18/hg18.wholeGene.lff -s #{@scratch} -o #{@outputDir}/#{@analysis}.report -R #{@radius} "
    cmd <<" > #{@outputDir}/svReport.log 2>#{@outputDir}/svReport.error.log"
    $stdout.puts cmd
    system(cmd)
    if(!$?.success?)
      @exitCode = $?.exitstatus
      raise "driverSVReport.rb didn't work"
    end
  end
  
  ##Intersect the set of genes determined at #3 and #4, and report it in genelist.txt
  def createGeneList()
    cmd = "module load glib/2.24.2; lffIntersect.rb -s #{CGI.escape("Whole_Gene:RefSeq")} -f #{CGI.escape("Whole_Gene:RefSeq")} "
    cmd << " -l '/cluster.shared/data/groups/brl/fasta/hg18/hg18.wholeGene.lff,#{@outputDir}/filtered_zScore.lff' -o #{@outputDir}/filtered_intersected1 -n #{CGI.escape("Whole_Gene:RefSeq")} "
    $stdout.puts cmd
    system(cmd)
    @wholeGeneHash = {}
    file = File.open("#{@outputDir}/filtered_intersected1" , "r")
    file.each {|line|
      line.strip!
      column = line.split(/\t/)
      @wholeGeneHash[column[1]] = 0
      puts column[1]
      }
    file.close
  end
  
  ##Converting xl sheets into csv
  def convertingXltoCSV()
    xlFiles = Dir["#{@outputDir}/*.xls"]
    xlFiles.each {|xl|
      skipFirstLine = false
      fileOutput = File.open("#{@outputDir}/#{File.basename(xl)}.genelist" , "w+")
      @geneHash = {}
      puts "opening #{xl} file"
      CSV.open(xl, "r") { |line|
        if(skipFirstLine == true)
          
          columns = line[0].split(/\s/)
          fileOutput.puts columns[11]
          genes = columns[11].split(/\,/)
          genes.each {|gene|
            @geneHash[gene] = 0
          }
        end
        skipFirstLine = true
        }
      fileOutput.close
    }
  end
  
  
  ##To find the intersection between the genes found using SVtool and pairwise search
  def intersection()
    file = File.open("#{@outputDir}/#{@analysis}" ,"w+")
    @geneHash.each {|k,v|
      if(@wholeGeneHash.key?(k))
        file.puts k
      end
      }
    file.close
    
  end


 

  def SVReport.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

    PROGRAM DESCRIPTION:
    driverInsertSizeCollect wrapper for Cancer workbench
    COMMAND LINE ARGUMENTS:
    --tracks         | -t => Comma seperated tracks (Only 2 ) 
    --scratch        | -s => Scratch Directory
    --output         | -o => Output Directory
    --analysis       | -a => Analysis Name
    --resolution     | -r => Resolution
    --lffClass       | -l => lff class
    --lffType        | -L => lff type
    --lffSubType     | -S => lff sub type
    --radius         | -r => Radius
    --help           | -h => [Optional flag]. Print help info and exit.

    usage:

    ruby wrapperInsertSizeCollect.rb -f jsonFile
    ";
    exit;
  end #

  # Process Arguments form the command line input
  def SVReport.processArguments()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ ['--tracks'     ,'-t', GetoptLong::REQUIRED_ARGUMENT],
                  ['--scratch'    ,'-s', GetoptLong::REQUIRED_ARGUMENT],
                  ['--output'     ,'-o', GetoptLong::REQUIRED_ARGUMENT],
                  ['--analysis'   ,'-a', GetoptLong::REQUIRED_ARGUMENT],
                  ['--resolution' ,'-r', GetoptLong::REQUIRED_ARGUMENT],
                  ['--lffClass'   ,'-l', GetoptLong::REQUIRED_ARGUMENT],
                  ['--lffType'    ,'-L', GetoptLong::REQUIRED_ARGUMENT],
                  ['--lffSubType' ,'-S', GetoptLong::REQUIRED_ARGUMENT],
                  ['--radius'     ,'-R', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'       ,'-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    SVReport.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash

    SVReport.usage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end
end

begin
optsHash = SVReport.processArguments()
SVReport = SVReport.new(optsHash)
SVReport.main()
    rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
     #SVReport.sendFailureEmail(err.message)
end
