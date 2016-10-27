#!/usr/bin/env ruby

# ##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
# ##############################################################################
require 'rein'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/fileFormats/lffHash'

# ##############################################################################
# NAMESPACE
# - a.k.a. 'module'
# - This is standard and matches the directory location + "Tool"
# - //brl-depot/.../brl/genboree/toolPlugins/tools/tiler/
# ##############################################################################
module BRL ; module Genboree ; module ToolPlugins ; module Tools ; module LffSelectorTool

  # ##############################################################################
  # HELPER CLASSES
  # ##############################################################################

  # ##############################################################################
  # EXECUTION CLASS
  # ##############################################################################
  class LFFSelector

    # Accessors (getters/setters ; instance variables
    attr_accessor :lffInFile, :ruleFile
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
      @lffInFile = optsHash['--lffFile'].strip
      @ruleFile = optsHash['--ruleFile']
      @outputType = optsHash['--outputType'].strip.gsub(/\\"/, "'").to_sym # '
      @outputSubtype = optsHash['--outputSubtype'].strip.gsub(/\\"/, "'").to_sym # '
      @outputClass = optsHash.key?('--outputClass') ? optsHash['--outputClass'].gsub(/\\"/, "'").to_sym  : :'Selected' # '
      $stderr.puts "  PARAMS:\n  - lffInFile => #{@lffInFile}\n  - ruleFile => #{@ruleFile}\n  - outputClass => #{@outputClass}\n  - outputType => #{@outputType}\n  - outputSubtype => #{@outputSubtype}\n\n"
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
      # Make LFFHash object (just 1) used during rule testing. Reuse will avoid
      # overheado f making 1 object per line.
      lffHash = LFFHash.new()

      # Print header
      puts "#class\tname\ttype\tsubtype\tchrom\tstart\tstop\tstrand\tphase\tscore\tqstart\tqend\tattributes\tcomments\tsequence\tfreeform comments"
      # Go through lines of lff file
      reader = BRL::Util::TextReader.new(@lffInFile)
      reader.each { |line|
        line.strip!
        # Skip blanks, headers, comments
        next if(line !~ /\S/ or line =~ /^\s*\[/ or line =~ /^\s*#/)

        # Populate LFFHash object
        lffHash.replace(line)

        # Test LFFHash object
        passedRuleSet = @engine.fire(lffHash)

        # If passes rule set, update track/class and output
        if(passedRuleSet)
          lffHash.lffClass = @outputClass
          lffHash.lffType = @outputType
          lffHash.lffSubtype = @outputSubtype
          puts lffHash.to_lff
        end
      }
      # Close lff file
      reader.close()
      return BRL::Genboree::OK
    end

    # ---------------------------------------------------------------
    # CLASS METHODS
    # - generally just 2 (arg processor and usage)
    # ---------------------------------------------------------------
    # Process command-line args using POSIX standard
    def LFFSelector.processArguments(outs)
      # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--ruleFile', '-r', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputType', '-t', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputSubtype', '-u', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputClass', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--verbose', '-V', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      outs[:verbose] = true if(optsHash and optsHash.key?('--verbose'))
      outs[:optsHash] = optsHash
      unless(progOpts.getMissingOptions().empty?)
        LFFSelector.usage("USAGE ERROR: some required arguments are missing")
      end
      if(optsHash.empty? or optsHash.key?('--help'))
        LFFSelector.usage()
      end
      return optsHash
    end

    # Display usage info and quit.
    def LFFSelector.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:

    Applies the rules in the rule file (in a rules-specification YAML format),
    to each of the LFF records in the lff file, using the Rein rule engine.

    Every LFF record will be tested against the rules, regardless of track.
    However, lffType and lffSubtype are possible subjects of rule conditions
    and may be tested to match specific track(s).

    LFF records matching the rule set in an appropriate way will be output on
    stdout with the new track info provided. This application is mainly for LFF
    record filtering.

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
    LFFHash class. If you want more, implement your own class from
    Rein::ObjectTemplate and do your own fancy things...that's how this was
    implemented.

    NOTES ABOUT TESTING OBJECT PROPERTIES:

    This tool applies rules to LFF records that are internally represented as
    an LFFHash. This means that you can test a number of static object
    properites (static fields of LFF) *and* even test arbitrary attribute-value
    pairs as if the attribute were a property of the object. That is to say,
    the following are possible properties you can test:

      lffClass
      lffType
      lffSubtype
      lffName
      lffChr
      lffStart
      lffStop
      lffStrand
      lffPhase
      lffScore
      lffQStart
      lffQStop
      lffSeq
      lffFreeComments
      <attributeName>

    Where <attributeName> is the name of an attribute in the attribute-value
    pairs (AVPs) of your LFF records. The attribute need not be present for all
    attributes, but any record missing it will *automatically* fail any
    condition that tests the missing attribute. The attribute need not have a
    value either, and can be a 'flag' type of attribute. You can test to see if
    an attribute is present or not using the 'isPresent?' and 'notIsPresent?'
    operations.

    Currently, you CANNOT TEST ATTRIBUTES WITH SPACES OR WEIRD CHARACTERS.
    Fixing this requires a core change in the rules engine.

    NOTES ABOUT OPERATIONS:

    The BRL extensions to Rein have added a number of operations for use in
    rule conditions. A full list of supported operators follows with example
    left-hand (LFFHash property) and right-hand operands; please make
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
      --lffFile             | -f  => Source LFF file.
      --ruleFile            | -r  => Rule specification file, in proper YAML
                                     format.
      --outputType          | -t  => The output track's 'type'.
      --outputSubtype       | -u  => The output track's 'subtype'.
      --outputClass         | -c  => [Optional] The output track's 'class'.
                                     Defaults to 'Tiles'.
      --verbose             | -V  -> [Optional] Prints more error info (trace)
                                     and such when error. Mainly for Genboree.
      --help                | -h  => [Optional flag]. Print help info and exit.

    USAGE:
    lffRuleSelector -f myLFF.lff -r filters.yaml -t Exons -u Long > myLFF.select.lff

  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def LFFSelector.usage(msg='')
  end # class LFFSelector
end ; end ; end ; end ; end # namespace

# ##############################################################################
# MAIN
# ##############################################################################
begin
  # Get arguments hash
  outs = { :optsHash => nil, :verbose => false }
  optsHash = BRL::Genboree::ToolPlugins::Tools::LffSelectorTool::LFFSelector.processArguments(outs)
  $stderr.puts "#{Time.now()} SELECTOR - STARTING"
  # Instantiate method
  selector =  BRL::Genboree::ToolPlugins::Tools::LffSelectorTool::LFFSelector.new(optsHash)
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
