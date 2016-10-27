#!/usr/bin/env ruby
# Turn on extra warnings and such

# Author: Arpit Tandon (tandon@bcm.tmc.edu)
# Purpose:
# Converts the GFF format to LFF, which is used by Genboree

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################

require 'rubygems'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'stringio'
require 'zlib'


class GffToLff
      BUFFERSIZE = 320000
  
      def initialize(optsHash)
	    @optsHash = optsHash
      end
  
      # * *Function*: Process the input file and fetches information from GFF file and convert into LFF
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
		  outputFileName = @optsHash["--inputFile"].sub(".gff",".lff")
		  outputFileHandle = File.open(outputFileName,"w+")
	    end
	    
	  
	
		     
	    while(!inputFileHandle.eof?)
	    # Reading Files in chunks using memory for faster processing
		  buffer = inputFileHandle.read(buffer)
		  buffIO = StringIO.new(buffer.chomp)
		  buffIO.each_line{ |line|
		  # Keep track of lines. First two lines should be omitted 
		  count += 1
		  if( count > 1 )
			line = orphan + line if(!orphan.nil?)
			orphan = nil
			if( line =~ /\n$/ )
			      line.strip!
			      column = line.split(/\t/)
			      type         = column[1]
			      subType      = column[2]
			      entryPoint   = column[0]
			      start        = column[3]
			      stop         = column[4]
			      phase        = column[7]
                              strand       = column[6]
                              score        = column[5]
			      qStart	   = "."
			      qStop	   = "."
                              name         = "Anno#{count-1}"
			      if (@optsHash.key?('--class')) then
				   clas    = @optsHash['--class']
			      else
			   	   clas    = "Anno-gff#{count-1}"
			      end
                              attr         = "Attribute=#{count-1};"
                              sequ         = "Seq-#{count-1}"
                              # checks for other parameter if its GFF3 format
                              if( column[8] =~ /NAME/)
                                  attributes   = column[8].split(/;/)
				  nameCheck = 0
				  inc = 0
                                  attributes.each { |ii|
                                    if(ii =~/NAME/)
                                      name = ii.split(/=/)
                                      name = name[1]
				      nameCheck = 1
				      attributes.delete_at(inc)
                                      column[8] = attributes
				      break;
                                    end
				    if (nameCheck ==0)
				      name = "Anno-#{count-1}"
				    end
				    inc += 1
                                  }
                                
                              end
                                  
			      writeBuffer << "#{clas}\t#{name}\t#{type}\t#{subType}\t#{entryPoint}\t#{start}\t#{stop}\t#{strand}\t#{phase}\t#{score}\t" + 
					     "#{qStart}\t#{qStop}\t#{column[8]}\n"
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
  def GffToLff.processArguements()
      # Adding all the prop_keys as potential command line options
      optsArray =  [ ['--class','-c', GetoptLong::OPTIONAL_ARGUMENT],
		     ['--subType', '-s', GetoptLong::OPTIONAL_ARGUMENT],
		     ['--help', '-h', GetoptLong::NO_ARGUMENT],
		     ['--inputFile', '-f',  GetoptLong::REQUIRED_ARGUMENT],
		     ['--outputFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
		     ['--doGzipOutput', '-z', GetoptLong::NO_ARGUMENT]
		   ]
    
      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      GffToLff.usage() if(optsHash.key?('--help'));
      
      unless(progOpts.getMissingOptions().empty?)
	GffToLff.usage("USAGE ERROR: some required arguements are missing. Use 'help' to see the details requirments")
      end
  
      GffToLff.usage() if(optsHash.empty?)
      return optsHash
	
 end
  
  def GffToLff.usage(msg='')
      unless(msg.empty?)
	puts "\n#{msg}\n"
      end
      puts " PROGRAM DESCRIPTION:
      Given a BED file, outputs an LFF file
      COMMAND LINE ARGUMENTS:
	-c    =>  [Optional]Override the LFF class value to use.
		  A general 'category' for the annotation's Track.
		  e.g. Gene Predictions, Conservation, Repeats, Assembly.
      	-s    =>  [Optional)Override the LFF subtype value to use.
		  The type of annotation; a repetition or a sensible
		  sub-category of the class .
	-f    =>  [Required]Name of input GFF/GFF3 file 
	-o    =>  [Optional]Name of output lff file. By default, it is
		  {inputFile}.lff
	-z    =>  [Optional]If the output file is required in compressed form.
	-h    => [optional flag] Output this usage info and exit.
  
      USAGE:
      GffToLff.rb -c Gene -t exon -n ASD -f inputFile.gff -o outputfile.lff -z ";
      
      exit(134);
    end

end


#######################################################################################
# MAIN
#######################################################################################

# Process command line options
optsHash = GffToLff.processArguements()
# Instantiate convertor using the program arguments
GffConvertor = GffToLff.new(optsHash)
# Converts BED to LFF
GffConvertor.work()


