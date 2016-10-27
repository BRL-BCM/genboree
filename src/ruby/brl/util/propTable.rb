#!/usr/bin/env ruby
# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'cgi'

# ##############################################################################

module BRL ; module Util

  class ParseError < Exception; end
  class MissingKeyError < Exception; end

  class PropTable < Hash
    attr_accessor(:splitCSV)

    def initialize(inputSrc=nil, splitCSV=true)
      @splitCSV = splitCSV
      return if(inputSrc.nil?) # empty propTable
      load(inputSrc)
    end

    def load(inputSrc)
      lineCounter = 0
      line = nil
      begin
        if(inputSrc.kind_of?(String) or inputSrc.kind_of?(IO) or inputSrc.kind_of?(BRL::Util::TextReader)) # then init from string
          inputSrc.each_line { |line|
            lineCounter+=1
              self.parseLine(line)
          }
        elsif(inputSrc.kind_of?(Hash)) # then init from hash
          inputSrc.each { |key, val|
            valueArray = (@splitCSV and val.kind_of?(String) ? val.split(',') : [val])
            self[key] = (valueArray.length == 1 ? valueArray[0] : valueArray)
          }
        else # dunno the type
          raise(TypeError, "Cannot initialize a PropTable from #{inputSrc.type}. Try a String, Hash, or IO object.");
        end
      rescue BRL::Util::ParseError => err
        raise(BRL::Util::ParseError, "Bad line in properties file/string:\n'#{line}'\nat line #{lineCounter}")
      ensure
        inputSrc.close() if(inputSrc.kind_of?(IO) or inputSrc.kind_of?(BRL::Util::TextReader))
      end
    end # load(inputSrc)

    def store(outputDest, doGzip=false)
      unless(outputDest.kind_of?(String))
        raise(TypeError, "BRL::Util::PropTable#store(outputDest) requires a String that is the path to the output file and optionally a boolean doGzip flag whose default is false");
      end
      writer = BRL::Util::TextWriter.new(outputDest, doGzip)
      self.each { |key, val|
        writer.write("#{key} = #{val}\n")
      }
      writer.close
    end # store(outputDest)

    def verify(propStringArray)
      unless(propStringArray.kind_of?(Array))
        raise(TypeError, "BRL::Util::PropTable#verify(propStringArray) requires an array of Strings to check against")
      end
      propStringArray.each { |elem|
        unless(self.key?(elem) and self[elem] !~ /^\s*$/)
          raise(BRL::Util::MissingKeyError, "A required key (#{elem}) is missing in the properties file/string")
        end
      }
    end

    # ##########################################################################
    protected # PROTECTED METHODS
    # ##########################################################################
    def parseLine(line)
      propName, valueStr = nil
      return if(line =~ /^\s*#/) # skip comment lines
      return if(line =~ /^\s*$/) # skip blank lines
      # Isolate the name and the value
      if(line =~ /^\s*(\S+)\s*=\s*(.+)$/)
        propName = $1.strip
        valueStr = $2.strip
        # Is the valueStr quoted? If so, extract what is inside as literal value
        if(valueStr =~ /^(?:(?:\"([^\n\r\"]*)\")|(?:\'([^\n\r\']*)\'))$/)
          if(!$1.nil? and !$1.empty?) # then double-quoted string
            valueArray = [$1]
          elsif(!$2.nil? and !$2.empty?) # then single-quoted string
            valueArray = [$2]
          else
            valueArray = [ '' ]
          end
        else # not quoted. Attempt to split by commas
          valueArray = (@splitCSV ? valueStr.split(/\s*,\s*/) : [ valueStr ])
        end
        self[propName] = (valueArray.length == 1 ? valueArray[0] : valueArray)
      else
        raise BRL::Util::ParseError
      end
      #ARJ
      #$stderr.puts "Got this from prop file: '#{propName}' = '#{self[propName]}'"
    end


  end # class TextReader

end ; end # module BRL ; module Util

if(__FILE__ == $0)
  # ##############################################################################
  # TEST DRIVER (run this file on its own)
  # ##############################################################################
  module TestPropTable
    require 'getoptlong'

    def TestPropTable.processArguments
      progOpts =
        GetoptLong.new(
          ['--fileToRead', '-i', GetoptLong::REQUIRED_ARGUMENT],
          ['--fileToWrite', '-o', GetoptLong::REQUIRED_ARGUMENT],
          ['--help', '-h', GetoptLong::NO_ARGUMENT]
        )

      optsHash = progOpts.to_hash
      return optsHash
    end

    def TestPropTable.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:

  COMMAND LINE ARGUMENTS:
    -i    => Location of the input properties file (plain or gzipped text)
    -o    => Location of output properties file

  USAGE:
    propTable.rb -i ./myTestFile.txt.maybeGZ.maybeNot -o ./myTestOutput

  ";
      exit(2);
    end
  end # module TestPropTable

  optsHash = TestPropTable.processArguments()
  if(optsHash.key?('--help') or optsHash.empty?())
    TestPropTable.usage()
  end

  # Empty proptable
  puts "--Empty PropTable--"
  emptyPT = BRL::Util::PropTable.new()
  puts ""
  puts "Is emptyPT empty? #{emptyPT.empty?()}"
  puts "What is splitCSV set to for emptyPT? #{emptyPT.splitCSV}"
  puts "Value of splitCSV after set to false for empty PT? #{emptyPT.splitCSV=false ; emptyPT.splitCSV}"

  # Proptable from a String
  puts('-' * 60)
  puts "--From OK String--"
  propStr = <<-'DONE'
    myStrProperty = aString
    myQuotedStrProperty             = "a quoted String"
    myQuotedStr2Property =                 'a quoted String2'
    myInteger = 12
    myFloat=3.2
    myArray = one,two,three
    myArray2 = "four,five, six "
  DONE
  propKeyArray = ['myStrProperty', 'myQuotedStrProperty', 'myQuotedStr2Property', 'myInteger', 'myFloat', 'myArray', 'myArray2']
  puts "PropStr to process:\n#{propStr}\n"
  stringPT = BRL::Util::PropTable.new(propStr)
  puts "stringPT contents:\n#{stringPT.inspect}\n"
  begin
    stringPT.verify(propKeyArray)
  rescue BRL::Util::MissingKeyError => err
    puts "EXCEPTION CAUGHT: #{err}"
  end

  # Proptable from string where don't want to split CSV's
  puts('-' * 60)
  puts "--From OK String, no split CSV--"
  propStr = <<-'DONE'
    myStrProperty = aString
    myQuotedStrProperty             = "a quoted String"
    myQuotedStr2Property =                 'a quoted String2'
    myInteger = 12
    myFloat=3.2
    myArray = one,two,three
    myArray2 = "four,five, six "
    DONE
  propKeyArray = ['myStrProperty', 'myQuotedStrProperty', 'myQuotedStr2Property', 'myInteger', 'myFloat', 'myArray', 'myArray2']
  puts "PropStr to process:\n#{propStr}\n"
  stringPT = BRL::Util::PropTable.new(propStr, false)
  puts "stringPT contents:\n#{stringPT.inspect}\n"
  begin
    stringPT.verify(propKeyArray)
  rescue BRL::Util::MissingKeyError => err
    puts "EXCEPTION CAUGHT: #{err}"
  end

  # Proptable from a badly formatted string
  puts('-' * 60)
  puts "--From BAD String--"
  begin
    propStr = <<-'DONE'
      myStrProperty = aString
      myQuotedStrProperty             = "a quoted String"
      myQuotedStr2Property =                 'a quoted String2'
      myInteger
      myFloat=3.2
      myArray = one,two,three
      myArray2 = "four,five, six "
      DONE
    propKeyArray = ['myStrProperty', 'myQuotedStrProperty', 'myQuotedStr2Property', 'myInteger', 'myFloat', 'myArray', 'myArray2']
    puts "PropStr to process:\n#{propStr}\n"
    stringPT = BRL::Util::PropTable.new(propStr)
    puts "stringPT contents:\n#{stringPT.inspect}\n"
    stringPT.verify(propKeyArray)
  rescue BRL::Util::MissingKeyError, BRL::Util::ParseError => err
    puts "EXCEPTION CAUGHT: #{err}"
  end

  # Proptable from a string with a missing key
  puts('-' * 60)
  puts "--From MISSING KEY String--"
  begin
    propStr = <<-'DONE'
      myStrProperty = aString
      myQuotedStrProperty             = "a quoted String"
      myQuotedStr2Property =                 'a quoted String2'
      myFloat=3.2
      myArray = one,two,three
      myArray2 = "four,five, six "
      DONE
    propKeyArray = ['myStrProperty', 'myQuotedStrProperty', 'myQuotedStr2Property', 'myInteger', 'myFloat', 'myArray', 'myArray2']
    puts "PropStr to process:\n#{propStr}\n"
    stringPT = BRL::Util::PropTable.new(propStr)
    puts "stringPT contents:\n#{stringPT.inspect}\n"
    stringPT.verify(propKeyArray)
  rescue BRL::Util::MissingKeyError, BRL::Util::ParseError => err
    puts "EXCEPTION CAUGHT: #{err}"
  end

  # PropTable from provided IO object
  puts('-' * 60)
  puts "--From IO object--"
  inIO = File.open(optsHash['--fileToRead']);
  propKeyArray = ['myStrProperty', 'myQuotedStrProperty', 'myQuotedStr2Property', 'myInteger', 'myFloat', 'myArray', 'myArray2']
  puts "PropStr to process:\n#{propStr}\n"
  ioPT = BRL::Util::PropTable.new(inIO)
  puts "stringPT contents:\n#{ioPT.inspect}\n"
  begin
    ioPT.verify(propKeyArray)
  rescue BRL::Util::MissingKeyError, BRL::Util::ParseError  => err
    puts "EXCEPTION CAUGHT: #{err}"
  ensure
    inIO.close() unless(inIO.closed?)
  end

  # PropTable from provided TextFileReader object
  puts('-' * 60)
  puts "--From TextFileReader object--"
  reader = BRL::Util::TextReader.new(optsHash['--fileToRead']);
  propKeyArray = ['myStrProperty', 'myQuotedStrProperty', 'myQuotedStr2Property', 'myInteger', 'myFloat', 'myArray', 'myArray2']
  puts "PropStr to process:\n#{propStr}\n"
  readerPT = BRL::Util::PropTable.new(reader)
  puts "stringPT contents:\n#{readerPT.inspect}\n"
  begin
    readerPT.verify(propKeyArray)
  rescue BRL::Util::MissingKeyError, BRL::Util::ParseError  => err
    puts "EXCEPTION CAUGHT: #{err}"
  ensure
    reader.close() unless(reader.closed?)
  end

  # Proptable from a Hash
  puts('-' * 60)
  puts "--From a Hash--"
  begin
    propHash = {
      'myStrProperty' => 'aString',
      'myQuotedStrProperty' => "a quoted String",
      'myQuotedStr2Property' => "'a quoted String2'",
      'myInteger' => 1,
      'myFloat' => 3.2,
      'myArray' => "one,two,three",
      'myArray2' => "four,five, six "
    }
    propKeyArray = ['myStrProperty', 'myQuotedStrProperty', 'myQuotedStr2Property', 'myInteger', 'myFloat', 'myArray', 'myArray2']
    puts "PropHash to process:\n#{propHash.inspect}\n"
    hashPT = BRL::Util::PropTable.new(propHash)
    puts "stringPT contents:\n#{hashPT.inspect}\n"
    hashPT.verify(propKeyArray)
  rescue BRL::Util::MissingKeyError, BRL::Util::ParseError => err
    puts "EXCEPTION CAUGHT: #{err}"
  end

  # Save propTable to disk
  puts('-' * 60)
  puts "--Save plain and gzipped--"
  hashPT.store(optsHash['--fileToWrite'])
  hashPT.store("#{optsHash['--fileToWrite']}.gz", true);
end # if(__FILE__ == $0)
