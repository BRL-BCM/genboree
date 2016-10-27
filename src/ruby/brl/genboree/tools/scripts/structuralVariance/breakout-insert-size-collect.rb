#!/usr/bin/env ruby
require 'getoptlong'

class BreakoutCollectInsert
  DEBUG =true 
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
                $stderr.sync=true
		@orientation = @optsHash['--orientation']
		if (@orientation != "same" && @orientation!="opposite") then
			BreakoutCollectInsert.usage("The orientation should have the values same or opposite")
		end
		$stderr.puts "Relative expected strand orientation of consistent matepairs #{@sameStrandPairs}" 
		
		@forwardFile = @optsHash['--forwardFile']
		@reverseFile = @optsHash['--reverseFile']
		@forwardFileList = @optsHash['--forwardFileList']
		@reverseFileList = @optsHash['--reverseFileList']
		
		@forwardSuffix = @optsHash['--forwardSuffix']
		@reverseSuffix = @optsHash['--reverseSuffix']
		
		@outputHistogram = @optsHash['--outputHistogram']
		@systemType = "shm"
		if (@optsHash.key?('--pbs')) then
			@systemType = "pbs"
		end
		@numberOfCores = 1
		if (@optsHash.key?('--numberOfCores')) then
			@numberOfCores=@optsHash['--numberOfCores'].to_i
			if (@numberOfCores<1) then
				BreakoutCollectInsert.usage("Number of cores should be a positive integer number")
			end
		end
		
		@fileType = @optsHash['--fileType']
		if (@fileType !~/^(bed|sam|bam|pash)$/) then
			BreakoutCollectInsert.usage("File type should be one of sam/bam/bed/pash")
		end
  end

	def prepareInputSets()
		@forwardList = []
		@reverseList = []
		if (@forwardFile != nil && @reverseFile!=nil) then
			@forwardList.push(@forwardFile)
			@reverseList.push(@reverseFile)
		elsif(@forwardFileList!=nil && @reverseFileList!=nil) then
			r = File.open(@forwardFileList, "r")
			l=nil
			r.each {|l|
				@forwardList.push(l.strip)
			}
			r.close()
			r = File.open(@reverseFileList, "r")
			l=nil
			r.each {|l|
				@reverseList.push(l.strip)
			}
			r.close()
			if (@forwardList.size != @reverseList.size) then
				BreakoutCollectInsert.usage("The forward file list and the reverse file list have different number of entries")
			end
		else
			BreakoutCollectInsert.usage("forward and reverse file lists incorrectly specified")
		end
		$stderr.puts "Forward files #{@forwardList.join(",")} reverse files #{@reverseList.join(",")}" if (DEBUG)
	end
	
	def loadNodeList()
		@nodeList = []
		if (@systemType=="shm") then
			@nodeList = "self" * @numberOfCores
		else
			# make sure the variable PBS_NODEFILE is defined
			if (!ENV.key?('PBS_NODEFILE')) then
				$stderr.puts "The environment variable PBS_NODEFILE is not defined"
				exit(2)
			end
			r = File.open(ENV['PBS_NODEFILE'], "r")
			if (r==nil) then
				$stderr.puts "Could not open the node file #{ENV['PBS_NODEFILE']}"
				exit(2)
			end
			l=nil
			r.each {|l|
				@nodeList.push(l.strip)
			}
			r.close()
		end
	end

	def submitSizeCollection()
		if (@forwardList.size>@numberOfCores) then
			@actualParallelism = @numberOfCores
		else
			@actualParallelism = @forwardList.size
		end
		$stderr.puts "Actual parallelism #{@actualParallelism}" if (DEBUG)
		@temporaryDir = "#{File.dirname(@outputHistogram)}/Collect.Insert.#{Process.pid}"
		system("mkdir -p #{@temporaryDir}")
		@temporaryHistogramRoot = "#{@temporaryDir}/out.hist.part"
		@jobsToNodesHash = {}
		@totalJobs = @forwardList.size
		finishedChildrenIds=[]
		childrenIds=[]
		# submit initial jobs
		1.upto(@actualParallelism) {|idx|
			$stderr.puts "Attempt initial submission of job #{idx}"
			jobId = Kernel.fork()
			if (jobId!=nil) then
				@jobsToNodesHash[jobId]=@nodeList[idx-1]
				childrenIds.push(jobId)
			else
				submitJob(idx-1, @nodeList[idx-1])
				Kernel.exit()
			end
			
		}
		# submit rest of jobs, as soon as a job finishes
		(@actualParallelism+1).upto(@totalJobs) {|idx|
			$stderr.puts "Attempt to submit input index #{idx}" if (DEBUG)
			jobId=Process.wait()
			finishedChildrenIds.push(jobId)
			freeNode = @jobsToNodesHash[jobId]
			jobId = Kernel.fork()
			if (jobId!=nil) then
				@jobsToNodesHash[jobId]=freeNode
				childrenIds.push(jobId)
			else
				submitJob(idx-1, freeNode)
				Kernel.exit()
			end
		}
		# cleanup: make sure all jobs have finished
		1.upto(@actualParallelism) {|i|
			$stderr.puts "Attempt cleanup job #{i}" if (DEBUG)
			id = Process.wait()  
			finishedChildrenIds.push(id)
		}
		$stderr.puts childrenIds.join(",") if (DEBUG)
		$stderr.puts finishedChildrenIds.join(",") if (DEBUG)
		
		
	end
	
	def submitJob(inputIndex, node)
		$stderr.puts "Processing #{@forwardList[inputIndex]}"
		sleep(2)
		command = ""
		if (@systemType=="pbs") then
			command <<"ssh #{node} "
		end
		command << " insertCollector.exe -f #{@forwardList[inputIndex]} -r #{@reverseList[inputIndex]} -o #{@temporaryHistogramRoot}.#{inputIndex} "
		command << " -M 100000 -T #{@fileType} -F #{@forwardSuffix} -R #{@reverseSuffix} -S #{@orientation} "
		$stderr.puts "executing command #{command}"
		check=system(command)
                $stderr.puts "check: #{check}"
		Kernel.exit()
	end
	
  def work()
		prepareInputSets
		loadNodeList()
		submitSizeCollection()
		centralizeResults()
		cleanup()
  end

	def centralizeResults()
		finalInsertHash = {}
		tempHistogramList = Dir["#{@temporaryHistogramRoot}*"]
		tempHistogramList.each {|histFile|
			r = File.open(histFile)
			l = nil
			r.each {|l|
				ff = l.split(/\t/)
				if (!finalInsertHash.key?(ff[0])) then
					finalInsertHash[ff[0]]=0
				end
				finalInsertHash[ff[0]] += ff[1].to_i
			}
			r.close()
		}
		temporaryOutputHistogram = "#{@temporaryDir}/#{File.basename(@outputHistogram)}"
		w = File.open(temporaryOutputHistogram, "w")
		finalInsertHash.keys.each {|k|
			w.puts "#{k}\t#{finalInsertHash[k]}"	
		}
		w.close()
		sortCommand = "sort -k1,1n -o #{@outputHistogram} #{temporaryOutputHistogram}"
		$stderr.puts "Executing sort command #{sortCommand}" if (DEBUG)
		system(sortCommand)
	end
	
	def cleanup()
		system("rm -rf #{@temporaryDir}")
	end
	
  def BreakoutCollectInsert.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--orientation',   	'-O', GetoptLong::OPTIONAL_ARGUMENT],
									['--forwardFile',	    '-f', GetoptLong::OPTIONAL_ARGUMENT],
									['--reverseFile',    	'-r', GetoptLong::OPTIONAL_ARGUMENT],
									['--forwardFileList',	'-F', GetoptLong::OPTIONAL_ARGUMENT],
									['--reverseFileList',	'-R', GetoptLong::OPTIONAL_ARGUMENT],
									['--forwardSuffix',		'-s', GetoptLong::REQUIRED_ARGUMENT],
									['--reverseSuffix',		'-S', GetoptLong::REQUIRED_ARGUMENT],
									['--outputHistogram', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--sharedMem',		  	'-M', GetoptLong::NO_ARGUMENT],
									['--pbs',					  	'-P', GetoptLong::NO_ARGUMENT],
									['--numberOfCores',		'-N', GetoptLong::OPTIONAL_ARGUMENT],
									['--fileType',				'-T', GetoptLong::REQUIRED_ARGUMENT],
									['--help',            '-h', GetoptLong::NO_ARGUMENT]
			]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = {}
		
		progOpts.each do |opt, arg|
      case opt
        when '--help'
          BreakoutCollectInsert.usage("")
        when '--orientation'
          optsHash['--orientation'] = arg
        when '--forwardFile'
          optsHash['--forwardFile']=arg
        when '--reverseFile'
          optsHash['--reverseFile']=arg
        when '--forwardFileList'
          optsHash['--forwardFileList']=arg
        when '--reverseFileList'
          optsHash['--reverseFileList']=arg
        when '--forwardSuffix'
          optsHash['--forwardSuffix']=arg
        when '--reverseSuffix'
          optsHash['--reverseSuffix']=arg
        when '--outputHistogram'
          optsHash['--outputHistogram']=arg
        when '--sharedMem'
          optsHash['--sharedMem']=1
        when '--pbs'
          optsHash['--pbs']=1
        when '--numberOfCores'
          optsHash['--numberOfCores']=arg
        when '--fileType'
          optsHash['--fileType']=arg  
      end
    end

		BreakoutCollectInsert.usage() if(optsHash.empty?);
		if (!optsHash.key?('--orientation') ||
				!optsHash.key?('--forwardSuffix') ||
				!optsHash.key?('--reverseSuffix') ||
				!optsHash.key?('--fileType') ||
				!optsHash.key?('--outputHistogram') ) then
			BreakoutCollectInsert.usage("USAGE ERROR: some required arguments are missing")
		end
		return optsHash
	end

	def BreakoutCollectInsert.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
