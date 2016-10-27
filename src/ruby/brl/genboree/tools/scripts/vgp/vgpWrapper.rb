#!/usr/bin/env ruby

# Load libraries
require 'json'
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/dbUtil'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/resources/track'
ENV['DBRC_FILE']

class VGPWrapper
  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @jobId = nil
    @context = nil
    @genbConf = nil
    @userEmail = nil
    @vgpParams = nil
    @trackApiHelper = nil
    @emailMessage = ""
    @chromFile = ""
    @segmentsFile = ""
    @paramFile = ""
    @jsonFile = optsHash['--inputFile']

    begin
      # Read the JSON job file
      parseInputFile(@jsonFile)

      # Download data via API Call
      @lffFiles = writeAnnotationsToDisk(@context['scratchDir'], @inputs, @vgpParams)

      # Upconvert from BED to LFF

      # Perform remaining VGP Coordinator tasks
      @chromFile = createChromDefFile(@context['scratchDir'], @vgpParams['entryPoints'])
      @segmentsFile = createSegmentsLffFile(@context['scratchDir'], @vgpParams['segments']) unless @vgpParams['segments'].nil?()
      @paramFile = createParamFile(@context['scratchDir'], @vgpParams)

      # Run VGP
      executeVGP(@paramFile, @context['scratchDir'])

      # Clean up/copy to final dest
      sendSuccessEmail()
    rescue => err
      displayErrorMsgAndExit(err)
    end
  end 

  def parseInputFile(inputFile)
    jsonObj = JSON.parse(File.read(inputFile))
    @inputs = jsonObj['inputs']
    @context = jsonObj['context']
    @userId = jsonObj['context']['userId']
    @jobId = jsonObj['context']['jobId']
    @adminEmail = jsonObj['context']['gbAdminEmail']
    @userEmail = jsonObj['context']['userEmail']
    @vgpParams = jsonObj['context']['vgpParams']
    @dbuKey = jsonObj['settings']['dbuKey']
    @genbConf = BRL::Genboree::GenboreeConfig.load(jsonObj['context']['gbConfFile'])

    # Setup our track api helper
    dbu = BRL::Genboree::DBUtil.new(@dbuKey, nil, nil)
    @trackApiHelper = BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(dbu, @genbConf)

    # Do some basic error checking -
    # Ensure the vgp params were passed to us
    raise ArgumentError.new('No VGP Parameters were found in the passed jobFile context') if(@vgpParams.nil?())

    # Ensure we have entry point
    raise ArgumentError.new('No entry points were specified for drawing') if(@vgpParams['entryPoints'].nil?() or @vgpParams['entryPoints'].empty?())

    # Make sure we have tracks to draw also
    raise ArgumentError.new('No tracks were specified to be drawn') if(@inputs.nil?() or @inputs.empty?())

    # Make sure at least one figure should be drawn also
    raise ArgumentError.new('No figures were specified to be drawn') if(@vgpParams['genomeView'].nil?() and @vgpParams['chromosomeView'].nil?())
  end

  def determineResolution(params)
    length = -1
    heightPx = -1

    # First determine our largest EP
    params['entryPoints'].each { |ep| length = ep['length'] if(ep['length'] > length) }
    
    # Error check our length
    raise RuntimeError.new('The length of the largest Entry Point could not be determined!') if(length == -1)

    # Set number of pixels we have to draw on (vertically), dependant on the type of figure being produced
    if(!params['genomeView'].nil?())
      heightPx = params['genomeView']['height'] || 768
    elsif(!params['chromosomeView'].nil?())
      heightPx = params['chromosomeView']['height'] || 600
    end
      
    # Error check our drawing height
    raise RuntimeError.new('No appropriate figure specified for drawing (genome view or chromosome view)!') if(heightPx == -1)

    # All our values are valid, calculate a resolution
    return (length.to_f() / heightPx.to_f()).floor()
  end

  def writeAnnotationsToDisk(scratchDir, inputs, vgpParams)
    resolution = -1
    apiCaller = nil
    annotFile = nil
    lffFiles = Array.new()

    # Determine landmarks string from eps (ignore segments here as that will get handled in the culling stage of VGP)
    landmarks = vgpParams['entryPoints'].map { |ep| ep['name'] }

    # We need to also attempt to get credentials to contact the REST API and construct ApiCaller
    begin 
      #dbrcFile = File.expand_path(ENV['DBRC_FILE'])
      # NOTE: On genboreeproto, for some reason Apache is not properly passing DBRC_FILE into the Ruby environment,
      #     : because the ENV['DBRC_FILE'] paradigm is used so heavily in other wrappers, I assume it is setup 
      #     : properly on other machines, here it is hardcoded for development purposes only and in deployment 
      #     : the commented line above should be used
      dbrcFile = '/usr/local/brl/local/apache/ruby/conf/apache/.dbrc'
      dbrcKey = @context['apiDbrcKey']
      dbrc = BRL::DB::DBRC.new(dbrcFile, dbrcKey)
      user = dbrc.user
      pass = dbrc.password
      host = dbrc.driver.split(/:/).last()

      apiCaller = ApiCaller.new(host, '', user, pass)
    rescue => error
      raise RuntimeError.new("There was an error attempting to read the .dbrc file for REST credentials: #{$!}")
    end

    # Next, go through the tracks, get them from the API, if they are HDHV get annotations using resolution (span), if not, get them without
    inputs.each { |trk|
      # We need to pull off the REST URI to make the next call to for the data
      # TODO: Look to see if there is a helper method to do this, there likely is...
      trackMatches = trk.match(%r{^http://[^/]+(/REST/v\d+/grp/[^/]+/db/[^/]+/trk/[^/\?]+)})
      next if(trackMatches.nil?() or trackMatches.captures().empty?()) # This doesnt appear to be a track URI, skip...

      annotUri = '' 
      trackUri = trackMatches.captures().first()
      trackName = CGI.escape(@trackApiHelper.extractName(trk))

      if(@trackApiHelper.isHdhv?(trk))
        # Determine resolution (span) by res = floor(BP / pixel)
        # NOTE: The BP to use to calc resolution will be the largest base pairs
        #     : specified for drawing. This is how VGP operates, everything is 
        #     : scaled to the largest entry point in the set. This is good in that we will
        #     : have a constant resolution for all tracks and entry points drawn
        resolution = determineResolution(@vgpParams) if(resolution == -1) # Lazy load our resolution
        
        annotUri = "#{trackUri}/annos?span=#{resolution}&landmarki=#{landmarks.join(',')}&format=bedGraph"
        annotFile = File.new(File.join(scratchDir, "#{trackName}.wig"), "w")
      else
        annotUri = "#{trackUri}/annos?landmark=#{landmarks.join(',')}&format=lff"
        annotFile = File.new(File.join(scratchDir, "#{trackName}.lff"), "w")
      end
      
      $stdout.puts("[#{trackName}] => #{annotUri}")
      lffFiles << annotFile.path()

      apiCaller.setRsrcPath(annotUri)
      apiCaller.get() { |buffer|
        annotFile << buffer
      }

      annotFile.close()
    }

    return lffFiles
  end

  ###############################################################################
  # The +createChromDefFile+ method will create the required 3-column formatted
  # chromosomes definitions file. This file informs VGP which Entry Points are to
  # be drawn and their lengths. MFS (BNI)
  # NOTE: Originally from vgpCoordinator.rb
  #
  # * Arguments :
  #  - +String+ -> The path where the chromosome definitions file should be saved
  #  - +Hash+ -> A hash representing which entry points should be drawn
  ###############################################################################
  def createChromDefFile(chromFilePath, entryPoints)
    begin
      $stdout.puts("[createChromDefFile] Creating chromosome definitions file (#{File.join(chromFilePath, 'chromosomes.das')})...")
      chromFile = File.new(File.join(chromFilePath, 'chromosomes.das'), 'w')
      entryPoints.each { |ep|
        chromFile.puts("#{ep["name"]}\tChromosome\t#{ep["length"]}")
      }
      chromFile.close
      $stdout.puts('[createChromDefFile] Finished creating chromosome definitions file...')
    rescue => e
      raise RuntimeError.new("There was an error creating the chromosomes definition file: #{e}")
    end

    return File.join(chromFilePath, 'chromosomes.das')
  end
   
  ###############################################################################
  # The +createLffFile+ method will gather all the annotation for the desired
  # annotation tracks and store them in the specified file. The annotation is
  # gathered by invoking the +AnnotationDownloader+ Java application. This
  # application must be in the path and executable. MFS (BNI)
  # NOTE: Originally from vgpCoordinator.rb
  #
  # * Arguments :
  #  - +String+ -> The path where the annotation LFF file should be written to
  #  - +Hash+ -> A hash representing the tracks to be drawn in the image, this
  #             can technically be blank and VGP will run
  #  - +Hash+ -> The configuration hash that contains the userId, rseqId, etc
  #  - +String+ -> The optional path where stderr can be redirected to for
  #                troubleshooting, if left blank no redirection will occur
  ###############################################################################
  def createSegmentsLffFile(segsFilePath, segments)
    begin
      $stdout.puts("[createSegmentsLffFile] Creating Segments LFF File (#{File.join(segsFilePath, 'segments.lff')})...")

      # Write our data to the file
      segsLffFile = File.new(File.join(segsFilePath, 'segments.lff'), 'w')
      segments.each { |entryPoint|
        epName = entryPoint.keys.first
        entryPoint[epName].sort! { |a, b| a["start"] <=> b["start"] } if entryPoint["segOrder"] == "startOrder"
        entryPoint[epName].each_with_index { |seg, index|
          segsLffFile.puts("EP Segment\t#{epName}_seg_#{index + 1}\tEntryPoint\tSegment\t#{epName}\t#{seg["start"]}\t#{seg["end"]}\t\t\t\t\t\t")
        }
      }
      segsLffFile.close()

      $stdout.puts('[createSegmentsLffFile] Finished creating Segments LFF File...')
    rescue => e
      raise RuntimeError.new("There was an error creating the Segments LFF file: #{e}")
    end

    return File.join(segsFilePath, 'segments.lff')
  end

  ###############################################################################
  # The +createParamFile+ method will add the final VGP specific options and
  # write then VGP options to a JSON formatted parameter file. MFS (BNI)
  # NOTE: Originally from vgpCoordinator.rb
  #
  # * Arguments :
  #  - +String+ -> The path where the VGP parameter file should be written to
  #  - +Hash+ -> A hash representing all the options, non-VGP parameters will
  #              be removed from the hash before it is writeen to the disk
  ###############################################################################
  def createParamFile(paramFilePath, paramOptions)
    begin
      $stdout.puts("[createParamFile] Creating parameters file for VGP (#{File.join(paramFilePath, 'vgpParameters.json')})...")
      paramFile = File.new(File.join(paramFilePath, 'vgpParameters.json'), 'w')

      # Remove hash values that are not param file options
      paramOptions.delete("entryPoints")
      paramOptions.delete("segments")
      paramOptions.delete("config")

      # Set final options - location of LFF file, chrDef and the output directory
      paramOptions["outputFormat"] = "png"
      paramOptions["epSegmentsFile"] = @segmentsFile if paramOptions["epSegmentsFile"].nil? && !@segmentsFile.empty?
      paramOptions["chrDefinitionFile"] = @chromFile if paramOptions["chDefinitionFile"].nil?
      paramOptions["outputDirectory"] = File.join(@context['scratchDir'], 'results') if paramOptions["outputDirectory"].nil?
      paramOptions["lffFiles"] = @lffFiles if paramOptions["lffFiles"].nil?

      # Write our param file to disk
      paramFile.puts(JSON.pretty_generate(paramOptions))
      paramFile.close()
      $stdout.puts('[createParamFile] Finished creating parameters file for VGP...')
    rescue => e
      raise RuntimeError.new("There was an error creating the parameter file: #{e}")
    end

    return File.join(paramFilePath, 'vgpParameters.json')
  end

  def executeVGP(paramFilePath, logPath)
    begin
      command = "vgp.rb -p #{paramFilePath}"
      command << " >#{File.join(logPath, 'vgp')}.out 2>#{File.join(logPath, 'vgp')}.err" unless logPath.empty?
      $stdout.puts("[executeVGP] Executing VGP...")
      $stdout.puts("VGP exec = '#{command}'")
      system(command)

      # TODO: Here is where we would copy to the final destination, clean up and create compressed packages of files, etc
    rescue => e
      raise RuntimeError.new("There was an error executing the VGP binary: #{e}")
    end
  end

  #####################################
  # Utility Methods
  #####################################

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
    toolTitle = 'Virtual Genome Painter (VGP)'

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
    buff << "\nVGP has successfully drawn your specified images of the annotations in the following tracks: \n"
    @inputs.each { |trk|
      trackName = @trackApiHelper.extractName(trk)
      buff << "#{trackName}\n"
    }
    buff << "\n\nThe Genboree Team"
    sendEmail(@userEmail, "GENBOREE NOTICE: Your #{@context['toolTitle']} completed", buff)
    $stderr.puts "STATUS: All Done"
  end

  # sends error email to recipients about the job status
  # [+returns+] no return value
  def sendErrorEmail()
    @jobId = "Unknown Job Id" if(@jobId.nil?)
    @userEmail = @genbConf.gbAdminEmail if(@userEmail.nil?)

    # EMAIL TO USER:
    # appropriate tool title
    if(@context and @context['toolTitle'])
      toolTitle = @context['toolTitle']
    else
      toolTitle = 'Tabbed File Viewer - Annotation Uploader'
    end

    # email body
    @emailMessage = "There was an unknown problem." if(@emailMessage.nil? or @emailMessage.empty?)
    prefix = "Unfortunately your #{toolTitle} job has failed. Please contact the Genboree Team (#{@genbConf.gbAdminEmail}) "
    prefix << "with the error details for help with this problem.\n\nERROR DETAILS:\n\n#{@emailMessage}"
    body = buildEmailBodyPrefix(prefix)
    body << "\n\n- The Genboree Team"

    # send email with subject and body
    sendEmail(@userEmail, "GENBOREE NOTICE: Your #{toolTitle} job failed", body)
  end
end

# Class for running the script and parsing args
class RunScript
  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="
  
  Author: Michael Smith (BNI)
  
  Description: This tool will process specified data tracks and run the Virtual Genome Painter (VGP) to produce desired output images, it is to be lanched via the workbench 
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

  def self.runVGP(optsHash)
    uploadObj = VGPWrapper.new(optsHash)
  end
end

optsHash = RunScript.parseArgs()
RunScript.runVGP(optsHash)
