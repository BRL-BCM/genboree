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

#  ExpType = Struct.new(:typeId, :typeName, :recordSize)
#  FieldDef = Struct.new(:fieldId, :typeId, :fieldName, :fieldOrder, :dataType, :size, :offset)


  # ##############################################################################
  # EXECUTION CLASS
  # ##############################################################################
  class UploadExpSchema
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
      @doHeaderRow = optsHash.key?('--noHeaderRow') ? false : true
      @dbrcFile = optsHash.key?('--dbrcFile') ? optsHash['--dbrcFile'] : nil
      $stderr.puts "  PARAMS:\n  - database => #{@databaseName}\n  - filename => #{@filename}\n  - dbrcFile => #{@dbrcFile}\n\n"
      return
    end

    def insertExpDataTypes()
      # Get a database handle
      @dbh = BRL::Genboree::DBUtil.new(@server, nil, @dbrcFile)
      # Set data database
      setDataDB()

      #get file handle and read in file info
      dataFile = File.new(@filename)

      recNum = Array.new
      annoVal = Array.new
      annoAttribute = ""
      annoTrack = ""
      counter = 0;

      while (!(dataFile.eof?))
        line = dataFile.gets.chomp.split(/\t/)
        if    (line[0]=~/ASSAY NAME/)
          assayName = line[1];
          $stderr.puts "ASSAY NAME: #{assayName}"
        elsif (line[0]=~/RECORD FIELDS/)
          recordFields = line
        elsif (line[0]=~/FIELD TYPES/)
          fieldTypes = line
        elsif (line[0]=~/ANNO LINK ATTRIBUTE/)
          annoLinkAtt = line[1]
        elsif (line[0]=~/ANNO LINK TRACK/)
          annoLinkTrack = line[1]
        elsif (line[0]=~/\d/)
          recNum[counter]=line[0]
          annoVal[counter]=line[1]
          counter += 1;
        end
      end
      dataFile.close()

      #validation
      if (assayName.nil? || recordFields.nil? || fieldTypes.nil?)
        raise "ERROR: Required fields missing.  'Assay Name', 'Record Fields', and 'Field Types' must be specified"
      elsif (@dbh.selectAssayByName(assayName).to_s != "")
        raise "ERROR: Assay name already exists"
      elsif (recordFields.length != fieldTypes.length)
        raise "ERROR: The number of Record Fields differs from the number of Field Types specified.  You must specify a size and type for each record field"
      end

      0.upto(recordFields.length-1){ |k|
        if (recordFields[k].nil? || recordFields[k]=="")
          raise "ERROR: blank RECORD FIELDS value found."
        end
        if (fieldTypes[k].nil? || fieldTypes[k]=="")
          raise "ERROR: blank FIELD TYPES value found."
        end
      }


      #get all our data types and sizes prepared
      outSizes = Array.new
      1.upto(fieldTypes.length-1){ |i|
        #special case for text - split out size
        if (fieldTypes[i]=~/text/)
          record = fieldTypes[i].split(/:/)
          begin
            outSizes[i] = record[1].to_i
          rescue Exception => err
            raise "ERROR: in type '#{record[0]}', '#{record[1]}' is not a valid integer size"
          end
          fieldTypes[i] = convertDataType(record[0])

        else #hash, insert default size
          fieldTypes[i] = convertDataType(fieldTypes[i])
          outSizes[i] = getDataSize(fieldTypes[i])
        end
      }


      # add up record sizes
      recordSize = 0
      1.upto(outSizes.length-1) do |i|
        recordSize += outSizes[i].to_i
      end

