#!/usr/bin/env ruby

# ##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
# ##############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
#require 'dbUtil'

require 'brl/fileFormats/delimitedTable'

include BRL::Genboree

# ##############################################################################
# NAMESPACE
# - a.k.a. 'module'
# - This is standard and matches the directory location + "Tool"
# ##############################################################################
module BRL ; module Genboree

  # ##############################################################################
  # HELPER CLASSES
  # ##############################################################################

#  AssayType = Struct.new(:typeId, :typeName, :recordSize)
  FieldDef = Struct.new(:fieldOrder, :dataType, :size)


  # ##############################################################################
  # EXECUTION CLASS
  # ##############################################################################
  class UploadAssayData
    # ---------------------------------------------------------------
    # Accessors (getters/setters ; instance variables
    # ---------------------------------------------------------------

    # ---------------------------------------------------------------
    # METHODS
    # ---------------------------------------------------------------
    def initialize(optsHash)
      self.config(optsHash) unless(optsHash.nil?)
    end

    def config(optsHash)
      @server = optsHash['--serverId'].strip
      @databaseName = optsHash['--database'].strip
      @filename = optsHash['--filename'].strip
      @outfilePath = optsHash['--outfilepath'].strip
      @dbrcFile = optsHash.key?('--dbrcFile') ? optsHash['--dbrcFile'] : nil
      $stderr.puts "  PARAMS:\n  - database => #{@databaseName}\n  - filename => #{@filename}\n  - dbrcFile => #{@dbrcFile}\n\n"
      return
    end


    def insertAssayData()
      # Get a database handle
      @dbh = BRL::Genboree::DBUtil.new(@server, nil, @dbrcFile)
      setDataDB()

      # get file handle
      dataFile = File.new(@filename)

      # read in header info
      header = true
      while ((header == true) && !(dataFile.eof?))
        line = dataFile.gets.chomp.split(/\t/)
        if    (line[0]=~/ASSAY NAME/)
          assayName = line[1];
        elsif (line[0]=~/ASSAY RUN NAME/)
          runName = line[1]
        elsif (line[0]=~/ASSAY RUN ATTRIBUTES/)
          runAttr = line[1]
        elsif (line[0]=~/DATA/)
          header = false
        end
      end

      # validate header
      if dataFile.eof?
        raise "Invalid file format: No DATA section in file"
      elsif (assayName.nil?)
        raise "Invalid file format: Assay Name not defined in header"
      elsif (runName.nil?)
        raise "Invalid file format: Assay Run Name not defined in header"
      end

      #get assayId
      assayId = @dbh.selectAssayByName(assayName)[0][0]
      if (assayId.nil?)
        raise "ERROR: Assay Name does not exist!"
      end

      # get run ID
      # does this run ID exist?
      runId = @dbh.selectAssayRunByNameAndID(assayId, runName)[0]
#      puts "runID: #{runId}"
      newRun = false
      #if nope, get the max val
      if (runId.nil?)
        newRun = true
        runId = @dbh.getMaxRunId()[0][0]
        #if no max val (empty table, make it = 1)
        if !(runId.nil?)
          runId = runId.to_i + 1
        else
          runId = 1
        end
      end
