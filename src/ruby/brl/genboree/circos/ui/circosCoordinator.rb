#! /usr/bin/env ruby

########################################################################################
# Project: Circos UI Integration
#   This project creates a new User Interface (UI) to assist users in
#   creating parameter files for the Circos visualization program (v0.49).
#   The integration also creates a server-side support environment to create
#   necessary configuration files, queue a Circos job with the Genboree environment
#   and then package the Circos output files and notify the user of job completion.
#
# circosCoordinator.rb - This file coordinates all the necessary elements to create a run of Circos
#
# NOTE - This circos UI server side implementation is not meant to take an already created
#   circos configuration file. This implementation assumes defaults. If a user has a 
#   complete circos configuration file, they should make their desired changes to the file
#   and then manually run the circos binary. This is not meant to be a circos runner script.
#
# Arguments:
# -o, --options (REQUIRED) : A JSON formatted object representing the Circos options (for drawing and running)
# -d, --daemonize (OPTIONAL): Run the coordinator in a daemonized mode (default when called from web)
#
# Developed by Bio::Neos, Inc. (BIONEOS)
# under a software consulting contract for:
# Baylor College of Medicine (CLIENT)
# Copyright (c) 2009 CLIENT owns all rights.
# To contact BIONEOS, visit http://bioneos.com
########################################################################################

require 'rubygems'
require 'json'
require 'getoptlong'
require 'fileutils'
require 'logger'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/circos/configFile'
require 'brl/util/emailer'

# Declare required variables
@filesPrefix = ""
@statusString = ""
@currScratchSpace = ""
@karyotypeFilePath = ""
@paramFilePath = ""
@circosFinalResultsPath = ""
@options = Hash.new
@daemonize = false
@uniqueId = Time.now.to_i.to_s + "_#{rand(65525)}"
jsonString = ""
filePath = ""
debugLogPath = File.join("usr", "local", "brl", "data", "genboree", "temp", "circos", "circosCoordinator.debug")
classpath = ENV["CLASSPATH"]
if(classpath.empty?)
  classpath =  "/usr/local/brl/local/apache/htdocs/common/lib/servlet-api.jar:"
  classpath << "/usr/local/brl/local/apache/htdocs/common/lib/mysql-connector-java.jar:"
  classpath << "/usr/local/brl/local/apache/htdocs/common/lib/activation.jar:"
  classpath << "/usr/local/brl/local/apache/htdocs/common/lib/mail.jar:"
  classpath << "/usr/local/brl/local/apache/java-bin/WEB-INF/lib/GDASServlet.jar"
end

options = GetoptLong.new(
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
  ['--daemonize', '-d', GetoptLong::NO_ARGUMENT],
  ['--options', '-o', GetoptLong::REQUIRED_ARGUMENT],
  ['--file', '-f', GetoptLong::REQUIRED_ARGUMENT],
  ['--job', '-j', GetoptLong::REQUIRED_ARGUMENT],
  ['--log', '-l', GetoptLong::REQUIRED_ARGUMENT]
)

# Constants
AnnoDownloaderCmd = "java -classpath #{classpath} -Xmx1800M  org.genboree.downloader.AnnotationDownloader"

# Load our config file to access Genboree constants & declare VGP scratch directory and storage directory
@genbConf = BRL::Genboree::GenboreeConfig.load()
@hostname = ENV["HTTP_HOST"] or @genbConf.machineName
circosScratchBase = @genbConf.circosScratchBase
circosResultsBase = @genbConf.circosResultsBase

########################################################################################
# BEGIN Utility methods to create necessary runtime files and to initiate a run of VGP
########################################################################################

###############################################################################
# The +printUsage+ method will alert the user of the usage information for the
# vgpCoordinator. This is displayed when the user specifies the -h/--help
# arguments. MFS (BNI)
#
# * Arguments : none
###############################################################################
def printUsage()
  print <<USAGE
