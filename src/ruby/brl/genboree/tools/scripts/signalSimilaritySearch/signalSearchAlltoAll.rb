#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller'
require 'brl/normalize/index_sort'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/toolConf'
include GSL
include BRL::Genboree::REST


class SignalSimilaritySearchAlltoAll

   def initialize(optsHash)
      @input    = File.expand_path(optsHash['--jsonFile'])
      jsonObj = JSON.parse(File.read(@input))
      @input  = jsonObj["inputs"]
      @output = jsonObj["outputs"][0]

      @toolIdStr = jsonObj['context']['toolIdStr']
      @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])
      @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr, @genbConf)
      @toolTitle = @toolConf.getSetting('ui', 'label')
     
      @gbConfFile = jsonObj["context"]["gbConfFile"]
      @apiDBRCkey = jsonObj["context"]["apiDbrcKey"]
      @scratch = jsonObj["context"]["scratchDir"]
      @email = jsonObj["context"]["userEmail"]
      @user_first = jsonObj["context"]["userFirstName"]
      @user_last = jsonObj["context"]["userLastName"]
      @username = jsonObj["context"]["userLogin"]
      @gbAdminEmail = jsonObj["context"]["gbAdminEmail"]
      @jobID = jsonObj["context"]["jobId"]
      @userId = jsonObj["context"]["userId"]
      
      @spanAggFunction = jsonObj["settings"]["spanAggFunction"]
      @removeNoDataRegions = jsonObj["settings"]["removeNoDataRegions"]
      @ranknNormalized = jsonObj["settings"]["rankNormalized"]
      @quantileNormalized = jsonObj["settings"]["quantileNormalized"]   
      @runName = jsonObj["settings"]["analysisName"]
      @ROItrack = jsonObj["settings"]["useGenboreeRoiScores"]
      @res = jsonObj["settings"]["resolution"]
      case jsonObj["settings"]["resolution"]
			when "high"
				@resolution = 1000
			when "medium"
				@resolution = 10000
			when "low"
				@resolution = 100000
			else
				@resolution = 10000
		end
      
      @runNameOriginal = @runName
      @runName = CGI.escape(@runName)
      
      @grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
      @dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
      @trackhelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)
      
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
      
   end
   
   ##Main to call either wigdownload or withROI
   def work
    
      @outputDir = "#{@scratch}/signal-search/#{@runName}"
      system("mkdir -p #{@outputDir}")
      if(@ROItrack == false)
         wigDownload
      else
         @input[@input.size-1] = @input[@input.size-1].chomp('?')
         @dbROI    = @dbhelper.extractName(@input[@input.size-1])
         @grpROI   = @grph.extractName(@input[@input.size-1])
         @trkROI   = @tkOutput = @trackhelper.extractName(@input[@input.size-1])
         withROI
      end
       ii = 0
       jj = 0
       
      for ii in 0 ...@input.size
         command = "ruby /cluster.shared/local/apps/signalSimilaritySearch/signalSimilaritySearch_All2All.rb -f '"
  
         for i in ii...@input.size
            if((i == @input.size-1  and ii ==0 ))
              command <<"#{File.basename(@input[i].chomp('?'))}' "
            else
              command <<"#{File.basename(@input[i].chomp('?'))},"
            end
         end
          if(ii!=0)
            for jj in 0...ii
              if(jj == ii-1)
                command <<"#{File.basename(@input[jj].chomp('?'))}'"
              else
                command <<"#{File.basename(@input[jj].chomp('?'))},"
              end
            end
          end
          
         
         
         
         if(@ROItrack == true)
           format = "Lff"
         else
           format = "Wig"
         end
         command << " -o #{File.basename(@input[ii].chomp('?'))}   -a #{@runName} -s #{@scratch} -F #{format} -c #{@removeNoDataRegions} -r #{@resolution} -q #{@quantileNormalized}"
  
          scriptName="submitAccountForMappings#{File.basename(@input[ii])}_job.pbs"	
          scriptFile = File.open("#{scriptName}", "w")
          scriptFile.puts "#!/bin/bash";
          scriptFile.puts "#PBS -q general";
          scriptFile.puts "#PBS -l nodes=1:ppn=1\n";
          scriptFile.puts "#PBS -l walltime=24:00:00\n";
          scriptFile.puts "#PBS -l cput=48:00:00\n";
          scriptFile.puts "mkdir -p #{@scratch}"
          scriptFile.puts "cd #{@scratch}"
          scriptFile.puts "mkdir -p #{@outputDir}"
          #scriptFile.puts "#PBS -l ppn=1\n";
          scriptFile.puts "#PBS -M #{ENV["USER"]}\@bcm.tmc.edu\n";
          scriptFile.puts "#PBS -m ea\n";
          scriptFile.puts "#PBS -N se7.rb\n"
          scriptFile.puts "cd $PBS_O_WORKDIR\n\n"
          scriptFile.print "#{command}\n"
          scriptFile.puts "sleep 2"
          scriptFile.close()
        
        # Submitting script on cluster
        
        command="qsub #{scriptName}"
        puts command
     # system(command)
               
           
           
            end
   end
   
   
   ## When there is no ROI track, download the score track in wig format
  def wigDownload
     #resolution = 1000
     for i in 0...@input.size
            @input[i] = @input[i].chomp('?')
            puts "downloading wig file #{@input[i]}"
            
            @db  = @dbhelper.extractName(@input[i])
            @grp = @grph.extractName(@input[i])
            @trk  = @trackhelper.extractName(@input[i])
            uri = URI.parse(@input[i])
            host = uri.host
            
            
            apicaller =ApiCaller.new(host,"",@user,@pass)
            path = "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/annos?format=vwig&span={resolution}&spanAggFunction={span}&emptyScoreValue={esValue}"
         
            apicaller.setRsrcPath(path)
            @buff = ''
            saveFile = File.open("#{@outputDir}/#{File.basename(@input[i])}","w+")
            saveFile2 = File.open("#{@outputDir}/#{File.basename(@input[i])}.wig","w+")
            @startPoint = 0
            @endPoint = 0
            @chr = ""
            ##Downloading wig files 
            httpResp = apicaller.get(
                                       {
                                           :grp      => @grp,
                                           :db       => @db,
                                           :trk      => @trk,
                                           :span     => "avg",
                                           :resolution => @resolution,
                                           :esValue  => "4290772992"
                                       }
                                    ){|chunck|
            fullChunk = "#{@buff}#{chunck}"           
            @buff = ''
           
            fullChunk.each_line { |line|
               if(line[-1].ord == 10)
                  saveFile2.write line
                  if(line =~ /variable/)
                     
                      @chr  =line.split(/chrom=/)[1].split(/span/)[0].strip!
                      
                  end
                 
                  unless(line=~/track/ or line =~/variable/)
                     columns = line.split(/\s/)
                     score = columns[1]
                     @endPoint = columns[0].to_i + @resolution
                       
                       saveFile.write("#{@lffClass}\t#{File.basename(@input[i])}\t#{@lffType}\t#{@lffSubType}\t#{@chr}\t#{@startPoint}\t#{@endPoint}\t+\t0\t#{score}\n")
                     @startPoint = @endPoint
                  end
                  
               else
                  @buff += line
               end
               }
            }
             saveFile.close
             saveFile2.close
            if apicaller.succeeded?
               $stdout.puts "successfully downloaded #{i+1} wig file" 
            else
               $stderr.puts apicaller.parseRespBody().inspect
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
               raise "#{apicaller.apiStatusObj['msg']}"
            end
        end     
  end
  

   ##When there is a ROI track, downloading first score track as lff format and other one in bedgraph
  def withROI
   
        for i in 0...@input.size-1
            puts "downloading score file #{@input[i]}"
            @input[i] = @input[i].chomp('?')
            uri = URI.parse(@input[i])
            host = uri.host
            apicaller =ApiCaller.new(host,"",@user,@pass)
      
            path = "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/annos?format={format}&scoreTrack={scrTrack}&spanAggFunction={span}&emptyScoreValue={esValue}" 
            apicaller.setRsrcPath(path)
            @buff = ''
            skipFirst =1
            saveFile = File.open("#{@outputDir}/#{File.basename(@input[i])}","w+")
            
            ## downloading lff/bedgraph file
            httpResp = apicaller.get(
                                        {
                                           :scrTrack => @input[i].chomp('?'),
                                           :esValue  => "4290772992",
                                           :grp      => @grpROI,
                                           :db       => @dbROI,
                                           :trk      => @trkROI,
                                           :format   => "bedGraph",
                                           :span     => "avg"
                                           
                                        }
                                    ) {|chunck|
            fullChunk = "#{@buff}#{chunck}"           
            @buff = ''
            fullChunk.each_line { |line|
               if(line[-1].ord == 10)
                     if(skipFirst>1)
                        fields = line.split(/\t/)
                        saveFile.write("#{@lffClass}\t#{File.basename(@input[i])}\t#{@lffType}\t#{@lffSubType}\t#{fields[0]}\t#{fields[1]}\t#{fields[2]}\t+\t0\t#{fields[3]}")
                     end
                     skipFirst+=1  
               else
                  @buff += line
               end
               }
            }
            saveFile.close
            if apicaller.succeeded?
               $stdout.puts "successfully downloaded file" 
            else
               @stderr.puts apicaller.parseRespBody().inspect
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
               raise "#{apicaller.apiStatusObj['msg']}"
            end
        end
    end    
    
    
  
    ##Linear-regression and other statistical calculations
  def regression      
        
     begin
         
         ## uploading summary file to specified location
          apicaller =ApiCaller.new(@hostOutput,"",@user,@pass)
          restPath = @pathOutput
          path = restPath +"/file/signal-search/#{@runName}/summary.txt/data"
          apicaller.setRsrcPath(path)
          infile = File.open("#{@outputDir}/summary.txt","r")
          apicaller.put(infile)
          
          if apicaller.succeeded?
               $stdout.puts "successfully uploaded summary.txt"
          else
               apicaller.parseRespBody()
               $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
               @exitCode = apicaller.apiStatusObj['statusCode']
               raise "#{apicaller.apiStatusObj['msg']}"
          end
          uploadedPath = restPath+"/file/signal-search/#{@runName}/summary.txt"
          @apiRSCRpath = CGI.escape(uploadedPath)
          infile.close
          track = 1
          @bufferResult = ""
          infile = File.open("#{@outputDir}/summary.txt","r")
          while(line = infile.gets)
              if(track ==10)
                break
              end
            @bufferResult << "   #{line}"
            track += 1
          end
          infile.close
         
         num = 0
               body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job is completed successfully.

