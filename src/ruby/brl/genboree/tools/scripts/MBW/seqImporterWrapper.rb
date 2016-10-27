#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/sampleApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/tools/toolWrapper'

include GSL
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class SeqImporterWrapper < BRL::Genboree::Tools::ToolWrapper
    
    VERSION = "1.0"
    COMMAND_LINE_ARGS = {
      '--inputFile' => [GetoptLong::REQUIRED_ARGUMENT, '-j', ""]
    }
    DESC_AND_EXAMPLES = {
      :description => "Sequence Import wrapper for Microbiome Workbench",
      :authors => [ "Arpit Tandon", "Aaron Baker (ab4@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} -j filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }
    
    def processJobConf()
      @exitCode = 0
      begin
        # further specify job variables in addition to the assignments made by #parseJobFile in parent
        @dbu = BRL::Genboree::DBUtil.new(@dbrcKey, nil, nil)
        @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)

        # output
        @output = @outputs[0]
        @dbOutput = @dbApiHelper.extractName(@output)
        @grpOutput = @grpApiHelper.extractName(@output)
        uriOutput = URI.parse(@output)
        @hostOutput = uriOutput.host
        @pathOutput = uriOutput.path
   
        # context
        @gbAdminEmail = @context["gbAdminEmail"]
    
        # settings
        @minAvgQuality = @settings["minAvgQuality"].to_i
        @minSeqCount = @settings["minSeqCount"].to_i
        @minSeqLength = @settings["minSeqLength"].to_i
        @blastDistalPrimerBool = @settings["blastDistalPrimer"]
        @blastDistalPrimer = (@blastDistalPrimerBool == true) ? 1 : 0
    
        @cutAtEndBool = @settings["cutAtEnd"]
        @cutAtEnd = (@cutAtEndBool == true) ? 1 : 0
    
        @removeNSequencesBool = @settings["removeNSequences"]
        @removeNSequences = (@removeNSequencesBool == true) ? 1 : 0
    
        @trimLowQualityBool = @settings["trimLowQualityRun"]
        @trimLowQualityRun = (@trimLowQualityBool == true) ? 1 : 0
    
        @sampleSetNameOriginal = @settings["sampleSetName"]
        @sampleSetName = CGI.escape(@sampleSetNameOriginal).gsub(/%[0-9a-f]{2,2}/i, "_")
    
        # variables used by code
        @fileNameBuffer = []
        @sampleNameBuffer = []
        @hashTable = Hash.new{|hh,kk| hh[kk] = []}
        @hashForHeaderValidation = Hash.new{|hh,kk| hh[kk] = []}
        @localFilelocation = []
        @jointInfo = Struct.new(:index, :value)
        @uniqueFileHash = {}
        @collectErrorBuffer = Hash.new{|hh,kk| hh[kk] = []}
        @anyErrorinMetadata = Hash.new{|hh,kk| hh[kk] = []}
        @regionHash = {}
    
        # default values of proximal and distal, according to region
        @knownRegion = Hash.new{|hh,kk| hh[kk] = Hash.new{|hh,kk| hh[kk] }}
        @knownRegion["V3V5"]["proximal"] = "CCGTCAATTCMTTTRAGT"
        @knownRegion["V3V5"]["distal"] = "CTGCTGCCTCCCGTAGG"
        @knownRegion["V3V1"]["proximal"] = "ATTACCGCGGCTGCTGG"
        @knownRegion["V3V1"]["distal"] = "CTGAGCCAGGATCAAACTCT"
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = "ERROR: Could not set up required variables for running job. Check your jobFile.json to make sure all variables are defined."
        @exitCode = 22
      end
      return @exitCode
    end

    # TODO not currently in use, trying to clarify buildHashOfMetatdata
    # which just makes validations and sets @hashTable accordingly
    def validateAvpHash(sampleHash)
      # validate core sample attributes
      sampleName = sampleHash['name']
      if(sampleName !~ /^[a-z0-9][A-Z0-9_\-\+\.]*$/i)
        @exitCode = 35
        @errUserMsg = @errInternalMsg = "The sample named #{sampleName} is invalid. Sample names MUST be alphanumeric "\
          "(a-z, A-Z and 1-9) and start with a letter but may also include the characters underscore ('_'), plus ('+'), "\
          "point ('.') or minus ('-')."
        @err = BRL::Genboree::GenboreeError.new(:"Bad Request", @errUserMsg)
        raise @err
      end

      # validate sample avpHash
      avpHash = sampleHash['avpHash']
      requiredFields = ["barcode", "proximal", "distal", "fileLocation"]
      requiredFields.each{|field|
        unless(avpHash.key?(field))
          if(field == "fileLocation")
            # provide a more helpful message unique to fileLocation
            @exitCode = 36
            @errUserMsg = @errInternalMsg = "The sample named #{sampleName} is missing a \"fileLocation\" attribute. "\
              "Did you link an sra or sff file using the \"Sample -File Linker\" tool?"
            @err =  BRL::Genboree::GenboreeError.new(:"Bad Request", @errUserMsg)
            raise @err
          else
            @exitCode = 37
            @errUserMsg = @errInternalMsg = "The sample #{sampleName} is missing a required attribute #{field}"
            @err =  BRL::Genboree::GenboreeError.new(:"Bad Request", @errUserMsg)
            raise @err
          end
        end
      }

      # barcodes containing TCAG are redundant, remove TCAG
      avpHash['barcode'].gsub!(/^TCAG/i,"")
    end
  
    # Merge multiple metadata files
    # Download sample metadata from inputs and store in @hashTable
    # Validate fields from sample metadata, error if invalid
    def buildHashofMetatdata
      for i in 0...@inputs.size
        $stdout.puts "#{Time.now.to_s}: downloading sample file #{@inputs[i]}"
        $stderr.puts "#{Time.now.to_s}: downloading sample file #{@inputs[i]}"
        @db  = @dbApiHelper.extractName(@inputs[i])
        @grp = @grpApiHelper.extractName(@inputs[i])
        @trk  = @trkApiHelper.extractName(@inputs[i])
        @sampleName = @sampleApiHelper.extractName(@inputs[i])
        uri = URI.parse(@inputs[i])
        host = uri.host
        path = uri.path
        path = path.chomp('?')
        #apicaller =ApiCaller.new(host,"",@user,@pass)
        apicaller =ApiCaller.new(host,"",@hostAuthMap)
        path = "#{path}?format=tabbed"
        path << "&gbKey=#{@dbApiHelper.extractGbKey(@inputs[i])}" if(@dbApiHelper.extractGbKey(@inputs[i]))
        apicaller.setRsrcPath(path)
        httpResp = apicaller.get(){|chunck|
          lines = chunck.split(/\n/)
          if(lines.size != 2)
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sample #{@sampleName} could not be downloaded successfully\nin tabbed format due to sample being incorrectly structured.\nPlease retry the “Import Sample” and/or “Sample - File Linker” tools\non this sample.")
            @errUserMsg = "Sample #{@sampleName} could not be downloaded successfully\nin tabbed format due to sample being incorrectly structured.\nPlease retry the “Import Sample” and/or “Sample - File Linker” tools\non this sample."
            @exitCode = 39
            raise @errUserMsg
          end
          @headers = lines[0].split(/\t/, Integer::MAX32)
          @columns = lines[1].split(/\t/, Integer::MAX32)
          @headers[0] = "sampleName"
          ii = 0
          @checkBarcode = false
          @checkProximal = false
          @checkDistal = false
          @checkRegion = false
          @checkFile = false
          @reg = ""
          if(@columns[0] !~ /^[a-z0-9][A-Z0-9_\-\+\.]*$/i)
            @collectErrorBuffer[@columns[0]].push(" Name MUST contain alphanumeric (a-z, A-Z and 1-9) and/or underscore ('_'),
          plus ('+'), point ('.') or minus ('-') characters only, where the name MUST
          start with letter or number.\n")
            @anyErrorinMetadata = true
          end
          for ii in 0 ...@headers.size
  
            if(@headers[ii] == "barcode")
              @checkBarcode = true
              ##After discussing with Kevin( TCAG must not be there in barcode)
              @columns[ii].gsub!(/^TCAG/i,"")
            end
            if(@headers[ii] == "proximal")
              @checkProximal = true
            end
            if(@headers[ii] == "distal")
              @checkDistal = true
            end
            if(@headers[ii] == "region")
              @reg = @columns[ii]
              @regionHash[@reg.upcase] = 0
              @checkRegion = true
            end
            if(@headers[ii] == "fileLocation")
              @checkFile = true
            end
  
            ji = @jointInfo.new(i,@columns[ii])
            #@hashTable[@headers[ii]].push(@columns[ii])
            @hashTable[@headers[ii]].push(ji)
            @hashForHeaderValidation[@headers[ii]][i] = @columns[0]
          end
          if(@checkRegion == false)
            @regionHash["no-region"] = 0
          end
          if( @checkFile == false )
            @collectErrorBuffer[@columns[0]].push("'fileLocation' was not found. Did you link an sra or sff file using
           'Sample -File Linker' tool?\n")
            @anyErrorinMetadata = true
          else
            @fileLocation = @hashTable["fileLocation"][i][1].to_s
            @uniqueFileHash[@fileLocation] = 0
            @fileLocation = @fileLocation.chomp('?')
            filenNameF = File.makeSafePath(File.basename(@fileLocation))
            @fileNameBuffer[i] = filenNameF
            @localFilelocation[i] = "#{@outputDir}/#{filenNameF}"
            @localFilelocation[i].chomp!('?')
            @sampleNameBuffer[i] = @columns[0]
            @uriFileLocation = URI.parse(@fileLocation)
          end
        }
  
        if apicaller.succeeded?
          $stdout.puts "#{Time.now.to_s}: Successfully downloaded #{@inputs[i]} "
          $stderr.puts "#{Time.now.to_s}: Successfully downloaded #{@inputs[i]} "
        else
	  parseStatus = apicaller.parseRespBody()
	  $stderr.debugPuts(__FILE__, __method__, "INSPECTING PARSE STATUS", "cmd=#{parseStatus.inspect()}")
	  if (!parseStatus.is_a?(StandardError))
	    $stderr.debugPuts(__FILE__, __method__, "INSPECTING DATA OBJ", "cmd=#{apicaller.apiDataObj.inspect}")
	    $stderr.debugPuts(__FILE__, __method__, "INSPECTING STATUS OBJ", "cmd=#{apicaller.apiStatusObj.inspect}")
            $stderr.debugPuts(__FILE__, __method__, "API response body", "cmd=#{Time.now.to_s}: #{apicaller.respBody()}")
            $stderr.debugPuts(__FILE__, __method__, "API status code and message", "cmd=#{Time.now.to_s}: API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}")
	  else
	    $stderr.debugPuts(__FILE__, __method__, "INSPECTING API'S HTTP RESPONSE BODY", "cmd=#{apicaller.httpResponse.body.class.inspect}")
	    $stderr.debugPuts(__FILE__, __method__, "DOES HTTP RESPONSE BODY RESPOND TO READ?", "cmd=#{apicaller.httpResponse.body.respond_to?(:read)}")
	    $stderr.debugPuts(__FILE__, __method__, "CONTENTS OF HTTP RESPONSE BODY RESPOND TO READ", "cmd=#{apicaller.httpResponse.body.read}") if parseStatus.respond_to?(:read)
	  end
          @exitCode = 29
          @errUserMsg = @errInternalMsg = "Unable to download sample files"
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          # propagate error to run()
          raise @err
        end
  
        # Validation of metadata file and looking for barcode, proximal, distal and region
        if(@checkBarcode == false)
          @exitCode = 30
          @errUserMsg = @errInternalMsg = "One or more samples is missing the field \"barcode\""
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg) 
          raise @err
        end
  
        if(!@uriFileLocation or @uriFileLocation.scheme.nil? or @uriFileLocation.host.nil? or @uriFileLocation.path.nil?)
          @exitCode = 31
          @errUserMsg = @errInternalMsg = "The \"fileLocation\" field in one or more of your samples is not correct or not defined."\
            "Did you link a .sra or .sff file using the 'Sample - File Linker' tool?"
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        end
  
        if(@checkProximal == false )
          if((@checkRegion == true and !( @reg =~ /^v[1|3]{1}v[3|1]{1}$/i or @reg =~ /^v[3|5]{1}v[5|3]{1}$/i) or @checkRegion == false ))
            @exitCode = 32
            @errUserMsg = @errInternalMsg = "Insufficient primer information. Provide a known 16S 'region' name and/or a"\
              "primer pair via the 'proximal' and 'distal' field."
            @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
            raise @err
          end
        end
  
        if(@checkProximal == true and @checkDistal == false and @blastDistalPrimerBool == true)
          if((@checkRegion == true and !( @reg =~ /^v[1|3]{1}v[3|1]{1}$/i or @reg =~ /^v[3|5]{1}v[5|3]{1}$/i) or @checkRegion == false ))
            @exitCode = 33
            @errUserMsg = @errInternalMsg = "Cannot determine 'distal' primer sequence. Provide a known 16S 'region'"\
              "name, a primer pair via the 'proximal' and 'distal' fields, or a"\
              "'proximal' primer end and a known 16S region."
            @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
            raise @err
          end
        end
  
        if(@checkProximal != true or (@blastDistalPrimer == 1 and @checkDistal != true))
         if(@checkRegion == true and !( @reg =~ /^v[1|3]{1}v[3|1]{1}$/i or @reg =~ /^v[3|5]{1}v[5|3]{1}$/i))
           @exitCode = 34
           @errUserMsg = @errInternalMsg = "'region' can not be identified. Please provide either V1V3 or V3V5 .\n"
           @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
           raise @err
         end
        end
  
        if(@checkProximal == false  and @checkRegion == true)
          # set proximal (and distal if originally missing) according to region
          # both V1V3 and V3V1 become known as V3V1
          if(@reg =~ /^v[1|3]{1}v[3|1]{1}$/i)
            if(@checkDistal == false)
              ji = @jointInfo.new(i,@knownRegion["V3V1"]["distal"])
              @hashTable["distal"].push(ji)
            end
            ji = @jointInfo.new(i,@knownRegion["V3V1"]["proximal"])
            @hashTable["proximal"].push(ji)
          # both V3V5 and V5V3 become known as V3V5
          elsif(@reg =~ /^v[3|5]{1}v[5|3]{1}$/i)
            if(@checkDistal == false)
              ji = @jointInfo.new(i,@knownRegion["V3V5"]["distal"])
              @hashTable["distal"].push(ji)
            end
            ji = @jointInfo.new(i,@knownRegion["V3V5"]["proximal"])
            @hashTable["proximal"].push(ji)
          end
        elsif(@checkProximal == true and @checkDistal == false and @checkRegion == true)
          # if distal is missing, set according to region
          if(@reg =~  /^v[1|3]{1}v[3|1]{1}$/i )
             ji = @jointInfo.new(i,@knownRegion["V3V1"]["distal"])
             @hashTable["distal"].push(ji)
           elsif(@reg =~ /^v[3|5]{1}v[5|3]{1}$/i)
             ji = @jointInfo.new(i,@knownRegion["V3V5"]["distal"])
             @hashTable["distal"].push(ji)
          end
        elsif(@checkProximal == true and @checkRegion == false)
          # if region is missing, set to V3V5
          ji = @jointInfo.new(i,"V3V5")
          @hashTable["region"].push(ji)
          if(@checkDistal == false)
             ji = @jointInfo.new(i,@knownRegion["V3V1"]["distal"])
             @hashTable["distal"].push(ji)
          end
        end
      end

      # if there are multiple regions or no region, user would get a warning email
      if(@regionHash.size > 1)
        regionStr = @regionHash.keys.join(",")
        @warningMsg = "Your input samples have 2 or more different primer regions: #{regionStr}. We have witnessed"\
          "that many samples will cluster based on primer region, which has the adverse effect of masking the clustering "\
          "of more interesting confounding factors (i.e. health, body site, etc.). Please ignore this message if you "\
          "intentionally submitted a job that contains more than one primer region."
      end
      # skipping warning message for missing regions because they are set to V3V5 if ALL are missing, otherwise above message is displayed
    end
  
    #def work
    # Download samples
    # Download files from sample's fileLocation field
    # Transform sample data to fit into run_readsfilter.rb script
    # Compress results of script
    # Upload compressed results
    # Clean up
    def run()
      @exitCode = 0
      begin
        system("mkdir -p #{@scratchDir}")
        Dir.chdir(@scratchDir)
        @outputDir = "#{@scratchDir}/seqImporter"
        system("mkdir -p #{@outputDir}")
        saveFile = File.open("#{@outputDir}/#{@sampleSetName}.local.metadata","w+")
        saveFile2 = File.open("#{@outputDir}/#{@sampleSetName}.metadata","w+")
        #saveFile.puts "sampleID\tsampleName\tbarcode\tminseqLength\tminAveQual\tminseqCount\tproximal\tdistal\tregion\tflag1\tflag2\tflag\3flag4\fileLocation\tTreatment\tBody_Site\tAge\tETHNIC\tSeq_center"
    
        # download sample meta data and save data in @hashTable
        buildHashofMetatdata()
    
        # download files specified in 'fileLocation' field of samples
        # store filepath in @localFileLocation array
        @uniqueFileHash.each {|k,v|
          @fileLocation = k.chomp('?')
          @dbF  = @dbApiHelper.extractName(@fileLocation)
          @grpF = @grpApiHelper.extractName(@fileLocation)
          uriF = URI.parse(@fileLocation)
          hostF = uriF.host
          #apicallerF =ApiCaller.new(hostF,"",@user,@pass)
          apicallerF =ApiCaller.new(hostF,"",@hostAuthMap)
          pathF = uriF.path + "/data"
          pathF << "?gbKey=#{@dbApiHelper.extractGbKey(@fileLocation)}" if(@dbApiHelper.extractGbKey(@fileLocation))
          apicallerF.setRsrcPath(pathF)
          filenNameF = File.makeSafePath(File.basename(@fileLocation))
          saveFileF = File.open("#{@outputDir}/#{filenNameF}","w+")
          @buff = ''
          httpRespF = apicallerF.get(){ |chunck1|
           saveFileF.write chunck1
          }
          saveFileF.close
    
          # uncompress the downloaded file, if needed
          expanderObj = BRL::Genboree::Helpers::Expander.new("#{@outputDir}/#{filenNameF}")
          if(compressed = expanderObj.isCompressed?("#{@outputDir}/#{filenNameF}"))
           newFileName = filenNameF.gsub(/.gz$/,'')
           fullPathToUncompFile = advancedExpander("#{@outputDir}/#{filenNameF}" ,"#{@outputDir}/#{newFileName}_compressed", @outputDir )
           $stderr.puts("fullPathToUncompFile: #{fullPathToUncompFile.inspect}")
           # expanderObj.extract('text')
           # fullPathToUncompFile = expanderObj.uncompressedFileName
    
           ##Finding same filename all over the array and change with uncompressed path
           indexOfOccurrence  = @localFilelocation.each.with_index.find_all{ |a,i| a == "#{@outputDir}/#{filenNameF}" }.map{ |a,b| b }
           $stderr.puts("indexOfOccurrence: #{indexOfOccurrence.inspect}")
           indexOfOccurrence.each {|index|
            @localFilelocation[index] = fullPathToUncompFile
            #$stderr.puts("@localFilelocation: #{@localFilelocation.inspect}\n\n")
           }
           Dir.chdir(@scratchDir)
          end
        }
        $stderr.puts("@localFilelocation: #{@localFilelocation.inspect}")
        Dir.chdir(@scratchDir)
    
        # run_readsfilter.rb requires a specifically formatted (certain fields) tab-delimited file, prepare it
        # (most of the fields are fields in the sample metadata, fileLocation is modified from its Genboree location
        # to the locally downloaded location)
        # also perform some further validation and default-setting of fields, TODO move those operations to be with the
        # other validation steps
        vv = 0
        seqCenter = "WUGSC"
        @hashTable.delete("biomaterialProvider")
        @hashTable.delete("biomaterialState")
        @hashTable.delete("biomaterialSource")
        @hashTable.delete("type")
        @hashTable.delete("state")
    
        saveFile.print "sampleID\tsampleName\tbarcode\tminseqLength\tminAveQual\tminseqCount\tproximal\tdistal\tregion\tflag1"
        saveFile.print "\tflag2\tflag3\tflag4\tfileLocation"
        saveFile2.print "sampleID\tsampleName\tbarcode\tminseqLength\tminAveQual\tminseqCount\tproximal\tdistal\tregion\tflag1"
        saveFile2.print "\tflag2\tflag3\tflag4\tfileLocation"
    
        maxSize =[]
        @hashTable.each{|k,v|
          maxSize.push(v.size)
        }
        mSize = maxSize.max
    
        ## VERY IMP.Step. Placing the available values with correct file order so that we
        ## tell which index (or file) doesnt have any value
        @newhashTable = Hash.new{|hh,kk| hh[kk] = []}
        @hashTable.each{|k,v|
          v.each{|l|
           @newhashTable[k][l.index] = l.value
          }
        }
    
        @newhashTable.each {|k,v|
          unless(k == "sampleName" or k == "barcode" or k == "proximal" or k == "distal" or k == "region" or k == "fileLocation")
           saveFile.print "\t#{k}"
           saveFile2.print "\t#{k}"
          end
        }
    
        saveFile.print "\n"
        saveFile2.print "\n"
    
        for i in 0 ... mSize
          firstOcc = true
          @newhashTable.each{|k,v|
           if(  !@newhashTable.key?('proximal') )
            @proximal = "CCGTCAATTCMTTTRAGT"
            $stdout.puts puts "#{Time.now.to_s}: set default proximal"
           elsif
            @proximal = @newhashTable["proximal"][i]
           end
    
           if( !@newhashTable.key?('distal'))
            @distal = "CTGCTGCCTCCCGTAGG"
            $stdout.puts "#{Time.now.to_s}: set default distal"
           else
            @distal = @newhashTable["distal"][i]
           end
    
           if( !@newhashTable.key?('region'))
            @region = "V3V5"
            $stdout.puts  "#{Time.now.to_s}: set default region"
           else
            @region = @newhashTable["region"][i]
           end
    
           if(firstOcc)
            saveFile.print "#{@newhashTable["sampleName"][i]}\t#{@newhashTable["sampleName"][i]}\t#{@newhashTable["barcode"][i]}\t"
            saveFile.print "#{@minSeqLength}\t#{@minAvgQuality}\t#{@minSeqCount}\t#{@proximal}\t#{@distal}\t"
            saveFile.print "#{@region}\t#{@blastDistalPrimer}\t#{@cutAtEnd}\t#{@removeNSequences}\t#{@trimLowQualityRun}\t"
            saveFile.print "#{@localFilelocation[i]}"
    
            saveFile2.print "#{@newhashTable["sampleName"][i]}\t#{@newhashTable["sampleName"][i]}\t#{@newhashTable["barcode"][i]}\t"
            saveFile2.print "#{@minSeqLength}\t#{@minAvgQuality}\t#{@minSeqCount}\t#{@proximal}\t#{@distal}\t"
            saveFile2.print "#{@region}\t#{@blastDistalPrimer}\t#{@cutAtEnd}\t#{@removeNSequences}\t#{@trimLowQualityRun}\t"
            saveFile2.print "#{@newhashTable["fileLocation"][i]}"
            firstOcc = false
           end
    
           unless(k == "sampleName" or k == "barcode" or k == "proximal" or k == "distal" or k == "region" or k == "fileLocation")
            if(@newhashTable[k][i]==nil)
              saveFile.print "\tno-Value"
              saveFile2.print "\tno-Value"
            else
             saveFile.print "\t#{@newhashTable[k][i]}"
             saveFile2.print "\t#{@newhashTable[k][i]}"
            end
           end
          }
          saveFile.print "\n"
          saveFile2.print "\n"
        end
        saveFile.close
        saveFile2.close
    
        $stdout.puts "#{Time.now.to_s}: Running Tool"
        $stderr.puts "#{Time.now.to_s}: Running Tool"
        cmd = "run_readsfilter.rb #{@outputDir}/#{@sampleSetName}.local.metadata  #{@outputDir} >>#{@outputDir}/seqImporter.log 2>>#{@outputDir}/seqImporter.error.log"
        system(cmd)
        if(!$?.success?)
          $stderr.debugPuts(__FILE__, __method__, "CMD FAILED", "cmd=#{cmd} ")
          $stderr.debugPuts(__FILE__, __method__, "CMD FAILED", "exitstatus=#{$?.exitstatus}")
          @errUserMsg = @errInternalMsg = "readsfilter script didn't run properly"
          @exitCode = 25
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @err)
          raise @err
        end

        # run_readsfilter.rb script generates update_inputTable.txt, which has sample names only for those samples with no sequence data
        # notify user about which samples have no sequence data
        tempHash = {}
        @noSeqExtError = ""
        fileTemp = File.open("#{@outputDir}/update_inputTable.txt")
        fileTemp.each {|line|
          line.strip!
          col = line.split(/\t/)
          tempHash[col[0]] = 0
        }
        fileTemp.close
        fileTemp1 = File.open("#{@outputDir}/#{@sampleSetName}.metadata")
        fileTemp2 = File.open("#{@outputDir}/#{@sampleSetName}.metadata.tmp", "w+")
        # boolean found is used to check whether any sequences are imported.  If found remains false, then sequences_metrics_summary.xls cannot be created,
	# so we need to present the user with an error.
	found = false
	# Because the first line in the metadata file will be descriptions of each column, it will NEVER be empty even if we can't import any sequences.  
	# We use the variable count to keep track of whether we're dealing with this initial line or another line (that contains an actual sequence).
	count = 0
        notFoundArray = []
        fileTemp1.each {|line|
          line.strip!
          col = line.split(/\t/)
          if(tempHash[col[0]])
           fileTemp2.puts line
	   # If count is higher than 0, then we know that we've reached a line after our initial line, so we know that we've found a legitimate sequence.
	   if (count > 0)
	     found = true
	   end
          else
           $stderr.puts "#{Time.now.to_s}: No sequences were extracted for #{col[0]}"
           notFoundArray.push(col[0])
           @noSeqExtError << "No sequences were extracted for sample #{col[0]}\n"
          end
	  count += 1
        }
	# If we haven't found a legitimate sequence, we need to print an error message for the user.
	unless(found)
          @errUserMsg = "ERROR encountered when executing the underlying tool(s).\nPlease check sequence/sample files (and seqImporter.error.log,\nwhich has been uploaded to your Genboree account).\nSpecifically, this failure was noticed in the underlying tool:\nsequences_metrics_summary.xls could not be created\nbecause no sequences were extracted from any of your samples.\nYour samples were the following:\n\n#{notFoundArray.join("\n")}"
	  @exitCode = 24
	  @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
	  # We'll make sure to upload the error log for the user, although the information given above / in the error e-mail is perhaps sufficient!
          uploadUsingAPI("seqImporter.error.log","#{@scratchDir}/seqImporter/seqImporter.error.log")
	  raise @err
	end
        fileTemp1.close
        fileTemp2.close
        system("mv #{@outputDir}/#{@sampleSetName}.metadata.tmp #{@outputDir}/#{@sampleSetName}.metadata")
    
        # compress files generated by run_readsfilter.rb script into .tar.gz archives for upload
        compression()
        if(!$?.success?)
          $stderr.debugPuts(__FILE__, __method__, "CMD FAILED", "cmd=#{cmd} ")
          $stderr.debugPuts(__FILE__, __method__, "CMD FAILED", "exitstatus=#{$?.exitstatus}")
          @errUserMsg = @errInternalMsg = "compression didn't run properly"
          @exitCode = 26
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        end

        # upload the archives we just created
        uploadData()
        if(!$?.success?)
          $stderr.debugPuts(__FILE__, __method__, "CMD FAILED", "cmd=#{cmd} ")
          $stderr.debugPuts(__FILE__, __method__, "CMD FAILED", "exitstatus=#{$?.exitstatus}")
          @errUserMsg = @errInternalMsg = "upload failed"
          @exitCode = 27
          @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
          raise @err
        end

        # clean up if everything went ok (no prior errors)
        Dir.chdir("#{@outputDir}")
        system("find . ! -name '*.log' | xargs rm -rf")
        Dir.chdir(@scratchDir)
        rmCmd = "for xx in `find ./ -type f -name '*.SFF'`; do `rm -f $xx`; done"
        `#{rmCmd}`
        rmCmd = "for xx in `find ./ -type f -name '*.sff'`; do `rm -f $xx`; done"
        `#{rmCmd}`
        rmCmd = "for xx in `find ./ -type f -name '*.SRA'`; do `rm -f $xx`; done"
        `#{rmCmd}`
        rmCmd = "for xx in `find ./ -type f -name '*.sra'`; do `rm -f $xx`; done"
        `#{rmCmd}`
      rescue => err
        if(@exitCode == EXIT_OK)
          @err = err
          $stderr.debugPuts(__FILE__, __method__, "SEQIMPORT ERROR", @err.message)
          $stderr.debugPuts(__FILE__, __method__, "SEQIMPORT ERROR", @err.backtrace)
          @exitCode = 28
          @errUserMsg = @errUserMsg = "ERROR: An unrecognized error occurred while running #{@toolTitle}."
        end
        # otherwise when @exitCode is set, assume @err, @errUserMsg, and @errInternalMsg were also set
        
        # if error, clean up 
        #    # deleting file from workbech created by UI
        #    apicaller =ApiCaller.new(@hostOutput,"",@hostAuthMap)
        #    restPath = @pathOutput
        #    path = restPath +"/file/MicrobiomeData/#{CGI.escape(@sampleSetNameOriginal)}/jobFile.json"
        #    path << "?gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
        #    apicaller.setRsrcPath(path)
        #    $stderr.puts "#{Time.now.to_s}: deleting directory from workbench"
        #    apicaller.delete()
        #    $stderr.puts "#{Time.now.to_s}: deleted"
        #  
        #  
        #    # deleting downloaded srf or sff file
        #    for i in 0...@localFilelocation.size
        #      if(File.exist?(@localFilelocation[i]))
        #        File.delete(@localFilelocation[i])
        #      end
        #    end
      end

      return @exitCode
    end # end run
  
     ##Advanced expander to handle zip and tar.gz file
     def advancedExpander(inputFileName, scratchArea, outputFile)
       begin
        system("mkdir -p #{scratchArea}")
        returnUncompressedFileName = ""
  
        system("cp #{inputFileName} #{scratchArea}/#{File.basename(inputFileName)}")
        Dir.chdir("#{scratchArea}")
        expanderObj = BRL::Genboree::Helpers::Expander.new("#{scratchArea}/#{File.basename(inputFileName)}")
        if(compressed = expanderObj.isCompressed?("#{scratchArea}/#{File.basename(inputFileName)}"))
           expanderObj.extract('text')
           fullPathToUncompFile = expanderObj.uncompressedFileName
           if(!File.directory?(fullPathToUncompFile))
            system("mv #{File.expand_path(fullPathToUncompFile)} #{outputFile}")
            returnUncompressedFileName = "#{outputFile}/#{File.basename(fullPathToUncompFile)}"
           #If its a zipped archive having ONLY one compressed file
           elsif((Dir.entries(fullPathToUncompFile).size.to_i - 2) == 2)
              files = Dir.entries(fullPathToUncompFile)
              files.delete(".")
              files.delete("..")
              files.each {|l|
               unless( l =~ /"#{File.basename(inputFileName)}"/)
                system("mv #{scratchArea}/#{l} #{outputFile}")
                returnUncompressedFileName =  "#{outputFile}/#{l}"
               end
               }
           #If its tar.gz archive having ONLY one uncompressed file
           elsif((Dir.entries(fullPathToUncompFile).size.to_i - 2) == 3)
            files = Dir.entries(fullPathToUncompFile)
            isItTarArchive = false
            isItMacZip = false
            files.each {|l|
              if(%x{file #{l}} =~ /POSIX/)
               isItTarArchive = true
               break
              end
              if(%x{file #{l}} =~ /directory/ and l =~ /MACOSX/)
              isItMacZip = true
              break
              end
            }
            if(isItTarArchive)
              files = Dir.entries(fullPathToUncompFile)
              files.delete(".")
              files.delete("..")
              files.each {|l|
              unless (%x{file #{l}} =~/POSIX/ or %x{file #{l}} =~/gzip/ )
               system("mv #{scratchArea}/#{l} #{outputFile}")
               returnUncompressedFileName =  "#{outputFile}/#{l}"
              end
              }
            elsif(isItMacZip)
              files = Dir.entries(fullPathToUncompFile)
              files.delete(".")
              files.delete("..")
              files.each {|l|
              unless (%x{file #{l}} =~/Zip/ or (%x{file #{l}} =~/directory/ and l =~ /MACOSX/) )
               system("mv #{scratchArea}/#{l} #{outputFile}")
               returnUncompressedFileName =  "#{outputFile}/#{l}"
              end
              }
            else
              raise "Number of files in archive is more than one"
            end
           else
            raise "Number of files in archive is more than one"
           end
        else
          $stdout.puts "uncompressed file"
          returnUncompressedFileName = inputFileName
        end
        system("rm -rf #{scratchArea}")
        return returnUncompressedFileName
      rescue => err
        $stderr.puts "Details: #{err.message}"
        $stderr.puts err.backtrace.join("\n")
       end
    end # end advanced expander
  
    ##tar of output directory
    def compression
      $stderr.puts "#{Time.now.to_s}: compressing....."
      for i in 0...@localFilelocation.size
        if(File.exist?(@localFilelocation[i]))
         File.delete(@localFilelocation[i])
        end
      end
      Dir.chdir(@outputDir)
      system("tar czf fasta.result.tar.gz `find . -name '*.fasta'`")
      system("tar czf filtered_fasta.result.tar.gz `find . -name '*.fa'`")
      system("tar czf stats.result.tar.gz `find . -name '*stat'`")
      system("tar czf fastq.result.tar.gz `find . -name '*.fq'`")
      Dir.chdir(@scratchDir)
      $stderr.puts "#{Time.now.to_s}: compression done"
  
    end
  
    def uploadUsingAPI(fileName,filePath)
      $stdout.puts "#{Time.now.to_s}: uploading #{fileName}"
      $stderr.puts "#{Time.now.to_s}: uploading #{fileName}"
      restPath = @pathOutput
      path = restPath +"/file/MicrobiomeData/#{CGI.escape(@sampleSetNameOriginal)}/#{fileName}/data?"
      path << "gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
      retVal = @fileApiHelper.uploadFile(@hostOutput, path, @userId, filePath)
      # Set error messages if upload fails using @fileApiHelper's uploadFailureStr variable
      unless(retVal)
        @errUserMsg = @fileApiHelper.uploadFailureStr
        @errInternalMsg = @fileApiHelper.uploadFailureStr
        @exitCode = 38
        @err = BRL::Genboree::GenboreeError.new(:"Internal Server Error", @errUserMsg)
        raise @err
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{fileName} uploaded successfully to server")
      end
      return
    end

    def uploadData
      @success = false
      uploadUsingAPI("fasta.result.tar.gz","#{@outputDir}/fasta.result.tar.gz")
      uploadUsingAPI("stats.result.tar.gz","#{@outputDir}/stats.result.tar.gz")
      uploadUsingAPI("filtered_fasta.result.tar.gz","#{@outputDir}/filtered_fasta.result.tar.gz")
      uploadUsingAPI("fastq.result.tar.gz","#{@outputDir}/fastq.result.tar.gz")
      uploadUsingAPI("sample.metadata","#{@outputDir}/#{@sampleSetName}.metadata")
      uploadUsingAPI("sequences_metrics_summary.xls","#{@outputDir}/sequences_metrics_summary.xls")
      uploadUsingAPI("settings.json","#{@scratchDir}/jobFile.json")
      @success = true
    end
  
    def prepSuccessEmail()
      # add warning messages to additional info
      additionalInfo = (@warningMsg.nil?) ? "" : @warningMsg
      additionalInfo << "\n\n#{@noSeqExtError}" unless(@noSeqExtError.nil? or @noSeqExtError.empty?)
      additionalInfo = nil if(additionalInfo.empty?)

      # prepare resultFileLocations
      locationStr = "Group : #{@grpOutput}\n"\
        "Database : #{@dbOutput}\n"\
        "Files\n"\
        "  MicrobiomeData\n"\
        "    #{@sampleSetNameOriginal}\n"
      resultFileLocations = [locationStr]
      settings = {
        "Minimum Average Quality" => @minAvgQuality,
        "Minimum Sequence Count" => @minSeqCount,
        "Minimum Sequence Length" => @minSeqLength,
        "Blast Distal Primer?" => @blastDistalPrimerBool,
        "Cut At End?" => @cutAtEndBool,
        "Remove \"N\" Sequences?" => @removeNSequencesBool,
        "Trim Low Quality?" => @trimLowQualityBool
      }
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, 
        @userLastName, @studyName, inputsText='n/a', outputsText='n/a', settings, additionalInfo, resultFileLocations, 
        resultFileURLs=nil, shortToolTitle=nil)
      return successEmailObject
    end
  

    def prepErrorEmail()
      additionalInfo = @errUserMsg
      settings = {
        "Minimum Average Quality" => @minAvgQuality,
        "Minimum Sequence Count" => @minSeqCount,
        "Minimum Sequence Length" => @minSeqLength,
        "Blast Distal Primer?" => @blastDistalPrimerBool,
        "Cut At End?" => @cutAtEndBool,
        "Remove \"N\" Sequences?" => @removeNSequencesBool,
        "Trim Low Quality?" => @trimLowQualityBool
      }
      failureEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, 
        @userLastName, @studyName, inputsText='n/a', outputsText='n/a', settings, additionalInfo, resultFileLocations=nil, 
        resultFileURLs=nil, shortToolTitle=nil)
      failureEmailObject.exitStatusCode = @exitCode
      return failureEmailObject
    end
  
  end
end; end; end; end

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  BRL::Script::main(BRL::Genboree::Tools::Scripts::SeqImporterWrapper)
end