circosCoordinator usage:
ruby circosCoordinator.rb [OPTIONS]

OPTIONS:
  -h, --help      : Print this usage information
  -d, --daemonize : Run the coordinator as a Daemon, if an email address is provided in the options
                    then an email notification will be sent upon completion
  -o, --options   : Specify the options as a JSON formatted object (eg '{"config" : {"userId" : 1}}')
  -f, --file      : Read the options from a file containing the JSON formatted object
  -j, --job       : The desired Job ID for this Circos run, optional (eg '-j "123456_1"')

NOTE: A Circos JSON object is required! Either specified via -o <object> or -f <pathToFile>
USAGE
end

def createDataFiles(tracks, config, errFilePath="")
  begin
    lffFields = [:class, :name, :type, :subtype, :chrom, :start, :stop, :strand, :phase, :score, :tstart, :tstop, :avp, :sequence, :comments]
    @debugLog.debug("[createDataFiles] Gathering annotation and creating data files...")
    if(tracks.length == 0)
      @debugLog.warn("[createDataFiles] No annotation or banding tracks specified...")
      return 
    end
    
    # Circos draws all annotation in a specified data file, so each different track style
    # needs to be represented in its own data file. Here we determine which data files to
    # download and tell the tracks where they can expect the resulting data file.
    ###
    # First we check to ensure we are only generating one data file for that track/circos-type
    # combination. Then we store a file handle for that track/circos-type so in the next step
    # we can save all our necessary data without having to loop again over the tracks.
    # tracksToDownload --> trackName --> circos data type --> file handle to store circos formatted data
    # tracksToDownload[cyto:band][highlight][File<<prefix>.cytoband.highlight.txt>]
    links = Hash.new() { |h,k| h[k] = Array.new() }
    tracksToDownload = Hash.new() { |h, k| h[k] = Hash.new() { |hh, kk| hh[kk] = Array.new() } }

    tracks.each_pair { |trackName, trackInstances|
      trackInstances.each { |trackObj|
        annoFile = File.join(@currScratchSpace, "#{@filesPrefix}.#{trackName.gsub(":", "").gsub(" ", "").downcase()}")
        
        if(["scatter", "line", "histogram", "heatmap"].include?(trackObj["properties"]["type"]))
          # These are all reprsented by the plot catgory in Circos, name the data files appropriately
          unless(tracksToDownload[trackName].has_key?(:plot))
            tracksToDownload[trackName][:plot].push(File.new("#{annoFile}.plot.txt", "w"))
          end  
          trackObj["properties"]["file"] = "#{annoFile}.plot.txt"
        else
          # Highlights, links, cytoband (this is our madeup type)
          type = trackObj["properties"]["type"].to_sym
          path = "#{annoFile}.#{trackObj["properties"]["type"]}.txt"

          if(type == :link)
            # Links need special processing
            links[trackName].push(trackObj)
            linkedToTrack = trackObj["properties"]["linked_to"].gsub(":", "").gsub(" ", "").downcase()
            linkedBy = trackObj["properties"]["linked_by"].gsub(" ", "").downcase()
            
            # Update the path b/c our links need a special file name for better debuggin
            path = "#{annoFile}.#{linkedToTrack}.#{linkedBy}.link.txt"

            # Check to see if we are already getting link data in that format, for that linkedBy field,
            # there is no need to get the same data twice
            exists = false
            trackOnlyPath = "#{annoFile}.#{linkedBy}.link.txt"
            tracksToDownload[trackName][type].each { |linkFh|
              exists = true if(linkFh.path == trackOnlyPath)
            }
            tracksToDownload[trackName][type].push(File.new(trackOnlyPath, "w")) unless(exists)

            # Make sure our linkedTo track is in the queue to be downloaded.
            # If it is not in the queue already, add it. Otherwise, ignore
            linkedToExists = false
            linkedToPath = File.join(@currScratchSpace, "#{@filesPrefix}.#{linkedToTrack}.#{linkedBy}.link.txt")
            tracksToDownload[trackObj["properties"]["linked_to"]][type].each { |linkFh|
              linkedToExists = true if(linkFh.path == linkedToPath)
            }
            tracksToDownload[trackObj["properties"]["linked_to"]][type].push(File.new(linkedToPath, "w")) unless(linkedToExists)
          elsif(!tracksToDownload[trackName].has_key?(type))
            # All other types, just make sure we aren't already gathering that data in that format
            tracksToDownload[trackName][type].push(File.new(path, "w"))
          end
          
          # Always tell our track object where to find its annotation file
          trackObj["properties"]["file"] = path
        end
      }
    }

    # Now go ahead and download the annotation for each track, saving it to its own lff file. After the 
    # annotation is saved, we will transcode it to the proper Circos format for each track type.
    debugLine = "[createDataFiles] Annotation downloader command will be run for each track: "
    debugLine << "'#{AnnoDownloaderCmd} -b -c -u #{config["userId"]} -r '#{config["rseqId"]}' -m '<track_name>' > 'filePath.lff'"
    @debugLog.debug(debugLine)
    tracksToDownload.each_pair { |name, typesHash|
      tempLffPath = File.join(@currScratchSpace, "#{@filesPrefix}.#{name.gsub(":", "").gsub(" ", "").downcase()}.lff")
      command = "#{AnnoDownloaderCmd} -b -c -u #{config["userId"]} -r '#{config["rseqId"]}' -m '#{CGI.escape(name)}' > #{tempLffPath}"
      command << " 2>#{errFilePath}" unless errFilePath.empty?
      @debugLog.debug("[createDataFiles] Executing annotation downloader command for '#{CGI.escape(name)}'")
      system(command)

      # The annotation for this track should be downloaded to the temporary LFF file.
      # so now write the data to each type file, in the correct Circos data formats
      File.foreach(tempLffPath) { |annotation|
        annotation.strip!()
        annoValues = annotation.split("\t")
        next if annoValues.length < 7

        typesHash.each_pair { |type, fhs|
          if(type == :link)
            fhs.each { |linkFh|
              linkedValue = nil
              tempFileSplit = File.basename(linkFh.path).split(".")
              linkedBy = tempFileSplit[tempFileSplit.length - 3]
              if(lffFields.include?(linkedBy.to_sym))
                linkedValue = annoValues[lffFields.index(linkedBy.to_sym)]
              else
                linkedValue = getAnnotAvp(annotation)[linkedBy.to_sym]
              end
              
              # Because we might be using an AVP that can contain virtually anything, we need to 
              # separate values with a reserved character, ';' being the only one. That way we 
              # can use the sort command and tell it how to separate the columns. Otherwise we 
              # can't be guaranteed a value in the linkedValue won't break our sort.
              # TODO: Check to see if type or subtype can contain a ';'
              linkFh << "#{annoValues[2]}:#{annoValues[3]};#{annoValues[4]};#{annoValues[5]};#{annoValues[6]};#{linkedValue}\n" unless(linkedValue.nil?)
            }
          elsif(type == :band)
            # Just like with VGP, the bandType AVP must be present to properly color the band
            color = (!annoValues[12].nil? and annoValues[12] =~/bandType\s*=\s*(\S+)\s*;.*/i) ? $1 : "gpos50"
            
            # Always only one file handle for band type
            fhs.first << "band #{annoValues[4]} #{annoValues[1]} #{annoValues[1]} #{annoValues[5]} #{annoValues[6]} #{color}\n"
          else
            value = (type == :highlight or type == :tile) ? "" : annoValues[9]

            # Always only one file handle for all plots
            fhs.first << "#{annoValues[4]} #{annoValues[5]} #{annoValues[6]} #{value}\n"
          end
        }
      }

      # Should be done with these files, close them up
      typesHash.each_value { |fhs| fhs.each { |fh| fh.close() } }
    }
      
    # Now handle our links in a special manner
    # NOTE: Because we are creating the annotation in the files, we should be ensured that
    # the annotation is correct and formatted properly. But we check just in case. If 
    # performance becomes an issue, those checks can be removed.
    links.each_pair { |name, tracks|
      tracks.each { |linkedTrack|
        trackName = name.gsub(":", "").gsub(" ", "").downcase()
        linkedByField = linkedTrack["properties"]["linked_by"].gsub(" ", "").downcase()
        linkedToTrack = linkedTrack["properties"]["linked_to"].gsub(":", "").gsub(" ", "").downcase()
        linkedToSelf = (trackName == linkedToTrack)
        trackDataFile = File.join(@currScratchSpace, "#{@filesPrefix}.#{trackName}.#{linkedByField}.link.txt")
        linkedDataFile = File.join(@currScratchSpace, "#{@filesPrefix}.#{linkedToTrack}.#{linkedByField}.link.txt")
        concatDataFile = File.join(@currScratchSpace, "#{@filesPrefix}.#{trackName}.#{linkedToTrack}.#{linkedByField}.cat")
        sortedDataFile = File.join(@currScratchSpace, "#{@filesPrefix}.#{trackName}.#{linkedToTrack}.#{linkedByField}.sorted")
        outFile = File.new(linkedTrack["properties"]["file"], "w")

        # To limit the memory usage, we will rely on some system utils to sort and concat our files
        system("cat #{trackDataFile} #{linkedDataFile} > #{concatDataFile}") unless(linkedToSelf)
        system("sort -t\\; #{(linkedToSelf) ? trackDataFile : concatDataFile} +4 -5 > #{sortedDataFile}")

        # Finally create our circos formatted link files
        idCount = 1
        currLinkValue = nil
        linkedAnnot = Hash.new() { |h, k| h[k] = Array.new() }
        File.foreach(sortedDataFile) { |line|
          line.strip!()
          annotValues = line.split(";")
          next if(annotValues.length < 5)
          annotLinkValue = annotValues[4]
          currLinkValue = annotLinkValue if(currLinkValue.nil?)
          
          # We have reached the end of annots with this value, write out current values
          if(annotLinkValue != currLinkValue)
            if(linkedToSelf)
              # Self-linked tracks are the simple case, we take one annot and make
              # it our reference then iterate through the rest and create the link
              refAnnotLine = linkedAnnot[annotValues[0]].pop()
              while(!refAnnotLine.nil?)
                refAnnot = refAnnotLine.split(";")
              
                # Link our next annotation to the rest
                linkedAnnot[annotValues[0]].each { |annotToLinkLine|
                  annotToLink = annotToLinkLine.split(";")
                  outFile << "link_#{idCount} #{refAnnot[1]} #{refAnnot[2]} #{refAnnot[3]}\n"
                  outFile << "link_#{idCount} #{annotToLink[1]} #{annotToLink[2]} #{annotToLink[3]}\n"
                  idCount += 1
                }

                refAnnotLine = linkedAnnot[annotValues[0]].pop()
              end
            elsif(linkedAnnot[name].length > 0 and linkedAnnot[linkedTrack["properties"]["linked_to"]].length > 0)
              # We have at least one link to create between the tracks
              linkedAnnot[name].each { |refAnnot|
                refAnnot = refAnnot.split(";")

                linkedAnnot[linkedTrack["properties"]["linked_to"]].each { |annotToLink|
                  annotToLink = annotToLink.split(";")

                  outFile << "link_#{idCount} #{refAnnot[1]} #{refAnnot[2]} #{refAnnot[3]}\n"
                  outFile << "link_#{idCount} #{annotToLink[1]} #{annotToLink[2]} #{annotToLink[3]}\n"
                  idCount += 1
                }
              }
            end

            # Clear out our stored links for this value
            linkedAnnot.clear()
            currLinkValue = annotLinkValue
          end

          linkedAnnot[annotValues[0]].push(line.strip())
        }

        outFile.close()
      }
    }

    @debugLog.debug("[createDataFiles] Finished gathering annotation and creating data files...")
  rescue => e
    raise RuntimeError.new("There was an error creating the data files: #{e}\n#{e.backtrace.join("\n ")}")
  end
