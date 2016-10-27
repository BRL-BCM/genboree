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
    module BRL ; module Genboree ; module ToolPlugins ; module Tools ; module TemplateWrapperTool

    # ##############################################################################
    # HELPER CLASSES
    # ##############################################################################
   class TemplateWrapper
           attr_accessor :lffFile, :lffHash, :verboseOn
           attr_accessor :lffType, :lffSubType, :lffClass, :lffOutPutFile

        # Required: the "new()" equivalent
        def initialize( lffFileIn, outPutType="sample", outPutSubType="Exons", outPutClass="03. Wrapper exons", nameOfOutputFile="#{lffFileIn}.out",verbose=false)
            @lffFile = lffFileIn
            @lffOutPutFile = nameOfOutputFile
            @verboseOn = verbose
            @lffHash = Hash.new {|hh, kk| hh[kk] = []}
            @lffClass = outPutClass
            @lffType = outPutType
            @lffSubType = outPutSubType
        end
   
        def run()
            $stderr.puts "\nlffFile = #{@lffFile},\n outputFile = #{@lffOutPutFile},\n" +
            "class = #{@lffClass},\ntype = #{@lffType},\nsubtype = #{@lffSubType}\n"
            return 1
        end
       
   end
  


# ##############################################################################
# EXECUTION CLASS
# ##############################################################################

    class Wrapper
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
    
            runner = TemplateWrapper.new(@lffInFile, @outputType, @outputSubtype, @outputClass, @nameOfOutputFile, @verbose)
            exitVal = runner.run()
        
            return exitVal 
        end

 
        # ---------------------------------------------------------------
        # CLASS METHODS
        # - generally just 2 (arg processor and usage)
        # ---------------------------------------------------------------
        # Process command-line args using POSIX standard
        def Wrapper.processArguments(outs)
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
                Wrapper.usage("USAGE ERROR: some required arguments are missing") 
            end
            if(optsHash.empty? or optsHash.key?('--help'))
                Wrapper.usage()
            end
            return optsHash
        end
        

        # Display usage info and quit.
        def Wrapper.usage(msg='')
            unless(msg.empty?)
                puts "\n#{msg}\n"
            end
            puts "

            PROGRAM DESCRIPTION:

            TemplateWrapper.rb < write some description of what your program is trying to do >
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
            TemplateWrapper.rb -f myLFF.lff -o outputFile -t type -u subtype [-c genboree's class] 
            ";
            exit(BRL::Genboree::USAGE_ERR);
        end # def Wrapper.usage(msg='')
    end # class Wrapper
    end ; end ; end ; end ; end #Modules
    
    

    
    # ##############################################################################
    # MAIN
    # ##############################################################################

include BRL::Genboree::ToolPlugins::Tools::TemplateWrapperTool


begin
  # Get arguments hash
    outs = { :optsHash => nil, :verbose => false }
    optsHash = Wrapper.processArguments(outs)
    $stderr.puts "#{Time.now()} Wrapper - STARTING" if(outs[:verbose])
    initialLffFile = nil
    # Instantiate method
    optsHash.each { | thekey, thevalue |
        puts "the key #{thekey} --> with a value of #{thevalue}" if(outs[:verbose])
    }
    $stderr.puts "#{Time.now()} Wrapper - INITIALIZED" if(outs[:verbose])
    extractWrapper =  Wrapper.new(optsHash)
    exitVal =  extractWrapper.execute()

    $stderr.puts "#{Time.now()} Wrapper - FINISHED" if(outs[:verbose])
    $stderr.puts "#{Time.now()} Finishing the process" if(outs[:verbose])
rescue Exception => err # Standard capture-log-report handling:
    errTitle =  "#{Time.now()} WrapperRegion - FATAL ERROR: The <TemplateName program > exited without processing all the data, due to a fatal error.\n"
    msgTitle =  "FATAL ERROR: The <Template program> exited without processing all the data, due to a fatal error.\n
                Please contact the Genboree admin. This error has been dated and logged.\n"
    errstr   =  "   The error message was: '#{err.message}'.\n"
    errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
    puts msgTitle unless(!outs[:optsHash].nil? or outs[:optsHash].key?('--help'))
    $stderr.puts(errTitle + errstr) if(outs[:verbose])
    exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} Wrapper - DONE" if(exitVal == 0 and outs[:verbose])
exit(exitVal)
