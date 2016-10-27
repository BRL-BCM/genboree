#!/usr/bin/env ruby
#########################################################
############ RSEQtools pipeline wrapper #################
## This wrapper runs the RNA-Seq data analysis pipeline #
## using modules in RSEQtools
## Modules used in this pipeline:
## 1. Bowtie 
## 2. RSEQtools
## 3. samtools
#########################################################

require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class RSeqToolsWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for running 'RSEQtools'.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sai Lakshmi Subramanian(sailakss@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        @targetUri = @outputs[0]
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        
        ## Getting relevant variables from "context"
        @dbrcKey = @context['apiDbrcKey']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        
        @intermediateFilesDir = "#{@scratchDir}/intermediateFiles"
        `mkdir -p #{@intermediateFilesDir}`

        @subJobsScratch = "#{@scratchDir}/subJobsScratch"
        `mkdir -p #{@subJobsScratch}`

        # Set up format options coming from the UI
        @analysisName = @settings['analysisName']
        @coverageFactor = @settings['coverageFactor']
        
        @doUploadResults = @settings['doUploadResults']
        @deleteDupTracks = @settings['deleteDupTracks']

        ## Make sure the genome version is supported by 
        ## current implementation of this pipeline
        @genomeVersion = @settings['genomeVersion']
#        if(!@genomeVersion.nil?)
#          @gbBowtieGenomesInfo = JSON.parse(File.read(@genbConf.gbBowtieGenomesInfo))
#          @indexBaseName = @gbBowtieGenomesInfo[@genomeVersion]['indexBaseName']
          @gbRSeqToolsGenomesInfo = JSON.parse(File.read(@genbConf.gbRSeqToolsGenomesInfo))
          @geneAnnoIndexBaseName = @gbRSeqToolsGenomesInfo[@genomeVersion]['indexBaseName']
          
          if(@geneAnnoIndexBaseName.nil?)
            @errUserMsg = "The gene annotations for genome: #{@genomeVersion} could not be found since this genome is not supported currently.\nPlease contact the Genboree Administrator for adding support for this genome. "
            raise @errUserMsg
          end
#        end

        ## Index Options
        @useIndex = @settings['useIndex']

        ## If user selects resulting tracks to be uploaded, set up
        ## appropriate track variables
        if(@doUploadResults)
          @lffType = @settings['lffType'].strip
          @lffSubType = @settings['lffSubType'].strip
          @className = @settings['trackClassName'].strip
          @className = CGI.escape("#{@className}")
          @trackName = CGI.escape("#{@lffType}:#{@lffSubType}")
        else
          @lffType = "RSEQtoolsRead"
          @lffSubType = "RSEQtoolsDensity"
          @className = CGI.escape("RSEQtools User Data")
          @trackName = CGI.escape("#{@lffType}:#{@lffSubType}")
        end
        
        ## Get appropriate gene annotation merged transcripts
        @rseqtoolsKnownGeneAnnoDir = ENV['RSEQTOOLS_ANNOS']
        @genomeKnownGeneAnnoDir = "#{@rseqtoolsKnownGeneAnnoDir}/#{@geneAnnoIndexBaseName}"
        @knownGeneCompositeModel = "#{@genomeKnownGeneAnnoDir}/knownGene_composite.interval" 
        
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @apiUriHelper = BRL::Genboree::REST::Helpers::ApiUriHelper.new()
        if(@apiUriHelper.extractType(@outputs[0]) != "db" )
          @outputs.reverse!
        end

        #outputDb = @outputs[0]
        #prjDb = @outputs[1]  

        ###Checking db and proj irrespective of their order
        #if(@outputs[0] !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
        #  prjDb = @outputs[0]
        #  outputDb = @outputs[1]
        #end
        #@dbName = @dbApiHelper.extractName(outputDb)
        #@targetUri = URI.parse(outputDb)
        #@fullDbUri = outputDb
        #@projectName = @prjApiHelper.extractName(prjDb)
        #@projectUri = prjDb
        
        # Find db and redminePrj from @outputs
        outputDb = redminePrjUri = nil
        if(@outputs[0] =~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
          outputDb = @outputs[0]
          redminePrjUri = @outputs[1]
        else
          redminePrjUri = @outputs[0]
          outputDb = @outputs[1]
        end

        @dbName = @dbApiHelper.extractName(outputDb)
        @targetUri = URI.parse(outputDb)
        @fullDbUri = outputDb
        @redminePrjUri = redminePrjUri

      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. \n"
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the script
    # [+returns+] nil
    def run()
      begin
        @user = @pass = nil
        @outFile = @errFile = ""
        if(@dbrcKey)
          dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
          # get super user, pass and hostname
          @user = dbrc.user
          @pass = dbrc.password
        else
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(@genbConf, @dbrcFile)
          @user = suDbDbrc.user
          @pass = suDbDbrc.password
        end
       
        ##### *******************************************
        ####    Perform quality control of FastQ files using FastQC. 
        ####    Create FastQC job conf file and call the wrapper
        ##### *******************************************
        @outFile = "#{@scratchDir}/rseqtools.out"
        @errFile = "#{@scratchDir}/rseqtools.err"

        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Creating FastQC job conf file.")
        createFastQCJobConf()
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running FastQC wrapper")
        foundErrorInFastQC = callFastQCWrapper()
  
        unless(foundErrorInFastQC)      
 
          ##### *******************************************
          ####    Align reads using Bowtie 2. 
          ####    Create Bowtie job conf file and call the wrapper
          ##### *******************************************
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Creating Bowtie 2 job conf file.")
          createBowtieJobConf()
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Running Bowtie 2 wrapper")
          foundErrorInBowtie = callBowtieWrapper()
          
          unless(foundErrorInBowtie)

            ##### *******************************************
            ####       Postprocessing alignment - SAMTOOLS
            ##### *******************************************
            @alignedSam = "#{@bowtieResultsDir}/#{CGI.escape(@analysisName)}_aligned.sam"
            if(!@alignedSam)
              @errUserMsg = "Could not find SAM Alignment. Bowtie 2 did not produce any alignments.\n Please contact Genboree administrator.\n"
              raise "SAM alignment is not found. Contact Genboree admin for more information. "
            end
            
            # Convert SAM to BAM using Samtools
            sam2bam()

            # Convert BAM to mapped BAM using Samtools
            bam2mappedBam()

            # Sort Mapped BAM file using Samtools
            sortBam()

            # Generate sorted SAM file back from the Sorted Mapped BAM file using Samtools
            sortedBam2sam()
           
            ##### ***************************************
            ####       RSEQtools - Downstream Analysis
            ##### ***************************************

            # Convert SAM to MRF format using RSEQtools
            sam2mrf()
           
            # Make wig files of mapped reads - Tracks for visualization
            mrf2wig()
            
            # Make GFF files of mapped reads 
            mrf2gff()
            
            # Find if there is any mapping bias
            mrfMappingBias()
           
            # Upload tracks to server
            uploadTracks()  
            
            # Calculate gene expression values using composite gene models
            createMrfQuantifierJobConf()
            foundErrorInMrfQuantifier = callMrfQuantifierWrapper()
          
            unless(foundErrorInMrfQuantifier)
              # Calculate annotation coverage using composite gene models
              createMrfAnnotationCoverageJobConf()
              foundErrorInMrfAnnotationCoverage = callMrfAnnotationCoverageWrapper()

              unless(foundErrorInMrfAnnotationCoverage)
                # Upload result files to server
                uploadResults()
       
                ## ALL DONE 
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE RSEQtools.")
                ## DONE RSEQtools
              end # unless(foundErrorInMrfAnnotationCoverage)       
            end # unless(foundErrorInMrfQuantifier)       
          end # unless(foundErrorInBowtie)       
        end # unless(foundErrorInFastQC)      

      @keepPatterns = ["subJobsScratch/*/*.err","subJobsScratch/*/*.out","subJobsScratch/*/*.log","subJobsScratch/*/*.error"]
      cleanUp(@keepPatterns)
      
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Running of RSEQtools Pipeline failed (#{err.message.inspect})." if(@errUserMsg.nil?)
        @errInternalMsg = "ERROR: Unexpected error trying to run RSEQtools Pipeline." if(@errInternalMsg.nil?)
        @exitCode = 30
      end
      return @exitCode
    end

###### *****************************
###### Methods used in this workflow
###### *****************************

    ### Method to create FastQC jobFile.json
    def createFastQCJobConf()
      @fastQCJobConf = @jobConf.deep_clone()
     
      ## Define context 
      @fastQCJobConf['context']['toolIdStr'] = "fastQC"
      @fastQCScratchDir = "#{@subJobsScratch}/fastQCOutput"
      @fastQCJobConf['context']['scratchDir'] = @fastQCScratchDir
      
      ## Create job specific scratch and results directories
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Making FastQC scratch dir")
      `mkdir -p #{@fastQCScratchDir}`
      
      ## Define settings
      @fastQCJobConf['settings']['casava'] = false
      @fastQCJobConf['settings']['suppressEmail'] = "true"

      ## Write jobConf hash to tool specific jobFile.json
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Writing job conf hash to FastQC jobfile #{@fastQCScratchDir}/fastQCJobFile.json")
      @fastQCJobFile = "#{@fastQCScratchDir}/fastQCJobFile.json"
      File.open(@fastQCJobFile,"w") do |fastQCJob|
        fastQCJob.write(JSON.pretty_generate(@fastQCJobConf))
      end
    end

    ## Method to call FastQC wrapper
    def callFastQCWrapper()
      outFileFromFastQC = "#{@fastQCScratchDir}/fastQC.out"
      errFileFromFastQC = "#{@fastQCScratchDir}/fastQC.err"
      command = "cd #{@fastQCScratchDir}; fastQCWrapper.rb -j #{@fastQCJobFile} >> #{@outFile} 2>> #{@errFile} "
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "FastQC wrapper command completed with exit code: #{statusObj.exitstatus}")
      foundError = findError(exitStatus,outFileFromFastQC,errFileFromFastQC)
      
      return foundError
    end
        
    ### Method to create Bowtie jobFile.json
    def createBowtieJobConf()
      @bowtieJobConf = @jobConf.deep_clone()
     
      ## Define context 
      @bowtieJobConf['context']['toolIdStr'] = "bowtie"
      @bowtieScratchDir = "#{@subJobsScratch}/bowtieOutput"
      @bowtieJobConf['context']['scratchDir'] = @bowtieScratchDir
      
      @bowtieResultsDir = "#{@intermediateFilesDir}/bowtieResults"
      
      ## Create job specific scratch and results directories
      `mkdir -p #{@bowtieScratchDir} #{@bowtieResultsDir}`
      
      ## Define outputs
      @bowtieJobConf['outputs'] = [@bowtieResultsDir]
      
      ## Make sure the genome is currently supported
      @genomeVersion = @settings['genomeVersion']

      ## Define settings
      @bowtieJobConf['settings']['doUploadResults'] = false
      @bowtieJobConf['settings']['deleteDupTracks'] = "off"
      @bowtieJobConf['settings']['lffType'] = "Read"
      @bowtieJobConf['settings']['lffSubType'] = "Density"
      @bowtieJobConf['settings']['trackClassName'] = "User Data"
      @bowtieJobConf['settings']['alignmentType'] = "endToEnd"
      @bowtieJobConf['settings']['presetOption'] = "sensitive"
      @bowtieJobConf['settings']['skipNReads'] = "0"
      @bowtieJobConf['settings']['alignFirstNReads'] = ""
      @bowtieJobConf['settings']['trimNBasesAt5prime'] = "0"
      @bowtieJobConf['settings']['trimNBasesAt3prime'] = "0"
      @bowtieJobConf['settings']['disallowGapsWithin'] = "4"
      @bowtieJobConf['settings']['strandDirection'] = "both"
      @bowtieJobConf['settings']['reportAlnsPerRead'] = "1"
      @bowtieJobConf['settings']['noUnalignedSamRecord'] =  "on"
      @bowtieJobConf['settings']['suppressEmail'] = "true"
      @bowtieJobConf['settings']['indexOutputs'] = @fullDbUri

      ## Write jobConf hash to tool specific jobFile.json
      @bowtieJobFile = "#{@bowtieScratchDir}/bowtieJobFile.json"
      File.open(@bowtieJobFile,"w") do |bowtieJob|
        bowtieJob.write(JSON.pretty_generate(@bowtieJobConf))
      end
    end

    ## Method to call Bowtie wrapper
    def callBowtieWrapper()
      outFileFromBowtie = "#{@bowtieScratchDir}/bowtie.out"
      errFileFromBowtie = "#{@bowtieScratchDir}/bowtie.err"
      command = "cd #{@bowtieScratchDir}; bowtieWrapper.rb -j #{@bowtieJobFile} >> #{@outFile} 2>> #{@errFile} "
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Bowtie wrapper command completed with exit code: #{statusObj.exitstatus}")
      foundError = findError(exitStatus,outFileFromBowtie,errFileFromBowtie)
      
      return foundError
    end
        
    ## Convert SAM to BAM using Samtools
    def sam2bam()
      @bamFile = "bowtieOutput_primary.bam"
      @sam2bamErrFile = "#{@scratchDir}/sam2bam.err"
      command = "samtools view -h -F 256 -S -b #{@alignedSam} -o #{@scratchDir}/#{@bamFile} 2>> #{@sam2bamErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@sam2bamErrFile}") > 0) # FAILED: sam2bam. Check stderr from this command.
        @errUserMsg = "Could not convert sam file to bam file using samtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from samtools: \n\n"
        errorReader = File.open("#{@sam2bamErrFile}")
        lineCount = 1        
        errorReader.each_line { |line|
          if(lineCount <= 12)
            @errUserMsg << "    #{line}"      
            lineCount += 1
          else
            @errUserMsg << "...."
            break
          end          
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 31
        raise
      end
      return @exitCode
    end

    ## Convert BAM to mapped BAM using Samtools
    def bam2mappedBam()
      @bamMappedFile = "bowtieOutput_primary_mapped.bam"
      @bamMappedErrFile = "#{@scratchDir}/bamMapped.err"
      command = "samtools view -h -F 12 -b #{@scratchDir}/#{@bamFile} -o #{@scratchDir}/#{@bamMappedFile} 2>> #{@bamMappedErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@bamMappedErrFile}") > 0) # FAILED: bamMapped. Check stderr from this command.
        @errUserMsg = "Could not convert bam to mapped bam file using samtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from samtools: \n\n"
        errorReader = File.open("#{@bamMappedErrFile}")
        lineCount = 1        
        errorReader.each_line { |line|
          if(lineCount <= 12)
            @errUserMsg << "    #{line}"      
            lineCount += 1
          else
            @errUserMsg << "...."
            break
          end          
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 32
        raise
      end
      return @exitCode
    end

    ## Sort Mapped BAM file using Samtools
    def sortBam()
      @bamMappedSortedFile = "bowtieOutput_primary_mapped_sorted.bam"
      @bamMappedSortedPrefix = "bowtieOutput_primary_mapped_sorted"
      @sortBamErrFile = "#{@scratchDir}/sortBam.err"
      command = "samtools sort -n #{@scratchDir}/#{@bamMappedFile} #{@scratchDir}/#{@bamMappedSortedPrefix} 2>> #{@sortBamErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@sortBamErrFile}") > 0) # FAILED: sortBam. Check stderr from this command.
        @errUserMsg = "Could not sort mapped bam file using samtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from samtools:\n\n"
        errorReader = File.open("#{@sortBamErrFile}")
        lineCount = 1        
        errorReader.each_line { |line|
          if(lineCount <= 12)
            @errUserMsg << "    #{line}"      
            lineCount += 1
          else
            @errUserMsg << "...."
            break
          end          
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 33
        raise
      end
      return @exitCode
    end

    ## Generate sorted SAM file back from the Sorted Mapped BAM file using Samtools
    def sortedBam2sam()
      @samSortedFile = "bowtieOutput_primary_mapped_sorted.sam"
      @samSortedErrFile = "#{@scratchDir}/samSorted.err"
      command = "samtools view -h #{@scratchDir}/#{@bamMappedSortedFile} -o #{@scratchDir}/#{@samSortedFile} 2>> #{@samSortedErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@samSortedErrFile}") > 0) # FAILED: samSorted. Check stderr from this command.
        @errUserMsg = "Could not convert sorted mapped bam back to sam file using samtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from samtools:\n\n"
        errorReader = File.open("#{@samSortedErrFile}")
        lineCount = 1        
        errorReader.each_line { |line|
          if(lineCount <= 12)
            @errUserMsg << "    #{line}"      
            lineCount += 1
          else
            @errUserMsg << "...."
            break
          end          
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 34
        raise
      end
      return @exitCode
    end

    ## Convert SAM to MRF format using RSEQtools
    def sam2mrf()
      @tmpMrfFile = "#{CGI.escape(@analysisName)}.mrf.tmp"
      @mrfFile = "#{CGI.escape(@analysisName)}.mrf"
      @sam2mrfErrFile = "#{@scratchDir}/sam2mrf.err"
      ## Update code to use new sam2mrf python script. Patch sent by Yale group
      command = "sam2mrf.py #{@scratchDir}/#{@samSortedFile} #{@scratchDir}/#{@tmpMrfFile} 2>> #{@sam2mrfErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@sam2mrfErrFile}") > 0) # FAILED: sam2mrf. Check stderr from this command.
        @errUserMsg = "Could not convert sam file to MRF using sam2mrf module in RSEQtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from RSEQtools:\n\n"
        errorReader = File.open("#{@sam2mrfErrFile}")
        lineCount = 1
        errorReader.each_line { |line|
          if(lineCount <= 12)
            @errUserMsg << "    #{line}"      
            lineCount += 1
          else
            @errUserMsg << "...."
            break
          end          
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 35
        raise
      end
      ## Sort MRF file
      command = "mrfSorter < #{@scratchDir}/#{@tmpMrfFile} > #{@scratchDir}/#{@mrfFile} 2>> #{@sam2mrfErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@sam2mrfErrFile}") > 0) # FAILED: sam2mrf. Check stderr from this command.
        @errUserMsg = "Could not generate sorted MRF file using mrfSorter module in RSEQtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from RSEQtools:\n\n"
        errorReader = File.open("#{@sam2mrfErrFile}")
        lineCount = 1        
        errorReader.each_line { |line|
          if(lineCount <= 12)
            @errUserMsg << "    #{line}"      
            lineCount += 1
          else
            @errUserMsg << "...."
            break
          end          
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 36
        raise
      end
      ## Remove temporary MRF file
      `rm #{@scratchDir}/#{@tmpMrfFile}`
      return @exitCode
    end

    ## Make wig files of mapped reads - Tracks for visualization
    def mrf2wig()
      @mrf2wigErrFile = "#{@scratchDir}/mrf2wig.err"
      command = "cat #{@scratchDir}/#{@mrfFile} | mrf2wig #{@scratchDir}/#{CGI.escape(@analysisName)} 2>> #{@mrf2wigErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@mrf2wigErrFile}") > 0) # FAILED: mrf2wig. Check stderr from this command.
        @errUserMsg = "Could not convert MRF file to wig using mrf2wig module in RSEQtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from RSEQtools:\n\n"
        errorReader = File.open("#{@mrf2wigErrFile}")
        lineCount = 1        
        errorReader.each_line { |line|
          if(lineCount <= 12)
            @errUserMsg << "    #{line}"      
            lineCount += 1
          else
            @errUserMsg << "...."
            break
          end          
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 37
        raise
      end
      return @exitCode
    end

    ## Make GFF files of mapped reads 
    def mrf2gff()
      @mrf2gffErrFile = "#{@scratchDir}/mrf2gff.err"
      command = "cat #{@scratchDir}/#{@mrfFile} | mrf2gff #{@scratchDir}/#{CGI.escape(@analysisName)} 2>> #{@mrf2gffErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@mrf2gffErrFile}") > 0) # FAILED: mrf2gff. Check stderr from this command.
        @errUserMsg = "Could not convert MRF file to GFF using mrf2gff module in RSEQtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from RSEQtools:\n\n"
        errorReader = File.open("#{@mrf2gffErrFile}")
        lineCount = 1        
        errorReader.each_line { |line|
          if(lineCount <= 12)
            @errUserMsg << "    #{line}"      
            lineCount += 1
          else
            @errUserMsg << "...."
            break
          end          
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 38
        raise
      end
      return @exitCode
    end

    ## Find if there is any mapping bias
    def mrfMappingBias()
      @mrfMappingBiasErrFile = "#{@scratchDir}/mrfMappingBias.err"
      @mappingBiasFile = "#{CGI.escape(@analysisName)}_mappingBias.txt"
      command = "cat #{@scratchDir}/#{@mrfFile} | mrfMappingBias #{@knownGeneCompositeModel} > #{@scratchDir}/#{@mappingBiasFile} 2>> #{@mrfMappingBiasErrFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      if(statusObj.exitstatus != 0 and File.size("#{@mrfMappingBiasErrFile}") > 0) # FAILED: mrfMappingBias. Check stderr from this command.
        @errUserMsg = "Could not get mapping bias from MRF file using mrfMappingBias module in RSEQtools,\nwhich exited with code #{statusObj.exitstatus}. Error message from RSEQtools:\n\n"
        errorReader = File.open("#{@mrfMappingBiasErrFile}")
        lineCount = 1        
        errorReader.each_line { |line|
          if(lineCount <= 12)
            @errUserMsg << "    #{line}"      
            lineCount += 1
          else
            @errUserMsg << "...."
            break
          end          
        }
        errorReader.close()
        @errUserMsg.chomp!
        @errUserMsg << "    \"\n\n"
        @exitCode = 39
        raise
      end
      return @exitCode
    end

    ## Method to upload tracks to the server
    def uploadTracks()
      # Convert the individual chromosome wig tracks into a single wig file for uploading to server 
      @outputWigFile = "#{CGI.escape(@analysisName)}_output.wig"
      `echo "track type=wiggle_0 name='#{@analysisName}_track'" > #{@scratchDir}/#{@outputWigFile}` 
      `grep -h -v "track type=wiggle_0" #{@scratchDir}/*_chr*.wig >> #{@scratchDir}/#{@outputWigFile}`
      
      @outputGffFile = "#{CGI.escape(@analysisName)}_output.gff"
      `cat #{@scratchDir}/*.gff >> #{@scratchDir}/#{@outputGffFile}`
      
      # Upload output signal track in wig format and mapped splice junction reads in gff format to user db
      # If the user has opted to delete existing tracks with matching names, we need to delete them from the target database before proceeding with the upload
      if(@deleteDupTracks)
        outputUri = URI.parse(@outputs[0])
        rsrcPath = outputUri.path
        apiCaller = WrapperApiCaller.new(outputUri.host, "#{rsrcPath}/trk/#{@trackName}", @userId)
        apiCaller.get()
        if(apiCaller.succeeded?) # Track exists, delete it
          apiCaller.delete()
          if(!apiCaller.succeeded?)
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to delete pre-existing track:#{@trackName.inspect} (during a re-attempt)\nAPI Response:\n#{apiCaller.respBody.inspect}")
            raise "Error: Could not delete pre-existing track: #{@trackName.inspect} (during a re-attempt) from target database."
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Pre-existing track: #{@trackName.inspect} deleted.")
          end
        end
      end

      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Uploading wig files to the server")
      if(@doUploadResults)
        uploadWig() 
        #createBigFilesJobConf()
        #callBigFilesWrapper()
      end
    end

    ## Upload wig files as tracks in User db
    def uploadWig()
      # Get the refseqid of the target database
      outputUri = URI.parse(@outputs[0])
      rsrcPath = outputUri.path
      rsrcPath << "?gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      apiCaller = WrapperApiCaller.new(outputUri.host, rsrcPath, @userId)
      apiCaller.get()
      resp = JSON.parse(apiCaller.respBody)
      uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
      uploadAnnosObj.refSeqId = resp['data']['refSeqId']
      uploadAnnosObj.groupName = @groupName
      uploadAnnosObj.userId = @userId
      uploadAnnosObj.jobId = @jobId
      uploadAnnosObj.className = CGI.unescape(@className)
      uploadAnnosObj.trackName = CGI.unescape(@trackName)
      uploadAnnosObj.outputs = @outputs
      begin
        uploadAnnosObj.uploadWig(CGI.escape(File.expand_path("#{@scratchDir}/#{@outputWigFile}")), false)
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        @errUserMsg = "FATAL ERROR: Could not upload result wig file to target database."
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise @errUserMsg
      end
      ## Create and upload bigwig
      begin
        uploadAnnosObj.wigToBigWig(CGI.escape(File.expand_path("#{@scratchDir}/#{@outputWigFile}")))        
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        @errUserMsg = "FATAL ERROR: Could not convert wig file to bigWig file and upload to the server.\n"
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise @errUserMsg
      end
      return
    end

    ## Method to create bigwig job conf file
    def createBigFilesJobConf()
      @bigFilesJobConf = @jobConf.deep_clone()
      
      @outputUri = URI.parse(@outputs[0])
      @outputUri.path = "#{@outputUri.path}/trk/#{@trackName}" 
      @wigTrack = @outputUri.to_s

      ## Define inputs
      @bigFilesJobConf['inputs'] = [@wigTrack]
     
      ## Define settings 
      @bigFilesJobConf['settings']['type'] = "bigwig"
      @bigFilesJobConf['settings']['suppressEmail'] = "true"

      ## Define context
      @bigFilesJobConf['context']['toolIdStr'] = "bigFiles"
      @bigFilesScratchDir = "#{@scratchDir}/subJobsScratch/bigFilesOutput"
      @bigFilesJobConf['context']['scratchDir'] = @bigFilesScratchDir

      ## Define outputs
      @bigFilesJobConf['outputs'] = [ ]
      
      ## Create job specific scratch and results directories
      `mkdir -p #{@bigFilesScratchDir}`
 
      ## Write jobConf hash to tool specific jobFile.json 
      @bigFilesJobFile = "#{@bigFilesScratchDir}/bigFilesJobFile.json"
      File.open(@bigFilesJobFile,"w") do |bigFilesJob|
        bigFilesJob.write(JSON.pretty_generate(@bigFilesJobConf))
      end
    end

    ## Method to call bigFiles tool wrapper to make bigwig file for the uploaded wig track
    ## This makes visualization easier for the user
    def callBigFilesWrapper()
      command = "cd #{@bigFilesScratchDir}; bigFilesWrapper.rb -j #{@bigFilesJobFile} >> #{@outFile} 2>> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      if(!exitStatus)
        @errUserMsg = "Could not run BigWig BigFiles Wrapper"
        raise "Command: #{command} died. Check #{@errFile} for more information. "
      end
    end

    ## Method to create MRF quantifier job conf file
    def createMrfQuantifierJobConf()
      @mrfQuantifierJobConf = @jobConf.deep_clone()
      
      ## Define inputs
      @mrfQuantifierJobConf['inputs'] = ["#{@scratchDir}/#{@mrfFile}"]
     
      ## Define settings 
      @mrfQuantifierJobConf['settings']['overlapType'] = "multipleOverlap"
      @mrfQuantifierJobConf['settings']['suppressEmail'] = "true"

      ## Define context
      @mrfQuantifierJobConf['context']['toolIdStr'] = "mrfQuantifier"
      @mrfQuantifierScratchDir = "#{@scratchDir}/subJobsScratch/mrfQuantifierOutput"
      @mrfQuantifierJobConf['context']['scratchDir'] = @mrfQuantifierScratchDir

      ## Define outputs
      @mrfQuantifierResultsDir = "#{@intermediateFilesDir}/mrfQuantifierResults"
      @mrfQuantifierJobConf['outputs'] = [@mrfQuantifierResultsDir]
      @geneExpressionFile = "#{CGI.escape(@analysisName)}_geneExpression.txt"
      
      ## Create job specific scratch and results directories
      `mkdir -p #{@mrfQuantifierScratchDir} #{@mrfQuantifierResultsDir}` 
 
      ## Write jobConf hash to tool specific jobFile.json 
      @mrfQuantifierJobFile = "#{@mrfQuantifierScratchDir}/mrfQuantifierJobFile.json"
      File.open(@mrfQuantifierJobFile,"w") do |mrfQuantifierJob|
        mrfQuantifierJob.write(JSON.pretty_generate(@mrfQuantifierJobConf))
      end
    end

    ## Method to call mrfQuantifier tool wrapper
    def callMrfQuantifierWrapper()
      outFileFromMrfQuantifier = @outFile # Since mrfQuantifier writes gene expression values to stdout 
      errFileFromMrfQuantifier = "#{@mrfQuantifierScratchDir}/mrfQuantifier.err"
      command = "cd #{@mrfQuantifierScratchDir}; mrfQuantifierWrapper.rb -j #{@mrfQuantifierJobFile} >> #{@outFile} 2>> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "MRF Quantifier wrapper command completed with exit code: #{statusObj.exitstatus}")
      foundError = findError(exitStatus,outFileFromMrfQuantifier,errFileFromMrfQuantifier)
      return foundError
    end

    ## Method to create MRF annotation coverage job conf file
    def createMrfAnnotationCoverageJobConf()
      @numReadsToSample = 500000
      @mrfAnnotationCoverageJobConf = @jobConf.deep_clone()
      
      ## Define inputs
      @mrfAnnotationCoverageJobConf['inputs'] = ["#{@scratchDir}/#{@mrfFile}"]
      
      ## Define settings
      @mrfAnnotationCoverageJobConf['settings']['readsToSample'] = @numReadsToSample
      @mrfAnnotationCoverageJobConf['settings']['suppressEmail'] = "true"

      ## Define context
      @mrfAnnotationCoverageJobConf['context']['toolIdStr'] = "mrfAnnotationCoverage"
      @mrfAnnotationCoverageScratchDir = "#{@scratchDir}/subJobsScratch/mrfAnnotationCoverageOutput"
      @mrfAnnotationCoverageJobConf['context']['scratchDir'] = @mrfAnnotationCoverageScratchDir
      
      ## Create job specific scratch and results directories
      `mkdir -p #{@mrfAnnotationCoverageScratchDir} #{@mrfAnnotationCoverageResultsDir}` 
      
      ## Define outputs
      @mrfAnnotationCoverageResultsDir = "#{@intermediateFilesDir}/mrfAnnotationCoverageResults"
      @mrfAnnotationCoverageJobConf['outputs'] = [@mrfAnnotationCoverageResultsDir]
      @coverageFile = "#{CGI.escape(@analysisName)}_coverage.txt"
  
      ## Write jobConf hash to tool specific jobFile.json 
      @mrfAnnotationCoverageJobFile = "#{@mrfAnnotationCoverageScratchDir}/mrfAnnotationCoverageJobFile.json"
      File.open(@mrfAnnotationCoverageJobFile,"w") do |mrfAnnotationCoverageJob|
        mrfAnnotationCoverageJob.write(JSON.pretty_generate(@mrfAnnotationCoverageJobConf))
      end
    end

    ## Method to call mrfAnnotationCoverage tool wrapper
    def callMrfAnnotationCoverageWrapper()
      outFileFromMrfAnnotationCoverage = @outFile # Since mrfAnnotationCoverage writes coverage values to stdout 
      errFileFromMrfAnnotationCoverage = "#{@mrfAnnotationCoverageScratchDir}/mrfAnnotationCoverage.err"
      command = "cd #{@mrfAnnotationCoverageScratchDir}; mrfAnnotationCoverageWrapper.rb -j #{@mrfAnnotationCoverageJobFile} >> #{@outFile} 2>> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
      exitStatus = system(command)
      statusObj = $?
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "MRF AnnotationCoverage wrapper command completed with exit code: #{statusObj.exitstatus}")
      foundError = findError(exitStatus,outFileFromMrfAnnotationCoverage,errFileFromMrfAnnotationCoverage)
      return foundError
    end

    ## Method to upload result files to the server
    def uploadResults()
      @finalOutputDir = "#{@scratchDir}/finalOutputDir"
      `mkdir -p #{@finalOutputDir}`

      ## Move all outputs into this dir, so it is easy for compressing
      system("mv #{@scratchDir}/#{@mrfFile} #{@scratchDir}/#{@bamMappedSortedFile} #{@scratchDir}/#{@samSortedFile} #{@scratchDir}/#{@mappingBiasFile} #{@mrfQuantifierResultsDir}/#{@geneExpressionFile} #{@mrfAnnotationCoverageResultsDir}/#{@coverageFile} #{@scratchDir}/*.wig #{@scratchDir}/*.gff  #{@fastQCScratchDir}/fastQC_* #{@finalOutputDir}/")
      
      # Compress output files to be transferred to user db
      @alignmentsOutputZip = "#{CGI.escape(@analysisName)}_alignments.zip"
      @resultsZip = "#{CGI.escape(@analysisName)}_results.zip"

      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Compressing outputs to create #{@alignmentsOutputZip} and #{@resultsZip} ")
      `cd #{@finalOutputDir}; zip -r #{@alignmentsOutputZip} #{@bamMappedSortedFile} #{@samSortedFile}`  
      `cd #{@finalOutputDir}; zip -r #{@resultsZip} #{@mrfFile} #{@mappingBiasFile} #{@geneExpressionFile} #{@coverageFile} *.wig *.gff fastQC_*/`  

      # Transfer output files to the user db
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Transferring compressed outputs to the server")
      transferFiles()

      # Finally, delete the wig file and compress all result files 
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Removing #{@scratchDir}/#{@outputWigFile}. Compressing all other files.")
      `rm -f #{@scratchDir}/#{@outputWigFile} ; gzip #{@scratchDir}/*.bam #{@subJobsScratch}/*/* #{@intermediateFilesDir}/*/* #{@finalOutputDir}/*`
    end

    ## Transfer output files to the user db
    def transferFiles()
      # Grab target URI by parsing output
      targetUri = URI.parse(@outputs[0])
      ## Upload compressed result files
      # Find resource path by tacking onto the end of target URI the smallRNA-specific information
      rsrcPath = "#{targetUri.path}/file/RSEQtools/{analysisName}/{outputFile}/data?"
      rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      # :analysisName => @analysisName
      # :outputFile => @alignmentsOutputZip
      # input is "#{@finalOutputDir}/#{@alignmentsOutputZip}"
      uploadFile(targetUri.host, rsrcPath, @userId, "#{@finalOutputDir}/#{@alignmentsOutputZip}", {:analysisName => @analysisName, :outputFile => @alignmentsOutputZip})
      # :outputFile => @resultsZip
      # input is "#{@finalOutputDir}/#{@resultsZip}"
      uploadFile(targetUri.host, rsrcPath, @userId, "#{@finalOutputDir}/#{@resultsZip}", {:analysisName => @analysisName, :outputFile => @resultsZip})
      ## Upload important result files directly for immediate view by user
      # :outputFile => @mappingBiasFile
      # input is "#{@finalOutputDir}/#{@mappingBiasFile}"
      uploadFile(targetUri.host, rsrcPath, @userId, "#{@finalOutputDir}/#{@mappingBiasFile}", {:analysisName => @analysisName, :outputFile => @mappingBiasFile})
      # :outputFile => @coverageFile
      # input is "#{@finalOutputDir}/#{@coverageFile}"
      uploadFile(targetUri.host, rsrcPath, @userId, "#{@finalOutputDir}/#{@coverageFile}", {:analysisName => @analysisName, :outputFile => @coverageFile})
      # :outputFile => @geneExpressionFile
      # input is "#{@finalOutputDir}/#{@geneExpressionFile}"
      uploadFile(targetUri.host, rsrcPath, @userId, "#{@finalOutputDir}/#{@geneExpressionFile}", {:analysisName => @analysisName, :outputFile => @geneExpressionFile})
      # uploadFile(targetUri.host, rsrcPath, @userId, "#{@finalOutputDir}/#{@outputGffFile}", {:analysisName => @analysisName, :outputFile => @outputGffFile}
    end

    ## Upload a given file to Genboree server
    def uploadFile(host, rsrcPath, userId, input, templateHash)
      # Call FileApiUriHelper's uploadFile method to upload current file
      retVal = @fileApiHelper.uploadFile(host, rsrcPath, userId, input, templateHash)
      # Set error messages if upload fails using @fileApiHelper's uploadFailureStr variable
      unless(retVal)
        @errUserMsg = @fileApiHelper.uploadFailureStr
        @errInternalMsg = @fileApiHelper.uploadFailureStr
        @exitCode = 38
        @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
        raise @err
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{input} uploaded successfully to server")
      end
      return
    end

    # Method to detect errors
    # @param [boolean] exitStatus indicating if the system() call "succeeded" or not.
    #   system() returns boolean, but if true can't be trusted for RSEQtools Pipeline.
    # @return [boolean] indicating if a RSEQtools Pipeline error was found or not.
    #                   if so, @errUserMsg, @errInternalMsg, @exitCode will be set appropriately
    def findError(exitStatus, toolOutFile, toolErrFile)
      retVal = false
      errorMessages = nil
      # Check the obvious things first. Outright failure or putting error messages on stderr:
      if(!exitStatus)
        # So far, so good. Look for ERROR lines on stdout that is written to outFile.
        cmd = "grep -hi \"error\" #{@outFile} #{@errFile} | grep -Pv \"(\.rb|Backtrace|NoMethod|rescue|RuntimeError|TypeError)\" " 
        errorMessages = `#{cmd}`

        ## look for errors in tool specific errFile and outFile, in this case from bowtie and fastqc
        if(toolErrFile and File.exist?(toolErrFile) and File.size("#{toolErrFile}") > 0)
          cmd = "grep -hi \"error\" #{toolErrFile} | grep -Pv \"(\.rb|Backtrace|NoMethod|rescue|RuntimeError|TypeError)\" "
          errorMessages << `#{cmd}`
        elsif(toolOutFile and File.exist?(toolOutFile) and File.size("#{toolOutFile}") >   0)
          cmd = "grep -hi \"error\" #{toolOutFile} | grep -Pv \"(\.rb|Backtrace|NoMethod|rescue|RuntimeError|TypeError)\" "
          errorMessages << `#{cmd}`
        end

        ## Case when user uploads 2 FASTQ files that are not paired end, bowtie provides an error message
        ## Convert that error message into an informative message to user
        if(errorMessages =~ /fewer reads in file specified with/)
          errorMessages = "The input files are not paired-end, one file has fewer reads than the other.\n If you upload 2 input files, please make sure they are paired-end FASTQ files with same number of reads.\n"
        end
      
        if(errorMessages =~ /Failed to download file completely after attempt number/)
          errorMessages = "The input file or Bowtie index file could not be downlaoded from the server, this could be due to a network problem. Please try again after sometime or contact Genboree admin.\n"
        end

        if(errorMessages.strip.empty?)
          retVal = false
        else
          retVal = true
        end
      end

      # Did we find anything?
      if(retVal)
        @errUserMsg = "RSEQtools Pipeline Failed. Message from RSEQtools Pipeline:\n\""
        @errUserMsg << (errorMessages || "[No error info available from RSEQtools Pipeline. Please contact Genboree admin for more details.]")
        @errUserMsg << "    \"\n\n"
        @errInternalMsg = @errUserMsg
        @exitCode = 30
      end
    end