end

###############################################################################
# This method creates our required karyotype file
###############################################################################
def createKaryotypeFile(fileName, entryPoints, bandingFilePath="")
  begin
    @debugLog.debug("[createKaryotypeFile] Creating karyotype file...")

    file = File.new(fileName, "w")
    entryPoints.sort { |a, b| a["position"] <=> b["position"] }.each { |ep|
      file.print "chr - #{ep["id"]} #{ep["label"]} 0 #{ep["length"]}"
      # Specify our color if we have set one for this entry point. Because of the way Circos
      # implements colors for the ideogram, we CANNOT use an RGB value here, we must use a named
      # color.  So we place the name of the entry point here as a reference to a color that we 
      # define of the same name in the <colors> section
      file.print " #{ep["id"]}_color" unless ep["color"].nil?
      file.print "\n"
    }

    # Check if a banding track was set, if so attempt to read the file and add to the karyotype
    if(!bandingFilePath.empty? and File.exists?(bandingFilePath))
      @debugLog.debug("[createKaryotypeFile] Appending band annotation from #{bandingFilePath} to karyotype file")
      file << IO.read(bandingFilePath)
    end

    file.close()
    @debugLog.debug("[createKaryotypeFile] Finished creating karyotype file...")
  rescue => e
    raise RuntimeError.new("There was an error creating the karyotype file: #{e}\n#{e.backtrace.join("\n ")}")
  end
