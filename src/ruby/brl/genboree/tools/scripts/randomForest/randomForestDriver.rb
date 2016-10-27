#!/usr/bin/env ruby

require "brl/genboree/tools/scripts/randomForest/randomForestHelper"
#require '/home/junm/gaussCode/brlheadmicrobiome/RandomForestUtils'
require 'brl/genboree/tools/scripts/randomForest/randomForestPlotter'
require 'fileutils'
require 'matrix.rb'
require "brl/util/textFileUtil"
require "brl/util/util"
require "brl/script/scriptDriver"

module BRL ; module Script
  class RandomForestDriver < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--features" =>  [ :REQUIRED_ARGUMENT, "-f", "Features to be used for random forest run" ],
      "--cutoffs" =>  [ :REQUIRED_ARGUMENT, "-c", "List of cutoffs to use" ],
      "--inputFile" =>  [ :REQUIRED_ARGUMENT, "-i", "Input OTU matrix file" ],
      "--output" =>  [ :REQUIRED_ARGUMENT, "-o", "output directory" ],
      "--values" =>  [ :REQUIRED_ARGUMENT, "-v", "CGI escaped JSON of feature to value mapping" ]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "Script to run Random Forest on existing OTU table",
      :authors      => [ "Sriram Raghuraman (raghuram@bcm.edu)"],
      :examples => [
        "#{File.basename(__FILE__)} -i ./test22.bed.gz -o ./idrTemp/ -n 2",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    def run()
      begin
        validateAndProcessArgs()
        @exitCode = runRandomForest(@features, @featureValues, @inputFile, @outputDir, @cutoffs)
      rescue => err
        $stderr.puts "Unexpected error while running RandomForestDriver"
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        @exitCode = 121
      end
      return @exitCode
    end


    def validateAndProcessArgs
      @features = @optsHash['--features'].split(/,/)
      @featureValues = JSON.parse(@optsHash['--values'])
      @cutoffs = @optsHash['--cutoffs'].split(/,/)
      @inputFile = @optsHash['--input']
      @outputDir = @optsHash['--output']
    end

    def runRandomForest(chosenFeatures, featureValuesHash, otuFile, outputDir, cutoffs)

      trimMatrixFile = "#{otuFile}_trim.txt"
      r=File.open(otuFile,"r")
      w=File.open(trimMatrixFile, "w")
      r.gets
      taxohash={}
      r.each_line{ |line|
        line.strip!
        cols=line.split(/\t/)
        taxo=cols.pop
        name=cols[0]
        taxohash[name]=taxo
        trimline=""
        cols.each{|ele|
          trimline << "#{ele}\t"
        }
        trimline.strip!
        w.puts trimline
      }
      r.close()
      w.close()
      featureLabels = featureValuesHash.keys
      rfPlotter = BRL::Script::RandomForestPlotter.new
      chosenFeatures.each{|feature|
        outDir = "#{File.expand_path(outputDir)}/RF_Boruta/#{feature}/"
        system("mkdir -p #{outDir}")
        attrHash = featureValuesHash[feature]
        #check each cutoff
        cutoffs.each{ |cutoff|
          #optional filtering step if we have really large input
          FileUtils.mkdir_p outDir
          outFile = "#{outDir}/otu_table_#{cutoff}-filtered"
          filteredMatrixFile = "#{outFile}.txt"
          transMatrixFile = "#{outFile}.trans"
          normMatrixFile = "#{outFile}.norm"
          rfobject=RandomForestHelper.new(trimMatrixFile,attrHash,feature,outDir)
          #Filter otu table based on cutoff
          filteredRF=rfobject.filterFeatureValuesByMinFeatureValue(cutoff.to_i)
          #filteredRF=rfobject.filterFeatureValuesByMinPercent(cutoff.to_i)
          rfobject.printmatrixTofile(filteredRF,filteredMatrixFile)
          #transpose the matrix and add feature value
          transRF=filteredRF.t          
          transRF=rfobject.addmeta(transRF)
          rfobject.printmatrixTofile(transRF,transMatrixFile)
          #normalize the matrix and prepare input for RandomForest
          normalizedRF=rfobject.normalization(transRF,0,100000)
          rfobject.printmatrixTofile(normalizedRF,normMatrixFile)
          #run Randome Forest
          rfobject.machineLearning(normMatrixFile,cutoff,feature)
          #run Boruta
          rfobject.borutaFeatureSelection(normMatrixFile,cutoff)


          valuearray=attrHash.values
          uniqsize=valuearray.uniq.size()
          #if(uniqsize==2)
            #combine RF Boruta OTUtable
            tableprep=normalizedRF.t
            tableforcombine="#{outFile}.forcombine"
            rfobject.printmatrixTofile(tableprep,tableforcombine)
            impOutStub="#{outDir}/RandomForest/#{feature}-#{cutoff}_sortedImportance.txt"
            impforcombine="#{outDir}/RandomForest/#{feature}-#{cutoff}_sortedImportanceforcombine.txt"
            r=File.open(impOutStub,"r")
            w=File.open(impforcombine,"w")
            w.puts r.gets
            r.each_line{|line|
              line.strip!
              cols=line.split("\t")
              name=cols[0]
              if name =~ /X/
                name.gsub!(/X/,"")
              end
              taxo=taxohash[name]
              #puts "#{name}\t#{taxohash[name]}"
              outputline="#{taxo}\t#{name}"
              for ii in 1..cols.size()
                outputline="#{outputline}\t#{cols[ii]}\t"
              end
              outputline.strip!
              w.puts outputline
            }
            r.close()
            w.close()
            borutaconfirmfile="#{outDir}/Boruta/Boruta_#{cutoff}_confirmed.txt"
            combinecmd="resultCombine.rb #{tableforcombine} #{impforcombine} #{borutaconfirmfile}"
            puts combinecmd
            system(combinecmd)
         # end
        }
        rfPlotter.plotResults(feature, cutoffs, outDir, "#{outDir}/graph/")
        `tsvtoxls.rb #{outDir}/RandomForest/ #{feature}`
      }
      outDir = File.expand_path(outputDir) + "/RF_Boruta/"
      line=""
      cutoffs.each{|cut|
        line+="#{cut} "
      }
      `randomforest_errorrate.rb #{outDir} #{line}`
      return EXIT_OK
    end
  end
end ; end # module BRL ; module Script

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::RandomForestDriver)
  #
  #fh={"body_site"=>{"T_700095565"=>"Throat", "T_700016994"=>"Throat", "S_700035861"=>"Stool", "T_700101388"=>"Throat", "S_700101600"=>"Stool", "S_700033665"=>"Stool", "T_700101622"=>"Throat", "S_700095850"=>"Stool", "S_700095543"=>"Stool", "T_700095872"=>"Throat"}}
  #BRL::Script::RandomForestDriver.new().runRandomForest("body_site", fh, "/home/raghuram/otu_table.txt","/home/raghuram",[500])

end