Job Summary:
   JobID                  : #{@jobID}
   Analysis Name          : #{@runNameOriginal}
   Query File             : #{CGI.unescape(File.basename(@input[0]))}
   Target Files           :"
  if(@ROItrack == true)
   num = @input.size-2
  else
    num = @input.size-1
  end
  body<<" #{num}"
  if(@ROItrack == true)
      body <<"
   ROITrack               : #{CGI.unescape(File.basename(@input[@input.size-1]))}"
    else
      body <<"
   ROITrack               : No ROI Track"
    end
   
    body <<"
    
Settings:
   SpanAggFunction        : #{@spanAggFunction}
   RemoveNoDataRegions    : #{@removeNoDataRegions}
   QuantileNormalized     : #{@quantileNormalized}
   Resolution             : #{@res}"
    
    body <<"
    
Top Results:
#{@bufferResult}"
      
      body <<"
      
Result File Location in the Genboree Workbench:
(Direct links to files are at the end of this email)
   Group : #{@grpOutput}
   DataBase : #{@dbOutput}
   Path to File:
      Files
      * signal-search
       * #{@runNameOriginal}
         * summary.txt

The Genboree Team

Result File URLs (click or paste in browser to access file):
    FILE: summary.txt
    URL: 
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpath}/data "
          

      subject = "Genboree: Your #{@toolTitle} job is complete "
         
          
           
           rescue => err
         $stderr.puts "Deatils: #{err.message}"
         $stderr.puts err.backtrace.join("\n")
         
          body =
