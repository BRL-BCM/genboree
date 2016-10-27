#!/usr/bin/env ruby
require 'brl/genboree/constants'
module BRL ; module Genboree ; module Helpers

module DataImport

  # The different file imports are difined here

  # Used by import jobs that require the "importWiggleInGenboree.rb" script
  # consider cluster
  #
  # [+inputFile+]   string: Full path to the input file
  # [+trackName+]   string: The name of the track 'type:subtype'
  # [+userId+]      int: Id of the user submitting the job
  # [+refseqId+]    int: Id of the database
  # [+groupId+]     int: Id of the group owning database
  # [+userEmail+]   string: Email address that will be notified with results of import job
  # [+gc+] hash with genb config settings
  # [+useCluster+]  bool, Changes absolute paths to relative
  def DataImport.buildWigImportCmd(inputFile, trackName, userId, refseqId, groupId, userEmail, gc, jobId, useCluster=false)
    # cluster version specifies relative paths
    outputDir = (useCluster) ? '.' : File.dirname(inputFile)
    wigImportCmd = "#{gc.toolScriptPrefix}#{BRL::Genboree::Constants::WIG_UPLOAD_CMD}"
    wigImportCmd <<  " -u #{userId} -d #{refseqId} -g #{CGI.escape(groupId)} -J #{jobId} -t #{CGI.escape(trackName)} -i #{outputDir}/#{File.basename(inputFile)} "
    wigImportCmd << " --email #{CGI.escape(userEmail)} " if(userEmail)
    wigImportCmd += " -j . " if(useCluster) # bin files get moved later, default is to go straight to ridSequence dir
    wigImportCmd += " -F " if(useCluster)
    wigImportCmd += " --dbrcKey #{gc.dbrcKey} " if(useCluster)
    if(!useCluster)
      wigImportCmd += " 1> #{outputDir}/importWiggle.out" +
                    " 2> #{outputDir}/importWiggle.err"
    end
    return wigImportCmd
  end


  # Used by import jobs that require the AutoUploader class
  #
  # [+inputFile+]     Full path to the input file
  # [+userId+]        int: Id of the user submitting the job
  # [+refseqId+]      int: Id of the database
  # [+extraOptions+]  Hash: Additional command line args, name value pairs
  # [+useCluster+]    bool, Changes absolute paths to relative
  def DataImport.buildJavaUploaderCmd(inputFile, inputFormat, userId, refseqId, extraOptions=nil, useCluster=false)
    # If the input is 3col LFF (Entrypoints), the AutoUploader doesn't take the inputFormat ('-t') option
    inputFormat = nil if(inputFormat == BRL::Genboree::Constants::GB_LFF_EP_FILE)
    # cluster version specifies relative paths
    outputDir = (useCluster) ? '.' : File.dirname(inputFile)
    uploaderCmd = BRL::Genboree::Constants::JAVAEXEC + " " +
                  BRL::Genboree::Constants::UPLOADERCLASSPATH +
                  BRL::Genboree::Constants::UPLOADERCLASS +
                  " -u #{userId} -r #{refseqId}" +
                  " -f #{outputDir}/#{File.basename(inputFile)}"
    uploaderCmd += " -t #{inputFormat}" if(!inputFormat.nil?)
    # Append extra options for various types
    extraOptions.each_pair { |kk, vv|
      uploaderCmd += " --#{kk}"
      uploaderCmd += "=#{vv} " if(!vv.nil?)
    } if(!extraOptions.nil?)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "command: #{uploaderCmd.inspect}")
    return uploaderCmd
  end

  def DataImport.buildZoomLevelsForLFFCmd(inputFile, userId, groupId, refseqId, useCluster=false)
    outputDir = (useCluster) ? '.' : File.dirname(inputFile)
    zoomUploaderCmd = BRL::Genboree::Constants::ZOOMLEVELSFORLFF +
                 " -i #{inputFile} -g #{groupId} -d #{refseqId} -u #{userId}"
    zoomUploaderCmd += " 1> #{outputDir}/createZoomLevelsForLFF.out" +
                       " 2> #{outputDir}/createZoomLevelsForLFF.err"
    return zoomUploaderCmd
  end

  def DataImport.buildZoomLevelsAndUploadLFFCmd(inputFile, userId, groupId, refseqId, useCluster=false)
      cmdOutFile = "#{File.dirname(inputFile)}/createZoomLevelsAndUploadLFF.out"
      cmdErrFile = "#{File.dirname(inputFile)}/createZoomLevelsAndUploadLFF.err"
      cmd = BRL::Genboree::Constants::ZOOMLEVELSANDUPLOADLFF +
            " -i #{inputFile} -d #{refseqId} -g #{groupId} -u #{userId}" +
            " > #{cmdOutFile} 2> #{cmdErrFile} "
      return cmd
  end

  # Used by import jobs that require the FastEntrypointUploader class
  #
  # [+inputFile+]     Full path to the input file
  # [+userId+]        int: Id of the user submitting the job
  # [+refseqId+]      int: Id of the database
  # [+useCluster+]    bool, Changes absolute paths to relative
  def DataImport.buildFastaUploadCmd(inputFile, userId, refseqId, useCluster=false, suppressEmail=false, useClassPathFromEnv=false)
    # cluster version specifies relative paths
    outputDir = (useCluster) ? '.' : File.dirname(inputFile)
    uploaderCmd = BRL::Genboree::Constants::JAVAEXEC + " "
    unless(useClassPathFromEnv)
      uploaderCmd << BRL::Genboree::Constants::UPLOADERCLASSPATH
    else
      uploaderCmd << " -classpath $CLASSPATH "
    end
    uploaderCmd << BRL::Genboree::Constants::FASTAFILEUPLOADERCLASS
    uploaderCmd << " -u #{userId} -r #{refseqId} -f #{outputDir}/#{File.basename(inputFile)} "
    uploaderCmd << " -s " if(suppressEmail)
    uploaderCmd << " > #{outputDir}/FastaEntrypointUploader.out 2> #{outputDir}/FastaEntrypointUploader.err "
    return uploaderCmd
  end

  # Wrap the command for the clusterJobScheduler.rb
  #
  # Output files requiring special handling that need to be moved to a different place;
  # the 'rest' of the output files go to the default output dir.
  # The default output dir is specified during creation of the cluster job object
  #
  # [+genbConf+]        object:
  # [+cmd+]             string: The command to be wrapped
  # [+inputFile+]       string: The full path to the input file (-i)
  # [+hostname+]        string: The hostname of the server where input and output goes
  # [+outputDir+]       string: The full path to the dir where output files will go
  # [+resourcePath+]    string: A resource identifier string for this job which can be used to track resource usage (-p)
  # [+specialOutput+]   string: Special output file handling option. A comma separated url escaped list (-l)
  # [+returns+]         string: The wrapped command
  def DataImport.wrapCmdForCluster(genbConf, cmd, inputFile, hostname, outputDir, resourcePath=nil, specialOutput=nil)
    raise ArgumentError, "cmd cannot be nil." if(cmd.nil?)
    # InputFile will be local during cluster execution. Need containing dir. to use as output dir. after cluster run
    clusterSchedulerString = "clusterJobScheduler.rb" +
                             " -o #{hostname}:#{outputDir}" +
                             " -e #{BRL::Genboree::Constants::CLUSTER_ADMIN_EMAIL }" +
                             " -c #{CGI.escape(cmd)}" +
                             " -i #{hostname}:#{inputFile}"
    # //clusterSchedulerString.append(" -r gbUpload=1 -k ");
    # Which resources will this job utilize on the node/ what type of node does it need?
    clusterSchedulerString += " -r " + genbConf.clusterLFFUploadResourceFlag + "=1"
    # Should the temporary working directory of the cluster job be retained on the node?
    if (genbConf.retainClusterGBUploadDir == "true" || genbConf.retainClusterGBUploadDir == "yes")
      clusterSchedulerString += " -k "
    end
    # Create a resource identifier string for this job which can be used to track resource usage
    # Format is /REST/v1/grp/{grp}/db/{db}/annos
    clusterSchedulerString += " -p #{resourcePath}" if(!resourcePath.nil?)
    clusterSchedulerString += " -l #{specialOutput}" if(!specialOutput.nil?)
    return clusterSchedulerString
  end

  # This function wraps a command with genbTaskWrapper.rb
  #
  # [+cmd+]       string: The command that will be wrapped
  # [+outputDir+] string: The dir where log files are created
  # [+returns+]   string: The wrapped command
  def DataImport.wrapCmdForRubyTaskWrapper(cmd, outputDir)
    raise ArgumentError, "cmd cannot be nil." if(cmd.nil?)
    genbTaskWrapperCmd = "genbTaskWrapper.rb -v -c #{CGI.escape(cmd)}" +
                         " -g #{ENV['GENB_CONFIG']}" +
                         " -e #{outputDir}/genbTaskWrapper.err" +
                         " -o #{outputDir}/genbTaskWrapper.out &"
    return genbTaskWrapperCmd
  end

  # This function wraps a command with the TaskWrapper class
  #
  # [+cmd+]       string: The command that will be wrapped
  # [+outputDir+] string: The dir where log files are created
  # [+returns+]   string: The wrapped command
  def DataImport.wrapCmdForJavaTaskWrapper(cmd, outputDir)
    raise ArgumentError, "cmd cannot be nil." if(cmd.nil?)
    taskWrapperCmd = BRL::Genboree::Constants::JAVAEXEC + " " +
                       BRL::Genboree::Constants::UPLOADERCLASSPATH +
                       "-Xmx1800M org.genboree.util.TaskWrapper" +
                       " -a -c #{CGI.escape(cmd)}" +
                       " -e #{outputDir}/errors.out 2>&1 &"
    return taskWrapperCmd
  end
end

end ; end ; end#!/usr/bin/env ruby
