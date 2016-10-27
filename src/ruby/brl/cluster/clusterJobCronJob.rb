#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'brl/util/util'
require 'brl/util/textFileUtil'
#require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/cluster/clusterJobRunner'
require 'brl/cluster/clusterJobUtils'

module BRL
module Cluster
  # == Overview
  # This ruby scipt serves as a cron job that can be scheduled to extract and submit unsubmitted jobs to the cluster system

genbConf = BRL::Genboree::GenboreeConfig.load()
fh = nil

haveLock = false
begin
  ClusterJobUtils.logClusterError("STATUS: Attempting non-blocking lock on lock file #{genbConf.clusterJobLockFile.inspect}")
  fh = File.open(genbConf.clusterJobLockFile, "w+")
  fh.flock(File::LOCK_EX | File::LOCK_NB)
  haveLock = true
  ClusterJobUtils.logClusterError("STATUS: Acquired lock.")
  clusterJobRunner = BRL::Cluster::ClusterJobRunner.new(genbConf.schedulerDbrcKey, genbConf.schedulerTable)
  numJobs = clusterJobRunner.work
rescue Errno::EAGAIN => err
  haveLock = false
  ClusterJobUtils.logClusterError("STAUTS: Lock failed. Could not get lock on file #{genbConf.clusterJobLockFile}. Another submitter may be running. Exiting #{err.to_s}")
rescue Exception => err1
  ClusterJobUtils.logClusterError("ERROR: Error while attempting to get lock on file #{genbConf.clusterJobLockFile} and then submit pending jobs.\nMessage: #{err1.to_s}\n#{err1.backtrace.join("\n")}")
ensure
  if(fh and haveLock)
    begin
      fh.flock(File::LOCK_UN)
    rescue => err2
      ClusterJobUtils.logClusterError("ERROR: Error while releasing lock on file #{genbConf.clusterJobLockFile}\nMessage: #{err2.to_s}\n#{err2.backtrace.join("\n")}")
    end
  end
end
end
end # module BRL ; module Cluster ;
