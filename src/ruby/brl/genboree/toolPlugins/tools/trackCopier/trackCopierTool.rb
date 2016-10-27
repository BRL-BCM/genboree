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
  module TrackCopierTool    # module namespace to hold various classes (or even various tools)

  # ##############################################################################
  # TOOL WRAPPER
  # - a specific class with some required methods
  # - this class wraps the tool execution and is 'registered' with the framework
  # ##############################################################################
    class TrackCopierClass  # an actual tool

      # ---------------------------------------------------------------
      # REQUIRED METHODS
      # ---------------------------------------------------------------
      # DEFINE your about() method
      def self.about()
        funcs = self.functions()
        return  {
                  :title => funcs[:trackCopier][:title],
                  :desc => funcs[:trackCopier][:desc],
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
          :trackCopier =>     # Must match a method name in this class (tool execution method)
          {
            :title => 'Track Copier',
            :desc => 'Copies tracks from one database into the current database.',
            :displayName => '7) Track Copier',     # Displayed in tool-list HTML to user
            :internalName => 'trackCopier',             # Internal reference/key
            # List all src file extensions => dest file extensions:
            :autoLinkExtensions => { 'tracks2Copy.lff.gz' => 'tracks2Copy.lff.gz' },
            # List all output extensions that will be available to the user:
            # - NOTE: the BASE of these files is expected to be the JOB NAME provided by the user.
            # - it is an *extension*, so a . will join it to the file BASE
            # - make sure to adhere to this convention.
            :resultFileExtensions =>  {
                                        'tracks2Copy.lff.gz' => true,
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

              # Input group->database->tracks:alias JSON
              :selectedTrackHashStr => { :desc => "Tracks to copy into this database: ", :paramDisplay => -1 },
              :tracksToCopyParamStr => { :desc => "Tracks to copy into this database: ", :paramDisplay => 2},

              # Copy display settings, etc
              :copyDisplaySettings => { :desc => "Copy display settings, description, links, etc: ", :paramDisplay => 3}
            }
          }
        }
      end

      def makeTrackLFFs(cleanOutput, outputDir, tracksToCopyHash, refSeqId, userId, filesToCleanUp)
        # Create global LFF file
        globalLFFFile = "#{cleanOutput}.tracks2Copy.lff"
        touchCmd = "touch #{globalLFFFile}"
        cmdOk = system(touchCmd)
        unless(cmdOk)
          raise "\n\nERROR: TrackCopierClass#makeTrackLFFs => error creating global LFF file.\n" +
                "    - exit code: #{$?}\n" +
                "    - command: #{touchCmd}\n"
        end
        # Get a DBUtil object
        dbrcFile = ENV['DB_ACCESS_FILE'].dup.untaint
        genbConfig = GenboreeConfig.new()
        genbConfig.loadConfigFile()
        dbu = BRL::Genboree::DBUtil.new(genbConfig.dbrcKey, nil, dbrcFile)
        # Connect to main genboree database
        dbu.connectToMainGenbDb()
        # Get each track LFF, modify it if needed, add it to the global LFF file
        tracksToCopyHash.each_key { |groupName|
          # For each groupName, get the group id
          groupId = dbu.selectGroupByName(groupName).first['groupName']
          byDatabases = tracksToCopyHash[groupName]
          byDatabases.each_key { |databaseName|
            # For each databaseName, get the refSeqId
            dbRefSeqId = dbu.selectRefseqByName(databaseName).first['refSeqId']
            byTracks = byDatabases[databaseName]
            byTracks.each_key { |trackName|
              trackAlias = byTracks[trackName]
              # For each trackName, download the LFF file
              cleanTrack = CGI.escape(trackName) # Make the track ultra-safe for DIR-naming
              trackLFF = "#{outputDir}/#{userId}_#{refSeqId}_#{cleanTrack}_#{Time.now.to_i}.lff"
              commandStr =  "java -classpath #{JCLASS_PATH} -Xmx1800M " +
                            " org.genboree.downloader.AnnotationDownloader " +
                            " -u #{userId} " +
                            " -r '#{dbRefSeqId}' " +
                            " -m '#{CGI.escape(trackName)}' " +
                            " > #{trackLFF} " +
                            " 2> #{trackLFF}.err "
              $stderr.puts "\n\nTRACK COPIER: track-download command:\n\n#{commandStr}\n\n"
              cmdOk = system(commandStr)
              unless(cmdOk)
                raise "\n\nERROR: TrackCopierClass#makeTrackLFFs => error with calling annotation downloader.\n" +
                      "    - exit code: #{$?.existstatus}\n" +
                      "    - command:   #{commandStr}\n"
              else
                filesToCleanUp << trackLFF
                filesToCleanUp << "#{trackLFF}.err"
              end
              # If alias not same as trackName, modify downloaded LFF file to use alais
              renameTrackInLFF(trackLFF, trackName, trackAlias) if(trackName != trackAlias)
              # Concatenate downloaded LFF file to global LFF file
              catCmd = "cat #{trackLFF} >> #{globalLFFFile}"
              cmdOk = system(catCmd)
              unless(cmdOk)
                raise "\n\nERROR: TrackCopierClass#makeTrackLFFs => error with cat'ing LFF to global LFF.\n" +
                      "    - exit code: #{$?.exitstatus}\n" +
                      "    - command:   #{catCmd}\n"
              end
            }
          }
        }
        return globalLFFFile
      end

      def renameTrackInLFF(trackLFF, trackName, trackAlias)
        trackName =~ /^([^:]+):([^:]+)$/
        trackType,trackSubtype = $1.strip(), $2.strip()
        trackAlias =~ /^([^:]+):([^:]+)$/
        aliasType,aliasSubtype = $1.strip(), $2.strip()
        newFile = File.open("#{trackLFF}.tmp", "w+")
        lffFile = File.open(trackLFF)
        lffFile.each { |line|
          line.strip!
          next if(line !~ /\S/ or line =~ /^\s*[#\[]/)
          fields = line.split(/\t/)
          # If the track matches the old one, replace it with the new one
          if(fields[2] == trackType and fields[3] == trackSubtype)
            fields[2] = aliasType and fields[3] = aliasSubtype
            line = fields.join("\t")
          end
          newFile.puts line
        }
        lffFile.close()
        newFile.close()
        # Rename newFile to lffFile
        File.delete(trackLFF)
        File.rename("#{trackLFF}.tmp", trackLFF)
        return
      end

      def makeTracksToCopyStr(tracksToCopyHash)
        retVal = ''
        tracksToCopyHash.each_key { |groupName|
          retVal << "GROUP: '#{groupName}'\n"
          tracksToCopyHash[groupName].each_key { |databaseName|
            retVal << "  DATABASE: '#{databaseName}'\n"
            tracksToCopyHash[groupName][databaseName].each_key { |trackName|
              aliasName = tracksToCopyHash[groupName][databaseName][trackName].strip()
              retVal << "    TRACK: '#{trackName}' AS '#{aliasName}'\n"
            }
          }
        }
        return retVal
      end

      # ---------------------------------------------------------------
      # TOOL-EXECUTION METHOD
      # - THIS IS THE FUNCTION THAT RUNS THE ACTUAL TOOL.
      # - Must match the top-level hash key in self.functions() above.
      # ---------------------------------------------------------------
      # - Here, it is called 'trackCopier', as returned by self.functions()
      # - Argument must be 'options', a hash with form data and a couple extra
      #   entries added by the framework. Get your data from there.
      # - NOTE: It is also possible to *do* the actual tool here. That might not
      #   be a good idea, for organization purposes. Keep the tool *clean* of this
      #   framework/convention stuff and make it it's own class or even program.
      def trackCopier( options )
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
        # File path where input data is and where output goes:
        output = options[:output]

        # Get the JSON for the groups->databases->tracks;aliases to copy and make a real hash and human readable string
        tracksToCopyJson = options[:selectedTrackHashStr]
        # Turn the JSON hash into a real hash
        tracksToCopyHash = JSON.parse(tracksToCopyJson)
        options[:tracksToCopyParamStr] = makeTracksToCopyStr(tracksToCopyHash)

        # Copy display setttings, etc?
        copyDisplaySettings = options[:copyDisplaySettings]
        copyDisplaySettings = false if(copyDisplaySettings.nil? or copyDisplaySettings !~ /\S/)

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
        BRL::Genboree::ToolPlugins::Util::saveParamData(options, output, TrackCopierClass.functions()[:trackCopier][:input])

        # -------------------------------------------------------------
        # PREPARATION CODE:
        # - Prepare data prior to running your tool
        $stderr.puts "TRACK COPIER: Done => prep work and saving params files"
        # For each group->database->track, download the track data file, modify if needed, then cat to global file
        globalLFFFile = makeTrackLFFs(cleanOutput, outputDir, tracksToCopyHash, refSeqId, userId, filesToCleanUp)
        $stderr.puts "TRACK COPIER: Done => making global LFF file for upload from src tracks"
        # Upload the global file
        # (Don't need \-escape spaces and such here)
        BRL::Genboree::ToolPlugins::Util::SeqUploader.uploadLFF( globalLFFFile.gsub(/\\/, ''), refSeqId, userId )
        $stderr.puts "TRACK COPIER: Done => uploading the global LFF file"
        filesToCleanUp << globalLFFFile
        # TODO: 4. If asked, copy the display settings
        # TODO: 4.1 For each group->database->track, get the various track settings
        # TODO: 4.2 For each group->database->track;alias, get the ftypeids
        # TODO: 4.3 Copy the display settings from the src to the destination
        # TODO: 5. Make sure cleaning up all intermediate files.

        # CLEAN UP CALL. This is *standardized*, call it at the end.
        # -------------------------------------------------------------
        cleanup_files(filesToCleanUp) # Gzips files listed
        return [ ]
      end
    end # class AttributeLifterClass
  end # module AttributeLifterTool
end ; end ; end ; end # end namespace
