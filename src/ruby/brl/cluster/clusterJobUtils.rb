#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/cluster/clusterJob'

module BRL;
module Cluster
   # == Overview
  # This class is intended to provide methods commonly used with #ClusterJob objects and are frequently invoked
  # from within different classes/objects All methods are static

  class ClusterJobUtils
    # Checks if the supplied #ClusterJob object has commands, job name and output directory filled in
    # Also writes out informational messages to stderr
    # [+clusterJob+] ClusterJob object to be checked
    # [+returns+]    true if the ClusterJob object is filled correctly
    def self.clusterJobFilledCorrectly(clusterJob)
      retVal = true
      if (clusterJob.commands.empty?) then
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "The commands to be executed must be specified!")
        retVal = false
      end
      if(clusterJob.jobName.nil?)  then
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "The job name must be specified!")
        retVal = false
      end
      if(clusterJob.outputDirectory.nil? or clusterJob.outputDirectory.empty?)
        $stderr.debugPuts(__FILE__, __method__, "WARNING", "No output directory specified for cluster job. Hope you have a clusterFileList set or don't care about any output.")
      end
      return retVal
    end

    def self.logClusterError(errMsg)
      genbConf = BRL::Genboree::GenboreeConfig.load()
      flogWriter = BRL::Util::TextWriter.new(genbConf.clusterJobLogFile, "a+")
      flogWriter.puts "#{Time.now.to_s} #{errMsg}"
      flogWriter.close
    end

    def self.generateOutputFileList(clusterJob, fileName)
      fh = File.open(fileName, 'w')
      clusterJob.outputFileList.each{|listingHash|
        fh.puts("#{listingHash['--srcrexp']}--#{listingHash['--destrexp']}--#{listingHash['--outputDir']}")
        }
      fh.close
    end
  end
end
end # module BRL ; module Cluster ;
