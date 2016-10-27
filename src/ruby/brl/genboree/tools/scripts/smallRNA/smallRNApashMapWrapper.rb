#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/db/dbrc'
require 'brl/util/emailer'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
include BRL::Genboree::REST


class PashMap

   def initialize(optsHash)
        @input    = File.expand_path(optsHash['--jsonFile'])
        jsonObj = JSON.parse(File.read(@input))
         @toolIdStr = jsonObj['context']['toolIdStr']
         @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr)
        jsonObj = addToolTitle(jsonObj)
         @input  = jsonObj["inputs"]
         @inputURI = jsonObj["inputs"]
         @output = jsonObj["outputs"][0]


        @kWeight = jsonObj["settings"]["kWeight"].to_i
        @kspan = jsonObj["settings"]["kSpan"].to_i
        @gap = jsonObj["settings"]["gap"].to_i
        @diagonals = jsonObj["settings"]["diagonals"].to_i
        @maxMapping = jsonObj["settings"]["maxMappings"].to_i
        @genome = jsonObj["settings"]["targetGenomeVersion"]
        @runName = jsonObj["settings"]["analysisName"]
        @runName = CGI.escape(@runName)
        @uploadResults = jsonObj["settings"]["uploadResults"]
        @sampleName = jsonObj["settings"]["sampleName"]
        @trackName = jsonObj["settings"]["wigTrackName"]
        @roiGbKey = jsonObj['settings']['roiGbKey']
         @email = jsonObj["context"]["userEmail"]
         @user_first = jsonObj["context"]["userFirstName"]
         @user_last = jsonObj["context"]["userLastName"]
         @gbConfFile = jsonObj["context"]["gbConfFile"]
         @username = jsonObj["context"]["userLogin"]
         @apiDBRCkey = jsonObj["context"]["apiDbrcKey"]
         @jobID = jsonObj["context"]["jobId"]

        # set toolTitle and shortToolTitle
        @toolTitle = @toolConf.getSetting('ui', 'label')
        @shortToolTitle = @toolConf.getSetting('ui', 'shortLabel')
        @shortToolTitle = @toolTitle if(@shortToolTitle == "[NOT SET]")

         @scratch = jsonObj["context"]["scratchDir"]
         @gbAdminEmail = jsonObj["context"]["gbAdminEmail"]
         @userId = jsonObj["context"]["userId"]


         ## Pulling out information about database,group and password
         grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
         @dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
          @outputDir = @output.chomp('?')
         uriOutput = URI.parse(@output)
         @hostOutput = uriOutput.host
         @pathOutput = uriOutput.path
         @dbOutput = @dbhelper.extractName(@output)
         @grpOutput = grph.extractName(@output)

         dbrc = BRL::DB::DBRC.new(nil, @apiDBRCkey)
         @pass = dbrc.password
         @user = dbrc.user
         genbConf = BRL::Genboree::GenboreeConfig.load()
         ##building offest file from the same database
         apicaller = WrapperApiCaller.new(genbConf.machineName,"",@userId)
         restPath = "/REST/v1/grp/{grp}/db/{db}/eps?gbKey=#{@roiGbKey}"
         apicaller.setRsrcPath(restPath)
         apicaller.get( {:grp=> "small_RNA_pipeline", :db => "smallRNAanalysis_#{@genome}"})
         eps =  apicaller.parseRespBody()
         epCumSize = 0
         saveOffFile = File.open("#{@scratch}/#{@genome}.off","w+")
         for i in 0...eps["data"]["entrypoints"].size
            saveOffFile.write("#{eps['data']['entrypoints'][i]['name']}\t#{epCumSize}\t#{eps['data']['entrypoints'][i]['length']}\n")
            epCumSize = eps["data"]["entrypoints"][i]["length"] + epCumSize
         end
         saveOffFile.close()

         #downloading bed file from genboree track by track and converting into lff
         @lffClass = " Gene"
         apicaller = WrapperApiCaller.new(genbConf.machineName,"",@userId)
         trackList = jsonObj["settings"]["ROITrack"]

         saveFile = File.open("#{@scratch}/#{@genome}.lff","w+")
         for i in 0...trackList.size
            puts "downloading track #{CGI.unescape(trackList[i])}"
            trackName = CGI.unescape(trackList[i])
            @lff = trackName.split(":")
            @lffType = @lff[0]
            @lffSubType = @lff[1]
            restPath = "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/annos?format=bed&gbKey=#{@roiGbKey}"

            apicaller.setRsrcPath(restPath)
            @buff = ''

            ## Using deafult database and group to download lff target file
            httpResp = apicaller.get( {:grp => "small_RNA_pipeline" , :db => "smallRNAanalysis_#{@genome}" ,:trk => CGI.unescape(trackList[i])} ){|chunck|
            fullChunk = "#{@buff}#{chunck}"
            @buff = ''
            fullChunk.each_line { |line|
               if(line[-1].ord == 10)
                  fields = line.chomp.split("\t")

                  saveFile.write("#{@lffClass}\t#{fields[3]}\t#{@lffType}\t#{@lffSubType}\t#{fields[0]}\t#{fields[1]}\t#{fields[2]}\t#{fields[5]}\t0\t#{fields[4]}\n")
               else
                  @buff += line
               end
               }
            }

         end
         #saveFile.close()

         @refGenome = "#{@scratch}/#{@genome}.off"
         @targetGenome = jsonObj["settings"]["targetGenome"]
         @lffFile = "#{@scratch}/#{@genome}.lff"

         @inputNewList = []
         count = 0
         ##Verifying for custom tracks or input file
         for i in 0...@input.size
            if(@input[i]=~BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
               @input[i] = @input[i].chomp('?')
               uritrack  = URI.parse(@input[i])
               @hosttrack = uritrack.host
               @pathtrack = uritrack.path

               trackhelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)
               @tkOutput = trackhelper.extractName(@input[i])
               @tkOutput = CGI.unescape(@tkOutput)
               @trk = @tkOutput.split(":")
               @lffType = @trk[0]
               @lffSubType = @trk[1]
               $stdout.puts @pathtrack
               apicaller = WrapperApiCaller.new(@hosttrack,"",@userId)
               restPath = "#{@pathtrack}/annos?format=bed"
               restPath << "&gbKey=#{@dbhelper.extractGbKey(@input[i])}" if(@dbhelper.extractGbKey(@input[i]))
               apicaller.setRsrcPath(restPath)

               @buff = ''
               httpResp = apicaller.get {|chunck|
                  fullChunk = "#{@buff}#{chunck}"
                  @buff = ''
                  fullChunk.each_line { |line|
                     if(line[-1].ord == 10)
                        fields = line.chomp.split("\t")
                        saveFile.write("#{@lffClass}\t#{fields[3]}\t#{@lffType}\t#{@lffSubType}\t#{fields[0]}\t#{fields[1]}\t#{fields[2]}\t#{fields[5]}\t0\t#{fields[4]}\n")
                     else
                        @buff += line
                     end
                     }
                  }
               $stdout.puts apicaller.parseRespBody()

                  if apicaller.succeeded?
                     $stdout.puts "success"
                  else
                     apicaller.parseRespBody()
                     $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
                  end
            else
               @inputNewList[count] = @input[i]
               count+=1
            end
         end
         @input = []
         @input = @inputNewList
         saveFile.close()

    end

   def addToolTitle(jsonObj)
    jsonObj['context']['toolTitle'] = @toolConf.getSetting('ui', 'label')
    return jsonObj
  end
    # Used to store job specific info. as attrs on uploaded files
    def setFileAttrs(fileRsrcPath,attrNames, attrValues)
        apiCaller = WrapperApiCaller.new(@hostOutput,"",@userId)
         rsrcPath = "#{fileRsrcPath}/attribute/{attribute}/value"
         rsrcPath << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
         apiCaller.setRsrcPath(rsrcPath)
         attrNames.each_index{|ii|
           payload = { "data" => { "text" => attrValues[ii]}}
          apiCaller.put({:attribute => attrNames[ii]},payload.to_json)
          if(!apiCaller.succeeded?) then $stderr.puts "Unable to set #{attrNames[ii]} attribute of #{fileRsrcPath}\n#{apiCaller.respBody}" end
           }
    end

  def work

    # Running pash mapping on input files
    for i in 0 ...@input.size
        Dir.chdir(@scratch)
        begin
          @input[i] = @input[i].chomp('?')
          uri = URI.parse(@input[i])
          hostInput = uri.host
          pathInput = uri.path
          bz = 0

          @baseName= File.basename(@input[i])
           if(@baseName =~ /(.+).bz2/)
                  name = @baseName.split(/(.+).bz2/)
                  @baseName = name[1]
                  bz =1
            end

          @runNameOriginal = CGI.unescape(@runName)
          @baseNameOriginal = CGI.unescape(@baseName)
          @outputDir = "#{@scratch}/PashMapped/#{@runName}/#{@baseName}"
          system("mkdir -p #{@outputDir}")
          rsrcPath = "#{pathInput}/data"
          rsrcPath << "?gbKey=#{@dbhelper.extractGbKey(@input[i])}" if(@dbhelper.extractGbKey(@input[i]))
          apicaller = WrapperApiCaller.new(hostInput,rsrcPath,@userId)

            puts "downloading #{@baseName}"
            saveFile = File.open("#{@outputDir}/#{@baseName}","w+")
            httpResp = apicaller.get() {|chunk|
               saveFile.write(chunk)
               }
            saveFile.close

            if apicaller.succeeded?
               $stdout.puts "successfully downloaded #{@baseName}"
            else
               apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
               raise "#{apicaller.apiStatusObj['msg']}"
            end

            @input[i] = "#{@outputDir}/#{@baseName}"

              if(bz==1)
                  system("bunzip2 #{@outputDir}/#{@baseName}")
                  $stderr.puts $?.exitstatus
                  system("mv #{@outputDir}/#{@baseName}.out #{@outputDir}/#{@baseName}")
                  $stderr.puts $?.exitstatus
                  @input[i] = "#{@outputDir}/#{@baseName}"
               end

            ##Checking for fastq format of input file
               if(!isFastQ(@input[i]))
                  @exitCode = $?.exitstatus
                  raise  "Input has wrong format. Please check the format of input file"
               end
        @cleanSampleName = @sampleName.gsub(/(?:%[A-F0-9][A-F0-9])+/i,"_")

