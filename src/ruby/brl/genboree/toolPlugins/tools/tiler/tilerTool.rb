# ##############################################################################
# LIBRARIES
# ##############################################################################
require 'cgi'
require 'erb'
require 'yaml'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/toolPlugins/util/util.rb'
include BRL::Genboree::ToolPlugins
include BRL::Genboree::ToolPlugins::Util

# ##############################################################################
# NAMESPACE
# - a.k.a. 'module'
# - This is *very* important.
# - How your tool is expected to be found.
# - First part is *standard* ; second is the module for your tool within Genboree
# - Must match the directory location + "Tool"
# - //brl-depot/.../brl/genboree/toolPlugins/tools/tiler/
# ##############################################################################
module BRL module Genboree ; module ToolPlugins; module Tools
  # Your tool's specific namespace
  module TilerTool    # module namespace to hold various classes (or even various tools)

  # ##############################################################################
  # TOOL WRAPPER
  # - a specific class with some required methods
  # - this class wraps the tool execution and is 'registered' with the framework
  # ##############################################################################
    class TilerClass  # an actual tool

      # ---------------------------------------------------------------
      # REQUIRED METHODS
      # ---------------------------------------------------------------
      # DEFINE your about() method
      def self.about()
        return  {
                  :title => 'Split and Tile',
                  :desc => 'Designs a tiling annotation set across long source annotations.',
                  :functions => self.functions()
                }
      end

      # DEFINE functions(), an info-providing method.
      # - describes the characteristics of the function (tool) available
      # - keys in the returned hash must match a method name in this class.
      # - :input info key contains the custom parameters (inputs) to the tool.
      # - many other info keys, such as expname, refSeqId, etc, are universal
      #   and must be present
      def self.functions()
        return  {
          :tileLongAnnos =>     # Must match a method name in this class (tool execution method)
          {
            :title => 'Tile Across Long Annotations',
            :desc => 'Designs a tiling annotation set across long source annotations.',
            :displayName => '2) Annotation Tiler',    # Displayed in tool-list HTML to user
            :internalName => 'tiler',                 # Internal reference/key
            # List all src file extensions => dest file extensions:
            :autoLinkExtensions => { 'lff.gz' => 'lff.gz' },
            # List all output extensions that will be available to the user:
            # - NOTE: the BASE of these files is expected to be the JOB NAME provided by the user.
            # - it is an *extension*, so a . will join it to the file BASE
            # - make sure to adhere to this convention.
            :resultFileExtensions =>  {
                                        'sorted.tiles.lff.gz' => true,
                                        'sorted.tiled.lff.gz' => true,
                                        'sorted.untiled.lff.gz' => true
                                      },
            # :INPUT parameters
            # - These *must* match the form element ids EXACTLY.
            # - Form element data is pre-processed a bit before you get it.
            # - They CANNOT be missing in the form nor missing here, unless noted.
            :input =>
            {
              # Standard: job name and database id
              :expname  =>  { :desc => "Job Name: ", :paramDisplay => 1 },
              :refSeqId => { :desc => "Genboree uploadId for input LFF data: ", :paramDisplay => -1 },
              # Input track...framework notices _lff and provides the _lff file for your tool.
              :template_lff => { :desc => "Track to tile: ", :paramDisplay => -1},
              # Exception: this following is created by the framework for
              # _lff form data elements.
              :template_lff_ORIG => { :desc => "Track to tile: ", :paramDisplay => 2},

              # Tool-specific parameters:
              :maxAnnoSize => { :desc => "Tile across annotations larger than: ", :paramDisplay => 3 },
              :tileSize => { :desc => "Size of each tile: ", :paramDisplay => 4 },
              :tileOverlap => { :desc => "Amount of overlap between tiles: ", :paramDisplay => 5 },
              :bpOrPerc => { :desc => "Is the overlap in bp or % ? ", :paramDisplay => 8 },
              :minTileSize => { :desc => "Minimum tile size: ", :paramDisplay => 5 },
              :leftAnnoPad => { :desc => "Left annotation pre-pad: ", :paramDisplay => 6 },
              :rightAnnoPad => { :desc => "Right annotation pre-pad: ", :paramDisplay => 7 },

              :uniqAnnoNames => { :desc => "Enforce sensible and unique tile names? ", :paramDisplay => 9 },
              :stripVerNums => { :desc => "Strip annoation version numbers when naming tiles? ", :paramDisplay => 10 },

              # Output track parameters:
              :trackClass => { :desc => "Tile track class: ", :paramDisplay => 12 },
              :trackType => { :desc => "Tile track type: ", :paramDisplay => 13 },
              :trackSubtype => { :desc => "Tile track subtype: ", :paramDisplay => 14 },
              :excludeUntiledAnnos => { :desc => "Exclude untiled source annotations in output?", :paramDisplay => 11 }
            }
          }
        }
      end

      # ---------------------------------------------------------------
      # TOOL-EXECUTION METHOD
      # - THIS IS THE FUNCTION THAT RUNS THE ACTUAL TOOL.
      # - Must match the top-level hash key in self.functions() above.
      # ---------------------------------------------------------------
      # - Here, it is called 'tileLongAnnos', as returned by self.functions()
      # - Argument must be 'options', a hash with form data and a couple extra
      #   entries added by the framework. Get your data from there.
      # - NOTE: It is also possible to *do* the actual tool here. That might not
      #   be a good idea, for organization purposes. Keep the tool *clean* of this
      #   framework/convention stuff and make it it's own class or even program.
      def tileLongAnnos( options )
        # Keep track of files we want to clean up (gzip) when finished
        filesToCleanUp = []

        # -------------------------------------------------------------
        # GATHER NEEDED PARAMETERS
        # - get your command-line (or method-call) options together to
        #   build a proper call to the wrapped tool.
        # -------------------------------------------------------------
        # Plugin options
        expname = options[:expname]
        refSeqId = options[:refSeqId]
        userId = options[:userId]
        # Framework has turned this into a file-path to the LFF:
        template_lff = options[:template_lff]
        # File path where input data is and where output goes:
        output = options[:output]

        # Tiling options
        maxAnnoSize = options[:maxAnnoSize].to_i
        tileSize = options[:tileSize].to_i
        tileOverlap = options[:tileOverlap].to_f
        overlapIsBp = options[:bpOrPerc] == 'bp' ? true : false
        minTileSize = options[:minTileSize].to_i
        leftAnnoPad = options[:leftAnnoPad].to_i
        rightAnnoPad = options[:rightAnnoPad].to_i

        # Naming options
        uniqAnnoNames = options.key?(:uniqAnnoNames)
        stripVerNums = options.key?(:stripVerNums)

        # Output options
        outputTrackClass = options[:trackClass]
        outputTrackType = options[:trackType]
        outputTrackSubtype = options[:trackSubtype]
        excludeUntiledAnnos = options[:excludeUntiledAnnos] == 'true' ? true : false

        # -------------------------------------------------------------
        # ENSURE output dir exists (standardized code)
        # NOTE: "output" is UNescaped file path. MUST pay attention where you use an UNescaped path
        #       and where you use an ESCaped path. Generally:
        #       - MUST use UNescaped path when making use of Ruby calls. True file name.
        #       - Use ESCaped path when using command-line calls. "sh" will interpret incorrectly otherwise.
        # -------------------------------------------------------------
        output =~ /^(.+)\/[^\/]*$/
        outputDir = $1
        checkOutputDir( outputDir )
        # NOTE: this is an ESCaped version of the file path, suitable (more or less)
        #       for use on the command line. This is not fully escaped however, on purpose.
        #       It is expected that the weird chars (`'; for eg) are not permitted by the
        #       UI for job names. Unfortunately, ' ' (space) is NOT a weird character, so
        #       we must escape it.
        cleanOutput = output.gsub(/ /, '\ ') # you need to use this to deal with spaces in files (which are ok!)

        # -------------------------------------------------------------
        # SAVE PARAM DATA (marshalled ruby)
        # -------------------------------------------------------------
        BRL::Genboree::ToolPlugins::Util::saveParamData(options, output, TilerClass.functions()[:tileLongAnnos][:input])

        # -------------------------------------------------------------
        # PREPARATION CODE:
        # - Prepare data prior to running your tool
        # - Eg, PREPROCESS the input lff file if needed (eg to make a new file more appropriate
        #   as input for the wrapped tool or whatever). This is not always necessary.
        #
        # Some example activities follow:

        ## PRE-PAD LFF RECORDS:
        # if( needToPreprocess )  # <-- sometimes decision is based on form data.
        #   newInputLffFileName = template_lff + ".newPad"
        #   writer = BRL::Util::TextWriter.new(newInputLffFileName)
        #   reader = BRL::Util::TextReader.new(template_lff)
        #   reader.each { |line|
        #     next if(line =~ /^\s*$/ or line =~ /^\s*\[/)
        #     arrSplit = line.split("\t")
        #     next unless(arrSplit.length >= 10)
        #     # Do something to LFF line:
        #     arrSplit[5] = arrSplit[5].to_i - upstreamPadding
        #     arrSplit[6] = arrSplit[6].to_i + downstreamPadding
        #     writer.print(arrSplit.join("\t"))
        #  }
        #  writer.close()
        #  # Replace old LFF file with this new one.
        #  File.delete(template_lff)
        #  File.rename(newTemplateLff, template_lff)
        # end

        ## GET ANY DNA SEQUENCE file the tool may need also.
        # This is not always necessary.
        # Here is a sort of template / example.
        #
        # rtrv = BRL::Genboree::ToolPlugins::Util::MySeqRetriever.new()
        # fastaWriter = BRL::Util::TextWriter.new(template_lff + ".fasta")
        # lffReader = BRL::Util::TextReader.new(template_lff)
        # filesToCleanUp << template_lff  # CLEAN UP: input LFF file
        # seqRec = nil # declare in outer scope for > speed
        # # go through each sequence the Retriever finds using the lffFile:
        # rtrv.each_seq(refSeqId, lffReader) { |seqRec|
        #   # Do something with the sequence (eg write it to a command file or just a fasta file or whatever)
        #   writer.puts seqRec
        # }
        # reader.close()
        # writer.close()

        ## CREATE ANY OTHER FILES you need. For example, files with commands or
        # lists of things in tool-specific formates, etc.
        # Here is a sort of template / example:
        #
        #  p3cmdFileName = "#{output}.p3cmd"
        #  p3cmdWriter = BRL::Util::TextWriter.new(p3cmdFileName)
        #  filesToCleanUp << p3cmdFileName # CLEAN UP: primer3 execution file
        #  # write stuff to the file
        #  p3cmdWriter.puts "<some info>"
        #  p3cmdWriter.close()

        # SORT INPUT FILE
        # - this preparation step is needed for *some* tiling scenarios (ok, most)
        if(uniqAnnoNames)
          # Prep command string
          # NOTE: use ESCaped version cleanOutput, because this is a shell-call.
          # - make sure to re-escape any file names based on CGI.escape()
          #   (the tool will do one layer of CGI.unescape() as part of parsing the arguments, so this is necessary)
          sortCmd = "#{RUBY_APP} #{LFF_SORTER_APP} -f #{CGI.escape(template_lff)} > #{cleanOutput}.sorted 2> #{cleanOutput}.sortError "
          $stderr.puts "#{Time.now} TilerTool#tileLongAnnos(): SORT command is:\n    #{sortCmd}\n" # for logging
          # Run command
          cmdOK = system( sortCmd )
          # Record clean up files
          filesToCleanUp << "#{cleanOutput}.sortError"
          # Check command status, raise error about any problems
          if(cmdOK)
            filesToCleanUp << template_lff
          else
            errMsg = "\n\nThe Tiler program failed and did not fully complete. Error sorting the input data.\n\n"
            $stderr.puts  "TILER ERROR: Tiler died during sorting: '#{errMsg.strip}'\n"
            options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
            raise errMsg
          end
        else # no matter what, rename file to ".sorted" so extension is standard for all scenarios
          # Run command; use ESCaped version cleanOutput, because this is a shell-call.
          `mv #{template_lff} #{cleanOutput}.sorted`
        end
        # Common extension even if not actually sorted:
        template_lff = "#{cleanOutput}.sorted".gsub(/\\/, '')
        filesToCleanUp << "#{template_lff}"

        # -------------------------------------------------------------
        # EXECUTE WRAPPED TOOL
        # -------------------------------------------------------------
        # Prep command string:
        # - use ESCaped version cleanOutput, because this is a shell-call.
        # - make sure to re-escape any file names based on CGI.escape()
        #   (the tool will do one layer of CGI.unescape() as part of parsing the arguments, so this is necessary)
        tilerCmd =  "#{RUBY_APP} #{LFF_TILER_APP} -f #{CGI.escape(template_lff)} -m #{maxAnnoSize} -s #{tileSize} -o #{tileOverlap} " +
                    " #{' -l ' if(overlapIsBp)} #{' -i ' if(excludeUntiledAnnos)} -c '#{CGI.escape(outputTrackClass)}' -t '#{CGI.escape(outputTrackType)}' -u '#{CGI.escape(outputTrackSubtype)}' " +
                    " #{' -v ' if(stripVerNums)} #{' -q ' if(uniqAnnoNames)} " +
                    " -n  #{minTileSize} -5 #{leftAnnoPad} -3 #{rightAnnoPad} " +
                    " > #{cleanOutput}.lffTiler.out 2> #{cleanOutput}.lffTiler.err"
        $stderr.puts "#{Time.now.to_s} TilerTool#tileLongAnnos(): TILER command is:\n    #{tilerCmd}\n" # for logging

        # Run tool command:
        cmdOK = system( tilerCmd )
        # NOTE: use ESCaped version cleanOutput, because clean up is a shell-call.
        filesToCleanUp << "#{cleanOutput}.lffTiler.out"  # CLEAN UP: out file from lffTiler.
        filesToCleanUp << "#{cleanOutput}.lffTiler.err"  # CLEAN UP: err file from lffTiler.

        # -------------------------------------------------------------
        # CHECK RESULT OF TOOL.
        # - Eg this might be a command code ($? after a system() call), nil/non-nil,
        #   or whatever. If ok, process any raw tool output files if needed. If not ok, put error info.
        # -------------------------------------------------------------
        if(cmdOK) # Command succeeded

          # -------------------------------------------------------------
          # POST-PROCESS TOOL OUTPUT. If needed.
          # - For example, to make it an HTML page, or more human-readable.
          # - Or to create LFF(s) from tool so it can be uploaded.
          # - Not all tools need to process tool output (e.g. if tool dumps LFF directly
          #   or is not upload-related)
          #
          # - open output file(s)
          # - open new output file(s)
          # - process output and close everything

          # -------------------------------------------------------------
          # GZIP SUCCESSFUL OUTPUT FILES.
          # - You *must* register your output files to save space.
          # - Some output can be huge and you don't know that the user hasn't
          #   selected their 10 million annos track to work on.
          # NOTE: use ESCaped version cleanOutput, because clean up is a shell-call.
          filesToCleanUp << "#{template_lff}.tiles.lff"
          filesToCleanUp << "#{template_lff}.tiled.lff"
          filesToCleanUp << "#{template_lff}.untiled.lff"

          # -------------------------------------------------------------
          # - UPLOAD DATA into Genboree as LFF.
          #   Sometimes the user chooses to do this or not. Sometimes it is a
          #   required step for the tool. Sometimes there is one file to upload.
          #   Sometimes there are many. Deal with the decisions and then the
          #   uploading in the following *standardized* way:
          template_lff = template_lff.gsub(/\\ /, ' ')
          BRL::Genboree::ToolPlugins::Util::SeqUploader.uploadLFF( "#{template_lff}.tiles.lff", refSeqId, userId )
        else # Command failed
          # Open any files you need to in order to get informative errors or any
          # data that is available.
          # Then:
          #
          # Raise error for framework to handle, with this error.
          errMsg = "\n\nThe Tiler program failed and did not fully complete.\n\n"
          $stderr.puts  "TILER ERROR: Tiler died: '#{errMsg.strip}'\n"
          options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
          raise errMsg
        end

        # -------------------------------------------------------------
        # CLEAN UP CALL. This is *standardized*, call it at the end.
        # -------------------------------------------------------------
        cleanup_files(filesToCleanUp) # Gzips files listed
        return [ ]
      end
    end # class TilerClass
  end # module TilerTool
end ; end ; end ; end # end namespace
