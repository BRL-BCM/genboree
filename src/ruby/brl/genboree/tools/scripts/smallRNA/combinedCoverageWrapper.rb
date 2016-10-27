#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/db/dbrc'
require 'spreadsheet'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'

include BRL::Genboree::REST


class RemoveAdapters



  def initialize(optsHash)
    @input    = File.expand_path(optsHash['--jsonFile'])
    jsonObj = JSON.parse(File.read(@input))

    @inputs  = jsonObj["inputs"]
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
    @toolId = jsonObj["context"]["toolIdStr"]
    @userId = jsonObj['context']['userId']

    @runName = jsonObj["settings"]["analysisName"]
    @runName = CGI.escape(@runName)
    @runNameOriginal = CGI.unescape(@runName)
    @sampleType = []
    @sampleType = jsonObj["settings"]["sampleType"]
    ##Pulling out information about target database,group and password
    grph = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @dbOutput = @dbhelper.extractName(@output)
    @grpOutput = grph.extractName(@output)
    dbrc = BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass = dbrc.password
    @user = dbrc.user
    @outputDir = @output.chomp('?')
    uriOutput = URI.parse(@output)
    @hostOutput = uriOutput.host
    @pathOutput = uriOutput.path
    @usableFiles = []
    @resultFiles = []
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
  
  
  def checkInputs
    @inputs.each{|input|
      lffFile = nil
      
      xlsFile = nil
      statsFile = nil
      sampleFound = false
      sampleName = nil
      uri = URI.parse(input)
      host = uri.host
      path = uri.path
      rsrcPath = "#{path}?detailed=true&depth=immediate"
      rsrcPath << "&gbKey=#{@dbhelper.extractGbKey(input)}" if(@dbhelper.extractGbKey(input))
      apiCaller = WrapperApiCaller.new(host,rsrcPath,@userId)
      apiCaller.get()
      if(apiCaller.succeeded?) then
        apiCaller.parseRespBody()
        apiCaller.apiDataObj.each{|dd|
          checkForSample = false
          if(dd["name"] =~ /\.lff/) then
            lffFile = File::makeSafePath(dd["name"])
            checkForSample = true
          elsif (dd["name"] =~ /\.xls/) then
            xlsFile = File::makeSafePath(dd["name"])
            checkForSample = true
          elsif (dd["name"] =~ /_Stats/) then
            statsFile = File::makeSafePath(dd["name"])
            checkForSample = true
          end
          if(checkForSample) then
            currSample = dd["attributes"]["SampleName"]
            if(currSample.nil? or currSample.empty?) then
              raise "ERROR: #{dd["name"]} does not have a valid SampleName atrribute. Unable to proceed\n\n"
            elsif(sampleName.nil?) then
              sampleName = currSample
            elsif(sampleName != currSample)
              raise "ERROR: All files in #{input} do not have the same SampleName. Unable to proceed\n\n"
            end
          end
          
          }
        validInput = !(lffFile.nil? or xlsFile.nil? or statsFile.nil? or sampleName.nil?)
        if(validInput) then
          filePrefix = @dbhelper.extractPath(input)
          @resultFiles << {:lff =>"#{filePrefix}/file/#{lffFile}",:xls =>"#{filePrefix}/file/#{xlsFile}",:stats =>"#{filePrefix}/file/#{statsFile}",:sample =>sampleName}
        else
          raise "ERROR: Input #{input} does not contain all of the required files:(.lff,.xls, _Stats). Unable to proceed\n\n"
        end
      else
        raise "ERROR: Unable to retrieve input #{input}.\n\n#{apiCaller.respBody}"        
      end
    }
  end

  def work
    begin
    checkInputs()
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
    index = 0
    resultsDir = "#{@scratch}/CombinedCoverage/#{@runName}"
    system("mkdir -p #{resultsDir}")
    @inputs.each_index{|ii|
      counter = 0
      begin
        @inputs[ii] = @inputs[ii].chomp('?')
        uri = URI.parse(@inputs[ii])
        hostInput = uri.host
        pathInput = uri.path
        rsrcPath = "#{@resultFiles[ii][:lff]}/data"
        @baseName = File.basename(@resultFiles[ii][:lff])
        rsrcPath << "?gbKey=#{@dbhelper.extractGbKey(@inputs[ii])}" if(@dbhelper.extractGbKey(@inputs[ii]))        
        apicaller = WrapperApiCaller.new(hostInput,rsrcPath,@userId)
        $stdout.puts "downloading #{@baseName}"
        saveFile = File.open("#{resultsDir}/#{@baseName}","w+")
        httpResp = apicaller.get() {|chunk|
          saveFile.write(chunk)
        }
        saveFile.close
        if apicaller.succeeded?
          $stdout.puts "success"
        else
          raise("ERROR: ApiCaller did not succeed\nrsrcPath=#{apicaller.rsrcPath}\nrespBody=#{apicaller.respBody.inspect}")
        end
        system("LFFValidator.rb -f #{CGI.escape(resultsDir)}/#{CGI.escape(@baseName)} -t annos -n 1")
        if($?!=0)
          @exitCode = $?.exitstatus
          raise "#{@baseName} has wrong format."
        end
        if(pathInput =~/(.*)#{@baseName}/)
          @dirOfInputFile = $1
        end
        @readName = @baseName.split(".")[0]
        ##Downloading excel file
        rsrcPath = "#{@resultFiles[ii][:xls]}/data"
        rsrcPath << "?gbKey=#{@dbhelper.extractGbKey(@inputs[ii])}" if(@dbhelper.extractGbKey(@inputs[ii]))
        apicaller = WrapperApiCaller.new(hostInput,rsrcPath,@userId)
        xlsName = File.basename(@resultFiles[ii][:xls])
        $stdout.puts "downloading #{xlsName}"
        saveFile = File.open("#{resultsDir}/#{xlsName}","w+")
        httpResp = apicaller.get() {|chunk|
          saveFile.write(chunk)
        }
        saveFile.close
        if apicaller.succeeded?
          $stdout.puts "success"
        else
          raise("ERROR: ApiCaller did not succeed\nrsrcPath=#{apicaller.rsrcPath}\nrespBody=#{apicaller.respBody.inspect}")
        end
        ## Making Combined Summary
        bookRead = Spreadsheet.open("#{resultsDir}/#{xlsName}")
        sheetRead = bookRead.worksheet(0)
        sheetRead.each { |row|
          a = row.join(',')
          columns = a.split(',')
          if(index==0)
            for jj in 0...columns.size
              sheet.row(counter).insert jj, columns[jj]
              row.set_format jj, Spreadsheet::Format.new(:number_format => '0.0')
            end
          else
            for jj in 3...columns.size
              sheet.row(counter).insert jj+track, columns[jj]
              row.set_format jj, Spreadsheet::Format.new(:number_format => '0.0')
            end
          end
          counter += 1
        }
        track += 3
        index += 1
        ##Downloading stats file
        rsrcPath = "#{@resultFiles[ii][:stats]}/data"
        rsrcPath << "?gbKey=#{@dbhelper.extractGbKey(@inputs[ii])}" if(@dbhelper.extractGbKey(@inputs[ii]))
        apicaller = WrapperApiCaller.new(hostInput,rsrcPath,@userId)
        statsName = File.basename(@resultFiles[ii][:stats])
        $stdout.puts "downloading #{statsName}"
        saveFile = File.open("#{resultsDir}/#{statsName}","w+")
        httpResp = apicaller.get() {|chunk|
          saveFile.write(chunk)
        }
        saveFile.close
        if apicaller.succeeded?
          $stdout.puts "success"
        else
          raise("ERROR: ApiCaller did not succeed\nrsrcPath=#{apicaller.rsrcPath}\nrespBody=#{apicaller.respBody.inspect}")
        end
        filereader = File.open("#{resultsDir}/#{statsName}")
        filereader.each{|line|
          column = line.split(/sum=/)
          puts column[1]
          @usableReads = column[1]
        }
        #@input[i] = "#{@output}/#{@baseName}"
        #@input[i] = CGI.escape(@input[i])
        @usableFiles[ii] = @usableReads.to_i
        #@validInputFiles[validEntries] = @input[i]
        @validUsable[validEntries] = @usableReads.to_i
        if(@sampleType[0]!="na")
          @validSampleType[validEntries] = @sampleType[ii]
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
    }
    book.write("#{resultsDir}/combinedCoverage.xls")
      
    xlsFilesDir = "#{resultsDir}/xlsFiles"
    system("mkdir -p #{xlsFilesDir}")
      ##Running filter script
      command = "combineMultipleCoverageExperimentsByNameAndChromosomeLocation.rb -f '"
      command << @resultFiles.map{|xx|CGI.escape("#{resultsDir}/#{File.basename(xx[:lff])}")}.join(",")
      #for i in 0...@validInputFiles.size
      #
      #  if(i!=@validInputFiles.size-1)
      #    command<<"#{@validInputFiles[i]},"
      #  else
      #    command<<"#{@validInputFiles[i]}'"
      #  end
      #end

      command <<"' -u '#{@validUsable.join(",")}'"
      #for i in 0...@validUsable.size
      #
      #  if(i!=@validUsable.size-1)
      #    command<<"#{@validUsable[i]},"
      #  else
      #    command<<"#{@validUsable[i]}'"
      #  end
      #end


      if(@sampleType[0] != "na" )
        command <<" -s '#{@validSampleType.join(",")}'"
        #for i in 0...@validSampleType.size
        #
        #  if(i!=@validSampleType.size-1)
        #    command<<"#{@validSampleType[i]},"
        #  else
        #    command<<"#{@validSampleType[i]}'"
        #  end
        #end
      end

      command <<" -o #{CGI.escape(xlsFilesDir)}> #{resultsDir}/log.combinedCoverage "

      $stdout.puts command

      system(command)
      if(!$?.success?)
        @exitCode = $?.exitstatus
        raise " combineMultipleCoverageExperimentsByNameAndChromosomeLocation.rb didn't work"
      end

      ## uploading of output files in specified location (from json file)
      apicaller = WrapperApiCaller.new(@hostOutput,"",@userId)
      restPath = @pathOutput
      #if(File.exists?("#{@output}/RNA_miRNA.xls"))
      #  infile = File.open("#{@output}/RNA_miRNA.xls","r")
      #elsif(File.exists?("#{@output}/RNA miRNA.xls"))
      #  infile = File.open("#{@output}/RNA miRNA.xls","r")
      #else
      #  infile = File.open("#{@output}/miRNA Cluster.xls","r")
      #end
      
        attrNames = ["JobToolId","CreatedByJobName","JobInputs"]
        attrValues = [@toolId, @jobID,@inputs.join(",")]
      xlsFilePaths = []
      rawDirPresent = false
      pathPrefix = restPath +"/file/CombinedCoverage/#{@runName}/"
            Dir.foreach(xlsFilesDir){|file|
              suffix = ""
              if(file =~ /\.xls$/) then
                path = pathPrefix.dup
                if(file =~ /miRNA/i) then
                  path << "#{CGI.escape(file)}/data"
                else
                  path << "raw/#{CGI.escape(file)}/data"
                  rawDirPresent = true
                  suffix = "raw/"
                end 
                path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
                apicaller.setRsrcPath(path)
                ofh = File.open("#{xlsFilesDir}/#{file}","r")
                apicaller.put(ofh)
                ofh.close
                if (apicaller.succeeded?) then
                  $stdout.puts "Successfully uploaded #{file}"
                  setFileAttrs("#{pathPrefix}#{suffix}#{CGI.escape(file)}",attrNames,attrValues)
                  xlsFilePaths << [file,path]
                else
                  raise("ERROR: ApiCaller did not succeed\nrsrcPath=#{apicaller.rsrcPath}\nrespBody=#{apicaller.respBody.inspect}")                  
                end
              end
            }
            
            
            if(rawDirPresent) then setFileAttrs("#{pathPrefix}raw",attrNames,attrValues) end
            setFileAttrs(pathPrefix.gsub(/\/$/,""),attrNames,attrValues)
      ##uploading combined coverage excel sheet
      restPath = @pathOutput
      path = restPath +"/file/CombinedCoverage/#{@runName}/combinedCoverage.xls/data"
      path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
      apicaller.setRsrcPath(path)
      infile = File.open("#{resultsDir}/combinedCoverage.xls","r")
      apicaller.put(infile)


      if apicaller.succeeded?
        $stdout.puts "Successfully uploaded combinedCoverage.xls"
        setFileAttrs("#{pathPrefix}combinedCoverage.xls",attrNames,attrValues)
      else
        raise("ERROR: ApiCaller did not succeed\nrsrcPath=#{apicaller.rsrcPath}\nrespBody=#{apicaller.respBody.inspect}")
      end

      uploadedPathCombined = restPath+"/file/CombinedCoverage/#{@runName}/combinedCoverage.xls"
      @apiRSCRpathCombined = CGI.escape(uploadedPathCombined)




      body =
      "
Hello #{@user_first.capitalize} #{@user_last.capitalize}
Your small RNA combining coverage tool run is completed successfully.

Job Summary:
JobID : #{@jobID}
Analysis Name : #{@runNameOriginal}

Input File :\n"
for i in 0...@resultFiles.size
        body << " #{File.basename(@resultFiles[i][:lff])}\n"
end
body << "\n\nResult File Location in the Genboree Workbench:
(Direct links to files are at the end of this email)
Group : #{@grpOutput}
DataBase : #{@dbOutput}
Path to File:
Files
* CombinedCoverage/\n"
xlsFilePaths.each{|xx|
body <<" * #{xx[0]}\n"
}
body << "* combinedCoverage.xls

The Genboree Team


Result File URLs (click or paste in browser to access file):
File: combinedCoverage.xls
http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpathCombined}/data\n\n"
xlsFilePaths.each{|xx|
  body << "File: #{xx[0]}\nURL:\n"
  body << "http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{xx[1]}\n\n"
  }
      if (@storeErrors!="")
        body <<"Following file(s) could not be processed due to bad format:
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

      Your #{@toolTitle} analysis job mapping reads is unsuccessful.

      Job Summary:
      JobID         : #{@jobID}
      Analysis Name : #{@runNameOriginal}

      Error Message : #{err.message}
      Exit Status   : #{@exitCode}
      Please Contact Genboree team with above information.

      The Genboree Team

      "

      subject = "Genboree: Your #{@toolTitle} analysis job of mapping reads is unsuccessful"
    end



    if (!@email.nil?) then
      sendEmail(subject,body)
    end

    #system("rm #{@scratch}/CombinedCoverage/#{@runName}/*.lff*")

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
