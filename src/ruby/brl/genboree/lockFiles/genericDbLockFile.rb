#!/usr/bin/env ruby

require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'

module BRL ; module Genboree ; module LockFiles
  class GenericDbLockFile
    attr_accessor :conf
    attr_accessor :dbType, :genbConf,  :lockFileDir, :lockFileName, :lockFilePath, :lockFile
    attr_accessor :maxDbOps, :maxLockRetries, :lockRetrySleepSecs
    attr_accessor :havePermission

    MINSLEEPTIME = 30
    MAXSLEEPTIME = 1800

    def initialize(dbType, conf={})
      @genbConf = nil
      @havePermission = false
      @dbType = dbType
      @conf = conf
    end

    def getPermission(blocking=true, sleepTime=nil, incrementBy=1)
      unless(@havePermission) # if already have it, then don't get it again...
        done = false
        loop {
          # Reload conf file to support on-the-fly management/admin
          loadConf()
          # Lock file. Note: if this fails [returns false] when it finally returns,
          # this code will proceed _regardless_. The parameters to getLock should be
          # appropriate so that the lock on the file will be attempted many many times
          # and do some sleeping in between or blocking=false for immediate failure (no retries).
          @lockFile = File.open(@lockFilePath, 'a+')
          # This is where the blocking happens
          gotLock = @lockFile.getLock(@maxLockRetries, @lockRetrySleepSecs, true, blocking)
          if(gotLock)
            # Got Lock (most probably). Read content
            @lockFile.rewind
            content = @lockFile.read
            lockCount = content.to_i
            # If there's room for incrementBy more ops, then have permission to do those incrementBy ops
            if((lockCount+incrementBy) <= @maxDbOps)
              lockCount += incrementBy
              @lockFile.truncate(0)
              @lockFile.rewind
              @lockFile.puts lockCount
              @lockFile.flush
              @havePermission = true
            end
            # Regardless of whether there was room for more ops or not, release hold on file:
            @lockFile.releaseLock
            @lockFile.close
            # Did we get our permission and/or were we told not to block/retry?
            if(@havePermission or (blocking == false))
              break
            else  # Else not allowed to connect right now, sleep a while, then retry.
              self.loadConf()
              @sleepSecs = (sleepTime.nil? ? @sleepSecs : sleepTime) # change sleeping time if provided
              sleep(@sleepSecs)
            end
          else # couldn't get lock, let alone see if there is room for more ops, retry or return immediately
            @havePermission = false
            if(blocking == false)
              break
            else # try lock again after pause
              @sleepSecs = (sleepTime.nil? ? @sleepSecs : sleepTime) # change sleeping time if provided
              sleep(@sleepSecs)
            end
          end
        }
      end
      return @havePermission
    end

    def releasePermission(decrementBy=1)
      retVal = false
      if(@havePermission)
        # Lock file.
        @lockFile = File.open(@lockFilePath, 'a+')
        lockOk = @lockFile.getLock(@maxLockRetries*2, @lockRetrySleepSecs)
        if(lockOk)
          # Got Lock. Read content
          @lockFile.rewind
          content = @lockFile.read
          lockCount = content.to_i
          lockCount -= decrementBy
          lockCount = 0 if(lockCount < 0)
          @lockFile.truncate(0)
          @lockFile.rewind
          @lockFile.puts lockCount
          @lockFile.flush
          @havePermission = false
          @lockFile.releaseLock
          @lockFile.close
          @lockFile = nil
          retVal = true
        else # Couldn't get lock for really really long time, can't release. Return failure; let caller decide what to do.
          retVal = false
        end
      else # no permission to release, do nothing
        retVal = true
      end
      return retVal
    end

    def loadConf()
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @sleepSecs          = @conf['sleepSecs']   || @genbConf.genericDbOpSleepSecs.to_i
      @lockFileDir        = @conf['lockFileDir'] || @genbConf.gbLockFileDir
      @maxLockRetries     = @conf['maxRetries']  || @genbConf.maxDbOpsLockRetries.to_i
      @lockRetrySleepSecs = @conf['retrySleepSecs'] || @genbConf.lockRetrySleepSecs.to_i
      # These come from @conf, if provided, or from specific settings in genbConf based on "dbType" (@deprecated)
      case @dbType
        when :custom
          @lockFileName = @conf['lockFileName']
          @maxDbOps     = @conf['maxOps']
        when :mainGenbDb
          @lockFileName = @genbConf.mainGenbDbOpsLockFile
          @maxDbOps = @genbConf.maxMainGenbDbOps.to_i
        when :userGenbDb
          @lockFileName = @genbConf.userGenbDbOpsLockFile
          @maxDbOps = @genbConf.maxUserGenbDbOps.to_i
        when :otherGenbDb
          @lockFileName = @genbConf.otherGenbDbOpsLockFile
          @maxDbOps = @genbConf.maxOtherGenbDbOps.to_i
        when :useImportTool
          @lockFileName = @genbConf.importToolLockFile
          @maxDbOps = @genbConf.maxImportToolDbOps.to_i
        when :largeMemJob
          @lockFileName = @genbConf.largeMemJobLockFile
          @maxDbOps = @genbConf.maxLargeMemJobOps.to_i
        when :clusterJobDb
          @lockFileName = @genbConf.clusterJobDbOpsLockFile
          @maxDbOps = @genbConf.maxClusterOps.to_i
        when :toolJob
          @lockFileName = @genbConf.toolJobOpsLockFile
          @maxDbOps = @genbConf.maxToolJobOps.to_i
        when :autoJobsCleanup
          @lockFileName = @genbConf.autoJobsCleanupLockFile
          @maxDbOps = @genbConf.maxAutoJobsCleanupOps.to_i
        else
        raise ArgumentError, "ERROR: unknown dbType arg (#{@dbType.inspect}). Must be one of these Symbols: :mainGenbDb, :userGenbDb, :otherGenbDb, :useImportTool, :clusterJobDb, largeMemJob . "
      end
      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "For @dbType = #{@dbType.inspect} : @lockFileName = #{@lockFileName.inspect} ; @maxDbOps = #{@maxDbOps.inspect} ; @conf:\n\n#{JSON.pretty_generate(@conf)}\n\n")
      @lockFilePath = "#{@lockFileDir}/#{@lockFileName}"
      return @genbConf
    end

    # Returns a time to sleep that is big for large number of records and small for small number of records.
    #
    # [+recCount+]        int: number of records to consider
    # [+minSleepTime+]    int: seconds; default=30secs
    # [+maxSleepTime+]    int: seconds; default=30mins
    # [+adjFactor+]       int: lower don't care limit
    # [+addRandomExtra+]  bool: add an extra random bit of time; useful to avoid a group of jobs having the same time
    # [+returns+]         int: seconds
    def self.sleepTimeScaledBySize(recCount, minSleepTime=30, maxSleepTime=1800, adjFactor=5.75, addRandomExtra=true)
      # Does a kind of bounded exponential time based on file size.
      # Time to sleep ranges from ~MINSLEEPTIME to ~MAXSLEEPTIME.
      # Log-based scaling in the calculation results in:
      # sleepTimeScaledBySize(x, minSleepTime=30, maxSleepTime=1800, adjFactor=6, addRandomExtra=true)
      # 1,000,000 annos will sleep for ~ 30
      # 10,000,000 annos will sleep for ~ 30
      # 100,000,000 annos will sleep for ~ 118.0
      # 1,000,000,000 annos will sleep for ~ 1006.0
      # 10,000,000,000 annos will sleep for ~ 1800

      time = minSleepTime
      orderFactor = Math.log10(recCount)
      # for recCounts less than adjFactor, we don't care, and will be 0
      adjOrderFactor = (orderFactor > adjFactor) ? orderFactor - adjFactor : 1
      adjTime = 10 ** adjOrderFactor
      #$stdout.puts  " -- #{orderFactor}, #{adjOrderFactor}, #{adjTime}"
      time = adjTime
      randTime = rand(adjTime/2) if(addRandomExtra)
      time += randTime
      if(time > maxSleepTime)
        time = maxSleepTime
      elsif(time < minSleepTime)
        time = minSleepTime
      end
      return time ;
    end


  end
end ; end ; end
