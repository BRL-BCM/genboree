#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/util/expander'
require 'brl/util/samTools'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/helpers/wgsMicrobiome/avpColInfo'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/convertText'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class WGSMicrobiomePipelineWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    REQUIRED_FIELDS = ['#name', '#FP-1_1', '#FP-1_2', '#HOST', '#GROUP', '#DB', '#FOLDER']
    SEQ_IMPORT_T_FILES = [
                          'seq_import/{sample}_1.fastq.gz',
                          'seq_import/{sample}_2.fastq.gz',
                          'seq_import/{sample}_single.fastq.gz',
                          'seq_import/{sample}_qc'
                        ]
    TAX_ABUN_T_FILES = ['metaphlan/{sample}-metaphlan.txt']
    DIGNORM_T_FILES = [
                        'digiNorm_assembly_findORFs/{sample}-digiNorm_metrics.tsv' ,
                        'digiNorm_assembly_findORFs/{sample}_shuffle_w_single_reads.fastq.keep.abundfilt.keep.pe.zip' ,
                        'digiNorm_assembly_findORFs/{sample}_shuffle_w_single_reads.fastq.keep.abundfilt.keep.se.zip' ,
                        'digiNorm_assembly_findORFs/UnusedReads.fa.filtered.zip' ,
                        'digiNorm_assembly_findORFs/contigs.fa.metrics' ,
                        'digiNorm_assembly_findORFs/contigs.fa.zip' ,
                        'digiNorm_assembly_findORFs/proba.contig.cvg.zip' ,
                        'digiNorm_assembly_findORFs/proba.faa.zip' ,
                        'digiNorm_assembly_findORFs/proba.fna.zip' ,
                        'digiNorm_assembly_findORFs/proba.gene.cvg.zip' ,
                        'digiNorm_assembly_findORFs/proba.orfs.zip' ,
                        'digiNorm_assembly_findORFs/proba.seq100.contig.zip' ,
                        'digiNorm_assembly_findORFs/stats.txt.zip' 
                      ]
    FUNC_ANNOT_DT_FILES = {
      
                            'provenance.txt' => nil
      
    }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used to run Kevin Riehle's WGS Microbiome Pipeline scripts. It is intended to be called from the workbench.",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
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
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @toolScriptPrefix = @context['toolScriptPrefix']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        @scratchDir = @context['scratchDir']
        @trkName = "#{@lffType}:#{@lffSubType}"
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
        @analysisName = @settings['analysisName']
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
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
        # Download the metadata file
        fileList = {}
        samples = {}
        uriObj = URI.parse(@inputs[0])
        metadata = CGI.escape(File.basename(@fileApiHelper.extractName(@inputs[0])))
        ff = File.open(metadata, 'w')
        apiCaller = WrapperApiCaller.new(uriObj.host, "#{uriObj.path}/data?", @userId)
        apiCaller.get() { |chunk| ff.print(chunk)}
        ff.close()
        # Go through the meta data file and download all the files
        rr = File.open(metadata)
        lcount = 0
        nameIdx = 0
        initHashes()
        # Create the dir on the shared space
        outputDir = BRL::Genboree::Tools::ToolWrapper.networkScratchDir(@jobId)
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Creating dir: #{outputDir}")
        `mkdir -p #{outputDir}`
        if($?.exitstatus != 0)
          raise "Could not create shared dir."
        end
        `mkdir -p #{outputDir}/scratch`
         # Make a link to the shared output dir
        `ln -s #{outputDir} #{@jobId}`
        rr.each_line { |line|
          line.strip!
          next if(line.empty?)
          cols = line.split(/\t/)
          if(lcount == 0) # Get the idx of some of the columns (mostly pertaining to files)
            cols.each_index { |ii|
              if(@targetInfoHash.key?(cols[ii]))
                @targetInfoHash[cols[ii]] = ii
              elsif(@fileColsHash.key?(cols[ii]))
                @fileColsHash[cols[ii]] = ii
              else
                if(cols[ii] =~ /^#FP-\d+_\d+$/ or cols[ii] =~ /^#SRA-\d+$/ or cols[ii] =~ /^#SE-\d+$/)
                  @fileColsHash[cols[ii]] = ii
                else
                  nameIdx = ii if(cols[ii] == '#name')
                end
              end
              @colIdxHash[ii] = cols[ii]
            }
          else # Loop over the data recs and download all the files to run the pipeline
            samples[cols[nameIdx]] = {}
            @fileColsHash.each_key { |fileType|
              fileName = CGI.escape(cols[@fileColsHash[fileType]])
              fileList[fileName] = nil
              fileRsrcPath = getFileRsrcPath(cols, fileName)
              host = cols[@targetInfoHash['#HOST']]
              fw = File.open(fileName, 'w')
              apiCaller = WrapperApiCaller.new(host, "#{fileRsrcPath}/data?", @userId)
              apiCaller.get() { |chunk| fw.print(chunk) }
              fw.close()
              `mv #{fileName} #{outputDir}`
            }
          end
          lcount += 1
        }
        # Go through the metadata file and add CLUSTER to some of the fields
        fw = File.open("#{metadata}.final", 'w')
        @avpColInfoObj = BRL::Genboree::Helpers::WgsMicrobiome::AvpColInfo.new()
        attributes = {}
        rr.rewind()
        lcount = 0
        rr.each_line { |line|
          line.strip!
          next if(line.empty?)
          cols = line.split(/\t/)
          if(lcount == 0)
            cols.each_index { |ii|
              if(!@fileColsHash.key?(cols[ii]))
                fw.print(cols[ii])
              else
                fw.print("CLUSTER#{cols[ii]}")
              end
              fw.print("\t") if(ii < (cols.size - 1 ))
            }
            fw.print("\tCLUSTER#O\tCLUSTER#U") # This hack is required right now since the command for the 4th step is not constructed from the 'post-assembly tsv file'
            fw.print("\n")
          else
            folderEncountered = false
            sampleName = cols[nameIdx]
            cols.each_index { |ii|
              colAlias = @avpColInfoObj.attributeForColumn(@colIdxHash[ii])
              attributes[colAlias] = nil if(colAlias and !colAlias.empty?)
              if(!fileList.key?(cols[ii]))
                if(@targetInfoHash['#FOLDER'] == ii)
                  folder = cols[ii]
                  if(folder.nil? or folder.empty?)
                    fw.print('/') 
                  else
                    fw.print(folder)
                  end
                  folderEncountered = true
                else
                  if(ii == nameIdx)
                    fw.print(CGI.escape(cols[ii]))
                  else
                    fw.print(cols[ii])
                  end
                end
                if(colAlias and !colAlias.empty?)
                  samples[sampleName][colAlias] = cols[ii] 
                  attributes[colAlias] = nil
                end
              else
                fw.print("#{outputDir}/#{cols[ii]}")
                if(colAlias and !colAlias.empty?)
                  fileRsrcPath = getFileRsrcPath(cols, CGI.escape(cols[ii]))
                  host = cols[@targetInfoHash['#HOST']]
                  fileUri = "http://#{host}#{fileRsrcPath}?"
                  if(!samples[sampleName].key?(colAlias))
                    samples[sampleName][colAlias] = fileUri
                  else
                    samples[sampleName][colAlias] << ",#{fileUri}"                    
                  end
                end           
              end
              fw.print("\t") if(ii < (cols.size - 1 ))
            }
            unless(folderEncountered) # FOLDER must be the last column
              fw.print("\t/")
            end
            fw.print("\t#{outputDir}/#{CGI.escape(sampleName)}/digiNorm_assembly_findORFs/proba.fna.zip\t#{outputDir}/#{CGI.escape(sampleName)}/digiNorm_assembly_findORFs/UnusedReads.fa.filtered.zip")
            fw.print("\n")
          end
          lcount += 1
        }
        rr.close()
        fw.close()
        `cp #{metadata}.final #{outputDir}/#{metadata}.final`
        # Run the pipeline
        wgsCmd = "module load wgsMicrobiomePipeline/0.1; WGS_construct_cmds.rb -m #{outputDir}/#{metadata}.final -t #{outputDir}/scratch "
        wgsCmd << " -1 " if(@settings.key?('--importSequencesFlag'))
        wgsCmd << " -2 " if(@settings.key?('--metaphlanFlag'))
        wgsCmd << " -3 " if(@settings.key?('--digiNormAssemblyORFflag'))
        wgsCmd << " -4 " if(@settings.key?('--functionalAnnotationFlag'))
        if(@settings['--host'] == 'hg19')
          wgsCmd << " -o #{outputDir} -k #{@genbConf.wgsMicrobiomeKeggDb_hg19} -d #{@genbConf.wgsMicrobiomeBowtie2Db_hg19}  "
        end
        wgsCmd << " --minQual #{@settings['--minQual']} " if(@settings.key?('--minQual'))
        wgsCmd << " --minSeqLen #{@settings['--minSeqLen']} " if(@settings.key?('--minSeqLen'))
        wgsCmd << " --dontQualityFilterFlag " if(@settings.key?('--dontQualityFilterFlag'))
        wgsCmd << " --eValCutoffUnassembledReads=#{@settings['--eValCutoffUnassembledReads']} " if(@settings.key?('--eValCutoffUnassembledReads'))
        wgsCmd << " --eValCutoffORFs=#{@settings['--eValCutoffORFs'].to_f.to_noSciNotationStr} " if(@settings.key?('--eValCutoffORFs'))
        wgsCmd << "> #{outputDir}/wgs.out 2> #{outputDir}/wgs.err"
        $stderr.debugPuts(__FILE__, __method__, "RUNNING", "#{wgsCmd.inspect}")
        `#{wgsCmd}`
        if($?.exitstatus != 0)
          raise File.read('wgs.err')
        else
          wgsCmd2 = "module load wgsMicrobiomePipeline/0.1; cluster_conditional_job_wrapper.rb -s #{outputDir}/scripts.txt -r #{outputDir}/resources.txt -l #{outputDir}/logs > #{outputDir}/full_wrapper_progress.log 2>&1"
          $stderr.debugPuts(__FILE__, __method__, "RUNNING", "#{wgsCmd2.inspect}")
          `#{wgsCmd2}`
          if($?.exitstatus != 0)
            raise File.read('full_wrapper_progress.log')
          end
        end
        # Transfer files to the workbench
        transferFiles(outputDir, samples.keys)
        linkSample2Attrs(samples, attributes, outputDir)
        $stderr.puts "All Done!"
      rescue => err
        @err = err
        @errUserMsg = err.message
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      ensure
        # Compress all the files that were downloaded if some of them already aren't
        fileList.each_key { |file|
          exp = nil
          filePath = "#{outputDir}/#{file}"
          if(File.exists?(filePath))
            exp = BRL::Util::Expander.new(filePath)
            `gzip #{filePath}` if(!exp.isCompressed?)
          end
        }
      end
      return @exitCode
    end
    
    # Send success email
    # [+returns+] emailObj
    def prepSuccessEmail()
      additionalInfo = "The output files have been copied to the #{@analysisName} directory under the WGS Microbiome Pipeline folder in the target database. "
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return successEmailObject
    end

    # Send failure/error email
    # [+returns+] emailObj
    def prepErrorEmail()
      additionalInfo = "     Error:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return errorEmailObject
    end
    
    
    
    ####################################
    # Helper methods
    ####################################
    def getFileRsrcPath(cols, fileName)
      grp = CGI.escape(cols[@targetInfoHash['#GROUP']])
      db = CGI.escape(cols[@targetInfoHash['#DB']])
      folder = cols[@targetInfoHash['#FOLDER']]
      filePath = ""
      if(folder.nil? or folder.empty? or folder == '/')
        filePath = fileName
      else
        folder.split('/').each { |dir|
          filePath << "#{CGI.escape(dir)}/"   
        }
        filePath << fileName
      end
      return "/REST/v1/grp/#{grp}/db/#{db}/file/#{filePath}"
    end
    
    
    # Write the sample-attribute data to a file and upload
    # @samples [Hash] Hash table linking sample names with their avps
    # @attributes [Hash] Hash table with attribute names as keys
    def linkSample2Attrs(samples, attributes, outputDir)
      ww = File.open('sampleAttr.txt', 'w') 
      ww.print("#")
      ww.print(attributes.keys.join("\t"))
      ww.print("\t#{@avpColInfoObj.attributeForColumn("CLUSTER#_1")}\t#{@avpColInfoObj.attributeForColumn("CLUSTER#_2")}")
      if(attributes.key?('wgsSingleEnd'))
        ww.print("\t#{@avpColInfoObj.attributeForColumn("CLUSTER#_S")}")
      end
      if(@settings.key?('--metaphlanFlag'))
        ww.print("\t#{@avpColInfoObj.attributeForColumn("CLUSTER#M")}")
      end
      if(@settings.key?('--digiNormAssemblyORFflag'))
        ww.print("\t#{@avpColInfoObj.attributeForColumn("CLUSTER#O")}\t#{@avpColInfoObj.attributeForColumn("CLUSTER#U")}")
      end
      ww.print("\n")
      uriObj = URI.parse(@outputs[0])
      fileUriPathPrefix = "http://#{uriObj.host}#{uriObj.path}/file/WGS%20Microbiome%20Pipeline/#{CGI.escape(@analysisName)}"
      apiCaller = WrapperApiCaller.new(uriObj.host, "", @context['userId'])
      samples.each_key { |sample|
        ii = 0
        attributes.keys.each { |attr|
          if(ii == 0)
            ww.print(samples[sample][attr])
          else
            ww.print("\t#{samples[sample][attr]}")
          end
          sample = CGI.escape(sample)
          apiCaller.setRsrcPath("#{uriObj.path}/sample/#{sample}/attribute/#{attr}?")
          apiCaller.delete()
          ii += 1
        }
        apiCaller.setRsrcPath("#{uriObj.path}/sample/#{sample}/attribute/#{@avpColInfoObj.attributeForColumn("CLUSTER#_1")}?")
        apiCaller.delete()
        apiCaller.setRsrcPath("#{uriObj.path}/sample/#{sample}/attribute/#{@avpColInfoObj.attributeForColumn("CLUSTER#_2")}?")
        apiCaller.delete()
        ww.print("\t#{fileUriPathPrefix}/seq_import/#{sample}_1.fastq.gz\t#{fileUriPathPrefix}/seq_import/#{sample}_2.fastq.gz")
        if(attributes.key?('wgsSingleEnd'))
          apiCaller.setRsrcPath("#{uriObj.path}/sample/#{sample}/attribute/#{@avpColInfoObj.attributeForColumn("CLUSTER#_S")}?")
          apiCaller.delete()
          ww.print("\t#{fileUriPathPrefix}/seq_import/#{sample}_single.fastq.gz")
        end
        if(@settings.key?('--metaphlanFlag'))
          apiCaller.setRsrcPath("#{uriObj.path}/sample/#{sample}/attribute/#{@avpColInfoObj.attributeForColumn("CLUSTER#M")}?")
          apiCaller.delete()
          ww.print("\t#{fileUriPathPrefix}/metaphlan/#{sample}-metaphlan.txt")
        end
        if(@settings.key?('--digiNormAssemblyORFflag'))
          apiCaller.setRsrcPath("#{uriObj.path}/sample/#{sample}/attribute/#{@avpColInfoObj.attributeForColumn("CLUSTER#O")}?")
          apiCaller.delete()
          apiCaller.setRsrcPath("#{uriObj.path}/sample/#{sample}/attribute/#{@avpColInfoObj.attributeForColumn("CLUSTER#U")}?")
          apiCaller.delete()
          ww.print("\t#{fileUriPathPrefix}/digiNorm_assembly_findORFs/#{sample}_proba.fna.zip\t#{fileUriPathPrefix}/digiNorm_assembly_findORFs/#{sample}_UnusedReads.fa.filtered.zip")
        end
        ww.print("\n")
      }
      ww.close()
      apiCaller.setRsrcPath("#{uriObj.path}/samples?format=tabbed")
      apiCaller.put({}, File.open('sampleAttr.txt'))
      $stderr.puts "apiCaller resp for uploading samples: #{apiCaller.parseRespBody}"
    end
    
    # Transfer some of the output files from the pipeline back to the workbench.
    # @outputDir full path to the shared output dir
    # @samples An array of the sample names
    # @returns nil
    def transferFiles(outputDir, samples)
      # Instantiate the ApiCaller since the target db is going to be constant
      uriObj = URI.parse(@outputs[0])
      dbRsrcPath = uriObj.path
      apiCaller = WrapperApiCaller.new(uriObj.host, "", @context['userId'])
      filePathPrefix = "#{dbRsrcPath}/file/WGS%20Microbiome%20Pipeline/#{CGI.escape(@analysisName)}"
      ( SEQ_IMPORT_T_FILES + TAX_ABUN_T_FILES + DIGNORM_T_FILES ).each { |file| # Some of the files may not be there depending on which steps were run
        samples.each { |sample|
          escSample = CGI.escape(sample)
          realFileName = file.gsub(/\{sample\}/, escSample)
          filePath = "#{outputDir}/#{escSample}/#{realFileName}" 
          if(File.exists?(filePath))
            fileBase = File.basename(realFileName)
            if(fileBase !~ /^#{escSample}/)
              fileBase = "#{escSample}_#{fileBase}"
              realFileName.gsub!(File.basename(realFileName), fileBase)
            end
            if(!File.directory?(filePath))
              apiCaller.setRsrcPath("#{filePathPrefix}/#{realFileName}/data?")
              apiCaller.put({}, File.open(filePath))
            else # Folder
              fileStr = `find #{filePath} -type f -name '*'`
              fileStr.each_line { |line|
                line.strip!
                fileBase = line.split(realFileName)[1]
                apiCaller.setRsrcPath("#{filePathPrefix}/#{realFileName}#{fileBase}/data?")
                apiCaller.put({}, File.open(line))
              }
            end
          end
        }
      }
      # Transfer the functional annotation files (if any)
      samples.each { |sample|
        escSample = CGI.escape(sample)
        fileStr = `find #{outputDir}/#{escSample}/functionalAnnotation -type f -name '*'`
        if(fileStr and !fileStr.empty?)
          fileStr.each_line { |line|
            line.strip!
            fileBase = File.basename(line)
            if(!FUNC_ANNOT_DT_FILES.key?(fileBase))
              if(fileBase !~ /^#{escSample}/)
                fileBase = "#{escSample}_#{fileBase}"
              end
              apiCaller.setRsrcPath("#{filePathPrefix}/functionalAnnotation/#{fileBase}/data?")
              apiCaller.put({}, File.open(line))
            end
          }
        end
      }
      # Transfer the files generated by the metaphlan report script
      metaphlanRepFiles = `find #{outputDir}/reports -type f -name '*'`
      if(metaphlanRepFiles and !metaphlanRepFiles.empty?)
        metaphlanRepFiles.each_line { |line|
          line.strip!
          apiCaller.setRsrcPath("#{filePathPrefix}/reports#{line.split('reports')[1]}/data?")
          apiCaller.put({}, File.open(line))
        }
      end
    end
    
    def initHashes()
      @targetInfoHash = {
                '#FOLDER' => nil,
                '#GROUP' => nil,
                "#DB" => nil,
                "#HOST" => nil
              }
      @fileColsHash = {
        "#FP-1_1" => nil,
        "#FP-1_2" => nil
      }
      @colIdxHash = {}
    end


    

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::WGSMicrobiomePipelineWrapper)
end
