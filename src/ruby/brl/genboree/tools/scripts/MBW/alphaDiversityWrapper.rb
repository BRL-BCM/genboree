#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/user'

include GSL
include BRL::Genboree::REST


class AlphaDiversityWrapper

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
      @removeSingletons = jsonObj["settings"]["removeSingletons"]
      if(@removeSingletons == true)
         @removeSingletons = 1
      else
         @removeSingletons = 0
      end

      @renyiOffset = jsonObj["settings"]["renyiOffset"]
      @pngDensity = jsonObj["settings"]["pngDensity"]
      @legendPosition = jsonObj["settings"]["legendPosition"]
      @permutations = jsonObj["settings"]["permutations"]
      @renyiScale = jsonObj["settings"]["renyiScale"]
      @renyiScale = @renyiScale.split(',')
      @renyi = ""
      for i in 0...@renyiScale.size
        @renyi << "#{@renyiScale[i]},"
      end
      @renyi = @renyi.chomp(",")

      @richnessOffset2 = jsonObj["settings"]["richnessOffset2"]
      @rainbow = jsonObj["settings"]["rainbow"]
      @meta = jsonObj["settings"]["meta"]
      @richnessOffset = jsonObj["settings"]["richnessOffset"]
      @legendBoolChar = jsonObj["settings"]["legendBoolChar"]
      @height = jsonObj["settings"]["height"]
      @colors= jsonObj["settings"]["colors"]
      @colors = @colors.split(',')
      @color = ""
      for i in 0...@colors.size

        @color << "#{@colors[i]},"
      end
      @color = @color.chomp(",")
      @width = jsonObj["settings"]["width"]
      @legendMarkerSizeMod = jsonObj["settings"]["legendMarkerSizeMod"]

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


      ##Calling qiime pipeline
      cmd = " module load R/2.11.1; run_alpha_diversity_pipeline_ARG.rb -f #{@outputDir}/otu_table -o #{@outputDir} -m '#{@featurs}' -c '#{@color}' -r '#{@renyi}' -p #{@permutations}"
      cmd <<" -n #{@legendPosition} -b #{@legendBoolChar} -k #{@legendMarkerSizeMod} -y #{@renyiOffset} -l #{@richnessOffset} -g #{@richnessOffset2} -h #{@height} "
      cmd <<" -w #{@width} -i #{@rainbow}  -j #{@pngDensity} -s #{@removeSingletons} >#{@outputDir}/alpha.log 2>#{@outputDir}/alpha.error.log"

      $stdout.puts cmd
      sucess = true
      system(cmd)
       if(!$?.success?)
         sucess =false
            @exitCode = $?.exitstatus
            raise " alpha diversity script didn't run properly"
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
         system("find . ! -name '*.log' | xargs rm -rf")
         Dir.chdir(@scratch)
       end

   end

    ##tar of output directory
   def compression


     Dir.chdir("#{@outputDir}/alphadiversity")
     system("tar czf raw.result.tar.gz * --exclude=*.PNG")
     system("tar czf richnessPlots.result.tar.gz `find 'richnessPlots' -name '*.PNG'`")
     system("tar czf rankAbundancePlots.result.tar.gz `find 'rankAbundancePlots' -name '*.PNG'`")
     system("tar czf renyiProfilePlots.result.tar.gz `find 'renyiProfilePlots' -name '*.PNG'`")
     Dir.chdir(@scratch)

   end

    ##Calling script to create html pages of plot in project area
   def projectPlot
      jsonLocation  = CGI.escape("#{@scratch}/jobFile.json")
      htmlLocation = CGI.escape("#{@outputDir}")
      cmd = "importAlphaDiversityFiles.rb -j #{jsonLocation} -i #{htmlLocation} >#{@outputDir}/project_plot.log 2>#{@outputDir}/project_plot.error.log"
      $stdout.puts cmd
      system(cmd)

   end

     ##uploading files on specified location
   def upload
     begin
          apicaller =ApiCaller.new(@hostOutput,"",@hostAuthMap)
          restPath = @pathOutput

           ##uplaoding otu table
            path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/AlphaDiversity/#{@jobName1}/raw.result.tar.gz/data"
            path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
            apicaller.setRsrcPath(path)
            infile = File.open("#{@outputDir}/alphadiversity/raw.result.tar.gz","r")
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
            path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/AlphaDiversity/#{@jobName1}/richnessPlots.result.tar.gz/data"
            apicaller.setRsrcPath(path)
            infile = File.open("#{@outputDir}/alphadiversity/richnessPlots.result.tar.gz","r")
            apicaller.put(infile)
             if apicaller.succeeded?
               $stdout.puts "successfully uploaded richnessPlots.result.tar.gz"
             else
               $stderr.puts apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
              raise "#{apicaller.apiStatusObj['msg']}"
             end


              path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/AlphaDiversity/#{@jobName1}/rankAbundancePlots.result.tar.gz/data"
            apicaller.setRsrcPath(path)
            infile = File.open("#{@outputDir}/alphadiversity/rankAbundancePlots.result.tar.gz","r")
            apicaller.put(infile)
             if apicaller.succeeded?
               $stdout.puts "successfully uploaded rankAbundancePlots.result.tar.gz "
             else
               $stderr.puts apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
              raise "#{apicaller.apiStatusObj['msg']}"
             end

             path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/AlphaDiversity/#{@jobName1}/renyiProfilePlots.result.tar.gz/data"
            apicaller.setRsrcPath(path)
            infile = File.open("#{@outputDir}/alphadiversity/renyiProfilePlots.result.tar.gz","r")
            apicaller.put(infile)
             if apicaller.succeeded?
               $stdout.puts "successfully uploaded renyiProfilePlots.result.tar.gz "
             else
               $stderr.puts apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
              raise "#{apicaller.apiStatusObj['msg']}"
             end

             #uploading metadata file back
           path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/AlphaDiversity/#{@jobName1}/sample.mapping.txt/data"
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
           path = restPath +"/file/MicrobiomeWorkBench/#{@studyName1}/AlphaDiversity/#{@jobName1}/settings.json/data"
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

