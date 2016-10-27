require 'erb'
require 'brl/util/textFileUtil'
require 'brl/genboree/toolPlugins/util/util.rb'
require 'brl/genboree/seqRetriever'
include BRL::Genboree::ToolPlugins
include BRL::Genboree::ToolPlugins::Util

module BRL module Genboree ; module ToolPlugins; module Tools;
  module Primer3
    class Primer3Tool

      def self.about()
        return  {
                  :title => 'Primer 3',
                  :desc => 'Designs primers based on selected annotations using Primer 3.',
                  :functions => self.functions()
                }
      end

      def self.functions()
        return  {
          :designPrimers =>
          {
            :title => 'Design Primers',
            :desc => 'Designs primers based on selected annotations using Primer 3.',
            :displayName => '3) Manual Primer Design',
            :internalName => 'primer3',
            :autoLinkExtensions => { 'raw.gz' => 'raw.gz' }, # src file extension => dest file extension
            :resultFileExtensions => { 'raw.gz' => true },
            # These must match the form element ids. They will be checked automatically
            # for basic presence. They CANNOT be missing.
            :input =>
            {
              :expname  =>  { :desc => "Job Name: ", :paramDisplay => 1 },
              :refSeqId => { :desc => "Genboree uploadId for LFF data: ", :paramDisplay => -1 },
              :template_lff => { :desc => "Template track: ", :paramDisplay => -1 },
              # This one is created by the framework
              :template_lff_ORIG => { :desc => "Template track: ", :paramDisplay => 2},
              :upstreamPadding => { :desc => "Additional padding upstream of template: ", :paramDisplay => 3 },
              :downstreamPadding => { :desc => "Additional padding downstream of template: ", :paramDisplay => 4 },
              :primerSizeMin => { :desc => "Minimum primer size: ", :paramDisplay => 5 },
              :primerSizeOpt => { :desc => "Optimum primer size: ", :paramDisplay => 6 },
              :primerSizeMax => { :desc => "Maximum primer size: ", :paramDisplay => 7 },
              :primerTmMin => { :desc => "Minimum primer Tm: ", :paramDisplay => 8 },
              :primerTmOpt => { :desc => "Optimum primer Tm: ", :paramDisplay => 9 },
              :primerTmMax => { :desc => "Maximum primer Tm: ", :paramDisplay => 10 },
              :ampliconTmMin => { :desc => "Minimum amplicon Tm: ", :paramDisplay => 11 },
              :ampliconTmOpt => { :desc => "Optimum amplicon Tm: ", :paramDisplay => 12 },
              :ampliconTmMax => { :desc => "Maximum amplicon Tm: ", :paramDisplay => 13 },
              :primerGcMin => { :desc => "Minimum primer GC: ", :paramDisplay => 14 },
              :primerGcOpt => { :desc => "Optimum primer GC: ", :paramDisplay => 15 },
              :primerGcMax => { :desc => "Maximum primer GC: ", :paramDisplay => 16 },
              :maxSelfComp => { :desc => "Maximum primer self complementarity: ", :paramDisplay => 17 },
              :max3Comp => { :desc => "Maximum primer-pair 3' complementarity: ", :paramDisplay => 18 },
              :maxPoly => { :desc => "Maximum primer mono-nucleotide run length: ", :paramDisplay => 19 },
              :numNs => { :desc => "Maximum number of Ns in primer: ", :paramDisplay => 20 },
              :gcClamp => { :desc => "Required number of 3' GC-clamping bases in primer: ", :paramDisplay => 21 },
              :leftDeadRegion => { :desc => "Minimum distance of primer from template's 5' end: ", :paramDisplay => 22 },
              :rightDeadRegion => { :desc => "Minimum distance of primer from template's 3' end: ", :paramDisplay => 23 },
              :ampliconSizeRange => { :desc => "Size range of amplicon", :paramDisplay => 24 },
              :primerTrackClass => { :desc => "Primer track class: ", :paramDisplay => 25 },
              :trackTypeName => { :desc => "Primer track type: ", :paramDisplay => 26 },
              :trackSubtypeName => { :desc => "Primer track subtype: ", :paramDisplay => 27 },
              :ampliconTrackClass => { :desc => "Amplicon track class: ", :paramDisplay => 28 },
              :ampTypeName  => { :desc => "Amplicon track type: ", :paramDisplay => 29 },
              :ampSubtypeName  => { :desc => "Amplicon track subtype: ", :paramDisplay => 30 },
              :useMasked => { :desc => "Use Repeatmasked Genome: ", :paramDisplay => 31 },
            }
          }
        }
      end

      # THIS IS THE FUNCTION THAT RUNS THE ACTUAL TOOL.
      # Here, it is called 'designPrimers', as returned by self.functions()
      def designPrimers( options )
        # Keep track of files we want to clean up when finished
        filesToCleanUp = []
        # Plugin options
        expname = options[:expname]
        refSeqId = options[:refSeqId]
        userId = options[:userId]
        template_lff = options[:template_lff]
        output = options[:output]

        # Which genome version?
        useMasked = options[:useMasked] == 'true'

        # Padding Options
        upstreamPadding = options[:upstreamPadding].to_i
        downstreamPadding = options[:downstreamPadding].to_i
        designInPads = options[:designInPads]

        # Dead region option
        leftDead = options[:leftDeadRegion].to_i
        rightDead = options[:rightDeadRegion].to_i

        # Primer3 Options
        #primer3Parameters = "PRIMER_FILE_FLAG=0\nPRIMER_PICK_INTERNAL_OLIGO=0\nPRIMER_EXPLAIN_FLAG=0\n"
        primer3Parameters = []

        primer3Parameters << "PRIMER_MIN_SIZE=#{options[:primerSizeMin]}" unless(options[:primerSizeMin].nil?)
        primer3Parameters << "PRIMER_OPT_SIZE=#{options[:primerSizeOpt]}" unless(options[:primerSizeOpt].nil?)
        primer3Parameters << "PRIMER_MAX_SIZE=#{options[:primerSizeMax]}" unless(options[:primerSizeMax].nil?)
        primer3Parameters << "PRIMER_MIN_TM=#{options[:primerTmMin]}" unless(options[:primerTmMin].nil?)
        primer3Parameters << "PRIMER_OPT_TM=#{options[:primerTmOpt]}" unless(options[:primerTmOpt].nil?)
        primer3Parameters << "PRIMER_MAX_TM=#{options[:primerTmMax]}" unless(options[:primerTmMax].nil?)
        primer3Parameters << "PRIMER_PRODUCT_MIN_TM=#{options[:ampliconTmMin]}" unless(options[:ampliconTmMin].nil?)
        primer3Parameters << "PRIMER_PRODUCT_OPT_TM=#{options[:ampliconTmOpt]}" unless(options[:ampliconTmOpt].nil?)
        primer3Parameters << "PRIMER_PRODUCT_MAX_TM=#{options[:ampliconTmMax]}" unless(options[:ampliconTmMax].nil?)
        primer3Parameters << "PRIMER_MIN_GC=#{options[:primerGcMin]}" unless(options[:primerGcMin].nil?)
        primer3Parameters << "PRIMER_OPT_GC=#{options[:primerGcOpt]}" unless(options[:primerGcOpt].nil?)
        primer3Parameters << "PRIMER_MAX_GC=#{options[:primerGcMax]}" unless(options[:primerGcMax].nil?)
        primer3Parameters << "PRIMER_SELF_ANY=#{options[:maxSelfComp]}" unless(options[:maxSelfComp].nil?)
        primer3Parameters << "PRIMER_PRODUCT_SIZE_RANGE=#{options[:ampliconSizeRange]}" unless(options[:ampliconSizeRange].nil?)
        primer3Parameters << "PRIMER_MAX_POLY_X=#{options[:maxPoly]}" unless(options[:maxPoly].nil?)
        primer3Parameters << "PRIMER_SELF_END=#{options[:max3Comp]}" unless(options[:max3Comp].nil?)
        primer3Parameters << "PRIMER_GC_CLAMP=#{options[:gcClamp]}" unless(options[:gcClamp].nil?)
        primer3Parameters << "PRIMER_NUM_RETURN=#{options[:numReturn]}" unless(options[:numReturn].nil?)
        primer3Parameters << "PRIMER_NUM_NS_ACCEPTED=#{options[:numNs]}" unless(options[:numNs].nil?)
        primer3Parameters << "PRIMER_MAX_DIFF_TM=#{options[:primerTmDiff]}" unless(options[:primerTmDiff].nil?)

        # A primer debugging option maybe useful for people to see in raw output:
        primer3Parameters << "PRIMER_EXPLAIN_FLAG=1"

        primer3ParamStr = primer3Parameters.join("\n")

        output =~ /^(.+)\/[^\/]*$/
        outputDir = $1
        checkOutputDir( outputDir )

        # SAVE PARAM DATA (marshalled ruby)
        BRL::Genboree::ToolPlugins::Util::saveParamData(options, output, Primer3Tool.functions()[:designPrimers][:input])

        # Add padding and dead regions to annotations
        unless(upstreamPadding.nil? || downstreamPadding.nil?) || (upstreamPadding == 0 && downstreamPadding == 0)
          newTemplateLff = template_lff + ".newPad"
          lffOut = File.open(newTemplateLff, 'w+')
          File.open(template_lff, 'r') { |lffIn|
            line = nil # faster if in outer-scope
            lffIn.each { |line|
              next if(line =~ /^\s*$/ or line =~ /^\s*\[/)
              arrSplit = line.split("\t")
              next unless(arrSplit.length >= 10)
              #start
              arrSplit[5] = arrSplit[5].to_i - upstreamPadding - leftDead
              #stop
              arrSplit[6] = arrSplit[6].to_i + downstreamPadding + rightDead
              lffOut.print(arrSplit.join("\t"))
            }
          }
          lffOut.close()
          # Replace old LFF file with this new one.
          File.delete(template_lff)
          File.rename(newTemplateLff, template_lff)
        end

        # First, take input files and grab sequence
        rtrv = BRL::Genboree::ToolPlugins::Util::MySeqRetriever.new()
        rtrv.useMasked = useMasked

        # Open lff file
        lffFile = File.open(template_lff, 'r')
        filesToCleanUp << template_lff  # CLEAN UP: input LFF file

        # Create p3cmd file
        p3cmdFileName = "#{output}.p3cmd"
        p3cmdFile = File.open(p3cmdFileName, 'w+')
        filesToCleanUp << p3cmdFileName # CLEAN UP: primer3 execution file

        seqRec = nil # declare in outer scope for > speed
        rtrv.each_seq(refSeqId, lffFile, '+') { |seqRec| # MUST override strand or all the parsing math down below is wrong
          # Check the noError condition
          unless(seqRec.noError == true)
            errMsg = "\n\nPrimer design cannot be run on your database because one or more\nsequence files are missing.\n\nPlease contact genboree_admin@genboree.org with the information above\nfor help about this error.\n"
            $stderr.puts errMsg # for logging
            raise errMsg
          end
          primer3cmd = "PRIMER_SEQUENCE_ID=#{seqRec.defline.gsub(/^>/,"")}\nSEQUENCE=#{seqRec.sequence}\n#{primer3ParamStr} \n"
          if((!designInPads.nil?) && (designInPads == "true"))
            seqRec.defline =~ /^(.+)\|(.+)\|(.+)\|(.+)/
            length = $3.to_i - $2.to_i + 1
            annoLength = length - upstreamPadding - downstreamPadding
            primer3cmd += "TARGET=#{upstreamPadding - leftDead - 1},#{annoLength + leftDead + rightDead} \n"
          end
          primer3cmd += "=\n"
          p3cmdFile.print primer3cmd
          # print primer3cmd # for logging
        }
        p3cmdFile.close()
        lffFile.close()
        # Nuke trailing newline to make primer3 happy fun
        File::truncate(p3cmdFileName, File.size(p3cmdFileName) - 1)

        # EXECUTE *ACTUAL* TOOL:
        cleanOutput = output.gsub(/ /, '\ ')
        p3cmdOK = system( "cat '#{p3cmdFileName}' | /usr/local/brl/local/bin/primer3_core " +
                          " > #{cleanOutput}.raw 2> #{cleanOutput}.primer3.err")
        filesToCleanUp << "#{cleanOutput}.primer3.err"  # CLEAN UP: err file from primer3.

        if(p3cmdOK)
          # Gzip the results files
          `gzip #{cleanOutput}.raw`

          # Upload primers into Genboree as LFF -- NOT OPTIONAL ANYMORE! (encourage Genboree use)
          klass = options[:primerTrackClass].gsub(/\\"/, "'") # '
          type = options[:trackTypeName].gsub(/\\"/, "'") # '
          subtype = options[:trackSubtypeName].gsub(/\\"/, "'") # '
          ampKlass = options[:ampliconTrackClass].gsub(/\\"/, "'") # '
          ampType = options[:ampTypeName].gsub(/\\"/, "'") # '
          ampSubtype = options[:ampSubtypeName].gsub(/\\"/, "'") # '

          re = /PRIMER_SEQUENCE_ID=(.+)\|(.+)\|(.+)\|(.+)/

          arrAnnotations = Array.new()
          productNames = Hash.new { |hh,kk| hh[kk] = 1 }

          # Write out file
          lffOutFile = File.open("#{output}.lff", 'w+')
          filesToCleanUp << "#{output}.lff" # CLEAN UP: lff file for primers/amplicons that will be uploaded.

          p3reader = IO.popen("gunzip -c #{cleanOutput}.raw.gz")

          annotationRec = nil
          p3reader.each("\n=\n") { |annotationRec|
            primerRecs = annotationRec.split(/^PRIMER_PAIR_PENALTY(?:_\d)?/)

            # Get data out of the header
            header = primerRecs.shift
            header.strip!
            lines = header.split(/\n/)
            lines[0] =~ re
            start = $2.to_i
            stop = $3.to_i
            origStart = start + upstreamPadding + leftDead
            origStop = stop - downstreamPadding - rightDead
            # Fix for re not splitting name and chrom
            splitName = $1.split("|")
            name = splitName[0]
            chrom = splitName[1]

            # If no primers were designed for this template
            if(primerRecs.length == 0)
              comments = []
              sequence = nil

              line = nil # faster if in outer-scope
              lines.each { |line|
                line.strip!
                line.gsub!(/;/, ',')
                next if(line =~ /^\s*=?\s*$/) # skip if blank or just = sign

                if(line =~ /SEQUENCE=(.+)/)
                  sequence = $1
                elsif
                  comments << line
                end
              }

              # print in Fail track
              lffOutFile.print "#{klass}\t#{name}\t#{type}\t#{subtype}.FAIL\t#{chrom}\t#{origStart}\t#{origStop}\t+\t.\t0\t.\t.\t#{comments.join('; ')};\t#{sequence}\n"
            # Primers were designed for this template
            else
              primerRecs.each { | primerRec |
                lines = primerRec.split(/\n/)
                lines[0] = "PRIMER_PAIR_PENALTY#{lines[0]}"

                rightStart = 0
                rightStop = 0
                rightTStart = 0
                rightTStop = 0
                rightComments = {}
                rightCommentsStr = ''
                rightSequence = nil

                leftStart = 0
                leftStop = 0
                leftTStart = 0
                leftTStop = 0
                leftComments = {}
                leftCommentsStr = ''
                leftSequence = nil

                ampComments = {}
                ampCommentsStr = ''

                line = nil # faster if in outer-scope
                lines.each { |line|
                  line.strip!
                  line.gsub!(/;/, ',')
                  next if(line =~ /^\s*$/)
                  if(line =~ /PRIMER_LEFT_(?:\d_)?SEQUENCE=(.+)/)
                    leftSequence = $1
                  elsif(line =~ /PRIMER_RIGHT_(?:\d_)?SEQUENCE=(.+)/)
                    rightSequence = $1
                  elsif(line =~ /PRIMER_LEFT(?:_\d)?=(.+)/)
                    coordinateSplit = $1.split(/,/)
                    leftStart = start + coordinateSplit[0].to_i
                    leftStop = start + coordinateSplit[0].to_i + coordinateSplit[1].to_i - 1
                    leftTStart = coordinateSplit[0]
                    leftTStop = coordinateSplit[0].to_i + coordinateSplit[1].to_i - 1
                  elsif(line =~ /PRIMER_RIGHT(?:_\d)?=(.+)/)
                    coordinateSplit = $1.split(/,/)
                    rightStart = start + coordinateSplit[0].to_i
                    rightStop = start + coordinateSplit[0].to_i - coordinateSplit[1].to_i + 1
                    rightTStart = coordinateSplit[0]
                    rightTStop = coordinateSplit[0].to_i - coordinateSplit[1].to_i + 1
                  elsif(line =~ /^(PRIMER_PAIR_.+)=(.+)$/)
                    val = $2
                    cleanAttr = $1.gsub(/_\d+_/, '_')
                    leftComments[cleanAttr] = val
                    rightComments[cleanAttr] = val
                    ampComments[cleanAttr] = val
                  elsif(line =~ /^(.+LEFT.+)=(.+)$/)
                    val = $2
                    cleanAttr = $1.gsub(/_\d+_/, '_')
                    leftComments[cleanAttr] = val
                    ampComments[cleanAttr] = val
                  elsif(line =~ /^(.+RIGHT.+)=(.+)$/)
                    val = $2
                    cleanAttr = $1.gsub(/_\d+_/, '_')
                    rightComments[cleanAttr] = val
                    ampComments[cleanAttr] = val
                  end
                }
                if(leftStop < leftStart)
                  leftStart, leftStop = leftStop, leftStart
                end
                if(rightStop < rightStart)
                  rightStart, rightStop = rightStop, rightStart
                end

                # print left primer
                leftComments.keys.sort.each { |attr| leftCommentsStr += "#{attr}=#{leftComments[attr]}; " }
                lffOutFile.print "#{klass}\t#{name}_#{productNames[name]}\t#{type}\t#{subtype}\t#{chrom}\t#{leftStart}\t#{leftStop}\t+\t.\t0\t#{leftTStart}\t#{leftTStop}\t#{leftCommentsStr}\t#{leftSequence}\n"
                # print right primer
                rightComments.keys.sort.each { |attr| rightCommentsStr += "#{attr}=#{rightComments[attr]}; " }
                lffOutFile.print "#{klass}\t#{name}_#{productNames[name]}\t#{type}\t#{subtype}\t#{chrom}\t#{rightStart}\t#{rightStop}\t-\t.\t0\t#{rightTStart}\t#{rightTStop}\t#{rightCommentsStr}\t#{rightSequence}\n"
                # Print amplicon
                ampComments.keys.sort.each { |attr| ampCommentsStr += "#{attr}=#{ampComments[attr]}; " }
                lffOutFile.print "#{ampKlass}\t#{name}_#{productNames[name]}\t#{ampType}\t#{ampSubtype}\t#{chrom}\t#{leftStart}\t#{rightStop}\t+\t.\t0\t#{leftTStart}\t#{rightTStop}\t#{ampCommentsStr}\n"
                productNames[name] += 1
              }
            end
          }
          p3reader.close()
          lffOutFile.close()

          # Upload file to Genboree
          BRL::Genboree::ToolPlugins::Util::SeqUploader.uploadLFF( "#{output}.lff", refSeqId, userId )
        else # p3cmd failed
          # Open the .results file
          # Grab the contents to make a Error message
          # Raise error for framework to handle, with this error.
          p3err = nil
          File.open("#{output}.results", 'r') { |ff| p3err = ff.read }
          p3ErrMsg = "\n\nPrimer3 did not like your parameters.\n\nPlease see its complaint on the PRIMER_ERROR line below:\n\n"
          p3ErrMsg += "#{p3err}\n\n"
          $stderr.puts p3ErrMsg # for logging
          raise p3ErrMsg
        end

        cleanup_files(filesToCleanUp) # Gzips files listed

        return [ ]
      end
    end # class Primer3Tool
  end # module Primer3
end ; end ; end ; end
