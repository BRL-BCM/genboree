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
  class LFFValidateError < StandardError
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
	# LFF Validator
	# ---------------------------------------------------------------------------
  class LFFValidator
    attr_accessor :maxErrors, :maxWarnings, :lffFile, :epFile, :recsPerBlock
    attr_accessor :firstLineNum, :currLineNum, :doOldFormat, :doFullValidation
    attr_accessor :errors

    # *initialize()*
    # Instatiate the LFFValidator.
    # _lffFile_ 		- The path of the lffFile to be validated.
    # _maxErrors_ 	-	Optional: maximum errors tolerated before giving up.
    # _epFile_			- Optional: path to epFile to use for validating entrypoints
    def initialize(optsHash)
      @lffFile = optsHash['--lffFile']
      @doFullValidation = (optsHash['--checkType'] == 'full' ? true : false)
      @firstLineNum = optsHash.key?('--firstLineNum') ? optsHash['--firstLineNum'].to_i : 0
      @epFile = optsHash['--epFile']
      @recsPerBlock = optsHash.key?('--recsPerBlock') ? optsHash['--recsPerBlock'].to_i : 16_000
      @doOldFormat = optsHash.key?('--doOldFormat')
      @failAllBadCoords = optsHash.key?('--failAllBadCoords')
      raise "ERROR: a valid EP file must be provided with --epFile if also setting --failAllBadCoords." if(@failAllBadCoords and (@epFile.nil? or @epFile !~ /\S/ or !File.exist?(@epFile)))
      @maxErrors = 25
      @errors = {}
      @eps = {}
      @currLineNum = firstLineNum - 1

      unless(@epFile.nil?)
        readEPFile() # read the EP file so we know what entrypoints are valid
      end
    end

    # *validateFile()*
    # Go through the file line-by-line (low memory) and validate each record.
    def validateFile()
    	BRL::Util.setLowPriority()
    	# Max num of columns?
    	maxNumCols = (@doOldFormat ? 14 : 15)
      reader = BRL::Util::TextReader.new(@lffFile)
      if(File::size(reader) <= 0)
        @errors[1] = LFFValidateError.new("- File is *EMPTY*. No data in file.")
      else
        reader.each { |line|
        	@currLineNum += 1
        	if(reader.lineno > 0 and (reader.lineno % @recsPerBlock == 0))
            sleepAmount = 2.5 + rand(3)
            #$stderr.puts("LFFValidator: Sleeping for #{sleepAmount}")
            sleep(sleepAmount)
          end
        	line.strip!
          next if(line =~ /^\s*#/ or line =~ /^\s*$/ or line =~ /^\s*\[/)
          ff = line.split("\t")
          if(ff.size == 3)
          	next unless(@doFullValidation)
            valid = LFFValidator.validateRefSeqArray(ff)
            @eps[ff[0]] = ff[2].to_i if(valid)
          elsif(ff.size >= 10 and ff.size <= maxNumCols)
            valid = LFFValidator.validateAnnotationArray(ff, @eps, @doOldFormat)
          elsif(ff.size == 7)
          	next # Skip any assembly lines (ignore...but don't tell anyone such lines are ok)
          else
            valid = LFFValidateError.new("- not a valid LFF record type.\n" +
                                         "  Wrong number of fields (has #{ff.size} fields rather than 3 or 10-#{maxNumCols} fields)\n")
          end
          # Assess validation result
          if(valid.is_a?(LFFValidateError))
            @errors[@currLineNum] = valid
            break if(@errors.size >= @maxErrors)
          end
        }
      end
      reader.close()
      return @errors.empty?
    end

    def readEPFile()
      return if(@epFile.nil?)
      @eps = {}
      reader = BRL::Util::TextReader.new(@epFile)
      reader.each { |line|
        next if(line =~ /^\s*#/ or line =~ /^\s*$/ or line =~ /^\s*\[/)
        line.strip!()
        ff = line.split("\t")
        valid = LFFValidator.validateRefSeqArray(ff)
        if(valid.is_a?(LFFValidateError))
          raise "\n\nERROR: #{valid.message}\n\n"
        end
        @eps[ff[0]] = ff[2].to_i
      }
      reader.close
      return
    end

    def haveErrors?()
   		return (!@errors.nil? and !@errors.empty?)
   	end

   	def haveTooManyErrors?()
   		return (!@errors.nil? and !@errors.empty? and @errors.size >= @maxErrors)
   	end

   	def haveSomeErrors?()
   		return (!@errors.nil? and !@errors.empty? and @errors.size < @maxErrors)
   	end

    def printErrors(ios = $stderr)
    	return if(@errors.nil? or @errors.empty?)
    	ios.puts "\n\n"
    	#if(@errors.size < @maxErrors)
    	#	ios.puts "WARNING: the file had some formatting errors. See examples below."
    	#else
    		ios.puts "ERROR: the file has formatting and/or content errors! See examples below."
      #end
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

    def LFFValidator.validateRefSeqArray(fields)
      error = LFFValidateError.new()
      retVal = fields
      if(fields.size != 3)
        error.message += "- Not an LFF [entry point] record. It only has #{fields.size} but should have 3\n"
        retVal = error
      end
      # Check for empty fields here, and check 3rd column specifically
      fields.each_index { |ii|
        if(fields[ii] =~ /^\s*$/)
          error.message += "- Column #{ii+1} is empty. Cannot be empty.\n"
          retVal = error
        else
          if(ii == 2 and (fields[ii].to_i <= 0))
            error.message += "- 3rd Column must be an integer that is the Entry Point length\n"
            retVal = error
          end
        end
      }
      return retVal
    end

    # *LFF.validateAnnotationArray()*
    # Validates an LFF record passed as an ARRAY, presumably after being read from a file.
    # _fields_ 			- The LFF record as an Array
    # _validEPHash 	- An optional hash of valid entrypoint names with valid lengths as values
    def LFFValidator.validateAnnotationArray(fields, validEPHash = nil, doOldFormat = false)
    	# Max num of columns?
    	maxNumCols = (doOldFormat ? 14 : 15)
    	checkValidEP = !(validEPHash.nil? or validEPHash.empty?)
      error = LFFValidateError.new()
      retVal = fields
      # origFields = fields.dup
      # Is the size right? If not, stop right here.
      unless((fields.size == 10 or fields.size == 12) or (fields.size > 12 and fields.size <= maxNumCols))
        error.message += (  "- This LFF record has #{fields.size} fields\n" +
                            "- LFF records are <TAB> delimited and have either 10 or 12 fields\n" +
                            "- Enhanced LFF records can have 13 or #{maxNumCols} fields\n" +
                            "- Space characters are not tabs\n" )
        retVal = error
      else # right number of fields, check them
        # ARJ: the following check is kinda important for things to work, but {} used by users...really need JDBC fix (some year they will fix)
        # fields.each { |field|
        #  if(field =~ /\{/ or field =~ /\}/)
        #    error.message += "- do not use { or } characters; unsafe due to a bug in MySQL's Java driver\n"
        #    retVal = error
        #    break
        #  end
        #}
      	lffStop = fields[6].to_i
      	lffStart = fields[5].to_i
        # Do we know about this entrypoint? If not, error and skip annotation.
        if(checkValidEP)
          if(!validEPHash.key?(fields[4]))
            error.message += "- referring to unknown entry point '#{fields[4]}'\n"
            retVal = error
          else # found correct refseq, but is coords ok?
            if(@failAllBadCoords)
              if(lffStop > validEPHash[fields[4]] or lffStop < 0)
                error.message += ("- end of annotation (7th column: '#{fields[6]}') is either \n" +
                                  "  not an integer or is not within the chromosome\n" +
                                  "  (length of '#{fields[4]}' is #{validEPHash[fields[4]]})\n")
                retVal = error
              end
              if(lffStart > validEPHash[fields[4]] or lffStart < 0)
                error.message += ("- start of annotation (6th column: '#{fields[5]}') is either \n" +
                                  "  not an integer or is not within the chromosome\n" +
                                  "  (length of '#{fields[4]}' is #{validEPHash[fields[4]]})\n")
                retVal = error
              end
            else # allow 1 but not both coords to be off the end of a chr
              if( (lffStop > validEPHash[fields[4]] or lffStop < 0) and
                  (lffStart > validEPHash[fields[4]] or lffStart < 0) )
                error.message += ("- both the start and stop of the annotation (6th, 7th columns: '#{fields[5]}', '#{fields[6]}') are outside the chromosome. Such imaginary annotations are not allowed. (Length of '#{fields[4]}' is #{validEPHash[fields[4]]}).\n")
                retVal = error
              end
            end
          end
        end

        # OK, we need to do all these checks
        # Check that the name column is not too long.
        if(fields[1].length > 200)
          error.message += "- the name '#{fields[1]}' is too long\n"
          retVal = error
        end
        # Check the type column
        if(fields[2] =~ /:/)
          error.message += "- the type column cannot contain ':' (the track type:subtype separator character)"
          retVal = error
        end
        # Check the subtype column
        if(fields[3] =~ /:/)
          error.message += "- the subtype column cannot contain ':' (the track type:subtype separator character)"
          retVal = error
        end
        # Check the strand column.
        unless(fields[7] =~ /^\s*[\+\-]\s*$/)
          error.message += "- the strand column contains '#{fields[7]}' and not + or -\n"
          retVal = error
        end
        # Check the phase column.
        unless(fields[8] =~ /^\s*[012\.]\s*$/)
           error.message += "- the phase column contains '#{fields[8]}' and not 0, 1, 2, or .\n"
           retVal = error
        end
        # Check start coord.
        unless(fields[5].valid?(:int)) # Don't need to check neg coords since only rejected if --failAllBadCoords provided and would be caught by now. Neg coords allowed in the default behavior should be truncated by the consuming code.
          error.message += "- the start column (6th column: '#{fields[5]}') is an integer\n"
          error.message += "- reference sequence coordinates start at 1\n"
          error.message += "- bases at negative or fractional coordinates are not supported\n"
          retVal = error
        end
        # Check the end coord.
        unless(fields[6].valid?(:int)) # Don't need to check neg coords since only rejected if --failAllBadCoords provided and would be caught by now. Neg coords allowed in the default behavior should be truncated by the consuming code.
          error.message += "- the end column (7th column: '#{fields[6]}') and is not an integer\n"
          error.message += "- reference sequence coordinates start at 1\n"
          error.message += "- bases at negative or fractional coordinates are not supported\n"
          retVal = error
        end
        unless(fields[9].valid?(:float))
          error.message += "- the score column contains '#{fields[9]}' and not an integer or real number.\n"
          retVal = error
        end
        # Check qstart/qend coords.
        if(fields.length > 10)
          unless(fields[10] =~ /^\s*\.\s*$/ or fields[10] =~ /^\s*(?:\+|\-)?\d+\s*$/)
            error.message += "- the qstart column (11th column: '#{fields[10]}') is not an integer or '.'\n"
            error.message += "- bases at negative or fractional coordinates are not supported\n"
            retVal = error
          end
          unless(fields[11] =~ /^\s*\.\s*$/ or fields[11] =~ /^\s*(?:\+|\-)?\d+\s*$/)
            error.message += "- the qstop column (12th column: '#{fields[11]}') is not an integer or '.'\n"
            error.message += "- bases at negative or fractional coordinates are not supported\n"
            retVal = error
          end
        end
        # Check the attribute-comments field.
        if(fields.length >= 13)
	        #$stderr.puts("  - has more than 13")
	        # Only check comments column strictly if doing new format.
	        # Old format allows anything in comments.
	        # Of course skip "empty" 13th column in all cases.
          unless(doOldFormat or fields[12] !~ /\S/ or fields[12] =~ /^\s*\.\s*$/)
            fields[12].strip!
	          #$stderr.puts("  - attr-comments NOT empty, need to check")
	          fields[12].gsub!(/(?:\s*;\s*)+$/, ';') if(fields[12] =~ /(?:\s*;\s*)+$/)
            fields[12] << ';' unless(fields[12][-1] == ';'[0])
            fields[12].gsub!(/^(?:\s*;\s*)+/, '') if(fields[12] =~ /^(?:\s*;\s*)+/)
            fields[12].gsub!(/(?:\s*;\s*)+/, ';')
             #$stderr.puts "#{fields[12]}"
            unless(fields[12] =~ /^(?:[^=;]{1,255}=(?:[^;]+)?\s*;\s*)+$/)
	            #$stderr.puts("  - looks like NON-attr stuff in the attr-comments")
              # We have some non attr-comments stuff in the 13th column.
              # This is NEVER ok in the new format.
              error.message += "- the attribute-comments column (13th column) is not correct\n"
              error.message += "- must be a series of semi-colon separated attribute value pairs\n"
              error.message += "- attribute is no more than 255 characters.\n"
              error.message += "- value is no more than ~65,000 characters.\n"
              error.message += "- example of 1 attribute value pair: myAttribute=G protein-related; \n"
              error.message += "- note the attribute name, then =, then value, then ; \n"
#              error.message += "#{fields.inspect}\n"
              retVal = error
            end
          end
        end
        # Check if any fields are empty that shouldn't be.
        fields.each_index { |ii|
        	next if(ii >= 12)
          field = fields[ii]
          if((field.nil? or (field.is_a?(String) and field =~ /^\s*$/)))
            error.message += "- some of the fields are empty and this is
not allowed\n"
            retVal = error
            break
          end
        }
      end
      return retVal
    end

    def LFFValidator.processArguments()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--checkType', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--firstLineNum', '-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--epFile', '-e', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--failAllBadCoords', '-b', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--recsPerBlock', '-r', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--doOldFormat', '-o', GetoptLong::NO_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      LFFValidator.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      LFFValidator if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

    # Display usage info and quit.
    def LFFValidator.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:

   Validates an LFF file in the indicated way.
   Can validate against a 3-column LFF entrypoint file if available.

  COMMAND LINE ARGUMENTS:
    --lffFile           | -f  => LFF file to validate.
    --checkType         | -t  => 'full' or 'annos' to do annotations only.
                                 In 'full' mode, entrypoints within the LFF
                                 file override any in the epFile.
    --firstLineNum      | -n  => Line number to use for the first line.
    --epFile            | -e  => [Optional] a 3-column LFF file of valid
                                 entrypoints. Any other EPs or annotations with
                                 incompatible coordinates will be rejected.
    --failAllBadCoords  | -b  =>  [Optional flag; requires --epFile] Instead of allowing
                                  annos that 'hang' off the ends of the chrs (in
                                  which 1 coordinate is within the chromosome),
                                  treat this as an error rather than being acceptable.
                                  Regardless, annos with NEITHER coord within the chr
                                  will be treated as errors.
    --recsPerBlock      | -r  => [Optional flag]. Option for Genboree, to get
                                 the correct record count.
    --doOldFormat       | -o  => [Optional] If present, validate against old 13
                                 column format; if not, validate against the new
                                 15 column format and enforce strict AVP syntax.
    --help              | -h  => [Optional flag]. Print help info and exit.

  USAGE:
  lFFValidator.rn -f myLFF.lff -t 'full' -n 10500 -p

  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def LFFValidator.usage(msg='')
  end # class LFFValidator
end ; end #module BRL; module FileFormats

################################################################################
# MAIN (if run from command line)
################################################################################
if(__FILE__ == $0)
	$stdout.sync = true
	optsHash = BRL::FileFormats::LFFValidator.processArguments()
  validator = BRL::FileFormats::LFFValidator.new(optsHash)
  allOk = validator.validateFile()
  puts validator.currLineNum
  exitVal = 0
  unless(allOk)
    validator.printErrors()
    if(validator.haveSomeErrors?())
    	exitVal = 10
    elsif(validator.haveTooManyErrors?())
   	  exitVal = 20
    else # WTF???
      exitVal = 30
    end
  end
  exit(exitVal)
end
