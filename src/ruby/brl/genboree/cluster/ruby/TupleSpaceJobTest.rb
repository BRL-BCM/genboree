#!/usr/bin/env ruby

require 'brl/genboree/cluster/ruby/TupleSpaceJob'

## MAIN TEST
outputDirectory = ARGV[0]
copyFile = ARGV[1]
outputHost = ARGV[2]
sourceHost = ARGV[3]
commandList = nil
begin
  tupleSpaceJob = BRL::Genboree::Pash::TupleSpaceJob.new()
  tupleSpaceJob.outputDirectory=outputDirectory
  tupleSpaceJob.inputFilesNeedCopy=[ "/etc/hosts", copyFile]
  if (commandList == nil) then
    tupleSpaceJob.commandList=["hostname","uname -a", "ls -latr > foo", "ls -latr > bar",  "echo $PATH"]
  else
    tupleSpaceJob.commandList = commandList
  end
  $stderr.puts "executing command #{tupleSpaceJob.commandList.join(";")}, with output directory #{tupleSpaceJob.outputDirectory}"
   
  tupleSpaceJob.jobName = "test"
  tupleSpaceJob.jobType = "debug"
  tupleSpaceJob.outputIgnoreList = ["bar", "baz"]
  jobResources = {}
  jobResources["dbconns"]= "2"
  tupleSpaceJob.jobResources=jobResources
  tupleSpaceJob.removeTemporaryFiles = true
  tupleSpaceJob.uniqueJobTicket = "Po.#{Time.now().to_i}"
  tupleSpaceJob.notificationEmail = "coarfa@bcm.edu"
  tupleSpaceJob.outputHost = outputHost
  tupleSpaceJob.sourceHost = sourceHost 
  tupleSpaceJob.submit() 
rescue => err
  $stderr.puts "caught exception"
  $stderr.puts err.message
  $stderr.puts err.backtrace.inspect
end
