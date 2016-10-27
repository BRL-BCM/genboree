#!/usr/bin/env ruby

##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
###############################################################################
require 'rubygems'
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'

def usage(msg='')
  unless(msg.empty?)
    puts "\n#{msg}\n"
  end
  puts "This script is used during cluster job submission to have environment variables instantiated to desired values just prior to the cluster job execution or to 
   change values of key value pairs in the genboree.config file used by the cluster. These are only set durign the cluster run and are automatically reset to their 
   original values on job completion.

   This is specified by a JSON string.
   An example json string might be 

   {\"env\":{\"BLAH\":\"blah2\"}}

		or 

   {\"genbConfig\":{\"dbHost\":\"probcm.tmc.edu\",\"userName\":\"enboree\"}}

		or for both kinds of variables

   {\"genbConfig\":{\"dbHost\":\"probcm.tmc.edu\",\"userName\":\"enboree\"},\"env\":{\"BLAH\":\"blah2\"}}

	COMMAND LINE ARGUMENTS:
            -j or --jsonString    => This flag is required and should be followed by the CGI escaped jsonString as described above
            
         USAGE:
          ./genbConfigRewriter.rb -j CGI.Escape(JSONSTRING)"
   exit(2);
end
  



optsArray = [['--help', '-h', GetoptLong::NO_ARGUMENT],
	    ['--jsonString', '-j', GetoptLong::REQUIRED_ARGUMENT]]
progOpts = GetoptLong.new(*optsArray)
optsHash = progOpts.to_hash

if(optsHash.key?('--help')) then
  usage()
end
unless(progOpts.getMissingOptions().empty?)
  usage("USAGE ERROR: some required arguments are missing")
end
      
if(optsHash.empty?) then
  usage()
end




  jsonString = optsHash['--jsonString']
  contextHash = JSON.parse(jsonString)
  genbConfHash = contextHash["genbConfig"]
  inputFileHandle = File.open(ENV["GENB_CONFIG"],"r")
  oldGenbConfig = inputFileHandle.read
  inputFileHandle.close
  newGenbConfig = oldGenbConfig
  genbConfHash.each_key{|key| newGenbConfig = newGenbConfig.sub(/^\s*#{key}\s*=\s*[^\n]+/,"#{key}=#{genbConfHash[key]}")}
  outputFileHandle = File.open("./genboree.config","w")
  outputFileHandle.puts newGenbConfig
  outputFileHandle.close