######### DO INSERTION ###

    ###insert into Assay table
      #puts "#{annoAttribute}--#{annoTrack}"
      assayId = @dbh.insertAssayEntry(assayName, recordSize, annoLinkAtt, annoLinkTrack)


    ### insert into AssayRecordFields table

      aSize = (recordFields.length-1)*7
      values = Array.new(aSize)
      counter = 0
      fieldNum = 1
      offset = 0

      1.upto(recordFields.length-1){ |i|
        #add to values array
        values[counter] = nil;
        values[counter+1] = assayId
        values[counter+2] = recordFields[i]
        values[counter+3] = fieldNum
        values[counter+4] = fieldTypes[i]
        values[counter+5] = outSizes[i]
        values[counter+6] = offset

        #increment
        offset = offset + outSizes[i].to_i
        counter += 7
        fieldNum += 1
      }
      #puts "values"
      #values.each{ |val|
      #  puts "\t#{val}"
      #}
      #puts "length: #{recordFields.length-1}"

      @dbh.insertMultiRecordEntries(values,(recordFields.length-1))


    ###insert into Assay2GenomeAnnotation table, if applicable
      if (!(recNum[0].nil?))
        0.upto(recNum.length-1) do |i|
          @dbh.insertIntoAssay2GenomeAnnotation(assayId, recNum[i], annoVal[i])
        end
      end

      return BRL::Genboree::OK
    end

#######################################
#  other functions
#######################################
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


    def convertDataType(dataType)
      validTypes = {
        'text'         => 0,
        'float'        => 1,
        'integer_32'   => 2,
        'integer_64'   => 3,
        'boolean'      => 4,
        'date'         => 5
      }

      return validTypes[dataType] unless(validTypes[dataType].nil?)
      raise "ERROR: non valid data type found in TYPE line.\nValid types are 'text:size', 'float', 'integer_32', 'integer_64', 'boolean', and 'date'"
    end

    def getDataSize(dataType)
      sizes = {
        1 => 8,        #'float'
        2 => 4,        #'integer_32'
        3 => 8,        #'integer_64'
        4 => 1,       #'boolean'
        5 => 10       #'date'
      }

      return sizes[dataType] unless(sizes[dataType].nil?)
      raise "ERROR: non valid data type found in TYPE line.\nValid types are 'text:size', 'float', 'integer_32', 'integer_64', 'boolean', and 'date'"
    end


    # ---------------------------------------------------------------
    # CLASS METHODS
    # ---------------------------------------------------------------
    # Process command-line args using POSIX standard
    def UploadExpSchema.processArguments(outs)
      # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--filename', '-f', GetoptLong::REQUIRED_ARGUMENT],
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
      UploadExpSchema.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      UploadExpSchema.usage() if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

    # Display usage info and quit.
    def UploadExpSchema.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:

    Dumps the samples in the given database to stdout, optionally sorting the
    columns alphabetically.

    COMMAND LINE ARGUMENTS:
      --filename            | -f  => path to file containing datatype schema
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
    UploadExpSchema.rb -f filename.txt -s genboreeAlanine \
     -d genboree_r_dd7c888e09ed9ee43924d6e19ecb508a3

  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def ExpDownloader.usage(msg='')
  end # class ExpDownloader
end ; end # namespace

# ##############################################################################
# MAIN
# ##############################################################################
begin
  # Get arguments hash
  outs = { :optsHash => nil, :verbose => false }
  optsHash = BRL::Genboree::UploadExpSchema.processArguments(outs)
  $stderr.puts "#{Time.now()} EXP DOWNLOADER - STARTING"

  # Instantiate method
  uploader =  BRL::Genboree::UploadExpSchema.new(optsHash)
  $stderr.puts "#{Time.now()} Upload  - INITIALIZED"


  # Execute tool
    exitVal = uploader.insertExpDataTypes()




rescue Exception => err # Standard capture-log-report handling:
  errTitle =  "#{Time.now()} EXP DOWNLOADER - FATAL ERROR: The downloader exited without downloading all the data, due to a fatal error.\n"
  msgTitle =  "FATAL ERROR: The downloader exited without downloading all the data, due to a fatal error.\n"
  msgTitle += "Please contact the Genboree admin. This error has been dated and logged.\n" if(outs[:verbose])
  errstr   =  "   The error message was: '#{err.message}'.\n"
  errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
  puts msgTitle unless(outs[:optsHash].key?('--help'))
  $stderr.puts(errTitle + errstr) if(outs[:verbose])
  exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} EXP DOWNLOADER - DONE" unless(exitVal != 0)
exit(exitVal)
