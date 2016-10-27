#!/usr/bin/env ruby


require 'brl/util/util'
require 'brl/util/textFileUtil'



module BRL ; module Genboree; module Pipelines; module Acgh; module Applications
          
TOP = "#!/usr/bin/env ruby

require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/pipelines/acgh/agilentToVGPPipeline'

module BRL ; module Genboree; module Pipelines; module Acgh; module Applications


class "
 
          
HEADER = '

DEFAULTUSAGEINFO ="

      Usage: ###PUT your usage message here #############.
      
  
      Mandatory arguments:

'

FUNCS = '    -v,   --version             Display version.
    -h,   --help, 			   Display help
      
"


    def self.printUsage(additionalInfo=nil)
      puts DEFAULTUSAGEINFO
      puts additionalInfo unless(additionalInfo.nil?)
      if(additionalInfo.nil?)
        exit(0)
      else
        exit(15)
      end
    end
    
    def self.printVersion()
      puts BRL::Genboree::Pipelines::Acgh::AGILENT_PIPELINE_VERSION
      exit(0)
    end

    def self.parseArgs()
          
      methodName = "'

CONTFUNC = "
      optsArray = ["

ENDCONT = "                    ['--version', '-v',   GetoptLong::NO_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]

      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      
      if(optsHash.key?('--help'))
        printUsage()
      elsif(optsHash.key?('--version'))
        printVersion()
      end
      printUsage(\"USAGE ERROR: some required arguments are missing\") unless(progOpts.getMissingOptions().empty?)

      return optsHash
    end
"
PREEND= "


    def self."

PREEND2="(optsHash)

"

PREEND3 = "
     

    end
  
end

end; end; end; end; end;  #namespace

optsHash = BRL::Genboree::Pipelines::Acgh::Applications::"

PREEND4=".parseArgs()

BRL::Genboree::Pipelines::Acgh::Applications::"

ENDEND="(optsHash)
"



ALPHABET = ['a', 'b','c','d', 'e', 'f', 'g', 'i', 'j', 'k', 'l', 'm',
						 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'w', 'x', 'y',
						 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
						 'A', 'B','C','D', 'E', 'F', 'G', 'I', 'J', 'K', 'L', 'M',
						 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'W', 'X', 'Y', 'Z'] 

 class TransformFile
  attr_accessor :readFileStr, :outPutFile, :nameOfVar, :className, :methodName, :calls

  def initialize(readFile)
    @readFileStr = readFile
    tmp = readFile.gsub(/.rb/, "_new.rb")
    @outPutFile = tmp
    @className = ""
    @methodName = ""
    @nameOfVar = Hash.new {|hh,kk| hh[kk] = nil }
    @calls = Array.new()
    parseFile()
    creatingNewFile()
  end

  def parseFile()
    # Read  file
    reader = BRL::Util::TextReader.new(@readFileStr)
		counter = 0
    line = nil
    begin

      reader.each { |line|
        newName = ""
        newSubType = ""
        newAttr = ""
        errofLevel = 0
        next if(line !~ /\S/)

        if(line =~ /^\s*class\s+(.*)\s*$/)
					@className = $1
					@className.strip!
#					puts "className = #{@className}"
        end
        
        if(line =~ /^\s*methodName\s*=\s*"([^"]*)"\s*$/)
					    @methodName = $1
					    @methodName.strip!
#					    puts "methodName = #{methodName}"
        end
        
        if(line =~ /^\s*\S*\s*=\s*optsHash[\[]['][-][-]([^']*)['][\]].*$/ )
					var = $1
					@nameOfVar[var] = ALPHABET[counter] unless(@nameOfVar.has_key?(var))
					counter += 1
        end
        
        if(line =~ /^\s.*\.new\(.*$/ )
					@calls << line
#					puts line
					counter += 1
        end
       
       
        

      }

      reader.close()
    rescue => err
      $stderr.puts "ERROR: bad line found. Blank columns? Line num: #{reader.lineno}. Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
      $stderr.puts "LINE: #{line.inspect}"
      exit 137
    end
 end   
 
 def creatingNewFile()

	    fileWriterOutPutFile = BRL::Util::TextWriter.new(@outPutFile)
      
      fileWriterOutPutFile.puts "#{TOP} #{@className}"
      fileWriterOutPutFile.puts HEADER

      @nameOfVar.each{|key, value|
				fileWriterOutPutFile.puts "    -#{value}    --#{key}            #[#{key}]."
				}
      fileWriterOutPutFile.puts "#{FUNCS}#{@methodName}\""
      fileWriterOutPutFile.puts CONTFUNC
      
      @nameOfVar.each{|key, value|
				fileWriterOutPutFile.puts "                    ['--#{key}', '-#{value}', GetoptLong::REQUIRED_ARGUMENT],"
				}

			fileWriterOutPutFile.puts ENDCONT
			fileWriterOutPutFile.puts "#{PREEND}#{@methodName}#{PREEND2}"
			@calls.each{|call|
				parts = call.split("(")
				callToClass = parts[0]
				varPart = parts[1]
				varPart.gsub!(/\)/, "")
				variables = varPart.split(",")
				
				variables.map!{|var|
					var = "optsHash['--#{var.strip}']"
				}
				fileWriterOutPutFile.puts "    #{callToClass}(#{variables.join(", ")})"
			}
			fileWriterOutPutFile.puts "#{PREEND3}#{@className}#{PREEND4}#{@className}.#{@methodName}#{ENDEND}"
			fileWriterOutPutFile.close()
 end
 
  
end #end of Class 



	class RunTransformFile
		def self.runTransformFile(optsHash)
			#--lffFileName
			methodName = "runTransformFile"
			readFile = nil

			
			readFile  = optsHash['--readFile'] if( optsHash.key?('--readFile') )


			
			if( readFile.nil?  )
					$stderr.puts "Error missing parameters in method #{methodName}"
					$stderr.puts "--readFile=#{readFile}"
					return
			end
			TransformFile.new(readFile)
		end
	end

end; end; end; end; end #namespace

optsHash = Hash.new {|hh,kk| hh[kk] = 0}
numberOfArgs = ARGV.size
i = 0
while i < numberOfArgs
	key = "''"
	value = "''"
	key = ARGV[i] if( !ARGV[i].nil? )
	value =  ARGV[i + 1]  if( !ARGV[i + 1].nil? )
	optsHash[key] = value
	i += 2
end


#testing basic functions not used for implementation
BRL::Genboree::Pipelines::Acgh::Applications::RunTransformFile.runTransformFile(optsHash)

