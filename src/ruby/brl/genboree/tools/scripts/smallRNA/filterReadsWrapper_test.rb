#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'uri'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/db/dbrc'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'

include BRL::Genboree::REST


class RemoveAdapters

   def initialize(optsHash)
        @input    = File.expand_path(optsHash['--jsonFile'])
        jsonObj = JSON.parse(File.read(@input))
    
         @input  = jsonObj["inputs"]
         @outputDir = jsonObj["outputs"][0]
         
         if(jsonObj["settings"]["adaptorSequence"]!="")
            @adaptorSequences = jsonObj["settings"]["adaptorSequences"]
         else
            @adaptorSequences = "[AN][TN][CN][TN][CN][GN]"
         end
         
         @maxReadLength = jsonObj["settings"]["maxReadLength"]
         @minReadLength = jsonObj["settings"]["minReadLength"]
         @minReadOccurance = jsonObj["settings"]["minReadOccurance"]
         @minHomoPolymer = jsonObj["settings"]["minHomoPolymer"]
         @scratch = jsonObj["context"]["scratchDir"]
          
         @email = jsonObj["context"]["userEmail"]
         @user_first = jsonObj["context"]["userLastName"]
         @user_last = jsonObj["context"]["userFirstName"]
         @gbConfFile = jsonObj["context"]["gbConfFile"]
         @username = jsonObj["context"]["userLogin"]
         @apiDBRCkey = jsonObj["context"]["apiDbrcKey"]

         # set toolTitle and shortToolTitle
         @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])
         @toolIdStr = jsonObj['context']'toolIdStr']
         @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr, @genbConf)
         @toolTitle = @toolConf.getSetting('ui', 'label')
         @shortToolTitle = @toolConf.getSetting('ui', 'shortLabel')
         @shortToolTitle = @toolTitle if(@shortToolTitle == "[NOT SET]")

         @runName = jsonObj["context"]["runName"]
         
         
         ##Pulling out information about target database,group and password
         grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
         dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
         @host = grph.extractHost(@outputDir)
         @group = grph.extractName(@outputDir)
         @database = dbhelper.extractName(@outputDir)
         @uri =grph.extractPureUri(@outputDir)
         dbrc = BRL::DB::DBRC.new(nil, @apiDBRCkey)
         @pass = dbrc.password
         @user = dbrc.user
             
             
                              
   end
   

  def work
    Dir.chdir(@scratch)
     ## Running filtering on input files
         for i in 0...@input.size
            uri = URI.parse(@input[i])
            hostInput = uri.host
            pathInput = uri.path
            puts hostInput
            puts pathInput
             @baseName= File.basename(@input[i])
             @output = "#{@scratch}/removeAdapter/#{@runName}/#{@baseName}"
             system("mkdir -p #{@output}")
             apicaller = ApiCaller.new(hostInput,"#{pathInput}/data",@user,@pass)
            
            puts "downloading #{@baseName}"
            saveFile = File.open("#{@output}/#{@baseName}","w+")
            httpResp = apicaller.get() {|chunk|
               saveFile.write(chunk)
               }
            saveFile.close
            @input[i] = "#{@output}/#{@baseName}"
         
             
          
         
         ##Running filter script
         
         command = "prepareSmallRNA.fastq_wb.rb -r #{@input[i]} -o #{@output} -u T -a #{@adaptorSequences} -M #{@maxReadLength} -m #{@minReadLength} -R #{@minReadOccurance} -H #{@minHomoPolymer} -a #{@adaptorSequences} > #{@output}/log.prepareSmallRNAfastq 2>&1"    
         system(command)
         system("grep -v '[+|h]' #{@output}/#{@baseName}.output.tags |sed 's/@/>/' > #{@output}/#{@baseName}_WithoutAdaptors.fa")
         system("grep @ #{@output}/#{@baseName}.output.tags | cut -d'_' -f3 |rubySumInput.rb > #{@output}/#{@baseName}_UsableReads.txt")
         command2 = "for f in #{@output}/#{@baseName}_WithoutAdaptors.fa; do echo $f; convertFastaQualToFastQ.rb -f $f -i 40 -o $f.fastq; done"
         system(command2)
         system("gzip #{@output}/#{@baseName}_WithoutAdaptors.fa.fastq")
         ## Calculating usable reads
         filereader = File.open("#{@output}/#{@baseName}_UsableReads.txt")
         filereader.each{|line|
            column = line.split(/sum=/)
            @usableReads = column[1]
            }
      
         ## uploading of output files in specified location (from json file)
         apicaller =ApiCaller.new(@host,"",@username,@pass)
         restPath = "/REST/v1/grp/#{@group}/db/#{@database}/file"
         path = restPath +"/FilteredReads/#{@runName}/#{@baseName}/#{@baseName}_WithoutAdaptors.fa.fastq.gz/data"
         apicaller.setRsrcPath(path)
         infile = File.open("#{@output}/#{@baseName}_WithoutAdaptors.fa.fastq.gz","r")
         apicaller.put(infile)
         puts path
      
         if apicaller.succeeded?
            puts "success"
         else
            apicaller.parseRespBody()
            $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
         end
         
         uploadedPath = restPath+"/FilteredReads/#{@runName}/#{@baseName}/#{@baseName}_WithoutAdaptors.fa.fastq.gz"
         @apiRSCRpath = CGI.escape(uploadedPath)
         
         
         body =
"
Hello #{@user_first} #{@user_last}

Your small RNA read filtering tool run is completed successfully.

Job Summary:
   JobID : #{@jobID}
   Analysis Name : #{@runName}
   Input File : #{@baseName}
   
Result File Location in the Genboree Workbench:
(Direct links to files are at the end of this email)
   Group : #{@group}
   DataBase : #{@database}
   Path to File:
      Files
      * FilteredReads
       * #{@runName}
        * #{@baseName}
         * #{@baseName}_WithoutAdaptors.fa.fastq.gz

The Genboree Team

Result File URLs (click or paste in browser to access file):
    FILE: #{@baseName}_WithoutAdaptors.fa.gz
    URL: 
http://genboree.org/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpath}/data "


      subject = "Genboree: Your #{@toolTitle} analysis job of filtering reads is complete "
    
    
    
         if (!@email.nil?) then
            sendEmail(subject,body)
         end
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
