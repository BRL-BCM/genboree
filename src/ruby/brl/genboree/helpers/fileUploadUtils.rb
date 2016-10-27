#!/usr/bin/env ruby
require 'brl/genboree/constants'
require 'brl/genboree/helpers/dataImport'
require 'brl/genboree/dbUtil'

module BRL ; module Genboree ; module Helpers

module FileUploadUtils

  # Creates the dirctory where the upload file will be moved and processed.
  #
  # [+returns+] String The directory path
  def FileUploadUtils.createFinalDir(path, databaseName, userName)
    if (path.nil? || databaseName.nil? || userName.nil?)
      $stderr.puts("Wrong parameters used in createFinalDir method databaseName or userName missing");
    end
    if(!File.directory?(path) || !File.writable?(path))
      stderr.puts("Wrong directory permissions or directory does not exist " + path);
    end
    newDir = path;

    timeStampDir = self.generateUniqueName();
    newDir += "/#{databaseName}/#{userName}/#{timeStampDir}"
    FileUtils.mkdir_p(newDir, :mode => 0775)
    return newDir;
  end

  # Generates a unique directory name for the uploaded file to sit in
  # Timestamp plus a random number
  #
  # [+returns+] String the name of the directory
  def FileUploadUtils.generateUniqueName()
    # Something like "Fri_Mar_19_15:46:09_-0500_2010_26"
    return Time.now.to_s.gsub(' ', '_') + '_' + rand(100).to_s
  end

  # Upload annotations from a data file
  # - +inputFormat+ -> The input format for the inputFile (lff, wig, agilent, etc)
  # - +nameOfExtractedFile+ -> The name of the file, after extraction if it was necessary (this could be the same as inputFile if it was not compressed)
  # - +inputFile+ -> Path to the uploaded data file [String]
  # - +userId+ -> User ID (not username) of the user uploading the annotations
  # - +refseqId+ -> DB to upload annotations to
  # - +useCluster+ -> Whether the upload should be done on the cluster (note that in many formats below, this is set to false) [Boolean]
  # - +genbConf+ -> A GenboreeConfig object, required by the various upload methodologies
  # - +specOpts+ -> A hash of any remaining options that are spcific to one particular upload format [Hash]
  # - +debug+ -> Debug mode [Boolean]
  def FileUploadUtils.upload(inputFormat, nameOfExtractedFile, inputFile, userId, refseqId, useCluster, genbConf, specOpts, debug)
    exitStatus = 500

    # For wig uploads, a ruby script is wrapped with a ruby task wrapper
    # Important: cluster code for this part is NOT tested
    if(inputFormat == 'wig')
      $stderr.puts("STATUS: Building command for wig import")
      trackName = specOpts['trackName']
      @jobId = "uiWigClusterUploadJob-#{Time.now.to_f}"
      # Import command will be run on "extracted" file (so called, even if not actually extracted)
      importCmd = DataImport.buildWigImportCmd(inputFile, trackName, userId, refseqId, specOpts['groupId'], specOpts['userEmail'], genbConf, @jobId, useCluster)
      # Make the dir for the bin file if it does not exit
      system("mkdir -p /usr/local/brl/data/genboree/ridSequences/#{refseqId}")
      # Create an entry for RID_SEQUENCE_DIR in the fmeta table
      dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil)
      dbName = dbu.selectDBNameByRefSeqID(refseqId)[0]['databaseName']
      dbu.setNewDataDb(dbName)
      dbu.updateFmetaEntry('RID_SEQUENCE_DIR', "/usr/local/brl/data/genboree/ridSequences/#{refseqId}")
      if(useCluster)
        $stderr.puts "STATUS: uploading via cluster. Import command to run on cluster:\n  #{importCmd.inspect}"
        clusterJob = BRL::Cluster::ClusterJob.new("#{@jobId}", "#{genbConf.internalHostnameForCluster}:#{File.dirname(inputFile)}", "gb", genbConf.clusterAdminEmail, false)
        # Actual importCmd
        clusterJob.commands << CGI.escape(importCmd)
        # Give proper permissions
        clusterJob.commands << CGI.escape("chgrp nobody ./*.bin")
        clusterJob.commands << CGI.escape("chmod 664 ./*.bin")
        # Clean up commands:
        # - remove the data file since we already have it (or compressed version) on the server
        clusterJob.cleanUpCommands << "rm -f ./#{File.basename(inputFile)}*"
        # register input file:
        clusterJob.inputFiles << "#{genbConf.internalHostnameForCluster}:#{inputFile}"
        # We need to move the bin file
        a = Array.new
        a[0] = Hash.new
        a[0]['srcrexp'] = ".bin"
        a[0]['outputDir'] = "#{genbConf.internalHostnameForCluster}:/usr/local/brl/data/genboree/ridSequences/#{refseqId}/"
        clusterJob.outputFileList = JSON.generate(a)
        clusterJobManager = BRL::Cluster::ClusterJobManager.new(genbConf.schedulerDbrcKey, genbConf.schedulerTable)
        @schedJobId = clusterJobManager.insertJob(clusterJob)
        $stderr.puts "STATS: Job: #{@jobId} with id: #{@schedJobId} launched on cluster"
      else #genbTaskWrapper
        wrappedCmd = DataImport.wrapCmdForRubyTaskWrapper(importCmd, File.dirname(inputFile))
      end
    elsif(inputFormat == 'agilent' || inputFormat == 'pash' || inputFormat == 'blat' || inputFormat == 'blast' || inputFormat == BRL::Genboree::Constants::GB_LFF_EP_FILE)
      # At this point we must have userId, groupId, refseqId, and fileToSaveData
      useCluster = false
      importCmd = DataImport.buildJavaUploaderCmd(nameOfExtractedFile, inputFormat, userId, refseqId, specOpts['extraOptions'], useCluster)
      importCmd = "#{specOpts['inflateCmd']} ; #{importCmd}" if(specOpts['inflateCmd'])
      if(useCluster)
        resourcePath = (inputFormat != BRL::Genboree::Constants::GB_LFF_EP_FILE) ? "/REST/v1/grp/#{CGI.escape(specOpts['groupName'])}/db/#{CGI.escape(specOpts['refseqName'])}/annos" : nil
        # NOTE NOTE: if put on cluster, must added inflation cmd just like for wig above
        wrappedCmd = DataImport.wrapCmdForCluster(genbConf, importCmd, inputFile, specOpts['hostname'], File.dirname(inputFile), resourcePath)
      else
        wrappedCmd = DataImport.wrapCmdForRubyTaskWrapper(importCmd, File.dirname(inputFile))
      end
    elsif(inputFormat == 'lff')
      # At this point we must have userId, groupId, refseqId, and fileToSaveData
      useCluster = false
      importCmd = DataImport.buildZoomLevelsAndUploadLFFCmd(nameOfExtractedFile, userId, specOpts['groupId'], refseqId, useCluster)
      importCmd = "#{specOpts['inflateCmd']} ; #{importCmd}" if(specOpts['inflateCmd'])
      if(useCluster)
        resourcePath = "/REST/v1/grp/#{CGI.escape(specOpts['groupName'])}/db/#{CGI.escape(specOpts['refseqName'])}/annos"
        # NOTE NOTE: if put on cluster, must added inflation cmd just like for wig above
        wrappedCmd = DataImport.wrapCmdForCluster(genbConf, importCmd, nameOfExtractedFile, specOpts['hostname'], File.dirname(inputFile), resourcePath)
      else
        wrappedCmd = DataImport.wrapCmdForRubyTaskWrapper(importCmd, File.dirname(inputFile))
      end
    elsif(inputFormat == BRL::Genboree::Constants::GB_FASTA_EP_FILE )
      # At this point we must have userId, groupId, refseqId, and fileToSaveData
      useCluster = false
      importCmd = DataImport.buildFastaUploadCmd(nameOfExtractedFile, userId, refseqId, useCluster)
      importCmd = "#{specOpts['inflateCmd']} ; #{importCmd}" if(specOpts['inflateCmd'])
      if(useCluster)
        # NOTE NOTE: if put on cluster, must added inflation cmd just like for wig above
        wrappedCmd = DataImport.wrapCmdForCluster(genbConf, importCmd, inputFile, specOpts['hostname'], File.dirname(inputFile), resourcePath)
      else
        wrappedCmd = DataImport.wrapCmdForRubyTaskWrapper(importCmd, File.dirname(inputFile))
      end
    else
      # Dont know about this format
      $stderr.puts("ERROR: #{inputFormat} is not currently supported for Annotation Upload")
    end

    #-----------------------------------
    # Launch the importer locally if indicated
    #-----------------------------------
    unless(useCluster)
      $stderr.puts(Time.now.to_s + " DEBUG: inflateCmd \n" + specOpts['inflateCmd'].inspect) if(debug)
      $stderr.puts(Time.now.to_s + " DEBUG: importCmd \n" + importCmd.inspect) if(debug)
      $stderr.puts(Time.now.to_s + " DEBUG: wrapperCmd \n" + wrappedCmd.inspect) if(debug)

      # Run actual import command
      exitStatus = system("/usr/bin/nohup #{wrappedCmd}")
    end

    return exitStatus
  end
end

end ; end ; end