statsFile = "#{@cleanSampleName}_Stats.txt"
         system("zgrep '@' #{@input[i]}  | cut -d'_' -f3 |rubySumInput.rb > #{@outputDir}/#{statsFile}")
          if(!$?.success?)
             @exitCode = $?.exitstatus
            raise "Couldn't create #{statsFile}"
          end


         ## Calculating usableReads
         filereader = File.open("#{@outputDir}/#{statsFile}")
         filereader.each{|line|
           column = line.split(/sum=/)
           puts column[1]
           @usableReads = column[1]
           }

         ## Calling pash mapping and accountformapping scripts to create mapped files and summary report
         fastaFile = "#{@cleanSampleName}.fa"
         cmd = "zgrep -v '[]*]' #{@outputDir}/#{@baseName} | grep -v  '+' | sed 's/@/>/' >#{@outputDir}/#{fastaFile}"
         $stdout.puts cmd
          system(cmd)

          if(!$?.success?)
             @exitCode = $?.exitstatus
            raise " Couldn't create #{@outputDir}/#{fastaFile}"
          end

          pashOutputFile = "#{@cleanSampleName}.pash3.0.Map.output.txt"
          cmd = "pash-3.0lx.exe -v #{@outputDir}/#{@baseName} -h #{@targetGenome} -k #{@kWeight} -n #{@kspan} -S #{@scratch} -s 22 -G #{@gap} -d #{@diagonals} -o #{@outputDir}/#{pashOutputFile} -N #{@maxMapping}"
          $stdout.puts cmd
          system(cmd)


          if(!$?.success?)
             @exitCode = $?.exitstatus
             raise " pash mapping failed"
          end

         outputEscape = CGI.escape(@outputDir)

         cmd = "accountForMappings.rb -p #{outputEscape}/#{pashOutputFile} -o #{outputEscape} -r  #{outputEscape}/#{fastaFile} -R #{@refGenome} -l #{@lffFile} -u #{@usableReads}"
         $stdout.puts cmd
         system(cmd)

         if(!$?.success?)
            @exitCode = $?.exitstatus
            raise " accountForMappings.rb didn't work"
         end


         trackLFF = "#{fastaFile}.trackCoverage.lff"
         system("gzip -qf #{@outputDir}/#{trackLFF}")
         if(!$?.success?)
            @exitCode = $?.exitstatus
            raise "compression of the file didn't work"
         end

         ##Calling script for converting pash => bed => wig and upload it in genboree

            @wigCheck = true
            command  = "PashToBed.rb -p #{outputEscape}/#{pashOutputFile} -o #{outputEscape} -s #{@scratch} -c #{@refGenome} -O #{CGI.escape(@output)} -g #{@gbConfFile} -j #{@jobID} -a #{@apiDBRCkey} -u #{@userId} -t #{@trackName} >#{@outputDir}/log.wig"
            system(command)
            if(!$?.success?)
               @wigCheck = false
            end

        attrNames = ["JobToolId","CreatedByJobName","SampleName","JobInputs"]
        attrVals = [@toolIdStr, @jobID,CGI.unescape(@sampleName),@inputURI]
        xlsFile = "#{fastaFile}.xls"
         ## Uploading of output xl sheet in given specified path( from json)
         apicaller = WrapperApiCaller.new(@hostOutput,"",@userId)
         restPath = @pathOutput
         path = restPath +"/file/PashMapped/#{@runName}/#{@baseName}/#{xlsFile}/data"
         path << "?gbKey=#{@dbhelper.extractGbkey(@output)}" if(@dbhelper.extractGbKey(@output))
         apicaller.setRsrcPath(path)
         infile = File.open("#{@outputDir}/#{xlsFile}","r")
         apicaller.put(infile)
         if apicaller.succeeded?
            $stdout.puts "success"
            setFileAttrs(restPath +"/file/PashMapped/#{@runName}/#{@baseName}/#{xlsFile}",attrNames,attrVals)
            #Also set attrs on immediate parent folder
            setFileAttrs(restPath +"/file/PashMapped/#{@runName}/#{@baseName}",attrNames,attrVals)
         else
             apicaller.parseRespBody()
            $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
            @exitCode = apicaller.apiStatusObj['statusCode']
            raise "#{apicaller.apiStatusObj['msg']}"
         end
         restPath = @pathOutput
         path = restPath +"/file/PashMapped/#{@runName}/#{@baseName}/#{trackLFF}.gz/data"
         path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
         apicaller.setRsrcPath(path)
         infile1 = BRL::Util::TextReader.new("#{@outputDir}/#{trackLFF}.gz")
         outfile1 = File.open("#{@outputDir}/#{trackLFF}_temp","w")
         infile1.each { | line|
            columns = line.split(/\t/)
            columns[3]= columns[3].gsub(/_/," ")
            outfile1.puts "#{@sampleName}\t#{columns[1]}\t#{@sampleName}\t#{columns[3]}\t#{columns[4]}\t#{columns[5]}\t#{columns[6]}\t#{columns[7]}\t#{columns[8]}\t#{columns[9]}"
            }
         infile1.close
         outfile1.close()
         system("mv #{@outputDir}/#{trackLFF}_temp #{@outputDir}/#{trackLFF}")
         system("gzip -qf #{@outputDir}/#{trackLFF}")
         infile1 = File.open("#{@outputDir}/#{trackLFF}.gz","r")
         apicaller.put(infile1)
         if apicaller.succeeded?
            $stdout.puts "successfully uploaded lff file"
            setFileAttrs(restPath +"/file/PashMapped/#{@runName}/#{@baseName}/#{trackLFF}.gz",attrNames,attrVals)
         else
            apicaller.parseRespBody()
            $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
            @exitCode = apicaller.apiStatusObj['statusCode']
            raise "#{apicaller.apiStatusObj['msg']}"
         end

         ##uploading trackCoverage lff file in genboree
         if(@uploadResults==true)
            #restPath = "/REST/v1/grp/#{CGI.escape(@grpOutput)}/db/#{CGI.escape(@dbOutput)}/annos?userId=#{@userId}"
            #restPath << "&gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
            #apicaller.setRsrcPath(restPath)
            #inFile = File.open("#{@outputDir}/#{trackLFF}.gz")
            #apicaller.put(inFile)
            #$stdout.puts "#{@outputDir}/#{trackLFF}.gz"
            #if apicaller.succeeded?
            #   $stdout.puts "successfully uploaded tracks"
            #else
            #   $stdout.puts apicaller.parseRespBody()
            #
            #   $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
            #   @exitCode = apicaller.apiStatusObj['statusCode']
            #   raise "#{apicaller.apiStatusObj['msg']}"
            #end
            path = "/REST/v1/grp/#{CGI.escape(@grpOutput)}/db/#{CGI.escape(@dbOutput)}?"
            path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
            apicaller.setRsrcPath(path)
            #infile = File.open("#{@outputDir}/finalUploadSummary.lff.gz","r")
            apicaller.get()
            resp = JSON.parse(apicaller.respBody)
            uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
            uploadAnnosObj.refSeqId = resp['data']['refSeqId']
            uploadAnnosObj.groupName = @grpOutput
            uploadAnnosObj.userId = @userId
            uploadAnnosObj.jobId = @jobID
            exp = BRL::Genboree::Helpers::Expander.new("#{@outputDir}/#{trackLFF}.gz")
            exp.extract()
            begin
              uploadAnnosObj.uploadLff(CGI.escape(File.expand_path(exp.uncompressedFileName)), false)
              `rm -f #{exp.uncompressedFileName}`
            rescue => uploadErr
              $stderr.puts "Error: #{uploadErr}"
              $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
              errMsg = "FATAL ERROR: Could not upload track to target database."
              if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
                errMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
              end
              raise errMsg
            end
         end


         restPath = @pathOutput
         path = restPath +"/file/PashMapped/#{@runName}/#{@baseName}/#{statsFile}/data"
         path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
         apicaller.setRsrcPath(path)
         infile1 = File.open("#{@outputDir}/#{statsFile}","r")
         apicaller.put(infile1)
         if apicaller.succeeded?
            setFileAttrs(restPath +"/file/PashMapped/#{@runName}/#{@baseName}/#{statsFile}",attrNames,attrVals)
            $stdout.puts "successfully uploaded stats file"
         else
            apicaller.parseRespBody()
            $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
            @exitCode = apicaller.apiStatusObj['statusCode']
            raise "#{apicaller.apiStatusObj['msg']}"
         end


         uploadedPathForxl = restPath+"/file/PashMapped/#{@runName}/#{@baseName}/#{xlsFile}"
         @apiRSCRpathForxl = CGI.escape(uploadedPathForxl)
         uploadedPathForlff = restPath+"/file/PashMapped/#{@runName}/#{@baseName}/#{trackLFF}.gz"
         @apiRSCRpathForlff = CGI.escape(uploadedPathForlff)
         uploadedPathFortxt =restPath+"/file/PashMapped/#{@runName}/#{@baseName}/#{statsFile}"
         @apiRSCRpathFortxt = CGI.escape(uploadedPathFortxt)



         body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job is completed successfully.