Your #{toolTitle} job completed successfully.

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
            *AlphaDiversity
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


           "
        end


 body <<"

The Genboree Team"

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
         path = restPath + "/file/MicrobiomeWorkBench/#{@studyName1}/AlphaDiversity/#{@jobName1}/jobFile.json"
         path << "?gbKey=#{@dbhelper.extractGbKey(@output)}"
         apicaller.setRsrcPath(path)
         apicaller.delete()
         $stdout.puts apicaller.parseRespBody()

   end

   def initToolTitles()
      # Set the toolTitle and the toolShortTitle
      tmp = GenboreeRESTRackup.new()
      tmp = nil
      constHash = GenboreeRESTRackup.toolMap[@toolIdStr]
      @toolTitle = @toolConf.getSetting('ui', 'label')
      @shortToolTitle = @toolConf.getSetting('ui', 'shortLabel')
      @shortToolTitle = @toolTitle if(@shortToolTitle !~ /\S/ or @shortToolTitle =~ /\[NOT SET\]/i)
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


   def AlphaDiversityWrapper.usage(msg='')
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
        end #pwd

      # Process Arguements form the command line input
      def AlphaDiversityWrapper.processArguements()
        # We want to add all the prop_keys as potential command line options
          optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                        ['--help'      ,'-h',GetoptLong::NO_ARGUMENT]
                      ]
          progOpts = GetoptLong.new(*optsArray)
          AlphaDiversityWrapper.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
          optsHash = progOpts.to_hash

          Coverage if(optsHash.empty? or optsHash.key?('--help'));
          return optsHash
      end

end
begin
optsHash = AlphaDiversityWrapper.processArguements()
performQCUsingFindPeaks = AlphaDiversityWrapper.new(optsHash)
performQCUsingFindPeaks.work()
 rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
     performQCUsingFindPeaks.sendFailureEmail(err.message)
end
#performQCUsingFindPeaks.compression()
#performQCUsingFindPeaks.upload()
