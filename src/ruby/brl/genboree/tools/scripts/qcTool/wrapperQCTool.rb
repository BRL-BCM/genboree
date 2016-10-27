#!/usr/bin/env ruby

require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/db/dbrc'
require 'brl/util/emailer'
require 'brl/util/util'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'json'
require 'getoptlong'
require 'rubygems'
require 'uri'
require 'fileutils'
include BRL::Genboree::REST

class WrapperQC
  attr_accessor :jsonObj

  GENOME_INFO_MAP = {
    "hg18" => { :host => 'genboree.org', :grp => 'Epigenomics Roadmap Repository', :db => 'Data Freeze 1 - Full Repo' },
    "hg19" => { :host => 'genboree.org', :grp => 'Epigenomics Roadmap Repository', :db => 'Data Freeze 2 Repository' }
  }

  def initialize(optsHash)
    @optsHash = optsHash
    json =  @optsHash['--jsonFile']
    noPermCheck = @optsHash['--noPermCheck']
    @prefix = "QC_"
    @output = @prefix + "output.txt"
    @jsonObj = nil
    @noPermCheck = noPermCheck
    @gbLock = nil
    @gbLockFileKey = nil
    @jobid = nil
    @outputurl = nil
    @experimentName = nil
    @clusterQueue = nil
    @pvalue = nil
    @genome = nil
    @assay = nil
    @fdr = nil
    @apiUserName = nil
    @userFirstName = nil
    @userLastName = nil
    @userPasswd = nil
    @userEmail = nil
    @userId = nil
    @tempDir = nil    #"tmp/"
    @gbAdminEmail = nil
  	@command = nil
  	@result = nil

    unless File.exist?(json)
      raise "Problem reading the standard tool interface config file."
    end

    #getParams(json)
    begin
      @jsonObj = JSON.parse(File.read(json))
    rescue
      raise "Problem parsing json file: " + $!
    end

    user = nil
    pass = nil
    host = nil
    begin
      #dbrcFile = File.expand_path("~/.dbrc")
      dbrcFile = File.expand_path(ENV['DBRC_FILE'])
      dbrcKey = @jsonObj['context']['apiDbrcKey']
      dbrc = BRL::DB::DBRC.new(dbrcFile, dbrcKey)
      user = dbrc.user
      pass = dbrc.password
      host = dbrc.driver.split(/:/).last
    rescue
      raise "cannot read .dbrc file: " + $!
    end

    @jobid = @jsonObj["context"]["jobId"]
    @apiUserName = user
    @userFirstName = @jsonObj["context"]["userFirstName"]
    @userLastName = @jsonObj["context"]["userLastName"]
    @userPasswd = pass
    @userEmail = @jsonObj["context"]["userEmail"]
    @userId = @jsonObj["context"]["userId"]
    @gbAdminEmail = @jsonObj["context"]["gbAdminEmail"]
    @userId = @jsonObj['context']['userId']
    if(@jobid == nil or @apiUserName == nil or @userPasswd == nil or @userEmail == nil)
      raise "Problem parsing the standard tool interface config file."
    end

    @tempDir = File.expand_path(@jsonObj["context"]["scratchDir"])
    if(@tempDir == nil)
      @tempDir = File.expand_path("tmp/")
    else
      @tempDir = @tempDir + "/"
    end
    unless(File.exist?(@tempDir) and File.writable?(@tempDir))
      #FileUtils.rm_r @tempDir
    #else
      raise "could not write on temporary directory"
    end
    #FileUtils.mkdir_p @tempDir

    if(@jsonObj.has_key?("settings"))
      @experimentName = @jsonObj["settings"]["experimentName"]
      @clusterQueue = @jsonObj["settings"]["clusterQueue"]
      @pvalue = @jsonObj["settings"]["pvalue"]
      @genome = @jsonObj["settings"]["genome"]
      @assay = @jsonObj["settings"]["assay"]
      @fdr = @jsonObj["settings"]["fdr"]
    end
  end

  def submitJob()
    #puts @jsonObj['context']['gbLockFileKey'].to_sym
    begin
      cmdResult =  executeQC()
      if(cmdResult == true)
        ################################################################
        #upload result file
        #################################################################
        if(putResultFile())
          # Body of email
          body = "The results of FindPeaks, HotSpot, and Poisson QC runs were:\n\n#{'-'*50}\n"
          body << File.read(@outFileName)
          body << "#{'-'*50}\nThis tab-delimited report is available in Genboree for later reference\nby you or the other members of the '#{@outputGroup}' group. Location in Workbench:\n    Group: #{CGI.unescape(@outputGroup)}\n    Database: #{CGI.unescape(@outputDb)}\n    Path in Files Area:\n#{@outputFilesPath}\n\nA direct link to the file is included at the bottom of this email."
          sendSuccessEmail(body)
        else
          description = "Could not upload output data."
          sendFatalErrorEmail(description)
          $stderr.puts "Could not upload output data."
        end
        compressTempFiles()
      else
        if($?.exitstatus == 57)
          description = "The data would not provide enough vector length for the correlation."
          sendFatalErrorEmail(description)
        else
          description = "Could not execute the Percentile QC tool."
          sendFatalErrorEmail(description)
        end
        compressTempFiles()
        $stderr.puts "Could not execute the Percentile QC tool."
      end
    rescue Exception => err
      #compressTempFiles()
      $stderr.puts err.message()
      $stderr.puts err.backtrace.join("\n")
      unless err.message =~ /^Could not/
        description = "'#{err.message}' at:\n#{err.backtrace.join("\n")}"
        sendFatalErrorEmail(description)
      else
        sendFatalErrorEmail(err.message())
      end
    end
  end

  def executeQC()
    ###################################################################
    # download input file describe in the json and get the path of file
    ###################################################################
    infile = getInputFile()
    infilesize = File.size(infile)
    fdr = @fdr
    pval = @pvalue
    assay = @assay

    ###################################################################
    # download appropriate chromosome file, as Andrew noted on wiki
    ###################################################################
    @chromsFile = getChromsFile()

    @outFileName = "./qc.report.txt"

    @outputurl = @jsonObj["outputs"][0]
    if(@outputurl == nil)
      raise "Could not complete executeSearchSignalSim because the output url was not defined."
    end

    ####################################################################
    #run executable file
    ####################################################################
    Dir.chdir(@tempDir)
    stderrFile = "./call4QC.stderr"
    stdoutFile = "./call4QC.stdout"
    @command = "call4QC.rb -b ./#{File.basename(infile)} -r ./#{File.basename(@chromsFile)} -s . -o ./#{File.basename(@outFileName)} -g #{@genome} -p #{@pvalue} -F #{@fdr} -a #{@assay} > #{stdoutFile} 2> #{stderrFile} "
    puts "Command: #{@command.inspect}"
    return system(@command)
  end

  def parseURL(url)
    uriObj = URI.parse(url)
    host = uriObj.host
    puts "host : #{host}"
    path = uriObj.path
    puts "path : #{path}"
    query = uriObj.query
    if(query != nil)
      if(query.size > 0)
        query += "&"
      end
    end
    return host, path, query
  end

  def getChromsFile()
    rsrcPath = "/REST/v1/grp/{grp}/db/{db}/eps?format=lff"
    $stderr.puts "chroms resource path: #{rsrcPath}"
    apiCaller = WrapperApiCaller.new(
      GENOME_INFO_MAP[@genome][:host],
      rsrcPath,
      @userId
    )

    httpResp = apiCaller.get( { :grp => GENOME_INFO_MAP[@genome][:grp], :db => GENOME_INFO_MAP[@genome][:db] } )

    if(apiCaller.succeeded?)
      chromsFileName = "#{@tempDir}#{@prefix}#{Time.now().to_f.round.to_s}_#{rand(1000000).to_s.rjust(6, '0')}.chroms"
      outfile = File.open(chromsFileName, "w+")
      apiCaller.respBody.each_line { |line|
        fields = line.strip.split(/\t/)
        outfile.puts "#{fields[0]}\t#{fields[2]}"
      }
      outfile.close()
      return File.expand_path(chromsFileName)
    else # api call failed
      $stderr.puts "API ERROR. RESPONSE BODY:\n#{apiCaller.respBody.inspect}"
      return nil
    end
  end

  def getInputFile()
    host, path, query = parseURL(@jsonObj["inputs"][0])
    puts "inputFile resouce : #{path}"
    baseName = File.basename(path)
    apiCaller = WrapperApiCaller.new(
          host,
          "#{path}/data",
          @userId)
    puts "apiCaller = ApiCaller.new(#{host},#{path},#{@apiUserName},#{@userPasswd})"

    fname = "#{@tempDir}#{baseName}"
    outfile = File.open(fname,"w+")
    puts "outfile : #{fname}"

    httpResp = apiCaller.get() {	|line|
      outfile.print line
    }
    outfile.close()

    if(apiCaller.succeeded?)
      return File.expand_path(fname)
    else
      apiCaller.parseRespBody()
      $stderr.puts "API response; statusCode: #{apiCaller.apiStatusObj['statusCode']}, message: #{apiCaller.apiStatusObj['msg']}"
      return nil
    end
  end

  def putResultFile()
    host, path, query = parseURL(@outputurl)
    resultfile = File.basename(@outFileName)
    dir1 = "Percentile QC"
    dir2 = @experimentName
    @outputFilesPath = "    * #{dir1}\n      * #{dir2}\n        * #{resultfile}"
    resource = path + "/file/{dir1}/{dir2}/#{resultfile}/data"
    # extract output db, group name:
    @outputurl =~ %r{/grp/([^/]+)/db/([^/\?]+)}
    @outputGroup = $1
    @outputDb = $2

    puts "putResultFile resource : #{resource}"
    apiCaller = WrapperApiCaller.new(host, resource, @userId)
    @outputFileUrl = apiCaller.fillApiUriTemplate({:dir1 => dir1, :dir2 => dir2})
    result = File.open(@outFileName)
    httpResp = apiCaller.put( {:dir1 => dir1, :dir2 => dir2}, result)

    if(apiCaller.succeeded?)
      result.close()
      return File.expand_path(@outFileName)
    else
      result.close()
      apiCaller.parseRespBody()
      $stderr.puts "API response; statusCode: #{apiCaller.apiStatusObj['statusCode']}, message: #{apiCaller.apiStatusObj['msg']}"
      return nil
    end
  end

  def getUserName()
    return "#{@userFirstName} #{@userLastName}"
  end

  def sendSuccessEmail(summary)
    subjectTxt = "Genboree: QC job completed successfully."
    bodyTxt = "Hello "+getUserName()+","
    bodyTxt += "\n\n"
    bodyTxt += "Your Percentile QC tool run has completed successfully.\n"
    bodyTxt += "(JobId: #{@jobid})\n\n"
    bodyTxt += summary
    bodyTxt += "\n"
    bodyTxt += "\n"
		bodyTxt += "-- The Genboree Team\n"
		bodyTxt += "\n\n"
		bodyTxt += "Result File URLs:\n"
		host, path, query = parseURL(@outputurl)
		bodyTxt += "    FILE: #{File.basename(@outFileName)}\n"
		uri = URI.parse(@outputFileUrl)
		rsrcPathToFileData = "#{uri.path}?#{uri.query}"
		bodyTxt += "    URL:\n\n"
		bodyTxt += "    http://#{host}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape(rsrcPathToFileData)}"
		bodyTxt += "\n\n"

    sendEmail(subjectTxt,bodyTxt)
  end

  def sendFailEmail()
    subjectTxt = "Genboree: your QC failed."
    bodyTxt = "Hello "+getUserName()+","
    bodyTxt += "\n\n"
    bodyTxt += "Unfortunately, we cannot run the QC tool on the tracks you provided.\n"
    bodyTxt += "\n"
    bodyTxt += "The databases the tracks come from are not compatible.The input\n"
    bodyTxt += "and target data must all be for the same species and the same assembly of that species' genome.\n"
    bodyTxt += "\n"
    bodyTxt += "Job Summary:\n"
    bodyTxt += "    JobID: #{@jobid}\n"
    bodyTxt += "    Input Track: "+getTrackName(@inputurl)+" (genome version: #{@inputver})\n"
    bodyTxt += "    Region of Interest: "+getTrackName(@roiurl)+" (genome version: #{@roiver})\n" unless @roiurl == nil
    #tcount = 1
    #@targeturls.each{	|turl|
    #	bodyTxt += "\tTarget#{tcount}: "+getTrackName(turl)+" (genome version: #{@targetvers[tcount-1]})\n"
    #	tcount += 1
    #}
    bodyTxt += "    The number of targets : #{@targeturls.length}"
    bodyTxt += "\n"
    bodyTxt += "If you can address this problem, we encourage you to rerun the tool.\n"
    bodyTxt += "\n"
    bodyTxt += "-- The Genboree Team\n"
    sendEmail(subjectTxt,bodyTxt)
  end

  def sendFatalErrorEmail(desc)
    subjectTxt = "Genboree: your QC failed"
    bodyTxt = "Hello " + getUserName() + ","
    bodyTxt += "\n\n"
    bodyTxt += "Unfortunately, we encountered a fatal problem when trying to run your QC job.\n"
    bodyTxt += "\n"
    bodyTxt += "Job Summary:\n"
    bodyTxt += "\tJobID: #{@jobid}\n"
    bodyTxt += "\n"
    bodyTxt += "Error Summary:\n"
    bodyTxt += "\tError description: #{desc}\n"
    bodyTxt += "\n"
    bodyTxt += "To help resolve this problem, please contact a Genboree Administrator\n"
    bodyTxt += "(genbadmin_admin@genboree.org) with the job and error summaries.\n"
    bodyTxt += "\n"
    bodyTxt += "-- The Genboree Team\n"
    sendEmail(subjectTxt,bodyTxt)
  end

  def sendEmail(subjectTxt, bodyTxt)
    puts "=====email Station===="
    puts @gbAdminEmail
    puts @userEmail

    email = BRL::Util::Emailer.new()
    email.setHeaders(@gbAdminEmail, @userEmail, subjectTxt)
    email.setMailFrom('andrewj@bcm.edu')
    email.addRecipient(@userEmail)
    email.addRecipient(@gbAdminEmail)
    email.setBody(bodyTxt)
    email.send()

    puts "Subj:"
    puts subjectTxt
    puts "Body:"
    puts bodyTxt
  end

  def compressTempFiles()
    Dir.chdir(@tempDir)
    files = Dir.glob("#{@prefix}*")
    files.each{	|f|
      if File.directory?(f)
        system("tar -zcvf #{f}.tar.gz #{f}")
        system("rm -r #{f}")
      else
        system("gzip #{f}")
      end
    }
  end

  def deleteTempDir()
    FileUtils.rm_rf(@tempDir)
  end

  def WrapperQC.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
						[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
						[ '--noPermCheck', '-n', GetoptLong::NO_ARGUMENT ],
						[ '--jsonFile', '-j', GetoptLong::REQUIRED_ARGUMENT ]
					]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		WrapperQC.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			WrapperQC.usage("USAGE ERROR: some required arguments are missing")
		end

		#WrapperQC.usage() if(optsHash.empty?);
		return optsHash
  end

  def WrapperQC.usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "
    # == Synopsis
    #
    # WrapperQC_1.0.rb: executes call4QC.rb with parameters in a JSON file
    #
    # == Usage
    #
    # WrapperQC_1.0.rb OPTION
    #
    # -h, --help:
    #    shows help
    #
	# --jsonFile, -j json_File
	#	 describes arguments for EpiComp_1.7.rb
	#"
	exit(2)
  end
