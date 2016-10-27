# Matthew Linnell
# January 11th, 2006
#-------------------------------------------------------------------------------
# Module utilities to be used by the pattern discovery wizard script
#-------------------------------------------------------------------------------
$VERBOSE = nil
require 'stringio'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/seqRetriever'
require 'brl/genboree/dbUtil'
require 'brl/genboree/toolPlugins/util/binaryFeatures'
require 'brl/genboree/toolPlugins/tools/tools'
include BRL::Genboree

class MyHash < Hash
    attr_reader :freeze_keys
    attr_writer :freeze_keys
    alias assign []=

    def initialize( obj=nil )
        @freeze_keys = false
        super( obj )
    end

    def []= (key, val)
        return false if self.freeze_keys && !self.has_key?( key )
        assign( key, val )
    end
end

class SeqRecord
  attr_accessor :defline, :sequence, :noError

  def initialize(defline, seq)
    @defline, @sequence = defline, seq
    @noError = true
  end
end

module BRL
  module Genboree
    module ToolPlugins

      @@dbu = nil unless(defined?(@@dbu))

      #---------------------------------------------------------------------------
      # * *Function*: Returns database connection object, default connection to 'genboree'
      #
      # * *Usage*   : <tt> BRL::Genboree::ToolPlugins.connect( 'some_annot_dbname' ) </tt>
      # * *Args*    :
      #   - +annot+ -> Optional.  Default connects to 'genboree', otherwise connects to database specified here
      # * *Returns* :
      #   - +connection+ -> Return connection object created from DBUtil
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      def self.connect(annot=nil)
        if(@@dbu.nil?)
          dbrc_file = ENV['DB_ACCESS_FILE'].dup.untaint
          genbConfig = BRL::Genboree::GenboreeConfig.new()
          genbConfig.loadConfigFile()
          @@dbu = BRL::Genboree::DBUtil.new( genbConfig.dbrcKey, annot, dbrc_file )
        end
        return @@dbu
      end

      # Reap resources
      def self.clear()
        if(defined?(@@dbu) and !@@dbu.nil?)
          @@dbu.clearCaches()
          @@dbu.clear()
          @@dbu = nil
        end
        return
      end

      LFF_OUTPUT_PATH = "/usr/local/brl/data/genboree/toolPlugins/tmp"
      SCRATCH_PATH = "/usr/local/brl/data/genboree/toolPlugins/tmp"
      JAVA_PATH = ""
      JCLASS_PATH = ENV['CLASSPATH']
      RESULTS_PATH = "/usr/local/brl/data/genboree/toolPlugins"
      TOOL_LIBRARY_PATH = "/usr/local/brl/local/apache/ruby/brl/genboree/toolPlugins"
      RUBY_EXEC = "/usr/local/brl/local/bin/ruby" # using this because /bin/env ruby does not seem to be working
      RUBY_LIB_DIR = "/usr/local/brl/local/apache/ruby"
      TOOL_USER_LINKS = "/usr/local/brl/local/apache/htdocs/genboree/toolPlugins/links"
      PLUGIN_LOCK_FILE = "/usr/local/brl/data/genboree/lockFiles/plugins.lock"
      # A regular expression describing all characters that need to be escaped
      # when constructing command line options, thus preventing command injection
      # such as cgi['foo'] = ">2 err; do_something_bad"
      BAD_CHARS_RE = /\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\_|\+|\=|\||\;|\'|\>|\<|\/|\?/
      BAD_CHARS_REPLACEMENT = "_" # The character to use to replace bad chars

      #---------------------------------------------------------------------------
      # * *Function*: Returns the corresponding DBI::Row for user with userId
      #
      # * *Usage*   : <tt> BRL::Genboree::ToolPlugins.getUser( 1 ) </tt>
      # * *Args*    :
      #   - +userId+ -> The integer value for the userId
      # * *Returns* :
      #   - +DBI::Row+ -> The DBI::Row of the given user
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      def self.getUser( userId )
        user = nil
        begin
          @@dbu = BRL::Genboree::ToolPlugins.connect()
          user = @@dbu.getUserByUserId( userId )[0] # internal DB name
        rescue => @err
          $stderr.puts @err
          $stderr.puts @err.backtrace
        end
        return user
      end

      #---------------------------------------------------------------------------
      # * *Function*: Email a user with the given userId notification of job completion or err
      #
      # * *Usage*   : <tt> BRL::Genboree::ToolPlugins.email( 1, BRL::Genboree::ToolPlugins::Tools.list[options[:tool]], :someToolFunction, "Experiment A" ) </tt>
      # * *Args*    :
      #   - +userId+ -> The integer value for the userId
      #   - +tool+ -> The name of the tool executed
      #   - +function+ -> The name of the function of said tool that was executed
      #   - +expname+ -> The name of the experiment executed
      #   - +msg+ ->  Optional.  Use when default message not desired (such as notification of error)
      # * *Returns* :
      #   - +true+ ->
      # * *Throws* :
      #   - +none+
      #---------------------------------------------------------------------------
      def self.email( userId, toolClass, functionSym, expname, msg="" )
        begin
          functionInfo = toolClass.functions()[functionSym]
          toolLabel = functionInfo[:displayName]
          user = getUser( userId )
          name = "#{user[3]} #{user[4]}"
          email = user[6] # internal DB name
          genbConfig = BRL::Genboree::GenboreeConfig.new()
          genbConfig.loadConfigFile()
          mailer = Emailer.new(genbConfig.gbSmtpHost)
          # TODO add complete, failure info
          subject = "Your Genboree Tool Execution is complete"
          subject += " (errors)" unless msg.empty?
          if msg.empty?
            msg << "Congratulations #{name}!\n\nYour experiment titled '#{expname}' with the Genboree Tool labelled '#{toolLabel}' is complete."
            msg << "\n \nYour results for this experiment can be found under the experiment results section for this group. (Tools->Plugin Results)"
          end
          mailer.setHeaders( "genboree_admin@genboree.org", email, subject )
          mailer.setBody( msg )
          mailer.addRecipient( email )
          mailer.setMailFrom( "genboree_admin@genboree.org" )
          mailer.send()
        rescue => @err
          $stderr.puts @err
          $stderr.puts @err.backtrace
        end
        return true
      end

      module Util
        include BRL::Genboree::ToolPlugins::Util::Kmers
        DBRC_FILE = ENV['DB_ACCESS_FILE']

        # USEFUL FUNCTION TO SAVE PARAM DATA
        # This way we can easily load up the :input hash for this
        # Job during display-of-results.
        def self.saveParamData(options, baseFileName, inputsHash)
          paramOut = File.open("#{baseFileName}.PARAMS.ruby.dat", 'w+')
          paramHash = {}
          inputsHash.keys.each { |kk|
            unless(inputsHash[kk][:paramDisplay].nil?)
              paramHash[kk] = (options[kk].nil? ? nil : options[kk].gsub(/\\"/, "'")) # '
            end
          }
          Marshal.dump(paramHash, paramOut)
          paramOut.close()
          return
        end

        def self.loadParamData(baseFileName)
          paramFile = "#{baseFileName}.PARAMS.ruby.dat"
          if(File.exists?(paramFile))
            paramOut = File.open(paramFile)
            paramHash = Marshal.load(paramOut)
            return paramHash
          else
            return nil
          end
        end

        # Are there any .masked sequence files for this database?
        def self.databaseHasMaskedSeq?(refSeqId)
          retVal = false
          begin
            @@dbu = BRL::Genboree::ToolPlugins.connect()
            annoDbNameRows = @@dbu.selectDBNameByRefSeqID(refSeqId)
            annoDbName = annoDbNameRows[0]['databaseName']
            @@dbu.setNewDataDb(annoDbName)
            resultSet = @@dbu.selectValueFmeta('RID_SEQUENCE_DIR')
            retVal = false if(resultSet.nil? or resultSet.empty?)
            seqDirName = resultSet[0]['fvalue'] # first row, first value is the meta-value we looked up
            seqDirPattern = "#{seqDirName.strip}/*.masked"
            files = Dir[seqDirPattern]
            if(files.nil? or files.empty?)
              retVal = false
            else
              retVal = true
            end
          rescue => @err
            $stderr.puts "\nDATA CORRUPTION? => RefSeqID '#{refSeqId}' doesn't have a sequence directory?? Got error trying to access the directory:\n\n#{@err}"
            $stderr.puts @err.backtrace
            # Maybe ok, dir doesn't exist? That would be bad...at least it is logged
            retVal = false
          end
          return retVal
        end

        # Count number of attributes in database
        def self.countAttributes(refSeqId)
          retVal = nil
          begin
            @@dbu = BRL::Genboree::ToolPlugins.connect()
            annoDbNameRows = @@dbu.selectDBNameByRefSeqID(refSeqId)
            annoDbName = annoDbNameRows[0]['databaseName']
            @@dbu.setNewDataDb(annoDbName)
            resultSet = @@dbu.countAttributes()
            if(resultSet.nil? or resultSet.empty?)
              retVal = 0
            else
              retVal = resultSet[0][0].to_i
            end
          rescue => @err
            $stderr.puts @err
            $stderr.puts @err.backtrace
          end
          return retVal
        end

        # Get attribute names as Array
        # - option to get only a limited number (nil==get all)
        # - option to sort alphabetically
        def self.getAttributeList(refSeqId, maxNum=nil, doSort=false, sharedAttrAlso=true)
          retVal = nil
          begin
            @@dbu = BRL::Genboree::ToolPlugins.connect()
            # From local database
            annoDbNameRows = @@dbu.selectDBNameByRefSeqID(refSeqId)
            annoDbName = annoDbNameRows[0]['databaseName']
            @@dbu.setNewDataDb(annoDbName)
            resultSet = @@dbu.selectAllAttributes(maxNum)
            attrHash= {}
            unless(resultSet.nil?)
              resultSet.each { |row|
                attrHash[row['name']] = nil
              }
            end
            # From shared database
            if(sharedAttrAlso)
              sharedDbNameRows = @@dbu.selectDBNamesByRefSeqID(refSeqId)
              sharedDbNameRows.delete_if {|row| row['databaseName'] == annoDbName }
              sharedDbNameRows.each { |dbNameRow|
                dbName = dbNameRow['databaseName']
                @@dbu.setNewDataDb(dbName)
                @@dbu.connectToDataDb()
                resultSet = @@dbu.selectAllAttributes(maxNum)
                unless(resultSet.nil?)
                  resultSet.each { |row|
                    attrHash[row['name']] = nil
                  }
                end
              }
            end

            # Sort attribute list
            attrList = attrHash.keys
            attrHash.clear()
            if(doSort)
              attrList.sort!{ |aa,bb| aa.downcase <=> bb.downcase }
            end
            retVal = attrList
          rescue => @err
            $stderr.puts @err
            $stderr.puts @err.backtrace
          end
          return retVal
        end

        # Get sample attribute names as Array
        # - option to get only a limited number (nil==get all)
        # - option to sort alphabetically
        def self.getSampleAttributeList(refSeqId, maxNum=nil, doSort=false, sharedAttrAlso=true)
          retVal = nil
          begin
            @@dbu = BRL::Genboree::ToolPlugins.connect()
            # From local database
            annoDbNameRows = @@dbu.selectDBNameByRefSeqID(refSeqId)
            annoDbName = annoDbNameRows[0]['databaseName']
            @@dbu.setNewDataDb(annoDbName)
            resultSet = @@dbu.selectAllSamplesAttNames(maxNum)
            attrHash= {}
            unless(resultSet.nil?)
              resultSet.each { |row|
                attrHash[row['saName']] = nil
              }
            end
            # From shared database
            if(sharedAttrAlso)
              sharedDbNameRows = @@dbu.selectDBNamesByRefSeqID(refSeqId)
              sharedDbNameRows.delete_if {|row| row['databaseName'] == annoDbName }
              sharedDbNameRows.each { |dbNameRow|
                dbName = dbNameRow['databaseName']
                @@dbu.setNewDataDb(dbName)
                @@dbu.connectToDataDb()
                resultSet = @@dbu.selectAllSamplesAttNames(maxNum)
                unless(resultSet.nil?)
                  resultSet.each { |row|
                    attrHash[row['saName']] = nil
                  }
                end
              }
            end

            # Sort attribute list
            attrList = attrHash.keys
            attrHash.clear()
            if(doSort)
              attrList.sort!{ |aa,bb| aa.downcase <=> bb.downcase }
            end
            retVal = attrList
          rescue => @err
            $stderr.puts @err
            $stderr.puts @err.backtrace
          end
          return retVal
        end

        # Class designed to streamline uploading of sequence
        class SeqUploader
          def self.uploadLFF( file, refSeqId, userId, validate=false )
            return if(File.size(file) < 1)
            filesToCleanUp = [] # Keep track of files we want to gzip when done
            cleanFile = file.gsub(/ /, '_')
            if(cleanFile != file)
              File.link(file, cleanFile)  # Make clean temp file to keep Java happy
                                          # We don't need to clean this up, it will be deleted
            end
            javapath = "java "
            classpath = "-classpath #{JCLASS_PATH} "
            options = " -Xmx800M org.genboree.upload.AutoUploader " +
                      " #{'-v' if(validate)} -t lff -r #{refSeqId.to_i} " +
                      " -f #{cleanFile} -u #{userId} -z > #{cleanFile}.errors 2>&1 "
            uploaderCmd = "#{javapath} #{classpath} #{options}"
            uploadOutput = `#{javapath} #{classpath} #{options}`
            exitStatus = $?
            uploadOK = (exitStatus.exitstatus == 0)
            filesToCleanUp << "#{cleanFile}.errors"
            filesToCleanUp << "#{cleanFile}.log"
            filesToCleanUp << "#{cleanFile}.full.log"
            filesToCleanUp << "#{cleanFile}.entrypoints.lff"
            File.unlink(cleanFile) if(cleanFile != file) # Remove the Java-friendly file
            unless(uploadOK)
              $stderr.puts "\n\nGENBOREE UPLOADER FAILED. Exit status from uploader = #{exitStatus.inspect}\n\n"
              raiseStr = "\n\nThere was an error creating your Genboree tracks from the tool output.\n\nFor assistance resolving this issue, please contact a Genboree admin (genboree_admin@genboree.org).\n\nGenboree complained that:\n"
              if(exitStatus.exitstatus == 20)
                raiseStr << "The results cannot be uploaded due to too many errors (for example: incompatible chromosome names or coordinates).\n\n"
              elsif(exitStatus.exitstatus == 10)
                raiseStr << "Some results could not be uploaded due to errors (for example: incompatible chromosome names or coordinates).\n\n"
              else
                raiseStr << "\n\nThere was an error creating your Genboree tracks from the tool output.\n\nFor assistance resolving this issue, please contact a Genboree admin (genboree_admin@genboree.org).\n\nGenboree complained that:\n#{uploadOutput}\n\n"
              end
              raise raiseStr
            end
            cleanup_files( filesToCleanUp ) # Gzips the files listed
          end
        end

        class MySeqRetriever
          GET_SEQ_OK = true

          attr_accessor :useMasked

          def initialize(useMasked=false)
            @useMasked = useMasked
          end

          def createRetriever(doRevCompl=false, useMasked=false)
            @retriever = BRL::Genboree::SeqRetriever.new(DBRC_FILE)
            @retriever.doAllLower = true
            @retriever.useMasked = useMasked
            return true
          end

          def getRids( uploadId )
            # Cache rid information
            rids = nil
            begin
              @@dbu = BRL::Genboree::ToolPlugins.connect()
              dbNameRow = @@dbu.selectDBNameByUploadID( uploadId )
              db_name = dbNameRow['databaseName']
              @@dbu.setNewDataDb(db_name)
              rids = @@dbu.selectAllRefNames()
            rescue => @err
              $stderr.puts @err
              $stderr.puts @err.backtrace
            end
            return rids
          end

          # Convert rids from selectAllRefNames into hash
          def ridHash( rids )
            hsh = Hash.new
            rids.each{ |ridRec| hsh[ridRec['refname']] = ridRec }
            return hsh
          end

          # Go through each sequence, one at a time, and yield() the corresponding
          # SeqRecord object to the provided block
          def each_seq(refSeqId, lffIO, overrideStrand=nil)
            uploadId = self.getUploadIdByRefSeqId(refSeqId)
            # REUSE this retriever instance:
            retriever = BRL::Genboree::SeqRetriever.new(DBRC_FILE)
            retriever.useMasked = @useMasked
            retriever.getDataDBNameByUploadId(uploadId, true)
            # Cache frefRecs by refname
            rids = self.getRids( uploadId )
            rhsh = self.ridHash( rids )
            # Assuming standard LFF file -- tab delimeted fields, new line delimited entries
            lffIO.each_line { |line|
              next if(line =~ /^\s*$/ or line =~ /^\s*\[/ or line =~ /^\s*#/) # get rid of headers and blank
              # RAH 3/3/06 : Change so that name from lff file is included in defline
              fields = line.strip.split(/\t/)
              # MAL 3/6/06 : move name to inside the array, instead of outside
              seqRec = self.getSequence_light( retriever, uploadId, fields[5].to_i, fields[6].to_i, (overrideStrand ? overrideStrand : fields[7]), rhsh[fields[4]], fields[1] )
              unless(seqRec.kind_of?(SeqRecord)) # seqRec can be an integer (error, record in noError)
                tmp = SeqRecord.new(nil, nil)
                tmp.noError = seqRec
                seqRec = tmp
              end
              yield(seqRec)
            }
            return
          end

          def getSequence_light( retriever, uploadId, fstart, fstop, strand, ridRec, gname )
            retriever.doRevCompl = (strand == "-" ? true : false)
            retriever.rid = ridRec['rid']
            retriever.currFrefRec = ridRec

            # Set the coords
            setStatus = retriever.setFromAndTo(fstart, fstop)

            # Check that range is ok according to seqRetriever:
            return setStatus unless(setStatus == SeqRetriever::OK)
            # (it could also be: FROM_BEYOND_END, FROM_NEGATIVE, TO_BEYOND_END, TO_NEGATIVE, which are *errors*)

            defLine = retriever.makeSeqDefline(gname, retriever.rid, fstart, fstop)

            # Get sequence into memory
            seqRec = nil
            begin
              getSeqStatus = sequence = retriever.getAnnoSequence(uploadId, retriever.rid, fstart, fstop, false)
              seqRec = SeqRecord.new(defLine, sequence)
            rescue => err
              $stderr.puts "-"*50
              $stderr.puts "ERROR: problem getting sequence for (uploadId, retriever, fstart, fstop, false) => (#{uploadId}, #{retriever.inspect}, #{fstart}, #{fstop}, false)"
              $stderr.puts err.backtrace.join("\n")
              $stderr.puts "-"*50
              raise "\n\nThere is no sequence associated with the entry points (e.g. chromosomes) of\n" +
                    "your database.\n\nPlease upload the sequences of your entry points, or contact your\n" +
                    "Genboree group admins so they can do this for you.\n"
            end

            # Check status.
              # Various errors for missing seq file, etc, can be returned;
              # see the seqRetriever.rb code at the top for the error code list.
              # NOTE: one error you *must* handle nicely is the ones that happen
              # if the DB or the entry point in that DB has NO SEQUENCE. This is
              # a "normal" case in Genboree and must be handled gracefully.
            if(getSeqStatus.kind_of?(String) or getSeqStatus == SeqRetriever::OK)
              seqRec.noError = true
            else
              seqRec.noError = getSeqStatus
            end

            return seqRec
          end

          def getUploadIdByRefSeqId( refSeqId )
            # Cache rid information
            uploadId = nil
            begin
                @@dbu = BRL::Genboree::ToolPlugins.connect()
                uploadId = @@dbu.selectUploadIDByRefSeqID( refSeqId )[0][0]
            rescue => @err
                $stderr.puts @err
                $stderr.puts @err.backtrace
            end
            return uploadId
          end
        end

      	def getAllResultExtensions(toolClass)
					allExts = {}
					return allExts if(toolClass.nil?)
					toolClass.functions().each_key { |functionSym|
						allExts.update(toolClass.functions()[functionSym][:resultFileExtensions])
					}
					return allExts
			  end

        # Options:
        #   :binary => The binary representation to be used
        def convert_to_wnw( options, positives, negatives="" )
          str = ""
          # Create all possible 6mers (or Xmers the size of {kmer})
          all_possible = BinaryFeatures.send( "#{options[:binary]}_attributes", options )
          all_possible.sort!
          arr = []
          # Positive cases
          positives.each_line do |line|
              arr.push( line.split("\t")[0] + "\t" + line.strip.split("\t")[1].split("").join(",") + ",true")
          end
          # Negative cases (negative control)
          negatives.each_line do |line|
              arr.push( line.split("\t")[0] + "\t" + line.strip.split("\t")[1].split("").join(",") + ",false")
          end

          str << all_possible.join(",")
          str << ",class\n"
          str << arr.join("\n")
          str
        end

        # Checks to see if a given directory for output exists, if not, create it
        def checkOutputDir( path )
            Dir.recursiveSafeMkdir( path )
            return
        end

        # Create necessary softlinks for displaying extra data on results
        # page.  This includes things such as images, and raw data
        def linkify( toolName, functionName, groupId, refSeqId, expname )
          toolClass = BRL::Genboree::ToolPlugins::Tools.list[toolName.to_sym]
          extensionHash = toolClass.functions[functionName.to_sym][:autoLinkExtensions]
          fileList = Hash.new { |hh,kk| hh[kk] = [] }
          # First, find all files in this experiments group
          baseFile = "#{RESULTS_PATH}/#{groupId}/#{refSeqId}/#{toolName}/#{expname}"
          extensionHash.each_key { |extension|
            fileList[extension] += Dir["#{baseFile}.#{extension}"]
          }
          # Make sure that htdocs/genboree/toolPlugins/links/groupId/ exists
          linkDirBase = "#{TOOL_USER_LINKS}/#{groupId}/#{refSeqId}/#{toolName}"
          Dir.recursiveSafeMkdir( linkDirBase )
          # Lastly, soft link to these files from htdocs/genboree/toolPlugins/links/groupId/
          fileList.each_key { |extension|
            fileList[extension].each { |srcFile|
              fileName = srcFile.split('/').last
              fileName =~ /^(.+)\.#{extension}$/
              baseFile = $1
              destExt = extensionHash[extension]
              File.symlink( srcFile, "#{linkDirBase}/#{baseFile}.#{destExt}" ) unless(File.exists?( "#{linkDirBase}/#{baseFile}.#{destExt}" ))
            }
          }
        end

        # Writes data to scratch space, returning the absolute path to the file
        def write_to_scratch( data, scratch_path=SCRATCH_PATH )
            # Use Time stamp + random int as file name
            fname = "#{scratch_path}/#{Time.now.to_i}_#{rand(1000)}"
            File.open( fname, "w+" ) { |ff|
              ff << data
            }
            return fname
        end

        # Gzip (was: delete) files we are done with
        def cleanup_files( filepaths )
          filepaths = [ filepaths ] if(filepaths.is_a?( String ))
          filepaths.each { |filePath|
            cleanFilePath = ""
            filePath.split(' ').each { |word|
              cleanFilePath += word  + (word[-1,2] == '\\' ? ' ' : '\ ')
            }
            cleanFilePath.chomp!('\ ')
            `gzip #{cleanFilePath}`
          }
          return
        end
    end
end ; end ; end # END : BRL::Genboree::ToolPlugins