end

def createCircosConfFile(fileName, tmpResultsDir, options)
  begin
    @debugLog.debug("[createCircosConfFile] Creating conf file for Circos")

    # Create our confFile object and set our parameters
    confFile = BRL::Genboree::Circos::ConfigFile.new(options)
    confFile["karyotype_file_path"] = @karyotypeFilePath
    confFile["tmp_results_dir"] = tmpResultsDir
    confFile["image_name"] = "#{@filesPrefix}.ideogram.png"

    # Generate the conf file, saving to fileName
    confFile.generateConfFile(fileName)
    @debugLog.debug("[createCircosConfFile] Finished creating conf file for Circos")
  rescue => e
    raise RuntimeError.new("There was an error creating the conf file: #{e}\n#{e.backtrace.join(" \n")}")
  end
end

def executeCircos(circosResultsWeb, confFilePath, runLogFilePath="")
  begin
    @debugLog.debug("[executeCircos] Executing Circos...")
    command = "circos -conf #{confFilePath}"
    command << " >#{runLogFilePath}.out 2>#{runLogFilePath}.err" unless runLogFilePath.empty?
    @debugLog.debug("Circos command: #{command}")   
 
    # Change working directory to our scratchspace, Make our temp results directory
    # Create an inputs/ directory to expose the user to the conf and input files
    Dir.chdir(@currScratchSpace)
    FileUtils.makedirs(@filesPrefix + "_results")
    FileUtils.makedirs(@filesPrefix + "_results/inputs")
    FileUtils.cp("#{@filesPrefix}.circos.conf", "#{@filesPrefix}_results/inputs")
    system("tar -cjvf #{@filesPrefix}_results/inputs/#{@filesPrefix}.inputs.tar.bz2 #{@filesPrefix}*.txt")

    # Execute Circos
    circosSuccess = system(command)

    if(circosSuccess)
      # Create our web  accessible resting place for our results
      FileUtils.makedirs(circosResultsWeb)
      FileUtils.cp_r("#{@filesPrefix}_results/.", circosResultsWeb)

      # Update our status message to the user
      @statusString << "Your run of Circos has completed (job ID: #{@uniqueId}). Your results can be viewed at the following address:\n\n"
      @statusString << "Group: #{@options["config"]["groupName"]}\n" if(@options["config"].has_key?("groupName"))
      @statusString << "Database: #{@options["config"]["rseqName"]}\n" if(@options["config"].has_key?("rseqName"))
      @statusString << "http://#{@hostname}/java-bin/circosResults.jsp?group_id=#{@options["config"]["groupId"]}&rseq_id=#{@options["config"]["rseqId"]}&job_id=#{@filesPrefix}"
      @statusString << "\n\nIf you have any questions, please contact your Genboree administrator.\n"
    else
      @statusString << "Your run of Circos has completed (job ID: #{@uniqueId}). However, Circos encountered an error while trying to create "
      @statusString << "your image. Please notify your Genboree administrator.\n"
      @debugLog.error("[executeCircos] Circos command did not process successfully, check the circos.err log...")
    end

    @debugLog.debug("[executeCircos] Finished executing Circos...")
  rescue => e
    raise RuntimeError.new("There was an error executing the Circos binary: #{e}")
  end
