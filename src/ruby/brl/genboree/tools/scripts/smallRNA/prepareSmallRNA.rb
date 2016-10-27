#!/usr/bin/env ruby

require 'brl/util/textFileUtil'
require 'brl/util/util'

	
class TrimSmallRNAs
  DEBUG = true
  DEBUGINDEX = false
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
		@adaptorSequences = ["TCGTATGCCGTCTTCTGCTTG"]
	end  
  
  def setParameters()
    @readsFile = @optsHash['--readsFile']
    @outputDir = @optsHash['--outputDir']
    @signatureString = ""
    if (@optsHash.key?('--requireAdapter')) then
			@requireAdapter = true
			@signatureString << "1"
    else
			@requireAdapter = false
			@signatureString << "0"
    end
    if (@optsHash.key?('--requireCoverage')) then
			@requireCoverage = true
			@coverage = @optsHash['--requireCoverage'].to_i
			@signatureString << "1"
    else
			@requireCoverage = false
			@coverage = 0
			@signatureString << "0"
    end
    
    @signatureString << "1"
    if (@optsHash.key?('--fuzzyMatch'))
			@doFullTrimming = false
			$stderr.puts "fuzzy triming" 
    else
			@doFullTrimming = true
			$stderr.puts "full triming" 
    end
  end
  
  def populateSubAdapterSequences
    adapter = @adaptorSequences[0]
    @adapterArray = []
    adapterSize = adapter.size
    adapterSize.downto(5) { |i|
      subAdaptor = adapter[0, i]
      $stderr.puts "added subadapter #{subAdaptor}" if (DEBUG)
      @adapterArray.push(subAdaptor)
    }
  end
  
  def work()
    totalTags = 0
    discardedShortTags = 0
    forwardTrimmed = 0
    notTrimmed = 0
    
    populateSubAdapterSequences()
    dname=File.basename("#{@outputDir}")
    system("mkdir -p #{@outputDir}")
    baseName = File.basename(@readsFile)
    sleep(1)
    readsReader = BRL::Util::TextReader.new(@readsFile) # Reading reads file  
    outputWriter = BRL::Util::TextWriter.new("#{@outputDir}/#{baseName}_WithoutAdaptors.fa")
   
    g=File.open("#{@outputDir}/tags.fa", "w")
    
    readsReader.each{ |l|
       if (l=~ />\s*(\d+)\s*$/) then
    	  g.print $1; g.print "\t"
       else
         g.print l
       end
    }
    g.close
    readsReader.close
    
    tagRead = BRL::Util::TextReader.new("#{@outputDir}/tags.fa") # Reading tags file  

    l = nil
    tagRead.each { |l|
    	
      totalTags += 1
      l =~ /^(\d+)\s+(\w+)$/
      tagCount = $1
      tag = $2
      trimTag = $2
      reverseTag = tag.reverse.tr("actgnACTGN", "TGACNTGACN")
      trimReverseTag = reverseTag
      defLine = "#{tag}__#{tagCount}"
      $stderr.puts "#{tagCount} ----> #{tag}" if (DEBUGINDEX)
      
      
      if (@doFullTrimming) then
				# now check for subadapter substring
				@adapterArray.each {|a|
					ind = tag.index(a)
					$stderr.puts "#{a} --> #{ind}" if (DEBUGINDEX)
					if (!ind.nil?) then
						trimTag = tag[0,ind]
						trimTag = "" if (trimTag.nil?)
						if (trimTag.size < 10) then
							$stderr.puts "tag #{tag} trims to #{trimTag} by #{a}, which is too short"
							discardedShortTags += 1
							trimTag = ""
						end
						break
					end
				}
				
				$stderr.puts "R: #{tagCount} ----> #{reverseTag}" if (DEBUG)
				# now check for subadapter substring
				@adapterArray.each {|a|
					ind = reverseTag.index(a)
					$stderr.puts "R: #{a} --> #{ind}" if (DEBUGINDEX)
					if (!ind.nil?) then
						trimReverseTag = reverseTag[0,ind]
						trimReverseTag = "" if (trimReverseTag.nil?)
						if (trimReverseTag.size < 10) then
							$stderr.puts "reverse tag #{reverseTag} trims to #{trimReverseTag} by #{a}, which is too short"
							if (trimTag.size > 0) then
								trimTag = ""
								discardedShortTags += 1
							end
							trimReverseTag = ""
						end
						break
					end
				}
      else
				# look only for 6 mer with regexp
				if (tag =~ /^(.*)(T|N)(C|N)(G|N)(T|N)(A|N)(T|N)/) then
					trimTag = $1
					if (trimTag.size < 10) then
							$stderr.puts "tag #{tag} trims to #{trimTag} by (T|N)(C|N)(G|N)(T|N)(A|N)(T|N), which is too short"
							discardedShortTags += 1
							trimTag = ""
					end
				end
				if (reverseTag =~ /^(.*)(T|N)(C|N)(G|N)(T|N)(A|N)(T|N)/) then
					trimReverseTag = $1
					if (trimReverseTag.size < 10) then
						if (trimTag.size > 0) then
							$stderr.puts "reverse tag #{reverseTag} trims to #{trimReverseTag} by (T|N)(C|N)(G|N)(T|N)(A|N)(T|N), which is too short"
							discardedShortTags += 1
							trimTag = ""
						end
					end
				end
			#	$stderr.puts "fuzzy match trimming not supported yet"
			end
      
      if (trimTag.size >0) then
				if (  !@requireAdapter || (@requireAdapter && trimTag.size < tag.size)) then
					$stderr.puts "generating \n>#{defLine}\n #{trimTag}" if (DEBUG)
					outputWriter.puts ">#{defLine}\n#{trimTag}"
				end
      end
      if (DEBUG) then
        if (trimTag == tag) then
          $stderr.puts "no trimming for #{tag}\t#{tagCount}"
          notTrimmed += 1
        elsif (trimTag.size>0) then
          $stderr.puts "trimmed for #{tag}\t#{tagCount}"
          forwardTrimmed += 1
        end  
        if (trimReverseTag.size>0 and trimReverseTag.size < reverseTag.size) then
          $stderr.puts "reverse trimming possible from #{reverseTag} to #{trimReverseTag}"
        end
        if (trimTag == tag && (trimReverseTag.size>0 and trimReverseTag.size < reverseTag.size)) then
          $stderr.puts "ntrimrtrim"
        end
      end
    
    } 
    tagRead.close()
    outputWriter.close()
    puts "total tags\t#{totalTags}\nshortTags\t#{discardedShortTags}\ntrimmed tags\t#{forwardTrimmed}\nnot trimmed\t#{notTrimmed}"
  end
  
  def TrimSmallRNAs.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--readsFile',       '-r', GetoptLong::REQUIRED_ARGUMENT],
									['--outputDir',     '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--requireAdapter', '-a', GetoptLong::OPTIONAL_ARGUMENT],
									['--requireCoverage','-c', GetoptLong::OPTIONAL_ARGUMENT],
									['--fuzzyMatch',     '-F', GetoptLong::OPTIONAL_ARGUMENT],
									['--help',           '-h', GetoptLong::NO_ARGUMENT]
								]
		
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		TrimSmallRNAs.usage() if(optsHash.key?('--help'));
		
		unless(progOpts.getMissingOptions().empty?)
			TrimSmallRNAs.usage("USAGE ERROR: some required arguments are missing") 
		end
	
		TrimSmallRNAs.usage() if(optsHash.empty?);
		return optsHash
	end
	
	def TrimSmallRNAs.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Trim adaptor sequence from small RNA tags.

COMMAND LINE ARGUMENTS:
  --readsFile          | -r   => small RNAs reads file
  --outputDir        | -o   => output Directory for the output files (tags.fa and reads file without adaptors)
  --requireAdapter    | -a   => [optional argument] require adapter
  --requireCoverage   | -c   => [optional argument] require coverage of 5 or all
  --fuzzyMatch        | -F   => use a fuzzy match with the first  6 bases in the adapter
  --help              | -h   => [optional flag] Output this usage info and exit

USAGE:
  prepareSmallRNA.rb  -r reads_file -o outputFile.fa 
";
			exit(2);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = TrimSmallRNAs.processArguments()
# Instantiate analyzer using the program arguments
TrimSmallRNAs = TrimSmallRNAs.new(optsHash)
# Analyze this !
TrimSmallRNAs.work()
exit(0);
