#!/usr/bin/env ruby
require 'fileutils'
require 'matrix.rb'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'brl/microbiome/workbench/RandomForestUtils'
require 'brl/microbiome/workbench/sample_class'
	
class RandomForestDriver
  DEBUG = true
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end  
  
  def setParameters()
   @sampleData = File.expand_path(@optsHash['--sampleData'])
   @metadata = File.expand_path(@optsHash['--metadata'])
   @feature = @optsHash['--feature']
   @outputFolder = File.expand_path(@optsHash['--outputFolder'])
   
  end
  
  def loadMetadataHash()
    r = File.open(@metadata)
    metadataLabels = []
    #@metahash=Hash.new {|h,k| h[k]=Hash.new(&h.default_proc))}
    @metahash=Hash.new {|h,k| h[k]={}}
    r.each {|l|
      if (r.lineno==1) then
        f = l.strip.split(/\t/)
        f.each {|a|
          metadataLabels.push(a)
        }
        metadataLabels[0]=nil    
      else
        f = l.strip.split(/\t/)
        sampleName = f[0]
        1.upto(f.size-1) { |i|
          @metahash[metadataLabels[i]][sampleName] = f[i]
          $stderr.puts "metahash #{metadataLabels[i]} -> #{sampleName} --> #{f[i]}" if (DEBUG)
        }
      end
    }
    r.close()
    $stderr.puts "mh: #{@metahash.keys.join(",")}" if (DEBUG)
  end


  def runRandomForest()
    #puts cutoffVal = cutoff.to_i
    #optional filtering step if we have really large input
    outDir = "#{@outputFolder}/RF_Boruta/#{@feature}/"
    FileUtils.mkdir_p outDir
    filteredMatrixFile = "#{outDir}/#{File.basename(@sampleData)}-filtered.txt"
    transMatrixFile=filteredMatrixFile.gsub(/txt/,"trans")
    normMatrixFile = filteredMatrixFile.gsub(/txt/, "norm") 
    rfobject=RandomForestUtils.new(@trimMatrixFile,@metahash[@feature],@feature,outDir) 
    #Filter otu table based on cutoff 
    filteredRF=rfobject.filterFeatureValuesByMinFeatureValue(-100000)
    $stderr.puts "Filtered Matrix File #{filteredMatrixFile}" if (DEBUG)
    rfobject.printmatrixTofile(filteredRF,filteredMatrixFile)
    #transpose the matrix and add feature value 
    transRF=filteredRF.t
    transRF=rfobject.addmeta(transRF)
    rfobject.printmatrixTofile(transRF,transMatrixFile)  
    #normalize the matrix and prepare input for RandomForest
    # normalizedRF=rfobject.normalization(transRF,0,100000)
    # rfobject.printmatrixTofile(normalizedRF,normMatrixFile)
    #run Randome Forest
    rfobject.machineLearning(transMatrixFile,0)
    #run Boruta
    rfobject.borutaFeatureSelection(transMatrixFile,0)
  end
  
  def work()
    system("mkdir -p #{@outputFolder}")
    @trimMatrixFile = @sampleData
    loadMetadataHash()
    if (!@metahash.key?(@feature)) then
      $stderr.puts "The feature selected #{@feature} is not present in the metadata #{@metahash.keys.join("\t")}"
      exit(2)
    end
    runRandomForest()
  
  end
  
  def RandomForestDriver.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--sampleData',     '-s', GetoptLong::REQUIRED_ARGUMENT],
				['--metadata',   '-m', GetoptLong::OPTIONAL_ARGUMENT],
				['--outputFolder',   '-o', GetoptLong::OPTIONAL_ARGUMENT],
				['--feature',  '-f', GetoptLong::OPTIONAL_ARGUMENT],
		         	['--help',           '-h', GetoptLong::NO_ARGUMENT]
								]
		
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		RandomForestDriver.usage() if(optsHash.key?('--help'));
		
		unless(progOpts.getMissingOptions().empty?)
			RandomForestDriver.usage("USAGE ERROR: some required arguments are missing") 
		end
	
		RandomForestDriver.usage() if(optsHash.empty?);
		return optsHash
	end
	
	def RandomForestDriver.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  It does something.

COMMAND LINE ARGUMENTS:
  --sampleData     | -s   => sample data 
  --metadata       | -m   => metadata file 
  --outputFolder   | -o   => output folder 
  --feature        | -f   => feature
  --help           | -h   => [optional flag] Output this usage info and exit

USAGE:
  randomForestDriver.rb  -s samplesData -m metaData -o optionalArg -f CellType
";
			exit(2);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = RandomForestDriver.processArguments()
# Instantiate analyzer using the program arguments
boilerPlate = RandomForestDriver.new(optsHash)
# Analyze this !
boilerPlate.work()
exit(0);
