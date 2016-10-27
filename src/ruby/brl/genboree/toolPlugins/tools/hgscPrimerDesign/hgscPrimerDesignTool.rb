require 'erb'
require 'brl/util/textFileUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/toolPlugins/util/util.rb'
include BRL::Genboree::ToolPlugins
include BRL::Genboree::ToolPlugins::Util

module BRL module Genboree ; module ToolPlugins; module Tools
  module HgscPrimerDesignTool  # module namespace to hold various classes (or even various tools)
    class HgscPrimerDesignClass # an actual tool
      # DEFINE your about() method
      def self.about()
        return  {
                  :title => "HGSC Primer Design",
                  :desc => "Runs HGSC's primer design pipeline on the selected template track.",
                  :functions => self.functions()
                }
      end

      # DEFINE a method that describes the characteristics of each function (tool) available.
      # The keys in the returned hash must match a function name in this class.
      # The :input description key contains the custom parameters (inputs) to the tool.
      # However, some, such as expname, refSeqId, etc, are ~universal.
      def self.functions()
        return  {
          :runHGSCPrimerDesign =>     # Must match a function/tool name in this class
          {
            :title => 'HGSC Primer Design',
            :desc => "Runs HGSC's primer design pipeline on the selected template track.",
            :displayName => '4) HGSC Primer Design Pipeline', # Displayed in tool-list HTML
            :internalName => 'hgscPrimerDesign',    # Internal reference/key
            :autoLinkExtensions => { 'lff.gz' => 'lff.gz' },  # List all src file extensions => dest file extensions.
            :resultFileExtensions => { 'primers.lff.gz' => true, 'amplicons.lff.gz' => true,  'primerOutput.txt.gz' => true },    # List all result files accessible via the output page.

            # :INPUT :>
            # These *must* match the form element ids. They will be checked automatically
            # for basic presence. They CANNOT be missing in the form!
            :input =>
            {
              :expname  => { :desc => "Job Name" },
              :refSeqId => { :desc => "Genboree uploadId for input LFF data" },

              :hgscProj => { :desc => "Is project an internal HGSC project?." },

              :trackType => { :desc => "The type for the primer Genboree track" },
              :trackSubtype => { :desc => "The subtype for the primer Genboree track" },
            }
          }
        }
      end

      # THIS IS THE FUNCTION THAT RUNS THE ACTUAL TOOL.
      # Here, it is called 'tileLongAnnos', as returned by self.functions()
      # NOTE: It is also possible to *do* the actual tool here. That might not
      # be a good idea, for organization purposes. Keep the tool *clean* of this
      # framework/convention stuff and make it it's own class or even program.
      def runHGSCPrimerDesign( options )
        # Keep track of files we want to clean up when finished
        filesToCleanUp = []

        # REQUIRED: get your command-line (or method-call) options together to
        # build a proper call to the wrapped tool.
        # Plugin options
        expname = options[:expname]
        refSeqId = options[:refSeqId]
        hgscProj = options[:annoNames]
        output = options[:output]

        # Make trackArray for track orders
        trackArray = getTrackArray(options)

        # Output options
        outputTrackType = options[:trackTypeName]
        outputTrackSubtype = options[:trackSubtypeName]

