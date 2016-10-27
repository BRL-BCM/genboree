#!/usr/bin/env ruby
# Turn on extra warnings and such

# Author: Arpit Tandon (tandon@bcm.tmc.edu)
# Purpose:
# Converts the BED format to LFF, which is used by Genboree

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################

require 'rubygems'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'stringio'
require 'zlib'


class BedToLff
      BUFFERSIZE = 320000
  
      def initialize(optsHash)
	    @optsHash = optsHash
      end
  
      # * *Function*: Process the input file and fetches information from BED file and convert into LFF
      # * *Args*    :
      #   - +none+
      # * *Returns* :
      #   - +none+
      # * *Throws*  :
      #   - +none+
      
      def work()
            check = 0	
            count = 0
	    writeBuffer = ""
	    orphan = ""
	    inputFileHandle = BRL::Util::TextReader.new(@optsHash["--inputFile"])   
	    #inputFileHandle = File.open(@optsHash["--inputFile"],"r")
	    if (@optsHash.key?('--outputFile'))
		  outputFileHandle = File.open(@optsHash['--outputFile'] + ".lff","w+")
		  outputFileName = @optsHash['--outputFile'] + ".lff"
		  
	    else
		  inputFileName = @optsHash["--inputFile"]
		  outputFileName = @optsHash["--inputFile"].sub(".bed",".lff")
		  outputFileHandle = File.open(outputFileName,"w+")
puts outputFileName
	    end
		     
	    while(!inputFileHandle.eof?)
	    # Reading Files in chunks using memory for faster processing
		  buffer = inputFileHandle.read(buffer)
		  buffIO = StringIO.new(buffer)
		  buffIO.each_line{ |line|
		  # Keep track of lines. First two lines should be omitted
		  count += 1
		  if( count > 2 )
			line = orphan + line if(!orphan.nil?)
			orphan = nil
			if( line =~ /\n$/ )
			      line.strip!
			      column = line.split(/\t/)
			      entryPoint   = column[0]
			      start        = column[1].to_i + 1
			      stop         = column[2]
			      phase        = "."
			      qStart	   = "."
			      qStop	   = "."
			      if (@optsHash.key?('--class')) then
				    clas      = @optsHash['--class']
			      else
				    clas      = "Anno-bed#{count-2} "
			      end
			      if (@optsHash.key?('--type')) then
				    type       = @optsHash['--type']
			      else
				    type       = "Anno-#{count-2}"
			      end
			  
			      if (@optsHash.key?('--subType')) then
				    subType    = @optsHash['--subType']
			      else
				    subType    = "Anno-#{count-2}"
			      end
			      
		
			      if(column[3].nil?)
				    name   = "Anno-#{count-2}"
			      else
				    name   = column[3]
			      end
			   
			      if(column[5].nil?)
				    strand = "+"
			      else
				    strand = column[5]
			      end
			      
			      if(column[4].nil?)
				    score  = "1.0"
			      else
				    score  = column[4]
			      end
			      
			      
	  
			      writeBuffer << "#{clas}\t#{name}\t#{type}\t#{subType}\t#{entryPoint}\t#{start}\t#{stop}\t#{strand}\t" + 
					  "#{phase}\t#{score}\t#{qStart}\t#{qStop}\tthickStart=#{column[6]};thickEnd=#{column[7]};" +
					  "itemRgb=#{column[8]};blockCount=#{column[9]};blockSizes=#{column[10]};blockStarts=#{column[11]}\n"
			else
			      orphan = line
			end
		   end
		  }
		  if(writeBuffer.size >= 32000) 
		     outputFileHandle.print(writeBuffer)
		     check = 1
		  end
	      end
	      if(check.to_i == 0)
		    outputFileHandle.print(writeBuffer)
	      end
	      if(@optsHash.key?('--doGzipOutput'))
		system("gzip #{outputFileName}")
		
	      end
	
    end
    
  # * *Function*: Processes all the command-line options and dishes them back as a hash.
  # * *Args*    :
  #   - +none+
  # * *Returns* :
  #   - +Hash+  -> Hash of the command-line args with arg names as keys associated with
  #     values. Values can be nil empty string in user gave '' or even nil if user didn't provide
  #     an optional argument.
  # * *Throws*  :
  #   - +none+		
  def BedToLff.processArguements()
      # Adding all the prop_keys as potential command line options
      optsArray =  [ ['--class','-c', GetoptLong::OPTIONAL_ARGUMENT],
		     ['--type', '-t', GetoptLong::OPTIONAL_ARGUMENT],
		     ['--subType', '-s', GetoptLong::OPTIONAL_ARGUMENT],
		     ['--help', '-h', GetoptLong::NO_ARGUMENT],
		     ['--inputFile', '-f',  GetoptLong::REQUIRED_ARGUMENT],
		     ['--outputFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
		     ['--doGzipOutput', '-z', GetoptLong::NO_ARGUMENT]
		   ]
    
      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      BedToLff.usage() if(optsHash.key?('--help'));
      
      unless(progOpts.getMissingOptions().empty?)
	BedToLff.usage("USAGE ERROR: some required arguements are missing. Use 'help' to see the details requirments")
      end
  
      BedToLff.usage() if(optsHash.empty?)
      return optsHash
	
 end
  
  def BedToLff.usage(msg='')
      unless(msg.empty?)
	puts "\n#{msg}\n"
      end
      puts " PROGRAM DESCRIPTION:
      Given a BED file, outputs an LFF file
      COMMAND LINE ARGUMENTS:
	-c    =>  [Optional]Override the LFF class value to use.
		  A general 'category' for the annotation's Track.
		  e.g. Gene Predictions, Conservation, Repeats, Assembly.
	-t    =>  [Optional]Override the LFF type value to use.
		  A name for the annotation/annotation group.
	-s    =>  [Optional)Override the LFF subtype value to use.
		  The type of annotation; a repetition or a sensible
		  sub-category of the class .
	-f    =>  [Required]Name of input BED file 
	-o    =>  [Optional]Name of output lff file. By default, it is
		  {inputFile}.lff
	-z    =>  [Optional]If the output file is required in compressed form.
	-h    => [optional flag] Output this usage info and exit.
  
      USAGE:
      bedToLff.rb -c Gene -t exon -s ASD -f inputFile.bed -o outputfile.lff -z ";
      
      exit(134);
    end

end


#######################################################################################
# MAIN
#######################################################################################

# Process command line options
optsHash = BedToLff.processArguements()
# Instantiate convertor using the program arguments
BedConvertor = BedToLff.new(optsHash)
# Converts BED to LFF
BedConvertor.work()



