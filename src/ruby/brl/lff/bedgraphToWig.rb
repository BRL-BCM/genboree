#!/usr/bin/env ruby
# Turn on extra warnings and such

# Author: Arpit Tandon (tandon@bcm.tmc.edu)
# Purpose:
# Converts the BedGraph format to Wig, which is used by Genboree

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################

require 'rubygems'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'stringio'
require 'zlib'


class BedgraphToWig
      BUFFERSIZE = 320000
  
      def initialize(optsHash)
	    @optsHash = optsHash
      end
  
      # * *Function*: Process the input file and fetches information from BEDGRAPH file and convert into Wig
      # * *Args*    :
      #   - +none+
      # * *Returns* :
      #   - +none+
      # * *Throws*  :
      #   - +none+
      
      def work()
        
            # Selecting wig format. 0 for variableStep and 1 for fixedStep
            wig = 0
            count = 0
	    writeBuffer = ""
	    orphan = ""
	   
	    if(@optsHash.key?('--step'))
		  step = @optsHash['--step']
	    else
		  step = 1
	    end
	    
	    inputFileHandle = BRL::Util::TextReader.new(@optsHash["--inputFile"])   
	    if (@optsHash.key?('--wigType'))
                wig = 1
            end
	    if (@optsHash.key?('--outputFile'))
		  if (!@optsHash.key?('--wigType'))
			outputFileHandle = File.open(@optsHash['--outputFile'] + ".vwig","w+")
			outputFileName = @optsHash['--outputFile'] + ".vwig"
		  else
		        outputFileHandle = File.open(@optsHash['--outputFile'] + ".fwig","w+")
			outputFileName = @optsHash['--outputFile'] + ".fwig"
		  end
	    else
		  inputFileName = @optsHash["--inputFile"]
		  if (!@optsHash.key?('--wigType'))
			outputFileName = @optsHash["--inputFile"].sub(".bedGraph",".vwig")
		  else
			outputFileName = @optsHash["--inputFile"].sub(".bedGraph",".fwig")
		  end
			outputFileHandle = File.open(outputFileName,"w+")
	    end
	    
            
	    while(!inputFileHandle.eof?)
		  # Reading Files in chunks using memory for faster processing
		  buffer = inputFileHandle.read(buffer)
		  buffIO = StringIO.new(buffer.chomp)
		  buffIO.each_line{ |line|
		  # Keep track of lines. First two lines should be omitted
		  count += 1
		  # Keep track of memory of IO buffer
		  check = 0
		  if(count ==1)
			name = line.split(/name=/)
			writeBuffer << "track type=wiggle_0 name=#{name[1]}"
		  end
		  
		  if count > 1
			line = orphan + line if(!orphan.nil?)
			orphan = nil
			if(line =~ /\n$/)
			      line.strip!
			      column = line.split(/\s/)
			      chrom = column[0]
			      chromStart = column[1].to_i + 1
			      chromEnd = column[2].to_i 
			      dataValue = column[3]
			      if(@optsHash.key?('--span'))
				    span = chromEnd - chromStart
				    spanOpt = 1
				    step = span
			      else
				    span = 1
				    spanOpt = 0
			      end
			      # Converting to variableStep format
			      if( wig.to_i == 0)
				    # If span is not default 1. It calculates span from the file
				    if(spanOpt.to_i == 1)
					  writeBuffer << "variableStep\schrom=#{chrom}\sspan=#{span}\n"
					  writeBuffer << "#{chromStart}\s#{dataValue}\n"
				    # If span is default value 1
				    else
					  writeBuffer << "variableStep\schrom=#{chrom}\sspan=#{span}\n"
					  for ii in (chromStart..chromEnd)
						writeBuffer <<"#{ii}\s#{dataValue}\n"
					  end
				    end
			      # Converting to fixedStep format
			      else
				    # If span is not default 1. It caculates span from the file
				    if(spanOpt.to_i == 1)
					  writeBuffer << "fixedStep\schrom=#{chrom}\sstart=#{chromStart}\sstep=#{step}\sspan=#{span}\n"
					  writeBuffer << "#{dataValue.to_i}\n"
				    # If span is default value 1		  
				    else
					  writeBuffer << "fixedStep\schrom=#{chrom}\sstart=#{chromStart}\sstep=#{step}\sspan=#{span}\n"
					  for ii in (chromStart..chromEnd)
						writeBuffer <<"#{dataValue}\n"
					  end
				    end
                              end
			else
			      orphan = line
			end
                  end
                  }
		  # Writing buffer to size if its memory gets exceeded
		  if(writeBuffer.size >= 32000) 
			outputFileHandle.print(writeBuffer)
			check =1
		  end
	    end
	    if(check.to_i == 0)
		  
		  outputFileHandle.print(writeBuffer)
	    end
	    # Zipping the file if option is selected
	    if(@optsHash.key?('--doGzipOutput'))
		  puts outputFileName
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
  def BedgraphToWig.processArguements()
    # Adding all the prop_keys as potential command line options
    optsArray =  [ ['--inputFile', '-f',  GetoptLong::REQUIRED_ARGUMENT],
		   ['--outputFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
		   ['--doGzipOutput', '-z', GetoptLong::NO_ARGUMENT],
		   ['--wigType','-w' , GetoptLong::OPTIONAL_ARGUMENT],
		   ['--span','-s', GetoptLong::OPTIONAL_ARGUMENT],
		   ['--step','-t', GetoptLong::OPTIONAL_ARGUMENT],
		   ['--help', '-h', GetoptLong::NO_ARGUMENT],
		   
		 ]
  
    progOpts = GetoptLong.new(*optsArray)
    optsHash = progOpts.to_hash
    BedgraphToWig.usage() if(optsHash.key?('--help'));
    
    unless(progOpts.getMissingOptions().empty?)
      BedgraphToWig.usage("USAGE ERROR: some required arguements are missing. Use 'help' to see the details requirments")
    end

    BedgraphToWig.usage() if(optsHash.empty?)
    return optsHash
      
  end
  
  def BedgraphToWig.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts " PROGRAM DESCRIPTION:
    Given a BED file, outputs an LFF file
    COMMAND LINE ARGUMENTS:
      -f    =>  [Required]Name of input BEDGRAPH file 
      -o    =>  [Optional]Name of output wig file. By default, it is
                {inputFile}.fwig/.vwig
      -z    =>  [Optional]If the output file is required in compressed form.
      -w    =>  [Optional]If the fixedStep wig output is required. By default,
                its variableStep wig file
      -s    =>  [Optional- Not Recommended] default is 1. Allows data composed
	        of contigous run of bases with the smae data value to be
	        specified more succintly. This option is not according to rules.
	        This is for future reference.
      -t    =>  [Optional] default is 1. Option when selecting fixedStep fromat.
      -h    =>  [optional flag] Output this usage info and exit.

    USAGE:
    bedgraphTowig.rb -f inputFile.bedgraph -o outputfile.wig -w ";
    
    exit(134);
  end

end


#######################################################################################
# MAIN
#######################################################################################

# Process command line options
optsHash = BedgraphToWig.processArguements()
# Instantiate convertor using the program arguments
BedConvertor = BedgraphToWig.new(optsHash)

# Converts BedGraph to Wig
BedConvertor.work()


