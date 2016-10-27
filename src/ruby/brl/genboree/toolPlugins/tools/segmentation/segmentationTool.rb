# ##############################################################################
# LIBRARIES
# ##############################################################################
require 'erb'
require 'yaml'
require 'cgi'
require 'json'
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
  module SegmentationTool    # module namespace to hold various classes (or even various tools)

  # ##############################################################################
  # TOOL WRAPPER
  # - a specific class with some required methods
  # - this class wraps the tool execution and is 'registered' with the framework
  # ##############################################################################
    class SegmentationClass  # an actual tool

      # ---------------------------------------------------------------
      # REQUIRED METHODS
      # ---------------------------------------------------------------
      # DEFINE your about() method
      def self.about()
        funcs = self.functions()
        return  {
                  :title => funcs[:segmentation][:title],
                  :desc => funcs[:segmentation][:desc],
                  :functions => funcs
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
          :segmentation =>     # Must match a method name in this class (tool execution method)
          {
            :title => 'Segmentation Tool',
            :desc => 'Segments the genome based on annotation scores, which are assumed to be log-ratios.',
            :displayName => '8) Segmentation Tool',     # Displayed in tool-list HTML to user
            :internalName => 'segmentation',             # Internal reference/key
            # List all src file extensions => dest file extensions:
            :autoLinkExtensions => { 'segments.lff.gz' => 'segments.lff.gz' },
            # List all output extensions that will be available to the user:
            # - NOTE: the BASE of these files is expected to be the JOB NAME provided by the user.
            # - it is an *extension*, so a . will join it to the file BASE
            # - make sure to adhere to this convention.
            :resultFileExtensions =>  {
                                        'segments.lff.gz' => true,
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
              :template_lff => { :desc => "Track to add attributes to: ", :paramDisplay => -1},
              # Exception: this following is created by the framework for
              # _lff form data elements. We use this to keep the existing parameter, since framework changes any *_lff NVPs.
              :template_lff_ORIG => { :desc => "Track to add attributes to: ", :paramDisplay => 2},

              # Tool-specific parameters:
              :minProbes => { :desc => "Minimum number of probes comprising a segment: ", :paramDisplay => 3 },
              :threshold => { :desc => "Minimum log-ratio score threshold for segments: ", :paramDisplay => 4 },
              :thresholdType => { :desc => "Type of tresholding: ", :paramDisplay => 5 },

              # Output track parameters:
              :trackClass => { :desc => "Output track class: ", :paramDisplay => 12 },
              :trackType => { :desc => "Output track type: ", :paramDisplay => 13 },
              :trackSubtype => { :desc => "Output track subtype: ", :paramDisplay => 14 },
            }
          }
        }
      end

      # ---------------------------------------------------------------
      # TOOL-EXECUTION METHOD
      # - THIS IS THE FUNCTION THAT RUNS THE ACTUAL TOOL.
      # - Must match the top-level hash key in self.functions() above.
      # ---------------------------------------------------------------
      # - Here, it is called 'segmentation', as returned by self.functions()
      # - Argument must be 'options', a hash with form data and a couple extra
      #   entries added by the framework. Get your data from there.
      # - NOTE: It is also possible to *do* the actual tool here. That might not
      #   be a good idea, for organization purposes. Keep the tool *clean* of this
      #   framework/convention stuff and make it it's own class or even program.
      def segmentation( options )
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
        inputLffFile = options[:template_lff_ORIG]
        # File path where input data is and where output goes:
        output = options[:output]

        # Lifting options
        minProbes = options[:minProbes]
        threshold = options[:threshold].to_f
        thresholdType = options[:thresholdType]
        thresholdType = 'absolute' if(thresholdType.nil? or thresholdType.empty?)

        # Output options
        outputTrackClass = options[:trackClass]
        outputTrackType = options[:trackType]
        outputTrackSubtype = options[:trackSubtype]

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
        BRL::Genboree::ToolPlugins::Util::saveParamData(options, output, SegmentationClass.functions()[:segmentation][:input])

        # -------------------------------------------------------------
        # PREPARATION CODE:
        # - Prepare data prior to running your tool

        # Clean up the input file too
        filesToCleanUp << "#{template_lff}"

        # -------------------------------------------------------------
        # EXECUTE WRAPPED TOOL
        # -------------------------------------------------------------
        # Prep command string:
        # - use ESCaped version cleanOutput, because this is a shell-call.'
        # - make sure to re-escape any file names based on CGI.escape()
        #   (the tool will do one layer of CGI.unescape() as part of parsing the arguments, so this is necessary)
        segmentCmd =  "segmentACGH.rb -f #{CGI.escape(template_lff)} -o #{cleanOutput}.segments.lff " +
                      (minProbes ? "-p #{minProbes}" : "") +
                      (thresholdType == 'stdev' ? " -e " : " -r ") + threshold.to_s +
                      " -c #{CGI.escape(outputTrackClass)} -t #{CGI.escape(outputTrackType)} -s #{CGI.escape(outputTrackSubtype)} "
        segmentCmd << " > #{cleanOutput}.segments.out 2> #{cleanOutput}.segments.err"
        $stderr.puts "#{Time.now.to_s} Segmentation#segmentation(): SEGMENT command is:\n    #{segmentCmd}\n" # for logging
        # Run tool command:
        cmdOK = system( segmentCmd )
        $stderr.puts "#{Time.now.to_s} Segmentation#segmentation(): LIFTER command exit ok? #{cmdOK.inspect}\n"
        # NOTE: use ESCaped version cleanOutput, because clean up is a shell-call.
        filesToCleanUp << "#{cleanOutput}.segments.lff.strip"
        filesToCleanUp << "#{cleanOutput}.segments.out"
        filesToCleanUp << "#{cleanOutput}.segments.err"
        filesToCleanUp << "#{cleanOutput}.segments.lff.segs.lff"
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
          # Tool strips the .lff before making these tmp files...so we need to do that too...
          template_noLff = template_lff.gsub(/\.lff$/, "")

          # -------------------------------------------------------------
          # - UPLOAD DATA into Genboree as LFF.
          #   Sometimes the user chooses to do this or not. Sometimes it is a
          #   required step for the tool. Sometimes there is one file to upload.
          #   Sometimes there are many. Deal with the decisions and then the
          #   uploading in the following *standardized* way:
          BRL::Genboree::ToolPlugins::Util::SeqUploader.uploadLFF( "#{output}.segments.lff", refSeqId, userId )
          filesToCleanUp << "#{cleanOutput}.segments.lff"
        else # Command failed
          # Open any files you need to in order to get informative errors or any
          # data that is available.
          # Then:
          #
          # Raise error for framework to handle, with this error.
          errMsg = "\n\nThe Segmentation program failed and did not fully complete.\n\n"
          $stderr.puts  "SEGMENTATION TOOL ERROR: segmentation tool died: '#{errMsg.strip}'\n"
          options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
          raise errMsg
        end

        # -------------------------------------------------------------
        # CLEAN UP CALL. This is *standardized*, call it at the end.
        # -------------------------------------------------------------
        cleanup_files(filesToCleanUp) # Gzips files listed
        return [ ]
      end
    end # class SegmentationClass
  end # module SegmentationTool
end ; end ; end ; end # end namespace
