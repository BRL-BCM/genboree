#!/usr/bin/env ruby
require 'getoptlong'

class BreakoutSVDetect
  DEBUG =true 
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
		@orientation = @optsHash['--orientation']
		if (@orientation != "same" && @orientation!="opposite") then
			BreakoutSVDetect.usage("The orientation should have the values same or opposite")
		end
		$stderr.puts "Relative expected strand orientation of consistent matepairs #{@sameStrandPairs}" 
		
		@forwardFile = @optsHash['--forwardFile']
		@reverseFile = @optsHash['--reverseFile']
		@forwardFileList = @optsHash['--forwardFileList']
		@reverseFileList = @optsHash['--reverseFileList']
		
		@forwardSuffix = @optsHash['--forwardSuffix']
		@reverseSuffix = @optsHash['--reverseSuffix']
		
		@outputStructVars = @optsHash['--structuralVariants']
		@systemType = "shm"
		if (@optsHash.key?('--pbs')) then
			@systemType = "pbs"
		end
		@numberOfCores = 1
		if (@optsHash.key?('--numberOfCores')) then
			@numberOfCores=@optsHash['--numberOfCores'].to_i
			if (@numberOfCores<1) then
				BreakoutSVDetect.usage("Number of cores should be a positive integer number")
			end
		end
		
		@fileType = @optsHash['--fileType']
		if (@fileType !~/^(bed|sam|bam|pash)$/) then
			BreakoutSVDetect.usage("File type should be one of sam/bam/bed/pash")
		end
		
		@chromosomeList = @optsHash['--chromosomeList']
		
		@minimumInsertSize = @optsHash['--minimumInsertSize'].to_i
		@maximumInsertSize = @optsHash['--maximumInsertSize'].to_i
		if (@minimumInsertSize<=0 || @maximumInsertSize<=0 || @minimumInsertSize >= @maximumInsertSize) then
			BreakoutSVDetect.usage("Insert size range incorrect")
		end
    @inconsistentMatepairsFile = nil
    if (@optsHash.key?('--inconsistentMatePairs')) then
      @inconsistentMatepairsFile = @optsHash['--inconsistentMatePairs']
    end
    @consistentMatepairsFile = nil
    
    if (@optsHash.key?('--consistentMatePairs')) then
      @consistentMatepairsFile = @optsHash['--consistentMatePairs']
      $stderr.puts "Consistent matepairs #{@consistentMatepairsFile}"
    end
  
  	@minNonChimericInsert = 100
    if (@optsHash.key?('--minNonChimericInsert')) then
      @minNonChimericInsert = @optsHash['--minNonChimericInsert']
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
				BreakoutSVDetect.usage("The forward file list and the reverse file list have different number of entries")
			end
		else
			BreakoutSVDetect.usage("forward and reverse file lists incorrectly specified")
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

	def prepareChromosomeFile()
		@chromosomeToNumberCorrespondenceFile = "#{@temporaryDir}/chromosomeToNumber.txt"
		w = File.open(@chromosomeToNumberCorrespondenceFile, "w")
		r = File.open(@chromosomeList, "r")
		l = nil
		@chromNumberToNameHash = {}
		@chromNumber = 1
		r.each {|l|
			w.puts "#{l.strip}\t#{@chromNumber}"
			@chromNumberToNameHash[@chromNumber]=l.strip
			$stderr.puts "cntn #{@chromNumber} #{@chromNumberToNameHash[@chromNumber]}" if (DEBUG)
			@chromNumber+=1
		}
		r.close()
		w.close()
		@chromNumber -= 1
		
		@chromNumberToNameHash.keys.each {|k|
			$stderr.puts "kcntn #{k} #{@chromNumberToNameHash[k]}" if (DEBUG)	
		}
	end

	def submitCallBreakpoints()
		@splitFileList = Dir["#{@splitFileRoot}*"]
		system("ls #{@splitFileRoot}*")
		$stderr.puts "splitFileList : #{@splitFileList.join(";")}" if (DEBUG)
		if (@splitFileList.size>@numberOfCores) then
			@actualParallelism = @numberOfCores
		else
			@actualParallelism = @splitFileList.size
		end
		$stderr.puts "Actual parallelism #{@actualParallelism}" if (DEBUG)
		@jobsToNodesHash = {}
		@totalJobs = @forwardList.size
		finishedChildrenIds=[]
		childrenIds=[]
		# submit initial jobs
		1.upto(@actualParallelism) {|idx|
			$stderr.puts "Attempt initial submission of splitjob #{idx}"
			jobId = Kernel.fork()
			if (jobId!=nil) then
				@jobsToNodesHash[jobId]=@nodeList[idx-1]
				childrenIds.push(jobId)
			else
				submitBreakCallJob(idx-1, @nodeList[idx-1])
				Kernel.exit()
			end
			
		}
		# submit rest of jobs, as soon as a job finishes
		(@actualParallelism+1).upto(@splitFileList.size) {|idx|
			$stderr.puts "Attempt to submit split input index #{idx}" if (DEBUG)
			jobId=Process.wait()
			finishedChildrenIds.push(jobId)
			freeNode = @jobsToNodesHash[jobId]
			jobId = Kernel.fork()
			if (jobId!=nil) then
				@jobsToNodesHash[jobId]=freeNode
				childrenIds.push(jobId)
			else
				submitBreakCallJob(idx-1, freeNode)
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

	def submitBreakCallJob(index, node)
		$stderr.puts "BreakCalling for  #{@splitFileList[index]}"
		command = ""
		if (@systemType=="pbs") then
			command <<"ssh #{node} "
		end
		if (File.size(@splitFileList[index])>0) then
			command << " breakCaller.exe -m #{@splitFileList[index]} -I #{@maximumInsertSize}  "
			command << " -o #{File.dirname(@splitFileList[index])}/bkps.#{File.basename(@splitFileList[index])}"
			command << " ; filterSameRead.rb #{File.dirname(@splitFileList[index])}/bkps.#{File.basename(@splitFileList[index])} "
			command << "  #{File.dirname(@splitFileList[index])}/same.bkps.#{File.basename(@splitFileList[index])} "
			command << "  #{File.dirname(@splitFileList[index])}/diff.bkps.#{File.basename(@splitFileList[index])} 25"
			$stderr.puts "executing command #{command}"
			system(command)
		end
		Kernel.exit()
	end
		
	def splitInconsistentMatepairs()
		@splitFileRoot = "#{@temporaryDir}/split.file"
		
		if (@chromNumber>@numberOfCores) then
			@actualParallelism = @numberOfCores
		else
			@actualParallelism = @chromNumber
		end
		$stderr.puts "Actual parallelism #{@actualParallelism}" if (DEBUG)
		@jobsToNodesHash = {}
		@totalJobs = @forwardList.size
		finishedChildrenIds=[]
		childrenIds=[]
		# submit initial jobs
		1.upto(@actualParallelism) {|idx|
			$stderr.puts "Attempt initial submission of splitjob #{idx}"
			jobId = Kernel.fork()
			if (jobId!=nil) then
				@jobsToNodesHash[jobId]=@nodeList[idx-1]
				childrenIds.push(jobId)
			else
				submitSplitJob(idx, @nodeList[idx-1])
				Kernel.exit()
			end
			
		}
		# submit rest of jobs, as soon as a job finishes
		(@actualParallelism+1).upto(@chromNumber) {|idx|
			$stderr.puts "Attempt to submit split input index #{idx}" if (DEBUG)
			jobId=Process.wait()
			finishedChildrenIds.push(jobId)
			freeNode = @jobsToNodesHash[jobId]
			jobId = Kernel.fork()
			if (jobId!=nil) then
				@jobsToNodesHash[jobId]=freeNode
				childrenIds.push(jobId)
			else
				submitSplitJob(idx, freeNode)
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

	def submitSplitJob(index, node)
		$stderr.puts "Processing split #{index}"
		command = ""
		if (@systemType=="pbs") then
			command <<"ssh #{node} "
		end
		command << " splitInconsistentFile.rb #{@temporaryDir}/inconsistent #{index} #{@chromNumber} #{@splitFileRoot}"
		$stderr.puts "executing command #{command}"
		system(command)
		$stderr.puts "split command idx #{index} #{command} result=#{result}"
		Kernel.exit()
	end

	def collectInconsistentMatePairs()
		if (@forwardList.size>@numberOfCores) then
			@actualParallelism = @numberOfCores
		else
			@actualParallelism = @forwardList.size
		end
		$stderr.puts "Actual parallelism #{@actualParallelism}" if (DEBUG)
		@temporaryDir = "#{File.dirname(@outputStructVars)}/Breakout.SV.#{Process.pid}"
		@temporaryDir = File.expand_path(@temporaryDir)
		system("mkdir -p #{@temporaryDir}")
		@temporaryHistogramRoot = "#{@temporaryDir}/inconsistent.part"
		@temporaryConsistentRoot = "#{@temporaryDir}/consistent.part"
		prepareChromosomeFile()
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
		command << " selectInconsistentMatepairs.exe -f #{@forwardList[inputIndex]} -r #{@reverseList[inputIndex]} -o #{@temporaryHistogramRoot}.#{inputIndex} "
		command << " -m #{@minimumInsertSize} -M #{@maximumInsertSize} -T #{@fileType} -F #{@forwardSuffix} -R #{@reverseSuffix} -S #{@orientation} "
		command << " -C #{@chromosomeToNumberCorrespondenceFile} -I #{@minNonChimericInsert} "
		if (@consistentMatepairsFile != nil) then
      command << " -O #{@temporaryConsistentRoot}.#{inputIndex}"
    end
		$stderr.puts "executing command #{command}"
		result=system(command)
		$stderr.puts "result #{result} for #{command}"
		Kernel.exit()
	end

	
  def work()
		$stderr.print "SV DETECT START#{Time.now()}"
		prepareInputSets
		loadNodeList()
		collectInconsistentMatePairs()
		splitInconsistentMatepairs()
		$stderr.print "BKP CALL START#{Time.now()}"
		submitCallBreakpoints()
		$stderr.print "BKP CALL STOP #{Time.now()}"
		centralizeResults()
		cleanup()
		$stderr.print "SV DETECT STOP#{Time.now()}"
  end

	def centralizeResults()
    # breakpoints
		r = File.popen("cat #{@temporaryDir}/diff.bkps.*" , "r")
		w = File.open(@outputStructVars, "w")
		l = nil
		r.each {|l|
			ff = l.strip.split(/\t/)
			ff[3] = @chromNumberToNameHash[ff[3].to_i]
			ff[6] = @chromNumberToNameHash[ff[6].to_i]
			w.puts ff.join("\t")
		}
		w.close()
		r.close()
    # inconsistent matepairs
    r = File.popen("cat #{@temporaryDir}/inconsistent*" , "r")
		w = File.open(@inconsistentMatepairsFile, "w")
		l = nil
		r.each {|l|
			ff = l.strip.split(/\t/)
			ff[0] = @chromNumberToNameHash[ff[0].to_i]
			ff[4] = @chromNumberToNameHash[ff[4].to_i]
			w.puts ff.join("\t")
		}
		w.close()
		r.close()
		# consistent matepairs
		if (@consistentMatepairsFile!=nil) then
      r = File.popen("cat #{@temporaryConsistentRoot}.*", "r")
      w= File.open(@consistentMatepairsFile, "w")
      r.each {|l|
        ff = l.strip.split(/\t/)
        ff[0] = @chromNumberToNameHash[ff[0].to_i]
        ff[4] = @chromNumberToNameHash[ff[4].to_i]
        w.puts ff.join("\t")
      }
      r.close()
      w.close()
		end
	end
	
	def cleanup()
		# system("rm -rf #{@temporaryDir}")
	end
	
  def BreakoutSVDetect.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--orientation',   	'-O', GetoptLong::OPTIONAL_ARGUMENT],
									['--forwardFile',	    '-f', GetoptLong::OPTIONAL_ARGUMENT],
									['--reverseFile',    	'-r', GetoptLong::OPTIONAL_ARGUMENT],
									['--forwardFileList',	'-F', GetoptLong::OPTIONAL_ARGUMENT],
									['--reverseFileList',	'-R', GetoptLong::OPTIONAL_ARGUMENT],
									['--forwardSuffix',		'-s', GetoptLong::REQUIRED_ARGUMENT],
									['--reverseSuffix',		'-S', GetoptLong::REQUIRED_ARGUMENT],
									['--structuralVariants', '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--sharedMem',		  	'-M', GetoptLong::NO_ARGUMENT],
									['--pbs',					  	'-P', GetoptLong::NO_ARGUMENT],
									['--numberOfCores',		'-N', GetoptLong::OPTIONAL_ARGUMENT],
									['--fileType',				'-T', GetoptLong::REQUIRED_ARGUMENT],
									['--minimumInsertSize',			'-i', GetoptLong::REQUIRED_ARGUMENT],
									['--minNonChimericInsert',		'-k', GetoptLong::OPTIONAL_ARGUMENT],
									['--maximumInsertSize',			'-I', GetoptLong::REQUIRED_ARGUMENT],
									['--consistentMatePairs',		'-C', GetoptLong::REQUIRED_ARGUMENT],
									['--inconsistentMatePairs',	       '-J', GetoptLong::REQUIRED_ARGUMENT],
									['--chromosomeList',				'-L', GetoptLong::REQUIRED_ARGUMENT],
									['--help',            '-h', GetoptLong::NO_ARGUMENT]
			]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = {}
		
		progOpts.each do |opt, arg|
      case opt
        when '--help'
          BreakoutSVDetect.usage("")
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
        when '--structuralVariants'
          optsHash['--structuralVariants']=arg
        when '--sharedMem'
          optsHash['--sharedMem']=1
        when '--pbs'
          optsHash['--pbs']=1
        when '--numberOfCores'
          optsHash['--numberOfCores']=arg
        when '--fileType'
          optsHash['--fileType']=arg
        when '--minimumInsertSize'
          optsHash['--minimumInsertSize']=arg
        when '--minNonChimericInsert'
          optsHash['--minNonChimericInsert']=arg
        when '--maximumInsertSize'
          optsHash['--maximumInsertSize']=arg
        when '--chromosomeList'
          optsHash['--chromosomeList']=arg
        when '--inconsistentMatePairs'
          optsHash['--inconsistentMatePairs']=arg
        when '--consistentMatePairs'
          optsHash['--consistentMatePairs']=arg
      end
    end

		BreakoutSVDetect.usage() if(optsHash.empty?);
		if (!optsHash.key?('--orientation') ||
				!optsHash.key?('--forwardSuffix') ||
				!optsHash.key?('--reverseSuffix') ||
				!optsHash.key?('--fileType') ||
				!optsHash.key?('--minimumInsertSize') ||
				!optsHash.key?('--maximumInsertSize') ||
				!optsHash.key?('--fileType') ||
				!optsHash.key?('--chromosomeList') ||
				!optsHash.key?('--structuralVariants') ) then
			BreakoutSVDetect.usage("USAGE ERROR: some required arguments are missing")
		end
		return optsHash
	end

	def BreakoutSVDetect.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "
PROGRAM DESCRIPTION:
This utility takes in forward and reverse files, or lists of forward and reverse files, corresponding
to mappings of matepair data, and the expected insert size range. It uses potentially multiple CPUs
to determine the consistent and inconsistent matepairs, and call structural variants.
This tool can make use of multiple available cores, other via
* shared memory, default mode
* cluster parallelism. The --pbs|-P option must be specified. Passwordless ssh authentication
  needs to be allowed between cluster nodes. On a cluster running PBS,
  the environment variable $PBS_NODEFILE is set and points to a file containing list of nodes used.
  The cluster parallelism can be used on a cluster that does not run pbs, if the user prepares the
  $PBS_NODEFILE environment variable, and makes it point to a file containing the list of machines
  to be used for this analysis.
The output structural variants are in raw format; we recommend processing them via the sv-to-lff.rb, svlff2csv.rb,
and other utilities provided by Breakout.

COMMAND LINE ARGUMENTS:
  --orientation          | -O   => consistent matepair orientation: same/opposite
  --forwardFile          | -f   => LFF file containing the sv calls
  --reverseFile          | -r   => [optional] class of the lff output file, default StructVariants
  --forwardFileList      | -F   => LFF file containing the sv calls
  --reverseFileList      | -R   => [optional] class of the lff output file, default StructVariants
  --forwardSuffix        | -s   => suffix of forward reads 
  --reverseSuffix        | -S   => suffix of reverse reads 
  --structuralVariants   | -o   => structural variants detected
  --sharedMem            | -M   => (default) the insert size collection will be performed on a multicore machine
  --pbs                  | -P   => [optional] the insert size collection will be performed on a multicore machine
  --numberOfCores        | -N   => [optional] number of cores used for computation, default 1
  --fileType             | -T   => input file types: sam, bam, bed, pash
  --minimumInsertSize    | -i   => lower bound of the expected insert size range
  --maximumInsertSize    | -I   => upper bound of the expected insert size range
  --minNonChimericInsert | -k   => minimum insert size which is not attributed to failed pairs 
  --consistentMatePairs  | -C   => [optional] consistent matepairs
  --inconsistentMatePairs| -J   => [optional] inconsistent matepairs
  --chromosomeList       | -L   => list of chromosomes; breakout works for genome assemblies with at most 1024 chromosomes
  --help                 | -h   => [optional] output this usage info and exit

USAGE:
  breakout-sv-detect.rb -O opp -f mapped.reads.1.bam -r mapped.reads.2.bam \
	  -o output.txt -s \"/0\" -S \"/1\" -N 2  -T bam -i 3000 -I 4000         \
		-C consistent.txt -J inconsistent.txt -L chromosomes.txt
";
		exit(2);
	end
end

########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = BreakoutSVDetect.processArguments()
# Instantiate analyzer using the program arguments
boilerPlate = BreakoutSVDetect.new(optsHash)
# Analyze this !
boilerPlate.work()
exit(0);