end

# WTF? Why is this copy here...stupid design. Use ToolWrapper to solve this design issues better and more robustly.
def sendEmail(subjectTxt, bodyTxt, wrapperObj=nil)
  if(wrapperObj and wrapperObj.jsonObj["context"])
    puts "=====Init Error Email Station===="
    gbAdminEmail = wrapperObj.jsonObj["context"]["gbAdminEmail"]
    userEmail = wrapperObj.jsonObj["context"]["userEmail"]
    if(gbAdminEmail and userEmail)
      email = BRL::Util::Emailer.new()
      email.setHeaders(gbAdminEmail, userEmail, subjectTxt)
      email.setMailFrom('andrewj@bcm.edu')
      email.addRecipient(userEmail)
      email.addRecipient(gbAdminEmail)
      email.setBody(bodyTxt)
      email.send()

      puts "Subj:"
      puts subjectTxt
      puts "Body:"
      puts bodyTxt
    end
  end
end



beginning = Time.now
puts ">Wrapper Begin : #{beginning}"

# Process command line options
optsHash = WrapperQC.processArguments()

begin
	# Instantiate analyzer using the program arguments
	wQC = WrapperQC.new(optsHash)
	# Submit this !
	wQC.submitJob()
rescue Exception => err
	$stderr.puts err.message()
	$stderr.puts err.backtrace.join("\n")
  # Try to send email to user
  if(wQC and wQC.jsonObj)
    subjectTxt = "Genboree: QCTool failed"
  	description = "Unexpected Error #{err.message} at:\n\n#{err.backtrace.join("\n")}\n\n"
  	sendEmail(subjectTxt, description, wQC)
  end
end


puts "Now : #{Time.now}"
puts ">Wrapper Time elapsed #{Time.now - beginning} seconds"