end

###############################################################################
# The +notifyUser+ method will alert the user of the outcome of the run.
# It will create a message and send it to the users provided email address,
# If no email address provided, prints to stdout.
# Method uses the BRL emailer utility, courtesy of ARJ (BRL). MFS (BNI)
#
# * Arguments :
#  - +String+ -> The message to display
#  - +String+ -> The email address to send to
###############################################################################
def notifyUser(message, emailAddr=nil)
  unless(emailAddr.nil?)
    # Log our info for debug purposes
    debugInfo = "[notifyUser] Preparing email notification...\n"
    debugInfo << "\temail to: #{emailAddr}\n"
    debugInfo << "\temail from: #{@genbConf.gbFromAddress}"
    @debugLog.debug(debugInfo)

    begin
      email = BRL::Util::Emailer.new(@genbConf.gbSmtpHost)
      # Set From:, To:, Subject:
      email.setHeaders(@genbConf.gbFromAddress, emailAddr, "Genboree Has Run Your Queued Circos Job")

      # Now set who to send the email as (a valid user at the SMTP host)
      email.setMailFrom(@genbConf.gbFromAddress)

      # Now add user(s) who will receive the email.
      email.addRecipient(emailAddr)
      #email.addRecipient(@genbConf.gbBccAddress)

      # Add the body of your email message
      email.setBody(message + "\nThank You,\nThe Genboree Team")
      sendOk = email.send()
      if(sendOk)
        @debugLog.debug("[notifyUser] Sending of email succeeded.")
      else
        @debugLog.debug(  "[notifyUser] Sending of email failed. Emailer reports this error:\n" +
                          "#{email.sendError.class}: #{email.sendError.message}\n  " +
                          email.sendError.backtrace.join("\n  ") )
      end
    rescue => err
      @debugLog.error("[notifyUser] An error occurred while preparing and sending the nofication!\n#{err}")
    end

  else
    @debugLog.debug("[notifyUser] Printing to console...")
    puts "\n#{message}"
  end
  @debugLog.debug("[notifyUser] User notification complete...")
