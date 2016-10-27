#!/usr/bin/env ruby

# ##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
# ##############################################################################
require 'rubygems'
require 'rein'
require 'interval'
require 'fileutils'
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
module BRL ; module Genboree ; module ToolPlugins ; module Tools ; module GeneModelGeneratorTool


    # ##############################################################################
    # HELPER CLASSES
    # ##############################################################################
    

    
    class GenerateGeneModel
        attr_accessor :lffInFile, :lffHash, :lffFileResult, :lffArray, :lffHashWithResults, :verboseOn
        attr_accessor :lffType, :lffSubType, :lffClass
 
        # Required: the "new()" equivalent
        def initialize( lffFileIn, outPutClass="02. Unified Gene Model", outPutType="gene", 
			outPutSubType="Model", nameOfOutputFile="#{lffFileIn}.out", verbose=false)
            @lffFile = lffFileIn
            @verboseOn = verbose
            @lffHash = Hash.new {|hh, kk| hh[kk] = []}
            @lffHashWithResults = Hash.new {|hh, kk| hh[kk] = []}
            @lffFileResult = nameOfOutputFile
            @lffClass = outPutClass
            @lffType = outPutType
            @lffSubType = outPutSubType
            @lffArray = []
        end
        
        def generateGeneModel()
            removeRedundantByChr()
            cpyHashToArray()
            removeSmallExons()
            cleanNames()
            changeClassName()
            changeTrackName()
            writeResults()
        end
        
        def removeRedundantByChr()
            # Make LFFHash object (just 1) used during rule testing. Reuse will avoid
            # overheado f making 1 object per line.
            # Go through lines of lff file
            reader = BRL::Util::TextReader.new(@lffFile)
            reader.each { |line|
                line.strip!
                lffArray = line.split(/\t/)
                # Skip blanks, headers, comments
                next if(line !~ /\S/ or line =~ /^\s*\[/ or line =~ /^\s*#/ or lffArray.length < 10)
                # If passes rule set, update track/class and output

                chrom = lffArray[4]
                start = lffArray[5].to_i
                stop = lffArray[6].to_i
                if(start > stop)
                    start, stop = stop, start
                end
                key = "#{chrom}_#{start}_#{stop}"
                key.gsub!(/\s/, "")
                @lffHash[key] = lffArray 
            }
            # Close lff file
            reader.close()
        end
        
        def cpyHashToArray()
            @lffHash.each_key {|arec|
                @lffArray.push(@lffHash[arec])
            }
        end
        
        def removeSmallExons()
            @lffArray.each_index { |ii| 
                currChr=@lffArray[ii][4];
                currRange=(@lffArray[ii][5]..@lffArray[ii][6]);
                isContained=false;
                @lffArray.each_index { |jj| 
                    next if(jj==ii or @lffArray[jj][4] != currChr); 
                    testRange = (@lffArray[jj][5]..@lffArray[jj][6]); 
                    break if(isContained = testRange.containsRange?(currRange))
                }
                @lffHashWithResults[ii] = @lffArray[ii] unless(isContained); # print no contained unique
	    }
        end
          
        def writeResults()
            fileWriter = BRL::Util::TextWriter.new(@lffFileResult)
            @lffHashWithResults.each_key {|arec|
                fileWriter.puts @lffHashWithResults[arec].join("\t")
            }
            fileWriter.close()
            return BRL::Genboree::OK
        end  

        def cleanNames()
            @lffHashWithResults.each_key {|arec|
                @lffHashWithResults[arec][1] = @lffHashWithResults[arec][1].upcase.strip().upcase.gsub(/\.\d+$/, "").strip()
            }
        end
        
        def changeClassName()
            @lffHashWithResults.each_key {|arec|
                @lffHashWithResults[arec][0] = @lffClass
            }
        end
        
        def changeTrackName()
            @lffHashWithResults.each_key {|arec|
                @lffHashWithResults[arec][2] = @lffType
                @lffHashWithResults[arec][3] = @lffSubType
            }
        end

    end
        
    # ##############################################################################
    # EXECUTION CLASS
    # ##############################################################################
    
    class GeneModelGenerator
        
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
            @lffFileResult = optsHash['--nameOfOutputFile'].strip
            @outputType = optsHash.key?('--outputSubtype') ? optsHash['--outputType'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'") : "gene"
            @outputSubtype = optsHash.key?('--outputSubtype') ? optsHash['--outputSubtype'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'") : "Models"
            @outputClass = optsHash.key?('--outputClass') ? optsHash['--outputClass'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'") : "02. Unified Gene Model"
            @verboseOn = optsHash.has_key?('--verbose')  
            puts "the @lffInFile = #{@lffInFile}\nand the @verboseOn = #{@verboseOn}" if(@verboseOn)
        end
                
        # ---------------------------------------------------------------
        # MAIN EXECUTION METHOD
        # - instance method called to "do the tool"
        # ---------------------------------------------------------------
        # Applies rules to each record in LFF file and outputs LFF record accordingly.
        
        def execute()
            runner = GenerateGeneModel.new(@lffInFile, @outputClass, @outputType, @outputSubtype, @lffFileResult, @verboseOn)
            runner.generateGeneModel()
        end
        
        # ---------------------------------------------------------------
        # CLASS METHODS
        # - generally just 2 (arg processor and usage)
        # ---------------------------------------------------------------
        # Process command-line args using POSIX standard
        def GeneModelGenerator.processArguments(outs)
            # We want to add all the prop_keys as potential command line options
            optsArray = [
                          ['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                          ['--nameOfOutputFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
                          ['--outputType', '-t', GetoptLong::REQUIRED_ARGUMENT],
                          ['--outputSubtype', '-u', GetoptLong::REQUIRED_ARGUMENT],
                          ['--outputClass', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                          ['--verbose', '-V', GetoptLong::NO_ARGUMENT],
                          ['--help', '-h', GetoptLong::NO_ARGUMENT]
            ]
            progOpts = GetoptLong.new(*optsArray)
            optsHash = progOpts.to_hash
            outs[:verbose] = true if(optsHash and optsHash.key?('--verbose'))
            outs[:optsHash] = optsHash
            unless(progOpts.getMissingOptions().empty?)
                @@usageError = true
                GeneModelGenerator.usage("USAGE ERROR: some required arguments are missing") 
            end
            
            if(optsHash.empty? or optsHash.key?('--help'))
                GeneModelGenerator.usage()
            end
            return optsHash
        end
            
            # Display usage info and quit.
        def GeneModelGenerator.usage(msg='')
            unless(msg.empty?)
                puts "\n#{msg}\n"
            end
                puts "
            
                    PROGRAM DESCRIPTION:
                    
                    GeneModelGenerator generate a gene model from several transcripts      
                    COMMAND LINE ARGUMENTS:
                          --lffFile         | -f  => Source LFF file.
                          --nameOfOutputFile    | -o  =>  Name of output file
                          --outputType      | -t  => The output track's 'gene'.
                          --outputSubtype   | -u  => The output track's 'Models'.
                          --outputClass     | -c  => [Optional] The output track's 'class'.
                                                     Defaults to '02. Unified Gene Model'.
                          --verbose         | -V  => [Optional] Prints more error info (trace)
                                                and such when error. Mainly for Genboree.
                          --help            | -h  => [Optional flag]. Print help info and exit.
                    
                    USAGE:
                    geneModelGenerator.rb -f myLFF.lff -o outputFile -t type -u subtype [-c genboree's class]
                    ";
            exit(BRL::Genboree::USAGE_ERR);
        end # def GeneModelGenerator.usage(msg='')
    
    end # class GeneModelGenerator
end ; end ; end ; end ; end
    
# ##############################################################################
# MAIN
# ##############################################################################
include BRL::Genboree::ToolPlugins::Tools::GeneModelGeneratorTool

begin
  # Get arguments hash
  outs = { :optsHash => nil, :verbose => false }
  optsHash = GeneModelGenerator.processArguments(outs)
  $stderr.puts "#{Time.now()} GENE_MODEL_GENERATOR - STARTING" if(outs[:verbose])
  initialLffFile = nil
  # Instantiate method
  optsHash.each { | thekey, thevalue |
      puts "the key #{thekey} --> with a value of #{thevalue}" if(outs[:verbose])
  }

  geneModelGenerator =  GeneModelGenerator.new(optsHash)
  $stderr.puts "#{Time.now()} geneModelGenerator - INITIALIZED" if(outs[:verbose])
  exitVal = geneModelGenerator.execute()
  $stderr.puts "#{Time.now()} geneModelGenerator - FINISHED" if(outs[:verbose])

  $stderr.puts "#{Time.now()} Finishing the process" if(outs[:verbose])
  rescue Exception => err # Standard capture-log-report handling:
      errTitle =  "#{Time.now()} GENE MODEL GENERATOR - FATAL ERROR: The liftover exited without processing all the data,
                  due to a fatal error.\n"
      msgTitle =  "FATAL ERROR: The gene model generator exited without processing all the data, due to a fatal error.\n
                  Please contact the Genboree admin. This error has been dated and logged.\n"
      errstr   =  "   The error message was: '#{err.message}'.\n"
      errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
      puts msgTitle unless(!outs[:optsHash].nil? or outs[:optsHash].key?('--help'))
      $stderr.puts(errTitle + errstr) if(outs[:verbose])
      exitVal = BRL::Genboree::FATAL
  end
  $stderr.puts "#{Time.now()} GENE MODEL GENERATOR - DONE" if(exitVal == 0 and outs[:verbose])
  exit(exitVal)
