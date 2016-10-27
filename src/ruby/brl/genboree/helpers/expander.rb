#!/usr/bin/env ruby
require 'pathname'
require 'open4'
require 'brl/util/util'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'
require 'brl/util/expander'

module BRL ; module Genboree ; module Helpers

#############################################################################
# This class is implemented to replace the Expander class from Java
# It is used to uncompress any type of compressed file
#
# Usage:
# expanderObj = Expander.new(fullPathToCompFile)
# expanderObj.extract()
# fullPathToUncompFile = expanderObj.uncompressedFileName
#
# Notes:
#  - If the file is already extracted, as in, it is not a compressed file,
#    then uncompressedFileName will be set to compressedFileName
#  - The compressed file remains on disk so it is up to you to clean it up.
#  - If the compressed file does not have the expected extension.  It will be appended.
#    and the uncompressed file will have the input name so be aware,
#    the compressed input file name becomes the uncompressed file name
#    and your compressed file gets renamed. ( See setFileNames() )
#  - To extract tar archived files which have been compresssed using any of the supported compression formats, instantiate using tarArchive=true as second argument
#############################################################################
class Expander < BRL::Util::Expander

end
end ; end ; end;# module BRL ; module Genboree ; module Helpers

# --------------------------------------------------------------------------
# MAIN (command line execution begins here)
# --------------------------------------------------------------------------
begin
  if($0 and File.exist?($0))
    # In case symlink chain, get ultimate file paths
    fileBeingRun = Pathname.new($0).realpath.to_s
    thisFile = Pathname.new(__FILE__).realpath.to_s
    if(!fileBeingRun.rindex('brl').nil?)
      fileBeingRun = fileBeingRun[fileBeingRun.rindex('brl'), fileBeingRun.size]
    end
    if(!(thisFile.rindex('brl').nil?)) # on the server
      thisFile = thisFile[thisFile.rindex('brl'),  thisFile.size]
    else
      raise "SERVER MISCONFIGURED! (#{thisFile} should by properly linked to $RUBYLIB area."
    end
    $stderr.puts "DEBUG: fileBeingRun = #{fileBeingRun.inspect} ; thisFile = #{thisFile.inspect}"
    if(fileBeingRun == thisFile)
      # process args
      optsHash = BRL::Util::Expander::processArguments()
      # instantiate
      expander = BRL::Util::Expander.new(optsHash['--file'])
      if(optsHash['--outputFile'])
        expander.forcedOutputFileName = optsHash['--outputFile']
      end
      $stderr.puts "EXPANDER instantiated" if(optsHash.key?('--verbose'))
      # call
      inflateOk = expander.extract()
      if(inflateOk)
        $stdout.print expander.uncompressedFileName
        if(optsHash.key?('--removeIntFiles'))
          expander.removeIntermediateCompFiles()
          $stderr.puts("file.dirname: #{File.dirname(optsHash['--file'])}")
          `mv #{expander.tmpDir}/* #{File.dirname(optsHash['--file'])}`
          `rm -rf #{expander.tmpDir}`
        end
        exitVal = 0
      else
        raise "ERROR: could not expand file. Expander object:\n    #{expander.inspect}"
      end
    end
  end
rescue => err
  errTitle =  "(#{$$}) #{Time.now()} Expander - FATAL ERROR: Couldn't run the expansion command. Exception listed below."
  errstr   =  "\n   The error message was: #{err.message}\n"
  errstr   += "\n   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
  $stderr.puts errTitle + errstr
  exitVal = 1
end
