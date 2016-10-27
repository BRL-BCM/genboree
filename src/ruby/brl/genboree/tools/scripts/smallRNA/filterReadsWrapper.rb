#!/usr/bin/env ruby

## Its a wrapper to run prepareSmallRNA.fastq_wb.rb
require 'json'
require 'fileutils'
require 'cgi'
require 'uri'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/db/dbrc'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'

include BRL::Genboree::REST


class RemoveAdapters

  def initialize(optsHash)
    @input    = File.expand_path(optsHash['--jsonFile'])
    jsonObj = JSON.parse(File.read(@input))

    @input  = jsonObj["inputs"]
    @outputDir = jsonObj["outputs"][0]

    @adaptorSequences = jsonObj["settings"]["adaptorSequences"]
    if(@adaptorSequences=='%')
       @adaptorSequences = ""
    end
    @maxReadLength = jsonObj["settings"]["maxReadLength"].to_i
    @minReadLength = jsonObj["settings"]["minReadLength"].to_i
    @minReadOccurance = jsonObj["settings"]["minReadOccurance"].to_i
    @maxHomoPolymer = jsonObj["settings"]["maxHomoPolymer"].to_i
    @trimHomoPolymer = jsonObj["settings"]["trimHomoPolymer"]
    @runName = jsonObj["settings"]["analysisName"]
    @runName = CGI.escape(@runName)
    @trimHomoPolymer = jsonObj["settings"]["trimHomoPolymer"]

    @scratch = jsonObj["context"]["scratchDir"]
    @email = jsonObj["context"]["userEmail"]
    @user_first = jsonObj["context"]["userFirstName"]
    @user_last = jsonObj["context"]["userLastName"]
    @gbConfFile = jsonObj["context"]["gbConfFile"]
    @username = jsonObj["context"]["userLogin"]
    @apiDBRCkey = jsonObj["context"]["apiDbrcKey"]

    # set toolTitle and shortToolTitle
    @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])
    @toolIdStr = jsonObj['context']['toolIdStr']
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr, @genbConf)
    @toolTitle = @toolConf.getSetting('ui', 'label')
    @shortToolTitle = @toolConf.getSetting('ui', 'shortLabel')
    @shortToolTitle = @toolTitle if(@shortToolTitle == "[NOT SET]")

    @jobID = jsonObj["context"]["jobId"]
    @userId = jsonObj['context']['userId']

    ## Storing information to send to user through email
    if(@maxReadLength == 6000000000)
       @maxReadLengthforMail = "Any Length"
    else
       @maxReadLengthforMail = @maxReadLength
    end

    if(@trimHomoPolymer == false)
       @maxHomoPolymerforMail = "Not Selected"
    elsif(@maxHomoPolymer == 6000000000)
       @maxHomoPolymerforMail = "Any Length"
    else
       @maxHomoPolymerforMail = @maxHomoPolymer
    end

    if(@adaptorSequences=="")
       @adaptorSequencesforMail = "Not Provided"
    else
       @adaptorSequencesforMail = @adaptorSequences
    end

    ##Pulling out information about output database,group and password
    grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @dbOutput = @dbhelper.extractName(@outputDir)
    @grpOutput = grph.extractName(@outputDir)

    @outputDir = @outputDir.chomp('?')
    uriOutput = URI.parse(@outputDir)
    @hostOutput = uriOutput.host
    @pathOutput = uriOutput.path

    @uri =grph.extractPureUri(@outputDir)
    dbrc = BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass = dbrc.password
    @user = dbrc.user
    @exitCode= ""
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




  def work
    Dir.chdir(@scratch)
     ## Running filtering on input files
         for i in 0...@input.size
            @returnErrorMessage = 0
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
               @output = "#{@scratch}/removeAdapter/#{@runName}/#{@baseName}"
               system("mkdir -p #{@output}")
               rsrcPath = "#{pathInput}/data"
               rsrcPath << "?gbKey=#{@dbhelper.extractGbKey(@input[i])}" if(@dbhelper.extractGbKey(@input[i]))
               apicaller = WrapperApiCaller.new(hostInput,rsrcPath,@userId)

               $stdout.puts "downloading #{@baseName}"
               saveFile = File.open("#{@output}/#{@baseName}","w+")
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

               @input[i] = "#{@output}/#{@baseName}"


               ##Uncompressing bzip2 files
               if(bz==1)
                  system("bunzip2 #{@output}/#{@baseName}")
                  $stderr.puts $?.exitstatus
                  system("mv #{@output}/#{@baseName}.out #{@output}/#{@baseName}")
                   $stderr.puts $?.exitstatus
                  @input[i] = "#{@output}/#{@baseName}"
               end
               @inputEscaped = CGI.escape(@input[i])
               @outputEscaped = CGI.escape(@output)


               ##Checking for fastq format of input file
               if(!isFastQ(@input[i]))
                  @exitCode = $?.exitstatus
                  raise  "Input has wrong format. Please check the format of input file"
               end


            ##Running filter script
            command = "prepareSmallRNA.fastq_wb.rb -r #{@inputEscaped} -o #{@outputEscaped} -u Y -a #{@adaptorSequences} -M #{@maxReadLength} -m #{@minReadLength} -R #{@minReadOccurance} -H #{@maxHomoPolymer} -a #{@adaptorSequences} > #{@output}/log.prepareSmallRNAfastq_#{@baseName}2>&1"
            system(command)
            if(!$?.success?)
               @exitCode = $?.exitstatus
               raise "prepareSmallRNA.fastq_wb.rb didn't run."
            end
            system("grep -v '[+|h]' #{@output}/#{@baseName}.output.tags |sed 's/@/>/' > #{@output}/#{@baseName}_WithoutAdaptors.fa")
             if(!$?.success?)
               @exitCode = $?.exitstatus
               raise "#{@baseName}.output.tags file is missing."
            end

            command2 = "for f in #{@output}/#{@baseName}_WithoutAdaptors.fa; do echo $f; convertFastaQualToFastQ.rb -f $f -i 40 -o $f.fastq; done"
            system(command2)
            if(!$?.success?)
               @exitCode = $?.exitstatus
               raise "convertFastaQualToFastQ.rb didn't run."
            end
            system("gzip -qf #{@output}/#{@baseName}_WithoutAdaptors.fa.fastq")
            if(!$?.success?)
               @exitCode = $?.exitstatus
               raise "compression of file didn't work."
            end


            ## uploading of output files in specified location (from json file)
            apicaller = WrapperApiCaller.new(@hostOutput,"",@userId)
            restPath = @pathOutput
            path = restPath +"/file/FilteredReads/#{@runName}/#{@baseName}/#{@baseName}_WithoutAdaptors.fa.fastq.gz/data"
            path << "?gbKey=#{@dbhelper.extractGbKey(@outputDir)}" if(@dbhelper.extractGbKey(@outputDir))
            apicaller.setRsrcPath(path)
            infile = File.open("#{@output}/#{@baseName}_WithoutAdaptors.fa.fastq.gz","r")
            apicaller.put(infile)

            if apicaller.succeeded?
               $stdout.puts "successfully uploaded #{@baseName}_WithoutAdaptors.fa.fastq.gz"
            else
               apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
               raise "#{apicaller.apiStatusObj['msg']}"
            end

            uploadedPath = restPath+"/file/FilteredReads/#{@runName}/#{@baseName}/#{@baseName}_WithoutAdaptors.fa.fastq.gz"
            @apiRSCRpath = CGI.escape(uploadedPath)


            body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} analysis job of filtering reads is completed successfully.

