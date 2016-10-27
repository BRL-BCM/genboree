#!/usr/bin/env ruby
### No warning!
$VERBOSE = nil

# ##############################################################################
# PURPOSE
# Simple: convert from UCSC chain table to equivalent LFF version
# ##############################################################################

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'

# ##############################################################################
# CONSTANTS
# ##############################################################################
FATAL = BRL::Genboree::FATAL
OK = BRL::Genboree::OK
OK_WITH_ERRORS = BRL::Genboree::OK_WITH_ERRORS
FAILED = BRL::Genboree::FAILED
USAGE_ERR = BRL::Genboree::USAGE_ERR
DARKEST_GRAY_VAL = 112 #==> hex: 70
LIGHTEST_GRAY_VAL = 195 #==> hex value: C3

# ##############################################################################
# HELPER FUNCTIONS AND CLASS
# ##############################################################################
# Process command line args
# Note:
#      - did not find optional extra alias files
def processArguments()
  optsArray = [
                ['--chimpChainFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
                ['--trackName', '-t', GetoptLong::REQUIRED_ARGUMENT],
                ['--className', '-l', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryInput', '-i', GetoptLong::REQUIRED_ARGUMENT],
                ['--tspeciesName', '-s', GetoptLong::REQUIRED_ARGUMENT],
                ['--qspeciesName', '-q', GetoptLong::REQUIRED_ARGUMENT],
                ['--fileToOutput', '-f', GetoptLong::REQUIRED_ARGUMENT],
                ['--cDirectoryOutput', '-d', GetoptLong::REQUIRED_ARGUMENT],
                ['--help', '-h', GetoptLong::NO_ARGUMENT]
              ]
  progOpts = GetoptLong.new(*optsArray)
  optsHash = progOpts.to_hash
  # Try to use getMissingOptions() from Ruby's standard GetoptLong class
  optsMissing = progOpts.getMissingOptions()
  # If no argument given or request help information, just print usage...
  if(optsHash.empty? or optsHash.key?('--help'))
    usage()
    exit(USAGE_ERR)
  # If there is NOT any required argument file missing, then return an empty array; otherwise, report error
  elsif(optsMissing.length != 0)
    usage("Error: the REQUIRED args are missing!")
    exit(USAGE_ERR)
  else
    return optsHash
  end
end

def usage(msg='')
  puts "\n#{msg}\n" unless(msg.empty?)
  puts "

PROGRAM DESCRIPTION:
  Converts from UCSC chain table to equivalent LFF version.

  COMMAND LINE ARGUMENTS:
    --chimpChainFile        | -r    => UCSC chain file to convert
    --trackName             | -t    => Track name for chain track
                                       (type:subtype)
    --className             | -t    => class name for chain track
    --cDirectoryInput       | -i    => directory location of converting file 
    --tspeciesName          | -s    => Species name aligned with  query in chain file
    --qspeciesName          | -q    => Species name aligned with  target in chain file
    --fileToOutput          | -f    => converted file name
    --cDirectoryOutput      | -d    => directory location of converted file
    --help                  | -h   => [optional flag] Output this usage
                                      info and exit.

  USAGE:
  BRL_UCSC_chimpchainlff.rb -r chr1_chainPanTro2.txt.gz -t Alignment:Chain -l 'Comparative Genomics' -i /users/ybai/work/Project1/test_Downloader -s Human -q Chimp -f chr1_chainPanTro2_LFF.txt -d /users/ybai/work/Project1/test_Converter
"
end

class MyConverter
  def initialize(inputsHash)
  end 
  def convert(inputsHash) 
    chimpChainFile = inputsHash['--chimpChainFile'].strip
    className = inputsHash['--className'].strip
    cDirectoryInput = inputsHash['--cDirectoryInput'].strip
    fileToOutput = inputsHash['--fileToOutput'].strip
    cDirectoryOutput = inputsHash['--cDirectoryOutput'].strip

    unless(File.size?("#{cDirectoryInput}/#{chimpChainFile}"))
      $stderr.puts "WARNING: the file '#{chimpChainFile}' is empty. Nothing to do."
      exit(FAILED)
    end
    # Set the track type/subtype
    lffType, lffSubtype = inputsHash['--trackName'].strip.split(':')

    # Set the targe species
    tspecies = inputsHash['--tspeciesName'].strip

    # Set the targe species
    qspecies = inputsHash['--qspeciesName'].strip

    # CONVERT chimp chain TO LFF RECORDS USING WHAT WE HAVE SO FAR
    targetName = Hash.new { |hh, kk| hh[kk] = 0 }
    queryName = Hash.new { |hh, kk| hh[kk] = 0 }
    # Open the file
    reader1 = BRL::Util::TextReader.new("#{cDirectoryInput}/#{chimpChainFile}")
    reader = BRL::Util::TextReader.new("#{cDirectoryInput}/#{chimpChainFile}")
    line = nil

    begin
    ## ==========> Phase I:  check the number of unique chromosomes (including _random ones) from the input file and sort regular ones in a numeric order
      # Initialize some useful arrays and indeies
      input_chromosome_arr = []
      input_random_chromosome_arr = []
      input_chr_chromosome_arr = []
      input_chromosome_arr_index =0
      input_random_chromosome_arr_index =0
      input_chr_chromosome_arr_index =0
      # Go through each line of input file
      reader1.each { |line1|
        next if(line1 =~ /^\s*#/ or line1 !~ /\S/)
        ff1 = line1.chomp.split(/\t/)
        ff1[6] = ff1[6].strip.to_sym	#qName
        # if the query chromosome is a random one
        if("#{ff1[6]}".include? "_random")
          input_random_chromosome_arr[input_random_chromosome_arr_index] = "#{ff1[6].to_sym}"
          input_random_chromosome_arr_index += 1
        # if the query chromosome is a character one (X, Y, M, or Un)
        elsif((("#{ff1[6]}".include? "X") or ("#{ff1[6]}".include? "Y") or ("#{ff1[6]}".include? "M") or ("#{ff1[6]}".include? "Un")) and (!("#{ff1[6]}".include? "_random")))
          input_chr_chromosome_arr[input_random_chromosome_arr_index] = "#{ff1[6].to_sym}"
          input_chr_chromosome_arr_index += 1
        # if the query chromosome is a numeric one (chr1, chr2, ...)
        else 
          input_chromosome_arr[input_chromosome_arr_index] = "#{ff1[6].to_sym}"
          input_chromosome_arr_index += 1
        end
      } # reader1 close
      reader1.close

      # Sort regular numeric chromosome
      result_chromosome_arr = input_chromosome_arr.uniq.sort do |x,y| 
        v1 = x.delete("A-Za-z")
        v2 = y.delete("A-Za-z")
        if(v1.length == v2.length)
          v1.to_i <=> v2.to_i
        else
          v1.length <=> v2.length
        end
      end

      # Do not sort _random chromosome
      result_random_chromosome_arr = input_random_chromosome_arr.uniq 
      ## ===========> End of Phase I

      ## =============> Phase II: Assign several color arrays
      # Assign 40 colors to a regular numeric chromosomes...
      color_arr = %w( 8B4513 556B2F 2F4F4F 808000 DC143C FF0000 FF00FF FF3399 FF8C00 FFA500 FFFF00 55EE55 00FF00 008000 0000CD 1E90FF 6495ED 00FFFF 00CCFF BA55D3 DA70D6 990000 009933 990066 CC3366 000066 003399 003333 006633 333300 CCBB00 AA7700 663300 CC9933 FF9966 FF6633 8A2BE2 4B0082 1E90FF 304040 )
      # Assign colors for random chromosomes by maximizing the difference
      max_num_grays = LIGHTEST_GRAY_VAL - DARKEST_GRAY_VAL + 1
      numRandomChrs = result_random_chromosome_arr.length
      numRandomChrs = max_num_grays if(numRandomChrs > max_num_grays)
      increment_count = max_num_grays / numRandomChrs
      currGray = [DARKEST_GRAY_VAL, DARKEST_GRAY_VAL, DARKEST_GRAY_VAL]
      random_color_arr = []
      numRandomChrs.times {|channelVal|
        random_color_arr << (currGray.slice(0).to_i.to_s(base=16).upcase + currGray.slice(1).to_i.to_s(base=16).upcase + currGray.slice(2).to_i.to_s(base=16).upcase)
        currGray.map!{|xx| xx + increment_count}
      } 
      ## =============> End of Phase II

      ## ===================> Phase III: Assign colors to chromosomes
      # Start assign colors to regular chromosomes...
      diff_counter = 0
      chromosome_color_hex = {}
      # If available colors stored in our array is enough to make assignment on input number of chromosome
      if (color_arr.length >= result_chromosome_arr.length) 
        result_chromosome_arr.each_index {|x| chromosome_color_hex[result_chromosome_arr[x]] = color_arr[x] }
      # Otherwise, extra chromosomes will be assigned as color - BLACK
      else
        color_arr.each_index {|x| chromosome_color_hex[result_chromosome_arr[x]] = color_arr[x] }
        while(diff_counter < (result_chromosome_arr.length - color_arr.length))
          chromosome_color_hex[result_chromosome_arr[color_arr.length + diff_counter]] = "000000"
          diff_counter += 1
        end        
      end

      # Start assign colors to random chromosomes...
      random_diff_counter = 0
      random_chromosome_color_hex = {}
      # If available colors stored in our array is enough to make assignment on input number of chromosome
      if (random_color_arr.length >= result_random_chromosome_arr.length) 
        result_random_chromosome_arr.each_index {|x| random_chromosome_color_hex[result_random_chromosome_arr[x]] = random_color_arr[x] }
      # Otherwise, extra chromosomes will be assigned as color - BLACK
      else
        random_color_arr.each_index {|x| random_chromosome_color_hex[result_random_chromosome_arr[x]] = random_color_arr[x] }
        while(random_diff_counter < (result_random_chromosome_arr.length - random_color_arr.length))
          random_chromosome_color_hex[result_random_chromosome_arr[random_color_arr.length + random_diff_counter]] = "000000"
          random_diff_counter += 1
        end        
      end

      # Start assign colors to spcial char chromosomes...
      # Assign several reserved colors for X, Y, M, and Un chromosome
      chr_chromosome_color_hex = {
        'X' => 'CC3300',
        'Y' => '336666',
        'M' => '9900FF',
        'Un' => '999933'
      }
      ## ================> End of Phase III
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line1.inspect}"
      exit(OK_WITH_ERRORS)
    end

    # Start conversion process...
    begin
       open("#{cDirectoryOutput}/#{fileToOutput}", 'w') do |f|
       # Go through each line
       reader.each { |line|
         next if(line =~ /^\s*#/ or line !~ /\S/)
         # Chop it up
         # bin	score	tName	tSize	tStart	tEnd	qName	qSize	qStrand	qStart	qEnd	id 
         ff = line.chomp.split(/\t/)
         bin = ff[0].strip.gsub(/;/, '.').to_sym #bin
         ff[1] = ff[1].to_sym	#score
         ff[2] = ff[2].strip.to_sym	#tName
         tChromosome = ff[2].to_sym	# target chromosome name
         targetName[ff[2]] += 1
         ff[2] = ("#{ff[2]}.#{targetName[ff[2]]}".to_sym) if(targetName[ff[2]] > 1)
         ff[3] = ff[3].to_i	#tSize
         ff[4] = ff[4].to_i	#tStart
         ff[5] = ff[5].to_i	#tEnd
         ff[6] = ff[6].strip.to_sym	#qName
         qChromosome = ff[6].to_sym	# query chromosome name
         queryName[ff[6]] += 1
         ff[6] = ("#{ff[6]}.#{queryName[ff[6]]}".to_sym) if(queryName[ff[6]] > 1)
         ff[7] = ff[7].to_i	#qSize
         ff[8] = ff[8].to_sym	#qStrand
         ff[9] = ff[9].to_i	#qStart
         ff[10] = ff[10].to_i	#qEnd
         ff[11] = ff[11].to_sym	#id

         # Dump each linked feature as LFF
         ### class, name, type, subtype, entry point(chr), start, stop, strand, phase, score, qStart, qStop
         f.print "#{className}\t#{qspecies}.#{ff[6]}\t#{lffType}\t#{lffSubtype}\t#{tChromosome}\t#{ff[4]}\t#{ff[5]}\t#{ff[8]}\t.\t#{ff[1]}\t#{ff[9]}\t#{ff[10]}\t"
         # attributes in order of useful information (in LFF anyway)
         ### bin, qSize, tSize 
         f.print "bin=#{bin}; qSize=#{ff[7]}; tSize=#{ff[3]};"

         ### annotationColor
         # If it is a special char chromosome X, Y, M, or Un
         if(("#{qChromosome}".include? "X") and !("#{qChromosome}".include? "_random"))
           assigned_color_X  = chr_chromosome_color_hex['X'] 
           f.print " annotationColor=##{assigned_color_X}; "
         elsif(("#{qChromosome}".include? "Y") and !("#{qChromosome}".include? "_random"))
           assigned_color_Y  = chr_chromosome_color_hex['Y'] 
           f.print " annotationColor=##{assigned_color_Y}; "
         elsif(("#{qChromosome}".include? "M") and !("#{qChromosome}".include? "_random"))
           assigned_color_M  = chr_chromosome_color_hex['M'] 
           f.print " annotationColor=##{assigned_color_M}; "
         elsif(("#{qChromosome}".include? "Un") and !("#{qChromosome}".include? "_random"))
           assigned_color_Un  = chr_chromosome_color_hex['Un'] 
           f.print " annotationColor=##{assigned_color_Un}; "
         elsif("#{qChromosome}".include? "_random")  
           assigned_color_random = random_chromosome_color_hex["#{qChromosome}"]
           f.print " annotationColor==##{assigned_color_random}; "
         else
           assigned_color = chromosome_color_hex["#{qChromosome}"]
           f.print " annotationColor=##{assigned_color}; "
         end
 
         # sequence (none)
         f.print "\t.\t"

         # summary (free form comments)
         f.print "."

         # done with record
         f.puts ""

      } # reader close
      reader.close
      end
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit(OK_WITH_ERRORS)
    end
  end
end

# ##############################################################################
# MAIN
# ##############################################################################
$stderr.puts "#{Time.now} BEGIN (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
begin
  optsHash = processArguments()
  converter = MyConverter.new(optsHash)
  converter.convert(optsHash)
  $stderr.puts "#{Time.now} DONE"
  exit(OK)
rescue => err
  $stderr.puts "Error occurs... Details: #{err.message}"
  $stderr.puts err.backtrace.join("\n")
  exit(FATAL)
end
