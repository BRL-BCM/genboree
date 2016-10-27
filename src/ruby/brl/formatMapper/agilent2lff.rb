#!/usr/bin/env ruby
=begin
=end
 
# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'						# for GetoptLong class (command line option parse)
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'brl/util/logger'
require 'cgi'
require 'brl/genboree/genboreeUtil'
include BRL::Util

module BRL ; module FormatMapper
        FATAL, OK, OK_WITH_ERRORS, FAILED, USAGE_ERR = 1,0,10,20,16
        MAX_NUM_ERRS = 25
        MAX_EMAIL_ERRS = 25
        MAX_EMAIL_SIZE = 30_000
               
   class AgilentToLff
     attr_accessor :errMsgs

     def initialize(optsHash)
       @aFile = optsHash['--aFile']
       @baseFileName = @aFile.strip.gsub(/\.txt$/, '')
       if(optsHash.key?('--outputFile'))
         @outputFile = optsHash['--outputFile']
       else
         @outputFile = @baseFileName + '.lff'
       end

       if optsHash.key?('--class')         
         @lffClass = optsHash['--class']
       else
         @lffClass = "Agilent"
       end

       if optsHash.key?('--type')
         @lffType = optsHash['--type']
       else
         @lffType = "Agilent"
       end

       if optsHash.key?('--filenameAsType')         
         type = CGI.escape(File.basename(@baseFileName))
         if (type =~ /[^\.]\.(.+)/)
           @lffType = $1
         else
           @lffType = CGI.escape(File.basename(@baseFileName))
         end
       end

       if optsHash.key?('--minProbes')
 	 @minProbes = CGI.escape(optsHash['--minProbes'])
       end

       if optsHash.key?('--subtype')
         @lffSubType = optsHash['--subtype']
       else
         @lffSubType = "Probe"
       end

       @raw = !(optsHash.key?('--raw'))
       @histogram = optsHash.key?('--histogram')
       @gainloss = optsHash['--gainloss']
       @throttle = optsHash['--throttle']

       if optsHash.key?('--segmentThresh')
         @segThresh = true
         if optsHash['--segmentThresh'] != "" && !(optsHash['--segmentThresh'].nil?)
           @segment = optsHash['--segmentThresh']
         else
           @segment = 0.10
         end
       end

       if optsHash.key?('--segmentStddev')
         @segStddev = true;
         if optsHash['--segmentStddev'] != "" && !(optsHash['--segmentStddev'].nil?)
           @segment = optsHash['--segmentStddev']
         else
           @segment = 2
         end
       end       
       
       @doGzip = false
     end
     

     def convert()
       BRL::Util.setLowPriority()
       @features = Array.new
       @nameHash = Hash.new
       @position = nil
       @probeName = nil
       @logRatio = nil
       @savedFeatures = Array.new      
       @duplicates = Hash.new
       @scores = Hash.new
       preProcess()

       # @nameHash.each{ |k, v|
       #   puts "#{k} -> #{v}"
       # }


       reader = BRL::Util::TextReader.new(@aFile)

       # declare needed writers
       rawFile = "#{@outputFile}.raw.lff"
       rawWriter = BRL::Util::TextWriter.new(rawFile, "w+", @doGzip)
       if @histogram
         histFile = "#{@outputFile}.hist.lff"
         histWriter = BRL::Util::TextWriter.new(histFile, "w+", @doGzip)
       end
       if !(@gainloss.nil?)
         glFile = "#{@outputFile}.gl.lff"
         glWriter = BRL::Util::TextWriter.new(glFile, "w+", @doGzip)
       end
       
       counter = 1;

       # Process line-by-line
       outputArray = Array.new
       reader.each { |line|         
         line.strip!
         line = line.gsub(/\015/, "")     #remove ^M windows characters'   
         data = line.split(/\t/)

         if (line =~ /^DATA/)
           if (data[@position]=~/(chr\w+):(\d+)-(\d+)/)
             pchr = $1;
             pstart = $2;
             pend = $3;

             # deal with duplicates
             lineKey = "#{data[@probeName]}#{pchr}#{pstart}#{pend}"
             
             if (@nameHash[lineKey] == 1) #only 1, output normally
               outputArray[0]  =  "#{@lffClass}"
               outputArray[1]  = "#{data[@probeName]}"
               outputArray[2]  = "#{@lffType}"
               outputArray[3]  = "#{@lffSubType}"
               outputArray[4]  = "#{pchr}"
               outputArray[5]  = "#{pstart}"
               outputArray[6]  = "#{pend}"
               outputArray[7]  = "+"
               outputArray[8]  = "."
               outputArray[9]  = "#{data[@logRatio]}"
               outputArray[10] = "."
               outputArray[11] = "."
               outputArray[12] = ""
               
               #output select set of features
               @savedFeatures.each{ |feat|
                 unless feat.nil?
                   data[feat] = data[feat].gsub(/\;/,":")
                   data[feat] = data[feat].gsub(/\=/,"-")
                   outputArray[12] += "#{@features[feat]}=#{data[feat]}; "
                 end
               }
               
             # output all features 
#             1.upto(data.length){ |i|
#               if !(data[i].nil?)
#                 data[i] = data[i].gsub(/\;/,":")
#                 data[i] = data[i].gsub(/\=/,"-")
#               end
#               outputArray[12] += "#{@features[i]}=#{data[i]}; "
#             }
             
               #output raw data             
               #puts "printing: #{outputArray}"
               printLff(outputArray,rawWriter)
               
               #print a gain/loss track, if specified
               doGainLoss(outputArray, glWriter)
               #print two histogram tracks, if specified
               doHistogram(outputArray, histWriter)

             else #this is a duplicate
               lineKey = "#{data[@probeName]}#{pchr}#{pstart}#{pend}"
#               puts ""
#               puts lineKey
#               puts "nameHash: #{@nameHash[lineKey]}"
#               if (@duplicates.key?(lineKey))
#                 puts "duplicates: #{@duplicates[lineKey]}"
#                 puts "duplicates+1: #{@duplicates[lineKey]+1}"
#               end

               if !(@duplicates.key?(lineKey)) #first instance of dup
#                 puts "-----1"
                 @duplicates[lineKey] = 1
                 @scores[lineKey] = data[@logRatio]
               elsif (@nameHash[lineKey] > (@duplicates[lineKey]+1))#middle instance of dup
#                 puts "-----2"
                 @scores[lineKey] =  @scores[lineKey].to_f + data[@logRatio].to_f
                 @duplicates[lineKey] += 1 
               elsif (@nameHash[lineKey] == @duplicates[lineKey]+1) #last instance of dup
#                 puts "-----3"
                 #puts "fixing duplicate: #{lineKey}"
                 @scores[lineKey] =  @scores[lineKey].to_f + data[@logRatio].to_f
                 @duplicates[lineKey] += 1 
                 
                 #do output
                 outputArray[0]  = "#{@lffClass}"
                 outputArray[1]  = "#{data[@probeName]}"
                 outputArray[2]  = "#{@lffType}"
                 outputArray[3]  = "#{@lffSubType}"
                 outputArray[4]  = "#{pchr}"
                 outputArray[5]  = "#{pstart}"
                 outputArray[6]  = "#{pend}"
                 outputArray[7]  = "+"
                 outputArray[8]  = "."
                 outputArray[9]  = "#{(@scores[lineKey]/@duplicates[lineKey])}"
                 outputArray[10] = "."
                 outputArray[11] = "."
                 outputArray[12] = ""
                 #output select set of features
                 @savedFeatures.each{ |feat|
                   unless feat.nil?
                     data[feat] = data[feat].gsub(/\;/,":")
                     data[feat] = data[feat].gsub(/\=/,"-")
                     outputArray[12] += "#{@features[feat]}=#{data[feat]}; "
                   end
                 }     
                 #output raw data             
                 printLff(outputArray,rawWriter)
                 
                 #print a gain/loss track, if specified
                 doGainLoss(outputArray, glWriter)
                 #print two histogram tracks, if specified
                 doHistogram(outputArray, histWriter)
               end
              
             end
             #else  # NOT (data[position]=~/(chr\w+):(\d+)-(\d+)/)
             # this is expected, there are some control probes built in that should not be 
             # converted to lff format
             # $stderr.puts "DATA Line #{data[1]} skipped - must be a control probe (no genomic coordinates)"
           end  
           
         end #if(line =~ /^DATA/)
         
         if (!(@throttle.nil?))
           if counter % 5000 == 0
             sleep(2)
           end
         end
         counter = counter+=1;
         
       } #each line
       reader.close()
       rawWriter.close()

       catCmd = "cat "
       if @raw
         catCmd = catCmd + "#{rawFile} "
       end
       if @histogram
         catCmd = catCmd + "#{histFile} "
         histWriter.close()
       end
       if !(@gainloss.nil?)
         catCmd = catCmd + "#{glFile} "
         glWriter.close()
       end



       #print segmented track, if specified
       if (!(@segment.nil?))
         segmentFile = "#{@outputFile}.seg.lff"

	if (@minProbes.nil?)
           if !(@segThresh.nil?)
             `segmentACGH.rb -f #{rawFile} -o #{segmentFile} -r #{@segment} -c #{@lffClass} -t #{@lffType} -s #{@lffSubType}Seg 2>#{@outputFile}.seg.err`
           else #must be stddev method
             `segmentACGH.rb -f #{rawFile} -o #{segmentFile} -e #{@segment} -c #{@lffClass} -t #{@lffType} -s #{@lffSubType}Seg 2>#{@outputFile}.seg.err`
           end
 	else #(we do pass probes arg)
           if !(@segThresh.nil?)
             `segmentACGH.rb -f #{rawFile} -o #{segmentFile} -r #{@segment} -c #{@lffClass} -t #{@lffType} -s #{@lffSubType}Seg -p #{@minProbes} 2>#{@outputFile}.seg.err`
           else #must be stddev method
             `segmentACGH.rb -f #{rawFile} -o #{segmentFile} -e #{@segment} -c #{@lffClass} -t #{@lffType} -s #{@lffSubType}Seg -p #{@minProbes} 2>#{@outputFile}.seg.err`
           end
	end	


         # if we have segment output
         if (!(File.zero? segmentFile))
           catCmd = catCmd + "#{segmentFile} "
         # else give them a little warning
         else 
