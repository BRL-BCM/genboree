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
require 'brl/genboree/LFFOperator'
require 'md5'
module BRL ; module Genboree

   class AttributeLifter < LFFOperator
    # We have these instance variables available already:
    # :loggers, :outFileName, :newTrackRec, :srcLffFiles, :lffRecords

    attr_reader :opNameCaps

    def initialize(optsHash)
      super(optsHash)  # Get generic, required properties
      @opNameCaps =  'AttributeLifter' # Override generic name with a specific one
      @firstTrackName = optsHash['--firstOperandTrack']
      @intersectAll = optsHash.key?('--intersectAll')
      @precipOnlyMatches = optsHash.key?('--precipOnlyMatches')
      @radius = optsHash.key?('--fuzzyRadius') ? optsHash['--fuzzyRadius'].to_i : 0
      @attributes = optsHash['--attributes']
      @otherTrackNames = extractTrackNames()
      @minNumIntersects = optsHash.key?('--minNumIntersections') ? optsHash['--minNumIntersections'].to_i : 1
      if optsHash.key?('--class')
        @lffClass = optsHash['--class']
      else
        @lffClass = "Intersect"
      end
      $stderr.puts "  Processing track '#{@firstTrackName}'"
      $stderr.puts "  2nd operand tracks: "
      @otherTrackNames.each { |otnEntry| $stderr.puts "    - #{otnEntry}" }
      $stderr.puts "  Attribute str: #{@attributes.split(/;/).inspect}"
      $stderr.puts "  Attributes to lift (with src track):"
      @attributes.split(/;/).each { |attrEntry| $stderr.puts "    - #{attrEntry}" }
      $stderr.puts "  Require Intersect in All Tracks? #{@intersectAll}"
      $stderr.puts "  Output Only Annos With Matches? #{@precipOnlyMatches}"
      $stderr.puts "  Intersection Radius: #{@fuzzyRadius}"
      $stderr.puts "  Minimum Number of Intersects: #{@minNumIntersections}"
      $stderr.puts "  Output class: #{@lffClass}"

    end

    def preProcess() # Required to implement this. Do any preprocessing of the data in @lffRecords, if needed.
      return
    end 

    def cleanUp() # Required to implement this. Do any cleanup following operation, if needed.
      return
    end

    def extractTrackNames()
      otherTrackNames = {}
      if(!(@attributes.nil?))
        attrEntries = @attributes.split(/;/)
        attTypeSub = {}
        attName = []
        attNewName = []
        counter = 0
        attrEntries.each { |attr|
          # extract info from attributes to save
          if(attr =~ /^([^:]+):([^:]+):([^=;]+)=([^=;]+)$/)
            otherTrackNames["#{$1}:#{$2}"] = nil
          else
            raise "ERROR: attributes to save need to be in the format Type:Subtype:attribute=newAttributeName. This one is not: '#{attr}'."
          end
        }
        return otherTrackNames.keys
      end
    end

    def applyOperation() # Required to implement this. Do the operation on the data in @lffRecords.
      #split up info on attributes to save, store in arrays
      if(!(@attributes.nil?))
        attributesToSave = @attributes.split(/;/)
        attTypeSub = Hash.new
        attName = Array.new
        attNewName = Array.new
        counter = 0
        attributesToSave.each{ |att|
          # extract info from attributes to save
          if (att=~/([^:]+):([^:]+):([^=]+)=(.+)/)
            if !(attTypeSub.key?("#{$1}:#{$2}"))
              puts "true"
              attTypeSub["#{$1}:#{$2}"] = counter
            else
              attTypeSub["#{$1}:#{$2}"] = attTypeSub["#{$1}:#{$2}"].to_s + "," + counter.to_s
            end
            attName[counter] = $3
            attNewName[counter] = $4
            counter += 1
          else
            raise "ERROR: attributes to save need to be in the format Type:Subtype:attribute=newAttributeName"
          end       
        }
        attributeHash = Hash.new

      end
      #hash fieldnames to field number
      fieldNames = Hash.new
      fieldNames["CLASS"]  = 0
      fieldNames["NAME"]   = 1
      fieldNames["TYPE"]   = 2
      fieldNames["SUBTYPE"]= 3
      fieldNames["CHROM"]  = 4
      fieldNames["START"]  = 5
      fieldNames["STOP"]   = 6
      fieldNames["STRAND"] = 7
      fieldNames["PHASE"]  = 8
      fieldNames["SCORE"]  = 9
      fieldNames["QSTART"] = 10
      fieldNames["QSTOP"]  = 11
      fieldNames["SEQUENCE"] = 13
      fieldNames["FREEFORM"] = 14

      # Open output file
      writer = BRL::Util::TextWriter.new(@outFileName, 'w+')
      # Loop over each chr (entrypoint)
      @lffRecords.keys.each { |ep|
        # For each annotation for the first track operand, look for any annotation
        # in any of the other tracks that 'intersects' with it. Output the annotation
        # if one is found.
        # NOTE: this is O(M*N) as written. It could be sped up if necessary by using
        # a coord-aware data structure for the annotations (currently in an array)
        # or one that ameliorates the zeroing in on the relevant coords (eg a Skip
        # List is good for that). Currently, however, terminating states are found quickly to
        # reduce the price of the M*N operations.
        next unless(@lffRecords[ep].key?(@firstTrackName))
        # Loop over each record
        @lffRecords[ep][@firstTrackName].each { |op1Rec|
          op1RecStart = (op1Rec[RSTART].to_i - @radius)
          op1RecEnd = (op1Rec[REND].to_i + @radius)
          if(op1RecStart > op1RecEnd)
            op1RecStart,op1RecEnd = op1RecEnd,op1RecStart
          end
          op1RecStart = (op1RecStart - @radius)
          op1RecEnd = (op1RecEnd + @radius)

          intersectFound = false
          numIntersects = 0
          # Go through the other annotations on this entrypoint and look for
          # intersecting ones.
          otherTracksTouched = {}
          @otherTrackNames.each { |otherTrackName|
            break if(  (!@intersectAll and intersectFound and numIntersects >= @minNumIntersects) or
                       (@intersectAll and intersectFound and (otherTracksTouched.size == @otherTrackNames.size) and !(otherTracksTouched.values.detect { |yy| yy < @minNumIntersects })))
            next unless(@lffRecords[ep].key?(otherTrackName))
            #@lffRecords[ep][otherTrackName].sort! { |aa,bb| cc = (aa[RSTART] <=> bb[RSTART]) ; ((cc == 0) ? aa[REND] <=> bb[REND] : cc); }
            @lffRecords[ep][otherTrackName].each { |op2Rec|
              if(op2Rec[RSTART] > op2Rec[REND])
                op2Rec[RSTART],op2Rec[REND] = op2Rec[REND],op2Rec[RSTART]
              end
              next if(op2Rec[REND] < op1RecStart)              # Have we reached the right area yet?
              break if(op2Rec[RSTART] > op1RecEnd)     # Have we gone beyond the end of the right area?
              # If here, then these two things are true:
              #        1) op1Start <= op2End     AND
              #   2) op2Start <= op1End
              # Therefore, we have found an overlap/intersection as part of the
              # "fast zeroing in" tests.
              intersectFound = true
              numIntersects += 1

              line = ""
              0.upto(11){ |k|
                line << op1Rec[k].to_s
              }
              md5sig = MD5.hexdigest(line)

              ### since we found it, add specified attributes before writing out annotation
              if(!(@attributes.nil?))
                if(attTypeSub.has_key?("#{op2Rec[TYPEID]}:#{op2Rec[SUBTYPE]}"))

                  asdf = attTypeSub["#{op2Rec[TYPEID]}:#{op2Rec[SUBTYPE]}"]

                  op1Rec[10] = "." if (op1Rec[10].nil?)
                  op1Rec[11] = "." if (op1Rec[11].nil?)
                  op1Rec[12] = "" if (op1Rec[12].nil?)

                  numbersOfAtts = attTypeSub["#{op2Rec[TYPEID]}:#{op2Rec[SUBTYPE]}"].to_s.split(",")
                  numbersOfAtts.each{ |num|
                    num = num.to_i
                    #if it is a fieldName                    
                    if(fieldNames.has_key?(attName[num]))
                      value = op2Rec[fieldNames[attName[num]]]
                    elsif(op2Rec[12] =~ /#{attName[num]}=([^;]*)\;/)
                      value = $1
                    end

                    #if attribute exists (more than one match), append and make comma-seperated list

                   # puts "before: #{op1Rec[12]}"                                     
                    #if attribute exists
                    if(op1Rec[12] =~ /(^|\;|\s)#{attNewName[num]}=([^;]*)\;\s?/)
                      #and value is not empty
                      currval = $2
                      if !((value.nil?) && !(currval.nil?))
                        #add it to the existing value
                        # but only if the value is not already added to the list
                        # (keep only unique values)                        
                        if !(attributeHash.key?("#{md5sig}:#{value}"))
                            if (currval != "")
                              op1Rec[12].gsub!(/(^|\;|\s)#{attNewName[num]}=([^;]*)\;\s?/, " #{attNewName[num]}=#{currval},#{value}; ")
                            else
                              op1Rec[12].gsub!(/(^|\;|\s)#{attNewName[num]}=([^;]*)\;\s?/, " #{attNewName[num]}=#{value}; ")
                            end
                          attributeHash["#{md5sig}:#{value}"] = 0                          
                        end
                      end
                    else  # just add it 
                      # if not empty
                      if ((value != "") && !(value.nil?))
                        op1Rec[12] << " #{attNewName[num]}=#{value}; "
                        attributeHash["#{md5sig}:#{value}"] = 0
                      end
                    end
#                    puts "after: #{op1Rec[12]}"                 
              }
                  end
              end
              ### end attributes section

              otherTracksTouched[otherTrackName] = 0 unless(otherTracksTouched.key?(otherTrackName))
              otherTracksTouched[otherTrackName] += 1
            }
          }

          if(@precipOnlyMatches)
            # write out only matches
             if(  (!@intersectAll and intersectFound and numIntersects >= @minNumIntersects) or
                  (@intersectAll and intersectFound and (otherTracksTouched.size == @otherTrackNames.size) and
                  !(otherTracksTouched.values.detect { |yy| yy < @minNumIntersects })))
               op1Rec[12] << "numIntersects=#{numIntersects}; "
              op1Rec[0], op1Rec[TYPEID], op1Rec[SUBTYPE] = @lffClass, @newTrackRec[TRACK_TYPE], @newTrackRec[TRACK_SUBTYPE]
              writer.puts op1Rec.join("\t")
             end
          else
            # write out everything
             if(  (!@intersectAll and intersectFound and numIntersects >= @minNumIntersects) or
                  (@intersectAll and intersectFound and (otherTracksTouched.size == @otherTrackNames.size) and
                   !(otherTracksTouched.values.detect { |yy| yy < @minNumIntersects })))
               op1Rec[12] << "numIntersects=#{numIntersects}; "
             end # class AttributeLifter
             op1Rec[0], op1Rec[TYPEID], op1Rec[SUBTYPE] = @lffClass, @newTrackRec[TRACK_TYPE], @newTrackRec[TRACK_SUBTYPE]
             writer.puts op1Rec.join("\t")
          end
        }
      }
      writer.close
      return
    end

    def AttributeLifter.processArguments()
      optsArray = [
                    ['--firstOperandTrack', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--intersectAll', '-a', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--outputFile', '-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--lffFiles', '-l', GetoptLong::REQUIRED_ARGUMENT],
                    ['--fuzzyRadius', '-r', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--minNumIntersections', '-m', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--noValidation', '-V', GetoptLong::NO_ARGUMENT],
                    ['--attributes', '-t', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--class', '-c', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--newTrackName', '-n', GetoptLong::REQUIRED_ARGUMENT],
                    ['--precipOnlyMatches', '-p', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      AttributeLifter.usage() if(optsHash.empty? or optsHash.key?('--help'))
      unless(  optsHash['--firstOperandTrack'].include?(58))
        $stderr.puts "#{Time.now()} ATTRIBUTE LIFTER ERROR - track names have colons (':') between the type and subtype.\nFirst operand track arg doesn't: #{optsHash['--firstOperandTrack']}."
                       exit(BRL::Genboree::USAGE_ERROR)
      end
      return optsHash
    end

     def AttributeLifter.usage(msg='')
      puts "\n#{msg}\n" unless(msg.empty?)
      puts "

  PROGRAM DESCRIPTION:
    Given a list of LFF files and two operand tracks, outputs an LFF file
    containing only those annotations from the first operand that overlap with
    at least one annotation from the second operand track.

    Actually, it's a bit more general in that it supports *multiple* second
    operand tracks, so you can have it output annotations from the first
    operand track that overlap with an annotation from *any* of the other
    operand tracks. Saves a bit of time and is more useful for certain use
    cases (eg, my ESTs that intersect with ESTs from any one of various cancer
    libraries). This is OPTIONAL.

        By default, first operand track annotations are output if they intersect
        *any* of the other operand tracks. But if you use -a, you can require
        intersection with *all* of the other operand tracks before a first operand
        track is accepted. This is OPTIONAL.

    Furthermore, you can also tell it a minimum number of intersections be
    found before outputting the record. (eg, my ESTs that intersect with at
    least 3 ESTs from any one of various cancer libraries). If you have
    also specified -a (see above), then *all* tracks must have at least this
    number of intersections with a first operand track annotation for it to be
    accepted. This is OPTIONAL.

    You can even provide a radius--this is a fixed number of base pairs that
    will be added to the ends of your records in the first operand track when
    determining intersection. This allows smaller ('point mappings') to be
    treated as bigger than they are. Good for treating PGI indices as BACs or
    something.


    This tool can also be used to extract attributes from the 'other' tracks
    and append them to the resulting intersection track.  If more than one
    annotation overlaps, the annotation will be copied as a comma seperated
    list.  (for example:  score=0.1, 0.6, 1.0)

    The attributes of the other track to be copied should be in the format:
        Type:Subtype:AttributeName=NewAttributeName

    The non-attribute fields in the other track can also be copied over as an
    annotation, and should be referred to using the format:
        Type:Subtype:FIELDNAME=NewAttributeName

    where FIELDNAME is one of the following:
    CLASS NAME TYPE SUBTYPE CHROM START STOP STRAND PHASE SCORE
    QSTART QSTOP SEQUENCE FREEFORM

    Track names follow this convention, as displayed in Genboree:
       Type:SubType
    That is to say, the track Type and its Subtype are separated by a colon, to
    form the track name. This format is *required* when identifying tracks.

    The tool will automatically create an attribute in each annotation that
    specifies the number of other annotations intersected. (numIntersections)


    The --lffFiles (or -l) option, the --otherOperandTracks (or -o) option,
    support both a single name or a comma-separated list of names. Enclosing
    in quotes is often a good practice, but shouldn't be required.

    COMMAND LINE ARGUMENTS:
      -f    => Name of the first operand track. You will be precipitating out
               annotations from this track that overlap with annotations from
               the other track(s).
      -l    => A list of LFF files where annotations can be found to work on.
               Annotations with irrelevant track names will be ignored and not
               output.
      -o    => Name of output file in which to put data.
      -c    => [optional] Override the LFF class value to use.
               Defaults to 'Intersect'.
      -n    => New track name for annotations having intersection.
               Should be in form of type:subtype.
      -r    => [optional] Add this radius to make annotations a bit 'larger'
               when considering overlap. Thus, the annotations may not strictly
               overlap, but may be really close to overlapping. Default is 0.
      -a    => [optional] This will require intersect with at least a minimum
               (see -m below) number of annotations from *each* track listed
               with -s. That is to say, 'AND' rather than 'OR', or insection
               with 'ALL' second operand tracks rather than just any track.
      -m    => [optional] Minimum number of interections a record in the first
               operand track must have to be output. Default is 1. If -a is
               used, then ALL second operand tracks must have at least this
               number of intersecting annotations for the first operand
               annotation to be output.
      -V    => [optional flag] Turns OFF lff record validation. For use when
               Genboree is calling this program. Saves time, in theory.
      -t    => [optional] a semicolon-seperated list of attributes to copy from the
               other tracks to the output track. Should be in the format:
               Type:Subtype:AttributeName=NewAttributeName;
      -p    => [optional flag] precipitate only annotations that have an intersect.
               The default is to precipitate all annotations from the first track.
      -h    => [optional flag] Output this usage info and exit.

    USAGE:
    lffIntersect.rb -f ESTs:Ut1 -s Gene:RefSeq,Gene:Ens -l \\
     ./myData.lff -o myInterData.lff -c Intersect -y Intersect -u PlusAnnos
        "
                exit(BRL::Genboree::USAGE_ERROR)
        end

end # class AttributeLifter

end ; end

# ##############################################################################
# MAIN
# ##############################################################################
begin
  optsHash = BRL::Genboree::AttributeLifter::processArguments()
  $stderr.puts "\n#{Time.now()} AttributeLifter - STARTING"
  intersector = BRL::Genboree::AttributeLifter.new(optsHash)
  exitVal = intersector.run()
  if(exitVal == BRL::Genboree::FAILED)
    $stderr.puts("#{Time.now()} #{intersector.opNameCaps} ERROR - too many errors amongst your files. Processing abandoned.")
    errStr =        "ERROR: Too many formatting errors in your file(s).\n"
  elsif(exitVal == BRL::Genboree::OK_WITH_ERRORS)
    $stderr.puts("#{Time.now()} #{intersector.opNameCaps} WARNING - some formatting errors amongst your files.")
    errStr =        "WARNING: Found some formatting errors in your file(s).\n"
  end
  if(exitVal == BRL::Genboree::FAILED or exitVal == BRL::Genboree::OK_WITH_ERRORS)
    maxPerFile = (BRL::Genboree::MAX_NUM_ERRS.to_f / intersector.loggers.size.to_f).floor
    errStr +=       "Please check that you really are using the LFF file format.\n"
    errStr += "\nHere is a sample of the formatting errors detected:\n"
    errStr += "\n"
    msgSize = errStr.size
    puts errStr
    intersector.loggers.each { |fileName, logger|
            puts "File: #{fileName}" unless(intersector.loggers.keys.size <= 1)
            msg = logger.to_s(maxPerFile)
            msgSize += msg.size
            break if(msgSize > BRL::Genboree::MAX_EMAIL_SIZE)
            print "#{msg}\n\n"
    }
  else
          $stderr.puts "\n#{Time.now()} #{intersector.opNameCaps} - SUCCESSFUL"
          puts "The Intersecting Track Operation was successful."
  end
rescue => err
    errTitle =  "#{Time.now()} AttributeLifter - FATAL ERROR: The track operation exited without processing the data, due to a fatal error.\n"
    msgTitle =  "FATAL ERROR: The track operation exited without processing the data, due to a fatal error.\n"
    errstr   =  "   The error message was: '#{err.message}'.\n"
    errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
    puts msgTitle
    $stderr.puts errTitle + errstr
    exitVal = BRL::Genboree::FATAL
end
puts ''

$stderr.puts "#{Time.now()} AttributeLifter - DONE (exitVal: '#{exitVal}')"
exit(exitVal)
