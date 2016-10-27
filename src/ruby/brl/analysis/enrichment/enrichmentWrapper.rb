#!/usr/bin/env ruby
require 'pathname'
require 'brl/util/util'
require 'brl/script/scriptDriver'
require 'brl/stats/R/rUtils' # For RUtils.phyper() & more robust R calling

# Write sub-class of BRL::Script::ScriptDriver
module BRL ; module Analysis ; module Enrichment
  class EnrichmentWrapper < BRL::Script::ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "beta"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--regionDir"   => [ :REQUIRED_ARGUMENT, "-r", "Directory containing cell type specific regions in BED format." ],
      "--featuresDir" => [ :REQUIRED_ARGUMENT, "-f", "Directory containing annotation region files in BED format." ],
      "--refFile"     => [ :REQUIRED_ARGUMENT, "-d", "BED File containing all regions." ],
      "--outDir"      => [ :REQUIRED_ARGUMENT, "-o", "Directory where output files can be written, and a scratch subdir can be made." ]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description  => "Calcuate enrichment of Transcription factor binding site for set of regions.
                    Takes two directory file as input. It will then iterate over each file
                    in the directories to calcuate the enrichment of tfbs for each cell
                    type specific ROIs.",
      :authors      => [ "Viren Amin (vamin@bcm.edu)" ],
      :examples => [ "#{File.basename(__FILE__)} -r regionDir -f featureDir -d refFile" ]
    }

    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------

    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    def run()
      @exitCode = setParameters()
      $stderr.puts "STATUS: using these inputs:\n  - regionDir: #{@regionDir.inspect}\n  - featureDir; #{@featureDir.inspect}\n  - refFile: #{@refFile.inspect}\n  - outDir: #{@outDir.inspect}"
      if(@exitCode == EXIT_OK) # then setParameters() was ok and we can proceed, else we'll be returning the error code from setParameters()
        # Set up featureEnrichment() to return an exit code on error.
        @exitCode = featureEnrichment()
      end
      # Must return a suitable exit code number
      return @exitCode
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...

    # -----------------------------------
    #  The algorithm
    # -----------------------------------
    def featureEnrichment()
      retVal = EXIT_OK
      $stderr.puts "STATUS: performing feature enrichment analysis..."

      # Create R engine to [re]use for phyper() calculations
      # - we don't need a new, independent engine; the shared global R is fine (so create with "false")
      rUtil = BRL::Stats::R::RUtils.new(false)

      # Make suitable scratch dir in appropriate scratchDir area
      scratchDir = "#{@outDir}/scratch"
      `mkdir -p #{scratchDir}`

      # Get branch-specific signature region files (will give full paths)
      regions = Dir["#{@regionDir}/*"]
      # Get feature ROI files (will give full paths)
      features = Dir["#{@featuresDir}/*"]
      # Count number of ROI regsion
      wcOut = `wc -l #{@refFile}`.strip
      totalEnhRegions = wcOut.split(' ').first.to_i
      $stderr.puts "STATUS: There are #{totalEnhRegions.commify} ROI regions of interest altogether."

      # Need to generate data matrix, such that rows are region of interest and columns are features.
      # Header is list of features. Since first column will be region of interests, start with that fixed column header.
      header = [ "Index" ]
      ii = 0
      tfbsOverlapEnhHash = {}

      regions.each { |roi| # for each ROI file eg. branch specific signatures
        $stderr.puts "  PROCESSING: #{roi}"
        roiBasename = File.basename(roi)
        # need to write enrichment values, first element is roi which are rownames and features will be in column
        enrichmentRow = []
        pvalueRow = []
        enrichmentRow << roiBasename
        pvalueRow << roiBasename

        # Calculate proportion of region overlap with enhancers
        wcOut = `wc -l #{roi}`.strip
        enhLineageSpecific = wcOut.split(' ').first.to_i

        enhNotLineageSpecific = totalEnhRegions - enhLineageSpecific

        baseline = 0
        features.each { |feature| # for each feature file...
          featureBasename = File.basename(feature)
          totalTfbsOverlapEnh = 0
          totalTfbsOverlapLineageEnh = 0
          enrichment = 0
          pvalue = 0

          if(ii == 0) # Need only one row, so here making if argument for header and total number of features. Dont need to loop for every ROI file
            header.push(featureBasename) # making header list of features
            intersectStatus = bedtoolsIntersect(@refFile, feature, "#{scratchDir}/enhancer_#{totalTfbsOverlapEnh}_intersectBed.bed")
            if(intersectStatus == 0)
              wcOut = `wc -l #{scratchDir}/enhancer_#{totalTfbsOverlapEnh}_intersectBed.bed`.strip
              totalTfbsOverlapEnh = wcOut.split(' ').first.to_f
              tfbsOverlapEnhHash[feature] = totalTfbsOverlapEnh
            else # intersectBed failed!
              # Found problem. Interface wants you to communicate problems clearly and in a certain way:
              # - exit code > 20
              @exitCode = 45
              # - set @errUserMsg to a message a normal user can read understand, without debug or internal code info.
              # - set @errInternalMsg to a similar message [for the logs], and optionally with some extra debug info to help figure out what went wrong.
              @errUserMsg = "FATAL ERROR: the bedtools intersect command failed on some of the input."
              @errInternalMsg = "ERROR: intersectBed failed with exit status #{$?.exitstatus}. Ran this command:\n  #{cmd.inspect}"
            end
          end

          # Still ok to continue? No errors so far?
          if(@exitCode == 0)
            # Calcuate TFBS that overlap with enhancer and TFBS that overlap with Branch specific enhancers
            intersectStatus = bedtoolsIntersect(roi, feature, "#{scratchDir}/#{roiBasename}_#{totalTfbsOverlapEnh}_intersectBed.bed")
            if(intersectStatus == 0)
              wcOut = `wc -l #{scratchDir}/#{roiBasename}_#{totalTfbsOverlapEnh}_intersectBed.bed`.strip
              totalTfbsOverlapLineageEnh = wcOut.split(' ').first.to_i

              pvalue = rUtil.phyper(
                totalTfbsOverlapLineageEnh, enhLineageSpecific, enhNotLineageSpecific, tfbsOverlapEnhHash[feature], false
              )
              #`R --vanilla --args #{totalTfbsOverlapLineageEnh } #{enhLineageSpecific} #{enhNotLineageSpecific} #{tfbsOverlapEnhHash[feature]} #{scratchDir}/pvalue_data.txt < phyper_test.R`

              pvalueRow << pvalue.to_f
              enrichmentRow << enrichment
            else # intersectBed failed!
              # Found problem. Interface wants you to communicate problems clearly and in a certain way:
              # - exit code > 20
              @exitCode = 45
              # - set @errUserMsg to a message a normal user can read understand, without debug or internal code info.
              # - set @errInternalMsg to a similar message [for the logs], and optionally with some extra debug info to help figure out what went wrong.
              @errUserMsg = "FATAL ERROR: the bedtools intersect command failed on some of the input."
              @errInternalMsg = "ERROR: intersectBed failed with exit status #{$?.exitstatus}. Ran this command:\n  #{cmd.inspect}"
            end
          end

          # If we have seen an error in any of the above, probably from an intersectBed call,
          # we should stop processing!
          break unless(@exitCode == 0)
        }

        # At this point, we've gone through all the features for the current roi.
        # Either all roi-feature pairs went well or there was an error during intersect.
        if(@exitCode == 0)
          if(ii == 0)
            @enrichCsv.puts header.join(',')
            @pvalueCsv.puts header.join(',')
          end

          ii = 1
          @enrichCsv.puts enrichmentRow.join(',')
          @pvalueCsv.puts pvalueRow.join(',')
        else # error, stop processing the ROIs
          break
        end
      }

      # Clean up the scratch dir & close output files
      `rm #{scratchDir}/*`
      @enrichCsv.close rescue false
      @pvalueCsv.close rescue false

      $stderr.puts "STATUS: ... done. Everything ok? #{@exitCode == 0 ? true : false}."

      return @exitCode
    end

    # -----------------------------------
    #  Aux
    # -----------------------------------

    # Get command-line argument info, cd to output dir, and do some checking
    def setParameters()
      @exitCode = EXIT_OK
      # Get full paths of input dirs and files (do this before an chdir obviously, or relative paths provided may be wrong)
      @regionDir = File.expand_path(@optsHash['--regionDir'])
      @featuresDir = File.expand_path(@optsHash['--featuresDir'])
      @refFile = File.expand_path(@optsHash['--refFile'])

      # Output dir and files
      @outDir = File.expand_path(@optsHash['--outDir'])
      @pvalueCsv = File.open("#{@outDir}/enrichment_#{Time.now.strftime("%m.%d.%Y")}.csv", "w+")
      @enrichCsv = File.open("#{@outDir}/pvalue_#{Time.now.strftime("%m.%d.%Y")}.csv", "w+")

      # Using current directory for scratch & output is dangerous...we don't know where our script will be called from.
      # - we will "cd" to the explicitly provided output dir
      Dir.chdir(@outDir)

      # Verify these dirs & file exist, are appropriate type, and are readable
      unless(checkDir(@regionDir) and checkDir(@featuresDir) and checkFile(@refFile))
        # Found problem. Interface wants you to communicate problems clearly and in a certain way:
        # - exit code > 20
        @exitCode = 42
        # - set @errUserMsg to a message a normal user can read understand, without debug or internal code info.
        # - set @errInternalMsg to a similar message [for the logs], and optionally with some extra debug info to help figure out what went wrong.
        #   (already set by checkDir() and checkFile() in this case)
        @errUserMsg = "FATAL ERROR: the enrichment script is being called with unusable input or output directories and files."
      end

      return @exitCode
    end

    # Make sure we can access input directory appropriately. Checks:
    # - dir exists? (um otherwise we have problem)
    # - dir readable? (can get file listing)
    # - dir executable? (can cd into dir)
    # Will also write stderr messages about any problems, to aid user and/or debugging.
    # @param [String] dir The full path to dir
    # @return [Boolean] indicating if the dir is ok or not
    def checkDir(dir)
      retVal = false
      if(File.exist?(dir))
        if(File.readable?(dir))
          if(File.executable?(dir))
            retVal = true
          else
            @errInternalMsg = "!! ERROR: the directory #{dir.inspect} is not executable by you. Cannot 'cd' into dir, for example. !!"
          end
        else
          @errInternalMsg = "!! ERROR: the directory #{dir.inspect} is not readbale by you. Cannot get a file listing, for example. !!"
        end
      else
        @errInternalMsg = "!! ERROR: the directory #{dir.inspect} does not exist! !!"
      end
      return retVal
    end

    # Make sure we can access input file approprirately. Checks:
    # - file exists?
    # - file readable?
    # @param [String] file The full path to file to check
    # @return [Boolean] indicating if the file is ok or not
    def checkFile(file)
      retVal = false
      if(File.exist?(file))
        if(File.readable?(file))
          retVal = true
        else
          @errInternalMsg = "ERROR: the directory #{dir.inspect} is not readbale by you. Cannot get a file listing, for example."
        end
      else
        @errInternalMsg = "ERROR: the directory #{dir.inputs} does not exist!"
      end
      return retVal
    end

    # Run "bedtools intersect" command (old way: "intersectBed") on 2 bed files,
    #   writing out the original entry in @bedFile1@ for each overlap (@-wa@) and
    #   only write out such records _once_ (unique records from @bedFile1@).
    # @param [String] bedFile1 Full path to the first bed file.
    # @param [String] bedFile2 Full path to the second bed file to intersect with the first.
    # @param [String] outputPath Full path to an output file where the intersecting records can go.
    # @return [Fixnum] actually returns @@exitCode@ which is set to non-zero when there is a problem
    #  running the intersectBed command. This value should be checked before continuing with
    #  processing or moving on to the next pair of files or whatever! It _should_ return 0 if everything
    #  is ok!
    def bedtoolsIntersect(bedFile1, bedFile2, outputPath)
      @exitCode = EXIT_OK
      cmd = "intersectBed -a #{bedFile1} -b #{bedFile2} -wa -u > #{outputPath}"
      cmdOut = `#{cmd}`
      unless($?.success?) # intersectBed failed!
        # Found problem. Interface wants you to communicate problems clearly and in a certain way:
        # - exit code > 20
        @exitCode = 45
        # - set @errUserMsg to a message a normal user can read understand, without debug or internal code info.
        # - set @errInternalMsg to a similar message [for the logs], and optionally with some extra debug info to help figure out what went wrong.
        @errUserMsg = "FATAL ERROR: the bedtools intersect command failed on some of the input."
        @errInternalMsg = "ERROR: intersectBed failed with exit status #{$?.exitstatus}. Ran this command:\n  #{cmd.inspect}"
      end
      return @exitCode
    end

    # -----------------------------------
    #  Aux
    # -----------------------------------

    def writeToCsv(csvString)
      File.open("#{@outDir}/enrichment_#{Time.now.strftime("%m.%d.%Y")}.csv", "a+") { |csvRow|
        csvRow.write("#{csvString}\n")
      }
    end

    def writeToCsv2(csvString)
      File.open("#{@outDir}/pvalue_#{Time.now.strftime("%m.%d.%Y")}.csv", "a+") { |csvRow|
        csvRow.write("#{csvString}\n")
      }
    end
  end # class EnrichmentWrapper
end ; end ; end # module BRL ; module Analysis ; module Enrichment


########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Analysis::Enrichment::EnrichmentWrapper)
end
