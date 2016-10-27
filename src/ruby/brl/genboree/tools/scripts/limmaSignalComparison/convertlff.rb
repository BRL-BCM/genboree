#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/pash/annotationIndex.rb'
require 'fileutils'
require 'cgi'

class GenenMiRNA
  DEBUG = false
  
  def initialize(optsHash)
    @file = File.expand_path(optsHash['--file'])
    @columns = optsHash['--columns'].to_i
    @window = optsHash['--window'].to_i
    @type   = CGI.escape(optsHash['--type'])
    @subType = CGI.escape(optsHash['--subType'])
    @targetTrackName = "UCSC%3AWholeGenes"
    @trackNamse = CGI.escape("#{@type}:#{@subType}")
    @dirName = File.dirname(@file)
    Dir.chdir(@dirName)
  end
    
 
  def usingLffIntersect
     cmd = "lffIntersect.rb -f #{@targetTrackName} -s #{@trackName} -l"
     cmd <<"'#{@file}.lff,"
     cmd << "/cluster.shared/data/groups/brl/atlas/hg19.wholeGenes.lff' -o #{File.basename(@file)}_intersected_#{@window} -n #{@trackName}"
     cmd <<" >#{@scratch}/logs/lffIntersect.log 2>#{@scratch}/logs/lffIntersect.error.log"
     $stderr.debugPuts(__FILE__, __method__, "convert.lff tool", "Converting to Lff")
     system(cmd)
   
  end
  
  def tsvToLff()
    file = File.open(@file)
    fileW = File.open("#{@file}.lff", "w+")
    skipFirst = false
    file.each{|line|
      line.strip!
      if(skipFirst)
        c = line.split(/\t/)
        #if(c[3].to_i != 0 )
        ##Considering only columns where we found 1 or -1, for multivariable attributes, there would
        ##be multiple one-to-one comparison.
        if(c.slice(3,@columns).include?('1') or c.slice(3,@columns).include?('-1'))
          info = c[0].split(/\_/)
          startP = info[1].to_i - @window
          endP = info[2].to_i + @window
          fileW.puts "Class\tname\t#{@type}\t#{@subType}\t#{info[0]}\t#{startP}\t#{endP}\t+\t0\t0"
        end
      end
      skipFirst = true
      }
    
    fileW.close
    
  end
  
  def extractGeneList
    system("cut -f2 #{File.basename(@file)}_intersected_#{@window}|cut -d':' -f2 |sort |uniq > genelist")
    
  end
  
  
  def GenenMiRNA.processArguments()
    # We want to add all the prop_keys as potential command line options
    optsArray =	[
                  ['--window',     '-w', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--file' ,      '-f', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--columns',    '-c', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--type'       ,'-t', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--subType'   , '-T', GetoptLong::OPTIONAL_ARGUMENT]
                 
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
    --file         | -f => file name
    --window       | -w => window
    --columns      | -c => columns numbers to be choosen from tsv file
    --type         | -t => track type
    --subType      | -T => track sub type
    --help         | -h => [Optional flag]. Print help info and exit.

 usage:
 
  ";
      exit;
  end # 
  
   
end
optsHash = GenenMiRNA.processArguments()
performQCUsingFindPeaks = GenenMiRNA.new(optsHash)
performQCUsingFindPeaks.tsvToLff()
#performQCUsingFindPeaks.usingLffIntersect()
#performQCUsingFindPeaks.extractGeneList()