#        # ENSURE output dir exists (standardized code)
#        output =~ /^(.+)\/[^\/]*$/
#        outputDir = $1
#        checkOutputDir( outputDir )
#
#        # PREPARATION CODE:
#        #
#        # PREPROCESS the input lff file if needed (eg to make a new file more appropriate
#        # as input for the wrapped tool or whatever). This is not always necessary.
#        # Here is a sort of template / example.
#        #
#        # if( needToPreprocess )  # <-- sometimes decision is based on form data.
#        #   newInputLffFileName = template_lff + ".newPad"
#        #   writer = BRL::Util::TextWriter.new(newInputLffFileName)
#        #   reader = BRL::Util::TextReader.new(template_lff)
#        #   reader.each { |line|
#        #     next if(line =~ /^\s*$/ or line =~ /^\s*\[/)
#        #     arrSplit = line.split("\t")
#        #     next unless(arrSplit.length >= 10)
#        #     # Do something to LFF line:
#        #     arrSplit[5] = arrSplit[5].to_i - upstreamPadding
#        #     arrSplit[6] = arrSplit[6].to_i + downstreamPadding
#        #     writer.print(arrSplit.join("\t"))
#        #  }
#        #  writer.close()
#        #  # Replace old LFF file with this new one.
#        #  File.delete(template_lff)
#        #  File.rename(newTemplateLff, template_lff)
#        # end
#
#        # GET ANY DNA SEQUENCE file the tool may need also.
#        # This is not always necessary.
#        # Here is a sort of template / example.
#        #
#        # rtrv = BRL::Genboree::ToolPlugins::Util::MySeqRetriever.new()
#        # fastaWriter = BRL::Util::TextWriter.new(template_lff + ".fasta")
#        # lffReader = BRL::Util::TextReader.new(template_lff)
#        # filesToCleanUp << template_lff  # CLEAN UP: input LFF file
#        # seqRec = nil # declare in outer scope for > speed
#        # # go through each sequence the Retriever finds using the lffFile:
#        # rtrv.each_seq(refSeqId, lffReader) { |seqRec|
#        #   # Do something with the sequence (eg write it to a command file or just a fasta file or whatever)
#        #   writer.puts seqRec
#        # }
#        # reader.close()
#        # writer.close()
#
#        # CREATE ANY OTHER FILES you need. For example, files with commands or
#        # lists of things in tool-specific formates, etc.
#        # Here is a sort of template / example:
#        #
#        #  p3cmdFileName = "#{output}.p3cmd"
#        #  p3cmdWriter = BRL::Util::TextWriter.new(p3cmdFileName)
#        #  filesToCleanUp << p3cmdFileName # CLEAN UP: primer3 execution file
#        #  # write stuff to the file
#        #  p3cmdWriter.puts "<some info>"
#        #  p3cmdWriter.close()
#
#        # BUILD COMMAND to call
#        cleanOutput = output.gsub(/ /, '\ ') # you need to use this to deal with spaces in files (which are ok!)
#        tilerCmd =  "#{LFF_TILER_APP} -f #{template_lff} -m #{maxAnnoSize} -s #{tileSize} -o #{tileOverlap} " +
#                    " #{' -l ' if(overlapIsBp)} #{' -i ' if(excludeUntiledAnnos)} -t #{outputTrackType} -u #{outputTrackSubtype} " +
#                    " > #{cleanOutput}.lffTiler.out 2> #{cleanOutput}.lffTiler.err"
#        $stderr.puts "#{Time.now.to_s} TilerTool#tileLongAnnos(): command is:\n    #{tilerCmd}\n" # for logging
#
#        # EXECUTE *ACTUAL* TOOL:
#        cmdOK = system( tilerCmd )
#        filesToCleanUp << "#{cleanOutput}.lffTiler.out"  # CLEAN UP: out file from lffTiler.
#        filesToCleanUp << "#{cleanOutput}.lffTiler.err"  # CLEAN UP: err file from lffTiler.
#
#        # CHECK RESULT OF TOOL. Eg this might be a command code ($? after a system() call), nil/non-nil,
#        # or whatever. If ok, process any raw tool output files if needed. If not ok, put error info.
#        if(cmdOK) # Command succeeded
#          # PROCESS TOOL OUTPUT. If needed. For example, to make it an HTML page, or more human-readable.
#          # Or to create LFF(s) from it so it can be uploaded.
#          # Not all tools need to process tool output (e.g. if tool dumps LFF directly or is not upload-related)
#          #
#          # - open output file(s)
#          # - open new output file(s)
#          # - process output and close everything
#
#          # GZIP OUTPUT FILES. You should gzip your output files to save space.
#          # Some output can be huge and you don't know that the user hasn't
#          # selected their 10 million annos track to work on. Use the BRL
#          # TextWriter to read the files in output.rhtml.
#          `gzip #{cleanOutput}.tiles.lff`
#          `gzip #{cleanOutput}.tiled.lff`
#          `gzip #{cleanOutput}.untiled.lff`
#
#          # UPLOAD DATA into Genboree as LFF.
#          # Sometimes the user chooses to do this or not. Sometimes it is a
#          # required step for the tool. Sometimes there is one file to upload.
#          # Sometimes there are many. Deal with the decisions and then the
#          # uploading in the following *standardized* way:
#           BRL::Genboree::ToolPlugins::Util::SeqUploader.uploadLFF( "#{template_lff}.tiles.lff", refSeqId, userId )
#        else # Command failed
#          # Open any files you need to in order to get informative errors or any
#          # data that is available.
#          # Then:
#          #
#          # Raise error for framework to handle, with this error.
#          errMsg = "\n\nThe Tiler program failed and did not fully complete.\n\n"
#          raise errMsg
#          $stderr.puts  "TILER ERROR: Tiler died: '#{errMsg.strip}'\n"
#          options.keys.sort.each { |key| $stderr.puts "  - #{key} = #{options[key]}\n" }
#        end
#
#        # CLEAN UP CALL. This is *standardized*, call it at the end.
#        cleanup_files(filesToCleanUp) # Gzips files listed
        return [ ]
      end
    end # class TilerClass
  end # module TilerTool
end ; end ; end ; end
