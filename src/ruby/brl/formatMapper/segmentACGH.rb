#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'			# for GetoptLong class (command line option parse)
require 'brl/util/util'			# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil'         # For TextReader/Writer classes
require 'brl/util/logger'
require 'rsruby'
require 'cgi'
include BRL::Util


module BRL ; module FormatMapper

   class ACGHsegment
     attr_accessor :errMsgs

     def initialize(optsHash)
       @aFile = optsHash['--aFile']
       @baseFileName = @aFile.strip.gsub(/\.lff$/, '')
       if(optsHash.key?('--outputFile'))
         @outputFile = optsHash['--outputFile']
       else
         @outputFile = @baseFileName + 'Segments.lff'
       end

       if optsHash.key?('--threshold')
         @threshold = optsHash['--threshold']
       end

       if optsHash.key?('--minProbes')
         @minProbes = optsHash['--minProbes']
       end

       if optsHash.key?('--devThreshold')
         @devThreshold = optsHash['--devThreshold']
       end

       if !(@devThreshold.nil?) && !(@threshold.nil?)
         raise "ERROR: You can only choose one thresholding method! (stddev or fixed value)"
       end

       if optsHash.key?('--class')
         @lffClass = CGI.escape(optsHash['--class'])
       else
         @lffClass = "aCGH"
       end

       if optsHash.key?('--type')
         @lffType = CGI.escape(optsHash['--type'])
       else
         @lffType = "Segmented"
       end

       if optsHash.key?('--subtype')
         @lffSubType = CGI.escape(optsHash['--subtype'])
       else
         @lffSubType = "Blocks"
       end
       @doGzip = false
     end


    def convert()
      BRL::Util.setLowPriority()

      reader = BRL::Util::TextReader.new(@aFile)
      newFile = "#{@outputFile}.strip"
      stripWriter = BRL::Util::TextWriter.new(newFile, "w+", @doGzip)

      stripArray = Array.new
      logArray = Array.new

      reader.each { |line|
        line.strip!
        next if(line !~ /\S/ or line =~ /^\s*(?:#|\[)/)
        line.gsub!(/\015/, "")     #remove ^M windows characters'
        data = line.split(/\t/)
        0.upto(9) { |i|
          stripArray[i] = data[i]
        }

        if !(@devThreshold.nil?)
          logArray.push(data[9].to_f)
        end

        @inputType = data[2]
        @inputSubType = data[3]

        # R code expects 13 files...what if fewer?
        if(stripArray.length == 10)
          stripArray.push('.', '.', '.')
        elsif(stripArray.length == 12)
          stripArray.push('.')
        elsif(stripArray.length > 13)
          stripArray = stripArray[0,13]
        end
        printLff(stripArray, stripWriter)
      }

      if !(@devThreshold.nil?)
        stddev = standard_deviation(logArray)
        $stderr.puts "stddev = #{stddev}"
        meanVal = mean(logArray)
        $stderr.puts "mean = #{meanVal}"
        # $stderr.puts "devThresh = #{@devThreshold}"
        puts "stddev*thresh = #{stddev*(@devThreshold.to_f)}"
        thresholdHi = meanVal + stddev*(@devThreshold.to_f)
        thresholdLow = meanVal - stddev*(@devThreshold.to_f)
      else
        @threshold = abs(@threshold) if (@threshold.to_f < 0)
        thresholdHi = @threshold.to_f
        thresholdLow = (@threshold.to_f * -1)
      end
      $stderr.puts "thresholdHi = #{thresholdHi}"
      $stderr.puts "thresholdLow = #{thresholdLow}"


      stripWriter.close()
      reader.close()

      @segFile = "#{@outputFile}.segs.lff"
      segWriter = BRL::Util::TextWriter.new("#{@segFile}", "w+", @doGzip)

      outputArray = Array.new
      outputArray[0] = @lffClass
      outputArray[2] = @lffType
      outputArray[3] = @lffSubType
      outputArray[7] = "+"
      outputArray[8] = "."

      # invoke R interpreter
      r = RSRuby.instance

      # we need this library
      r.library('DNAcopy')

      # read in the file
      #puts "R:  a = read.table('#{@aFile}', header=FALSE, sep='\t')"
      rcmd = "a = read.table('#{newFile}', header=FALSE, sep='\t', comment.char = \"\", quote=\"\")"
      r.eval_R(rcmd)
       # $stderr.puts c
      #convert to a CNA object
      r.eval_R("CNA.object <-CNA( genomdat = a[,10], chrom = a[,5], maploc = a[,6],data.type = 'logratio')")
      # $stderr.puts "A------------------"
      # $stderr.puts a.inspect
      # smooth the data
       r.eval_R("smoothed.CNA.object <-smooth.CNA(CNA.object)")
      # $stderr.puts "B------------------"
      # $stderr.puts b.inspect
      # $stderr.puts "Results------------------"
      # run the segmentation algorithm
       results = r.eval_R("segment.smoothed.CNA.object <-segment(smoothed.CNA.object, verbose=1)")
      # $stderr.puts results.inspect

#      results["output"].each{ |k,v|
#        $stderr.puts "k: #{k} v:#{v}"
#      }

      #parse and print the results
       counter = 1
      #more than one segment, retunred in array
      if(results["output"]["seg.mean"].class==Array)
        0.upto(results["output"]["chrom"].length-1){ |i|

          #only output if mean above threshold
          if (results["output"]["seg.mean"][i].to_f > thresholdHi) ||
             (results["output"]["seg.mean"][i].to_f < thresholdLow)
            outputArray[1] = "segment_#{counter}"
            outputArray[4] = results["output"]["chrom"][i]
            outputArray[5] = results["output"]["loc.start"][i]
            outputArray[6] = results["output"]["loc.end"][i]
            outputArray[9] = results["output"]["seg.mean"][i]
            outputArray[10]= "."
            outputArray[11]= "."
            if results["output"]["seg.mean"][i].to_f < 0
              outputArray[12]= "annotationColor=red; length=#{outputArray[6]-outputArray[5]};"
            else
              outputArray[12]= "annotationColor=green; length=#{outputArray[6]-outputArray[5]};"
            end
            printLff(outputArray,segWriter)
            counter += 1
          end
        }
      else #only one segment returned
        #only output if mean above threshold
        if (results["output"]["seg.mean"].to_f > thresholdHi) ||
           (results["output"]["seg.mean"].to_f < thresholdLow)
          outputArray[1] = "segment_#{counter}"
          outputArray[4] = results["output"]["chrom"]
          outputArray[5] = results["output"]["loc.start"]
          outputArray[6] = results["output"]["loc.end"]
          outputArray[9] = results["output"]["seg.mean"]
          outputArray[10]= "."
          outputArray[11]= "."
          if results["output"]["seg.mean"].to_f < 0
            outputArray[12]= "annotationColor=red; length=#{outputArray[6]-outputArray[5]};"
          else
            outputArray[12]= "annotationColor=green; length=#{outputArray[6]-outputArray[5]};"
          end
          printLff(outputArray,segWriter)
          counter += 1
        end
      end

      segWriter.close()

      #require minimum number of probes (use an intersect with min # of intersections)
      if !(@minProbes.nil?)
        intersectCmd =  "lffIntersect.rb -f #{@lffType}:#{@lffSubType} -s #{CGI.escape(@inputType)}:#{CGI.escape(@inputSubType)} " +
                        " -l " + CGI.escape(CGI.escape(@segFile) + ',' + CGI.escape(@aFile)) +
                        " -o #{CGI.escape(@outputFile)} -n #{@lffType}:#{@lffSubType} -c #{@lffClass} -m #{@minProbes} -V "
        $stderr.puts "#{'-'*40}\nsegmentACGH.rb calling lffIntersect.rb  like this\n  #{intersectCmd}\n#{'-'*40}"
        `#{intersectCmd}`
      else
        `mv #{@outputFile}.segs.lff #{@outputFile}`
      end
    end  #convert()

    def printLff(outputArray,writer)
      0.upto(outputArray.length-2){ |i|
        writer.print "#{outputArray[i]}\t"
      }
       writer.print "#{outputArray[outputArray.length-1]}\n"
    end


    def mean(population)
      total = 0
      population.each{ |x|
        total += x
      }
      return total/population.length
    end


    def variance(population)
      n = 0
      mean = 0.0
      s = 0.0
      population.each { |x|
        n = n + 1
        delta = x - mean
        mean = mean + (delta / n)
        s = s + delta * (x - mean)
       }
      # if you want to calculate std deviation
       # of a sample change this to "s / (n-1)"
      return s / n
    end

    # calculate the standard deviation of a population
    # accepts: an array, the population
    # returns: the standard deviation
    def standard_deviation(population)
      Math.sqrt(variance(population))
    end




    def ACGHsegment.processArguments()
      optsArray =	[	['--aFile', '-f', GetoptLong::REQUIRED_ARGUMENT],
                                ['--outputFile', '-o', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--threshold', '-r', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--devThreshold', '-e', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--minProbes', '-p', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--class', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--type', '-t', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--subtype', '-s', GetoptLong::OPTIONAL_ARGUMENT],
                                ['--help', '-h', GetoptLong::NO_ARGUMENT]
                        ]
       progOpts = GetoptLong.new(*optsArray)
       optsHash = progOpts.to_hash
       ACGHsegment.usage() if(optsHash.empty? or optsHash.key?('--help'))
       return optsHash
     end

     def ACGHsegment.usage(msg='')
       puts "\n#{msg}\n" unless(msg.empty?)
       puts "

  PROGRAM DESCRIPTION:
    Takes an arrayCGH lff file and segments it.  Produces an LFF output file
    containing the resulting segments above the specified threshold

    It is assumed that the score column of the input lff file contains a
    log-ratio score for that probe.

    It is also assumed that each annotation in the input file is of
    the same type and subtype

    This script uses the DNAcopy R library to do segmentation.


    COMMAND LINE ARGUMENTS:
      -f    => LFF file to segment
      -o    => [optional] Override the output file location.
               Default is aFileSegments.lff, minus the extension if present.
      -r    => [optional] Threshold based on value - only keep segments
               where the abs. value is above this log-ratio score.
      -e    => [optional] Threshold based on this # of standard deviations
               from the mean.
      -p    => [optional] Require that a segment be composed of at least
               this many probes to be output (algorithmic default is 2)
      -c    => [optional] Override the LFF class value to use.
               Defaults to 'aCGH'.
      -t    => [optional] Override the LFF type value to use.
               Defaults to 'Segmented'.
      -s    => [optional] Override the LFF subtype value to use.
               Defaults to 'Blocks'.
      -h    => [optional flag] Output this usage info and exit

    USAGE:
    segmentACGH.rb  -f my agilentData.txt
	"
       exit(BRL::FormatMapper::USAGE_ERR)
     end #usage

   end # class ACGHsegment

 end ; end

# ##############################################################################
# MAIN
# ##############################################################################
optsHash = BRL::FormatMapper::ACGHsegment::processArguments()
converter = BRL::FormatMapper::ACGHsegment.new(optsHash)
converter.convert()

exit()
