#!/usr/bin/env ruby
require 'pathname'
require 'md5'
require 'stringio'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/script/scriptDriver'
require 'brl/genboree/dbUtil'
require 'brl/sql/binning'
require 'brl/util/expander'
require 'brl/fileFormats/LFFValidator'

module BRL ; module Script
  class LffUploader < ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "1.0"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--inputFile"        =>     [ :REQUIRED_ARGUMENT, "-i", "input lff file." ],
      "--refSeqId"         =>     [ :REQUIRED_ARGUMENT, "-r", "refSeqId of the database."],
      "--userId"           =>     [ :REQUIRED_ARGUMENT, "-u", "userId."],
      "--skipVal"          =>     [ :OPTIONAL_ARGUMENT, "-s", "skip validation."],
      "--dbrcKey"          =>     [ :OPTIONAL_ARGUMENT, "-K", "dbrc key."],
      "--skipSorting"      =>     [ :OPTIONAL_ARGUMENT, "-S", "Skip Sorting of lff file by track name (for files that are already sorted)."],
      "--help"             =>     [ :NO_ARGUMENT, "-h", "help"]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "A program to upload lff annotations into Genboree. ",
      :authors      => [ "Sameer Paithankar (paithank@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} --inputFile=file.lff -u 1400 -r 9999"
      ]
    }

    READ_BUFFER_SIZE = WRITE_BUFFER_SIZE = 4 * 1024 * 1024
    
    KEY_VALUE_LIMIT = 2_000_000
    ArrayStruct = Struct.new(:currIdx, :array)
    HashStruct = Struct.new(:currIdx, :hash)
    FDATA_FIELDS = ['fid', 'rid', 'fstart', 'fstop', 'fbin', 'fscore', 'fstrand', 'fphase', 'ftarget_start', 'ftarget_stop', 'gname', 'displayCode', 'displayColor', 'groupContextCode']
    FIDTEXT_FIELDS = ['fid', 'text']
    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    def run()
      retval = EXIT_OK
      validateAndProcessArgs()
      begin
        extract()
        initDbuObj()
        setUpEpHash()
        validateLff() unless(@skipVal)
        sortLff() unless(@skipSorting)
        upload()
        @dbu.clear()
        @dbu = nil
        `rm -f ./sql.txt`
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "All Done!")
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "ERROR:\n", "#{err}\n\nBacktrace:#{err.backtrace.join("\n")}")
        retval = 20
      end
      # Must return a suitable exit code number
      return retval
    end
    
    def extract()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Extracting...")
      exp = BRL::Util::Expander.new(@inputFile)
      exp.extract()
      @inputFile = exp.uncompressedFileName
    end

    # Pre-allocate arrays for storing records for various tables
    # [+batchSize+] No of records to insert at a time
    # [+returns+] nil
    def initArrs(batchSize)
      @fdata2Arr = []
      @fdata2AvpArr = []
      @fdata2SeqArr = []
      @fdata2CommentsArr = []
      batchSize.times { |ii|
        @fdata2Arr[ii] = Array.new(14)
        @fdata2AvpArr[ii] = {}
        @fdata2SeqArr[ii] = nil
        @fdata2CommentsArr[ii] = nil
      }
    end
    
    def resetArrs()
      @currIdx.times { |ii|
        14.times { |jj|
          @fdata2Arr[ii][jj] = nil  
        }
        @fdata2AvpArr[ii].clear()
        @fdata2SeqArr[ii] = nil
        @fdata2CommentsArr[ii] = nil
      }
      @currIdx = 0
      @avpEmpty = true
      @seqEmpty = true
      @commEmpty = true
      @keyValuePairs = 0
      GC.start()
    end
    
    def addFData2Rec(rid, fstart, fstop, fbin, ftypeId, fscore, fstrand, fphase, ftargetStart, ftargetStop, gname, grpContextCode)
      @fdata2Arr[@currIdx][0] = rid
      @fdata2Arr[@currIdx][1] = fstart
      @fdata2Arr[@currIdx][2] = fstop
      @fdata2Arr[@currIdx][3] = fbin
      @fdata2Arr[@currIdx][4] = ftypeId
      @fdata2Arr[@currIdx][5] = fscore
      @fdata2Arr[@currIdx][6] = fstrand
      @fdata2Arr[@currIdx][7] = ( fphase == '.' ? '0' : fphase )
      @fdata2Arr[@currIdx][8] = ftargetStart
      @fdata2Arr[@currIdx][9] = ftargetStop
      @fdata2Arr[@currIdx][10] = gname
      @fdata2Arr[@currIdx][11] = '\N'
      @fdata2Arr[@currIdx][12] = '\N'
      @fdata2Arr[@currIdx][13] = grpContextCode
    end


  
    # [+color+] color value in decimal (r, g, b)
    # [+returns+] hex color value
    def generateHexColor(color)
      return "##{color.split(/,/).map { |xx| ("%.2X" % xx.to_i) }.join('')}"
    end
    
    def upload()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Starting upload...")
      reader = File.open(@inputFile)
      orphan = nil
      trkName = nil
      prevTrkName = nil
      chrom = nil
      fstart = nil
      ftypeId = nil
      fstop = nil
      fbin = nil
      fmethod = nil
      fsource = nil
      classHash = {}
      attNames = {}
      attValues = {}
      tmpAvpHash = {}
      ftype2gclassHash = Hash.new { |hh,kk| hh[kk] = {} }
      @ftype2AttNameHash = {}
      gclassHash = {}
      @prevAttNamesSize = nil
      @prevAttValuesSize = nil
      ftypeCountHash = {}
      batchSize = @genbConf.lffUploaderBatchSize.to_i
      initArrs(batchSize)
      @setFieldsFdata = {'ftypeid' => nil}
      @setFieldsFidText = {'ftypeid' => nil, 'textType' => nil}
      @currIdx = 0
      @avpEmpty = true
      @seqEmpty = true
      @commEmpty = true
      @keyValuePairs = 0
      prevGrpContextCode = 'L'
      nextLine = nil
      line = nil
      grpContextCode = nil
      begin
        reader.each_line { |initLine|
          initLine.strip!
          next if(initLine.empty? or initLine =~ /^#/)
          line = initLine
          break
        }
        loop {
          fields = line.split(/\t/)
          gclass = fields[0]
          fmethod = fields[2]
          fsource = fields[3]
          trkName = "#{fmethod}:#{fsource}"
          chrom = fields[4]
          chromLength = @epHash[chrom][0]
          fstart = fields[5].to_i
          fstart = 1 if(fstart < 1)
          fstop = fields[6].to_i
          fstop = chromLength if(fstop > chromLength)
          if(fstart > fstop)
            tmpStart = fstart
            fstart = fstop
            fstop = tmpStart
          end
          ftargetStart = fields[10]
          ftargetStart = '\N' if(!ftargetStart.nil? and ftargetStart == '.')
          ftargetStop = fields[11]
          ftargetStop = '\N' if(!ftargetStop.nil? and ftargetStop == '.')
          avps = fields[12]
          avps = nil if(!avps.nil? and avps == '.')
          seq = fields[13]
          seq = nil if(!seq.nil? and seq == '.')
          comments = fields[14]
          if(prevTrkName.nil?)
            prevTrkName = trkName.dup() 
            ftypeId = getFtypeId(trkName)
            @ftype2AttNameHash[ftypeId] = {}
          end
          binner = BRL::SQL::Binning.new()
          fbin = binner.bin(BRL::SQL::MIN_BIN, fstart, fstop)
          ftype2gclassHash[ftypeId][gclass] = nil
          gclassHash[gclass] = nil
          # To set the groupContextCode, we need to look up the next line
          if(!reader.eof?)
            gotValidLine = false
            while(!gotValidLine)
              nextLine = reader.readline()
              nextLine.strip!
              gotValidLine = true if(!nextLine.empty? and nextLine !~ /^#/)
              break if(reader.eof?)
            end
            unless(gotValidLine)
              nextLine = nil
              if(prevGrpContextCode == 'U' or prevGrpContextCode == 'L')
                grpContextCode = 'U'
              else
                grpContextCode = 'L'
              end
            else
              tmpFields = nextLine.split(/\t/)
              if(tmpFields[1] == fields[1] and chrom == tmpFields[4]) # Next line is of the same group as the current line
                if(fstart == tmpFields[5].to_i and fstop == tmpFields[6].to_i) # Next record is a repeat of the current record
                  grpContextCode = 'U'
                  prevGrpContextCode = 'U'
                else
                  if(prevGrpContextCode == 'L' or prevGrpContextCode == 'U')
                    grpContextCode = 'F'
                    prevGrpContextCode = 'F'
                  else
                    grpContextCode = "M"
                    prevGrpContextCode = "M"
                  end
                end
              else # Next group/gene starts
                if(prevGrpContextCode == 'L' or prevGrpContextCode == 'U')
                  grpContextCode = 'U'
                  prevGrpContextCode = 'U'
                else
                  grpContextCode = "L"
                  prevGrpContextCode = "L"
                end
              end  
            end
          else
            nextLine = nil
            if(prevGrpContextCode == 'U' or prevGrpContextCode == 'L')
              grpContextCode = 'U'
            else
              grpContextCode = 'L'
            end
          end
          if(trkName == prevTrkName)
            addFData2Rec(@epHash[chrom][1], fstart, fstop, fbin, ftypeId, fields[9], fields[7], fields[8], ftargetStart, ftargetStop, fields[1], grpContextCode)
          else
            insertRecs(attNames, attValues, ftypeId)
            ftypeId = getFtypeId(trkName)
            @ftype2AttNameHash[ftypeId] = {}
            addFData2Rec(@epHash[chrom][1], fstart, fstop, fbin, ftypeId, fields[9], fields[7], fields[8], ftargetStart, ftargetStop, fields[1], grpContextCode)
          end
          if(!avps.nil?)
            avpList = avps.strip.split(';')
            tmpAvpHash = @fdata2AvpArr[@currIdx]
            nonFdataAvps = false
            avpList.each { |pair|
              pair.strip!
              name, value = pair.split('=')
              value = '' if(value.nil?)
              if(name != 'annotationCode' and name != 'annotationColor')
                tmpAvpHash[name] = value
                attNames[name] = nil if(!attNames.key?(name))
                attValues[value] = nil if(!attValues.key?(value))
                nonFdataAvps = true
              end
              if(name == 'annotationCode')
                @fdata2Arr[@currIdx][11] = value.to_i
              end
              if(name == 'annotationColor')
                if(value =~ /^#/)
                  @fdata2Arr[@currIdx][12] = value.gsub('#', '0x').to_i(16)
                elsif(value =~ /^\d+,\d+,\d+$/)
                  hexColor = generateHexColor(value)
                  @fdata2Arr[@currIdx][12] = hexColor.gsub('#', '0x').to_i(16)
                elsif(BRL::Util::COLOR_MAP_HASH.has_key?(value))
                  @fdata2Arr[@currIdx][12] = BRL::Util::COLOR_MAP_HASH[value].gsub('#', '0x').to_i(16)
                else
                  # Leave it as 'NULL'
                end
              end
            }
            if(nonFdataAvps)
              @keyValuePairs += (avpList.size)
              @avpEmpty = false
            end
          end
          @fdata2SeqArr[@currIdx] = seq
          @seqEmpty = false if(!seq.nil?)
          @fdata2CommentsArr[@currIdx] = comments
          @commEmpty = false if(!comments.nil?)
          @currIdx += 1
          # Insert into database
          if(@currIdx == batchSize or @keyValuePairs >= KEY_VALUE_LIMIT) # Protect against data with large AVPs per record
            insertRecs(attNames, attValues, ftypeId)
          end
          if(!ftypeCountHash.key?(ftypeId))
            ftypeCountHash[ftypeId] = 1
          else
            ftypeCountHash[ftypeId] += 1
          end
          prevTrkName = trkName.dup()
          if(!nextLine.nil?)
            line = nextLine
          else
            break
          end
        }
        if(@currIdx > 0)
          insertRecs(attNames, attValues, ftypeId)
        end
        insertFtype2AttNames()
        insertClasses(ftype2gclassHash, gclassHash) if(!gclassHash.empty?)
        insertFtypeCount(ftypeCountHash) if(!ftypeCountHash.empty?)
        reader.close()
        @fdata2Arr = nil
        @fdata2AvpArr = nil
        @fdata2SeqArr = nil
        @fdata2CommentsArr = nil
        $stderr.print("\n")
      rescue => err
        reader.close()
        raise err
      end
    end
    
    def insertFtype2AttNames()
      @dbu.deleteFtype2AttributeNameByFtypeidList(@ftype2AttNameHash.keys)
      ff = File.open('sql.txt', 'w')
      oneEntry = false
      @ftype2AttNameHash.each_key { |ftypeId|
        attNameIdHash = @ftype2AttNameHash[ftypeId]
        if(!attNameIdHash.empty?)
          attNameIdHash.each_key { |attNameId|
            ff.puts("#{ftypeId}\t#{attNameId}")  
          }
          oneEntry = true
        end
      }
      ff.close()
      @dbu.loadDataWithFile('ftype2attributeName', "./sql.txt", false, false) if(oneEntry)
    end
    
    def insertFtypeCount(ftypeCountHash)
      recs = []
      ftypeCountHash.each_key { |ftypeId|
        fcountRecs = @dbu.selectFdataCountByFtypeId(ftypeId)
        recs << [ftypeId, fcountRecs.first['count']]
      }
      @dbu.replaceRecords(:userDB, 'ftypeCount', recs, recs.size, 2, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
    end
    
    def insertClasses(ftype2gclassHash, gclassHash)
      gclassRecs = []
      gclassHash.each_key { |gclass|
        gclassRecs << [gclass]  
      }
      @dbu.insertRecords(:userDB, 'gclass', gclassRecs, true, gclassRecs.size, 1, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")  
      allGclasses = @dbu.selectAllGIDs()
      ftype2GClassRecs = []
      allGclasses.each { |rec|
        gclassHash[rec['gclass']] = rec['gid']  
      }
      ftype2gclassHash.each_key { |ftypeId|
        tmpClassHash = ftype2gclassHash[ftypeId]
        tmpClassHash.each_key { |gclass|
          ftype2GClassRecs << [ftypeId, gclassHash[gclass]]  
        }
      }
      @dbu.insertRecords(:userDB, 'ftype2gclass', ftype2GClassRecs, false, ftype2GClassRecs.size, 2, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
      gclassHash.clear()
      ftype2gclassHash.clear()
      ftype2GClassRecs.clear()
    end
    
    def getFtypeId(trkName)
      ftypeId = nil
      fmethod, fsource = trkName.split(':')
      trkRecs = @dbu.selectFtypeByTrackName(trkName)
      if(trkRecs.nil? or trkRecs.empty?)
        @dbu.insertFtype(fmethod, fsource)
        trkRecs = @dbu.selectFtypeByTrackName(trkName)
        ftypeId = trkRecs.first['ftypeid']
      else
        ftypeId = trkRecs.first['ftypeid']
      end
      return ftypeId
    end
    
    def insertRecs(attNames, attValues, ftypeId)
      maxFid = nil
      begin
        maxFid = @dbu.insertFdataSentinalRecord(@currIdx)
        fid = maxFid + 1
        origFid = fid
        terminalFid = maxFid + (@currIdx + 1)
        writeBuff = ""
        ff = File.open('sql.txt', 'w')
        @currIdx.times { |ii|
          writeBuff << "#{fid}\t#{@fdata2Arr[ii][0..3].join("\t")}\t#{@fdata2Arr[ii][5..13].join("\t")}\n"
          fid += 1
          if(writeBuff.size > WRITE_BUFFER_SIZE)
            ff.print(writeBuff)
            writeBuff = ""
          end
        }
        if(!writeBuff.empty?)
          ff.print(writeBuff)
        end
        ff.close()
        @setFieldsFdata['ftypeid'] = ftypeId
        @dbu.loadDataWithFile('fdata2', "./sql.txt", true, false, FDATA_FIELDS, @setFieldsFdata)
        if(!attNames.empty?)
          if(@prevAttNamesSize.nil? or @prevAttNamesSize != attNames.keys.size)
            @prevAttNamesSize = attNames.keys.size
            attNameRecs = []
            attNames.each_key { |key|
              attNameRecs << [key] 
            }
            @dbu.insertRecords(:userDB, 'attNames', attNameRecs, true, attNameRecs.size, 1, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
            attNameRecs.clear()
            attNameRecs = @dbu.selectAllAttNames()
            attNameRecs.each { |rec|
              attNames[rec['name']] = rec['attNameId']
            }
            attNameRecs.clear()
          end
        end
        if(!attValues.empty?)
          if(@prevAttValuesSize.nil? or @prevAttValuesSize != attValues.keys.size)
            @prevAttValuesSize = attValues.keys.size
            ff = File.open('sql.txt', 'w')
            ff.print(attValues.keys.join("\n"))
            ff.close()
            @dbu.loadDataWithFileInAttValues('./sql.txt', false, true)
            attValueRecs = @dbu.selectAllAttValues()
            attValueRecs.each { |rec|
              attValues[rec['value']] = rec['attValueId']  
            }
            attValueRecs.clear()
          end
        end
        if(!@avpEmpty)
          writeBuff = ""
          ff = File.open('sql.txt', 'w')
          fid = origFid
          @currIdx.times { |ii|
            avps =  @fdata2AvpArr[ii]
            if(!avps.empty?)
              avps.each_key { |key|
                writeBuff << "#{fid}\t#{attNames[key]}\t#{attValues[avps[key]]}\n"
                @ftype2AttNameHash[ftypeId][attNames[key]] = nil
                if(writeBuff.size > WRITE_BUFFER_SIZE)
                  ff.print(writeBuff)
                  writeBuff = ""
                end
              }
            end
            fid += 1
          }
          if(!writeBuff.empty?)
            ff.print(writeBuff)
          end
          ff.close()
          @dbu.loadDataWithFile('fid2attribute', "./sql.txt", false, false)
        end
        if(!@seqEmpty)
          ff = File.open('sql.txt', 'w')
          fid = origFid
          writeBuff = ""
          @currIdx.times { |ii|
            rec = @fdata2SeqArr[ii]
            if(!rec.nil?)
              writeBuff << "#{fid}\t#{rec}\n"
            end
            fid += 1
            if(writeBuff.size > WRITE_BUFFER_SIZE)
              ff.print(writeBuff)
              writeBuff = ""
            end
          }
          if(!writeBuff.empty?)
            ff.print(writeBuff)
          end
          ff.close()
          @setFieldsFidText['ftypeid'] = ftypeId
          @setFieldsFidText['textType'] = 's'
          @dbu.loadDataWithFile('fidText', "./sql.txt", false, false, FIDTEXT_FIELDS, @setFieldsFidText)
        end
        if(!@commEmpty)
          fid = origFid
          writeBuff = ""
          ff = File.open('sql.txt', 'w')
          @currIdx.times { |ii|
            rec = @fdata2CommentsArr[ii]
            if(!rec.nil?)
              writeBuff << "#{fid}\t#{rec}\n"
            end
            fid += 1
            if(writeBuff.size > WRITE_BUFFER_SIZE)
              ff.print(writeBuff)
              writeBuff = ""
            end
          }
          if(!writeBuff.empty?)
            ff.print(writeBuff)
          end
          ff.close()
          @setFieldsFidText['ftypeid'] = ftypeId
          @setFieldsFidText['textType'] = 't'
          @dbu.loadDataWithFile('fidText', "./sql.txt", false, false, FIDTEXT_FIELDS, @setFieldsFidText)
        end
        # Delete sentinal rec 
        @dbu.deleteFdata2RecByFid(terminalFid)
        writeBuff = ""
        $stderr.print(" . ")
        resetArrs()
      rescue Exception => dberr
        raise dberr
      end
    end
    
    # Sets up entrypint/chromosome hash by querying the target database
    # [+returns+] nil
    def setUpEpHash()
      @epHash = {}
      allFrefRecords = @dbu.selectAllRefNames()
      allFrefRecords.each { |record|
        @epHash[record['refname']] = [record['rlength'].to_i, record['rid'].to_i]
      }
    end
    
    def sortLff()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Sorting...")
      `sort -t '\t' -d -k3,4 -k5,5 -k2,2 -k6,7n #{@inputFile} > #{@inputFile}.sorted`
      `mv #{@inputFile}.sorted #{@inputFile}`
    end
    
    # Instantiates DBUtil class and connects to the database provided
    # [+returns+] nil
    def initDbuObj()
      if(!@dbrcKey)
        #Making dbUtil Object for database 'genboree'
        @genbConf = BRL::Genboree::GenboreeConfig.load
        @dbu = BRL::Genboree::DBUtil.new("#{@genbConf.dbrcKey}", nil, nil)
      else
        @dbu = BRL::Genboree::DBUtil.new(@dbrcKey, nil, nil)
      end
      refseqRecord = @dbu.selectDBNameByRefSeqID(@refSeqId)
      raise "Database with refseqId: #{@refSeqId} does not exist" if(refseqRecord.nil? or refseqRecord.empty?)
      databaseName = refseqRecord.first['databaseName']
      @dbu.setNewDataDb(databaseName)
    end
    
    # DO validation of the lff file (if required)
    # [+returns+] nil
    def validateLff()
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "validating lff file")
      # Write out the 3 column lff file for valid entrypoints
      chrDefFile = "chrDefinitions.lff"
      ff = File.open(chrDefFile, "w")
      @epHash.each_key { |chr|
        ff.puts("#{chr}\tchromosome\t#{@epHash[chr][0]}")
      }
      ff.close()
      $stderr.puts "    - done getting chromosome definitions; start validation library call"
      validator = BRL::FileFormats::LFFValidator.new({'--lffFile' => @inputFile, '--epFile' => chrDefFile})
      allOk = validator.validateFile() # returns true if no errors found
      unless(allOk)
        errors = ''
        if(validator.haveSomeErrors?() or validator.haveTooManyErrors?())
          ios = StringIO.new(errors)
          validator.printErrors(ios)
        else # WTF???
          errors = "\n\n\n\nFATAL ERROR: Unknown Error in LFFValidator. Cannot upload LFF."
        end
        raise errors
      end
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "file validated...")
    end

    # Do validation of the inputs
    # [+returns+] nil
    def validateAndProcessArgs()
      @inputFile = @optsHash['--inputFile']
      @refSeqId = @optsHash['--refSeqId']
      @userId = @optsHash['--userId']
      @skipVal = @optsHash['--skipVal'] ? true : false
      @skipSorting = @optsHash['--skipSorting'] ? true : false
      @dbrcKey = @optsHash['--dbrcKey'] ? @optsHash['--dbrcKey'] : false
    end
  end
end ; end # module BRL ; module Script

# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Script::LffUploader)
end
