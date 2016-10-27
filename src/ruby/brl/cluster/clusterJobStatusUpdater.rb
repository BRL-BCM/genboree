#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'brl/util/util'
#require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/cluster/clusterJobManager'
require 'getoptlong'

module BRL
module Cluster
  # == Overview
  # This ruby script is invoked in a programamtic context
  # Its primary purpose is to update the job scheduler table with additional information about the cluster job
  # at different stages of its execution. This script accepts command line arguments designated with specific flags for this purpose.
  # The attributes that can be updated in the scheduler table include:
  #   The cluster assigned job Id for this job
  #   The cluster host on which this job was run
  #   The status of the job at different stages - 'running','completed' or 'failed'  
  #   The submission time of the job to teh cluster
  #   The time at which the job begins execution on the cluster
  #   The time at which the job completes execution on the cluster
  #
  # == Example usage:
  #
  # === E.g. Job completed successfully
  #   
  #   ./clusterJobStatusUpdater.rb -j 11 -u 'completed' -c 234 -h 'brl2.brl.bcm.tmc.edu' -d testDb -n ClusterJobs


class ClusterJobStatusUpdater
  
  def initialize(optsHash)
    @optsHash = optsHash
    setParameters()
  end

  def setParameters()
    @jobId = @optsHash['--jobId']
    @status = @optsHash['--status']
    @cjobId = @optsHash['--cjobId']
    @hostname = @optsHash['--hostname']
    @database = @optsHash['--database']
    @table = @optsHash['--name']
    @beginTime = @optsHash['--btime']
    @endTime = @optsHash['--etime']
    @submissionTime = @optsHash['--stime']
    @pbsCmds = @optsHash['--pbsCmds']
  end

  def work()
    clusterJobManager = ClusterJobManager.new(@database,@table)
    updateHash = {}
    updateHash["status"] = @status
    updateHash["clusterJobID"] = @cjobId unless @cjobId.nil?
    updateHash["clusterHostname"] = @hostname unless @hostname.nil?
    updateHash["submitDate"] = Time.now unless @submissionTime.nil?
    updateHash["execStartDate"] = Time.now unless @beginTime.nil?
    updateHash["execEndDate"] = Time.now unless @endTime.nil?
    updateHash["pbsCommands"] = @pbsCmds if(@pbsCmds)
    #updateHash["submitDate"] = Time.parse(@submissionTime) unless @submissionTime.nil?
    #updateHash["execStartDate"] = Time.parse(@beginTime) unless @beginTime.nil?
    #updateHash["execEndDate"] = Time.parse(@endTime) unless @endTime.nil?
    clusterJobManager.updateClusterJobDetails(@jobId, updateHash)
  end

  def ClusterJobStatusUpdater.processArguments()

    optsArray =	[ ['--jobId',     '-j', GetoptLong::REQUIRED_ARGUMENT],# The jobId assigned to this job by the scheduler. This helps identify the appropriate record in the scheduler table
                  ['--status',    '-u', GetoptLong::REQUIRED_ARGUMENT],# The final status of the job - 'completed' or 'failed'
                  ['--cjobId',    '-c', GetoptLong::OPTIONAL_ARGUMENT],# The jobId assigned to this job by the cluster
                  ['--hostname',  '-h', GetoptLong::OPTIONAL_ARGUMENT],# The host on the cluster on which this job was run
                  ['--database',  '-d', GetoptLong::REQUIRED_ARGUMENT], # The database where the scheduler table is located
                  ['--name',      '-n', GetoptLong::REQUIRED_ARGUMENT], # The name of the scheduler table
                  ['--btime',     '-b', GetoptLong::OPTIONAL_ARGUMENT], # The start time of the job on the cluster
                  ['--etime',     '-e', GetoptLong::OPTIONAL_ARGUMENT], # The completion time of the job on the cluster
                  ['--stime',     '-s', GetoptLong::OPTIONAL_ARGUMENT], # The submission time of the job to the cluster
                  ['--pbsCmds',   '-p', GetoptLong::OPTIONAL_ARGUMENT], # The submission time of the job to the cluster
                  ['--help', GetoptLong::OPTIONAL_ARGUMENT]
                ]

    progOpts = GetoptLong.new(*optsArray)
    optsHash = progOpts.to_hash
    ClusterJobStatusUpdater.usage() if(optsHash.key?('--help'));

    unless(progOpts.getMissingOptions().empty?)
      ClusterJobStatusUpdater.usage("USAGE ERROR: some required arguments are missing")
    end

    ClusterJobStatusUpdater.usage() if(optsHash.empty?);
    return optsHash
  end

  def ClusterJobStatusUpdater.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
  PROGRAM DESCRIPTION:
    This ruby script is invoked in a programamtic context
    Its primary purpose is to update the job scheduler table with additional information about the cluster job
    at different stages of its execution. This script accepts command line arguments designated with specific flags for this purpose.
    The attributes that can be updated in the scheduler table include:
      The cluster assigned job Id for this job
      The cluster host on which this job was run
      The status of the job at different stages - 'running','completed' or 'failed'  
      The submission time of the job to teh cluster
      The time at which the job begins execution on the cluster
      The time at which the job completes execution on the cluster
      
    
    COMMAND LINE ARGUMENTS:
      -j or --jobId     => The jobId assigned to this job by the scheduler.
                           This helps identify the appropriate record in the scheduler table. This is required.
      -u or --status    => The status of the job - 'running', or 'failed'. This is required.
      -c or --cjobId    => The jobId assigned to this job by the cluster. This is optional.
      -h or --hostname  => The host on the cluster on which this job was run. This is optional.
      -d or --database  => The database where the scheduler table is located. This is required.
      -n or --name      => The name of the scheduler table. This is required.
      -s or --stime     => The time at which the job was submitted to the cluster. This is optional.
      -b or --btime     => The time at which the job begins execution on the cluster. This is optional.
      -e or --etime     => The time at which the job completed execution on the cluster. This is optional.
      -p or --pbsCmds   => Additional pbs commands to run (export env varaiables)
      
    USAGE:
    clusterJobStatusUpdater.rb -j 11 -u 'completed' -c 234 -h 'brl2.brl.bcm.tmc.edu' -d 'testDb' -t 'ClusterJobs'"
      exit(2);
  end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = ClusterJobStatusUpdater.processArguments()
clusterJobStatusUpdater = ClusterJobStatusUpdater.new(optsHash)
clusterJobStatusUpdater.work()
end
end # module BRL ; module Cluster ;
