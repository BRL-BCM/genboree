#!/usr/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/util/convertText'
require 'brl/util/vcfParser'
require 'brl/fileFormats/LFFValidator'
require 'brl/cache/helpers/dnsCacheHelper'
require 'brl/cache/helpers/domainAliasCacheHelper'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/tools/toolWrapper'
require 'brl/genboree/tools/wrapperEmailer'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/helpers/sniffer'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class UploadTrackAnnosWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    include BRL::Cache::Helpers::DNSCacheHelper
    include BRL::Cache::Helpers::DomainAliasCacheHelper

    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for uploading annotations as tracks in Genboree. This script will evoke the relevant script/program depending on the format.
                        This tool is intended to be called via the Genboree Workbench",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Make some the variables as attr accessors so that this class can be used as a library and not just as a script. 
    attr_accessor :refSeqId
    attr_accessor :groupName
    attr_accessor :userId
    attr_accessor :targetDbUri
    attr_accessor :jobId
    attr_accessor :trackName
    attr_accessor :outFile
    attr_accessor :errFile
    attr_accessor :outputs
    attr_accessor :skipNAChr
    attr_accessor :skippedLines
    attr_accessor :skippedBlocks
    attr_accessor :className
    attr_accessor :specialAttrs # Must be hash table with attribute-value pairs

    # Extract the relevant information to run the job
    # [+returns+] nil
    def processJobConf()
      begin
        @targetUri = @outputs[0]
        dbrcFile = File.expand_path(ENV['DBRC_FILE'])
        @dbrcKey = @context['apiDbrcKey']
        @deleteSourceFiles = @settings['deleteSourceFiles']
        @adminEmail = @context['gbAdminEmail']
        @userId = @context['userId']
        @jobId = @context['jobId']
        @jobId = 0 unless @jobId
        @userEmail = @context['userEmail']
        @userLogin = @context['userLogin']
        @toolScriptPrefix = @context['toolScriptPrefix']
        @userFirstName = @context['userFirstName']
        @userLastName = @context['userLastName']
        dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
        @user = dbrc.user
        @pass = dbrc.password
        @host = dbrc.driver.split(/:/).last
        @scratchDir = @context['scratchDir']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)

        # Set up format options coming from the UI
        @format = @settings['inputFormat'].to_s.strip
        @format = 'bedGraph' if(@format =~ /^bedgraph$/i)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "File Format: #{@format.inspect}")
        
        @trackName = nil
        if(@format != 'lff' and @format != 'vcf' and @format != 'gff3') # No Track name coming from the UI
          @lffType = @settings['lffType'].strip
          @lffSubType = @settings['lffSubType'].strip
          @trackName = "#{@lffType}:#{@lffSubType}"
        end
        # allow bed, bedGraph formats to have a 1-based closed coordinate system despite their specification
        # big is included in this category since files labelled as bigWig may actually be bigBed or bigBedGraph
        if(@format == 'bed' or @format == 'bedGraph' or @format =~ /^big/i)
          # ui defaults to automatically determine based on the file format
          # for these formats, that is 0-based
          @coordSystem = @settings['radioGroup_coordSystem_btn'] =~ /1 based/ ? "1" : "0"
        end
        @makeBigwig = "off"
        if(@format == 'wig')
          @makeBigwig = @settings['makeBigwig']
        end
        
        @histTracks = @settings['histTracks']
        @segAnalysis = @settings['segAnalysis']
        @minProbesPerSeg = @settings['minProbesPerSeg']
        @segLogRatio = @settings['segLogRatio']
        @segAnalysisRadio = @settings['segAnalysisRadio']
        if(@settings['Skip non-assembly chromosomes'] and @settings['Skip non-assembly chromosomes'] == 'on')
          @skipNAChr = true
        else
          @skipNAChr = false
        end
        if(@settings['Skip out-of-range annotations'] and @settings['Skip out-of-range annotations'] == 'on')
          @skipOORAnnos = true
        else
          @skipOORAnnos = false
        end
        @transformEncoding = false
        @transformEncoding = true if(@settings['Convert NON-ASCII files to ASCII before processing'] and @settings['Convert NON-ASCII files to ASCII before processing'] == 'on')
        @lffSubType = @settings['subtype'] if(@format == 'vcf')
        @groupName = @grpApiHelper.extractName(@outputs[0])
        @dbName = @dbApiHelper.extractName(@outputs[0])
        checkTrackClassName()
        @specialAttrs = {}
      rescue => err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = err
        @errBacktrace = err.backtrace.join("\n")
        @exitCode = 22
      end
      return @exitCode
    end

    # Runs the application
    # [+returns+] nil
    def run()
      begin
        fileBase = "#{@format}_upload"
        command = ""
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
        # Download the input file from the server
        fileBase = File.basename(@fileApiHelper.extractName(@inputs[0]))
        tmpFile = "#{@scratchDir}/#{CGI.escape(fileBase)}"
        ww = File.open(tmpFile, "w")
        inputUri = URI.parse(@inputs[0])
        targetUri = URI.parse(@outputs[0])
        rsrcUri = "#{inputUri.path}/data?"
        rsrcUri << "gbKey=#{@dbApiHelper.extractGbKey(@inputs[0])}" if(@dbApiHelper.extractGbKey(@inputs[0]))
        apiCaller = WrapperApiCaller.new(inputUri.host, rsrcUri, @userId)
        downloadedSuccessfully = false
        loop {
          apiCaller.get() { |chunk| ww.print(chunk) }
          ww.close()
          if(apiCaller.succeeded?)
            downloadedSuccessfully = true
          else
            ww = File.open(tmpFile, "w")
          end
          break if(downloadedSuccessfully)
          sleep(10)
        }
        exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
        exp.extract()
        if(exp.uncompressedFileList.size > 1)
          @errUserMsg = "#{CGI.unescape(fileBase)} extracted to more than 1 file. Uploading annotations via multiple files is not currently supported."
          raise @errUserMsg
        elsif(exp.uncompressedFileList.size == 0)
          @errUserMsg = "#{CGI.unescape(fileBase)} extracted to 0 files. Please add a file to the archive and run the tool again."
          raise @errUserMsg
        end
        inputFile = CGI.escape(exp.uncompressedFileList[0])
        unescInputFile = exp.uncompressedFileList[0]
        # Convert to unix format
        unless(@format =~/^big/i)
          convObj = BRL::Util::ConvertText.new(unescInputFile, true)
          convObj.transformEncoding = @transformEncoding
          begin
            convObj.convertText()
          rescue => err
            # @format is not convertible by iconv but may still be a fine upload format
          end
          # File must be ASCII at this point
          sn = BRL::Genboree::Helpers::Sniffer.new(unescInputFile)
          encodingFmt = sn.autoDetect()
          if(encodingFmt == 'UTF')
            @errUserMsg = "#{File.basename(unescInputFile)} is not ASCII. Please make sure to check the 'Convert NON-ASCII files to ASCII before processing' option before submitting." 
            raise @errUserMsg  
          end
        end
        
        # Get the refseqid of the target database
        outputUri = URI.parse(@outputs[0])
        rsrcUri = outputUri.path
        rsrcUri << "?gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
        apiCaller = WrapperApiCaller.new(outputUri.host, rsrcUri, @userId)
        apiCaller.get()
        resp = JSON.parse(apiCaller.respBody)
        @refSeqId = resp['data']['refSeqId']
        # Get the entrypoints of the target db
        apiCaller = WrapperApiCaller.new(outputUri.host, "#{rsrcUri}/eps?", @userId)
        apiCaller.get()
        if(!apiCaller.succeeded?)
          @errUserMsg = "Failed to get entrypoints from target database. API Response:\n#{apiCaller.respBody.insepct}"
          raise @errUserMsg
        end
        eps = apiCaller.parseRespBody['data']['entrypoints']
        @epHash = {}
        eps.each { |epObj|
          @epHash[epObj['name']] = epObj['length'].to_i
        }
        exitStatus = nil
        if(@format == "wig" or @format =~ /^bigwig$/i or @format =~ /^bigBedgraph/i)
          # If it's bigWig or bigBedgraph, we need to convert it to wig first
          if(@format =~ /^big/i)
            # We need to dump the bigWig/bigBedgraph as text.
            textFile = "#{File.dirname(unescInputFile)}/#{CGI.escape(File.basename(unescInputFile, File.extname(unescInputFile)))}.txt"
            # Don't escape arguments here, this is not a BRL .rb script (file names should be carefully constructed):
            cmd = "bigWigToWig #{unescInputFile} #{textFile} 2>&1 "
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{cmd.inspect}")
            cmdOut = `#{cmd}`
            exitObj = $?
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Command exited with status #{exitObj.exitstatus}")
            if(exitObj.exitstatus != 0)
              @errUserMsg = "Could not convert BigWig/BigBedgraph file to Wig using UCSC bigWigToWig program,\nwhich exited with code #{exitObj.exitstatus}. Error message from bigWigToWig:\n\n#{(cmdOut.strip.empty? ? "[No message available]" : cmdOut.strip)}"
              raise @errUserMsg
            else
              # textFile may be some kind of wig or may actually be a bedGraph file! detect and convert to wig if needed
              # Detect:
              sniffer = BRL::Genboree::Helpers::Sniffer.new(textFile)
              if(sniffer.detect?("bedGraph"))
                # Grep out the track header (the converter can't handle it properly)
                bedGraphFile  = "#{textFile}.bedGraph"
                fwigFile      = "#{textFile}.fwig"
                `grep -v 'track' #{textFile} > #{bedGraphFile}`
                # If Non-assembly chr are NOT to be skipped, create a file with the eps and give it to the converter
                unless(@skipNAChr)
                  epWriter = File.open('chrList.txt', 'w')
                  @epHash.each_key { |key|
                    epWriter.puts(key)
                  }
                  epWriter.close()
                end
                # Convert command.
                # Arguments to BRL Ruby scripts should be escaped! Not only for making a safe command, but to get filenames built
                # using CGI.escape() into the program correctly.
                command = "bedGraphToFixedWig.rb -i #{bedGraphFile} -o #{CGI.escape(fwigFile)} --coordSystem #{@coordSystem}"
                command << " --epFile chrList.txt" unless(@skipNAChr)
                command << " 2>&1 "
                $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
                cmdOut = `#{command}`
                exitObj = $?
                if(exitObj.exitstatus != 0)
                  @errUserMsg = "Could not convert BedGraph file (from BigWig/BigBedGraph orginal) to Wig using the bedGraphToFixedWig.rb program,\nwhich exited with code #{exitObj.exitstatus}. Error message from bedGraphToFixedWig:\n\n#{(cmdOut.strip.empty? ? "[No message available]" : cmdOut.strip)}"
                  raise @errUserMsg
                else
                  textFile = fwigFile
                end
              elsif(!sniffer.detect?("wig"))
                # Sniffer found unsupported format??
                actualFormat = (sniffer.autoDetect() || "[Unknown]")
                @errUserMsg = "After dumping BigWig/BigBedGraph file to text via UCSC bigWigToWig, could not tell whether output is Fwig, Vwig, or BedGraph; yet it should be one of those formats! File possibly corrupt/truncated or detector pattern not robust. Format detected was: #{actualFormat.inspect}."
                raise @errUserMsg
              end # if(sniffer.detect?("bedGraph"))
              # Setup wig upload call
              inputFile = CGI.escape(textFile)
              unescInputFile = textFile
            end # if(exitObj.exitstatus != 0)
          end # if(@format =~ /^big/i)
          removeNonAssemblyChrs(unescInputFile, 'wig') if(@skipNAChr or @skipOORAnnos)
          uploadWig(inputFile)
          ## if user selects option to make and upload bigWig for a wig file
          if(@makeBigwig == "on")
            wigToBigWig(inputFile)
          end          
        elsif(@format == "lff")
          removeNonAssemblyChrs(unescInputFile, 'lff') if(@skipNAChr or @skipOORAnnos)
          uploadLff(inputFile)
        elsif(@format == 'bedGraph')
          @outFile = "./bedGraph2Wig.out"
          @errFile = "./bedGraph2Wig.err"
          # NOTE: this code was given inputFile as-is (and thus was broken). But grep doesn't support unescaping the file path!!
          # IF we've done things correctly, this wrapper has created safe file names anyway.
          # (e.g. from escaped track names) and there will be no problem.

          # First we need to convert the bedgraph file to wig
          # Grep out the track header (the converter can't handle it properly)
          # - FIXED: inputFile is an escaped path (see code above!) Can't give grep that!
          `grep -v 'track' #{unescInputFile} > #{unescInputFile}.final.bedGraph`
          removeNonAssemblyChrs("#{CGI.unescape(inputFile)}.final.bedGraph", 'bedGraph') if(@skipNAChr or @skipOORAnnos)
          # If Non-assembly chr are NOT to be skipped, create a file with the eps and give it to the converter
          unless(@skipNAChr)
            epWriter = File.open('chrList.txt', 'w')
            @epHash.each_key { |key|
              epWriter.puts(key)
            }
            epWriter.close()
          end
          # Arguments to BRL Ruby scripts should be escaped! Not only for making a safe command, but to get filenames built
          # using CGI.escape() into the program correctly.
          # - be careful, this code is horribly inconsistent with what is already fully escaped
          #   and what is not; so systematic escaping is unreliable; and it wasn't escaping everything it
          #   should (but Andrew is the only one who tests with real names with spaces, &, ', and other things users like to use)
          command = "bedGraphToFixedWig.rb -i #{CGI.escape(unescInputFile)}.final.bedGraph --coordSystem #{@coordSystem}"
          command << " --epFile chrList.txt" unless(@skipNAChr)
          command << " > #{@outFile} 2> #{@errFile}"
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command}")
          `#{command}`
          exitObj = $?.dup()
          if(exitObj.exitstatus != 0)
            raise "Command [FAILED]: #{command}\n.Check #{@outFile} and #{@errFile} for more information."
          end
          # Finally, upload the wig file
          uploadWig("#{inputFile}.final.fwig")
          `gzip #{CGI.unescape(inputFile)}.final.bedGraph` if(File.exists?("#{CGI.unescape(inputFile)}.final.bedGraph"))
          `rm -f #{CGI.unescape(inputFile)}` if(File.exists?(CGI.unescape(inputFile)))
        else
          # Run the converters first:
          if(@format == 'blast')
            @outFile = "./blast2lff.out"
            @errFile = "./blast2lff.err"
            command = "blast2lff.rb -f #{inputFile} -o #{inputFile}.lff -c #{CGI.escape(@className)} -t #{CGI.escape(@lffType)} -s #{CGI.escape(@lffSubType)}"
            command << " > #{@outFile} 2> #{@errFile}"
            `#{command}`
            exitObj = $?.dup
            # Check if the sub script ran successfully
            if(exitObj.exitstatus != 0)
              raise "Sub-process failed with exit code #{exitObj.exitstatus}: #{command}\n\nCheck #{@outFile} and #{@errFile} for more information."
            end
          elsif(@format == 'bed' or @format =~ /^bigbed$/i)
            # If it's bigBed, we need to convert it to bed first
            if(@format =~ /^bigbed$/i)
              bedFile = "#{File.dirname(unescInputFile)}/#{CGI.escape(File.basename(unescInputFile, File.extname(unescInputFile)))}.bed"
              # Don't escape arguments here, this is not a BRL .rb script (file names should be carefully constructed):
              cmd = "bigBedToBed #{unescInputFile} #{bedFile} 2>&1 "
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{cmd.inspect}")
              cmdOut = `#{cmd}`
              exitObj = $?
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Command exited with status #{exitObj.exitstatus}")
              if(exitObj.exitstatus != 0)
                @errUserMsg = "Could not convert BigBed file to Bed using UCSC bigBedToBed program,\nwhich exited with code #{exitObj.exitstatus}. Error message from bigBedToBed:\n\n#{(cmdOut.strip.empty? ? "[No message available]" : cmdOut.strip)}"
                raise @errUserMsg
              end
            else # bed
              bedFile = unescInputFile
            end

            @outFile = "./bed2lff.out"
            @errFile = "./bed2lff.err"
            # Arguments to BRL Ruby scripts should be escaped! Not only for making a safe command, but to get filenames built
            # using CGI.escape() into the program correctly.
            command = "bed2lff.rb -i #{CGI.escape(bedFile)} -o #{CGI.escape(bedFile)}.lff -c #{CGI.escape(@className)} -t #{CGI.escape(@lffType)} --coordSystem #{@coordSystem} -u #{CGI.escape(@lffSubType)}"
            command << " > #{@outFile} 2> #{@errFile}"
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command: #{command.inspect}")
            `#{command}`
            exitObj = $?.dup
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Command exited with status #{exitObj.exitstatus}")
            # Check if the sub script ran successfully
            if(exitObj.exitstatus != 0)
              @errUserMsg = "Converting your BED file (#{File.basename(bedFile).inspect}) to LFF failed.\nTypically because it is not actually a BED file. Error message:\n\n#{File.read(@outFile)}"
              raise "Sub-process failed with exit code #{exitObj.exitstatus}: #{command}\n\nCheck #{@outFile} and #{@errFile} for more information."
            else
              # Ensure inputFile set to escaped path to bedFile (in case bigBed had to write its own bed file)
              inputFile = CGI.escape(bedFile)
            end
          elsif(@format == 'gff3')
            @outFile = "./gff32lff.out"
            @errFile = "./gff32lff.err"
            command = "gff32lff.rb -i #{inputFile} -o #{inputFile}.lff -c #{CGI.escape(@className)} "
            command << " > #{@outFile} 2> #{@errFile}"
            `#{command}`
            exitObj = $?.dup
            # Check if the sub script ran successfully
            if(exitObj.exitstatus != 0)
              raise "Sub-process failed with exit code #{exitObj.exitstatus}: #{command}\n\nCheck #{@outFile} and #{@errFile} for more information."
            end
          elsif(@format == 'blat')
            @outFile = "./blat2lff.out"
            @errFile = "./blat2lff.err"
            command = "blat2lff.rb -f #{inputFile} -o #{inputFile}.lff -c #{CGI.escape(@className)} -t #{CGI.escape(@lffType)} -s #{CGI.escape(@lffSubType)}"
            command << " > #{@outFile} 2> #{@errFile}"
            `#{command}`
            exitObj = $?.dup
            # Check if the sub script ran successfully
            if(exitObj.exitstatus != 0)
              raise "Sub-process failed with exit code #{exitObj.exitstatus}: #{command}\n\nCheck#{@outFile} and #{@errFile}  for more information."
            end
          elsif(@format == 'agilent')
            @outFile = "./agilent2lff.out"
            @errFile = "./agilent2lff.err"
            command = "agilent2lff.rb -f #{inputFile} -o #{inputFile}.lff -c #{CGI.escape(@className)} -t #{CGI.escape(@lffType)} -s #{CGI.escape(@lffSubType)}"
            command << " -i " if(@histTracks)
            if(@segAnalysis)
              command << " -p #{@minProbesPerSeg}  "
              if(@segAnalysisRadio == "stdev")
                command << " -e #{@segLogRatio}"
              else
                command << " -n #{@segLogRatio}"
              end
            end
            command << ""
            command << " > #{@outFile} 2> #{@errFile}"
            `#{command}`
            exitObj = $?.dup
            # Check if the sub script ran successfully
            if(exitObj.exitstatus != 0)
              raise "Sub-process failed with exit code #{exitObj.exitstatus}: #{command}\n\nCheck #{@outFile} and #{@errFile} for more information."
            end
          elsif(@format == 'vcf')
            vcfObj = nil
            buff = '' # buffer for dumping out lff records in chunks
            @outFile = @errFile = ""
            # First validate the vcf file
            isValid = BRL::Util::VcfParser.validate(unescInputFile)
            if(!isValid)
              if(File.exists?("#{unescInputFile}.vcf-to-tab.err"))
                @errUserMsg = File.read("#{unescInputFile}.vcf-to-tab.err")
              end
              raise "VCF file failed validation. Check #{unescInputFile}.vcf-to-tab.err for more info."
            end
            # Get the entrypoints in the target database. The entrypoints in the vcf file MUST be present in the target database.
            targetHost = outputUri.host
            rsrcPath = "#{outputUri.path}/eps?"
            rsrcPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
            apiCaller = WrapperApiCaller.new(targetHost, rsrcPath, @userId)
            apiCaller.get()
            frefHash = {}
            retVal = apiCaller.parseRespBody()['data']['entrypoints']
            retVal.each { |chr|
              frefHash[chr['name']] = chr['length'].to_i
            }
            vcfReader = File.open(unescInputFile)
            lffWriter = File.open("#{unescInputFile}.lff", "w")

            # Instantiate vcf parser class based on the column header line (for indexing the columns)
            @vcfMetaInfoHash = {}
            vcfReader.each_line { |line|
              if(line =~ /^#(?!#)/) # Column Header
                # Init vcfParser
                vcfObj = BRL::Util::VcfParser.new(line, nil, frefHash, @skipNAChr)
                break
              else
                @vcfMetaInfoHash = BRL::Util::VcfParser.parseMetaInfoLines(line, @vcfMetaInfoHash)
              end
            }
            @specialAttrs = @vcfMetaInfoHash
            # Go through the rest of the file and convert vcf lines into lff
            # Since the vcf converter is run as a library, call the vcf methods in an exception handling loop so that
            # the error can be reported back to the user
            begin
              vcfReader.each_line { |line|
                line.strip!
                next if(line =~ /^#/ or line !~ /\S/)
                vcfObj.parseLine(line)
                #$stderr.puts "vcfObj.vcfDataHash: #{vcfObj.vcfDataHash.inspect}"
                buff << vcfObj.makeLFF(@className, "", @lffSubType) # sample will be used as type
                if(buff.size >= 128_000)
                  lffWriter.print(buff)
                  buff = ''
                end
              }
            rescue => vcfErr
              @errUserMsg = vcfErr.message
              raise @errUserMsg
            end
            if(!buff.empty?) # Flush out the remaining contents of the buffer
              lffWriter.print(buff)
            end
            buff = ''
            vcfReader.close()
            lffWriter.close()
          else # pash
            @outFile = "./pashTwo2lff.out"
            @errFile = "./pashTwo2lff.err"
            command = "pashTwo2lff.rb -f #{inputFile} -o #{inputFile}.lff -c #{CGI.escape(@className)} -t #{CGI.escape(@lffType)} -s #{CGI.escape(@lffSubType)}"
            command << " > #{@outFile} 2> #{@errFile}"
            `#{command}`
            exitObj = $?.dup
            # Check if the sub script ran successfully
            if(exitObj.exitstatus != 0)
              raise "Sub-process failed with exit code #{exitObj.exitstatus}: #{command}\n\nCheck #{@outFile} and #{@errFile}for more information."
            end
          end
          removeNonAssemblyChrs("#{CGI.unescape(inputFile)}.lff", 'lff') if(@skipNAChr or @skipOORAnnos)
          uploadLff("#{inputFile}.lff", true, @specialAttrs)
          `gzip #{CGI.unescape(inputFile)}` if(File.exists?(CGI.unescape(inputFile)))
        end
        # Try to read the out file first:
        outStream = ""
        outStream << File.read(@outFile) if(File.exists?(@outFile))
        @errUserMsg = outStream if(!outStream.empty?)
      rescue => err
        @err = err
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err.message}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        # If out file is not there or empty, read the err file
        if(@errUserMsg.nil? or @errUserMsg.empty?)
          @errUserMsg = File.read(@errFile) if(File.exists?(@errFile))
        end
        @errUserMsg = "Unknown Error" if(@errUserMsg.nil? or @errUserMsg.empty?)
        @exitCode = 30
      end
      return @exitCode
    end

    # Removes chromosomes not part of the reference genome assembly
    # [+inputFile+] file from which the non-assembly chromosome will be removed
    # [+format+] format of the file to be filtered
    # [+returns+] nil
    def removeNonAssemblyChrs(inputFile, format)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "BEGIN: Strip unknown chromosomes from #{format.inspect} file #{CGI.unescape(inputFile.to_s)}")
      rr = File.open(inputFile)
      ww = File.open("#{inputFile}.filtered", "w")
      writeBuff = ""
      orphan = nil
      addBlockRecs = false
      @skippedLines = 0
      @skippedBlocks = 0
      @skippedChrs = {}
      while(!rr.eof?)
        buffer = rr.read(8 * 1024 * 1024)
        buffIO = StringIO.new(buffer)
        buffIO.each_line { |line|
          line = orphan + line if(!orphan.nil?)
          orphan = nil
          if(line =~ /\n$/)
            line.strip!
            next if(line =~ /^#/ or line.empty?)
            case format
            when 'lff'
              fields = line.split(/\t/)
              conditionSatisfied = true
              if(@skipNAChr)
                if(!@epHash.key?(fields[4]))
                  @skippedLines += 1
                  @skippedChrs[fields[4]] = nil
                  conditionSatisfied = false
                end
              end
              if(conditionSatisfied)
                if(@skipOORAnnos)
                  startCoord = fields[5].to_i
                  endCoord = fields[6].to_i
                  if(startCoord > @epHash[fields[4]] or endCoord < 1)
                    conditionSatisfied = false
                  end
                end
              end
              writeBuff << "#{line}\n" if(conditionSatisfied)
            when 'bedGraph'
              fields = line.split(/\s+/)
              conditionSatisfied = true
              if(@skipNAChr)
                if(!@epHash.key?(fields[0]))
                  @skippedLines += 1
                  @skippedChrs[fields[0]] = nil
                  conditionSatisfied = false
                end
              end
              if(conditionSatisfied)
                if(@skipOORAnnos)
                  startCoord = fields[1].to_i
                  endCoord = fields[2].to_i
                  if(@coordSystem == '0')
                    startCoord += 1
                  end
                  if(startCoord > @epHash[fields[0]] or endCoord < 1)
                    conditionSatisfied = false
                  end
                end
              end
              writeBuff << "#{line}\n" if(conditionSatisfied)
            when 'wig'
              if(line =~ /^fixedStep/ or line =~ /^variableStep/)
                blockFields = line.split(/\s+/)
                chrom = nil
                blockFields.each { |blockFld|
                  if(blockFld.strip.split('=')[0] == 'chrom')
                    chrom = blockFld.strip.split('=')[1]
                    addBlockRecs =  ( @epHash.key?(chrom) ? true : false )
                  end
                }
                if(addBlockRecs)
                  writeBuff << "#{line}\n"
                else
                  @skippedChrs[chrom] = nil
                  @skippedBlocks += 1
                end
              elsif(line =~ /^(?:(\+|\-)?\d+)\s+(?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?$/i or line.valid?(:float))
                writeBuff << "#{line}\n" if(addBlockRecs)
              else
                # No-op
              end
            end
          else
            orphan = line
          end
          if(writeBuff.size >= 4 * 1024 * 1024)
            ww.write(writeBuff)
            writeBuff = ""
          end
        }
        buffIO.close()
      end
      if(!writeBuff.empty?)
        ww.write(writeBuff)
        writeBuff = ""
      end
      ww.close()
      rr.close()
      `mv #{inputFile}.filtered #{inputFile}`
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "DONE: Strip unknown chromosomes from #{format.inspect} file #{CGI.unescape(inputFile.to_s)}")
    end

    # [+inputFile+] wig file to be uploaded into Genboree
    # [+returns+] nil
    def uploadWig(inputFile, compressFile=true)
      # Validate trackClassName is specified correctly
      checkTrackClassName()
      @outFile = @errFile = nil
      @startTime = Time.now
      # Check if track is already present (For example: Track Copier creates an empty track before calling this method)
      # Also make a list of which tracks are empty. We will nuke these if something goes wrong.
      # If tracks are not empty, that means they were set up from a prior upload. In that case we will keep the tracks.
      targetUri = ( @outputs ? URI.parse(@outputs[0]) : URI.parse(@dbApiHelper.getUrlFromRefSeqId(@refSeqId)) )
      apiCaller = WrapperApiCaller.new(targetUri.host, "#{targetUri.path}/trk/#{CGI.escape(@trackName)}/annos/count?", @userId)
      apiCaller.get()
      emptyTrk = nil
      # If call fails, assume track not present
      if(!apiCaller.succeeded?)
        apiCaller.setRsrcPath("#{targetUri.path}/trk/#{CGI.escape(@trackName)}?trackClassName={className}")
        apiCaller.put({:className => @className})
        emptyTrk = true
      else
        emptyTrk = (apiCaller.parseRespBody['data']['count'] > 0 ? false : true)
      end
      exitObj = nil
      addressesMatch = (self.class.addressesMatch?(targetUri.host, @genbConf.machineName) ? true : false)
      #addressesMatch = false # For testing
      if(addressesMatch)
        apiCaller = WrapperApiCaller.new(targetUri.host, "#{targetUri.path}/trk/#{CGI.escape(@trackName)}/attribute/gbPartialEntity/value?", @userId)
        payload = { "data" => { "text" => 1 } }
        apiCaller.put({}, payload.to_json)
        command = "importWiggleInGenboree.rb"
        command <<  " -u #{@userId} -d #{@refSeqId} -g #{CGI.escape(@groupName)} -J #{@jobId} -t #{CGI.escape(@trackName)} -i #{inputFile} "
        command << " -j . -F --dbrcKey #{@genbConf.dbrcKey} "  # bin files get moved later, default is to go straight to ridSequence dir
        @outFile = "./importWiggle.out"
        @errFile = "./importWiggle.err"
        command << " > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching sub-process: #{command}")
        `#{command}`
        exitObj = $?.dup()
        # Untag the track
        payload = { "data" => { "text" => 0 } }
        apiCaller.put({}, payload.to_json)
      else
        @outFile = "remoteWig.out"
        @errFile = "remoteWig.err"
        command = "remoteWiggleUploader.rb -i #{inputFile} -u #{@userId} -d #{CGI.escape(@outputs[0])} -t #{CGI.escape(@trackName)} > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching sub-process: #{command}")
        `#{command}`
        exitObj = $?.dup()
      end
      # Check if the sub script ran successfully
      if(exitObj.exitstatus != 0)
        # Upload failed. If track was empty, nuke it.
        if(emptyTrk)
          apiCaller = WrapperApiCaller.new(targetUri.host, "#{targetUri.path}/trk/#{CGI.escape(@trackName)}?", @userId)
          apiCaller.delete()
        end
        @errUserMsg = File.read(@outFile) if(File.exists?(@outFile))
        raise "Sub-process failed: #{command}\n\nCheck importWiggle.out and importWiggle.err for more information. "
      end
      # Copy the bin file to the server
      Dir.entries(".").each { |file|
        if(file =~ /\.bin/)
          outputUri = URI.parse(@outputs[0])
          rsrcPath = outputUri.path
          rsrcPath << "/file/#{CGI.escape(file)}/data?fileType=bin"
          rsrcPath << "&gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
          apiCaller = WrapperApiCaller.new(outputUri.host, rsrcPath, @userId)
          apiCaller.put({}, File.open(file))
          if(!apiCaller.succeeded?)
            @errUserMsg = "Could not copy file to server using API.\nAPI response:\n#{apiCaller.respBody.inspect}"
            raise "API Call to put bin file FAILED:\n#{apiCaller.respBody.inspect}"
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "API call to put bin file succeeded. Removing .bin file from local scratch area...")
            `rm -f #{file}`
          end
          break
        end
      }
      `gzip #{CGI.unescape(inputFile)}` if(File.exists?(CGI.unescape(inputFile)) and compressFile)
    end

    ## Convert wig to bigWig
    def wigToBigWig(inputFile)
      # Because the wig importer would have compressed the wigfile
      if(File.exists?("#{CGI.unescape(inputFile)}.gz"))
        `gunzip #{CGI.unescape(inputFile)}.gz`
      end
      # prepare chrom.sizes file for this output db
      outputUri = URI.parse(@dbApiHelper.extractPureUri(@outputs[0]))
      host = outputUri.host
      rsrcPath = outputUri.path
      tmpPath = "#{rsrcPath}/eps?"
      tmpPath << "gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
      apiCaller = WrapperApiCaller.new(host, tmpPath, @userId)
      apiCaller.get()
      refFileWriter = File.open("chrom.sizes", "w")
      apiCaller.parseRespBody['data']['entrypoints'].each { |rec|
        refFileWriter.puts "#{rec['name']}\t#{rec['length']}"
      }
      refFileWriter.close()
      # convert wig to bigWig file
      @outputBigWigFile = "trackAnnos.bw"
      @errFile = "wigToBigWig.err"
      @outFile = "wigToBigWig.out"
      command = "wigToBigWig #{CGI.unescape(inputFile)} chrom.sizes #{@outputBigWigFile} > #{@outFile} 2> #{@errFile}"
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching command to convert wigfile to bigWig: #{command}")
      exitStatus = system(command)
      exitObj = $?.dup()
      # if bigWig file was created, then upload it to the server
      if(exitObj.exitstatus == 0)
        ## Upload bigWig file to server - this bigWig should be linked with the corresponding track
        bigFileRsrcPath = rsrcPath.dup()
        bigFileRsrcPath << "/file/#{@outputBigWigFile}/data?fileType=bigFile&trackName=#{CGI.escape(@trackName)}"
        bigFileRsrcPath << "&gbKey=#{@dbApiHelper.extractGbKey(@outputs[0])}" if(@dbApiHelper.extractGbKey(@outputs[0]))
        apiCaller = WrapperApiCaller.new(host, bigFileRsrcPath, @userId)
        apiCaller.put({}, File.open(@outputBigWigFile))
        if(!apiCaller.succeeded?)
          @errUserMsg = "Could not put file: #{@outputBigWigFile} to host: #{host}.\nAPI Error Message:\n#{apiCaller.respBody.inspect}"
          raise "API Call FAILED to put bigWig file. Error:\n#{apiCaller.respBody.inspect}"
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Copied over bigWig file to host: #{host}")
        end
      else
        @errUserMsg = "ERROR: Failed to convert wig to bigWig.\n"
        @errUserMsg << File.read(@outFile) if(File.exists?(@outFile) && File.size("#{@outFile}") >= 0)
        @errUserMsg << File.read(@errFile) if(File.exists?(@errFile) && File.size("#{@errFile}") >= 0)       
        raise @errUserMsg
      end
      # compress the input wigfile
      `gzip #{CGI.unescape(inputFile)}` if(File.exists?(CGI.unescape(inputFile)))
      return
    end

    # Creates the 3-column unique track list file from an LFF input file.
    #   The file is tab-delimited and the 3 columns are: CLASS, TYPE, SUBTYPE
    # @param [String] lffFile The LFF file to get the unique list of tracks for.
    # @param [String] outputFile [Optional] The output file where to put the track list
    # @return [String] the name of the outputFile where the track list was written
    def makeUniqTrkFile(lffFile, outputFile="./uniqTrks.txt")
      stdoutStr = `cut -f 3,4,1 #{CGI.unescape(lffFile)} | sort -u > #{outputFile}`
      exitObj = $?
      raise "ERROR: cut and sort failed with exit code #{exitObj.exitstatus}" unless(exitObj.success?)
      return outputFile
    end

    # @params [String] inputFile lff file to be uploaded
    # @params [boolean] compressFile
    # @params specialAttrs [Hash] A hash table with a attribute-value map
    # @return [nil]
    def uploadLff(inputFile, compressFile=true, specialAttrs={})
      # Validate trackClassName is specified correctly
      checkTrackClassName()
      @outFile = @errFile = nil
      # Construct a unique list of trk names from the lff file. We will tag them with the 'gbPartialEntity'
      uniqTrksFile = makeUniqTrkFile(inputFile)
      ff = File.open(uniqTrksFile)
      trkName2ClassHash = {} # values are class names found in lff input file
      ff.each_line { |line|
        line.strip!
        next if(line.nil? or line.empty? or line =~ /^#/)
        fields = line.split(/\t/)
        trkName2ClassHash["#{fields[1]}:#{fields[2]}"] = fields[0]
      }
      ff.close()
      targetDbUriObj = ( @outputs ? URI.parse(@outputs[0]) : URI.parse(@dbApiHelper.getUrlFromRefSeqId(@refSeqId)))
      # Loop over trkName2ClassHash and tag all tracks
      # Also make a list of which tracks are empty. We will nuke these if something goes wrong.
      # If tracks are not empty, that means they were set up from a prior upload. In that case we will keep the tracks.
      # trkNameHash is keyed by track names and the values are boolean indicating if the track is empty
      apiCaller = WrapperApiCaller.new(targetDbUriObj.host, "", @userId)
      trkNameHash = {} # values are boolean indicating if the track is empty
      trkName2ClassHash.each_key { |trkName|
        apiCaller.setRsrcPath("#{targetDbUriObj.path}/trk/#{CGI.escape(trkName)}/annos/count?")
        apiCaller.get()
        if(apiCaller.succeeded?) # track exists, is empty?
          trkNameHash[trkName] = (apiCaller.parseRespBody['data']['count'] > 0 ? false : true)
        else # track doesn't exist yet
          trkNameHash[trkName] = true # is empty
          # add track, with a class from the lff
          apiCaller.setRsrcPath("#{targetDbUriObj.path}/trk/#{CGI.escape(trkName)}?trackClassName=#{CGI.escape(trkName2ClassHash[trkName])}")
          apiCaller.put()
        end
        # Comment out the lines below for now. The 'hiding' was never working since @trackName was being used instead of trkName
        # Actually hiding the track causes downstream problems like the zoom level updater not being able to get the track
        # To-do: 
        # Hide the track
        #apiCaller.setRsrcPath("#{targetDbUriObj.path}/trk/#{CGI.escape(trkName)}/attribute/gbPartialEntity/value?")
        #payload = { "data" => { "text" => 1 } }
        #apiCaller.put({}, payload.to_json)
      }
      exitStatus = nil
      if(self.class.addressesMatch?(targetDbUriObj.host, @genbConf.machineName)) # The target database is not external
        command = "createZoomLevelsForLFF.rb -i #{inputFile} -d #{@refSeqId} -g #{CGI.escape(@groupName)} -u #{@userId} -C -k #{@genbConf.dbrcKey} -e"
        @outFile = "./createZoomLevelsForLFF.out"
        @errFile = "./createZoomLevelsForLFF.err"
        command << " >#{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching sub-process: #{command}")
        @startTime = Time.now
        exitStatus = system(command)
        # Check if the sub script ran successfully
        if(!exitStatus)
          # Nuke all tracks were empty
          trkNameHash.each_key { |trkName|
            # Untag the track
            apiCaller.setRsrcPath("#{targetDbUriObj.path}/trk/#{CGI.escape(@trackName)}/attribute/gbPartialEntity/value?")
            payload = { "data" => { "text" => 0 } }
            apiCaller.put({}, payload.to_json)
            if(trkNameHash[trkName])
              apiCaller.setRsrcPath("#{targetDbUriObj.path}/trk/#{CGI.escape(trkName)}?")
              apiCaller.delete()
            end
          }
          @errUserMsg = File.read(@outFile) if(File.exists?(@outFile))
          raise "Sub-process failed running this command:\n  #{command.inspect}\nCheck createZoomLevelsForLFF.err and createZoomLevelsForLFF.out for more information.\n\n"
        end
        exitStatus = nil
        @outFile = "./AutoUploader.out"
        @errFile = "./AutoUploader.err"
        # NOTE: Java side doesn't handle escaped files. So we'll give it the actual version.
        # IF we've done things correctly, this wrapper has created safe file names anyway
        # (e.g. from escaped track names) and there will be no problem.
        command = "lffUploader.rb -i #{inputFile} -u #{@userId} -r #{@refSeqId} --skipVal > #{@outFile} 2> #{@errFile}"
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching sub-process: #{command}")
        `#{command}`
        exitStatus = $?.dup.exitstatus
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Done running lff uploader")
        # Check if the sub script ran successfully
        if(exitStatus != 0)
          nukeEmptyTracks(trkNameHash, targetDbUriObj, apiCaller)
          raise "Sub-process failed with exit code #{exitObj.exitstatus}: #{command}\n\nCheck AutoUploader.out and AutoUploader.err for more information."
        end
      else
        validateLFF(CGI.unescape(inputFile))
        rr = File.open(CGI.unescape(inputFile))
        streamLines = ""
        lcount = 0
        rr.each_line { |line|
          streamLines << line
          lcount += 1
          if(lcount == 2500 or streamLines.size >= 337500)
            apiCaller.setRsrcPath("#{targetDbUriObj.path}/annos?format=gbTabbedDbRecs&annosFormat=lff")
            apiCaller.put(streamLines)
            streamLines = ""
            lcount = 0
            if(!apiCaller.succeeded?)
              nukeEmptyTracks(trkNameHash, targetDbUriObj, apiCaller)
              raise apiCaller.parseRespBody
            end
          end
        }
        rr.close()
        if(!streamLines.empty?)
          apiCaller.setRsrcPath("#{targetDbUriObj.path}/annos?format=gbTabbedDbRecs&annosFormat=lff")
          apiCaller.put(streamLines)
          if(!apiCaller.succeeded?)
            nukeEmptyTracks(trkNameHash, targetDbUriObj, apiCaller)
            raise apiCaller.parseRespBody
          end
        end
      end
      trkNameHash.each_key { |trkName|
        #apiCaller.setRsrcPath("#{targetDbUriObj.path}/trk/#{CGI.escape(trkName)}/attribute/gbPartialEntity/value?")
        #payload = { "data" => { "text" => 0 } }
        #apiCaller.put({}, payload.to_json)
        
        # Add any special attributes the track may have
        if(!specialAttrs.empty?)
          if(@format == 'vcf')
            specialAttrs.each_key { |key|
              attrName = "gbVcf#{key}"
              attrValue = specialAttrs[key]
              apiCaller.setRsrcPath("#{targetDbUriObj.path}/trk/#{CGI.escape(trkName)}/attribute/#{CGI.escape(attrName)}/value?")
              # For some of the reserved fields like INFO, FORMAT, etc, first check if some definitions already exist.
              # If they do, attach them to the field definitions of *this* upload.
              if(BRL::Util::VcfParser::RESERVED_METAINFO_FIELDS.key?(key))
                apiCaller.get()
                if(apiCaller.succeeded?)
                  respVal = apiCaller.parseRespBody['data']['text']
                  begin 
                    existingDefinitions = JSON.parse(respVal)
                    existingDefinitions.each {|el|
                      attrValue << el  
                    }
                  rescue => jsonParseErr
                    $stderr.debugPuts(__FILE__, __method__, "LOG", "FATAL Error: Existing definition (Track: #{trkName}) for meta info field: #{key} cannot be parsed. This will be over-written by the definitions from this upload. ")
                  end
                end
                attrValue = attrValue.to_json
              end
              payload = { "data" => { "text" => attrValue } }
              apiCaller.put({}, payload.to_json)
              $stderr.debugPuts(__FILE__, __method__, "DEBUG", "apiCaller.respBody:\n#{apiCaller.respBody.inspect}")
            }
          end
        end
      }
      `gzip #{CGI.unescape(inputFile)}` if(File.exists?(CGI.unescape(inputFile)) and compressFile)
      `gzip uniqTrks.txt` if(File.exists?('uniqTrks.txt'))
    end

    def nukeEmptyTracks(trkNameHash, targetDbUriObj, apiCaller)
      # Nuke all tracks were empty
      trkNameHash.each_key { |trkName|
        apiCaller.setRsrcPath("#{targetDbUriObj.path}/trk/#{CGI.escape(@trackName)}/attribute/gbPartialEntity/value?")
        payload = { "data" => { "text" => 0 } }
        apiCaller.put({}, payload.to_json)
        if(trkNameHash[trkName])
          apiCaller.setRsrcPath("#{targetDbUriObj.path}/trk/#{CGI.escape(trkName)}?")
          apiCaller.delete()
        end
      }
    end

    def validateLFF(lffFile)
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "validating lff before streaming")
      # Write out the 3 column lff file for valid entrypoints
      chrDefFile = "chrDefinitions.lff"
      ff = File.open(chrDefFile, "w")
      @epHash.each_key { |chr|
        ff.puts("#{chr}\tchromosome\t#{@epHash[chr]}")
      }
      ff.close()
      $stderr.puts "    - done getting chromosome definitions; start validation library call"
      validator = BRL::FileFormats::LFFValidator.new({'--lffFile' => lffFile, '--epFile' => chrDefFile})
      allOk = validator.validateFile() # returns true if no errors found
      unless(allOk)
        errors = ''
        if(validator.haveSomeErrors?() or validator.haveTooManyErrors?())
          ios = StringIO.new(errors)
          validator.printErrors(ios)
        else # WTF???
          errors = "\n\n\n\nFATAL ERROR: Unknown Error in LFFValidator. Cannot upload LFF."
        end
        @errUserMsg = errors.dup()
        raise errors
      end
    end

    def checkTrackClassName()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Validating trackClassName")
      if(@settings) # Will not be set if the tool is being used as a class
        if(@settings['trackClassName'])
          @className = @settings['trackClassName']
        else
          # Determine default class for format, if any
          # - how & whether we use this default depends on what the user provided and the format
          # - but get default first
          # - can be nil for formats like LFF that have class in them
          @className = Abstraction::Track.getDefaultClass(@format.upcase.to_sym)
        end
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Track Class: #{@className.inspect}")
      end
    end

    def prepSuccessEmail()
      additionalInfo = ""
      additionalInfo << "     Group:    '#{@groupName}'\n"
      additionalInfo << "     Database: '#{@dbName}'\n"
      additionalInfo << "     Track:    '#{@trackName}'\n" if(@trackName)
      additionalInfo << "     Class:    '#{@className}'\n" if(@className)
      additionalInfo << "\n#{@errUserMsg}\n\n"
      if(@skipNAChr and !@skippedChrs.empty?)
        if(@format == 'wig')
          additionalInfo << "Warning: A total of #{@skippedBlocks} block(s) of wig data mapping to the following chromosome(s) were skipped:\n\n"
        else
          additionalInfo << "Warning: A total of #{@skippedLines} annotation(s) mapping to the following chromosome(s) were skipped:\n\n"
        end
        @skippedChrs.each_key { |chr|
          additionalInfo << "#{chr}\n"
        }
      end
      additionalInfo << "\nYou can now login to Genboree and visualize your data.\n\n"
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return successEmailObject
    end

    def prepErrorEmail()
      additionalInfo = ""
      additionalInfo << "     Group:    '#{@groupName}'\n"
      additionalInfo << "     Database: '#{@dbName}'\n"
      additionalInfo << "     Track:    '#{@trackName}'\n" if(@trackName)
      additionalInfo << "     Class:    '#{@className}'\n" if(@className)
      additionalInfo << "     Error message from upload tool:\n#{@errUserMsg}"

      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      errorEmailObject.exitStatusCode = @exitCode
      return errorEmailObject
    end
  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper)
end
