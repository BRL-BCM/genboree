#!/usr/bin/env ruby

# ##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
# ##############################################################################
$VERBOSE = $verbose = VERBOSE = nil
require 'rein'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/fileFormats/delimitedTable'

# ##############################################################################
# NAMESPACE
# - a.k.a. 'module'
# - This is standard and matches the directory location + "Tool"
# - //brl-depot/.../brl/genboree/toolPlugins/tools/tiler/
# ##############################################################################
module BRL ; module Genboree ; module ToolPlugins ; module Tools ; module SampleSelectorTool

  # ##############################################################################
  # HELPER CLASSES
  # ##############################################################################

  # ##############################################################################
  # EXECUTION CLASS
  # ##############################################################################
  class SampleSelector

    # Accessors (getters/setters ; instance variables
    attr_accessor :sampleInFile, :ruleFile
    attr_accessor :outputClass, :outputType, :outputSubtype

    # Required: the "new()" equivalent
    def initialize(optsHash=nil)
      self.config(optsHash) unless(optsHash.nil?)
    end

    # ---------------------------------------------------------------
    # HELPER METHODS
    # - set up, do specific parts of the tool, etc
    # ---------------------------------------------------------------
    # Method to handle tool configuration/validation
    def config(optsHash)
      @sampleInFile = optsHash['--sampleFile'].strip
      @ruleFile = optsHash['--ruleFile']
      $stderr.puts "  PARAMS:\n  - sampleInFile => #{@sampleInFile}\n  - ruleFile => #{@ruleFile}\n\n"
      readRuleFile()
    end

    # Reads in rule file
    def readRuleFile()
      ruleFile = BRL::Util::TextReader.new(@ruleFile)
      @engine = Rein::RuleEngine.new(ruleFile)
      ruleFile.close() unless(ruleFile.closed?)
      $stderr.puts "#{Time.now} SELECTOR - Read rules file and found #{@engine.rules.size} rules."
      return
    end

    # ---------------------------------------------------------------
    # MAIN EXECUTION METHOD
    # - instance method called to "do the tool"
    # ---------------------------------------------------------------
    # Applies rules to each record in LFF file and outputs LFF record accordingly.
    def applyRules()
      # Make DelimitedRecord object (just 1) used during rule testing. Reuse will avoid
      # overheado f making 1 object per line.
      sampleRec = BRL::FileFormats::DelimitedRecord.new(nil, nil)

      # Set up sample file
      # - read in headers
      # - set alphabetical col sort order
      sampleTable = BRL::FileFormats::DelimitedTable.new()
      sampleReader = BRL::Util::TextReader.new(@sampleInFile)
      sampleTable.parseColHeaders(sampleReader)
      # sampleTable.colOrderBy { |colName, idx| colName }
      idx2hdrMap = sampleTable.colIndexMap
      columns = sampleTable.columns
      puts columns.join("\t")
      # Go through rest of lines of sample file
      # - treat as DelimitedRecords
      # - test each line against rules
      sampleReader.each { |line|
        line.strip!
        # Skip blanks, headers, comments
        next if(line !~ /\S/)

        # Populate LFFHash object
        sampleRec.replace(line, idx2hdrMap)

        # Test DelimitedRecord object
        passedRuleSet = @engine.fire(sampleRec)

        # If passes rule set, output the row
        puts sampleRec.to_s(columns) if(passedRuleSet)
      }
      # Close lff file
      sampleReader.close()
      return BRL::Genboree::OK
    end

    # ---------------------------------------------------------------
    # CLASS METHODS
    # - generally just 2 (arg processor and usage)
    # ---------------------------------------------------------------
    # Process command-line args using POSIX standard
    def SampleSelector.processArguments(outs)
      # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--sampleFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--ruleFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--verbose', '-V', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      outs[:verbose] = true if(optsHash and optsHash.key?('--verbose'))
      outs[:optsHash] = optsHash
      unless(progOpts.getMissingOptions().empty?)
        SampleSelector.usage("USAGE ERROR: some required arguments are missing")
      end
      if(optsHash.empty? or optsHash.key?('--help'))
        SampleSelector.usage()
      end
      return optsHash
    end

    # Display usage info and quit.
    def SampleSelector.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:

    Applies the rules in the rule file (in a rules-specification YAML format),
    to each of the sample rows in the sample file, using the Rein rule engine.

    The first non-blank row in the sample file must be the column headers.
    The file must be tab-delimited.
    The number of sample columns must match the number of header columns.
    Blank rows are skipped.
    Blank columns in the header row cause that column to be skipped.

    Every sample record will be tested against the rules.

    Sample records matching the rule set in an appropriate way will be output on
    stdout. This application is mainly for off-line sample record filtering.

    NOTES ABOUT THE RULE SET:

    BRL's extension of the Rein engine supports several modes of operation for
    a rule *set* and how an object may pass the rule *set*. How the individual
    rules work together to allow an object to pass the whole set is called
    'conflict resolution' in Rein (because even though the object may pass some
    individual rules and not others in the set, it may pass the set as a whole).

    Our extensions to Rein support the following options for the 'conflict'
    property in the rule file:

      'all'       => The object must pass ALL rules in the set.
      'any'       => The object must pass ONE or MORE rules in the set.
      'required'  => The object must pass all rules whose REQUIRED property
                     is 'true' in the set. Other rules may or may not pass.
      'priority'  => The original mode for Rein: the one rule with the hightest
                     'priority' is the one that determines if the object passes
                     the set as a whole. If no priority, then the first rule.

    NOTES ABOUT 'ACTIONS':

    The action(s) of ALL PASSING RULES are executed, regardless of whether
    the object passes the rule set as whole or not.

    Actions in the rules file should be limited to properties supported by the
    BRL::FileFormats::DelimitedRecord class. In general, this turns all column
    headers into object-attributes of the DelimitedRecord. If you want more than
    this, implement your own class from Rein::ObjectTemplate and do your own
    fancy things...that's how this program was implemented.

    NOTES ABOUT TESTING OBJECT PROPERTIES:

    This tool applies rules to Sample records that are internally represented as
    a BRL::FileFormats::DelimitedRecord. This means that you can test any
    column by using its column name.

    TO DO:

    Currently, you CANNOT TEST ATTRIBUTES WITH SPACES OR WEIRD CHARACTERS.
    Fixing this requires a core change in the rules engine. (THIS MUST BE
    FIXED FOR SAMPLES, AT LEAST).

    NOTES ABOUT OPERATIONS:

    The BRL extensions to Rein have added a number of operations for use in
    rule conditions. A full list of supported operators follows with example
    left-hand (DelimitedRecord property) and right-hand operands; please make
    note of type-specific versions when provided:

      ----Generic Operators----
      >
      <
      >=
      <=
      =
      isTrue?           => true, case-insensitive 'true' or 'yes', non-0 number
      isFalse?          => false, case-insensitive 'false' or 'no', 0

      ----Number Specific Operators----
      num_between?      => number within a range such as: (29..95)
      num_notBetween?   => number not within a range such as: (2..25)

      ----String Specific Operations----
      beginsWith?
      contains?
      endsWith?

      beginsWith_ignoreCase?
      contains_ignoreCase?
      endsWith_ignoreCase?

      notBeginsWith?
      notContains?
      notEndsWith?

      notEndsWith_ignoreCase?
      notContains_ignoreCase?
      notBeginsWith_ignoreCase?

      str_between?      => string within a range such as: ('a'..'k')
      str_notBetween?   => string not within a range such as: ('pbe'..'pbg')

    COMMAND LINE ARGUMENTS:
      --sampleFile          | -f  => Source sample file.
      --ruleFile            | -r  => Rule specification file, in proper YAML
                                     format.
      --verbose             | -V  -> [Optional] Prints more error info (trace)
                                     and such when error. Mainly for Genboree.
      --help                | -h  => [Optional flag]. Print help info and exit.

    USAGE:
    sampleRuleSelector -f samples.txt -r filters.yaml > selected.samples.txt

  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def SampleSelector.usage(msg='')
  end # class SampleSelector
