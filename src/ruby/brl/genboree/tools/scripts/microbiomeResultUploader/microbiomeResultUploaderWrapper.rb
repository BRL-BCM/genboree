#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/util/emailer'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/helpers/expander'
require 'uri'
require 'json'
require 'brl/genboree/abstract/resources/user'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST


# Main Class
class MicrobiomeResultUploaderWrapper
  NON_MICROBIOME_RESULT_UPLOADER_SETTINGS = { 'clusterQueue' => true }
  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @jsonFile = optsHash['--inputFile']
    @emailMessage = ""
    @userEmail = nil
    @context = nil
    @jobId = nil
    begin
      @fileHelperObj = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      parseInputFile(@jsonFile)
      importArrayData()
      sendSuccessEmail()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end

  # Downloads ROI Track and array data file
  # Runs arrayDataImporter.rb
  # [+returns+] nil
  def importArrayData()
    # First make sure we have a valid key to make API calls
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    @dbu = BRL::Genboree::DBUtil.new(genbConfig.dbrcKey, nil, nil)
    @hostAuthMap = Abstraction::User.getHostAuthMapForUserId(@dbu, @userId)
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    if(@dbrcKey)
      dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
      # get super user, pass and hostname
      @user = dbrc.user
      @pass = dbrc.password
    else
      suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc(genbConfig, dbrcFile)
      @user = suDbDbrc.user
      @pass = suDbDbrc.password
    end
    dbHelperObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()

    # Download roi track
    getRoi()

    # Next get the array/probe file
    getArrayFile()

    # Check if we need to extract files (if file is an archive: tar.* or zip)
    # Our final goal in any case is to process all the content of the 'expandedFiles' dir
    # If the downloaded file IS the file to be processed then the 'expandedFiles' dir
    # will only contain that file. Otherwise it will have ONLY the extractes files
    fileList = []
    expander = BRL::Genboree::Helpers::Expander.new("expandedFiles/#{@fileName}")
    if(expander.isCompressed?)
      expanded = expander.extract('text')
      raise "FATAL ERROR: Could not extract array/probe file." if(!expanded)
      `rm expandedFiles/#{@fileName}` # We want to keep only the extracted files for easy processing
      Dir.entries("./expandedFiles").each { |file|
        next if(file == '.' or file == '..' or file =~ /\.tar/)
        fileList.push("expandedFiles/#{file}")
      }
    else
      fileList.push("expandedFiles/#{@fileName}")
    end

    # Call the core program for each of the extracted file
    @skippedHash = Hash.new { |hh,kk|
      hh[kk] = {}
    }
    @missingHash = Hash.new { |hh,kk|
      hh[kk] = {}
    }
    fileList.each { |file|
      `mkdir wigFiles`
      sampleReader = File.open(file)
      header = nil
      sampleSize = 0
      sampleIdxHash = {}
      sampleReader.each_line { |line|
        line.strip!
        next if(line.nil? or line.empty? or line =~ /^\s*$/)
        if(line =~ /^#/)
          fields = line.split(/\t/)
          raise "Header line does not have any sample columns." if(fields.size < 2)
          sampleSize = ( fields.size - 1 )
          fields.size.times { |ii|
            next if(ii == 0)
            sampleIdxHash[fields[ii]] = ( ii + 1 )
          }
          header = line
          break
        end
      }
      sampleReader.close()
      if(header.nil?) # No header line
        raise "Could not find header line"
      end
      # For each sample, call the core script
      sampleIdxHash.each_key { |sample|
        sampleIdx = sampleIdxHash[sample]
        # Generate the tmp score file
        inputFile = "#{CGI.escape(sample)}.txt"
        cutCmd = "cut -f1,#{sampleIdx} #{file} > #{inputFile}"
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Launching Command: #{cutCmd}")
        `#{cutCmd}`
        trkName = "#{sample}:#{@subtype}"
        wigFile = "#{CGI.escape(trkName)}.wig"
        cmd = "microbiomeResultUploader.rb -r roi.bed -a #{inputFile} -w #{CGI.escape(wigFile)} -S skippedProbes.txt -M missingProbes.txt -T #{CGI.escape(trkName)} 1>> microbiomeResultUploader.out 2>> microbiomeResultUploader.err"
        $stderr.debugPuts(__FILE__, __method__, "COMMAND", cmd)
        `#{cmd}`
        exitObj = $?.dup()
        if(exitObj.exitstatus != 0)
          errorStream = File.read("microbiomeResultUploader.err")
          @emailMessage = "#{errorStream}"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Command died: #{cmd}")
          raise @emailMessage
        end
        aliasUri = ApiCaller.applyDomainAliases(@dbUri)
        uri = URI.parse(aliasUri)
        host = uri.host
        rcscUri = uri.path
        trkRsrc = "#{rcscUri}/trk/#{CGI.escape(trkName)}?"
        trkRsrc << "gbKey=#{dbHelperObj.extractGbKey(@dbUri)}" if(dbHelperObj.extractGbKey(@dbUri))
        apiCaller = ApiCaller.new(host, trkRsrc, @hostAuthMap)
        apiCaller.put()

        # Upload track
        uploadRsrc = "#{rcscUri}/trk/#{CGI.escape(trkName)}/annos?format=wig&userId=#{@userId}"
        uploadRsrc << "&gbKey=#{dbHelperObj.extractGbKey(@dbUri)}" if(dbHelperObj.extractGbKey(@dbUri))
        apiCaller = ApiCaller.new(host, uploadRsrc, @hostAuthMap)
        apiCaller.put({}, File.open(wigFile))

        # Set the 'sampleName' attribute
        attrRsrc = "#{rcscUri}/trk/#{CGI.escape(trkName)}/attribute/sampleName/value?"
        attrRsrc << "gbKey=#{dbHelperObj.extractGbKey(@dbUri)}" if(dbHelperObj.extractGbKey(@dbUri))
        payload = { "data" => {"text" => sample } }
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "attrRsrc: #{attrRsrc.inspect}")
        apiCaller = ApiCaller.new(@host, attrRsrc, @hostAuthMap)
        apiCaller.put(payload.to_json)
        if(!apiCaller.succeeded?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Failed to set attribute")
        end

        $stderr.puts "file: #{file.inspect} processed."
        @skippedHash[File.basename(file)][sample] = File.read("skippedProbes.txt")
        @missingHash[File.basename(file)][sample] = File.read("missingProbes.txt")
      }
    }
    $stderr.puts "@skippedHash: #{@skippedHash.inspect}"
  end


  # Downloads ROI Track
  # [+returns+] nil
  def getRoi()
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Downloading roi Track: #{@roiTrack}")
    uri = URI.parse(@roiTrack)
    rcscPath = uri.path
    rcscPath << "/annos?format=bed&gbKey=#{@roiGbKey}"
    apiCaller = ApiCaller.new(uri.host, rcscPath, @hostAuthMap)
    ww = File.open("#{@scratchDir}/roi.bed", "w")
    apiCaller.get() {|chunk| ww.print chunk}
    if(!apiCaller.succeeded?)
      raise "'getting' roi track failed:\napiCaller respBody: #{apiCaller.respBody.inspect}"
    end
    ww.close()
    addEntrypoints() # Add the entrypoints/chrs (coming from the ROI db) to the target db if not already present
  end

  def addEntrypoints()
    uri = URI.parse(@dbApiHelper.extractPureUri(@arrayDb))
    host = uri.host
    rsrcPath = uri.path
    apiCaller = ApiCaller.new(host, "#{rsrcPath}/eps?gbKey=#{@roiGbKey}", @hostAuthMap)
    apiCaller.get()
    resp = apiCaller.parseRespBody()['data']['entrypoints']
    chrHash = {}
    targetUri = URI.parse(@dbUri)
    targetGbKey = nil
    targetGbKey = @dbApiHelper.extractGbKey(@dbUri) if(@dbApiHelper.extractGbKey(@dbUri))
    resp.each { |chr|
      chrName = chr['name']
      chrLength = chr['length'].to_i
      # Check if the chr is already there in the target db
      rsrcPath = "#{targetUri.path}/ep/#{CGI.escape(chrName)}?"
      rsrcPath << "gbKey=#{targetGbKey}" if(targetGbKey)
      apiCaller = ApiCaller.new(targetUri.host, rsrcPath, @hostAuthMap)
      apiCaller.get()
      # Not there, add it
      if(!apiCaller.succeeded?)
        payload = { "data" => {"name" => chrName, "length" => chrLength } }
        apiCaller.put(payload.to_json)
      end
    }
  end

  # Downloads array/probe file
  # [+retuns+] nil
  def getArrayFile()
    $stderr.puts "Downloading array file..."
    `mkdir expandedFiles`
    # Put the file in a new dir since it may be an archive of files and we will need to extract the archive before processing
    @fileName = CGI.escape(File.basename(@fileHelperObj.extractName(@arrayFile)))
    ww = File.open(@fileName, "w")
    aliasUri = ApiCaller.applyDomainAliases("#{@arrayFile}")
    uri = URI.parse(aliasUri)
    rcscUri = uri.path
    rcscUri = rcscUri.chomp("?")
    rcscUri << "/data?"
    rcscUri << "gbKey=#{@fileHelperObj.extractGbKey(aliasUri)}" if(@fileHelperObj.extractGbKey(aliasUri))
    apiCaller = ApiCaller.new(uri.host, rcscUri, @hostAuthMap)
    apiCaller.get() { |chunk| ww.print chunk}
    if(!apiCaller.succeeded?)
      raise "'getting' file: #{fileName.inspect} failed:\napiCaller respBody: #{apiCaller.respBody.inspect}"
    end
    ww.close
    `cp #{@fileName} expandedFiles`
  end

  # parses the json input file
  # [+inputFile+] json file
  # [+returns+] nil
  def parseInputFile(inputFile)
    jsonObj = JSON.parse(File.read(inputFile))
    @arrayFile = jsonObj['inputs'][0]
    @dbUri = jsonObj['outputs'][0]
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    @dbrcKey = jsonObj['context']['apiDbrcKey']
    @adminEmail = jsonObj['context']['gbAdminEmail']
    @userId = jsonObj['context']['userId']
    @jobId = jsonObj['context']['jobId']
    @context = jsonObj['context']
    @userEmail = jsonObj['context']['userEmail']
    @userLogin = jsonObj['context']['userLogin']
    @roiTrack = jsonObj['settings']['ROI']
    @arrayDb = jsonObj['settings']['arrayDb']
    @roiKey = jsonObj['settings']['roiKey']
    @subtype = jsonObj['settings']['subtype']
    @roiGbKey = jsonObj['settings']['roiGbKey']
    dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
    @user = dbrc.user
    @pass = dbrc.password
    @host = dbrc.driver.split(/:/).last
    @scratchDir = jsonObj['context']['scratchDir']
    @toolPrefix = jsonObj['context']['toolScriptPrefix']
    @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    $stderr.puts "ERROR:\n #{msg}"
    $stderr.puts "ERROR Backtrace:\n #{msg.backtrace.join("\n")}"
    @emailMessage = msg.to_s if(@emailMessage.nil? or @emailMessage.empty?)
    sendErrorEmail()
    exit(14)
  end

  def buildEmailBodyPrefix(msg)
    # defaults if things very very wrong (no json file even)
    userFirstName = 'User'
    userLastName = ''
    toolTitle = 'Microbiome Result Uploader'

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
  EOS
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
    buff << "\nThe following array/probe file has been imported: \n"
    buff << " #{CGI.unescape(File.basename(@arrayFile.chomp("?")))}\n"
    buff << "\nYou will get email notifications once the wig tracks(s) have been uploaded.\n\n"
    buff << "\n\nThe Genboree Team"
    probesSkipped = false
    @skippedHash.each_key { |key|
      @skippedHash[key].each_key { |sample|
        if(!@skippedHash[key][sample].empty?)
          probesSkipped = true
          break
        end
      }
    }
    unless(probesSkipped)
      @missingHash.each_key { |key|
        @missingHash[key].each_key { |sample|
          if(!@missingHash[key][sample].empty?)
            probesSkipped = true
            break
          end
        }
      }
    end
    if(probesSkipped)
      buff << "\n\nPlease note that some of the probes could not be processed due to the following errors:\n\n"
      @skippedHash.each_key { |key|
        @skippedHash[key].each_key { |sample|
          if(!@skippedHash[key][sample].empty?)
            buff << "Probes skipped due to Non-Numeric/Empty Scores (File: #{CGI.unescape(key)}; Sample: #{sample}):\n"
            buffIO = StringIO.new(@skippedHash[key][sample])
            buffIO.each_line { |line|
              buff << " #{line}"
            }
            buffIO.close()
          end
        }
      }
      @missingHash.each_key { |key|
        @missingHash[key].each_key { |sample|
          if(!@missingHash[key][sample].empty?)
            buff << "Probes skipped due to Unknown Names (File: #{CGI.unescape(key)}; Sample: #{sample}):\n"
            buffIO = StringIO.new(@missingHash[key][sample])
            buffIO.each_line { |line|
              buff << " #{line}"
            }
            buffIO.close()
          end
        }

      }
    end
    sendEmail(@userEmail, "GENBOREE NOTICE: Your #{@context['toolTitle']} completed", buff)
    $stderr.puts "STATUS: All Done"
  end

  # sends error email to recipients about the job status
  # [+returns+] no return value
  def sendErrorEmail()
    genbConf = ENV['GENB_CONFIG']
    @jobId = "Unknown Job Id" if(@jobId.nil?)
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    @userEmail = genbConfig.gbAdminEmail if(@userEmail.nil?)

    # EMAIL TO USER:
    # appropriate tool title
    if(@context and @context['toolTitle'])
      toolTitle = @context['toolTitle']
    else
      toolTitle = 'Microbiome Result Uploader'
    end

    # email body
    @emailMessage = "There was an unknown problem." if(@emailMessage.nil? or @emailMessage.empty?)
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

  Description: This tool is intended to used for uploading Microbiome results via the workbench.
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

  def self.runMicrobiomeResultUploaderWrapper(optsHash)
    microbiomeResultUploaderWrappererObj = MicrobiomeResultUploaderWrapper.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.runMicrobiomeResultUploaderWrapper(optsHash)
