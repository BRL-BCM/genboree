#!/usr/bin/env ruby

require 'getoptlong'                # for GetoptLong class (command line option parse)
require 'brl/util/util'             # for to_hash extension of GetoptLong classrequire 'brl/util/propTable'
require 'brl/util/textFileUtil'     # For TextReader/Writer classes
require 'brl/util/logger'

include BRL::Util

module BRL ; module FormatMapper
        USAGE_ERR = 16
        MAX_NUM_ERRORS = 10
        ATTRS_PER_REC = 9
        
        DEFAULT_CLASS = "GFFTOLFF"
        DEFAULT_TYPE = "GFF"
        DEFAULT_SUBTYPE ="ANNOTATION"

class GffToLff
        
        def initialize(optsHash)
                @gffFile = optsHash['--gffFile']
                @baseFileName = @gffFile.strip.gsub(/\.lff$/, '')
                @doGzip =  false
                if(optsHash.key?('--outputFile'))
                        @outputFile = optsHash['--outputFile']
                else
                        @outputFile = @baseFileName +  '.lff'
                end

               if  optsHash.key?('--class')
                    @lffClass = optsHash['--class']
               else
                   @lffClass = DEFAULT_CLASS
                   GffToLff.classUsage() 
                   
         end
        @lffType = optsHash.key?('--type') ? optsHash['--type'] : DEFAULT_TYPE
        @lffSubtype = optsHash.key?('--subtype') ? optsHash['--subtype'] :DEFAULT_SUBTYPE
       
        
 
        end
 
        
               
        def convert()
                err_count = 0
                reader = BRL::Util::TextReader.new(@gffFile)
                writer = BRL::Util::TextWriter.new(@outputFile, "w+", @doGzip)
                reader.each { |line|
                        if err_count < BRL::FormatMapper::MAX_NUM_ERRORS
                        
                        line.strip!
                        # Is it a header or blank or comment line or a non word character?
                        next if(line =~ /^\s*$/ or line =~ /^\s*#/ or line =~ /^(?:gffLayout|match|\s+match|\-+)/ or line =~ /^(\W)+/)

                                valuePairs = ""
                                name = ""
                                str =""
 
                                rr = line.strip.split(/\t/)
                        
                                if (rr.length < ATTRS_PER_REC )
                                    err_count = err_count + 1
                                    next
                                end
                
                                classname = @lffClass
                                chromosomeName = rr[0].strip
                                type = rr[1].strip
                                subtype = rr[2].strip
                                start = rr[3].strip
                                stop = rr[4].strip
                                
                                if (rr[5] == ".")
                                    score = 1.0 # default score for lff format
                                else
                                    score = rr[5].strip
                                end

                                if (rr[6] == ".")
                                    strand = "+" #if you don't care about strand.
                                else
                                    strand = rr[6].strip
                                end
                                
                                phase = rr[7].strip
                                str = rr[8].strip
                                #vP = rr[8].strip.split(/;/)
 
                                case str
    
                                  when /^\s*name/
                                    name , valuePairs = GffToLff.extractName(str)
                                    
                                  else
                                    name , valuePairs = GffToLff.namePrint(str)
   
                                end
                                writer.print "#{classname}\t#{name}\t#{type}\t#{subtype}\t#{chromosomeName}\t#{start}\t#{stop}\t#{strand}\t#{phase}\t#{score}\t.\t.\t#{valuePairs}\n"
 
                     end           
 
                }
 
 
                # Close files
                reader.close()
                writer.close()
                return err_count
                
                
        end
        
        def GffToLff.extractName(str)
               name =""
               valuePairs = ""
    
               if (str =~ /;/ )
                vP = str.strip.split(/;/)
        
                vP.each { | tempVP |
                if(tempVP =~ /name/)
                 tempname = tempVP.gsub(/name /, "").split(/"/)
                 name = tempname[1]
                 
                else
                
                
                nameValue = tempVP.strip.split(/\s/)
                                        if(valuePairs.empty?)
                                            valuePairs = "#{nameValue[0].strip}=#{nameValue[1].strip}; "
                                        else
                                            valuePairs = valuePairs + "#{nameValue[0].strip}=#{nameValue[1].strip}; "
                                        end
                    
                end
                        }
                                    
               else
                vP = str.strip.gsub(/name/, "")
                if vP =~ /"/
                name_arr = vP.split(/"/)
                name = name_arr[1]
                else
                 name = vP
                 valuePairs = ""
                end
        
                end
                             
            return name , valuePairs
    
        end
        
        def GffToLff.namePrint(str)
             name =""
             valuePairs = ""
    
            if (str =~ /;/ )
              vP = str.strip.split(/;/)
              vP.each { | tempVP |
                 if tempVP =~ /"/
                 
                 tempname = tempVP.strip.split(/"/)
                 name = tempname[1]
                 else
                
                  if !(name.empty?)
               
                  nameValue = tempVP.strip.split(/\s/)
                  
                  if(valuePairs.empty?)
                      valuePairs = "#{nameValue[0].strip}=#{nameValue[1].strip}; "
                  else
                      valuePairs = valuePairs + "#{nameValue[0].strip}=#{nameValue[1].strip}; "
                  end
                
                  else
                    name = vP[0]
                    valuePairs = ""
                     
                  end
                 end
                }
        
            else if (str =~ /"/)
            tempname = str.strip.split(/"/)
            name = tempname[1]
            else
            name = str
            valuePairs = ""

            end
            end
            return name , valuePairs
        end
        
        def GffToLff.processArguments()
                optsArray =     [
                                    ['--gffFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                                    ['--outputFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                                    ['--class', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                                    ['--type', '-t', GetoptLong::OPTIONAL_ARGUMENT],
                                    ['--subtype', '-s', GetoptLong::OPTIONAL_ARGUMENT],
                                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                                ]
                progOpts = GetoptLong.new(*optsArray)
                optsHash  = progOpts.to_hash
                GffToLff.usage() if(optsHash.empty? or optsHash.key?('--help'))
                return optsHash
        end
        
        def GffToLff.usage(msg='')
                puts "\n#{msg}\n" unless(msg.empty?)
                puts "
 
    PROGRAM DESCRIPTION:
    Converts a GFF file to a Genboree-compliant LFF file.
    gff headers will be ignored wherever they occur, allowing concatenation of
    many gff files into one.
 
    The reference sequence is assumed to be the gff target.
 
    Only the input file need be specified and each entire hit will be turned
    
    Alternatively, you can have each block of a hit converted separately and/or
    override the class/type/subtype and/or override the output file.
 
    Each GFF hit will be a unique LFF hit. 
 
    NOTE: The 'score' column in the LFF will be an alignment score calculated
          from the hit details.
          [ score= 2*matches - mismatches - gaps - 2*(gapBases-gaps) ]
 
    COMMAND LINE ARGUMENTS:
      -f    => Gff file to convert to LFF.
      -o    => [optional] Override the output file location.
               Default is the gffFile.gff.lff.
      -c    => [optional] Override the LFF class value to use.
               Defaults to 'Gff'.
      -t    => [optional] Override the LFF type value to use.
               Defaults to 'Gff'.
      -s    => [optional] Override the LFF subtype value to use.
               Defaults to 'Hit'.
      
      -h    => [optional flag] Output this usage info and exit
 
    USAGE:
    gff2lff.rb  -f mygffHits.gff
        "
                exit(BRL::FormatMapper::USAGE_ERR)
        end
        
        
        def GffToLff.classUsage()
            puts "class name not provided . Default value GFFTOLFF is used. \n
            USAGE: gff2lff.rb  -f mygffHits.gff [-o output.lff] [-c classname]"
        end
end # class GffToLff
end
end
 
 
# MAIN##########################################################################:
optsHash = BRL::FormatMapper::GffToLff::processArguments()######################:
converter = BRL::FormatMapper::GffToLff.new(optsHash)
ret_val = converter.convert()
if (ret_val >= BRL::FormatMapper::MAX_NUM_ERRORS)
    puts "Error: not a valid input file"
end
exit()

