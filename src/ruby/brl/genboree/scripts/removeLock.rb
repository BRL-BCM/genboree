#!/usr/bin/env ruby
require 'json'
require 'brl/genboree/lockFiles/genericDbLockFile'

ppn, lockType, confFile = ARGV[0], ARGV[1], ARGV[2]
#$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "ppn: #{ppn.inspect} ; lockType: #{lockType.inspect} ; confFile: #{confFile.inspect}")
lockType = (lockType ? lockType.to_sym : :toolJob)
conf = ( (confFile and File.readable?(confFile)) ? JSON.parse(File.read(confFile)) : {} )
#$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "lockType: #{lockType.inspect} ; conf:\n\n#{JSON.pretty_generate(conf)}")
dbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(lockType, conf)
dbLock.havePermission = true
dbLock.loadConf()
dbLock.releasePermission(ppn.to_i)
