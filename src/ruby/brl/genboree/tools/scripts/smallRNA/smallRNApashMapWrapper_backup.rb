#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/db/dbrc'
require 'brl/util/emailer'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
include BRL::Genboree::REST


class PashMap

   def initialize(optsHash)
        @input    = File.expand_path(optsHash['--jsonFile'])
        jsonObj = JSON.parse(File.read(@input))
   
         @input  = jsonObj["inputs"]
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
         
         @email = jsonObj["context"]["userEmail"]
         @user_first = jsonObj["context"]["userFirstName"]
         @user_last = jsonObj["context"]["userLastName"]
         @gbConfFile = jsonObj["context"]["gbConfFile"]
         @username = jsonObj["context"]["userLogin"]
         @apiDBRCkey = jsonObj["context"]["apiDbrcKey"]
         @jobID = jsonObj["context"]["jobId"]
         @toolTitle = jsonObj["context"]["toolTitle"]
         @scratch = jsonObj["context"]["scratchDir"]
         @gbAdminEmail = jsonObj["context"]["gbAdminEmail"]
         @userId = jsonObj["context"]["userId"]
         
         ## Pulling out information about database,group and password
         grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
         dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
          @outputDir = @output.chomp('?')
         uriOutput = URI.parse(@output)
         @hostOutput = uriOutput.host
         @pathOutput = uriOutput.path
         @dbOutput = dbhelper.extractName(@output)
         @grpOutput = grph.extractName(@output)
         
         dbrc = BRL::DB::DBRC.new(nil, @apiDBRCkey)
         @pass = dbrc.password
         @user = dbrc.user
         
         ##building offest file from the same database
         apicaller =ApiCaller.new("genboree.brl.bcmd.bcm.edu","",@user,@pass)
         restPath = "/REST/v1/grp/{grp}/db/{db}/eps"
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
         @targetGenome = jsonObj["settings"]["targetGenome"]
          @refGenome = "#{@scratch}/#{@genome}.off"
         @lffFile = "#{@scratch}/#{@genome}.lff"
         #downloading bed file from genboree track by track and converting into lff
        
         
   end
   
   
   def pashfile
       @lffClass = " Gene"
         apicaller =ApiCaller.new("genboree.brl.bcmd.bcm.edu","",@user,@pass)
         trackList = jsonObj["settings"]["ROITrack"]
         saveFile = File.open("#{@scratch}/#{@genome}.lff","w+")
         for i in 0...trackList.size
            puts "downloading track #{trackList[i]}"
            @lff = trackList[i].split(":")
            @lffType = @lff[0]
            @lffSubType = @lff[1]
            restPath = "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/annos?format=bed"
            apicaller.setRsrcPath(restPath)
            @buff = ''
            
            ## Using deafult database and group to download lff target file
            httpResp = apicaller.get( {:grp => "small_RNA_pipeline" , :db => "smallRNAanalysis_#{@genome}" ,:trk => trackList[i]} ){|chunck|                  
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
               apicaller =ApiCaller.new(@hosttrack,"",@user,@pass)
               restPath = "#{@pathtrack}/annos?format=bed"
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
   
   
  def work
    
    # Running pash mapping on input files
    t1 = Thread.new{pashfile}
    t1.join
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
          apicaller = ApiCaller.new(hostInput,"#{pathInput}/data",@user,@pass)
            
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
               
           
         system("zgrep '@' #{@input[i]}  | cut -d'_' -f3 |rubySumInput.rb > #{@outputDir}/#{@baseName}_Stats.txt")
          if(!$?.success?)
             @exitCode = $?.exitstatus
            raise "Couldn't create Stats.txt "
          end
         
      
         ## Calculating usableReads   
         filereader = File.open("#{@outputDir}/#{@baseName}_Stats.txt")
         filereader.each{|line|
           column = line.split(/sum=/)
           puts column[1]
           @usableReads = column[1]
           }
         
         ## Calling pash mapping and accountformapping scripts to create mapped files and summary report
          system("zgrep -v '[]*]' #{@outputDir}/#{@baseName} | grep -v  '+' | sed 's/@/>/' >#{@outputDir}/#{@baseName}.fa ")
          if(!$?.success?)
             @exitCode = $?.exitstatus
            raise " Couldn't create #{@outputDir}/#{@baseName}.fa"
          end
          system("pash-3.0lx.exe -v #{@outputDir}/#{@baseName} -h #{@targetGenome} -k #{@kWeight} -n #{@kspan} -S #{@scratch} -s 22 -G #{@gap} -d #{@diagonals} -o #{@outputDir}/#{@baseName}.pash3.0.Map.output.txt -N #{@maxMapping} > #{@outputDir}/log.pash-3.0 2>&1")
          if(!$?.success?)
             @exitCode = $?.exitstatus
             raise " pash mapping failed"
          end
         
         @outputHttp = CGI.escape(@outputDir)
         @baseNameHttp = CGI.escape(@baseName)
         system("accountForMappings.rb -p #{@outputHttp}/#{@baseNameHttp}.pash3.0.Map.output.txt -o #{@outputHttp} -r  #{@outputHttp}/#{@baseNameHttp}.fa -R #{@refGenome} -l #{@lffFile} -u #{@usableReads}")
         if(!$?.success?)
            @exitCode = $?.exitstatus
            raise " accountForMappings.rb didn't work"
         end
         
         @readName = @baseName.split(".")
         @readName = @readName[0]
         system("gzip -qf #{@outputDir}/#{@readName}.trackCoverage.lff")
         if(!$?.success?)
            @exitCode = $?.exitstatus
            raise "compression of the file didn't work"
         end
         
         ## Uploading of output xl sheet in given specified path( from json)
         apicaller =ApiCaller.new(@hostOutput,"",@user,@pass)
         restPath = @pathOutput
         path = restPath +"/file/PashMapped/#{@runName}/#{@baseName}/#{@readName}.xls/data"
         apicaller.setRsrcPath(path)
         infile = File.open("#{@outputDir}/#{@readName}.xls","r")
         apicaller.put(infile)
         if apicaller.succeeded?
            $stdout.puts "success" 
         else
             apicaller.parseRespBody()
            $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
            @exitCode = apicaller.apiStatusObj['statusCode']
            raise "#{apicaller.apiStatusObj['msg']}"
         end
         restPath = @pathOutput
         path = restPath +"/file/PashMapped/#{@runName}/#{@baseName}/#{@readName}.trackCoverage.lff.gz/data"
         apicaller.setRsrcPath(path)
         infile1 = BRL::Util::TextReader.new("#{@outputDir}/#{@readName}.trackCoverage.lff.gz")
         outfile1 = File.open("#{@outputDir}/#{@readName}_temp.trackCoverage.lff","w")
         infile1.each { | line|
            columns = line.split(/\t/)
            columns[3]= columns[3].gsub(/_/," ")
            outfile1.puts "#{@sampleName}\t#{columns[1]}\t#{@sampleName}\t#{columns[3]}\t#{columns[4]}\t#{columns[5]}\t#{columns[6]}\t#{columns[7]}\t#{columns[8]}\t#{columns[9]}"
            }
         infile1.close
         outfile1.close()
         system("mv #{@outputDir}/#{@readName}_temp.trackCoverage.lff #{@outputDir}/#{@readName}.trackCoverage.lff ")
         system("gzip -qf #{@outputDir}/#{@readName}.trackCoverage.lff")
         
         infile1 = File.open("#{@outputDir}/#{@readName}.trackCoverage.lff.gz","r")
         apicaller.put(infile1)
         if apicaller.succeeded?
            $stdout.puts "successfully uploaded lff file" 
         else
            apicaller.parseRespBody()
            $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
            @exitCode = apicaller.apiStatusObj['statusCode']
            raise "#{apicaller.apiStatusObj['msg']}"
         end
         
         ##uploading trackCoverage lff file in genboree
         if(@uploadResults==true)
            restPath = "/REST/v1/grp/#{CGI.escape(@grpOutput)}/db/#{CGI.escape(@dbOutput)}/annos?userId=#{@userId}"
            apicaller.setRsrcPath(restPath)
            inFile = File.open("#{@outputDir}/#{@readName}.trackCoverage.lff.gz")
            apicaller.put(inFile)
            $stdout.puts "#{@outputDir}/#{@readName}.trackCoverage.lff.gz"
            if apicaller.succeeded?
               $stdout.puts "successfully uploaded tracks" 
            else
               $stdout.puts apicaller.parseRespBody()
               
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
               raise "#{apicaller.apiStatusObj['msg']}"
            end
         end
         
         
         restPath = @pathOutput
         path = restPath +"/file/PashMapped/#{@runName}/#{@baseName}/#{@readName}_Stats.txt/data"
         apicaller.setRsrcPath(path)
         infile1 = File.open("#{@outputDir}/#{@baseName}_Stats.txt","r")
         apicaller.put(infile1)
         if apicaller.succeeded?
            $stdout.puts "successfully uploaded stats file" 
         else
            apicaller.parseRespBody()
            $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
            @exitCode = apicaller.apiStatusObj['statusCode']
            raise "#{apicaller.apiStatusObj['msg']}"
         end
         
         
         uploadedPathForxl = restPath+"/file/PashMapped/#{@runName}/#{@baseName}/#{@readName}.xls"
         @apiRSCRpathForxl = CGI.escape(uploadedPathForxl)
         uploadedPathForlff = restPath+"/file/PashMapped/#{@runName}/#{@baseName}/#{@readName}.trackCoverage.lff.gz"
         @apiRSCRpathForlff = CGI.escape(uploadedPathForlff)
         uploadedPathFortxt =restPath+"/file/PashMapped/#{@runName}/#{@baseName}/#{@readName}_Stats.txt"
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
         * #{@baseNameOriginal}.xls
         * #{@baseNameOriginal}.trackCoverage.lff
         * #{@baseNameOriginal}_Stats.txt

"
if (@uploadResults==true)
body << "#{@baseNameOriginal}.trackCoverage.lff has been added to queue for uploading. You will shortly get a mail of its final status."

end
body <<
"
The Genboree Team

Result File URLs (click or paste in browser to access file):
    File: #{@baseNameOriginal}.xls
    URL: 
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpathForxl}/data     

    File: #{@baseNameOriginal}.trackCoverage.lff
    URL:
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpathForlff}/data
       
    File: #{@baseNameOriginal}_Stats.txt
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