Job Summary:
   JobID : #{@jobID}
   Analysis Name : #{@runNameOriginal}
   Input File : #{@baseNameOriginal}

Result File Location in the Genboree Workbench:
(Direct links to files are at the end of this email)
   Group : #{@grpOutput}
   DataBase : #{@dbOutput}
   Path to File:
      Files
      * PashMapped
       * #{@runNameOriginal}
        * #{@baseNameOriginal}
         * #{xlsFile}
         * #{trackLFF}
         * #{statsFile}

"
if(@wigCheck == true)
   body<<" **Wig file has been uploaded.
"
else
   body<< "Wig file couldn't be created. Please contact Genboree Team"
end

if (@uploadResults==true)
body << " **lff file has been uploaded."

end
body <<
"
The Genboree Team

Result File URLs (click or paste in browser to access file):
    File: #{xlsFile}
    URL:
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpathForxl}/data

    File: #{trackLFF}
    URL:
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpathForlff}/data

    File: #{statsFile}
    URL:
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpathFortxt}/data"

      subject = "Genboree: Your #{@toolTitle} pash mapping tool run is completed "

        rescue => err
              $stderr.puts "Details: #{err.message}"
                 $stderr.puts err.backtrace.join("\n")


                 if(@exitCode=="")
                    @exitCode ="NA"
                 end

             body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job is unsuccessfull .

