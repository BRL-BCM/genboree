#!/usr/bin/env ruby

require 'date'
require 'time'
require 'cgi'
require 'brl/db/dbrc'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/kb/mongoKbDatabase'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/lockFiles/genericDbLockFile'

raise "\n\nERROR: script takes 3 args: the Genboree host, the group name (escaped) and the regexp (should include leading '/' and path components must be escaped) which should match the folder/file names to delete." unless(ARGV.size == 3)

# Gather args
gbHost = ARGV[0]
groupName = CGI.unescape(ARGV[1])
regexp = CGI.unescape(ARGV[2])
begin
  dbrc = BRL::DB::DBRC.new()
  dbrcRec = dbrc.getRecordByHost(gbHost, :api)
  raise "Can't create/load key config object" unless(dbrc and dbrcRec)
rescue => err
  $stderr.puts %Q@
    ERROR: Run this script via Genboree-env enabled user like genbadmin.
      * Account must have standard Genboree-related env variables configured
        for the intended Genboree instance, such as: $DBRC_FILE, $GENB_CONFIG,
        $DOMAIN_ALIAS_FILE.
      * Furthermore, the $DBRC_FILE *must* have prefix-host based entries for
        connecting to the main MySQL database. 
      * Code will be expecting to be able to module load a module nameed
        'glib-2.0'
      * Will exit, but here are error details:
        - ERR CLASS: #{err.class}
        - ERR MSG:   #{err.message}
        - ERR TRACE:\n#{err.backtrace.join("\n")}

  @
  exit(7)
end
$stderr.puts "*************************************"
@genbConf = ENV['GENB_CONFIG']
@genbConfig = BRL::Genboree::GenboreeConfig.load(@genbConf)
@dbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:autoJobsCleanup)
hasPermission = @dbLock.getPermission(false) # Don't block
unless(hasPermission)
  $stderr.puts " Did not get permission to run. A previous cleanup job is already running. Exiting with 0 exit status."
  exit(0) ;
end
$stderr.puts "Starting cleanup script - #{Time.now}"
$stderr.puts "Going to delete files that match pattern: #{regexp}"
# Make dbu
dbu = BRL::Genboree::DBUtil.new("DB:#{gbHost}", nil, nil)
grpRecs = dbu.selectGroupByName(groupName)
if(grpRecs.nil? or grpRecs.empty?)
  $stderr.puts "Group: #{groupName.inspect} not found."
  exit(20)
end
groupId = grpRecs.first['groupId']
resultHash = {}
apiCaller = BRL::Genboree::REST::ApiCaller.new(gbHost, "", dbrcRec[:user], dbrcRec[:password])
grpRefseqRecs = dbu.selectGroupRefSeqByGroupId(groupId)
grpRefseqRecs.each {|grpRefseqRec|
  begin
    refseqId = grpRefseqRec['refSeqId']
    refseqRec  = dbu.selectDatabaseById(refseqId).first
    refseqName = refseqRec['refseqName']
    resultHash[refseqName] = { :total => 0, :deleted => 0, :failed_deletion => 0}
    databaseName = refseqRec['databaseName']
    $stderr.puts "Scanning DB: #{refseqName.inspect}; refseqId: #{refseqId}; databaseName: #{databaseName}"
    conn = nil
    dbu.setNewDataDb(databaseName)
    fileRecs = nil
    begin
      fileRecs = dbu.selectAllFiles(true)
    rescue => err
      $stderr.puts err
    ensure
      if(fileRecs.nil?)
        $stderr.puts "Error encountered getting file records. Skipping to next db."
        next
      end
    end
    succeeded = 0
    failed = 0
    filesMatched = 0
    foldersSeen = []
    $stderr.puts "No of files to match: #{fileRecs.size}; first rec: #{fileRecs.last.inspect}"
    fileRecs.each {|fileRec|
      fileName = fileRec['name'] # file names in db are unescaped.
      # Try to extract the date from the file name
      ss = /(\d\d\d\d-\d\d-(\d)*)/
      ss =~ fileName
      dateFromFile = $1
      if(fileName =~ /#{regexp}/ or ( dateFromFile and Date.parse(dateFromFile) <= Date.parse(regexp) ) )
        filesMatched += 1
        # Check if this file/folder was under a folder which we have already deleted
        folderSeen = false 
        if(!foldersSeen.empty?)
          foldersSeen.each { |folderName|
            if(fileName =~ /#{folderName}/)
              succeeded += 1
              $stderr.puts "Parent folder: #{folderName} for file: #{fileName} has already been deleted. Skipping..."
              folderSeen = true
            end
          }
        end
        next if(folderSeen)
        rsrcPath = nil
        fileToDelete = nil
        if(fileName =~ /\/$/)
          rsrcPath = "/REST/v1/grp/{grp}/db/{db}/files/{file}?"
          fileToDelete = fileName.gsub(/\/$/, '')
        else
          fileToDelete = fileName
          rsrcPath = "/REST/v1/grp/{grp}/db/{db}/file/{file}?insertMissingParent=false"
        end
        apiCaller.setRsrcPath(rsrcPath)
        apiCaller.delete( { :grp => groupName, :db => refseqName, :file => fileToDelete } )
        if(apiCaller.succeeded?)
          $stderr.puts "SUCCESS [Deleted]=> File: #{fileName}.\n\n"
          succeeded += 1
          if(fileName =~ /\/$/)
            foldersSeen.push(fileName)
          end
        else
          # Try deleting the file a few times. Maybe we had a server restart??
          attempts = 0
          deleted = false
          while(attempts <= 2 and !deleted)
            $stderr.puts "REATTEMPT: Server responded with non 200 status code. Trying again..."
            sleep(15)
            apiCaller.delete( { :grp => groupName, :db => refseqName, :file => fileName } )
            if(apiCaller.succeeded?)
              deleted = true
              $stderr.puts "SUCCESS [Deleted]=> File: #{fileName}.\n\n"
              succeeded += 1
              if(fileName =~ /\/$/)
                foldersSeen.push(fileName)
              end
            else
              attempts += 1
            end
          end
          unless (deleted)
            failed += 1
            $stderr.puts "FAILED => File: #{fileName}.\n\nAPI Response:\n#{apiCaller.respBody.inspect}\n\n"
          end
        end
      end
    }
    resultHash[refseqName] = { :matched => filesMatched, :success => succeeded, :failure => failed}
    $stderr.puts "Files Matched: #{filesMatched}"
    if(filesMatched > 0)
      if(filesMatched != succeeded)
        $stderr.puts "FAILED: Could not delete #{failed} files out of #{filesMatched} files. Check log for API response."
      else
        $stderr.puts "Successfully deleted all matched files."
      end
    end
  rescue => err
    $stderr.puts "ERROR: #{err}\n\nTRACE:\n\n#{err.backtrace.join("\n")}"
  ensure
    @dbLock.releasePermission()
    $stderr.puts '-' * 60
  end
}
# Generate final report
$stdout.puts "#Database\tFiles Matched\tSucceeded\tFailed"
resultHash.keys.sort.each { |dbName|
  matched = resultHash[dbName][:matched]
  success = resultHash[dbName][:success]
  failure = resultHash[dbName][:failure]
  $stdout.puts "#{dbName}\t#{matched}\t#{success}\t#{failure}"  
}
$stderr.puts "All Done."