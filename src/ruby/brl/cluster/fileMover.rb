#! /usr/bin/env ruby

# == Overview
  # This script is used during cluster job submission to deal with a subset of output files that need to end up in different locations
  # as compared to the 'rest' of the files. This is to be used in addition to the rsync * command generated byt the cluster job submitter.
  # If all output files need to end up in the same place, this script should not be used.
  #
  # The script primarily works off of a CGI escaped JSON string which specifies the output files to look out for
  # specified as a regexp - 'srcrexp', how to modify these output files if necessary by a regexp - 'destrexp' and the output dir where the modified output files end up 'outputdir'
  # The JSON string is generated by calling JSON.generate on an array of hashes where each array element is a hash with the 3 keys specified above.
  # == Notes
  #
  # == Example usage:
  # a=Array.new
  # a[0]=Hash.new
  # a[0]['srcrexp']="output\\/(\\d+)\\.out"  (We are trying to specify something like ./output/1234.out Note the escaped forward and back slashes)
  # a[0]['destrexp']="results/\\1/outputs"  (We are trying to specify output/1234/1234.out Note the back reference \1. Since this is a string, no escaped forward slashes)
  # a[0]['outputDir']="a:b/"
  # CGI.escape(JSON.generate(a))  This is the string to use with the -s argument
  #
  # The script also takes a directory argument whose recursive listing is checked for pattern matches. It is easiest to use '.' as the directory and invoke the script from the top level directory fo interest
  #
  # /usr/bin/rsync -rltgoDvz -e /usr/bin/ssh output/1234.out a:b/results/1234/outputs
  # This is sample output for the JSOn string produced above.
  # The script also keeps track of and deletes any special files that have been rsynced so they aren't repeated when the rsync * that follows as a result of the cluster job submission is executed.


require 'rubygems'
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/util/emailer'

  def usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "This script is used during cluster job submission to deal with a subset of output files that need to end up in different locations
   as compared to the 'rest' of the files. This is to be used in addition to the rsync * command generated by the cluster job submitter.
   If all output files need to end up in the same place, this script should not be used.

   The script primarily works off of a CGI escaped JSON string which specifies the output files to look out for
   specified as a regexp - 'srcrexp', how to modify these output files if necessary by a regexp - 'destrexp' and the output dir where the modified output files end up  'outputdir'

   The JSON string is generated by calling JSON.generate on an array of hashes where each array element is a hash with the 3 keys specified above.
   a=Array.new
   a[0]=Hash.new
   a[0]['srcrexp']=\"output\\/(\\d+)\\.out\"  (We are trying to specify something like ./output/1234.out Note the escaped forward and back slashes)
   a[0]['destrexp']=\"results/\\1/outputs\"  (We are trying to specify output/1234/1234.out Note the back reference \1. Since this is a string, no escaped forward slashes)
   a[0]['outputDir']=\"a:b/\"
   CGI.escape(JSON.generate(a))  This is the string to use with the -s argument

   The script also takes a directory argument whose recursive listing is checked for pattern matches. It is easiest to use '.' as the directory and invoke the script from the top level directory of interest

   /usr/bin/rsync -rltgoDvz -e /usr/bin/ssh output/1234.out a:b/results/1234/outputs

   This is sample output for the JSON string produced above.
   The script also keeps track of and deletes any special files that have been rsynced so they aren't repeated when the rsync * that follows as a result of the cluster job submission is executed.PROGRAM DESCRIPTION:

          COMMAND LINE ARGUMENTS:
            -d or --directory     => This flag is required and should be followed by the directory whose listing is to be chacked for pattern matches
            -s or --jsonString    => This flag is required and should be followed by the CGI escaped jsonString as described above

          USAGE:
          ./filemover.rb -d . -s CGI.Escape(JSONSTRING)"
      exit(2);
    end

  def sendEmail(emailTo, subject, body)
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
    # Email to user
    if(!emailTo.nil?)
      emailer.addRecipient(emailTo)
      emailer.addRecipient(genbConfig.gbAdminEmail)
      emailer.setHeaders(genbConfig.gbFromAddress, emailTo, subject)
      emailer.setMailFrom(genbConfig.gbFromAddress)
      emailer.addHeader("Bcc: #{genbConfig.gbBccAddress}")
      body ||= "There was an unknown problem."
      emailer.setBody(body)
      emailer.send()
    end
  end


optsArray = [['--help', '-h', GetoptLong::NO_ARGUMENT],
             ['--directory', '-d', GetoptLong::REQUIRED_ARGUMENT],
             ['--jsonString', '-s', GetoptLong::REQUIRED_ARGUMENT]]


progOpts = GetoptLong.new(*optsArray)
optsHash = progOpts.to_hash
if(optsHash.key?('--help')) then
  usage()
end

unless(progOpts.getMissingOptions().empty?)
 usage("One or more required arguments are missing")
end
if(optsHash.empty?) then
 usage("One or more required arguments are missing")
end

directory = optsHash['--directory']
patternList = JSON.parse(optsHash['--jsonString'])


# rsync used to use -rltgoDvz but many of those seem inappropriate (goD) and/or are failing (t); also remove -e for ssh (default anyway)
rsyncCall = "rsync -rlvz "

removeList = Array.new
Dir.chdir(directory)
directoryListing = Dir.glob(File.join("**","*"))
directoryListing.each{|listing|
  patternList.each{|patternHash|
    if(listing =~ /#{patternHash['srcrexp']}/)
      newListing = listing
      if(patternHash['destrexp'] =~ /\S/)
        newListing = listing.gsub(/#{patternHash['srcrexp']}/, patternHash['destrexp'])
      end
      fileMvCmd = "#{rsyncCall} #{listing} #{patternHash['outputDir']}#{newListing}"
      $stderr.puts "Rsync special file with cmd:\n   #{fileMvCmd}"
      system("#{rsyncCall} #{listing} #{patternHash['outputDir']}#{newListing}")
      exitObj = $?
      exitStatus = exitObj.exitstatus
      # send email
      genbConfig = BRL::Genboree::GenboreeConfig.load()
      emailTo = genbConfig.gbAdminEmail
      subject = "CLUSTER ERROR: rsync failure"
      body = " There was a problem with rsyncing of the 'special' (.bin file maybe?) files. Details below:\nCmd: #{fileMvCmd.inspect}\n\nexitstatus: #{exitStatus.inspect}\n\ndirectory: #{directory.inspect}"
      sendEmail(emailTo, subject, body) if(exitStatus != 0)
      removeList << listing if(exitStatus == 0) # Remove rsync'd file if transfer was ok; else keep
    end
  }
}

$stderr.puts "Rsyncs done, try to delete local versions of special files."
removeList.reverse.each { |listing|
  cmd = "rm #{listing}"
  $stderr.puts "Trying to remove rsync'd special file with cmd:\n    #{cmd}"
  cmdOk = system(cmd)
  $stderr.puts "    REMOVE FAILED! exit code: #{$?.exitstatus}" unless(cmdOk)
}
