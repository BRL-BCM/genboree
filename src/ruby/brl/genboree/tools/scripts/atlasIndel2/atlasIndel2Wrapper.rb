#!/usr/bin/env ruby

# Load libraries
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
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/tools/scripts/uploadTrackAnnos/uploadTrackAnnosWrapper'
require 'brl/genboree/helpers/expander'
require 'brl/util/convertText'
require 'brl/util/samTools'
require 'brl/util/vcfParser'
require 'uri'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

# Driver Class
class DriveAtlasIndel2
  NON_ATLASINDEL2_SETTINGS = { 'clusterQueue' => true }
  MAX_OUT_BUFFER = 1024 * 1024 * 4

  # Constructor
  # [+optsHash+] command line args
  # [+returns+] nil
  def initialize(optsHash)
    @jsonFile = optsHash['--inputFile']
    @emailMessage = ""
    @userEmail = nil
    @context = nil
    @jobId = nil
    @origFileBaseName = nil
    begin
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      @grpApiHelper = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new()
      # Parse the input json file
      parseInputFile(@jsonFile)
      # Run Atlas-SNP2.rb program
      runAtlasIndel2()
      # Prepares lff file:
      prepLff()
      # Transfer .vcf., .snp and .lff files to target
      transferFiles()
      # Uploads lff file as track in Genboree (if required)
      uploadLff() if(@uploadIndelTrack)
      # Send Email to User with success notification
      sendSuccessEmail()
    rescue Exception => err
      # Also sends out Failure email to user
      displayErrorMsgAndExit(err)
    end
  end

  # Downloads inputs files and runs the Atlas-SNP2 program
  # [+returns+] nil
  def runAtlasIndel2()
    filehelperObj = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
    dbHelperObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
    # First check if we have the reference fasta sequence for the tool
    dirFound = File.directory?(@fastaDir)
    if(!dirFound)
      @emailMessage = "The reference Fasta sequence file for genome: #{@refGenome} could not be found."
      raise @emailMessage
    end
    # Download the sam/bam file
    uri = URI.parse(@input)
    rcscUri = uri.path
    rcscUri = rcscUri.chomp("?")
    rcscUri << "/data?"
    rcscUri << "gbKey=#{@dbApiHelper.extractGbKey(@input)}" if(@dbApiHelper.extractGbKey(@input))
    @inputFileName = CGI.escape(File.basename(filehelperObj.extractName(@input)))
    fileWriter = File.open(@inputFileName, "w")
    uri = URI.parse(@input)
    apiCaller = WrapperApiCaller.new(uri.host, rcscUri, @userId)
    $stderr.puts "Downloading bam/sam file: #{@inputFileName}"
    writeBuff = ''
    apiCaller.get() { |chunk|
      writeBuff << chunk
      if(writeBuff.size >= MAX_OUT_BUFFER)
        fileWriter.print(writeBuff)
        writeBuff = ''
      end
    }
    if(!apiCaller.succeeded?)
      @emailMessage = "Failed to download file: #{CGI.unescape(@inputFileName)}"
      raise "Failed to download file: #{CGI.unescape(@inputFileName)}.\nDetails:\n#{apiCaller.respBody.inspect}"
    end
    if(!writeBuff.empty?)
      fileWriter.print(writeBuff)
      writeBuff = ''
    end
    fileWriter.close()
    # If the file is a sam file, we need to expand it and convert it to unix format and finally convert that into a bam file
    bamFile = @inputFileName !~ /\.bam$/i ? prepSamFile(@inputFileName) : @inputFileName.dup()
    # Once we get the bam file, we check if sorting is required or not
    preppedFile = BRL::Util::SamTools.isBamSorted?(bamFile) ? bamFile.dup() : sortBamFile(bamFile)
    # We need to get the fref records for preparing the bam file
    dbu = BRL::Genboree::DBUtil.new(@dbuDBRCKey, nil, nil)
    dbHelpObj = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(dbu, nil)
    refSeqRec = dbHelpObj.tableRow(@output)
    if(refSeqRec.nil?) # probably the ROI track repo is missing
      @emailMessage = "Problem accessing the fref records from the target database"
      raise @emailMessage
    end
    dbu.setNewDataDb(refSeqRec['databaseName'])
    frefHash = {}
    allFrefRecords = dbu.selectAllRefNames()
    allFrefRecords.each { |record|
      frefHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i] if(!frefHash.has_key?(record['refName']))
    }

    # Comment out the lines below sinec Atlas-Indel2.rb has been fixed:

    # Get the final bam file after extracting records that pertain to only those chrs that come from fref.
    # Run Atlas_indel2.rbon THAT .bam file
    #cmd = "module load atlastools; samtools index #{preppedFile}; samtools view -b #{preppedFile} "
    #frefHash.each_key { |chr|
    #  cmd << " #{chr} #{chr.gsub("chr", "")} "
    #}

    if(@inputFileName !~ /\.bam$/i)
      @inputFileName.gsub!(/\.sam(?:\.[^\.]+)?/i, "")
    else
      @inputFileName.gsub!(/\.bam(?:\.[^\.]+)?/i, "")
    end
    cmd = "module load atlastools; samtools index #{preppedFile}; "
    cmd << " Atlas-Indel2.rb -b #{preppedFile} -r #{@fastaDir}/#{@refGenome}.fa -o #{@scratchDir}/#{@inputFileName}.vcf "
    if(@platformType == "illumina")
      cmd << " -I "
    else
      cmd << " -S "
    end
    cmd << " -s #{CGI.escape(@sampleName)} -p #{@zCutOff} -t #{@minTotalDepth} -m #{@minVarReads} -v #{@minVarRatio} -P #{@z1bpCutOff} -h #{@homoVarCutOff}"
    cmd << " -f " if(@strandDirFilter)
    cmd << "> #{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.vcf.stdout 2> #{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.vcf.stderr"
    $stderr.puts "Launching Command: #{cmd.inspect}"
    exitStatus = system(cmd)
    statusObj = $?.dup()
    if(!exitStatus)
      stderrStream = File.read("#{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.vcf.stderr")
      stdoutStream = File.read("#{@scratchDir}/#{CGI.escape(@sampleName)}.#{@platformType}.vcf.stdout")
      @emailMessage = "Failed to run: Atlas-Indel2.rb.\n Stderr:\n#{stderrStream}\nStdout:\n#{stdoutStream}\n"
      raise "Atlas-Indel2.rb failed with status: #{statusObj.inspect}.\nCommand: #{cmd.inspect}"
    end
    # Compress the bam.bai file
    cmd = "zip #{preppedFile}.bai.zip #{preppedFile}.bai"
    exitStatus = system(cmd)
    statusObj = $?.dup()
    if(!exitStatus)
      $stderr.puts "ERROR: Failed to zip file: #{preppedFile}.bai\nExitStatus: #{statusObj.inspect}\nCommand: #{cmd.inspect} "
    end
    # remove the original .bai file
    cmd = "rm #{preppedFile}.bai"
    exitStatus = system(cmd)
    statusObj = $?.dup()
    if(!exitStatus)
      $stderr.puts "ERROR: Failed to rm file: #{preppedFile}.bai\nExitStatus: #{statusObj.inspect}\nCommand: #{cmd.inspect} "
    end
    `rm -f #{@inputFileName} #{preppedFile}`
  end

  # Sortes bam file
  # [+bamFile+]
  # [+returns+] preppedFile
  def sortBamFile(bamFile)
    preppedFile = nil
    begin
      BRL::Util::SamTools.sortBam(bamFile)
      preppedFile = "#{bamFile.gsub(".bam", ".sorted")}.bam"
    rescue => err
      raise err
    end
    return preppedFile
  end

  # Preps downloaded Sam file:
  # expands it and converts it to unix format
  # Finally converts it into a sorted bam file
  # [+samFile+]
  # [+returns+] bamFile
  def prepSamFile(samFile)
    $stderr.puts "Prepping SAM file..."
    # Uncompress the file if its zipped
    expanderObj = BRL::Genboree::Helpers::Expander.new(samFile)
    expanderObj.extract(desiredType = 'text')
    fullPathToUncompFile = expanderObj.uncompressedFileName
    # Convert to unix format:
    convertObj = BRL::Util::ConvertText.new(fullPathToUncompFile)
    convertObj.convertText(:all2unix)
    preppedFile = convertObj.convertedFileName
    # Convert it into a sorted bam file
    bamFile = preppedFile.gsub(".2unix", ".bam")
    begin
      BRL::Util::SamTools.sam2bam(preppedFile, bamFile, false)
    rescue => err
      raise err
    end
    return bamFile
  end

  # Transfer output files to target
  # [+returns+] nil
  def transferFiles()
    uri = URI.parse(@output)
    host = uri.host
    rcscUri = uri.path
    rcscUri = rcscUri.chomp("?")
    rcscUri << "/file/#{CGI.escape("Atlas2 Suite Results")}/#{CGI.escape(@studyName)}/Atlas-Indel2/#{CGI.escape(@jobName)}/"
    # Transfer files:
    files = [@vcfFile, @lffFile]
    # gzip the files
    compressedFiles = []
    files.each { |file|
      cmd = "zip #{file}.zip #{file}"
      exitStatus = system(cmd)
      exitObj = $?.dup()
      if(!exitStatus)
        @emailMessage = "Could not compress file: #{file.inspect}"
        raise "gzip cmd failed.\nExit Status: #{exitObj.inspect}\nCommand: #{cmd.inspect}"
      end
      if(File.exists?("#{file}.zip"))
        compressedFiles.push("#{file}.zip")
        `rm -f #{file}`
      end
    }

    compressedFiles.each { |file|
      fileUri = rcscUri.dup()
      fileUri << "#{File.basename(file)}/data?"
      fileUri << "gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
      apiCaller = WrapperApiCaller.new(host, fileUri, @userId)
      $stderr.puts "Transferring file: #{File.basename(file)}"
      apiCaller.put({}, File.open(file))
      if(!apiCaller.succeeded?)
        @emailMessage = "Failed to transfer file: #{File.basename(file)} to target."
        raise "Failed to transfer file: #{File.basename(file)} to target.\nDetails: \n#{apiCaller.respBody.inspect}"
      else # Delete file from disk
        `rm -f #{file}` if(file !~ /\.lff/)
      end
    }
  end


  # Uploads Lff File as a track
  # [+returns+] nil
   def uploadLff()
    @uploadFailed = false
    uri = URI.parse(@output)
    host = uri.host
    rcscUri = uri.path.chomp("?")
    # First create the empty track
    rcscUri << "/trk/#{@trackName}?"
    rcscUri << "gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
    apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
    apiCaller.put()
    if(apiCaller.succeeded?) # OK, set the default display
      payload = { "data" => { "text" => "Expand with Names" } }
      rcscUri.chomp!("?")
      rcscUri << "/defaultDisplay?"
      rcscUri << "gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
      apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
      apiCaller.put(payload.to_json)
      $stderr.puts "Setting the default display for track: #{@trackName} failed (rcscUri: #{rcscUri.inspect}): #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
      # Set the default color
      rcscUri.gsub!("/defaultDisplay?", "/defaultColor?")
      apiCaller = WrapperApiCaller.new(host, rcscUri, @userId)
      payload = { "data" => { "text" => "#ff0000" } }
      apiCaller.put(payload.to_json)
      $stderr.puts "Setting the default color for track: #{@trackName} failed (rcscUri: #{rcscUri.inspect}): #{apiCaller.respBody.inspect}" if(!apiCaller.succeeded?)
    else # Failed
      $stderr.puts "Creating the empty track: #{@trackName} failed (Track already exists?) (rcscUri: #{rcscUri.inspect}): #{apiCaller.respBody.inspect}"
    end
    outputUri = URI.parse(@output)
    rsrcUri = outputUri.path
    rsrcUri << "?gbKey=#{@dbApiHelper.extractGbKey(@output)}" if(@dbApiHelper.extractGbKey(@output))
    apiCaller = WrapperApiCaller.new(outputUri.host, rsrcUri, @userId)
    apiCaller.get()
    resp = JSON.parse(apiCaller.respBody)
    uploadAnnosObj = BRL::Genboree::Tools::Scripts::UploadTrackAnnosWrapper.new()
    uploadAnnosObj.refSeqId = resp['data']['refSeqId']
    uploadAnnosObj.groupName = @groupName
    uploadAnnosObj.userId = @userId
    exp = BRL::Genboree::Helpers::Expander.new("#{File.basename(@lffFile)}.zip")
    exp.extract()
    begin
      uploadAnnosObj.uploadLff(CGI.escape(File.expand_path(exp.uncompressedFileList[0])), false)
      `rm -rf #{exp.uncompressedFileList[0]}`
    rescue => uploadErr
      $stderr.puts "Error: #{uploadErr}"
      $stderr.puts "Error Backtrace:\n\n#{uploadErr.backtrace.join("\n")}"
      @errUserMsg = "FATAL ERROR: Could not upload result lff file to target database."
      if(uploadAnnosObj.outFile and File.exists?(uploadAnnosObj.outFile))
        @errUserMsg << "\n\n#{File.read(uploadAnnosObj.outFile)}"
      end
      raise @errUserMsg
    end
  end


  # Creates an lff file from the .vcf file generated by Atlas-Indel2.rb program
  # [+returns+] nil
  def prepLff()
    $stderr.puts "Preparing LFF File..."
    @vcfFile = "#{@inputFileName}.vcf"
    vcfReader = File.open(@vcfFile)
    @lffFile = "#{@inputFileName}.lff"
    lffWriter = File.open(@lffFile, "w")
    buff = ''
    vcfObj = nil
    vcfReader.each_line { |line|
      if(line =~ /^#(?!#)/) # Column Header
        # Init vcfParser
        vcfObj = BRL::Util::VcfParser.new(line, nil)
        break
      end
    }

    # Go through the vcf file and create a lff record for each record in the file
    vcfReader.each_line { |line|
      line.strip!
      next if(line.nil? or line =~ /^#/ or line =~ /^\s*$/ or line.empty?)
      vcfObj.parseLine(line)
      buff << vcfObj.makeLFF("Atlas Tool Suite", @lffType, @lffSubType)
      if(buff.size >= MAX_OUT_BUFFER)
        lffWriter.print(buff)
        buff = ''
      end
      vcfObj.deleteNonCoreKeys
    }
    if(!buff.empty?)
      lffWriter.print(buff)
      buff = ''
    end
    # Close all file handlers
    vcfReader.close()
    lffWriter.close()
  end
  
  def addToolTitle(jsonObj)
    jsonObj['context']['toolTitle'] = @toolConf.getSetting('ui', 'label')
    return jsonObj
  end

  # parses the json input file and sets up required instance variables
  # [+inputFile+] json file
  # [+returns+] nil
  def parseInputFile(inputFile)
    jsonObj = JSON.parse(File.read(inputFile))
    
    # Get Input/Output
    @input = jsonObj['inputs'][0]
    @output = jsonObj['outputs'][0]
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    # Get Context Info:
    @toolIdStr = jsonObj['context']['toolIdStr']
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr)
    jsonObj = addToolTitle(jsonObj)
    @dbrcKey = jsonObj['context']['apiDbrcKey']
    @dbuDBRCKey = jsonObj['settings']['dbuDBRCKey']
    @adminEmail = jsonObj['context']['gbAdminEmail']
    @userId = jsonObj['context']['userId']
    @jobId = jsonObj['context']['jobId']
    @context = jsonObj['context']
    @userEmail = jsonObj['context']['userEmail']
    @userLogin = jsonObj['context']['userLogin']
    @scratchDir = jsonObj['context']['scratchDir']
    # Get Settings options
    @studyName = jsonObj['settings']['studyName']
    @jobName = jsonObj['settings']['jobName']
    @uploadIndelTrack = jsonObj['settings']['uploadIndelTrack']
    @trackName = jsonObj['settings']['trackName']
    @platformType = jsonObj['settings']['platformType']
    @zCutOff = jsonObj['settings']['zCutOff']
    @minTotalDepth = jsonObj['settings']['minTotalDepth']
    @minVarReads = jsonObj['settings']['minVarReads']
    @minVarRatio = jsonObj['settings']['minVarRatio']
    @strandDirFilter = jsonObj['settings']['strandDirFilter']
    @strandFilter = @strandDirFilter ? "true" : "false"
    @sampleName = jsonObj['settings']['sampleName']
    @fastaDir = jsonObj['settings']['fastaDir']
    @refGenome = jsonObj['settings']['refGenome']
    @lffType = jsonObj['settings']['lffType']
    @lffSubType = jsonObj['settings']['lffSubType']
    @z1bpCutOff = jsonObj['settings']['z1bpCutOff']
    @homoVarCutOff = jsonObj['settings']['homoVarCutOff']
    @trackName = CGI.escape("#{@lffType}:#{@lffSubType}") if(@uploadIndelTrack)
    @lffType = CGI.escape(@sampleName) unless(@lffType)
    @lffSubType = 'Indels' unless(@lffSubType)
    @groupName = @grpApiHelper.extractName(@output)
    # Get User, pass and host info:
    dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
    @user = dbrc.user
    @pass = dbrc.password
    @host = dbrc.driver.split(/:/).last
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
    toolTitle = 'Atlas-Indel2'

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
      Job Name       : #{@jobName}
      Study Name     : #{@studyName}
      Platform Type  : #{@platformType}
      Sample Name    : #{@sampleName}

            Advanced Settings:
      Z-CutOff                       : #{@zCutOff}
      Minimum Total Depth            : #{@minTotalDepth}
      Minimum Var Reads              : #{@minVarReads}
      Minimum Var Ratio              : #{@minVarRatio}
      Strand Dir Filter              : #{@strandFilter}

    EOS
    if(@uploadIndelTrack)
      buff << <<-EOS
        Indel Track Name    : #{@lffType}:#{@lffSubType}
      EOS
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
    buff << "\n\nThe Genboree Team"
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
      toolTitle = 'Atlas-Indel2'
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

  Description: This tool is intended to used for running the Atlas-Indel2.rb program from BCM-HGSC via the Genboree Workbench
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

  def self.performDriveAtlasIndel2(optsHash)
    driveAtlasIndel2Obj = DriveAtlasIndel2.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performDriveAtlasIndel2(optsHash)
