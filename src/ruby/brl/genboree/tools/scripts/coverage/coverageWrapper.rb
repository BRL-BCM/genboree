#!/usr/bin/env ruby

# Loading libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/genboreeDBHelper'
require 'brl/util/emailer'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/helpers/expander'
require 'uri'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

# Main class
class SignalCoverageWrapper
  BUFFERSIZE = 32_000_000
  NON_COVERAGE_SETTINGS = { 'clusterQueue' => true }
  # Constructor
  # [+optsHash+] hash with command line args
  # [+returns+] nil
  def initialize(optsHash)
    @userEmail = nil
    inputFile = optsHash['--inputFile']
    @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
    @grpApiHelper = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new()
    begin
      parseInputFile(inputFile)
      computeCoverage()
      sendSuccessEmail()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end

  # makes API call to get the annos for the track
  # also launches the program for computing coverage
  # [+returns+] nil
  def computeCoverage()
    # first get the data
    rcscUri = nil
    tempFile = nil
    tmpFile = "#{@scratchDir}/#{Time.now.to_f}.tmp"
    writer = BRL::Util::TextWriter.new(tmpFile)
    if(@inputUri =~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP) # for track
      rcscUri = @inputUri.slice(@inputUri.index('/REST/')..-1)
      rcscUri.gsub!("?", "")
      rcscUri << "/annos?format=bed"
      rcscUri << "&extendAnnos&extendValue=#{@extendValue}" if(@extendValue)
      rcscUri << "&truncateAnnos&truncateValue=#{@truncateValue}" if(@truncateValue)
      rcscUri << "&gbKey=#{@dbApiHelper.extractGbKey(@inputUri)}" if(@dbApiHelper.extractGbKey(@inputUri))
    else # for file
      rcscUri = @inputUri.slice(@inputUri.index('/REST/')..-1)
      rcscUri.gsub!("?", "")
      rcscUri << "/data"
      rcscUri << "?gbKey=#{@dbApiHelper.extractGbKey(@inputUri)}" if(@dbApiHelper.extractGbKey(@inputUri))
    end
    $stderr.puts "URI for 'get': #{rcscUri}"
    apiCaller = WrapperApiCaller.new(@host, rcscUri, @userId)
    $stderr.puts "downloading annos..."
    apiCaller.get() { |chunk| writer.print chunk}
    if(!apiCaller.succeeded?)
      @emailMessage = "There was a problem downloading the resource: #{@inputUri.inspect}"
      raise "ERROR: apiCaller response for 'getting': #{@inputUri.inspect}\n: #{apiCaller.respBody}"
    end
    # Performs 'extent' or/and 'truncate' if provided
    writer.close
    @exp = BRL::Genboree::Helpers::Expander.new(tmpFile)
    @exp.extract()
    tmpFile = @exp.uncompressedFileName
    if(@inputUri !~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
      if(@extendValue or @truncateValue)
        tempFile = "#{@scratchDir}/#{Time.now.to_f}.temp"
        fileReader = File.open(tmpFile)
        fileWriter = File.open(tempFile, "w")
        orphan = nil
        while(!fileReader.eof?)
          fileBuff = fileReader.read(BUFFERSIZE)
          fileBuffIO = StringIO.new(fileBuff)
          strand = nil
          chromEnd = nil
          chromStart = nil
          fileBuffIO.each_line { |line|
            line = orphan + line if(!orphan.nil?)
            orphan = nil
            if(line =~ /\n$/)
              line.strip!
              next if(line.nil? or line.empty? or line =~ /^#/ or line =~ /^\s*$/)
              currRec = line.split(/\t/)
              case @fileType
              when 'bed'
                strand = currRec[5]
                chromStart = currRec[1].to_i + 1
                chromEnd = currRec[2].to_i
              when 'lff'
                strand = currRec[7]
                chromStart = currRec[5].to_i
                chromEnd = currRec[6].to_i
              when 'bedGraph'
                chromStart = currRec[1].to_i + 1
                chromEnd = currRec[2].to_i
              when 'gff'
                strand = currRec[6]
                chromStart = currRec[3].to_i
                chromEnd = currRec[4].to_i
              when 'gff3'
                strand = currRec[6]
                chromStart = currRec[3].to_i
                chromEnd = currRec[4].to_i
              when 'gtf'
                strand = currRec[6]
                chromStart = currRec[3].to_i
                chromEnd = currRec[4].to_i
              end
              if(@extendValue)
                @extendValue = @extendValue.to_i
                if((chromEnd - chromStart) + 1 < @extendValue)
                  if(@fileType == 'bedGraph') # since bedGraph does not have strand
                    chromEnd = chromStart + (@extendValue - 1)
                  else
                    if(strand == '+')
                      chromEnd = chromStart + (@extendValue - 1)
                    else
                      chromStart = chromEnd - (@extendValue - 1)
                    end
                  end
                end
              end
              if(@truncateValue)
                @truncateValue = @truncateValue.to_i
                if((chromEnd - chromStart) + 1 > @truncateValue)
                  if(@fileType == 'bedGraph')
                    chromEnd = chromStart + (@truncateValue - 1)
                  else
                    if(strand == '+')
                      chromEnd = chromStart + (@truncateValue - 1)
                    else
                      chromStart = chromEnd - (@truncateValue - 1)
                    end
                  end
                end
              end
              # Subtract 1 from start coord for 'bed' and 'bedGraph'
              chromStart -= 1 if(@fileType == 'bed' or @fileType == 'bedGraph')
              case @fileType
              when 'bed'
                currRec[1] = chromStart
                currRec[2] = chromEnd
              when 'lff'
                currRec[5] = chromStart
                currRec[6] = chromEnd
              when 'bedGraph'
                currRec[2] = chromEnd
                currRec[1] = chromStart
              when 'gff'
                currRec[3] = chromStart
                currRec[4] = chromEnd
              when 'gff3'
                currRec[3] = chromStart
                currRec[4] = chromEnd
              when 'gtf'
                currRec[3] = chromStart
                currRec[4] = chromEnd
              end
              fileWriter.puts(currRec.join("\t"))
            else
              orphan = line
            end
          }
        end
        fileReader.close()
        fileWriter.close()
        system("rm #{tmpFile}")
      else
        tempFile = tmpFile
      end
    else
      tempFile = tmpFile
    end
    # next sort the file and remove redundancies
    cmd = ""
    stderrFileForProgram = "#{@scratchDir}/#{Time.now.to_f}.removeRedundantReads.rb.err"
    if(@noStrand)
      cmd = "removeRedundantReads.rb -i #{CGI.escape(tempFile)} -f #{@fileType} -o #{CGI.escape(tempFile)}_sorted --noStrandForSorting --userEmail #{@userEmail} --jobId #{@jobId} 2> #{stderrFileForProgram}"
    else
      cmd = "removeRedundantReads.rb -i #{CGI.escape(tempFile)} -f #{@fileType} -o #{CGI.escape(tempFile)}_sorted --userEmail #{@userEmail} --jobId #{@jobId} 2 > #{stderrFileForProgram}"
    end
    $stderr.puts "cmd to run: #{cmd}"
    exitStatus = system(cmd)
    # Check if the sub script ran successfully
    if(!exitStatus)
      # Sub script failed
      # read the stderr and send an error report via email
      @jobId = "Unknown Job Id" if(!@jobId)
      remRedErr = File.read(stderrFileForProgram)
      @emailMessage = "There was a problem in sorting and removing redundant reads"
      raise remRedErr
    end
    # next call the signalCoverage tool program
    stderrFileForProgram = "#{@scratchDir}/#{Time.now.to_f}.coverage.rb.err"
    wigFile = "#{@scratchDir}/#{Time.now.to_f}.wig"
    if(!@useScore)
      cmd = "coverage.rb -i #{CGI.escape(tempFile)}_sorted -o #{wigFile} -t #{@outputTrackName} -f #{@fileType} --userEmail #{@userEmail} --jobId #{@jobId} 2> #{stderrFileForProgram}"
    else
      cmd = "coverage.rb -i #{CGI.escape(tempFile)}_sorted -o #{wigFile} -t #{@outputTrackName} -f #{@fileType} --userEmail #{@userEmail} --useScore --jobId #{@jobId} 2> #{stderrFileForProgram}"
    end
    $stderr.puts "cmd to run: #{cmd}"
    exitStatus = system(cmd)
    # Check if the sub script ran successfully
    if(!exitStatus)
      # Sub script failed
      # read the stderr and send an error report via email
      @jobId = "Unknown Job Id" if(!@jobId)
      covErr = File.read(stderrFileForProgram)
      @emailMessage = "There was a problem in computing coverage."
      raise covErr
    end
    # Finally upload the wig file into Genboree as a high density track
    outputUri = URI.parse(@outUri)
    rsrcPath = outputUri.path
    rsrcPath << "?gbKey=#{@dbApiHelper.extractGbKey(@outUri)}" if(@dbApiHelper.extractGbKey(@outUri))
    apiCaller = WrapperApiCaller.new(outputUri.host, rsrcPath, @userId)
    apiCaller.get()
    resp = JSON.parse(apiCaller.respBody)
    uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
    uploadAnnosObj.refSeqId = resp['data']['refSeqId']
    uploadAnnosObj.groupName = @grpApiHelper.extractName(@outUri)
    uploadAnnosObj.userId = @userId
    uploadAnnosObj.jobId = @jobId
    uploadAnnosObj.trackName = @outputTrackName
    uploadAnnosObj.outputs = [@outUri]
    begin
      uploadAnnosObj.uploadWig(CGI.escape(File.expand_path(wigFile)), false)
    rescue => uploadErr
      $stderr.puts "Error: #{uploadErr}"
      $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
      @errUserMsg = "FATAL ERROR: Could not upload result wig file to target database."
      if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
        @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
      end
      raise @errUserMsg
    end
  end

  def addToolTitle(jsonObj)
    @toolTitle = @toolConf.getSetting('ui', 'label')
    @shortToolTitle = @toolConf.getSetting('ui', 'shortLabel')
    @shortToolTitle = @toolTitle if(@shortToolTitle !~ /\S/ or @shortToolTitle =~ /\[NOT SET\]/i)
    jsonObj['context']['toolTitle'] = @toolTitle
    return jsonObj
  end
  

  # parses the json input file
  # [+inputFile+] json file
  # [+returns+] nil
  def parseInputFile(inputFile)
    # get track name
    jsonObj = JSON.parse(File.read(inputFile))
    @toolIdStr = jsonObj['context']['toolIdStr']
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr)
    jsonObj = addToolTitle(jsonObj)
    @inputUri = jsonObj['inputs'][0]
    # Get output dir
    @outUri = jsonObj['outputs'][0]
    lffType = jsonObj['settings']['lffType']
    lffSubType = jsonObj['settings']['lffSubType']
    @outputTrackName = "#{lffType}:#{lffSubType}"
    if(!jsonObj['settings']['extendReadsValue'].empty?)
      @extendValue = jsonObj['settings']['extendReadsValue']
    else
      @extendValue = false
    end
    if(!jsonObj['settings']['truncateReadsValue'].empty?)
      @truncateValue =  jsonObj['settings']['truncateReadsValue']
    else
      @truncateValue = false
    end
    if(@inputUri !~ BRL::Genboree::REST::Helpers::TrackApiUriHelper::NAME_EXTRACTOR_REGEXP)
      @fileType = jsonObj['settings']['fileType']
    else
      @fileType = 'bed' # for downloading track as bed
    end
    @noStrand = jsonObj['settings']['noStrandForSorting']
    @useScore = jsonObj['settings']['useScore']
    @analysisName = jsonObj['settings']['analysisName']
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    dbrcKey = jsonObj['context']['apiDbrcKey']
    @userEmail = jsonObj['context']['userEmail']
    @adminEmail = jsonObj['context']['gbAdminEmail']
    @userId = jsonObj['context']['userId']
    @jobId = jsonObj['context']['jobId']
    @context = jsonObj['context']
    @settings = jsonObj['settings']
    dbrc = BRL::DB::DBRC.new(dbrcFile, dbrcKey)
    # get super user, pass and hostname
    @user = dbrc.user
    @pass = dbrc.password
    @host = dbrc.driver.split(/:/).last
    # get scratch dir
    @scratchDir = jsonObj['context']['scratchDir']
    @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(err)
    $stderr.puts "ERROR from coverageWrapper.rb:\n #{err}"
    $stderr.puts "ERROR Backtrace from coverageWrapper.rb:\n #{err.backtrace.join("\n")}"
    @emailMessage = err.message if(@emailMessage.nil? or @emailMessage.empty?)
    sendErrorEmail()
    exit(1)
  end

  def buildEmailBodyPrefix(msg)
    # defaults if things very very wrong (no json file even)
    userFirstName = 'User'
    userLastName = ''
    toolTitle = 'Coverage Computation'
    # use appropriate info from json file if available
    if(@context and @context.is_a?(Hash))
      userFirstName = @context['userFirstName'] if(@context['userFirstName'])
      userLastName = @context['userLastName'] if(@context['userLastName'])
      toolTiitle = @context['toolTitle'] if(@context['toolTitle'])
    end
    buff = ''
    buff << "\nHello #{userFirstName} #{userLastName},\n\n#{msg}\n\nJOB SUMMARY:\n"
    buff << <<-EOS
  JobID          : #{@jobId}
  Coverage Computation Settings :
  EOS
    if(@settings and @settings.is_a?(Hash))
      @settings.keys.sort{ |aa,bb| aa.downcase <=> bb.downcase}.each { |key|
        next if(NON_COVERAGE_SETTINGS.key?(key) or @settings[key].nil? or @settings[key].empty?) # nil and empty settings are skipped when making Spark properties file, so skip here too
        buff << "      #{key} : #{@settings[key]}\n"
      }
    else
      buff << "      [ Not Available Due to Error ]"
    end
    return buff
  end

  def sendEmail(emailTo, subject, body)
    self.class.sendEmail(emailTo, subject, body)
  end

  def self.sendEmail(emailTo, subject, body)
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    # Email to user
    if(!emailTo.nil?)
      emailer.addRecipient(emailTo)
      emailer.addRecipient(genbConfig.gbAdminEmail)
      emailer.setHeaders(genbConfig.gbFromAddress, emailTo, subject)
      emailer.setMailFrom(genbConfig.gbFromAddress)
      emailer.addHeader("Bcc: #{genbConfig.gbBccAddress}")
      body ||= "There was an unknown problem."
      emailer.setBody(body)
      emailer.send()
    end
  end

  def sendSuccessEmail()
    # Build message body
    buff = buildEmailBodyPrefix("Your #{@context['toolTitle']} job has completed successfully.")
    buff << "\nThe following track has been uploaded: \n #{@outputTrackName.inspect}\n\nThe Genboree Team"
    sendEmail(@userEmail, "GENBOREE NOTICE: Your #{@context['toolTitle']} completed", buff)
    $stderr.puts "STATUS: All Done"
  end

  # sends error email to recipients about the job status
  # [+returns+] no return value
  def sendErrorEmail()
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    @userEmail = genbConf.gbAdminEmail if(@userEmail.nil?)
    # EMAIL TO USER:
    # appropriate tool title
    if(@context and @context['toolTitle'])
      toolTitle = @context['toolTitle']
    else
      toolTitle = 'Coverage Computation'
    end
    # email body
    @emailMessage = "There was an unknown problem." if(@emailMessage.empty?)
    body = buildEmailBodyPrefix("Unfortunately your #{toolTitle} job has failed. Please contact the Genboree Team (#{genbConfig.gbAdminEmail}) with the error details for help with this problem.\n\nERROR DETAILS:\n\n#{@emailMessage}")
    body << "\n\n- The Genboree Team"
    # send email with subject and body
    sendEmail(@userEmail, "GENBOREE NOTICE: Your #{toolTitle} job failed", body)
  end


end




# Class for running the script and parsing args
class RunScript
  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This tool is a wrapper for computing coverage of a track in Genboree.
  Note that the track for which the coverage is to be computed MUST be a non high density track.
  The track is downloaded via the API in bed format and then converted to fixedStep wiggle format and finally
  uploaded into Genboree as a high Density track. The records of the final fixedStep file indicate the coverage
  for each window

  Notes: Intended to be called via the Genboree Workbench
    -j  --inputFile                     => input file in json format
    -v  --version                       => Version of the program
    -h  --help                          => Display help

  "
  def self.printUsage(additionalInfo=nil)
    puts DEFAULTUSAGEINFO
    puts additionalInfo unless(additionalInfo.nil?)
    if(additionalInfo.nil?)
      exit(0)
    else
      exit(15)
    end
  end

  def self.printVersion()
    puts VERSION_NUMBER
    exit(0)
  end

  def self.getDriver()
    return @@driver
  end

  def self.parseArgs()
    optsArray=[
      ['--inputFile','-j',GetoptLong::REQUIRED_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--help','-h',GetoptLong::NO_ARGUMENT]
    ]
    progOpts=GetoptLong.new(*optsArray)
    optsHash=progOpts.to_hash
    if(optsHash.key?('--help'))
      printUsage()
    elsif(optsHash.key?('--version'))
      printVersion()
    end
    printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    return optsHash
  end

  def self.performSignalCoverageWrapper(optsHash)
    sigCovWrapperObj = SignalCoverageWrapper.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performSignalCoverageWrapper(optsHash)
