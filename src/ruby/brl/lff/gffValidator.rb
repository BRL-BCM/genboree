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
  class GffValidateError < StandardError
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
	# Gff Validator
	# ---------------------------------------------------------------------------
  class GffValidator
    attr_accessor :maxErrors, :maxWarnings, :lffFile
    attr_accessor :currLineNum,  :doFullValidation
    attr_accessor :errors

    # *initialize()*
    # Instatiate the GffValidator.
    # _GffFile_ 		- The path of the GffFile to be validated.
    # _maxErrors_ 	-	Optional: maximum errors tolerated before giving up.
    def initialize(optsHash)
      @lffFile = optsHash['--GffFile']
      @maxErrors = 25
      @errors = {}
      @eps = {}
      @currLineNum = 0
    
    end
    
    
    # *validate file()*
    # Go through file line by line ( low memory ) and validate each record
    def validateFile()
      #BRL::UTIL::setLowPriority()
     
      format = 0     
      maxNumCols = 9
      reader = BRL::Util::TextReader.new(@lffFile)
      if (@lffFile =~ /\.gff3/ )
        format = 1
      end
      if(File::size(reader) <= 0 )
        @errors[1] = GffValidator.new("-File is 'Empyt'. No data in file.")
      else
        reader.each { |line|
          
          @currLineNum += 1
         if ( @currLineNum > 3)
          line.strip!
          next if(line =~ /^\s*#/ or line =~ /^\s*$/ or line =~ /^\s*\[/)
          ff = line.split("\t")
          if(ff.size == 9 )
             
            valid = GffValidator.validateMain(ff,format)
          else
            valid = GffValidateError.new("- not a valid Gff record type.\n" +
                                         "  Wrong number of fields. Have #{ff.size} fields rather than between 3 and -#{maxNumCols} fields)\n")
          end
          # Assess validation result
          if(valid.is_a?(GffValidateError))
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
        
  
    def GffValidator.validateMain(fields, format)
      error = GffValidateError.new()
      retVal = fields
      if(fields.size != 9)
        error.message += "- Not an Gff [entry point] record. It only has #{fields.size} but should have 4\n"
        retVal = error
      end
    	# Checking chrom field
    	if(fields[0] =~ /^\<|\s/)
            error.message += "-'#{fields[0]}' is not valid entry. " 
            retVal = error
    	end
    	# Checking for source column
    	if ( fields[1].nil?)
          error.message += "-Source column cant remain empty.." 
          retVal = error
    	end
    	# Checking for type column
    	if ( fields[2].nil?)
          error.message += "-Type column cant remain empty.." 
          retVal = error
    	end
    	# Checking Start column
    	if( fields[3].to_i <=0 )
          error.message += "-ChromStart position must be in integer\n"
          retVal = error
    	end
    	# Checking end column
    	if( fields[4].to_i <=0 )
          error.message += "-ChromEnd position must be in integer\n"
          retVal = error
    	end
    	# Checking score column
    	unless( fields[5] =~ /^(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?$/i or fields[5] == "." )
          error.message += "-Score'#{fields[5]}' is not correct\n"
          retVal = error
    	end
    	# Checking strand column
    	unless( fields[6] =~ /^\s*[\+|\-|\.|\?]\s*$/ )
          error.message += "-the strand column contains '#{fields[6]}' and not + or -\n"
          retVal = error
        end
    	# Checking frame column
    	unless ((fields[7].to_i >= 0 and fields[7].to_i <=2) or (fields[7] == "."))
          error.message += "-If the feature is a coding exon, frame should be a number between 0-2 not the given value '#{fields[7]} \n"
          retVal = error
    	end
    	if ( format == 1)
          unless (fields[8] =~ /(\w+\=(\w*\d*\,?)*\;?)+/ )
            error.message += "-'#{fields[8]}' has error. Plz check online for the correct GFF3 format. It should be format tag=value "
            retVal = error
          end
    	else
          unless ( fields[8] =~ /\w+\d+/ and fields[8] !~ /\=/)
            error.message += "-'#{fields[8]}' has error. Plz check online for the correct GFF format "
            retVal = error
          end
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
    	
    	
    
    
    def GffValidator.processArguments()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--GffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      GffValidator.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      GffValidator if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

    # Display usage info and quit.
    def GffValidator.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:

   Validates an Gff file in the indicated way.
   Can validate against a 3-column Gff entrypoint file if available.

  COMMAND LINE ARGUMENTS:
    --GffFile       | -f  => Gff file to validate.
    --help          | -h  => [Optional flag]. Print help info and exit.

  USAGE:
  GffgraphValidator.rb -f input.gff

  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def GffValidator.usage(msg='')
  end # class GffValidator
end

#module BRL; module FileFormats

################################################################################
# MAIN (if run from command line)
################################################################################
if(__FILE__ == $0)
	$stdout.sync = true
	optsHash = BRL::FileFormats::GffValidator.processArguments()
  validator = BRL::FileFormats::GffValidator.new(optsHash)
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