############ END of methods specific to this RSEQtools wrapper

    def prepSuccessEmail()
      @settings = @jobConf['settings']

      if(@useIndex =~ /useExistingIndex/)
        indexList = @settings['indexList']
        indexName = File.basename(indexList)

        files = @fileApiHelper.extractName(indexList)
        fileString = files.gsub(/\//, " >> ")
        @settings.delete('indexList')
      end
       
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = @analysisName
      inputsText                = customBuildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.exitStatusCode = @exitCode
      additionalInfo = ""
      additionalInfo << "You can download result files from this location:\n" + 
                          "|-Group: '#{@groupName}'\n" +
                            "|--Database: '#{@dbName}'\n" +
                              "|---Files\n" +
                                "|----RSEQtools\n"+
                                  "|-----#{@analysisName}\n\n"
      if(!files.nil?) 
        additionalInfo << "  The Bowtie2 index file '#{indexName}' used in this analysis \n " + 
                          "  can be found at: \n" +
                          "  Files >> #{fileString} \n\n  " +
                          "  Tracks generated by this pipeline can be found under \"Tracks\" in your database.\n" +
                          "  These tracks can be readily viewed in the UCSC Genome Broswer using the \"View Tracks in UCSC Genome Browser\" \n" +
                          "  tool under \"Visualization\" menu in the toolbar. \n"
      end

      #projHost = URI.parse(@redminePrjUri).host
      #emailObject.resultFileLocations = "http://#{projHost}/java-bin/project.jsp?projectName=#{CGI.escape(@prjApiHelper.extractName(@projectUri))}"
      #emailObject.additionalInfo = additionalInfo
      return emailObject
    end

    def prepErrorEmail()
      emailObject               = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle,@userEmail,@jobId)
      emailObject.userFirst     = @userFirstName
      emailObject.userLast      = @userLastName
      emailObject.analysisName  = @analysisName
      inputsText                = customBuildSectionEmailSummary(@inputs)
      emailObject.inputsText    = inputsText
      outputsText               = buildSectionEmailSummary(@outputs)
      emailObject.outputsText   = outputsText
      emailObject.settings      = @jobConf['settings']
      emailObject.errMessage    = @errUserMsg
      emailObject.exitStatusCode = @exitCode
      return emailObject
    end

    def customBuildSectionEmailSummary(section)
      sectionHash = {}
      countDisplay = 1
      
      ##Only display 10 input items as max
      section.each { |file|
        uriObj = URI.parse(file)
        scheme = uriObj.scheme
        if(scheme =~ /file/)
          type = scheme
          baseName = File.basename(uriObj.path)
        else
          type = @apiUriHelper.extractType(file)
          baseName = @apiUriHelper.extractName(file)
        end
        sectionHash["#{countDisplay}. #{type.capitalize}"] = baseName
        # We want to display only 9 files and keep record if there are more than
        # 9,
        # which would be shown by "...."
        if(countDisplay == 9 and section.size > 9)
          sectionHash["99"] = "....."
          break
        end
        countDisplay += 1
      }
      return sectionHash
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::RSeqToolsWrapper)
end

