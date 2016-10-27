#!/usr/bin/env ruby

        # ##############################################################################
        # LIBRARIES
        # - The first 3 are standard for all apps.
        # ##############################################################################
        require 'rubygems'
        require 'rein'
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
    module BRL ; module Genboree ; module ToolPlugins ; module Tools ; module CodingRegionExtractorTool



            # ##############################################################################
            # HELPER CLASSES
            # ##############################################################################
           class CodingRegionExtractor
                   attr_accessor :lffFile, :lffHash, :verboseOn
                   attr_accessor :lffType, :lffSubType, :lffClass, :lffOutPutFile
 
                # Required: the "new()" equivalent
                def initialize( lffFileIn, outPutType="coding", outPutSubType="Exons", outPutClass="03. Coding exons", nameOfOutputFile="#{lffFileIn}.out",verbose=false)
                    @lffFile = lffFileIn
                    @lffOutPutFile = nameOfOutputFile
                    @verboseOn = verbose
                    @lffHash = Hash.new {|hh, kk| hh[kk] = []}
                    @lffClass = outPutClass
                    @lffType = outPutType
                    @lffSubType = outPutSubType
                end
           
                def run()
                #    $stderr.puts "\nlffFile = #{@lffFile},\n outputFile = #{@lffOutPutFile},\n" +
                #    "class = #{@lffClass},\ntype = #{@lffType},\nsubtype = #{@lffSubType}\n"
                #    return 1
                #end
                #
                #def generateCoding()
                    extractCodingRegions()
                    changeClassName()
                    changeTrackName()
                    writeCodingResults()
                end
                
                def extractCodingRegions()
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

                        cdsStart = cdsEnd = -1
                        chrom = lffArray[4]
                        lffArray[5] = lffArray[5].to_i
                        lffArray[6] = lffArray[6].to_i
                        if(lffArray[5] > lffArray[6])
                            lffArray[5], lffArray[6] = lffArray[6], lffArray[5]
                        end

                        lffArray[12] =~ /cdsStart=(\d+)/
                        cdsStart = $1.to_i
                        lffArray[12] =~ /cdsEnd=(\d+)/
                        cdsEnd = $1.to_i
                        
                        cdsEnd, cdsStart = cdsStart, cdsEnd if(cdsEnd < cdsStart)

                        next if(cdsStart < 0 || cdsEnd < 0)
                        
                        exonRange = lffArray[5] .. lffArray[6]
    
                        if(lffArray[5] < cdsStart and lffArray[6] < cdsStart) # then exon before cdsStart
                          next
                        elsif(exonRange.include?(cdsStart)) #then exon contains cdsStart
                          lffArray[5] = cdsStart
                        end
                    
                        if(lffArray[5] > cdsEnd and lffArray[6] > cdsEnd) # then exon after cdsEnd
                          next
                        elsif(exonRange.include?(cdsEnd)) # then exon contains cdsEnd
                          lffArray[6] = cdsEnd
                        end
                        
                        key = "#{lffArray[1]}_#{chrom}_#{lffArray[5]}_#{lffArray[6]}_#{lffArray[7]}"
                        
                        key.gsub!(/\s/, "")
                        @lffHash[key] = lffArray

                    }
                    # Close lff file
                    reader.close()
                end
                
                def writeCodingResults()
                    fileWriter = BRL::Util::TextWriter.new(@lffOutPutFile)
                    @lffHash.each_key {|arec|
                        fileWriter.puts @lffHash[arec].join("\t")
                    }
                    fileWriter.close()
                    return BRL::Genboree::OK
                end  
                
                def changeClassName()
                    @lffHash.each_key {|arec|
                        @lffHash[arec][0] = @lffClass
                    }
                end
                
                def changeTrackName()
                    @lffHash.each_key {|arec|
                        @lffHash[arec][2] = @lffType
                        @lffHash[arec][3] = @lffSubType
                    }
                end
               
               
               
               
               
               
           end
          
       
       
        # ##############################################################################
        # EXECUTION CLASS
        # ##############################################################################

        class Coding
            attr_accessor :optsHash, :lffInFile, :outputType, :outputSubtype, :outputClass, :nameOfOutputFile, :verbose 
            # Required: the "new()" equivalent
            def initialize(optsHash=nil)
                @optsHash = optsHash
               self.config() unless(optsHash.nil?)
            end

            # ---------------------------------------------------------------
            # HELPER METHODS
            # - set up, do specific parts of the tool, etc
            # ---------------------------------------------------------------

            # Method to handle tool configuration/validation
            def config()
                @lffInFile = @optsHash['--lffFile'].strip
                @outputType = @optsHash['--outputType'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'")
                @outputSubtype = @optsHash['--outputSubtype'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'")
                @outputClass = @optsHash.key?('--outputClass') ? optsHash['--outputClass'].gsub(/\\/,'').gsub(/\\,/, ',').gsub(/\\"/, "'")  : 'Selected' 
                @nameOfOutputFile = @optsHash['--nameOfOutputFile'].strip
                @verbose = @optsHash.has_key?('--verbose')
                    
                puts "the @lffInFile = #{@lffInFile}\nthe @outputType = #{@outputType}\n" +
                "the @outputSubtype = #{@outputSubtype}\nthe @nameOfOutputFile = #{@nameOfOutputFile}\n" +
                "and the @verbose = #{@verbose}" if(@verbose)
            end

            def validFiles()
                    
                unless(File.exist?(@lffInFile))
                    puts "\n\nERROR: cannot find lff file \"#{@lffInFile}\""
                    return false
                else
                    puts "\n\nPass the lfffile" if(@verbose)
                    initialLffFile = @lffInFile
                end
                
                return true
            end
  
  

            # ---------------------------------------------------------------
            # MAIN EXECUTION METHOD
            # - instance method called to "do the tool"
            # ---------------------------------------------------------------
            # Applies rules to each record in LFF file and outputs LFF record accordingly.

            def execute()
                exitVal = 1
                   
                unless(validFiles())
                    $stderr.puts "Error lff file not found, try using full path"  
                    return false 
                end


                runner = CodingRegionExtractor.new(@lffInFile, @outputType, @outputSubtype, @outputClass, @nameOfOutputFile, @verbose)
                exitVal = runner.run()
            
                return exitVal
                    
            end
 
 
            # ---------------------------------------------------------------
            # CLASS METHODS
            # - generally just 2 (arg processor and usage)
            # ---------------------------------------------------------------
            # Process command-line args using POSIX standard
            def Coding.processArguments(outs)
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
                    Coding.usage("USAGE ERROR: some required arguments are missing") 
                end
                if(optsHash.empty? or optsHash.key?('--help'))
                    Coding.usage()
                end
                return optsHash
            end
            

            # Display usage info and quit.
            def Coding.usage(msg='')
                unless(msg.empty?)
                    puts "\n#{msg}\n"
                end
                puts "

                PROGRAM DESCRIPTION:

                CodingRegionExtractor.rb generate coding sequence for a set of genes from refseq
                COMMAND LINE ARGUMENTS:
                --lffFile             | -f  => Source LFF file.
                --nameOfOutputFile    | -o  =>  Name of output file
                --outputType      | -t  => The output track's 'type'.
                --outputSubtype   | -u  => The output track's 'subtype'.
                --outputClass     | -c  => [Optional] The output track's 'class'.
                                 Defaults to 'Selected'.
                --verbose             | -V  => [Optional] Prints more error info (trace)
                    and such when error. Mainly for Genboree.
                --help                | -h  => [Optional flag]. Print help info and exit.

                USAGE:
                codingRegionExtractor.rb -f myLFF.lff -o outputFile -t type -u subtype [-c genboree's class] 
                ";
                exit(BRL::Genboree::USAGE_ERR);
            end # def Coding.usage(msg='')
        end # class Coding
    end ; end ; end ; end ; end #Modules
    
    

    
    # ##############################################################################
    # MAIN
    # ##############################################################################

include BRL::Genboree::ToolPlugins::Tools::CodingRegionExtractorTool


begin
  # Get arguments hash
  outs = { :optsHash => nil, :verbose => false }
        optsHash = Coding.processArguments(outs)
        $stderr.puts "#{Time.now()} Coding - STARTING" if(outs[:verbose])
        initialLffFile = nil
        # Instantiate method
        optsHash.each { | thekey, thevalue |
            puts "the key #{thekey} --> with a value of #{thevalue}" if(outs[:verbose])
        }
        $stderr.puts "#{Time.now()} Coding - INITIALIZED" if(outs[:verbose])
        extractCoding =  Coding.new(optsHash)
        exitVal =  extractCoding.execute()

        $stderr.puts "#{Time.now()} Coding - FINISHED" if(outs[:verbose])
        $stderr.puts "#{Time.now()} Finishing the process" if(outs[:verbose])
rescue Exception => err # Standard capture-log-report handling:
  errTitle =  "#{Time.now()} CodingRegion - FATAL ERROR: The codingRegion exited without processing all the data, due to a fatal error.\n"
      msgTitle =  "FATAL ERROR: The coding region program exited without processing all the data, due to a fatal error.\n
                  Please contact the Genboree admin. This error has been dated and logged.\n"
      errstr   =  "   The error message was: '#{err.message}'.\n"
      errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
      puts msgTitle unless(!outs[:optsHash].nil? or outs[:optsHash].key?('--help'))
  $stderr.puts(errTitle + errstr) if(outs[:verbose])
  exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} Coding Region Extractor - DONE" if(exitVal == 0 and outs[:verbose])
exit(exitVal)
