#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/user'

include GSL
include BRL::Genboree::REST


class MachineLearningWrapper

   def initialize(optsHash)
      @input    = File.expand_path(optsHash['--jsonFile'])
      jsonObj = JSON.parse(File.read(@input))
      @input  = jsonObj["inputs"]
      @outputArray = jsonObj["outputs"]
      @output = jsonObj["outputs"][0]

       ##shuffling of outputdirectory to put 1st as db and 2nd one as prj
      @tempOutputArray = []
      if(@outputArray.size == 2)
         if(@outputArray[0] !~ (BRL::Genboree::REST::Helpers::DatabaseApiUriHelper::NAME_EXTRACTOR_REGEXP))
                  @tempOutputArray[0] = @outputArray[1]
                  @tempOutputArray[1] = @outputArray[0]
                  @outputArray = @tempOutputArray
                  @output = @outputArray[0]
         end
      end

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
      saveFileM = File.open("#{@outputDir}/otu_table/mapping.txt","w+")
      for i in 0...@input.size
         @input[i] = @input[i].chomp('?')
        saveFile = File.open("#{@outputDir}/otu_table/otu_table.txt","w+")
        puts "downloading otu tables from #{File.basename(@input[i])}"
        @db  = @dbhelper.extractName(@input[i])
        @grp = @grph.extractName(@input[i])
        @trk  = @trackhelper.extractName(@input[i])
        uri = URI.parse(@input[i])
        host = uri.host
        path = uri.path
        path = path.chomp('?')
        apicaller =ApiCaller.new(host,"",@hostAuthMap)
        path = path.gsub(/\/files\//,'/file/')
        pathR = "#{path}/otu.table/data?"
        pathR << "gbKey=#{@dbhelper.extractGbKey(@input[i])}" if(@dbhelper.extractGbKey(@input[i]))
        apicaller.setRsrcPath(pathR)
        @buff = ''
        httpResp = apicaller.get(){|chunck|
               saveFile.write chunck
         }
        saveFile.close
        #downloading metadata file
        pathR = "#{path}/mapping.txt/data?"
        apicaller.setRsrcPath(pathR)
        track = 0
       @buff = ''
         httpResp = apicaller.get(){|chunck|
            saveFileM.write chunck
         }
      end
      saveFileM.close

      fileCorrection = File.open("#{@outputDir}/otu_table/tmp.mapping.txt","w+")
      fileCorrectionO = File.open("#{@outputDir}/otu_table/mapping.txt","r")
      track = 0
      fileCorrectionO.each_line { |line|
         next if(line.empty?)
         if(line =~ /^#SampleID/ and track == 0)
            fileCorrection.puts line
            track += 1
         elsif(line !~ /^#SampleID/)
            fileCorrection.puts line
            track += 1
         end
         }
      fileCorrectionO.close
      fileCorrection.close
      system(" mv #{@outputDir}/otu_table/tmp.mapping.txt #{@outputDir}/otu_table/mapping.txt ")

      if(track < 3)
        raise " Needs at least 3 samples for classification"
      end


      ##Calling qiime pipeline
      sucess =true
      cmd = "module load R/2.11.1 ;run_MachineLearning_ARG.rb -f #{@outputDir}/otu_table -o #{@outputDir} -m '#{@featurs}'>#{@outputDir}/ml.log 2>#{@outputDir}/ml.error.log"
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

       if(@outputArray.size==2)
         projectPlot()
         if(!$?.success?)
            sucess = false
            @exitCode = $?.exitstatus
            raise "project plot failed"
         end
      end

       if(sucess == true)
         sendSEmail()
         $stdout.puts "sent"
         Dir.chdir("#{@outputDir}")
       #   system("find . ! -name '*.log' | xargs rm -rf")
          Dir.chdir(@scratch)
       end

   end

    ##tar of output directory
   def compression
     Dir.chdir("#{@outputDir}")
     system("tar czf raw.result.tar.gz * --exclude=*.log")
     system("tar czf 5.result.tar.gz `find . -name '*5_[sortedImportance|bag]*.txt'`")
     system("tar czf 25.result.tar.gz `find . -name '*25_[sortedImportance|bag]*.txt'`")
     system("tar czf 100.result.tar.gz `find . -name '*100_[sortedImportance|bag]*.txt'`")
     system("tar czf 500.result.tar.gz `find . -name '*500_[sortedImportance|bag]*.txt'`")
     Dir.chdir(@scratch)

   end

   ##Calling script to create html pages of plot in project area
   def projectPlot
      jsonLocation  = CGI.escape("#{@scratch}/jobFile.json")
      htmlLocation = CGI.escape("#{@outputDir}")
      cmd = "importMLFiles.rb -j #{jsonLocation} -i #{htmlLocation} >#{@outputDir}/project_plot.log 2>#{@outputDir}/project_plot.error.log"
      $stdout.puts cmd
      system(cmd)

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

             path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/MachineLearning/#{@jobName1}/otu_abundance_cutoff_100.result.tar.gz/data"
            apicaller.setRsrcPath(path)
            infile = File.open("#{@outputDir}/100.result.tar.gz","r")
            apicaller.put(infile)
             if apicaller.succeeded?
               $stdout.puts "successfully uploaded 100.result.tar.gz "
             else
               $stderr.puts apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
              raise "#{apicaller.apiStatusObj['msg']}"
             end

             path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/MachineLearning/#{@jobName1}/otu_abundance_cutoff_500.result.tar.gz/data"
            apicaller.setRsrcPath(path)
            infile = File.open("#{@outputDir}/500.result.tar.gz","r")
            apicaller.put(infile)
             if apicaller.succeeded?
               $stdout.puts "successfully uploaded 500.result.tar.gz "
             else
               $stderr.puts apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
              raise "#{apicaller.apiStatusObj['msg']}"
             end

             path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/MachineLearning/#{@jobName1}/RF_Summary.xls/data"
            apicaller.setRsrcPath(path)
            infile = File.open("#{@outputDir}/RF_Boruta/RF_summary.xls","r")
            apicaller.put(infile)
             if apicaller.succeeded?
               $stdout.puts "successfully uploaded RF_summary.xls "
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

            ##uploading gini_trends_3sorted.xls file
           # xlsFile = File.expand_path(%x{find . -name 'gini_trends_3sorted.xls' -print})
           # xlsFile.chomp!
           # path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/MachineLearning/#{@jobName1}/gini_trends_3sorted.xls/data"
           #apicaller.setRsrcPath(path)
           #infile = File.open("#{xlsFile}","r")
           #apicaller.put(infile)
           # if apicaller.succeeded?
            #   $stdout.puts "successfully uploaded gini_trends_3sorted.xls file "
           # else
            #   $stderr.puts apicaller.parseRespBody()
            #   $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
            #   @exitCode = apicaller.apiStatusObj['statusCode']
            # raise "#{apicaller.apiStatusObj['msg']}"
           # end

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

   def initToolTitles()
     @toolTitle = @toolConf.getSetting('ui', 'label')
     @shortToolTitle = @toolConf.getSetting('ui', 'shortLabel')
     @shortToolTitle = @toolTitle if(@shortToolTitle !~ /\S/ or @shortToolTitle =~ /\[NOT SET\]/i)
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
          "


        if(@outputArray.size ==2)
           @outputArray[1] = @outputArray[1].chomp('?')
           prj =  @outputArray[1].split(/\/prj\//)

           body <<"

Plots URL (click or paste in browser to access file):
    Prj: #{prj[1]}
    URL:
http://#{@hostOutput}/java-bin/project.jsp?projectName=#{prj[1]}



The Genboree Team"

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

Your #{@toolTitle} job was unsuccessfull.

Job Summary:
  JobID                    : #{@jobID}
  Study Name               : #{CGI.unescape(@studyName)}
   Job Name                : #{CGI.unescape(@jobName)}

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
