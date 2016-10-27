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
  class BedValidateError < StandardError
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
	# BED Validator
	# ---------------------------------------------------------------------------
  class BedValidator
    attr_accessor :maxErrors, :maxWarnings, :lffFile
    attr_accessor :currLineNum,  :doFullValidation
    attr_accessor :errors

    # *initialize()*
    # Instatiate the BedValidator.
    # _bedFile_ 		- The path of the bedFile to be validated.
    # _maxErrors_ 	-	Optional: maximum errors tolerated before giving up.
    def initialize(optsHash)
      @lffFile = optsHash['--bedFile']
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
        @errors[1] = BedValidateError.new("-File is 'Empyt'. No data in file.")
      else
        reader.each { |line|
          @currLineNum += 1
         if ( @currLineNum > 2)
          
          line.strip!
          next if(line =~ /^\s*#/ or line =~ /^\s*$/ or line =~ /^\s*\[/)
          ff = line.split("\t")
          if(ff.size == 3 )
            valid = BedValidator.validateMain(ff)
          elsif(ff.size >= 3 and ff.size <= maxNumCols)
            valid = BedValidator.validateFull(ff)
          else
            valid = BedValidateError.new("- not a valid BED record type.\n" +
                                         "  Wrong number of fields. Have #{ff.size} fields rather than between 3 and -#{maxNumCols} fields)\n")
          end
          # Assess validation result
          if(valid.is_a?(BedValidateError))
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
        
  
    def validateMain(fields)
      error = BedValidateError.new()
      retVal = fields
      if(fields.size != 3)
        error.message += "- Not an BED [entry point] record. It only has #{fields.size} but should have 3\n"
        retVal = error
      end
      # Check for empty fields here, and check 3rd column specifically
      fields.each_index { |ii|
        if(fields[ii] =~ /^\s*$/)
          error.message += "- Column #{ii+1} is empty. Cannot be empty.\n"
          retVal = error
        else
          if(ii == 0 and (ii !~/chr\d+/ or ii !~/scaffold\d+/))
            error.message += "1st column must be name of chromosome (chr3, chrY, chr2_random) or scaffold (e.g. scaffold10671)."
            retVal = error
          end
          
          if((ii == 1 or ii == 2 )and (fields[ii].to_i <= 0))
            error.message += "- #{ii} Column must be an integer that is the position of the feature\n"
            retVal = error
          end
        end
      }
      return retVal
    end
    
    
     # *Bedthat .validateFull()*
    # Validates an Bed record passed as an ARRAY, presumably after being read from a file.
    # _fields_ 			- The Bed record as an Array
    def BedValidator.validateFull(fields)
    	# Max num of columns?
    	maxNumCols = 12
    	error = BedValidateError.new()
    	retVal = fields
    	unless(fields.size >= 3 and fields.size <= 12)
          error.message += (" - This bed record has #{fields.size} fields\n" +
                            "BED record are <TAB> delimited and have either 3 or 12 fields\n")
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
    	# Checking all fields
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
    	# Checking name column
    	if( fields[3].length > 200 )
          error.message += "-the name '#fields[3]' is too long\n"
          retVal = error
    	end
    	# Checking the score column
    	unless( fields[4] =~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?$/i )
          error.message += "-Score '#{fields[4]}' is out of range\n"
          retVal = error
    	end
    	# Checking the strand column
    	unless( fields[5] =~ /^\s*[\+\-]\s*$/ )
          error.message += "-the strand column contains '#{fields[7]}' and not + or -\n"
          retVal = error
    	end
    	# Checking the thickStart column
    	if( fields[6].to_i <0)
          error.message += "-thickStart '#{fields[6]}'position must be in integer\n"
          retVal = error
    	end
    	if( fields[7].to_i <0)
          error.message += "-thickEnd '#{fields[7]}' position must be in integer\n"
          retVal = error
    	end
    	unless( fields[8].to_i == 255 or fields[8].to_i ==0  )
          error.message += "-itemRGB '#{fields[8]}' shoud have values of the form (255,0,0)\n"
          retVal = error
    	end
    	if( fields[9].to_i < 0 )
          error.message += "-BlockCount '#{fields[9]}' shoud have positive integer\n"
          retVal = error
    	end
    	unless( fields[10] =~ /[\d+]/ or fields[10] =~ /[\d+]\,+[\d+]/)
          error.message += "-BlockSize '#{fields[10]}' shoud have positive integers or comma separated integers\n"
          retVal = error
    	end
    	unless( fields[11] =~ /[\d+]/ or fields[11] =~ /[\d+]\,+[\d+]/)
          error.message += "-BlockStarts '#{fields[11]}' shoud have positive integers or comma separated integers\n"
          retVal = error
    	end
    	return retVal
    end
    	
    	
    
    
    def BedValidator.processArguments()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--bedFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      BedValidator.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      BedValidator if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

    # Display usage info and quit.
    def BedValidator.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:

   Validates an Bed file in the indicated way.
   Can validate against a 3-column Bed entrypoint file if available.

  COMMAND LINE ARGUMENTS:
    --BedFile       | -f  => Bed file to validate.
    --help          | -h  => [Optional flag]. Print help info and exit.

  USAGE:
  bedValidator.rb -f input.bd

  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def BedValidator.usage(msg='')
  end # class BedValidator
end

#module BRL; module FileFormats

################################################################################
# MAIN (if run from command line)
################################################################################
if(__FILE__ == $0)
	$stdout.sync = true
	optsHash = BRL::FileFormats::BedValidator.processArguments()
  validator = BRL::FileFormats::BedValidator.new(optsHash)
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