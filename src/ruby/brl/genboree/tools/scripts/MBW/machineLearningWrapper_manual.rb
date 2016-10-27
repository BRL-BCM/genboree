#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/user'
require 'brl/util/expander'
require 'brl/util/convertText'

include GSL
include BRL::Genboree::REST


class MachineLearningWrapper

  def initialize(optsHash)
    @input    = File.expand_path(optsHash['--jsonFile'])
    jsonObj = JSON.parse(File.read(@input))
    @input  = jsonObj["inputs"]
    @output = jsonObj["outputs"][0]

    @gbConfFile = jsonObj["context"]["gbConfFile"]
    @apiDBRCkey = jsonObj["context"]["apiDbrcKey"]
    @scratch = jsonObj["context"]["scratchDir"]
    @email = jsonObj["context"]["userEmail"]
    @user_first = jsonObj["context"]["userFirstName"]
    @user_last = jsonObj["context"]["userLastName"]
    @username = jsonObj["context"]["userLogin"]
    @toolIdStr = jsonObj["context"]["toolIdStr"]
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr)
    initToolTitles()
    @gbAdminEmail = jsonObj["context"]["gbAdminEmail"]
    @jobID = jsonObj["context"]["jobId"]
    @userId = jsonObj["context"]["userId"]

    @featurs = ""
    @featureLists = jsonObj["settings"]["featureList"]
    for i in 0...@featureLists.size
      @featurs << "#{@featureLists[i]},"
    end
    @featurs = @featurs.chomp(",")

    @jobName = jsonObj["settings"]["jobName"]
    @studyName = jsonObj["settings"]["studyName"]

    @grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @trackhelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)
    genbConfig = BRL::Genboree::GenboreeConfig.load()
    @dbu = BRL::Genboree::DBUtil.new(genbConfig.dbrcKey, nil, nil)
    @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
    ##pulling out upload location specifications
    @output = @output.chomp('?')
    @dbOutput = @dbhelper.extractName(@output)
    @grpOutput = @grph.extractName(@output)
    uriOutput = URI.parse(@output)
    @hostOutput = uriOutput.host
    @pathOutput = uriOutput.path

    @uri = @grph.extractPureUri(@output)
    dbrc = BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass = dbrc.password
    @user = dbrc.user
    @uri = URI.parse(@input[0])
    @host = @uri.host
    @exitCode= ""

    @hashTableofIds = {}
    @fileNameBuffer = []
    @jobName1 = CGI.escape(@jobName)
    @jobName = @jobName1.gsub(/%[0-9a-f]{2,2}/i, "_")
    @studyName1 = CGI.escape(@studyName)
    @studyName = @studyName1.gsub(/%[0-9a-f]{2,2}/i, "_")
  end


  def work
      system("mkdir -p #{@scratch}")
      Dir.chdir(@scratch)
      @outputDir = "#{@scratch}/#{@jobName}"
      system("mkdir -p #{@outputDir}/otu_table")
      #saveFileM = File.open("#{@outputDir}/otu_table/mapping.txt","w+")
      mappedFile = File.open("#{@outputDir}/otu_table/mapping.txt","w+")
      mappedFile.write "#SampleID\tBarcodeSequence\tNullLinkerPrimerSequence"

      for i in 0 ... @input.size

         @input[i] = @input[i].chomp('?')
         @db  = @dbhelper.extractName(@input[i])
         @grp = @grph.extractName(@input[i])
         @trk  = @trackhelper.extractName(@input[i])
         uri = URI.parse(@input[i])
         host = uri.host
         path = uri.path
         path = path.chomp('?')
         if(@input[i]=~/\/bioSample\//)
            path = "#{path}?format=tabbed"
            path << "&gbKey=#{@dbhelper.extractGbKey(@input[i])}" if(@dbhelper.extractGbKey(@input[i]))
            puts "bosmaple"
         else
            path = path + "/data"
            path << "?gbKey=#{@dbhelper.extractGbKey(@input[i])}" if(@dbhelper.extractGbKey(@input[i]))
         end

         $stdout.puts path
         apicaller =ApiCaller.new(host,"",@hostAuthMap)

         apicaller.setRsrcPath(path)

            $stdout.puts "downloading #{i} file #{File.basename(@input[i])}"
            saveFile = File.open("#{@outputDir}/otu_table/#{File.basename(@input[i])}","w+")
            httpResp = apicaller.get(){|chunck|
                     saveFile.write chunck
               }
            saveFile.close
            # Extract the file since it may be compressed
            exp = BRL::Util::Expander.new("#{@outputDir}/otu_table/#{File.basename(@input[i])}")
            exp.extract()
            if(exp.uncompressedFileName != "#{@outputDir}/otu_table/#{File.basename(@input[i])}")
              `mv #{exp.uncompressedFileName} #{@outputDir}/otu_table/#{File.basename(@input[i])}`
            end
            # Convert the downloaded file into unix format
            convObj = BRL::Util::ConvertText.new("#{@outputDir}/otu_table/#{File.basename(@input[i])}", true)
            convObj.convertText()
            checkContent = ""
            if( i == 0)
               checkContent = %x{grep "# QIIME v1.2.0 OTU table" #{@outputDir}/otu_table/#{File.basename(@input[0])}}
               checkContent1 = %x{grep "#OTU ID" #{@outputDir}/otu_table/#{File.basename(@input[0])}}
               if(checkContent == "" )
                   @exitCode = $?.exitstatus
                  raise "Header ('# QIIME v1.2.0 OTU table') is missing from OTU table. Please refer the help section for the format of OTU table"
               elsif(checkContent1 == "")
                  @exitCode = $?.exitstatus
                  raise "Header column (#OTU ID) in second line is missing or wrong in OTU table. Please refer the help section for the format of OTU table"
               else
                  system("mv #{@outputDir}/otu_table/#{File.basename(@input[i])} #{@outputDir}/otu_table/otu_table.txt")
                  fileRead =File.open("#{@outputDir}/otu_table/otu_table.txt")
                  t = 0
                  fileRead.each_line{ |line|
                     if(t ==1)
                        if(line !~ /#OTU/)
                           @exitCode = $?.exitstatus
                           raise "Please refer the help section for the format of OTU table"

                        end
                        c = line.split(/\t/)
                        for iij in 1 ...c.size-1
                           @hashTableofIds[c[iij]] = ""
                        end
                     end
                     t +=1
                     }
               end
               if( t<4 )
                  @exitCode = $?.exitstatus
                   raise "No enough data in OTU table for classification"

               end

            else

             tempFile = File.open("#{@outputDir}/otu_table/#{File.basename(@input[i])}")

              idHash = {}
              checkT = false
             killList = ["name","minseqLength", "#sampleName", "sampleName", "minAveQual", "minseqCount", "proximal", "distal", "region", "flag1", "flag2", "flag3", "type", "#name","flag4", "fileLocation", "sampleID", "barcode", "biomaterialState", "biomaterialProvider","biomaterialSource","state","region"]
             killArray = []
             track = 0
             index = 0
             tempFile.each_line { |line|
                columns = line.split(/\t/)
                if(track == 0)
                  for iy in 0...columns.size
                    columns[iy].gsub!("#", "")
                    if(columns[iy] == "name" or columns[iy] == "sampleName")
                       idHash[columns[iy]] = iy
                    end
                 end
                end


                checkT = false
                if(track != 0)
                   if(idHash.key?("name"))
                      index = idHash["name"]
                   elsif(idHash.key?("sampleName"))
                      index = idHash["sampleName"]
                   else
                      raise " No sampleName or name column was found. Please refer the help section for the format of metadata file"
                   end
                   if(@hashTableofIds.include?(columns[index.to_i]))
                        mappedFile.write "#{columns[index.to_i]}\tTGGTGAAC\tNULL"
                        checkT = true
                   end

                end


                  for ii in 0 ...columns.size
                     if( track ==0 )

                        unless(killList.include?(columns[ii]))
                           if( i > 0 )
                              killArray.push(ii)
                              mappedFile.write "\t#{columns[ii]}"
                           end
                        end
                     end

                     if(killArray.include?(ii) and track != 0 )
                        mappedFile.write "\t#{columns[ii]}"
                     end
                  end
                 # mappedFile.write "\n"
                  track += 1

                }
               end
      end

             mappedFile.close


         ##Extra Validation to ensure correct feature list ( unique 2) and at least 3 sample ids
         @hashTableVer = Hash.new { |hh, kk| hh[kk] = [] }
         file = File.open("#{@outputDir}/otu_table/mapping.txt")
         skipLine = false
         file.each_line { |line|
               columns = line.split(/\t/)
               if(!skipLine)
                  for iu in 3...columns.size
                     @hashTableVer[iu] = []
                  end
               elsif(skipLine)
                  for iu in 3...columns.size
                     @hashTableVer[iu].push(columns[iu])
                     @hashTableVer[iu].uniq!
                  end
               end
               skipLine = true
            }
         file.close
         filterArray = []
         @hashTableVer.each { |k ,v|
            if(@hashTableVer[k].size < 2)
               filterArray.push(k)
            end

            }
        ##Filtering mapping.txt
        file = File.open("#{@outputDir}/otu_table/tmp.mapping.txt","w+")
        fileo = File.open("#{@outputDir}/otu_table/mapping.txt")
        selectedFeatures = ""
        @failedFeatures = ""
        p = 0
        @failedEatureArray = []
        firstLine = true

           fileo.each_line { |line|
              line.strip!
              c = line.split(/\t/)
              for iy in 0...c.size
                 if(!filterArray.include?(iy))
                    file.write "#{c[iy]}\t"
                 elsif(filterArray.include?(iy) and firstLine ==true)
                    @failedFeatures << "#{c[iy]},"
                    @failedEatureArray[p] = c[iy]
                    p += 1
                 end

              end
              firstLine = false
              file.write "\n"
              }

        #3Finding features which should be used and tracking record of them

        @notUsedFeatures = @failedEatureArray & @featureLists

        file.close
        fileo.close
        #system("mv  #{@outputDir}/otu_table/tmp.mapping.txt #{@outputDir}/otu_table/mapping.txt")
        fileo = File.open("#{@outputDir}/otu_table/tmp.mapping.txt")
        fileo1 = File.open("#{@outputDir}/otu_table/tmp1.mapping.txt","w+")

        selectedFeatures = ""
        firstLine = true
        fileo.each_line { |line|
           line.strip!
           columns = line.split(/\t/)
           if(firstLine == true)
            for ik in 3 ...columns.size
                selectedFeatures << "#{columns[ik]},"
            end
            firstLine = false
           end

           fileo1.puts line
           }
        selectedFeatures.chomp!(",")
        @failedFeatures.chomp!(",")

        selectedFeatures = ""
        minusFeatureList = @featureLists - @failedEatureArray
        for ir in 0...minusFeatureList.size
           selectedFeatures << "#{minusFeatureList[ir]},"
        end
         selectedFeatures.chomp!(",")

        fileo.close
        fileo1.close
        system("cp  #{@outputDir}/otu_table/tmp1.mapping.txt #{@outputDir}/otu_table/mapping.txt")


         if(filterArray.size ==@hashTableVer.size or selectedFeatures.size ==0 )
            @exitCode = $?.exitstatus
            raise "All selected features are removed as they have only one unique value"

         end

         numOfLine = %x{wc -l #{@outputDir}/otu_table/mapping.txt}
         if(numOfLine.to_i < 4)
            @exitCode = $?.exitstatus
            raise "There should be atleast 2 unique sampleIDs"

         end



      ##Calling qiime pipeline
      sucess =true
      cmd = "module load R/2.11.1 ;run_MachineLearning_ARG.rb -f #{@outputDir}/otu_table -o #{@outputDir} -m '#{selectedFeatures}'>#{@outputDir}/ml.log 2>#{@outputDir}/ml.error.log"
      $stdout.puts cmd
      system(cmd)
       if(!$?.success?)
         sucess =false
            @exitCode = $?.exitstatus
            raise " machinelearning script didn't run properly"
       end
       compression()
       if(!$?.success?)
         sucess =false
            @exitCode = $?.exitstatus
            raise " compression didn't run properly"
       end
       upload()
       if(!$?.success?)
         sucess =false
            @exitCode = $?.exitstatus
            raise "upload failed"
       end
       if(sucess == true)
         sendSEmail()
         $stdout.puts "sent"
         Dir.chdir("#{@outputDir}")
          #system("find . ! -name '*.log' | xargs rm -rf")
          Dir.chdir(@scratch)
       end

  end

    ##tar of output directory
   def compression
     Dir.chdir("#{@outputDir}")
     system("tar czf raw.result.tar.gz * --exclude=*.log")
     system("tar czf 5.result.tar.gz `find . -name '*5_[sortedImportance|bag]*.txt'`")
     system("tar czf 25.result.tar.gz `find . -name '*25_[sortedImportance|bag]*.txt'`")
     Dir.chdir(@scratch)

   end

     ##uploading files on specified location
   def upload
     begin
          apicaller =ApiCaller.new(@hostOutput,"",@hostAuthMap)
          restPath = @pathOutput

           ##uplaoding otu table
            path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/MachineLearning/#{@jobName1}/raw.result.tar.gz/data"
            path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
            apicaller.setRsrcPath(path)
            infile = File.open("#{@outputDir}/raw.result.tar.gz","r")
            apicaller.put(infile)
             if apicaller.succeeded?
               $stdout.puts "successfully uploaded raw.result.tar.gz"
             else
               $stderr.puts apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
              raise "#{apicaller.apiStatusObj['msg']}"
             end

          ##uplaoding otu table
            path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/MachineLearning/#{@jobName1}/otu_abundance_cutoff_5.result.tar.gz/data"
            apicaller.setRsrcPath(path)
            infile = File.open("#{@outputDir}/5.result.tar.gz","r")
            apicaller.put(infile)
             if apicaller.succeeded?
               $stdout.puts "successfully uploaded 5.result.tar.gz "
             else
               $stderr.puts apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
              raise "#{apicaller.apiStatusObj['msg']}"
             end


              path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/MachineLearning/#{@jobName1}/otu_abundance_cutoff_25.result.tar.gz/data"
            apicaller.setRsrcPath(path)
            infile = File.open("#{@outputDir}/25.result.tar.gz","r")
            apicaller.put(infile)
             if apicaller.succeeded?
               $stdout.puts "successfully uploaded 25.result.tar.gz "
             else
               $stderr.puts apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
              raise "#{apicaller.apiStatusObj['msg']}"
             end

             #uploading metadata file back
           path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/MachineLearning/#{@jobName1}/sample.mapping.txt/data"
           apicaller.setRsrcPath(path)
           infile = File.open("#{@outputDir}/otu_table/mapping.txt","r")
           apicaller.put(infile)
            if apicaller.succeeded?
               $stdout.puts "successfully uploaded metadata file "
            else
               $stderr.puts apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
             raise "#{apicaller.apiStatusObj['msg']}"
            end

          ##uploading json setting file
           path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/MachineLearning/#{@jobName1}/settings.json/data"
           apicaller.setRsrcPath(path)
           infile = File.open("#{@scratch}/jobFile.json","r")
           apicaller.put(infile)
            if apicaller.succeeded?
               $stdout.puts "successfully uploaded jsonfile file "
            else
               $stderr.puts apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
             raise "#{apicaller.apiStatusObj['msg']}"
            end
     end

     end

    def sendSEmail()
    $stdout.puts "sending"
    body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job completed successfully.

Job Summary:
   JobID                  : #{@jobID}
   Study Name             : #{CGI.unescape(@studyName)}
   Job Name               : #{CGI.unescape(@jobName)}

Result File Location in the Genboree Workbench:
   Group : #{@grpOutput}
   DataBase : #{@dbOutput}
   Path to File:
      Files
      * MicrobiomeData
         * #{CGI.unescape(@studyName)}
            *MachineLearning
               *#{CGI.unescape(@jobName1)}


The Genboree Team"

if(@notUsedFeatures.size != 0 )
   body <<"

Following USER SELECTED features weren't used as they had only one unique value
"

   for ii in 0 ...@notUsedFeatures.size
      body <<" --#{@notUsedFeatures[ii]}"
   end
end






      subject = "Genboree: Your #{@shortToolTitle} job is complete "

      if (!@email.nil?) then
            sendEmail(subject,body)
           end
    end

       def sendFailureEmail(errMsg)


          body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job was unsucessfull.

Job Summary:
  JobID                    : #{@jobID}
  Study Name               : #{CGI.unescape(@studyName)}
  Job Name                 : #{CGI.unescape(@jobName)}

      Error Message : #{errMsg}
      Exit Status   : #{@exitCode}

Please Contact Genboree team with above information.

The Genboree Team"

      subject = "Genboree: Your #{@shortToolTitle} job was unsuccessfull "


         if (!@email.nil?) then
             sendEmail(subject,body)
         end

         ##Deleting file from workbech created by UI
         apicaller =ApiCaller.new(@hostOutput,"",@hostAuthMap)
         restPath = @pathOutput
         path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/MachineLearning/#{@jobName1}/jobFile.json"
         path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
         apicaller.setRsrcPath(path)
         apicaller.delete()
         $stdout.puts apicaller.parseRespBody()

   end


  def initToolTitles()
    @toolTitle = @toolConf.getSetting('ui', 'label')
    @shortToolTitle = @toolConf.getSetting('ui', 'shortLabel')
    @shortToolTitle = @toolTitle if(@shortToolTitle.to_s !~ /\S/ or @shortToolTitle =~ /\[NOT SET\]/i)
  end

  ##Email
  def sendEmail(subjectTxt, bodyTxt)
    email = BRL::Util::Emailer.new()
    email.setHeaders("genboree_admin@genboree.org", @email, subjectTxt)
    email.setMailFrom('genboree_admin@genboree.org')
    email.addRecipient(@email)
    email.addRecipient("genboree_admin@genboree.org")
    email.setBody(bodyTxt)
    email.send()
  end


   def MachineLearningWrapper.usage(msg='')
          unless(msg.empty?)
            puts "\n#{msg}\n"
          end
          puts "

        PROGRAM DESCRIPTION:
           seqImporter wrapper for microbiome workbench
        COMMAND LINE ARGUMENTS:
          --file         | -j => Input json file
          --help         | -h => [Optional flag]. Print help info and exit.

       usage:

      ruby removeAdaptarsWrapper.rb -f jsonFile

        ";
            exit;
        end #

      # Process Arguements form the command line input
      def MachineLearningWrapper.processArguements()
        # We want to add all the prop_keys as potential command line options
          optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                        ['--help'      ,'-h',GetoptLong::NO_ARGUMENT]
                      ]
          progOpts = GetoptLong.new(*optsArray)
          MachineLearningWrapper.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
          optsHash = progOpts.to_hash

          Coverage if(optsHash.empty? or optsHash.key?('--help'));
          return optsHash
      end

end
begin
optsHash = MachineLearningWrapper.processArguements()
performQCUsingFindPeaks = MachineLearningWrapper.new(optsHash)
performQCUsingFindPeaks.work()
rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
     performQCUsingFindPeaks.sendFailureEmail(err.message)
     exit(1)
end
