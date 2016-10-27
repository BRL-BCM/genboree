#!/usr/bin/env ruby
$VERBOSE = nil

require "brl/util/textFileUtil"
require "brl/util/util"
require "brl/genboree/genboreeUtil"

include BRL::Util

module BRL; module FileFormats

  # ---------------------------------------------------------------------------
	# Error Classes
	# ---------------------------------------------------------------------------
  class BedgraphValidateError < StandardError
    def initialize(msg='')
      @message = msg
      super(msg)
    end
    def message=(value)
      @message = value
    end
    def message()
      @message
    end
  end
  
  # ---------------------------------------------------------------------------
	# Bedgraph Validator
	# ---------------------------------------------------------------------------
  class BedgraphValidator
    attr_accessor :maxErrors, :maxWarnings, :lffFile
    attr_accessor :currLineNum,  :doFullValidation
    attr_accessor :errors

    # *initialize()*
    # Instatiate the BedgraphValidator.
    # _BedgraphFile_ 		- The path of the BedgraphFile to be validated.
    # _maxErrors_ 	-	Optional: maximum errors tolerated before giving up.
    def initialize(optsHash)
      @lffFile = optsHash['--BedgraphFile']
      @maxErrors = 25
      @errors = {}
      @eps = {}
      @currLineNum = 0
    
    end
    
    
    # *validate file()*
    # Go through file line by line ( low memory ) and validate each record
    def validateFile()
      #BRL::UTIL::setLowPriority()
      maxNumCols = 12
      reader = BRL::Util::TextReader.new(@lffFile)
      if(File::size(reader) <= 0 )
        @errors[1] = BedgraphValidator.new("-File is 'Empyt'. No data in file.")
      else
        reader.each { |line|
          @currLineNum += 1
         if ( @currLineNum > 2)
          line.strip!
          next if(line =~ /^\s*#/ or line =~ /^\s*$/ or line =~ /^\s*\[/)
          ff = line.split("\t")
          if(ff.size == 4 )
            valid = BedgraphValidator.validateMain(ff)
          else
            valid = BedgraphValidateError.new("- not a valid Bedgraph record type.\n" +
                                         "  Wrong number of fields. Have #{ff.size} fields rather than 4)\n")
          end
          # Assess validation result
          if(valid.is_a?(BedgraphValidateError))
            @errors[@currLineNum] = valid
            break if(@errors.size >= @maxErrors)
          end
          end
        }
      end
      reader.close()
      return @errors.empty?
    end
      
    def haveErrors?()
        return (!@errors.nil? and !@errors.empty?)
    end
    
    def haveTooManyErrors?()
        return (!@erros.nil? and !@errors.empty? and @errors.size >= @maxErrors)
    end
    
    def haveSomeErrors?()
        return (!@errors.nil? and !@errors.empty? and @errors.size < @maxErrors)
    end
    
    def printErrors(ios = $stderr)
        return if(@errors.nil? or @errors.empty?)
        ios.puts "\n\n"
        if(@errors.size < @maxErrors)
          ios.puts "WARNING: the file had some formatting errors. See examples below."
    	else
    		ios.puts "ERROR: the file had too many formatting errors! See examples below."
        end
        ios.puts   "----------------------------------------------------------\n\n"

        @errors.keys.sort.each { |lineNum|
          err = @errors[lineNum]
          ios.puts "Line #{lineNum}   Has errors:\n#{err.message}\n\n"
        }
        ios.puts "... There were more errors, but only 25 are listed above....\n\n" if(@errors.size >= @maxErrors)
        return
    end
  

    def clear()
      @lffFile = @epFile = @maxErrors = @maxWarnings = nil
      @errors.clear
      return
    end
        
  
    def BedgraphValidator.validateMain(fields)
      error = BedgraphValidateError.new()
      retVal = fields
      if(fields.size != 4)
        error.message += "- Not an BedGRAPH [entry point] record. It only has #{fields.size} but should have 4\n"
        retVal = error
      end
      
    	# Checking chrom field
    	unless(fields[0] =~ /chr(\d+|X|Y)/ or fields[0] =~ /scaffold\d+/)
            error.message += "-'#{fields[0]}' is not valid entry. It should be either chr or scaffold"    
            retVal = error
    	end
    	# Checking chromStart column
    	if( fields[1].to_i <=0 )
          error.message += "-ChromStart position must be in integer\n"
          retVal = error
    	end
    	# Checking chromEnd column
    	if( fields[2].to_i <=0 )
          error.message += "-ChromEnd position must be in integer\n"
          retVal = error
    	end
    	# Checking datavale column
    	unless( fields[3] =~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?$/i)
          error.message += "-DataValue'#{fields[3]}' is not correct\n"
          retVal = error
    	end
    	
    	# Check if any fields are empty that shouldn't be.
        fields.each_index { |ii|
          field = fields[ii]
          if((field.nil? or (field.is_a?(String) and field =~ /^\s*$/)))
            error.message += "- some of the fields are empty and this is not allowed\n"
            retVal = error
            break
          end
        }
    	
    	return retVal
    end
    	
    	
    
    
    def BedgraphValidator.processArguments()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--BedgraphFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      BedgraphValidator.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      BedgraphValidator if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

    # Display usage info and quit.
    def BedgraphValidator.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:

   Validates an Bedgraph file in the indicated way.
   Can validate against a 3-column Bedgraph entrypoint file if available.

  COMMAND LINE ARGUMENTS:
    --BedgraphFile       | -f  => Bedgraph file to validate.
    --help          | -h  => [Optional flag]. Print help info and exit.

  USAGE:
  BedgraphgraphValidator.rb -f input.bd

  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def BedgraphValidator.usage(msg='')
  end # class BedgraphValidator
end

#module BRL; module FileFormats

################################################################################
# MAIN (if run from command line)
################################################################################
if(__FILE__ == $0)
	$stdout.sync = true
	optsHash = BRL::FileFormats::BedgraphValidator.processArguments()
  validator = BRL::FileFormats::BedgraphValidator.new(optsHash)
  allOk = validator.validateFile()
  puts validator.currLineNum
  exitVal = 0
  unless(allOk)
    validator.printErrors()
    if(validator.haveSomeErrors?())
    	exitVal = 10
    elsif(validator.haveTooManyErrors?())
   	  exitVal = 20
    else
      exitVal = 30
    end
  end
  exit(exitVal)
end
end
