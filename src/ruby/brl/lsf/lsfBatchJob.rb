#!/usr/bin/env ruby
$VERBOSE = true
# ##############################################################################
# $Copyright:$
# ##############################################################################

# ##############################################################################
# EXAMPLE:
#				cmdStr = "#{TRIM_READS_CMD} #{@readFileName}"
#				lsf = BRL::LSF::LSFBatchJob.new(jobName)
#				lsf.errorFile = "#{lsfMsgDir}/#{jobName}.err"
#				lsf.outputFile = "#{lsfMsgDir}/#{jobName}.out"
#				lsf.queueName = queue
#				lsf.commandStrToRun = cmdStr
#				lsf.submit()		
# ##############################################################################

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/util'					# for to_hash extension of GetoptLong class, Range extension, NaN constant, etc

# ##############################################################################

module BRL ; module LSF
	class LSFSubmissionError < StandardError ; end ;		# Raised when bsub doesn't happen properly

	class LSFBatchJob
		attr_accessor :bsubExe, :bkillExe, :bstopExe, :bmodExe, :bresumeExe
		attr_accessor :jobName, :errorFile, :outputFile, :queueName, :loginShell
		attr_accessor :commandStrToRun
		attr_accessor :resourceStr, :minMaxNumProcessorsStr, :machineStr, :userPriority
		attr_accessor :jobID
		attr_accessor :useExclusiveMode, :userGroup, :dependencyStr
		attr_accessor :emailWhenStarts, :emailWhenFinished, :emailAddress
		attr_accessor :beginTimeStr, :terminationTimeStr, :runTimeLimitStr, :cpuTimeLimitStr, :coreLimit, :dssLimit, :fileSizeLimit, :memLimit, :stackLimit
		attr_accessor :preExecCommand, :copyFileStrs, :stdinFile

		attr_reader		:bsubMsg

		def initialize(jobName)
			# Init all to nil
			@bsubExe, @bkillExe, @bstopExe, @bmodExe, @bresumeExe, @jobName, @errorFile = nil
			@outputFile, @queueName, @loginShell, @commandStrToRun,	@resourceStr = nil
			@minMaxNumProcessorsStr, @machineStr, @userPriority,@jobID,	@useExclusiveMode = nil
			@userGroup, @dependencyStr, @emailWhenStarts, @emailWhenFinished, @emailAddress = nil
			@beginTimeStr, @terminationTimeStr, @runTimeLimitStr, @cpuTimeLimitStr, @coreLimit = nil
			@dssLimit, @fileSizeLimit, @memLimit, @stackLimit, @preExecCommand, @copyFileStrs, @stdinFile = nil
			# Now set specifics we can assume
			@bsubExe, @bkillExe, @bstopExe, @bmodExe, @bresumeExe = 'bsub', 'bkill', 'bstop', 'bmod', 'bresume'
			@jobName = jobName
			@loginShell = "/bin/bash"
		end

		def submit()
			# Must have: bsubExe, jobName, commandStrToRun, queueName
			unless(self.checkRequired( [@bsubExe, @jobName, @commandStrToRun, @queueName] ))
				raise(LSFSubmissionError, "ERROR: To submit an LSF job, you need to set bsubExe, jobName, commandStrTorun, and queueName to non-nil, non-empty values.")
			end
			# Warn if no: errorFile, outputFile
			unless(self.checkNoWarning( [@errorFile, @outputFile] ))
				raise(LSFSubmissionError, "WARNING: your job named #{@jobName} doesn't have both a specific stderr file and a stdout file for LSF stderr and stdout output. Not smart.")
			end
			# Construct the command
			bsubCmd =	"#{@bsubExe} -J #{@jobName} -q #{@queueName} " +
								((@errorFile.nil? or @errorFile.nil?) ? '' : "-e #{@errorFile} ") +
								((@outputFile.nil? or @outputFile.nil?) ? '' : "-o #{@outputFile} ") +
								((@loginShell.nil? or @loginShell.empty?) ? '' : "-L #{@loginShell} ") +
								((@resourceStr.nil? or @resourceStr.empty?) ? '' : "-R #{@resourceStr} ") +
								((@minMaxNumProcessorsStr.nil? or @minMaxNumProcessorsStr.empty?) ? '' : "-n #{@minMaxNumProcessorsStr} ") +
								((@machineStr.nil? or @machineStr.empty?) ? '' : "-m #{@machineStr} ") +
								((@userPriority.nil? or (@userPriority.to_i < 1) or (@userPriority.to_i >99)) ? '' : "-sp #{@userPriority} ") +
								((@useExclusiveMode.nil? or !useExclusiveMode) ? '' : "-x ") +
								((@userGroup.nil? or @userGroup.empty?) ? '' : "-G #{@userGroup} ") +
								((@dependencyStr.nil? or @dependencyStr.empty?) ? '' : "-w #{@dependencyStr} ") +
								((@emailWhenStarts.nil? or !@emailWhenStarts) ? '' : "-B ") +
								((@emailWhenFinished.nil? or !@emailWhenFinished) ? '' : "-N ") +
								((@emailAddress.nil? or @emailAddress.empty?) ? '' : "-u #{@emailAddress} ") +
								((@beginTimeStr.nil? or @beginTimeStr.empty?) ? '' : "-b #{@beginTimeStr} ") +
								((@terminationTimeStr.nil? or @terminationTimeStr.empty?) ? '' : "-t #{@terminationTimeStr} ") +
								((@runTimeLimitStr.nil? or @runTimeLimitStr.empty?) ? '' : "-W #{@runTimeLimitStr} ") +
								((@cpuTimeLimitStr.nil? or @cpuTimeLimitStr.empty?) ? '' : "-c #{@cpuTimeLimitStr} ") +
								((@coreLimit.nil? or (@coreLimit.to_i < 1)) ? '' : "-C #{@coreLimit} ") +
								((@dssLimit.nil? or (@dssLimit.to_i < 1)) ? '' : "-D #{@dssLimit} ") +
								((@fileSizeLimit.nil? or (@fileSizeLimit.to_i < 1)) ? '' : "-F #{@fileSizeLimit} ") +
								((@memLimit.nil? or (@memLimit.to_i < 1)) ? '' : "-M #{@memLimit} ") +
								((@stackLimit.nil? or (@stackLimit.to_i < 1)) ? '' : "-S #{@stackLimit} ") +
								((@preExecCommand.nil? or @preExecCommand.empty?) ? '' : "-E #{@preExecCommand} ") +
								((@copyFileStrs.nil? or @copyFileStrs.empty?) ? '' : "-f #{@copFileStrs.join('-f ')} ") +
								((@stdinFile.nil? or @stdinFile.empty?) ? '' : "-i #{@stdinFile} ") +
								@commandStrToRun ;
			@bsubMsg = `#{bsubCmd}`
			unless(@bsubMsg =~ /Job <\d+> is submitted to/)
				raise(LSFSubmissionError, "ERROR: The submission didn't work. bsub said:\n  '#{@bsubMsg}'\nin response to your submission, which looked like:\n   #{bsubCmd}\n")
			end
			@bsubMsg =~ /Job <(\d+)> is submitted to/
			@jobID = $1.to_i
			return @jobID
		end # def submit()

		def kill

		end

		def modify

		end

		def suspend

		end

		def resume

		end

		def LSFBatchJob.killAll(jobNamePattern="*", queue="*")

		end

		def LSFBatchJob.suspendAll(jobNamePattern="*", queue="*")

		end

		def LSFBatchJob.modifyAll(optionsStr, jobNamePattern="*", querue="*")

		end

		def LSFBatchJob.resumeAll(jobNamePattern="*", queue="*")

		end

		# ##########
		protected
		# ##########
		def checkRequired(attrArray)
			attrArray.each {
				|attribute|
				if(attribute.nil? or attribute.empty?)
					return false
				end
			}
		end

		def checkNoWarning(attrArray)
			attrArray.each {
				|attribute|
				if(attribute.nil? or attribute.empty?)
					return false
				end
			}
		end

	end # class Bsub
end ; end # module BRL ; module LSF