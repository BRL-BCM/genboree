#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/db/dbrc'
require 'spreadsheet'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'

include BRL::Genboree::REST


class RemoveAdapters

   def initialize(optsHash)
        @input    = File.expand_path(optsHash['--jsonFile'])
        jsonObj = JSON.parse(File.read(@input))
    
         @input  = jsonObj["inputs"]
         @output = jsonObj["outputs"][0]
         
          
         @email = jsonObj["context"]["userEmail"]
         @user_first = jsonObj["context"]["userFirstName"]
         @user_last = jsonObj["context"]["userLastName"]
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

         @scratch = jsonObj["context"]["scratchDir"]
         @jobID = jsonObj["context"]["jobId"]
         
         
         @runName = jsonObj["settings"]["analysisName"]
         @runName = CGI.escape(@runName)
         @runNameOriginal = CGI.unescape(@runName)
         @sampleType = []
         @sampleType = jsonObj["settings"]["sampleType"]
         ##Pulling out information about target database,group and password
         grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
         dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
         @dbOutput = dbhelper.extractName(@output)
         @grpOutput = grph.extractName(@output)
         dbrc = BRL::DB::DBRC.new(nil, @apiDBRCkey)
         @pass = dbrc.password
         @user = dbrc.user
         @outputDir = @output.chomp('?')
         uriOutput = URI.parse(@output)
         @hostOutput = uriOutput.host
         @pathOutput = uriOutput.path
         @usableFiles = []              
   end
   
   

  def work
    
     ## Running filtering on input files 
         Dir.chdir(@scratch)
         
         book = Spreadsheet::Workbook.new
         sheet = book.create_worksheet
         track = 0
         @storeErrors = ""
         @validInputFiles =[]
         validEntries = 0
         @validUsable =[]
         @validSampleType = [""]
         ii = 0
         for i in 0...@input.size
            counter = 0
            begin
              @input[i] = @input[i].chomp('?')
              uri = URI.parse(@input[i])
              hostInput = uri.host
              pathInput = uri.path
              @baseName= File.basename(@input[i])
              @output = "#{@scratch}/combinedCoverage/#{@runName}"
              system("mkdir -p #{@output}")
              apicaller = ApiCaller.new(hostInput,"#{pathInput}/data",@user,@pass)
              
              $stdout.puts "downloading #{@baseName}"
              saveFile = File.open("#{@output}/#{@baseName}","w+")
              httpResp = apicaller.get() {|chunk|
                 saveFile.write(chunk)
                 }
              saveFile.close
              
              if apicaller.succeeded?
                $stdout.puts "success"
              else
                apicaller.parseRespBody()
                $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
                @exitCode = apicaller.apiStatusObj['statusCode']
                raise "#{apicaller.apiStatusObj['msg']}"
              end
                     
           
              system("LFFValidator.rb -f #{CGI.escape(@output)}/#{CGI.escape(@baseName)} -t annos -n 1")
              if($?!=0)
                @exitCode = $?.exitstatus
                raise "#{@baseName} has wrong format."
              end
            
             
              if(pathInput =~/(.*)#{@baseName}/)
                @dirOfInputFile = $1
              end
              @readName = @baseName.split(".")
              @readName = @readName[0]
              
              ##Downloading excel file
              apicaller = ApiCaller.new(hostInput,"#{@dirOfInputFile}#{@readName}.xls/data",@user,@pass)
              $stdout.puts "downloading #{@readName}.xls"
              saveFile = File.open("#{@output}/#{@readName}.xls","w+")
              httpResp = apicaller.get() {|chunk|
                 saveFile.write(chunk)
                 }
              saveFile.close
              
              if apicaller.succeeded?
                $stdout.puts "success"
              else
                apicaller.parseRespBody()
                $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
                @exitCode = apicaller.apiStatusObj['statusCode']
                raise "#{apicaller.apiStatusObj['msg']}"
              end
           
             
             ## Making Combined Summary
              bookRead = Spreadsheet.open("#{@output}/#{@readName}.xls")
              sheetRead = bookRead.worksheet(0)
              sheetRead.each { |row|
                a = row.join(',')
                columns = a.split(',')
                if(ii==0)
                  for jj in 0...columns.size
                    sheet.row(counter).insert jj, columns[jj]
                  end
                else
                  for jj in 3...columns.size
                    sheet.row(counter).insert jj+track, columns[jj]
                  end
                end
                counter += 1
               }
              track += 3
              ii += 1
                  
             
              ##Downloading stats file
              apicaller = ApiCaller.new(hostInput,"#{@dirOfInputFile}#{@readName}_Stats.txt/data",@user,@pass)
              $stdout.puts "downloading #{@baseName}_Stats.txt"
              saveFile = File.open("#{@output}/#{@baseName}_Stats.txt","w+")
              httpResp = apicaller.get() {|chunk|
                 saveFile.write(chunk)
                 }
              saveFile.close
              
              if apicaller.succeeded?
                $stdout.puts "success"
              else
                apicaller.parseRespBody()
                $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
                @exitCode = apicaller.apiStatusObj['statusCode']
               raise "#{apicaller.apiStatusObj['msg']}"
             end
           
              
              filereader = File.open("#{@output}/#{@baseName}_Stats.txt")
              filereader.each{|line|
                column = line.split(/sum=/)
                puts column[1]
                @usableReads = column[1]
               }
  
              
          
              @input[i] = "#{@output}/#{@baseName}"
              @input[i] = CGI.escape(@input[i])
              @usableFiles[i] = @usableReads.to_i
              @validInputFiles[validEntries] = @input[i]
              @validUsable[validEntries] = @usableReads.to_i
              
              if(@sampleType[0]!="na")
               @validSampleType[validEntries] = @sampleType[i]
              end
              
              validEntries+=1
              
          
        rescue => err
              $stderr.puts "Details: #{err.message}"
              $stderr.puts err.backtrace.join("\n")
                 
                 
                 if(@exitCode=="")
                    @exitCode ="NA"
                 end
              $stderr.puts @exitCode
              @storeErrors << "#{CGI.unescape(@baseName)}\n"
            end
            
         
         end
         book.write("#{@output}/combinedCoverage.xls")
         
         begin
          @output = "#{@scratch}/combinedCoverage/#{@runName}"
   
          
          ##Running filter script
          system("mkdir -p #{@output}")
          command = "combineMultipleCoverageExperimentsByNameAndChromosomeLocation.rb -f '"
          for i in 0...@validInputFiles.size
         
            if(i!=@validInputFiles.size-1)
             command<<"#{@validInputFiles[i]},"
            else
              command<<"#{@validInputFiles[i]}'"
            end
          end
          
          command <<" -u '"
          for i in 0...@validUsable.size
         
            if(i!=@validUsable.size-1)
             command<<"#{@validUsable[i]},"
            else
              command<<"#{@validUsable[i]}'"
            end
          end
          
        
          if(@sampleType[0] != "na" )
            command <<" -s '"
           for i in 0...@validSampleType.size
         
               if(i!=@validSampleType.size-1)
                  command<<"#{@validSampleType[i]},"
               else
                command<<"#{@validSampleType[i]}'"
               end
            end
          end
          
          command <<" -o #{CGI.escape(@output)}> #{@output}/log.combinedCoverage "
          
          $stdout.puts command
          
          system(command)
          if(!$?.success?)
             @exitCode = $?.exitstatus
             raise " combineMultipleCoverageExperimentsByNameAndChromosomeLocation.rb didn't work"
          end
          
          ## uploading of output files in specified location (from json file)
          apicaller =ApiCaller.new(@hostOutput,"",@user,@pass)
          restPath = @pathOutput
          path = restPath +"/file/combinedCoverage/#{@runName}/RNA_miRNA.xls/data"
          apicaller.setRsrcPath(path)
          if(File.exists?("#{@output}/RNA_miRNA.xls"))
             infile = File.open("#{@output}/RNA_miRNA.xls","r")
          else
            infile = File.open("#{@output}/RNA miRNA.xls","r")
          end
          
          apicaller.put(infile)
          
       
          if apicaller.succeeded?
             $stdout.puts "success"
          else
             apicaller.parseRespBody()
             $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
             @exitCode = apicaller.apiStatusObj['statusCode']
             raise "#{apicaller.apiStatusObj['msg']}"
          end
          
          uploadedPath = restPath+"/file/combinedCoverage/#{@runName}/RNA_miRNA.xls"
          @apiRSCRpath = CGI.escape(uploadedPath)
          
          ##uploading combined coverage excel sheet
          restPath = @pathOutput
          path = restPath +"/file/combinedCoverage/#{@runName}/combinedCoverage.xls/data"
          apicaller.setRsrcPath(path)
          infile = File.open("#{@output}/combinedCoverage.xls","r")
          apicaller.put(infile)
          
       
          if apicaller.succeeded?
             $stdout.puts "success"
          else
             apicaller.parseRespBody()
             $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
             @exitCode = apicaller.apiStatusObj['statusCode']
             raise "#{apicaller.apiStatusObj['msg']}"
          end
          
          uploadedPathCombined = restPath+"/file/combinedCoverage/#{@runName}/combinedCoverage.xls"
          @apiRSCRpathCombined = CGI.escape(uploadedPathCombined)
          
          
      
     
         body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your small RNA combining coverage tool run is completed successfully.

Job Summary:
   JobID : #{@jobID}
   Analysis Name : #{@runNameOriginal}
   Input File :\n"
         for i in 0...@input.size
            body << "         #{File.basename(CGI.unescape(CGI.unescape(@input[i])))}\n"
         end
         
body << "Result File Location in the Genboree Workbench:
(Direct links to files are at the end of this email)
   Group : #{@grpOutput}
   DataBase : #{@dbOutput}
   Path to File:
      Files
      * combinedCoverage
       * RNA_miRNA.xls
       * combinedCoverage.xls
       
The Genboree Team

Result File URLs (click or paste in browser to access file):
    File: RNA_miRNA.xls
    URL: 
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpath}/data 

    File: combinedCoverage.xls
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpathCombined}/data "
  
  if (@storeErrors!="")
    body <<"
    
Following file(s) couldnt be processed due to bad format:
#{@storeErrors}"
  end
  

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

Your #{@toolTitle} analysis job mapping reads is unsuccessfull .

Job Summary:
   JobID         : #{@jobID}
   Analysis Name : #{@runNameOriginal}
   
   Error Message : #{err.message}
   Exit Status   : #{@exitCode}
Please Contact Genboree team with above information.

The Genboree Team

"
 
      subject = "Genboree: Your #{@toolTitle} analysis job of mapping reads is unsuccessfull "
    end
         
    
    
         if (!@email.nil?) then
            sendEmail(subject,body)
         end
         
         system("rm #{@scratch}/combinedCoverage/#{@runName}/*.lff*")
  
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
