#!/usr/bin/env ruby

require "fileutils"
require "brl/util/textFileUtil"
require "brl/util/util"
require "brl/script/scriptDriver"

module BRL ; module Script
  class EpgQiimeDriver < ScriptDriver
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
      :description => "Script to run Qiime to generate PCOA plots for epigenomic data",
      :authors      => [ "Sriram Raghuraman (raghuram@bcm.edu)"],
      :examples => [
        "#{File.basename(__FILE__)} -i ./test22.bed.gz -o ./idrTemp/ -n 2",
        "#{File.basename(__FILE__)} --help"
      ]
    }



    def run()
      begin
        validateAndProcessArgs()
        @exitCode = runQiime(@features, @featureValues, @inputFile, @outputDir, @cutoffs)
      rescue => err
        $stderr.puts "Unexpected error while running EpgQiimeDriver"
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
        @exitCode = 121
      end
      return @exitCode
    end

def initialize
    @errMsg = ""
end

    def validateAndProcessArgs
      @features = @optsHash['--features'].split(/,/)
      @featureValues = JSON.parse(@optsHash['--values'])
      @cutoffs = @optsHash['--cutoffs'].split(/,/)
      @inputFile = @optsHash['--input']
      @outputDir = @optsHash['--output']
    end

    def runQiime(attrNames, matrixFile,mappingFile,outputDir,plotDir,metrics = nil)
      if(metrics.nil? or metrics.empty?) then metrics = @metrics end
      metrics.each{|metric|
        metricFolder="#{outputDir}/#{metric}_dist/"
        cmd = "beta_diversity.py -i #{matrixFile} -m #{metric} -o #{metricFolder}"
        $stderr.debugPuts(__FILE__,__method__,"DEBUG","beta diversity cmd:#{cmd}")
        system(cmd)
        if($?.exitstatus!=0) then
          errMsg = "ERROR: Beta diversity calculation for #{metric} failed"
          @errMsg << errMsg
        else
          cmd = "principal_coordinates.py -i #{metricFolder}/#{metric}_#{File.basename(matrixFile)} -o #{metricFolder}/#{metric}_coords.txt"
          $stderr.debugPuts(__FILE__,__method__,"DEBUG","principal coordinates cmd:#{cmd}")
          system(cmd)
          if($?.exitstatus!=0) then
            errMsg = "ERROR: Principal coordinates calculation for #{metric} failed"
            @errMsg << errMsg
          else
            attrNames.each{|attr|
              cmd = "make_2d_plots.py -i #{metricFolder}/#{metric}_coords.txt -m #{mappingFile} -o #{plotDir}/#{metric}_2d-all/ -b #{attr}"
              $stderr.debugPuts(__FILE__,__method__,"DEBUG","2D plot cmd:#{cmd}")
              system(cmd)
              if($?.exitstatus!=0) then
                errMsg = "ERROR: 2D plot creation for #{metric} and #{attr} failed"
                @errMsg << errMsg
              else
                cmd = "make_3d_plots.py -i #{metricFolder}/#{metric}_coords.txt -m #{mappingFile} -o #{plotDir}/#{metric}_3d-all/ -b #{attr}"
                $stderr.debugPuts(__FILE__,__method__,"DEBUG","3D plot cmd:#{cmd}")
                system(cmd)
                if($?.exitstatus!=0) then
                  errMsg = "ERROR: 3D plot creation for #{metric} and #{attr} failed"
                  @errMsg << errMsg
                end
              end
            }
          end
        end
      }
      if(!@errMsg.empty?) then
        raise @errMsg
      else
        return EXIT_OK
      end
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
  BRL::Script::main(BRL::Script::EpgQiimeDriver)
  #
  #fh={"body_site"=>{"T_700095565"=>"Throat", "T_700016994"=>"Throat", "S_700035861"=>"Stool", "T_700101388"=>"Throat", "S_700101600"=>"Stool", "S_700033665"=>"Stool", "T_700101622"=>"Throat", "S_700095850"=>"Stool", "S_700095543"=>"Stool", "T_700095872"=>"Throat"}}
  #BRL::Script::RandomForestDriver.new().runRandomForest("body_site", fh, "/home/raghuram/otu_table.txt","/home/raghuram",[500])
end