end

###############################################################################
# The +cleanup+ method handles tar'ing debug files and cleaning up the scratch
# space. MFS (BNI)
#
# * Arguments : none
###############################################################################
def cleanup()
  begin
    @debugLog.debug("[cleanup] Cleaning up scratch space...")
    @debugLog.debug("Circos Coordinator exiting...")
    @debugLog.info("-" * 60)

    # Compress our scratch files -- exclude temporary files
    Dir.chdir(@currScratchSpace)
    system("tar -cjvf #{@filesPrefix}.files.tar.bz2 #{@filesPrefix}*")

    # Cleanup the scratch space
    FileUtils.rm(Dir.glob("#{@filesPrefix}*.{conf,txt,lff,err,out,debug,sorted,cat,json}"))
    FileUtils.rm_rf("#{@filesPrefix}_results")
  rescue Exception => err
    @debugLog.error("[cleanup] An error occurred while trying to cleanup the scratch space! Circos Coordinator has exited!\n#{err}")
  ensure
    @debugLog.close()
  end
end

###############################################################################
# The +getAnnotAvp+ method returns a hash of the AVP values for the specified
# annotation. This method taken from VGP#Annotation class and refined. MFS (BNI)
#
# * Arguments : 
#  - +String+ -> The annotation, represented as a string from an LFF file
###############################################################################
def getAnnotAvp(annotation)
  hash = Hash.new()
  avpStr = annotation.strip.split(/\t/)[12]

  # No AVP specified for this annotation, return empty hash  
  return hash if(avpStr.nil? or avpStr !~ /\S/)

  avpStr.strip.split(/;/).each { |pair|
    pair.strip =~ /^([^=;]+)\s*=\s*([^;]*)\s*$/
    attribute,value = $1.strip, $2.strip
    hash[attribute.gsub(" ", "").downcase().to_sym] = value
  }

  return hash