#      puts "runID: #{runId}"


      # get fields for validation
      fields2 = getFieldInfo(assayId)
      sampleIdList = Array.new
      outfileNames = Array.new
      fileLocHash = Hash.new
      sampleIdHash = Hash.new

      @counter = 0;
      # for each line in the data file: validate, then insert.
      dataFile.each_line {|line|
        line.chomp!
        if (line != "")
          dataLine = line.split(/\t/)
          numFields = fields2.length

          #validate length - must be multiple of fields2.length
          #(first field is sample name - not included)
          if !((dataLine.length-1).remainder(numFields) == 0)
            raise "Invalid file format: Line #{@counter+1} does not have the appropriate number
                   of fields.  It should have #{numFields} fields (or a multiple thereof)"
          end

          # have we cached this sampleId yet?
          # if not, get it
          if (sampleIdHash.key?("#{dataLine[0]}"))
            sampleId = sampleIdHash["#{dataLine[0]}"]
          else
            sampleId = @dbh.selectSampleByName(dataLine[0])[0][0]
            if (sampleId.nil?)
              raise "ERROR: Sample name #{dataLine[0]} does not exist"
            end
          end
          sampleIdList.push(sampleId)

          # have we cached this file location yet?
          # if not, get it
          if (fileLocHash.key?("#{assayId}#{runId}#{sampleId}"))
            fileLoc = fileLocHash["#{assayId}#{runId}#{sampleId}"]
          else
            fileLoc = @dbh.selectFileLocByIDs(assayId, runId, sampleId)[0]
            fileLocHash["#{assayId}#{runId}#{sampleId}"] = fileLoc
          end

          #if so, we append to that file
          if !(fileLoc.nil?)
            outfileName = fileLoc[0]
            outfile = File.new(outfileName, "a")
          #if not, we open a new file
          else
            outfileName = "#{@outfilePath}/#{assayName}-#{runId }-#{dataLine[0]}"
            outfile = File.new(outfileName,"w")
          end

#          puts "oufileName: #{outfileName}"
          outfileNames.push(outfileName)


          # now, lets do the parsing/validation of the incoming data
          # first break the line into the appropriate number of chunks
          # (since we can append lots of sample data together on one line)
          numChunks = (dataLine.length-1)/numFields
          loopCounter = 0;
          # go through it chunk by chunk
          $stderr.puts "Handling #{dataLine[0]}"
          while (loopCounter < numChunks)
            output = []
            outputstring = ""

            #get the appropriate subset of data
#            data = dataLine.slice(((loopCounter*numChunks)+1),numFields)
            data = dataLine.slice(((loopCounter*numFields)+1),numFields)


# debugging code
#            if (dataLine[0] == "TCGA-06-0195-01B-01W-0250-10")
#            $stderr.puts "slice from #{((loopCounter*numFields)+1)}, getting  #{numFields} cells"
#            $stderr.puts data.inspect
#            $stderr.puts "loopCounter = #{loopCounter}"
#            $stderr.puts "numChunks = #{numChunks}"
#            $stderr.puts "numFields = #{numFields}"
#            $stderr.puts "#{dataLine.length}"
#            end
# end debugging code


            # now check all data fields against schema in DB
            0.upto(data.length-1) do |i|

              # big case statement for validation, output creation
              ########################################
              case fields2[i].dataType
                # #  type  (if null)
                #
                # 0 = text:size ("")
                # 1 = float (Float::MAX)
                # 2 = int (Integer::MAX32)
                # 3 = int (Integer::MAX64)
                # 4 = bool (\a)
                # 5 = date ("")


              #validate text####
              when 0 then
                if (data[i].nil?)
                  data[i] = ""
                elsif data[i].length > fields2[i].size
                  raise "ERROR: line #{@counter+1}, field #{i} has errors: text length is longer than defined data size"
                end
                output.push(data[i])
                outputstring = outputstring << "A#{fields2[i].size}"

              #validate float####
              when 1 then
                begin
                  if (data[i]=="")
                    data[i] = Float::MAX
                  elsif (data[i]=~/^\s*(?:\+|\-)?\d*(?:\d+\.|\.\d+)?(?:e(?:\+|\-)?\d+)?\s*$/i)
                    data[i] = data[i].to_f
                  elsif (data[i].strip() =~ /^e\d/)
                    data[i] = "1" + data[i]
                  else
                    raise "ERROR: line #{@counter+1}, field #{i} has errors: '#{data[i]}' is not a valid floating point number"
                  end
                rescue Exception => err
                  raise "ERROR: line #{@counter+1}, field #{i} has errors: '#{data[i]}' is not a valid floating point number"
                end
                output.push(data[i])
                outputstring = outputstring << "d"

              #validate int32####
              when 2 then
                #puts "Line=#{data[1]}  DATA='#{data[i]}'"
                begin
                if ((data[i]=="") || (data[i].nil?))
                  data[i] = Integer::MAX32
                elsif (data[i]=~/^\s*(?:\+|\-)?\d+\s*$/)
                  data[i] = data[i].to_i
                else
                  raise "ERROR: line #{@counter+1}, field #{i} has errors:  '#{data[i]}' is not a valid integer"
                end
                rescue Exception => err
                  raise "ERROR: line #{@counter+1}, field #{i} has errors:  '#{data[i]}' is not a valid integer"
                end
                output.push(data[i])
                outputstring = outputstring << "i"

              #validate int64####
              when 3 then
                #puts "Line=#{data[1]}  DATA='#{data[i]}'"
                begin
                  if ((data[i]=="") || (data[i].nil?))
                    data[i] = Integer::MAX64
                  elsif (data[i]=~/^\s*(?:\+|\-)?\d+\s*$/)
                    data[i] = data[i].to_i
                  else
                    raise "ERROR: line #{@counter+1}, field #{i} has errors:  '#{data[i]}' is not a valid integer"
                  end
                rescue Exception => err
                  raise "ERROR: line #{@counter+1}, field #{i} has errors:  '#{data[i]}' is not a valid integer"
                end
                output.push(data[i])
                outputstring = outputstring << "N"

              #validate bool####
              when 4 then
                #puts "Line=#{data[1]}  DATA=#{data[i]}"
                if (data[i] == "")
                  data[i] = "\a";
                else
                  case data[i].downcase
                  when "true" then data[i] = 1
                  when "false" then data[i] = 0
                  when "t" then data[i] = 1
                  when "f" then data[i] = 0
                  when "0" then data[i] = 0
                  when "1" then data[i] = 1
                  else raise "ERROR: line #{@counter+1}, field #{i} has errors: '#{data[i]}' is not a valid boolean value.  Type 'boolean' must be in one of the following formats: 0/1, T/F, true/false"
                  end
                end
                output.push(data[i].to_s)
                outputstring = outputstring << "A1"

              #validate date####
              when 5 then
                #puts "Line=#{data[1]}  DATA=#{data[i]}"
                begin
                  if (data[i]=="")
                    data[i] = ""
                  else
                    temp = Date.parse(data[i],true)
                    data[i] = temp
                  end
                rescue Exception => err
                  raise "ERROR: line #{@counter+1}, field #{i} has errors:  '#{data[i]}' is not a valid date"
                end
              output.push(data[i].to_s)
                outputstring = outputstring << "A10"

                #else unknown type - wtf??
              else raise "ERROR: #{fields2[i].dataType} is not a valid data type (how did that get in the DB?)"
              end #case statement
              ########################################3

            end #0.upto
            loopCounter += 1
          end #while loop

          #write out this sample's file

          #puts output
          #puts outputstring


          outstring = output.pack(outputstring)
          outfile.print(outstring)
          outfile.close

          @counter += fields2.length
        end #if line != ""
      }# end eachline

      puts "end of loop:"
      puts "#{`date`}"
      # add info to appropriate tables of DB
      if (newRun == true)
        @dbh.insertAssayRunEntry(assayId, runName, Time.now)
      end

      # send it one big array of data
      # chunking of inserts is handled on other side
      values = Array.new
      counterVal = 0
