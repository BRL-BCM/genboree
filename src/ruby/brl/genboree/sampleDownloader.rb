#!/usr/bin/env ruby

# ##############################################################################
# LIBRARIES
# - The first 3 are standard for all apps.
# ##############################################################################
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
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
  Sample = Struct.new(:saId, :saName)
  Attribute = Struct.new(:saAttNameId, :saName)
  Value = Struct.new(:saAttValueId, :saValue)

  # ##############################################################################
  # EXECUTION CLASS
  # ##############################################################################
  class SampleDownloader
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
      @doSortCols = optsHash.key?('--noSortColumns') ? false : true
      @doHeaderRow = optsHash.key?('--noHeaderRow') ? false : true
      @dbrcFile = optsHash.key?('--dbrcFile') ? optsHash['--dbrcFile'] : nil
      $stderr.puts "  PARAMS:\n  - database => #{@databaseName}\n  - noSortColumns => #{@doSortCols}\n  - dbrcFile => #{@dbrcFile}\n\n"
      return
    end

    def download()
      # Get a database handle
      @dbh = BRL::Genboree::DBUtil.new(@server, nil, @dbrcFile)
      # Set data database
      setDataDB()
      # Get all the samples, keyed by saId
      @samples = getSamples()
      # Get all the attributes, keyed by saAttNameId
      @attributes = getAttributes()
      # Get all the values, keyed by saAttValueId
      @values = getValues()
      # Create the column array
      @columns = @attributes.values.map { |attribute| attribute.saName }
      @columns.sort! {|aa,bb| aa.downcase <=> bb.downcase } if(@doSortCols)
      if(@doHeaderRow)
        puts "SampleID\t" + @columns.join("\t")
      end
      # Go through samples2attributes in blocks of 10,000 at a time and for
      # each row:
      # . add sample to cache of samples currently being worked on if not there
      # . add the AVP
      # . check if we have all the AVPs for this sample
      #   - if so, print it using appropriate column order
      #   - and then remove it from cache of samples currently being worked on
      # NOTE: a 'group by' would be nice in the SQL, but it is too slow, so we
      #       use this trick of a "currently worked on Samples cache"
      rows = nil
      currSamples = Hash.new {|hh,kk| hh[kk] = {} } # collect samples until we have all their info, then dump
      @dbh.eachBlockOfSamples2Attributes() { |blockOfRows|
        blockOfRows.each { |row|
          # Set Sample ID property if not set for this sample
          rowSampleID, rowAttrID, rowValID, rowState = row
          currSample = currSamples[rowSampleID]
          unless(currSample.key?('~~~SampleID'))
            currSample['~~~SampleID'] = @samples[rowSampleID].saName
          end
          # Set the attribute for this sample
          currSample[@attributes[rowAttrID].saName] = @values[rowValID].saValue
          # If we have all the attributes for this sample, dump it and delete from
          # currSamples list
          if(currSample.size == (@attributes.size + 1))
            # Print Sample ID first, always
            print "#{currSample['~~~SampleID']}\t"
            # Print columns in order
            @columns.each_index { |ii|
              print "#{currSample[@columns[ii]]}"
              print "\t" unless(ii == (@columns.size - 1))
            }
            puts ""
            # Remove sample from currSamples collection
            currSamples.delete(rowSampleID)
          end
        }
      }
      return BRL::Genboree::OK
    end

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

    def getSamples()
      samples = {}
      rows = @dbh.selectAllSamples()
      if(rows.nil?)
        raise "ERROR: retrieving samples failed for database '#{@databaseName}'. Aborting."
      elsif(rows.empty?)
        $stderr.puts "WARNING: no samples stored in database '#{@databaseName}'."
      end
      rows.each { |row|
        sample = Sample.new(row['saId'], row['saName'].strip)
        samples[sample.saId] = sample
      }
      return samples
    end

    def getAttributes()
      attributes = {}
      rows = @dbh.selectAllSamplesAttNames()
      if(rows.nil?)
        raise "ERROR: retrieving sample attributes failed for database '#{@databaseName}'. Aborting."
      elsif(rows.empty?)
        $stderr.puts "WARNING: no sample attributes stored in database '#{@databaseName}'."
      end
      rows.each { |row|
        attribute = Attribute.new(row['saAttNameId'], row['saName'].strip)
        attributes[attribute.saAttNameId] = attribute
      }
      return attributes
    end

    def getValues()
      values = {}
      rows = @dbh.selectAllSamplesAttValues()
      if(rows.nil?)
        raise "ERROR: retrieving sample attributes failed for database '#{@databaseName}'. Aborting."
      elsif(rows.empty?)
        $stderr.puts "WARNING: no sample attributes stored in database '#{@databaseName}'."
      end
      rows.each { |row|
        value = Value.new(row['saAttValueId'], row['saValue'].strip)
        values[value.saAttValueId] = value
      }
      return values
    end

    # ---------------------------------------------------------------
    # CLASS METHODS
    # ---------------------------------------------------------------
    # Process command-line args using POSIX standard
    def SampleDownloader.processArguments(outs)
      # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--serverId', '-s', GetoptLong::REQUIRED_ARGUMENT],
                    ['--database', '-d', GetoptLong::REQUIRED_ARGUMENT],
                    ['--noSortColumns', '-S', GetoptLong::NO_ARGUMENT],
                    ['--noHeaderRow', '-H', GetoptLong::NO_ARGUMENT],
                    ['--dbrcFile', '-r', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--verbose', '-V', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--help', '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      optsHash = progOpts.to_hash
      outs[:verbose] = true if(optsHash and optsHash.key?('--verbose'))
      outs[:optsHash] = optsHash
      SampleDownloader.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      SampleDownloader.usage() if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end

    # Display usage info and quit.
    def SampleDownloader.usage(msg='')
      unless(msg.empty?)
        puts "\n#{msg}\n"
      end
      puts "

  PROGRAM DESCRIPTION:

    Dumps the samples in the given database to stdout, optionally sorting the
    columns alphabetically.

    COMMAND LINE ARGUMENTS:
      --serverId            | -s  => Server ID string. This matches a key in the
                                     dbrc file. Typical values are:
                                     . genboreeAlanine
                                     . genboreeTyrosine
      --database            | -d  => Database name or refseq ID.
      --noSortColumns       | -S  => [Optional Flag] If present, DO NOT sort the
                                     sort the columns alphabetically (except for
                                     sample name of course).
      --noHeaderRow         | -H  => [Optional Flag] If present, DO NOT print
                                     the header row at the top.
      --dbrcFile            | -r  => [Optional Flag] .dbrc file to use for DB
                                     connection parameters. Defaults to the
                                     standard: first for DBRC_FILE env variable,
                                     then ~/.dbrc.
      --verbose             | -V  -> [Optional] Prints more error info (trace)
                                     and such when it fails. Mainly for Genboree
      --help                | -h  => [Optional flag]. Print help info and exit.

    USAGE:
    sampleDownloader.rb -s genboreeAlanine \
     -d genboree_r_dd7c888e09ed9ee43924d6e19ecb508a3

  ";
      exit(BRL::Genboree::USAGE_ERR);
    end # def SampleDownloader.usage(msg='')
  end # class SampleDownloader
end ; end # namespace

# ##############################################################################
# MAIN
# ##############################################################################
begin
  # Get arguments hash
  outs = { :optsHash => nil, :verbose => false }
  optsHash = BRL::Genboree::SampleDownloader.processArguments(outs)
  $stderr.puts "#{Time.now()} SAMPLE DOWNLOADER - STARTING"
  # Instantiate method
  downloader =  BRL::Genboree::SampleDownloader.new(optsHash)
  $stderr.puts "#{Time.now()} SAMPLE DOWNLOADER - INITIALIZED"
  # Execute tool
  exitVal = downloader.download()
rescue Exception => err # Standard capture-log-report handling:
  errTitle =  "#{Time.now()} SAMPLE DOWNLOADER - FATAL ERROR: The downloader exited without downloading all the data, due to a fatal error.\n"
  msgTitle =  "FATAL ERROR: The downloader exited without downloading all the data, due to a fatal error.\n"
  msgTitle += "Please contact the Genboree admin. This error has been dated and logged.\n" if(outs[:verbose])
  errstr   =  "   The error message was: '#{err.message}'.\n"
  errstr   += "   The complete back-trace is:\n\"\n" + err.backtrace.join("\n") + "\n\""
  puts msgTitle unless(outs[:optsHash].key?('--help'))
  $stderr.puts(errTitle + errstr) if(outs[:verbose])
  exitVal = BRL::Genboree::FATAL
end
$stderr.puts "#{Time.now()} SAMPLE DOWNLOADER - DONE" unless(exitVal != 0)
exit(exitVal)