end

########################################################################################
# END utility methods
########################################################################################

########################################################################################
# BEGIN Processing and generating return content/notification
########################################################################################

options.each { |option, arg|
  case option
    when '--help'
      printUsage()
      exit
    when '--daemonize'
      @daemonize = true
    when '--options'
      jsonString = arg
    when '--file'
      filePath = arg
    when '--job'
      @uniqueId = arg
    when '--log'
      debugLogPath = arg
  end
}

# Read our options, JSON formatted object. First check for the file specified, then the options struct
@options.merge!(JSON.load(filePath)) unless filePath.empty?
@options.merge!(JSON.parse(jsonString)) unless jsonString.empty?

# Ensure the required options are present
if(@options.nil? or
   @options["config"].nil? or
   @options["config"]["userId"].nil? or
   @options["config"]["groupId"].nil? or
   @options["config"]["rseqId"].nil? or
   @options["config"]["userLogin"].nil? or
   @options["ideogram"].nil? or
   @options["ideogram"]["entry_points"].nil? or
   @options["ideogram"]["entry_points"].empty? or
   circosScratchBase.nil? or circosScratchBase.empty? or
   circosResultsBase.nil? or circosResultsBase.empty?)

  raise ArgumentError.new("Some required arguments were missing!")
end

# Create a unique prefix for runs: <userId>_<timestamp>_<randNumForOneSecRes>
@filesPrefix = @options["config"]["userId"].to_s + "_" + @uniqueId

# Make the log path if necessary.
debugLogPathDir = File.dirname(debugLogPath)
FileUtils.mkdir_p(debugLogPathDir)

# Check if we are daemonized - if so, daemonize and go forth
if(@daemonize)
  require 'daemons'
  Daemons.daemonize

  # Reestablish stderr/stdout handles for error printing  
  File.umask(002)
  $stderr = File.new("#{debugLogPathDir}/#{@filesPrefix}.circosCoordinator.err", "w+")
  $stdout = File.new("#{debugLogPathDir}/#{@filesPrefix}.circosCoordinator.out", "w+")
end

# Create our debug logger to log our actions
@debugLog = Logger.new(debugLogPath)
@debugLog.level = Logger::DEBUG
@debugLog.datetime_format = "%Y-%m-%d %H:%M:%S, "