Job Summary:
   JobID         : #{@jobID}
   Analysis Name : #{@runNameOriginal}
   Input File    : #{@baseNameOriginal}

   Error Message : #{err.message}
   Exit Status   : #{@exitCode}
Please Contact Genboree team with above information.

The Genboree Team

"

      subject = "Genboree: Your #{@toolTitle} job is unsuccessfull "
    end


      if (!@email.nil?) then
         sendEmail(subject,body)
      end

    #  system("cp #{@scratch}/PashMapped/#{@runName}/#{@baseName}/log* #{@scratch}/PashMapped/#{@runName} ")
    #  system("cp #{@scratch}/PashMapped/#{@runName}/#{@baseName}/*pash* #{@scratch}/PashMapped/#{@runName}")
    #  system("rm #{@scratch}/PashMapped/#{@runName}/#{@baseName}/*")

    end

    File.delete("#{@scratch}/#{@genome}.lff")
  end

  def sendEmail(subjectTxt, bodyTxt)

    puts "=====email Station===="
    #puts @gbAdminEmail
    #puts @userEmail

    email = BRL::Util::Emailer.new()
    email.setHeaders("genboree_admin@genboree.org", @email, subjectTxt)
    email.setMailFrom('genboree_admin@genboree.org')
    email.addRecipient(@email)
    email.addRecipient(@gbAdminEmail)
    email.setBody(bodyTxt)
    email.send()

  end


  ##Validating the format of input file
    def isFastQ(fileName)
      returns = false
      checkFile = BRL::Util::TextReader.new(fileName)
      checkFile.each { | line |
         if(line[0,1] == "@")
            returns = true
         end
         break
      }
    returns
   end



   def PashMap.usage(msg='')
          unless(msg.empty?)
            puts "\n#{msg}\n"
          end
          puts "

        PROGRAM DESCRIPTION:
          Wrapper to run pashMapping and accountForMappings.rb . It is a wrapper file.

        COMMAND LINE ARGUMENTS:
          --file         | -j => Input json file
          --help         | -h => [Optional flag]. Print help info and exit.

       usage:

      ruby removeAdaptarsWrapper.rb -f jsonFile

        ";
            exit;
        end #

      # Process Arguements form the command line input
      def PashMap.processArguements()
        # We want to add all the prop_keys as potential command line options
          optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                        ['--help'     ,'-h',GetoptLong::NO_ARGUMENT]
                      ]
          progOpts = GetoptLong.new(*optsArray)
          PashMap.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
          optsHash = progOpts.to_hash

          Coverage if(optsHash.empty? or optsHash.key?('--help'));
          return optsHash
      end

end

optsHash = PashMap.processArguements()
performQCUsingFindPeaks = PashMap.new(optsHash)
performQCUsingFindPeaks.work()