PROGRAM DESCRIPTION:
This utility takes in forward and reverse files, or lists of forward and reverse files, 
and uses potentially multiple CPUs to determine the distribution of insert sizes.
This tool can make use of multiple available cores, other via
* shared memory, default mode
* cluster parallelism. The --pbs|-P option must be specified. Passwordless ssh authentication
  needs to be allowed between cluster nodes. On a cluster running PBS,
  the environment variable $PBS_NODEFILE is set and points to a file containing list of nodes used.
  The cluster parallelism can be used on a cluster that does not run pbs, if the user prepares the
  $PBS_NODEFILE environment variable, and makes it point to a file containing the list of machines
  to be used for this analysis.

COMMAND LINE ARGUMENTS:
  --orientation          | -O   => consistent matepair orientation: same/opposite
  --forwardFile          | -f   => LFF file containing the sv calls
  --reverseFile          | -r   => [optional] class of the lff output file, default StructVariants
  --forwardFileList      | -F   => LFF file containing the sv calls
  --reverseFileList      | -R   => [optional] class of the lff output file, default StructVariants
  --forwardSuffix        | -s   => suffix of forward reads 
  --reverseSuffix        | -S   => suffix of reverse reads 
  --outputHistogram      | -o   => output insert size histogram
  --sharedMem            | -M   => (default) the insert size collection will be performed on a multicore machine
  --pbs                  | -P   => [optional] the insert size collection will be performed on a multicore machine
  --numberOfCores        | -N   => [optional] number of cores used for computation, default 1
  --fileType             | -T   => input file types: sam, bam, bed, pash
  --help                 | -h   => [optional] output this usage info and exit

USAGE:
  breakout-insert-size-collect.rb -O opp -f mapped.reads.1.bam -r mapped.reads.2.bam \
	  -o output.txt -s \"/0\" -S \"/1\" -N 2  
";
		exit(2);
	end
end

########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = BreakoutCollectInsert.processArguments()
# Instantiate analyzer using the program arguments
boilerPlate = BreakoutCollectInsert.new(optsHash)
# Analyze this !
boilerPlate.work()
exit(0);
