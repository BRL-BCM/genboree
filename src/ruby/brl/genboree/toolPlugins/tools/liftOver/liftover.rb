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
        module BRL ; module Genboree ; module ToolPlugins ; module Tools ; module LiftOverTool


            # ##############################################################################
            # HELPER CLASSES
            # ##############################################################################
                                 
          class Concatenatefiles
              # Accessors (getters/setters ; instance variables
              attr_accessor :dirName, :subfixPattern, :targetFileName
              
               def initialize(directoryName, subFix, finalFileName)
                    @dirName = directoryName
                    @subfixPattern = subFix
                    @targetFileName = finalFileName
               end
              
              def concatFiles
                     resultFiles =  Dir[ "#{@dirName}/*#{@subfixPattern}" ]
                     temp_counter = 0
                     cmdOK = 1
                     resultFiles.each { | resultF |
	                 temp_counter = temp_counter + 1
	                 catCmd="cat #{resultF} >> #{@targetFileName}"
	                 cmdOK = system( catCmd )
                    }
                    return cmdOK
              end 
              
          end


          class LffSplit
                MAXFILESIZE = 200000
#                MAXFILESIZE = 1000
                # Accessors (getters/setters ; instance variables
                attr_accessor :lffFile, :lffOut, :maxNumberOfRecords, :verbose

                # Required: the "new()" equivalent
                def initialize(lffFileIn, lffOut, verbose=false, maxLines=MAXFILESIZE)
                    @lffFile = lffFileIn
                    @lffOut = lffOut
                    @maxNumberOfRecords = maxLines
                    @verbose = verbose
                end
                
                def getNumberLinesInFile()
                    retValue = 0
                    reader = BRL::Util::TextReader.new(@lffFile)

                    reader.each { |line|
                        lffArray = line.split(/\t/)
                        next if(line !~ /\S/ or line=~ /^\s*\[/ or line =~ /^\s*#/ or lffArray.length < 10)
                        retValue = retValue + 1
                    }
                    return retValue
                end

                def createFolderWithSmallerFiles ()
                    myNewDir = "#{File.dirname(@lffOut)}/#{File.basename(@lffOut)}_tempSplit#{rand(1000)}"
                    Dir::mkdir(myNewDir)
                    $stderr.puts "the new directory is #{myNewDir}"
                    reader = BRL::Util::TextReader.new(@lffFile)
                    counter = 0
                    fileCounter= 0
                    baseName= File.basename(@lffOut)
                    newFileName = "#{myNewDir}/#{baseName}_#{fileCounter}.lff"
                    fileWriter = BRL::Util::TextWriter.new(newFileName)
                    fileCounter = fileCounter + 1
                    aWritterInUse = true
                    reader.each { |line|
                        lffArray = line.split(/\t/)
                        next if(line !~ /\S/ or line =~ /^\s*\[/ or line =~ /^\s*#/ or lffArray.length < 10)
                        if(counter >= @maxNumberOfRecords)
                            fileWriter.close()
                            aWritterInUse = false
                            $stderr.puts "Inside the if counter = #{counter} >= #{@maxNumberOfRecords}" if(@verbose) # for logging aWritterInUse = false
                            counter = 0
                        end

                        if(!aWritterInUse)
                            newFileName = "#{myNewDir}/#{baseName}_#{fileCounter}.lff"
                            fileWriter = BRL::Util::TextWriter.new(newFileName)
                            fileCounter = fileCounter + 1
                            aWritterInUse = true
                        end
                        
                        fileWriter.puts line
                        counter = counter + 1
                    }
                    fileWriter.close() if(aWritterInUse)
                    reader.close()
                    return myNewDir
                end
                

            def splitFile()
                return nil if(getNumberLinesInFile() < @maxNumberOfRecords)
                dirName = createFolderWithSmallerFiles()
                return dirName
            end
                
                
           end # class SplitLffRecords

          class LiftOverAFile
                LIFTOVER_APP = "liftOver"
                EXTENSION_NAMES = [ "_results.lff", "_fail.lff", "_initial.bed", "_results.bed", "_fail.bed", "_transferErrorsfromResults.bed", "_transferErrorsfromFail.bed"]
                # Accessors (getters/setters ; instance variables
                attr_accessor :lffInFile, :chainFile, :lffHash, :bedHash, :outPutFile
                attr_accessor :bedFile, :bedFileResult, :bedFail, :lffFileResult, :lffFail
                attr_accessor :bedResultsErrors, :bedFailErrors, :liftOverCmd, :workingDir
                attr_accessor :liftOverBin, :extensionNames #Dont need accessors but just in case that I need to print them


                # Required: the "new()" equivalent
                def initialize(lffFileIn, workingDir, chainFileIn, verbose=false, liftOverBin=LIFTOVER_APP, extensionNames=EXTENSION_NAMES )
                    @lffFile = lffFileIn
                    @workingDir = workingDir
                    @chainFile = chainFileIn
                    @liftOverBin = liftOverBin
                    myBase = File.basename(@lffFile)
                    @verbose = verbose
                    @lffHash = Hash.new {|hh, kk| hh[kk] = []}
                    @bedHash =  Hash.new {|hh, kk| hh[kk] = []}
                    @extensionNames = extensionNames
                    @lffFileResult = "#{workingDir}/#{myBase}#{extensionNames[0]}"
                    @lffFail = "#{workingDir}/#{myBase}#{extensionNames[1]}"
                    @bedFile = "#{workingDir}/#{myBase}#{extensionNames[2]}"
                    @bedFileResult = "#{workingDir}/#{myBase}#{extensionNames[3]}"
                    @bedFail = "#{workingDir}/#{myBase}#{extensionNames[4]}"
	            @bedResultsErrors = "#{workingDir}/#{myBase}#{extensionNames[5]}"
	            @bedFailErrors = "#{workingDir}/#{myBase}#{extensionNames[6]}"
	            @liftOverCmd = "#{@liftOverBin} #{@bedFile} #{@chainFile} #{@bedFileResult} #{@bedFail} 2>/dev/null"
                end

                
                  def transformNoFoundBedToLff()
                    fileWriter = BRL::Util::TextWriter.new(@lffFail)
                    errorWriter = BRL::Util::TextWriter.new(@bedFailErrors)
                    reader = BRL::Util::TextReader.new(@bedFail)
                    reader.each { |line|
                        line.strip!
                        bedArray = line.split(/\t/)
		        next if(line !~ /\S/ or line =~ /^\s*\[/ or line =~ /^\s*#/ or bedArray.length < 4)
                        mykey = bedArray[3].strip
                        bedArray[1] = bedArray[1].to_i + 1

                        if(@lffHash.has_key?(mykey))
                            tt = @lffHash[mykey]
                            fileWriter.puts tt.join("\t")
                        else
                            errorWriter.puts "\n\nERROR: no record  for #{mykey}    why ?? the full info is #{line}\n"
                        end
                    }
                    # Close lff file
                    reader.close()
                    fileWriter.close()  
                    errorWriter.close()  
                end              
                
                def transformResultsBedToLff()
                    fileWriter = BRL::Util::TextWriter.new(@lffFileResult)
                    errorWriter = BRL::Util::TextWriter.new(@bedResultsErrors)
                    reader = BRL::Util::TextReader.new(@bedFileResult)
                    reader.each { |line|
                        line.strip!
                        bedArray = line.split(/\t/)
		        next if(line !~ /\S/ or line =~ /^\s*\[/ or line =~ /^\s*#/ or bedArray.length < 4)
                        mykey = bedArray[3].strip
                        bedArray[1] = bedArray[1].to_i + 1

                        if(@lffHash.has_key?(mykey))
                            tt = @lffHash[mykey]
                            tt[4] = bedArray[0]
                            tt[5] = bedArray[1]
                            tt[6] = bedArray[2]
                            fileWriter.puts tt.join("\t")
                        else
                            errorWriter.puts "\n\nERROR: no record  for #{mykey}    why ?? the full info is #{line}\n"
                        end
                    }
                    # Close lff file
                    reader.close()
                    fileWriter.close()  
                    errorWriter.close()  
                end
                                
                def liftOverLffFile()
                    # Make LFFHash object (just 1) used during rule testing. Reuse will avoid
                    # overhead of making 1 object per line.
                    # Go through lines of lff file
                    reader = BRL::Util::TextReader.new(@lffFile)
                    reader.each { |line|
                        line.strip!
                        lffArray = line.split(/\t/)
                        # Skip blanks, headers, comments
                        next if(line !~ /\S/ or line =~ /^\s*\[/ or line =~ /^\s*#/ or lffArray.length < 10)
                        # If passes rule set, update track/class and output
                        key = "#{lffArray[1]}.#{lffArray[2]}.#{lffArray[3]}.#{lffArray[4]}.#{lffArray[5]}.#{lffArray[6]}.#{lffArray[7]}.#{lffArray[9]}"
		        key.gsub!(/\s/, "")
                        chrom = lffArray[4]
                        start = lffArray[5].to_i - 1
                        stop = lffArray[6].to_i
                        if(start > stop)
                            start, stop = stop, start
                        end
                        bed = "#{chrom}\t#{start.to_s}\t#{stop.to_s}\t#{key}"
                        @lffHash[key] = lffArray 
                        @bedHash[key] = bed
                    }
                    # Close lff file
                    reader.close()
                    fileWriter = BRL::Util::TextWriter.new(@bedFile)
                    @bedHash.each_key {|abed|
                        fileWriter.puts @bedHash[abed]
                    }
                    fileWriter.close()
                    
                    $stderr.puts "#{Time.now} Starting the liftover app  command = :\n    #{@liftOverCmd}\n"  if(@verbose) # for logging
                    # Run command
                    cmdOK = system( @liftOverCmd )
                    $stderr.puts "#{Time.now} After the liftover app  the exit cmd = #{cmdOK}\n" if(@verbose) # for logging
                    transformResultsBedToLff()
                    transformNoFoundBedToLff()

                    return BRL::Genboree::OK
                end

                
                
          end



          class RunLiftover
                EXTENSION_NAMES = [ "_results.lff", "_fail.lff", "_initial.bed", "_results.bed", "_fail.bed", "_transferErrorsfromResults.bed", "_transferErrorsfromFail.bed"]
               # Accessors (getters/setters ; instance variables
                attr_accessor :keepExtraFiles, :dirName, :lffFile, :chainFile, :verbose, :nameOfOutputFile, :workingDir
                
                # Required: the "new()" equivalent
                def initialize(lffFileIn, chainFile, outputFile, keep=false, verbose=false)
                    @lffFile = lffFileIn
                    @chainFile = chainFile
                    @verbose = verbose
                    @nameOfOutputFile = outputFile
                    @keepExtraFiles = keep
                end
                
                def run()
                    @workingDir = File.dirname(@nameOfOutputFile)
                    exitVal = 1
                    splitter = LffSplit.new(@lffFile, @nameOfOutputFile)
                    @dirName = splitter.splitFile()
                    $stderr.puts "the dirName is #{@dirName}" if(@verbose)
                    unless(@dirName.nil?)
                        filesToProces = Dir[ "#{@dirName}/*.lff" ]
                    else
                        filesToProces = Array.new(1)
                        filesToProces[0] = @lffFile
                    end

                    $stderr.puts "#{Time.now()} After splitting files #{@lffFile} directory = #{@dirName}" if(@verbose)
            
                    # Execute tool
                    
                    filesToProces.each { |currentFile|
                        $stderr.puts "The new file is #{currentFile}" if(@verbose)
                        if(@dirName.nil?)
                            runner = LiftOverAFile.new(currentFile, @workingDir, @chainFile, @verbose)  
                        else  
                            runner = LiftOverAFile.new(currentFile, @dirName, @chainFile, @verbose)
                      end  
                        exitVal = runner.liftOverLffFile()
                    }
                    
                    unless(@dirName.nil?)
                        EXTENSION_NAMES.each { |fileType|
                                bigFile = Concatenatefiles.new(@dirName, fileType, "#{@workingDir}/#{File.basename(@lffFile)}#{fileType}")
                                createdFiles = bigFile.concatFiles()   
                            }
                        unless(@keepExtraFiles)
                                    FileUtils.rm_rf(@dirName)
                        end
                    end
                    
                    FileUtils.move("#{@workingDir}/#{File.basename(@lffFile)}#{EXTENSION_NAMES[0]}", @nameOfOutputFile)
                    
                    unless(@keepExtraFiles)
                        listToDelete = Array.new()
                        EXTENSION_NAMES.each { |fileType|
                            $stderr.puts "rm the file #{@workingDir}/#{File.basename(@lffFile)}#{fileType}" if(@verbose)
                            listToDelete << "#{@workingDir}/#{File.basename(@lffFile)}#{fileType}"
                        }
                       FileUtils.rm_rf(listToDelete) 
                    end

                    
                    
                    
                    return exitVal
                    
                end   
          end


 
        # ##############################################################################
        # EXECUTION CLASS
        # ##############################################################################

        class LiftOver
            LIFTOVER_APP = "liftOver"

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
                @chainFile = optsHash['--chainFile'].strip
                @keepExtraFiles = optsHash.has_key?('--keepExtraFiles')
                @nameOfOutputFile = optsHash['--nameOfOutputFile'].strip
                @verbose = optsHash.has_key?('--verbose')
                    
                puts "the @lffInFile = #{@lffInFile}\nthe @chainFile = #{@chainFile}\n" +
                "the @nameOfOutputFile = #{@nameOfOutputFile}\n the @keepExtraFiles = #{@keepExtraFiles}\n" +
                "and the @verbose = #{@verbose}" if(@verbose)
            end

            def validFiles()
                    
                unless(system("which #{LIFTOVER_APP} 1>/dev/null 2>&1"))
                   $stderr.puts "\n\nERROR: the UCSC liftover tool must be in your PATH and must be called \"#{LIFTOVER_APP}\"\n\n" 
                    return false 
                else
                    $stderr.puts "\n\nPass the liftover app" if(@verbose)
                end
                
                $stderr.puts "#{Time.now()} After testing if liftover app exist #{LIFTOVER_APP}" if(@verbose)

                unless(File.exist?("#{@chainFile}"))
                    $stderr.puts "\n\nERROR: cannot find data file \"#{@chainFile}\""
                    return false
                else
                    puts "\n\nPass the chainfile" if(@verbose)
                end 

                $stderr.puts "#{Time.now()} After testing if chainfile exist #{@chainFile}" if(@verbose)

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
                    $stderr.puts "One or more of the required applications are not present "  
                    return false 
                end


                runner = RunLiftover.new(@lffInFile, @chainFile, @nameOfOutputFile, @keepExtraFiles, @verbose)
                exitVal = runner.run()
            
                return exitVal
                    
            end
 
            # ---------------------------------------------------------------
            # CLASS METHODS
            # - generally just 2 (arg processor and usage)
            # ---------------------------------------------------------------
            # Process command-line args using POSIX standard
            def LiftOver.processArguments(outs)
                # We want to add all the prop_keys as potential command line options
                optsArray = [ ['--lffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                              ['--chainFile', '-c', GetoptLong::REQUIRED_ARGUMENT],
                              ['--nameOfOutputFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
                              ['--keepExtraFiles', '-k', GetoptLong::NO_ARGUMENT],
                              ['--verbose', '-V', GetoptLong::NO_ARGUMENT],
                              ['--help', '-h', GetoptLong::NO_ARGUMENT]
                            ]
                progOpts = GetoptLong.new(*optsArray)
                optsHash = progOpts.to_hash
                outs[:verbose] = true if(optsHash and optsHash.key?('--verbose'))
                outs[:keepExtraFiles] = true if(optsHash and optsHash.key?('--keepExtraFiles'))
                outs[:optsHash] = optsHash
                unless(progOpts.getMissingOptions().empty?)
                    @@usageError = true
                    LiftOver.usage("USAGE ERROR: some required arguments are missing") 
                end
                if(optsHash.empty? or optsHash.key?('--help'))
                    LiftOver.usage()
                end
                return optsHash
            end

            # Display usage info and quit.
            def LiftOver.usage(msg='')
                unless(msg.empty?)
                    puts "\n#{msg}\n"
                end
                puts "

                PROGRAM DESCRIPTION:

                LiftOver one lff file from one assembly to another      
                COMMAND LINE ARGUMENTS:
                --lffFile             | -f  => Source LFF file.
                --chainFile           | -c  => File with coordinates necessary to liftover file for example <fullPath>\"hg17ToHg18.over.chain\". 
                --nameOfOutputFile    | -o  =>  Name of output file
                --keepExtraFiles    | -k  => [Optional] Keep extra files ie.bed files or if the lff file has more than 200,000 lines keep the temp files and temp dirs
                --verbose             | -V  => [Optional] Prints more error info (trace)
                    and such when error. Mainly for Genboree.
                --help                | -h  => [Optional flag]. Print help info and exit.

                USAGE:
                liftoverlff.rb -f myLFF.lff -c file.over.chain 
                ";
                exit(BRL::Genboree::USAGE_ERR);
            end # def LiftOver.usage(msg='')
        end # class LiftOver
    end ; end ; end ; end ; end

    # ##############################################################################
    # MAIN
    # ##############################################################################
    include BRL::Genboree::ToolPlugins::Tools::LiftOverTool

    begin
        # Get arguments hash
        outs = { :optsHash => nil, :verbose => false }
        optsHash = LiftOver.processArguments(outs)
        $stderr.puts "#{Time.now()} LIFTOVER - STARTING" if(outs[:verbose])
        initialLffFile = nil
        # Instantiate method
        optsHash.each { | thekey, thevalue |
            puts "the key #{thekey} --> with a value of #{thevalue}" if(outs[:verbose])
        }

        liftAnnotations =  LiftOver.new(optsHash)
        $stderr.puts "#{Time.now()} LIFTOVER - INITIALIZED" if(outs[:verbose])
        exitVal = liftAnnotations.execute()
        $stderr.puts "#{Time.now()} LIFTOVER - FINISHED" if(outs[:verbose])
            
        $stderr.puts "#{Time.now()} Finishing the process" if(outs[:verbose])
        rescue Exception => err # Standard capture-log-report handling:
            errTitle =  "#{Time.now()} LIFTOVER - FATAL ERROR: The liftover exited without processing all the data, due to a fatal error.\n"
            msgTitle =  "FATAL ERROR: The liftover exited without processing all the data, due to a fatal error.\nPlease contact the Genboree admin. This error has been dated and logged.\n"
            errstr   =  "   The error message was: '#{err.message}'.\n"
            errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
            puts msgTitle unless(!outs[:optsHash].nil? or outs[:optsHash].key?('--help'))
            $stderr.puts(errTitle + errstr) if(outs[:verbose])
            exitVal = BRL::Genboree::FATAL
        end
        $stderr.puts "#{Time.now()} SELECTOR - DONE" if(exitVal == 0 and outs[:verbose])
        exit(exitVal)