Job Summary:
   JobID : #{@jobID}
   Analysis Name : #{@runNameOriginal}
   Input File : #{@baseNameOriginal}
   Adapter : #{@adaptorSequencesforMail}
   Maximum Read Length : #{@maxReadLengthforMail}
   Minimum Read Length : #{@minReadLength}
   Minimum Read Occurence : #{@minReadOccurance}
   Trailing Homopolymer Length : #{@maxHomoPolymerforMail}



Result File Location in the Genboree Workbench:
(Direct links to files are at the end of this email)
   Group : #{@grpOutput}
   DataBase : #{@dbOutput}
   Path to File:
      Files
      * FilteredReads
       * #{@runNameOriginal}
        * #{@baseNameOriginal}
         * #{@baseNameOriginal}_WithoutAdaptors.fa.fastq.gz

The Genboree Team

Result File URLs (click or paste in browser to access file):
    FILE: #{@baseNameOriginal}_WithoutAdaptors.fa.fastq.gz
    URL:
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpath}/data "


      subject = "Genboree: Your #{@toolTitle} analysis job of filtering reads is complete "



            rescue => err
                 $stderr.puts "Details: #{err.message}"
                 $stderr.puts err.backtrace.join("\n")


                 if(@exitCode=="")
                    @exitCode ="NA"
                 end
             body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} analysis job of filtering reads is unsuccessful.

Job Summary:
   JobID         : #{@jobID}
   Analysis Name : #{@runNameOriginal}
   Input File    : #{@baseNameOriginal}

   Error Message : #{err.message}
   Exit Status   : #{@exitCode}

Please contact Genboree team (genboree_admin@genboree.org) with above information.

The Genboree Team

"

      subject = "Genboree: Your #{@toolTitle} analysis job of filtering reads is unsuccessfull "
    end

         if (!@email.nil?) then
            sendEmail(subject,body)
         end
     # system("cp #{@scratch}/removeAdapter/#{@runName}/#{@baseName}/log*  #{@scratch}/removeAdapter/#{@runName}")
     # system("rm #{@scratch}/removeAdapter/#{@runName}/#{@baseName}/*")

      end



  end

  def sendEmail(subjectTxt, bodyTxt)

    puts "=====email Station===="
    #puts @gbAdminEmail
    #puts @userEmail

    email = BRL::Util::Emailer.new()
    email.setHeaders("genboree_admin@genboree.org", @email, subjectTxt)
    email.setMailFrom('genboree_admin@genboree.org')
    email.addRecipient(@email)
    email.addRecipient("genboree_admin@genboree.org")
    email.setBody(bodyTxt)
    email.send()

  end


   def RemoveAdapters.usage(msg='')
          unless(msg.empty?)
            puts "\n#{msg}\n"
          end
          puts "

        PROGRAM DESCRIPTION:
          Wrapper to run preparesmallRNA.fastq.rb. It is a wrapper to filter the fastq file.

        COMMAND LINE ARGUMENTS:
          --file         | -j => Input json file
          --help         | -h => [Optional flag]. Print help info and exit.

       usage:

      ruby removeAdaptarsWrapper.rb -f jsonFile

        ";
            exit;
        end #

      # Process Arguements form the command line input
      def RemoveAdapters.processArguements()
        # We want to add all the prop_keys as potential command line options
          optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                        ['--help'      ,'-h',GetoptLong::NO_ARGUMENT]
                      ]
          progOpts = GetoptLong.new(*optsArray)
          RemoveAdapters.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
          optsHash = progOpts.to_hash

          Coverage if(optsHash.empty? or optsHash.key?('--help'));
          return optsHash
      end

end

optsHash = RemoveAdapters.processArguements()
performQCUsingFindPeaks = RemoveAdapters.new(optsHash)
performQCUsingFindPeaks.work()