begin
  @debugLog.info("-" * 60)
  @debugLog.debug("Circos Coordinator started...")

  # Ensure that options were specified
  raise ArgumentError if jsonString.empty? and filePath.empty?
  if(!jsonString.empty? and !filePath.empty?)
    @statusString << "WARNING: The '--file' and '--options' were both specified; the '--options' structure has higher precedence\n\n"
    @debugLog.warn("WARNING: The '--file' and '--options' were both specified; the '--options' structure has higher precedence")
  end

  # Gather/Create necessary info and file paths
  @currScratchSpace = File.join(circosScratchBase, @options["config"]["groupId"].to_s,
    @options["config"]["rseqId"].to_s, @options["config"]["userLogin"].to_s)
  @karyotypeFilePath = File.join(@currScratchSpace, "#{@filesPrefix}.karyotype.txt")
  @paramFilePath = File.join(@currScratchSpace, "#{@filesPrefix}.circos.conf")
  @circosFinalResultsPath = File.join(circosResultsBase, @options["config"]["groupId"].to_s, 
    @options["config"]["rseqId"].to_s, @options["config"]["userLogin"].to_s, @filesPrefix)
  
  FileUtils.makedirs(@currScratchSpace)

  # Print some info for debugging
  configDebug = "Circos Config Options:\n"
  configDebug << "  userEmail: #{@options["config"]["userEmail"]}\n"
  configDebug << "  userId : #{@options["config"]["userId"]}\n"
  configDebug << "  userLogin : #{@options["config"]["userLogin"]}\n"
  configDebug << "  groupId : #{@options["config"]["groupId"]}\n"
  configDebug << "  rseqId : #{@options["config"]["rseqId"]}\n"
  configDebug << "File Paths:\n"
  configDebug << "  filesPrefix: #{@filesPrefix}\n"
  configDebug << "  karyotypeFilePath: #{@karyotypeFilePath}\n"
  configDebug << "  confFilePath: #{@paramFilePath}\n"
  configDebug << "  circosFinalResultsPath: #{@circosFinalResultsPath}\n"
  @debugLog.debug(configDebug)

  # Gather our specified tracks
  bandingTrackFilePath = ""
  tracks = Hash.new { |h, k| h[k] = Array.new() }
  tracks.merge!(@options["tracks"]) unless @options["tracks"].nil?
  if(!@options["ideogram"]["banding"].nil?)
    tracks[@options["ideogram"]["banding"]].push({"properties" => {"type" => "band"}})
    bandingTrackFilePath = File.join(@currScratchSpace, "#{@filesPrefix}.#{@options["ideogram"]["banding"].gsub(":", "").gsub(" ", "").downcase}.band.txt")
  end

  # Save our passed options for any debugging purposes
  optionsFile = File.new(File.join(@currScratchSpace, "#{@filesPrefix}.receivedOptions.json"), "w")
  optionsFile << JSON.pretty_generate(@options)
  optionsFile.close()
  
  # Now create our config files and execute Circos
  createDataFiles(tracks, @options["config"], File.join(@currScratchSpace, "#{@filesPrefix}.annotationDownloader.err"))
  createKaryotypeFile(@karyotypeFilePath, @options["ideogram"]["entry_points"], bandingTrackFilePath)
  createCircosConfFile(@paramFilePath, File.join(@currScratchSpace, "#{@filesPrefix}_results"), @options)
  executeCircos(@circosFinalResultsPath, @paramFilePath, File.join(@currScratchSpace, "#{@filesPrefix}.circos"))
rescue ArgumentError => e

rescue Exception => e
  # Failsafe, if any other error occurs (perhaps with the fork?), alert the user
  @statusString << "An internal system error has occurred while processing your Circos job (job ID: #{@uniqueId}), "
  @statusString << "please contact your Genboree administrator for assistance.\n"
  @statusString << "*ERROR*: An unknown error has occurred!\n"

  debugLine = "An internal system error has occurred (job ID: #{@uniqueId})!\n"
  debugLine << "ERROR: An unknown error has occurred!\n"
  debugLine << "EXCEPTION: #{e}\n"
  @debugLog.error(debugLine)
ensure
  notifyUser(@statusString, @options["config"]["userEmail"])
  cleanup()
end

########################################################################################
# END Processing
########################################################################################