"
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job is unsucessfull.

Job Summary:
  JobID : #{@jobID}
   Analysis Name : #{@runNameOriginal}
   Query Track :
      #{CGI.unescape(File.basename(@input[0]))}
   
  
      Error Message : #{err.message}
      Exit Status   : #{@exitCode}
Please Contact Genboree team with above information. 
        

The Genboree Team"

      subject = "Genboree: Your #{@toolTitle} job is unsuccessfull "
        end
        
         if (!@email.nil?) then
             sendEmail(subject,body)
           end
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
  
  
   def SignalSimilaritySearchAlltoAll.usage(msg='')
          unless(msg.empty?)
            puts "\n#{msg}\n"
          end
          puts "
      
        PROGRAM DESCRIPTION:
           Pairwise epigenome comparison tool
        COMMAND LINE ARGUMENTS:
          --file         | -j => Input json file
          --help         | -h => [Optional flag]. Print help info and exit.
      
       usage:
       
      ruby removeAdaptarsWrapper.rb -f jsonFile  
      
        ";
            exit;
        end # 
      
      # Process Arguements form the command line input
      def SignalSimilaritySearchAlltoAll.processArguements()
        # We want to add all the prop_keys as potential command line options
          optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                        ['--help'      ,'-h',GetoptLong::NO_ARGUMENT]
                      ]
          progOpts = GetoptLong.new(*optsArray)
          SignalSimilaritySearchAlltoAll.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
          optsHash = progOpts.to_hash
        
          Coverage if(optsHash.empty? or optsHash.key?('--help'));
          return optsHash
      end 

end

optsHash = SignalSimilaritySearchAlltoAll.processArguements()
performQCUsingFindPeaks = SignalSimilaritySearchAlltoAll.new(optsHash)
performQCUsingFindPeaks.work()