#      puts "len: #{sampleIdList.length}"
#      puts "list: #{sampleIdList}"
      0.upto(sampleIdList.length-1){ |k|
        values[counterVal] = nil
        values[counterVal+1] = sampleIdList[k]
        values[counterVal+2] = assayId
        values[counterVal+3] = runId
        values[counterVal+4] = outfileNames[k]
        values[counterVal+5] = Time.now

        counterVal += 6
      }
      @dbh.insertMultiAssayDataEntries(values,(sampleIdList.length))


      #! Add A/V pairs
      if !(runAttr.nil?)
        #add them to appropriate database (doesn't exist yet!!)
      end


      return BRL::Genboree::OK
    end

############################################################
# other methods
############################################################
    def setDataDB()
      if(@databaseName =~ /^\d+$/) # then refSeq ID given
        rows = @dbh.selectDBNameByRefSeqID(@databaseName)
        if(rows.nil? or rows.empty?)
          raise "ERROR: no database found for refSeq ID '#{@databaseName}'. Aborting."
        end
        @databaseName = rows.first['databaseName']
      end
      @dbh.setNewDataDb(@databaseName)
    end


    #new
    def getRunId(assayId, runName)
      rows = @dbh.selectAssayRunByNameAndID(assayId, runName)
      if(rows.nil?) #if name/assay does not exist
        return nil
      end
      runID = rows[0][0]
      return runID
    end

    def getFileLocation(assayId,runId)
      rows = @dbh.selectFileLocByIDs(assayID,runID)
      if (rows.nil?)
        return 0
      else
        return rows[0][0]
      end
    end


    def getFieldInfo(assayId)
      fields = {}
      rows = @dbh.selectAssayRecordFieldsByAssayId(assayId)
      if(rows.nil?)
        raise "ERROR: retrieving fields failed for database '#{@databaseName}'. Aborting."
      elsif(rows.empty?)
        $stderr.puts "WARNING: no fields for assayId '#{@assayId}' stored in database '#{@databaseName}'."
      end
      rows.each { |row|
        field = FieldDef.new(row[DBUtil::A3_FIELD_NUMBER], row[DBUtil::A3_DATA_TYPE], row[DBUtil::A3_FIELD_SIZE])
        fields[field.fieldOrder-1] = field
      }
      return fields
    end


    # ---------------------------------------------------------------
    # CLASS METHODS
    # ---------------------------------------------------------------
    # Process command-line args using POSIX standard
    def UploadAssayData.processArguments(outs)
      # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--filename', '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outfilepath', '-o', GetoptLong::REQUIRED_ARGUMENT],
                    ['--serverId', '-s', GetoptLong::REQUIRED_ARGUMENT],
                    ['--database', '-d', GetoptLong::REQUIRED_ARGUMENT],
                    ['--dbrcFile', '-r', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--verbose', '-V', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      outs[:verbose] = true if(optsHash and optsHash.key?('--verbose'))
      outs[:optsHash] = optsHash
      UploadAssayData.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      UploadAssayData.usage() if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

    # Display usage info and quit.
    def UploadAssayData.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:
    Reads sample data from the uploaded file, verifies it, updates the assayData
    database and prints the appropriate output files.

    COMMAND LINE ARGUMENTS:
      --filename            | -f  => path to file containing data
      --outfilename         | -o  => output file path
                                     (will be overridden if assay/run exist)
      --serverId            | -s  => Server ID string. This matches a key in the
                                     dbrc file. Typical values are:
                                     . genboreeAlanine
                                     . genboreeTyrosine
      --database            | -d  => Database name or refseq ID.
      --dbrcFile            | -r  => [Optional Flag] .dbrc file to use for DB
                                     connection parameters. Defaults to the
                                     standard: first for DBRC_FILE env variable,
                                     then ~/.dbrc.
      --verbose             | -V  -> [Optional] Prints more error info (trace)
                                     and such when it fails. Mainly for Genboree
      --help                | -h  => [Optional flag]. Print help info and exit.

    USAGE:
    UploadAssayData.rb -f filename.txt -o /path/to/outfileprefix -t 5 -s genboreeAlanine \
     -d genboree_r_dd7c888e09ed9ee43924d6e19ecb508a3

  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def AssayDownloader.usage(msg='')
  end # class AssayDownloader
end ; end # namespace

# ##############################################################################
# MAIN
# ##############################################################################
begin
  # Get arguments hash
  outs = { :optsHash => nil, :verbose => false }
  optsHash = BRL::Genboree::UploadAssayData.processArguments(outs)
  $stderr.puts "#{Time.now()} ASSAY UPLOADER - STARTING"

  # Instantiate method
  uploader =  BRL::Genboree::UploadAssayData.new(optsHash)
  $stderr.puts "#{Time.now()} Upload  - INITIALIZED"

  # Execute tool
    exitVal = uploader.insertAssayData()


rescue Exception => err # Standard capture-log-report handling:
  errTitle =  "#{Time.now()} ASSAY UPLOADER - FATAL ERROR: The uploader exited without downloading all the data, due to a fatal error.\n"
  msgTitle =  "FATAL ERROR: The uploader exited without downloading all the data, due to a fatal error.\n"
  msgTitle += "Please contact the Genboree admin. This error has been dated and logged.\n" if(outs[:verbose])
  errstr   =  "   The error message was: '#{err.message}'.\n"
  errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
  puts msgTitle unless(outs[:optsHash].key?('--help'))
  $stderr.puts(errTitle + errstr) if(outs[:verbose])
  exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} ASSAY UPLOADER - DONE" unless(exitVal != 0)
exit(exitVal)
