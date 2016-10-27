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
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/util/convertText'
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class TrkCombineWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This script is used to combine/merge one or more tracks into a single track. It is intended to be called from the workbench.",
      :authors      => [ "Sameer Paithankar(paithank@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    attr_accessor :exitCode
    # Extract the relevant information to run the job
    # @returns [Integer] exitCode
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
        @scratchDir = @context['scratchDir']
        @replaceOrigTrack = false
        if(@settings.key?("replaceOrigTrk")) # This is a special setting if the wrapper is being called from the "Merge Track Annotations' UI
          if(@settings['replaceOrigTrk'] == 'replace')
            @replaceOrigTrack = true
            @trkName = @trkApiHelper.extractName(@inputs[0])
          end
        end
        unless(@replaceOrigTrack)
          @className = @settings['trackClassName']
          @lffType = @settings['lffType']
          @lffSubType = @settings['lffSubType']
          @trkName = "#{@lffType}:#{@lffSubType}"
        end
        @removeDuplicates = @settings['removeDuplicates']
        @useStrand = @settings['Use strand for removing duplicates']
        @mergeAnnos = @settings['mergeAnnos']
        @useStrandForMerging = @settings['Merge only if same strand']
        @scoreType = @settings['scoreType']
        @featureDistance = @settings['featureDistance']
        @namePrefix = @settings['namePrefix']
        @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
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
    # @returns [Integer] exitCode
    def run()
      begin
        ww = File.open('combined.lff', 'w')
        @inputs.each { |input|
          uriObj = URI.parse(input)
          trkName = @trkApiHelper.extractName(input)
          rsrcPath = "#{uriObj.path}/annos?format=lff"
          $stderr.puts "Downloading #{rsrcPath}"          
          apiCaller = WrapperApiCaller.new(uriObj.host, rsrcPath, @context['userId'])
          orphan = nil
          apiCaller.get() { |chunk|
            ww.print(chunk)
          }
        }
        ww.close()
        # Sort the lff by chr, start and end (and strand if required) if duplicates are to be removed
        if(@removeDuplicates)
          sortLff(@useStrand)
        end
        ww = File.open('combined.final.lff', 'w')
        rr = File.open('combined.lff')
        lcount = 0
        prevStart = nil
        prevStop = nil
        prevChr = nil
        prevStrand = nil
        rr.each_line { |line|
          line.strip!
          next if(line =~ /^#/ or line.empty?)
          cols = line.split(/\t/)
          if(@replaceOrigTrack) # This option will only be true if the wrapper is being called from the 'Merge Annotations' UI
            @className = cols[0]
            @lffType = cols[2]
            @lffSubType = cols[3]
          end
          unless(@removeDuplicates)
            ww.print("#{@className}\t#{cols[1]}\t#{@lffType}\t#{@lffSubType}\t#{cols[4..cols.size].join("\t")}\n")  
          else
            if(lcount == 0)
              ww.print("#{@className}\t#{cols[1]}\t#{@lffType}\t#{@lffSubType}\t#{cols[4..cols.size].join("\t")}\n")
            else
              if(@useStrand)
                if(prevChr == cols[4] and prevStart == cols[5] and prevStop == cols[6] and prevStrand == cols[7])
                  # Skip the current line
                else
                  ww.print("#{@className}\t#{cols[1]}\t#{@lffType}\t#{@lffSubType}\t#{cols[4..cols.size].join("\t")}\n")
                end
              else
                if(prevChr == cols[4] and prevStart == cols[5] and prevStop == cols[6])
                  # Skip the current line
                else
                  ww.print("#{@className}\t#{cols[1]}\t#{@lffType}\t#{@lffSubType}\t#{cols[4..cols.size].join("\t")}\n")
                end
              end
            end
          end
          prevChr = cols[4]
          prevStart = cols[5]
          prevStop = cols[6]
          prevStrand = cols[7]
          lcount += 1
        }
        ww.close()
        rr.close()
        `mv combined.final.lff combined.lff`
        # Perform merging if required (using bedtools)
        if(@mergeAnnos)
          sortLff(@useStrandForMerging)
          mergeAnnos()
        end
        # Set up some of the attr accessors for running the lff uploader
        tgtUriObj = URI.parse(@outputs[0])
        apiCaller = WrapperApiCaller.new(tgtUriObj.host, tgtUriObj.path, @context['userId'])
        apiCaller.get()
        resp = apiCaller.parseRespBody()
        refSeqId = resp['data']['refSeqId']
        uploadTrk(refSeqId)
      rescue => err
        @err = err
        @errUserMsg = err.message
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{err}\n\nBacktrace:\n#{err.backtrace.join("\n")}")
        @exitCode = 30
      ensure
        `gzip combined.lff`
      end
      return @exitCode
    end
    
    # @returns nil
    def mergeAnnos()
      # Convert lff to bed
      rr = File.open('combined.lff')
      ww = File.open('combined.bed', 'w')
      rr.each_line { |line|
        line.strip!
        next if(line.empty? or line =~ /^#/)
        line = line.gsub(/ +/, "_")
        fields = line.split(/\t/)
        ww.print("#{fields[4]}\t#{fields[5]}\t#{fields[6]}\t#{fields[1]}\t#{fields[9]}\t#{fields[7]}\n")
      }
      rr.close()
      ww.close()
      bedtoolsCmd = "module load BEDTools/2.17; bedtools merge -nms "
      bedtoolsCmd << " -s " if(@useStrandForMerging)
      if(@scoreType == 'mergedAnnos')
        bedtoolsCmd << " -n "
      else
        bedtoolsCmd << " -scores #{@scoreType} "
      end
      bedtoolsCmd << " -d #{@featureDistance}  " if(@featureDistance and @featureDistance.to_i != 0)
      bedtoolsCmd << " -i combined.bed > combined.merged.bed 2> bedtools.merge.err "
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching sub-process: #{bedtoolsCmd}")
      `#{bedtoolsCmd}`
      if($?.exitstatus != 0)
        bedtoolsErr = "bedtools -merge failed to merge annotations."
        bedtoolsErr = File.read('./bedtools.merge.err') if(File.exists?('./bedtools.merge.err'))
        raise bedtoolsErr
      end
      # Re-write the 'combined.lff' file if things are fine so far
      rr = File.open('combined.merged.bed')
      ww = File.open('combined.merged.lff', 'w')
      annoCount = 0
      nameHash = {}
      rr.each_line { |line|
        line.strip!
        next if(line.empty? or line =~ /^#/)
        annoCount += 1
        fields = line.split(/\s+/)
        name = nil
        if(@namePrefix)
          name = "#{@namePrefix}#{annoCount}"
        else
          if(fields[3].length > 190)
            name = ""
            cc = 0
            fields[3].each_char { |char|
              cc += 1
              if(cc <= 190)
                name << char 
              else
                break
              end
            }
          else
            name = fields[3]
          end
          if(nameHash.key?(name))
            nameHash[name] += 1
          else
            nameHash[name] = 1
          end
        end
        nameToUse = nil
        if(@namePrefix)
          nameToUse = name.dup
        else
          nameToUse = ( nameHash[name] == 1 ? name : "#{name}_#{nameHash[name]}" )
        end
        ww.puts("#{@className}\t#{nameToUse}\t#{@lffType}\t#{@lffSubType}\t#{fields[0]}\t#{fields[1]}\t#{fields[2]}\t+\t.\t#{fields[4]}")
      }
      rr.close()
      ww.close()
      `mv combined.merged.lff combined.lff; gzip combined.bed; gzip combined.merged.bed`
    end
    
    # @resp [String] refSeqId of target database
    # @returns nil
    def uploadTrk(refSeqId)
      if(@replaceOrigTrack)
        trkUriObj = URI.parse(@inputs[0])
        apiCaller = WrapperApiCaller.new(trkUriObj.host, trkUriObj.path, @userId)
        apiCaller.delete()
      end
      uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
      uploadAnnosObj.refSeqId = refSeqId
      uploadAnnosObj.groupName = @groupName
      uploadAnnosObj.userId = @userId
      uploadAnnosObj.outputs = @outputs
      begin
        uploadAnnosObj.uploadLff('./combined.lff', false)
      rescue => uploadErr
        $stderr.puts "Error: #{uploadErr}"
        $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
        @errUserMsg = "FATAL ERROR: Could not upload result lff file to target database."
        if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
          @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
        end
        raise @errUserMsg
      end
    end

    # Sorts lff file (with or without strand)
    # @useStrand [boolean]
    # @returns nil
    def sortLff(useStrand)
      sortCmd = "sort -t $'\t' -d -k5,5 -k6,7n"
      sortCmd << " -k8,8 " if(useStrand)
      sortCmd << " combined.lff > combined.lff.sorted"
      `#{sortCmd}`
      raise "FATAL ERROR: Could not sort lff file using unix sort." if($?.exitstatus != 0)
      `mv combined.lff.sorted combined.lff`
    end
    
    
    
    # Send success email
    # @returns emailObj
    def prepSuccessEmail()
      additionalInfo = ""
      additionalInfo << "     Group:    '#{@groupName}'\n"
      additionalInfo << "     Database: '#{@dbName}'\n"
      additionalInfo << "     Track:    '#{@trkName}'\n" if(@trkName)
      additionalInfo << "     Class:    '#{@className}'\n" if(@className)
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return successEmailObject
    end

    # Send failure/error email
    # @returns emailObj
    def prepErrorEmail()
      additionalInfo = "     Error:\n#{@errUserMsg}"
      errorEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, @userLastName, analysisName="", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo, resultFileLocations=nil, resultFileURLs=nil)
      return errorEmailObject
    end

  end
end; end ; end ; end

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Genboree::Tools::main(BRL::Genboree::Tools::Scripts::TrkCombineWrapper)
end
