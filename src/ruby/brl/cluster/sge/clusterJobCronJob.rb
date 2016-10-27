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

module BRL
module Cluster
  # == Overview
  # This ruby scipt serves as a cron job that can be scheduled to extract and submit unsubmitted jobs to the cluster system
  
genbConf = BRL::Genboree::GenboreeConfig.load()
fh = nil
flogWriter = BRL::Util::TextWriter.new(genbConf.clusterJobLogFile,"a","bzip")
haveLock = false
begin
  fh = File.open(genbConf.clusterJobLockFile, "w+")
  fh.flock(File::LOCK_EX | File::LOCK_NB)  
  haveLock = true
  #clusterJobRunner = ClusterJobRunner.new(genbConf.schedulerDbrcKey,genbConf.schedulerTable)
  #numJobs = clusterJobRunner.work()
  #flog.puts "#{Time.now.to_s} #{numJobs} submitted successfully" 
  timeNow = Time.now.to_s
  #flogWriter.puts "#{timeNow} Got lock on file #{genbConf.clusterJobLockFile} "
  clusterJobRunner = ClusterJobRunner.new(genbConf.schedulerDbrcKey,genbConf.schedulerTable)
  numJobs = clusterJobRunner.work(flogWriter)
  #flogWriter.puts "#{timeNow} #{Time.now.to_s} #{numJobs} jobs submitted successfully"
rescue Errno::EAGAIN => err  
  haveLock = false
  flogWriter.puts "#{timeNow} #{Time.now.to_s} Could not get lock on file #{genbConf.clusterJobLockFile}. Exiting #{err.to_s}"
#  flogWriter.puts err.backtrace.join("\n")
rescue Exception => err1
  flogWriter.puts "#{timeNow} #{Time.now.to_s} Error while attempting to get lock on file #{genbConf.clusterJobLockFile}\n#{err1.to_s}"
#  flogWriter.puts err1.backtrace.join("\n")
ensure
  if(fh and haveLock)
    begin
      fh.flock(File::LOCK_UN)
      #flogWriter.puts "#{timeNow} #{Time.now.to_s} Released lock on file #{genbConf.clusterJobLockFile} "
    rescue => err2
      flogWriter.puts "#{timeNow} #{Time.now.to_s} Error while releasing lock on file #{genbConf.clusterJobLockFile}\n#{err2.to_s}"
#      flogWriter.puts err2.backtrace.join("\n")
    end
  end
flogWriter.close
end
end
end # module BRL ; module Cluster ;