end ; end ; end ; end ; end # namespace

# ##############################################################################
# MAIN
# ##############################################################################
begin
  # Get arguments hash
  outs = { :optsHash => nil, :verbose => false }
  optsHash = BRL::Genboree::ToolPlugins::Tools::SampleSelectorTool::SampleSelector.processArguments(outs)
  $stderr.puts "#{Time.now()} SELECTOR - STARTING"
  # Instantiate method
  selector =  BRL::Genboree::ToolPlugins::Tools::SampleSelectorTool::SampleSelector.new(optsHash)
  $stderr.puts "#{Time.now()} SELECTOR - INITIALIZED"
  # Execute tool
  exitVal = selector.applyRules()
rescue Exception => err # Standard capture-log-report handling:
  errTitle =  "#{Time.now()} SELECTOR - FATAL ERROR: The selector exited without processing all the data, due to a fatal error.\n"
  msgTitle =  "FATAL ERROR: The selector exited without processing all the data, due to a fatal error.\n"
  msgTitle += "Please contact the Genboree admin. This error has been dated and logged.\n" if(outs[:verbose])
  errstr   =  "   The error message was: '#{err.message}'.\n"
  errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
  puts msgTitle unless(outs[:optsHash].key?('--help'))
  $stderr.puts(errTitle + errstr) if(outs[:verbose])
  exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} SELECTOR - DONE" unless(exitVal != 0)
exit(exitVal)
