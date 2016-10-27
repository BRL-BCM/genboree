#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/tools/toolWrapper'

include GSL
include BRL::Genboree::REST

module BRL; module Genboree; module Tools; module Scripts
  class RDPWrapper < BRL::Genboree::Tools::ToolWrapper
    VERSION = 1.0
    COMMAND_LINE_ARGS = {
      '--inputFile' => [GetoptLong::REQUIRED_ARGUMENT, '-j', ""]
    }
    DESC_AND_EXAMPLES = {
      :description => "RDP wrapper for Microbiome Workbench",
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
      # outputs
      @output = @outputs[0]
      @dbOutput = @dbApiHelper.extractName(@output)
      @grpOutput = @grpApiHelper.extractName(@output)
      uriOutput = URI.parse(@output)
      @hostOutput = uriOutput.host
      @pathOutput = uriOutput.path
  
      @tempOutputArray = []
      if(@outputs.size == 2)
        # force database as first output, project as second output
        if(@outputs[0] !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
          @tempOutputArray[0] = @outputs[1]
          @tempOutputArray[1] = @outputs[0]
          @outputs = @tempOutputArray
          @output = @outputs[0]
        end
      end
  
      # context
      @username = @context["userLogin"]
      @gbAdminEmail = @context["gbAdminEmail"]
  
      # settings
      @jobName = @settings["jobName"]
      @cgiJobName = CGI.escape(@jobName)
      @filJobName = @cgiJobName.gsub(/%[0-9a-f]{2,2}/i, "_")
  
      @studyName = @settings["studyName"]
      @cgiStudyName = CGI.escape(@studyName)
      @filStudyName = @cgiStudyName.gsub(/%[0-9a-f]{2,2}/i, "_")
  
      # other
      @fileNameBuffer = []
      @dbu = BRL::Genboree::DBUtil.new(@dbrcKey, nil, nil)
      @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
      @success = false
      @hashTable = Hash.new{|hh,kk| hh[kk] = []}
      @jointInfo = Struct.new(:index, :value)
  
      rescue => err
        @err = err
        @errUserMsg = "ERROR: Could not set up required variables for running job. "
        @errInternalMsg = "ERROR: Could not set up required variables for running job. Check your jobFile.json to make sure all variables are defined."
        @exitCode = 22
      end
      
      return @exitCode
    end
 
    def downloadData
      saveFileM = File.open("#{@outputDir}/metadata.txt","w+")
      for i in 0...@inputs.size
        @inputs[i] = @inputs[i].chomp('?')
        saveFile = File.open("#{@outputDir}/#{File.basename(@inputs[i])}.tar.gz","w+")
        puts "downloading metadata and filtered files from #{File.basename(@inputs[i])}"
        @db  = @dbApiHelper.extractName(@inputs[i])
        @grp = @grpApiHelper.extractName(@inputs[i])
        @trk  = @trkApiHelper.extractName(@inputs[i])
        uri = URI.parse(@inputs[i])
        host = uri.host
        path = uri.path
        path = path.chomp('?')
        apicaller =ApiCaller.new(host,"",@hostAuthMap)
        path = path.gsub(/\/files\//,'/file/')
        pathR = "#{path}/filtered_fasta.result.tar.gz/data?"
        pathR << "gbKey=#{@dbApiHelper.extractGbKey(@inputs[i])}" if(@dbApiHelper.extractGbKey(@inputs[i]))
        apicaller.setRsrcPath(pathR)
        @buff = ''
        httpResp = apicaller.get(){|chunk|
          fullChunk = "#{@buff}#{chunk}"
          @buff = ''
          fullChunk.each_line{ |line|
            if(line[-1].ord == 10)
              saveFile.write line
            else
              @buff += line
            end
          }
        }
        saveFile.close
        Dir.chdir(@outputDir)
        system("tar -zxf #{@outputDir}/#{File.basename(@inputs[i])}.tar.gz")
        Dir.chdir(@scratchDir)
        #downloading metadata file
        pathR = "#{path}/sample.metadata/data?"
        apicaller.setRsrcPath(pathR)
        @buff = ''
          httpResp = apicaller.get(){|chunck|
               saveFileM.write chunck
           }
        end
        saveFileM.close
  
        fileCorrection = File.open("#{@outputDir}/tmp.metadata.txt","w+")
        fileCorrectionO = File.open("#{@outputDir}/metadata.txt","r")
        track = 0
         fileCorrectionO.each_line { |line|
           line.strip!
           next if(line.empty?)
           if(line =~ /^SampleID/i )
              @headers = line.split(/\t/, Integer::MAX32)
           elsif(line !~ /^SampleID/i)
               @columns = line.split(/\t/, Integer::MAX32)
               for ii in 0 ...@headers.size
                 ji = @jointInfo.new(track,@columns[ii])
                 @hashTable[@headers[ii]].push(ji)
               end
              track += 1
           end
           }
  
        ##Finding number of files, that would be in mSize
        maxSize =[]
        @hashTable.each{|k,v|
            maxSize.push(v.size)
           }
        mSize = maxSize.max
        @newhashTable = Hash.new{|hh,kk| hh[kk] = []}
  
        @hashTable.each_key{|k|
          for ik in 0 ...mSize
            @newhashTable[k][ik] = "no-Value"
          end
  
          }
        ##Building new hash of array and filling up "no-values" for missing headers
        @hashTable.each{|k,v|
           v.each{|l|
              @newhashTable[k][l.index] = l.value
           }
        }
         #Maintaining the order
        fileCorrection.print "sampleID\tsampleName\tbarcode\tminseqLength\tminAveQual\tminseqCount\tproximal\tdistal\tregion\tflag1"
        fileCorrection.print "\tflag2\tflag3\tflag4\tfileLocation"
        @newhashTable.each{|k,v|
           kk = k.strip
           unless(k == "sampleName" or k == "barcode" or k == "proximal" or k == "distal" or k == "region" or k == "fileLocation" or k == "minseqLength" or k == "minAveQual")
              unless (k == "minseqCount" or k =="flag1" or k =="flag2" or k == "flag3" or k== "flag4" or k=="sampleID")
                 fileCorrection.print "\t#{kk}"
              end
           end
        }
        fileCorrection.puts
        for i in 0 ... mSize
           firstOcc = true
           @newhashTable.each{|k,v|
              if(firstOcc)
              fileCorrection.print "#{@newhashTable["sampleName"][i]}\t#{@newhashTable["sampleName"][i]}\t#{@newhashTable["barcode"][i]}\t"
              fileCorrection.print "#{@newhashTable["minseqLength"][i]}\t#{@newhashTable["minAveQual"][i]}\t#{@newhashTable["minseqCount"][i]}\t"
              fileCorrection.print "#{@newhashTable["proximal"][i]}\t#{@newhashTable["distal"][i]}\t#{@newhashTable["region"][i]}\t#{@newhashTable["flag1"][i]}\t"
              fileCorrection.print "#{@newhashTable["flag2"][i]}\t#{@newhashTable["flag3"][i]}\t#{@newhashTable["flag4"][i]}\t#{@newhashTable["fileLocation"][i]}"
              firstOcc = false
           end
           unless(k == "sampleName" or k == "barcode" or k == "proximal" or k == "distal" or k == "region" or k == "fileLocation" or k == "minseqLength" or k == "minAveQual")
              unless (k == "minseqCount" or k =="flag1" or k =="flag2" or k == "flag3" or k== "flag4" or k == "sampleID")
                 value = @newhashTable[k][i].strip
                 fileCorrection.print "\t#{value}"
              end
           end
           }
           fileCorrection.puts
        end
        fileCorrectionO.close
        fileCorrection.close
        system(" mv #{@outputDir}/tmp.metadata.txt #{@outputDir}/metadata.txt ")
      # end for
    end

    #def work
    def run()
      @exitCode = 0
      begin 
        system("mkdir -p #{@scratchDir}")
        Dir.chdir(@scratchDir)
        @outputDir = "#{@scratchDir}/#{@filJobName}"
        system("mkdir -p #{@outputDir}")
        downloadData()
        ##Calling rdp pipeline
        rdpExecutable = "run_RDP_pipeline.rb"
        cmd = " #{rdpExecutable} #{@outputDir}/metadata.txt  #{@outputDir}>#{@outputDir}/rdp.log 2>#{@outputDir}/rdp.error.log"
        $stdout.puts cmd
        system(cmd)
        if(!$?.success?)
          @exitCode = $?.exitstatus
          raise " Error running #{rdpExecutable}"
        else
          @success = true
        end
    
        if(@outputs.size==2)
             projectPlot()
             if(!$?.success?)
                sucess = false
                @exitCode = $?.exitstatus
                raise "project plot failed"
             end
          end
    
        if(@success) then
          compressFiles()
          uploadData()
          Dir.chdir("#{@outputDir}")
             system("find . ! -name '*.log' | xargs rm -rf")
    
              Dir.chdir(@scratchDir)
        end
      rescue => err
        if(@exitCode == EXIT_OK)
          @err = err
          $stderr.debugPuts(__FILE__, __method__, "RDP ERROR", @err.message)
          $stderr.debugPuts(__FILE__, __method__, "RDP ERROR", @err.backtrace)
          @exitCode = 28
          @errUserMsg = @errUserMsg = "ERROR: An unrecognized error occurred while running #{@toolTitle}."
        end
        # otherwise when @exitCode is set, assume @err, @errUserMsg, and @errInternalMsg were also set
      end

      return @exitCode
    end
  
    # tar of output directory
    def compressFiles
      Dir.chdir("#{@outputDir}/RDPsummary")
      #system("tar -zcf #{@sampleSetName1}.tar.gz * --exclude=*.log --exclude=*.sra --exclude=*.sff --exclude=*.local.metadata")
      system("tar czf class.result.tar.gz class")
      system("tar czf domain.result.tar.gz domain")
      system("tar czf family.result.tar.gz family")
      system("tar czf genus.result.tar.gz genus")
      system("tar czf order.result.tar.gz order")
      system("tar czf phylum.result.tar.gz phylum")
      Dir.chdir("#{@outputDir}")
      system("tar czf png.result.tar.gz `find . -name '*.PNG'`")
      Dir.chdir(@scratchDir)
    end
  
    def uploadUsingAPI(studyName,toolName,jobName,fileName,filePath)
      restPath = @pathOutput
      path = restPath +"/file/MicrobiomeWorkBench/#{studyName}/#{toolName}/#{jobName}/#{fileName}/data"
      path << "?gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
      @apicaller.setRsrcPath(path)
      infile = File.open("#{filePath}","r")
      @apicaller.put(infile)
      if @apicaller.succeeded?
        $stdout.puts "successfully uploaded #{fileName} "
      else
        $stderr.puts @apicaller.parseRespBody()
        $stderr.puts "API response; statusCode: #{@apicaller.apiStatusObj['statusCode']}, message: #{@apicaller.apiStatusObj['msg']}"
        @exitCode = @apicaller.apiStatusObj['statusCode']
        raise "#{@apicaller.apiStatusObj['msg']}"
      end
    end
  
    def prepSuccessEmail()
      # prepare inputs description 
      inputsText = {}
      @inputs.each{|input|
        inputTokens = input.split('/')
        folderName = CGI.unescape(inputTokens[-1])
        inputsText[folderName] = "folder used as #{@shortToolTitle} input"
      }

      # prepare resultFileLocations
      locationStr = "Group : #{@grpOutput}\n"\
        "Database : #{@dbOutput}\n"\
        "Files\n"\
        "  MicrobiomeWorkBench\n"\
        "    #{@studyName}\n"\
        "      RDP\n"\
        "        #{@jobName}\n"
      resultFileLocations = [locationStr]

      # prepare resultFileURLs
      if(@outputs.size == 2)
        # outputs were sorted in processJobConf
        prjName = @prjApiHelper.extractName(@outputs[1])
        if(prjName)
          resultFileURLs = {
            @jobName => "http://#{@hostOutput}/java-bin/project.jsp?projectName=#{prjName}"
          }
        else
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "project API helper unable to extract name for #{@outputs[1].inspect}")
          resultFileURLs = nil
        end
      else
        resultFileURLs = nil
      end
      settings = {
        "RDP Version" => "2.2",
        "RDP Bootstrap Cutoff" => "0.8"
      }
      successEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, 
        @userLastName, @studyName, inputsText, outputsText='n/a', settings, additionalInfo=nil, resultFileLocations, 
        resultFileURLs, @shortToolTitle)
      return successEmailObject
    end

    def prepErrorEmail()
      # prepare inputs description 
      inputsText = {}
      @inputs.each{|input|
        inputTokens = input.split('/')
        folderName = CGI.unescape(inputTokens[-1])
        inputsText[folderName] = "folder used as #{@shortToolTitle} input"
      }

      # prepare error message
      additionalInfo = @errUserMsg

      # prepare settings message
      settings = {
        "RDP Version" => "2.2",
        "RDP Bootstrap Cutoff" => "0.8"
      }
      failureEmailObject = BRL::Genboree::Tools::WrapperEmailer.new(@toolTitle, @userEmail, @jobId, @userFirstName, 
        @userLastName, @studyName, inputsText='n/a', outputsText='n/a', settings, additionalInfo, resultFileLocations=nil, 
        resultFileURLs=nil, @shortToolTitle)
      failureEmailObject.exitStatusCode = @exitCode
      return failureEmailObject
    end
 
    # Call script to create html pages of plot in project area
    def projectPlot
      jsonLocation  = CGI.escape("#{@scratchDir}/jobFile.json")
      htmlLocation = CGI.escape("#{@outputDir}")
      cmd = "importRDPFiles.rb -j #{jsonLocation} -i #{htmlLocation} >#{@outputDir}/project_plot.log 2>#{@outputDir}/project_plot.error.log"
      $stdout.puts cmd
      system(cmd)
    end
  
    def uploadData
      @apicaller = ApiCaller.new(@hostOutput,"",@hostAuthMap)
      restPath = @pathOutput
      @success = false
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"class.result.tar.gz","#{@outputDir}/RDPsummary/class.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"domain.result.tar.gz","#{@outputDir}/RDPsummary/domain.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"family.result.tar.gz","#{@outputDir}/RDPsummary/family.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"genus.result.tar.gz","#{@outputDir}/RDPsummary/genus.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"order.result.tar.gz","#{@outputDir}/RDPsummary/order.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"phylum.result.tar.gz","#{@outputDir}/RDPsummary/phylum.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"png.result.tar.gz","#{@outputDir}/png.result.tar.gz")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"count.xlsx","#{@outputDir}/RDPreport/count.xlsx")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"weighted.xlsx","#{@outputDir}/RDPreport/weighted.xlsx")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"weighted_normalized.xlsx","#{@outputDir}/RDPreport/weighted_normalized.xlsx")
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"count_normalized.xlsx","#{@outputDir}/RDPreport/count_normalized.xlsx")

      ##several xls files generated to summary the result from other tsv files
      xlsFiles = Dir.glob("#{@outputDir}/RDPreport/*.xls")
      xlsFiles.each {|files|
        fName = File.basename(files)
        fName = fName.gsub!(/RDP_/,'')
        fName = fName.gsub!(/_/,'.')
	fName = CGI.escape(fName)
        uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"#{fName}","#{@outputDir}/RDPreport/#{File.basename(files)}")
        }

      # upload metadata file
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"sample.metadata","#{@outputDir}/metadata.txt")
      # upload json setting file
      uploadUsingAPI(@cgiStudyName, @toolTitle,@cgiJobName,"settings.json","#{@scratchDir}/jobFile.json")
      @success = true
    end
  end
end; end; end; end

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  BRL::Script::main(BRL::Genboree::Tools::Scripts::RDPWrapper)
end
