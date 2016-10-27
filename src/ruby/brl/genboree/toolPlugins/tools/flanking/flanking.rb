#!/usr/bin/env ruby
=begin
=end


# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'                                            # for GetoptLong class (command line option parse)
require 'brl/util/util'                                 # for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/util/logger'
require 'brl/genboree/genboreeUtil'
include BRL::Util

module BRL ; module FormatMapper
        FATAL, OK, OK_WITH_ERRORS, FAILED, USAGE_ERR = 1,0,10,20,16
        MAX_NUM_ERRS = 25
        MAX_EMAIL_ERRS = 25
        MAX_EMAIL_SIZE = 30_000

   class Flanking
     attr_accessor :errMsgs

     def initialize(optsHash)
       @outputFile = optsHash['--outputFile']
       @segmentFile = optsHash['--segmentFile']
       @baseFileName = @segmentFile.strip.gsub(/\.lff$/, '')
       @otherTrackNames = optsHash['--otherOperandTracks']
       @radius = optsHash.key?('--fuzzyRadius') ? optsHash['--fuzzyRadius'].to_i : 0
       @lffFiles = optsHash['--lffFiles']
       @newTrackName = optsHash['--newTrackName']
       @oneEnd = optsHash.key?('--oneEnd')
       @nonFlanking = optsHash.key?('--nonFlanking')
       @matchAll = optsHash.key?('--matchAll')
       @doGzip = false
       if optsHash.key?('--class')
         @lffClass = optsHash['--class']
       else
         if (!(@nonFlanking))
           @lffClass = "Flanked"
         else
           @lffClass = "NonFlanked"
         end
       end

     end


   def findFlanking()
     BRL::Util.setLowPriority()
     # make a reader
     reader = BRL::Util::TextReader.new(@segmentFile)

     tempFile = "#{@baseFileName}.ends.lff"
     tempWriter = BRL::Util::TextWriter.new(tempFile, "w+", @doGzip)

     # Process line-by-line
     outputArray = Array.new
     names = Array.new
     data = Array.new
     startPos = Hash.new
     endPos = Hash.new
     counter = 0

     reader.each { |line|
       line.strip!
       next if(line =~ /^\s*#/ or line =~ /^\s*\[/ or line !~ /\S/)
       data = line.split(/\t/)
       dEnd = data[6]
       # append some completely improbable string to make each annotation unique
       names[counter] = data[1] + "$%^$" + counter.to_s

       #store start/stop for later 

       #(only needed if looking for yes one end matches or Non-2 end)
       if (((@oneEnd) && (!@nonFlanking)) || (!@oneEnd && @nonFlanking))
         startPos[names[counter]] = data[5]
         endPos[names[counter]] = data[6]
       end

       #print start annotation
       data[1] = "#{names[counter]}&*1"
       data[6] = data[5].to_i+1
       printLff(data,tempWriter)

       #print end annotation
       data[1] = "#{names[counter]}&*2"
       data[5] = dEnd.to_i - 1
       data[6] = dEnd
       printLff(data,tempWriter)
       counter += 1
     }

     type = data[2]
     subtype = data[3]

     reader.close()
     tempWriter.close()


     #are we matching all tracks?
     strAll = ""
     if (@matchAll)
       strAll = " -a"
     end

     if (@nonFlanking)
       #do NON-intersect
       `lffNonIntersect.rb -f #{CGI.escape(type)}:#{CGI.escape(subtype)} -o #{CGI.escape(@baseFileName)}.intersect.lff -s #{CGI.escape(@otherTrackNames)} -l #{CGI.escape(@lffFiles)},#{CGI.escape(@baseFileName)}.ends.lff -c #{CGI.escape(@lffClass)} -n #{CGI.escape(@newTrackName)} -r #{@radius} -V#{strAll}`
##      `lffNonIntersect.rb -f #{type}:#{subtype} -o #{@baseFileName}.intersect.lff -s #{@otherTrackNames} -l #{@lffFiles},#{@baseFileName}.ends.lff -c #{@lffClass} -n #{@newTrackName} -r #{@radius} -V#{strAll}`
     else       
       #do intersect
       `lffIntersect.rb -f #{CGI.escape(type)}:#{CGI.escape(subtype)} -o #{CGI.escape(@baseFileName)}.intersect.lff -s #{@otherTrackNames} -l #{CGI.escape(@lffFiles)},#{CGI.escape(@baseFileName)}.ends.lff -c #{CGI.escape(@lffClass)} -n #{CGI.escape(@newTrackName)} -r #{@radius} -V#{strAll}`
##      `lffIntersect.rb -f #{type}:#{subtype} -o #{@baseFileName}.intersect.lff -s #{@otherTrackNames} -l #{@lffFiles},#{@baseFileName}.ends.lff -c #{@lffClass} -n #{@newTrackName} -r #{@radius} -V#{strAll}`
     end

     # make a second reader
     reader2 = BRL::Util::TextReader.new("#{@baseFileName}.intersect.lff")
     hashNames = Hash.new

     #make the final output writer
     writer = BRL::Util::TextWriter.new(@outputFile, "w+", @doGzip)

     reader2.each { |line|
       line.strip!
       data = line.split(/\t/)
       hashNames[data[1]] = line
     } #end each
     
     if ((!(@oneEnd) && !(@nonFlanking)) || (@oneEnd && @nonFlanking)) # match both ends (N1, F2)
       names.each{ |name|
         if (hashNames.has_key?("#{name}&*1")) && (hashNames.has_key?("#{name}&*2"))
           startLine = (hashNames["#{name}&*1"].split(/\t/))
           endLine = (hashNames["#{name}&*2"].split(/\t/))
           startLine[6] = endLine[6]
           #remove completely improbable string
           startLine[1] = name.gsub(/\$\%\^\$\d+/,"")
           startLine = handleMissingFields(startLine)
           printLff(startLine,writer)
         end
       }
     else #only must match one end  (N2, F1)
       names.each{ |name|
         #if front matched
         if (hashNames.has_key?("#{name}&*1"))
           startLine = (hashNames["#{name}&*1"].split(/\t/))
           startLine[6] = endPos[name]
           #remove completely improbable string
           startLine[1] = name.gsub(/\$\%\^\$\d+/,"")
           startLine = handleMissingFields(startLine)
           printLff(startLine,writer)
           #if end matched
         elsif(hashNames.has_key?("#{name}&*2"))
           startLine = (hashNames["#{name}&*2"].split(/\t/))
           startLine[5] = startPos[name]
           #remove completely improbable string
           startLine[1] = name.gsub(/\$\%\^\$\d+/,"")          
           startLine = handleMissingFields(startLine)
           printLff(startLine,writer)
         end
       }
     end
     
     reader2.close()
     writer.close()
   end  #findFlanking()

   #handle missing fields, add flanking attribute
   def handleMissingFields(line)
     if (line[10].nil?)
       line[10]="."
     end
     if (line[11].nil?)
       line[11]="."
     end
     if (@nonFlanking)
       if !(line[12].nil?)
         line[12] << "flanked=false;"
       else
         line[12] = "flanked=false;"
       end
     else
       if !(line[12].nil?)
         line[12] << "flanked=true;"
       else
         line[12] = "flanked=true;"
       end
     end
     return line
   end



   def printLff(outputArray,theWriter)
     0.upto(outputArray.length-2){ |i|
       theWriter.print "#{outputArray[i]}\t"
     }
     theWriter.print "#{outputArray[outputArray.length-1]}\n"
   end


   def Flanking.processArguments()
     optsArray =[
                 ['--segmentFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                 ['--otherOperandTracks', '-s', GetoptLong::REQUIRED_ARGUMENT],
                 ['--outputFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
                 ['--lffFiles', '-l', GetoptLong::REQUIRED_ARGUMENT],
                 ['--newTrackName', '-n', GetoptLong::REQUIRED_ARGUMENT],
                 ['--fuzzyRadius', '-r', GetoptLong::OPTIONAL_ARGUMENT],
                 ['--class', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                 ['--oneEnd', '-e', GetoptLong::NO_ARGUMENT],
                 ['--nonFlanking', '-x', GetoptLong::NO_ARGUMENT],
                 ['--matchAll', '-a', GetoptLong::NO_ARGUMENT],
                 ['--help', '-h', GetoptLong::NO_ARGUMENT]
                ]


     progOpts = GetoptLong.new(*optsArray)
     optsHash = progOpts.to_hash
     Flanking.usage() if(optsHash.empty? or optsHash.key?('--help'))
     return optsHash
   end


   def Flanking.usage(msg='')
     puts "\n#{msg}\n" unless(msg.empty?)
     puts "

  PROGRAM DESCRIPTION:

       Finds annotations in the first track that are flanked by annotations in
       the addtional tracks given.  In theory, useful for explaining regions of
       gain or loss by finding segments that have flanking segmental duplications
       or low-copy repeats.

       Annotations from the first track are considered flanked if their endpoints
       intersect an annotation from the second track(s).  The default is to
       require both ends to have a match, but the -e option can be used to require
       only one end.


    COMMAND LINE ARGUMENTS:
      -f    => Name of the input lff file.  This file should contain annotations
               from one track, which will be precipitated out if they are flanked
               by segments from the other track(s)
      -s    => Name(s) of the second operand track(s). If you specify more than
               one, then an annotation in the first track flanked by
               annotation in *any* of these tracks will be output.
      -l    => A list of LFF files where the second operand track annotations
               can be found to work on. Annotations with irrelevant track names
               will be ignored
      -o    => Name of output file in which to put data
      -c    => [optional] Override the LFF class value to use.
               Defaults to 'Flanked' (or 'NonFlanked' if using -x)
      -n    => New track name for annotations that are flanked.
               Should be in form of type:subtype.
      -r    => [optional] Add this radius to make annotations a bit 'larger'
               when considering overlap. Thus, the annotations may not strictly
               overlap, but may be really close to overlapping. Default is 0.
      -a    => [optional] This will require flanking intersections from 'ALL'
               second operand tracks rather than just any track.
      -e    => [optional flag] require only one end of the annotation to have an
               intersection
      -x    => [optional flag] use the inverse process, make the tool return all
               'non-flanked' annotations
      -V    => [optional flag] Turns OFF lff record validation. For use when
               Genboree is calling this program. Saves time, in theory.
      -h    => [optional flag] Output this usage info and exit

    USAGE:
    flanking.rb -f segments.lff -s Segmental:Duplications,LCR:Track -l \\
    myData.lff -o outputFile.lff -c Flanking -n Flanked:Annos
        "
       exit(BRL::FormatMapper::USAGE_ERR)
     end #usage

   end # class Flanking

 end ; end

# ##############################################################################
# MAIN
# ##############################################################################
optsHash = BRL::FormatMapper::Flanking::processArguments()
converter = BRL::FormatMapper::Flanking.new(optsHash)
converter.findFlanking()

exit()
