#!/usr/bin/env ruby

require 'GenboreeClusterJob.rb'

## MAIN TEST
outputDirectory = ARGV[0]
commandList = nil
begin
  genboreeClusterJob = BRL::GenboreeCluster::GenboreeClusterJob.new()
  genboreeClusterJob.outputDirectory=outputDirectory
  genboreeClusterJob.inputFilesNeedCopy=[ "/usr/local/brl/home/genbadmin/diff.proline.probe", "/usr/local/brl/home/genbadmin/downloads/libxml2-2.6.29.tar.gz", ]
  if (commandList == nil) then
    genboreeClusterJob.commandList=["hostname","uname -a", "ls -latr > foo", "ls -latr > bar",  "echo $PATH"]
  else
    genboreeClusterJob.commandList = commandList
  end
  $stderr.puts "executing command #{genboreeClusterJob.commandList.join(";")}, with output directory #{genboreeClusterJob.outputDirectory}"
   
  genboreeClusterJob.jobName = "test"
  genboreeClusterJob.outputIgnoreList = ["bar", "baz"]
  jobResources = {}
  jobResources["dbconns"]= "2"
  genboreeClusterJob.jobResources=jobResources
  genboreeClusterJob.removeJobDirectory = true
  genboreeClusterJob.submitAndWaitForCompletion() 
rescue => err
  $stderr.puts "caught exception"
  $stderr.puts err.message
  $stderr.puts err.backtrace.inspect
end