#           if (@histogram || !(@gainloss.nil?))
             $stderr.puts "\n\n****************************************\n
                    WARNING:  No segments found above the log-ratio threshold specified.  Nothing was uploaded.\n
                    ****************************************\n\n"
#           else
#             raise  "\n\n****************************************\n
#                    WARNING:  No segments found above the log-ratio threshold specified.  Nothing was uploaded.\n
#                   ****************************************\n\n"           
#           end
         end
       end


       #merge the tracks into one big LFF for upload       
       catCmd = "#{catCmd}> #{@outputFile}"
       puts "calling: #{catCmd}"
       `#{catCmd}`

     end  #convert()     


     
     def printLff(outputArray,theWriter)
       0.upto(outputArray.length-2){ |i|
         theWriter.print "#{outputArray[i]}\t"
       }
       theWriter.print "#{outputArray[outputArray.length-1]}\n"
     end

     def doHistogram(outputArray, histWriter)
       if @histogram
         outputArray2 = outputArray.dup
         #color appropriately, rename track, print
         if (outputArray2[9].to_f >= 0)
           outputArray2[0] = "Histogram"
           outputArray2[12] = "annotationColor=green;";
           outputArray2[3] += "Gain"
           printLff(outputArray2,histWriter)
         else #if loss
           outputArray2[0] = "Histogram"
           outputArray2[12] = "annotationColor=red;";
           outputArray2[3] += "Loss"
           outputArray2[9] = outputArray2[9].to_f.abs
           printLff(outputArray2,histWriter)
         end          
       end  
     end

     def doGainLoss(outputArray, glWriter)
       if !(@gainloss.nil?)
         outputArray2 = outputArray.dup
         #if above threshold
         if (outputArray2[9].to_f).abs > @gainloss.to_f               
           outputArray2[3] += "GL"
           #color appropriately               
           if (outputArray2[9].to_f > 0)
             outputArray2[12] = "annotationColor=green;";
           else #if loss
             outputArray2[12] = "annotationColor=red;";
           end       
           printLff(outputArray2,glWriter)
         end             
       end
     end


     def preProcess()
       foundFeats = false
       reader2 = BRL::Util::TextReader.new(@aFile)       
       reader2.each { |line|
         line.strip!

         if line=~/FEATURES/
           foundFeats = true;
           line = line.gsub(/\015/, "")     #remove ^M windows characters'
           data = line.split(/\t/)
           @features = data;

           0.upto(data.length-1){ |i|
             @position = i  if (data[i]=~/SystematicName/)             
             @probeName = i if (data[i]=~/ProbeName/)
             @logRatio = i if (data[i]=~/^LogRatio$/)
             @savedFeatures[0] = i if (data[i]=~/Description/)
             @savedFeatures[1] = i if (data[i]=~/LogRatioError/)
             @savedFeatures[2] = i if (data[i]=~/PValueLogRatio/)
             # @savedFeatures[3] = i if (data[i]=~/ProbeUID/)
             # @savedFeatures[4] = i if (data[i]=~/GeneName/)

           }
           
           if @position.nil? 
             raise "ERROR: Could not find required field \"SystematicName\"\n"                  
           end
           if @probeName.nil? 
             raise "ERROR: Could not find required field \"ProbeName\"\n"
           end  
           if @logRatio.nil?
             raise "ERROR: Could not find required field \"LogRatio\"\n"
           end

         #hash all of the lines to find duplicates
         elsif ((line =~ /^DATA/) && (foundFeats == true))
           data = line.split(/\t/)
           if (data[@position]=~/(chr\w+):(\d+)-(\d+)/)
             pchr = $1;
             pstart = $2;
             pend = $3;
             pname = data[@probeName]

             lineKey = "#{pname}#{pchr}#{pstart}#{pend}"

             if (@nameHash.key?(lineKey))
               @nameHash[lineKey]+=1
             else
               @nameHash[lineKey]=1           
             end
           end
         end
       }
       reader2.close()
     end


     def AgilentToLff.processArguments()
       optsArray =	[	['--aFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                                ['--outputFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--class', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--type', '-t', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--subtype', '-s', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--histogram', '-i', GetoptLong::NO_ARGUMENT],
                                ['--gainloss', '-g', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--segmentThresh', '-n', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--segmentStddev', '-e', GetoptLong::OPTIONAL_ARGUMENT],
				['--minProbes', '-p', GetoptLong::OPTIONAL_ARGUMENT],
				['--raw', '-w', GetoptLong::NO_ARGUMENT],
                                ['--throttle', '-r', GetoptLong::NO_ARGUMENT],
                                ['--filenameAsType', '-q', GetoptLong::NO_ARGUMENT],
                                ['--help', '-h', GetoptLong::NO_ARGUMENT]
                        ]
       progOpts = GetoptLong.new(*optsArray)
       optsHash = progOpts.to_hash
       AgilentToLff.usage() if(optsHash.empty? or optsHash.key?('--help'))
       return optsHash
     end
     
     def AgilentToLff.usage(msg='')
       puts "\n#{msg}\n" unless(msg.empty?)
       puts " 

  PROGRAM DESCRIPTION:
    Converts a Agilent output file to a Genboree-compliant LFF file.

    It is assumed that the file contains a FEATURES line with all data fields
    defined.  All data lines should begin with DATA.  The following three fields
    are required to be present in each DATA line:

        - ProbeName (will be used in the 'name' field of the lff file)
        - LogRatio  (will be used in the 'score' field of the lff file)
        - SystematicName:
            - should be in the format 'chr#:start-end' and should define
              the probe's genomic position
            - these coordinates should be referenced to the same genome 
              build as the database you're uploading the data into 
             (i.e. hg18/build 36)


    Additional fields will be output as attribute-value pairs.  Only the input 
    file need be specified and each data line will be converted  into one LFF 
    record using defaults for class, type, subtype and output file.

    The default is to output one track with all probes.  Using the appropriate
    command line arguments, additional tracks can also be created, with one of 
    the following types:

         Histogram -    produces two additional tracks, gain and loss, with log 
                        values recalculated as absolute values - used for 
                        displaying bar graphs.
         Gain/Loss -    produces an additional track containing probes with an 
                        absolute value that exceeds the given log ratio threshold.  
         Segmentation - produces one additional track, containing segmented blocks
                        of gain and loss.  The resulting track will contain only
                        regions with a mean log ratio value higher than the
                        threshold specified.

         
    COMMAND LINE ARGUMENTS:
      -f    => Agilent file to convert to LFF.
      -o    => [optional] Override the output file location.
               Default is the aFile.lff, minus the extension if present.
      -c    => [optional] Override the LFF class value to use.
               Defaults to 'Agilent'.
      -t    => [optional] Override the LFF type value to use.
               Defaults to 'Agilent'.
      -s    => [optional] Override the LFF subtype value to use.
               Defaults to 'Probe'.
      -g    => [optional] Produce Gain/Loss track using this log ratio threshold
      -i    => [optional flag] Produce two Histogram tracks.
      -n    => [optional] Run segmentation on the data using this absolute
               threshold (Defaults to '0.10')
      -e    => [optional] Run segmentation on the data using this stddev
               threshold (Defaults to '2')
      -p    => [optional] Require that a segments be composed of at least
               this many probes to be output (algorithmic default is 2)
      -w    => [optional flag] disable output of raw data to final file
      -r    => [optional flag] throttle the speed of processing such
               that it pauses every 5k lines (for genb. server use only)
      -q    => [optional flag] use filename as the 'Type' name.  For use
               in Auto-upload. (KCL1234.lff -> type: KCL1234)  Overrides
               -t type argument
      -h    => [optional flag] Output this usage info and exit

    USAGE:
    agilent2lff.rb  -f my agilentData.txt
	"
       exit(BRL::FormatMapper::USAGE_ERR)
     end #usage
     
   end # class AgilentToLff
   
 end ; end

# ##############################################################################
# MAIN
# ##############################################################################
optsHash = BRL::FormatMapper::AgilentToLff::processArguments()
converter = BRL::FormatMapper::AgilentToLff.new(optsHash)
puts `date`
converter.convert()
puts `date`
exit()
