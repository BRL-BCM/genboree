#!/usr/bin/env ruby

# Load libraries
require 'getoptlong'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/rackups/thin/genboreeRESTRackup'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/util/emailer'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/rest/helpers/groupApiUriHelper'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/rest/helpers/fileApiUriHelper'
require 'brl/util/expander'
require 'brl/util/convertText'
require 'uri'
require 'json'
ENV['DBRC_FILE']
ENV['PATH']
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

# Main Class
class ArrayDataImporterWrapper
  NON_ARRAYDATAIMPORTER_SETTINGS = { 'clusterQueue' => true }
  # Constructor
  # [+optsHash+] command line args
  def initialize(optsHash)
    @jsonFile = optsHash['--inputFile']
    @emailMessage = ""
    @userEmail = nil
    @context = nil
    @jobId = nil
    begin
      @fileApiHelper = BRL::Genboree::REST::Helpers::FileApiUriHelper.new()
      @grpApiHelper = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new()
      @dbApiHelper = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new()
      parseInputFile(@jsonFile)
      importArrayData()
      sendSuccessEmail()
    rescue Exception => err
      displayErrorMsgAndExit(err)
    end
  end

  # Downloads ROI Track and array data file
  # Runs arrayDataImporter.rb
  # [+returns+] nil
  def importArrayData()
    # First make sure we have a valid key to make API calls
    @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG']).dup()
    # Download roi track
    $stderr.debugPuts(__FILE__,__method__,"preroi",Time.now)
    getRoi()
    $stderr.debugPuts(__FILE__,__method__,"prearray",Time.now)
    # Next get the array/probe file
    getArrayFile()
    $stderr.debugPuts(__FILE__,__method__,"prexp",Time.now)
    # Check if we need to extract files (if file is an archive: tar.* or zip)
    # Our final goal in any case is to process all the content of the 'expandedFiles' dir
    # If the downloaded file IS the file to be processed then the 'expandedFiles' dir
    # will only contain that file. Otherwise it will have ONLY the extractes files
    fileList = []
    expander = BRL::Util::Expander.new("#{@scratchDir}/expandedFiles/#{@fileName}")
    if(expander.isCompressed?)
      expanded = expander.extract('text')
      raise "FATAL ERROR: Could not extract array/probe file." if(!expanded)
      if(expander.multiFileArchive)
        expander.uncompressedFileList.each { |file|
          next if(file == '.' or file == '..' or file == @fileName or expander.isCompressed?(file))
          # Convert to unix format
          convObj = BRL::Util::ConvertText.new(file, true)
          convObj.convertText()
          fileList.push(CGI.escape(file))
        }
      else
        # Convert to unix format
        convObj = BRL::Util::ConvertText.new(expander.uncompressedFileName, true)
        convObj.convertText()
        fileList.push(CGI.escape(expander.uncompressedFileName))
      end
      `rm #{@scratchDir}/expandedFiles/#{@fileName}` # We want to keep only the extracted files for easy processing
    else
      # Convert to unix format
      convObj = BRL::Util::ConvertText.new("#{@scratchDir}/expandedFiles/#{@fileName}", true)
      convObj.convertText()
      fileList.push(CGI.escape("#{@scratchDir}/expandedFiles/#{@fileName}"))
    end
    $stderr.debugPuts(__FILE__,__method__,"preprocess",Time.now)
    # Call the core array data import program for each of the extracted file
    @skippedHash = {}
    @missingHash = {}
    @trkHash = {}
    cutFileList = []
    cpgCoords={}
    cpgUsed = {}
    rr=File.open("#{@scratchDir}/roi.bed","r")
    rr.each_line{|line|
      sl=line.chomp.split(/\s+/).map{|xx| xx.strip}
      cpgCoords[sl[3]]="#{sl[0]}:#{sl[1]}-#{sl[2]}"
      cpgUsed[sl[3]] = false
    }
    rr.close
    fileList.each { |file|
      `mkdir -p wigFiles`
      cmd = nil
      if(@fileFormat == 'tracksAsBlocks')
        if(!@trackName.nil?)
          cmd = "arrayDataImporter.rb  -r roi.bed -a #{file} -w wigFiles -S skippedProbes.txt -M missingProbes.txt -T #{CGI.escape(@trackName)} 1> arrayDataImporter.out 2> arrayDataImporter.err"
        else
          cmd = "arrayDataImporter.rb  -r roi.bed -a #{file} -w wigFiles -S skippedProbes.txt -M missingProbes.txt  1> arrayDataImporter.out 2> arrayDataImporter.err"
        end
        cutFileList << "arrayDataImporter.err"
        $stderr.puts "launching cmd: #{cmd}"
        exitStatus = system(cmd)
        if(!exitStatus)
          arrayDataErrorStream = File.read("arrayDataImporter.err")
          @emailMessage = "#{arrayDataErrorStream}"
          $stderr.puts "Cmd failed: #{cmd.inspect}"
          raise @emailMessage
        end
        @skippedHash[File.basename(file)] = File.read("skippedProbes.txt")
        @missingHash[File.basename(file)] = File.read("missingProbes.txt")
      else # @fileformat = @tracksAsCols, break up the files into multiple 2 column files
        origFile = CGI.unescape(file)
        # Count the number of score cols in the file
        validCols = []
        validColNames = []
        roiSubtype = CGI.unescape(@roiTrack).split(':')[1]
        fh = File.open(origFile)
        fline=fh.readline()
        if(fline =~ /^#/) then
          colNames = fline.chomp.split(/\t/)
          #colNames = fline.chomp.split(/\s+/)
          numCols = colNames.length - 1
          # Skip first column
          (1 .. numCols).each{|ii|
            skipCol = false
            @ignoreColsWithKeyword.each { |keyword|
              keyword.strip!
              unless(@keywordType) # Skip col if matches
                if(colNames[ii] =~ /#{keyword}/)
                  skipCol = true 
                  break
                end
              else
                if(colNames[ii] =~ /#{keyword}/) # Include col if matches
                  skipCol = false
                  break
                else
                  skipCol = true
                end
              end
            }
            next if(skipCol)
            validCols << ii
            if(colNames[ii] =~ /\S:\S/) then
              validColNames << colNames[ii]
            else
              validColNames << "#{colNames[ii]}:#{roiSubtype}"
            end
          }
        else
          @emailMessage = "Header line not present or incorrectly formatted. Does not start with '#'"
          raise @emailMessage
        end
        if(validCols.empty?) then
          @emailMessage = "Header line not present or incorrectly formatted. No valid column names found. Please ensure that all columns are tab-separated"
          raise @emailMessage
        else
          numCols = validCols.length
        end
        # Header looks good start processing

        fileHandles = []
        skippedProbes = []
        FileUtils.mkdir_p("#{@scratchDir}/skippedProbes")
        missingProbes = []
        FileUtils.mkdir_p("#{@scratchDir}/missingProbes")
        validColNames.each{|colName|
          newfh=File.open("wigFiles/#{CGI.escape(colName)}.wig","w")
          newfh.print "track name='#{colName}' type=wiggle_0\n"
          fileHandles << newfh
        }
        origFileName = File.basename(origFile)
        fh.each_line{|fline|          
          next if(fline.nil? or fline !~ /\S/ or fline =~ /^#/)
          sl=fline.chomp.split(/\t/)
          landmark = cpgCoords[sl[0]]
          if(!landmark.nil?) then
            if(landmark !~ /^#/) then
              landmark =~ /^([^:]+):(\d+)-(\d+)$/
              chrom, start, stop = $1, $2.to_i, $3.to_i
              (0 .. numCols-1).each{|ii|
                val = sl[validCols[ii]]
                if(!val.nil? and val.valid?(:float)) then
                  fileHandles[ii].puts "fixedStep chrom=#{chrom} start=#{start + 1} span=1 step=1"
                  (stop - start).times {fileHandles[ii].puts val}
                else
                  skippedWriter = (skippedProbes[ii] or (skippedProbes[ii]=File.open("#{@scratchDir}/skippedProbes/#{origFileName}_#{validColNames[ii]}_skipped.txt","w")))
                  skippedWriter.puts sl[0]
                  @skippedProbesExist = true
                end
              }
              cpgUsed[sl[0]] = true
            else
              fh.close()
              raise "Probe Name: #{sl[0].inspect} appears twice in the probe file (Line Number:#{fh.lineno}). All probes must be present only once for a particular track."
            end
          else
            (0 .. numCols-1).each{|ii|
              skippedWriter = (skippedProbes[ii] or (skippedProbes[ii]=File.open("#{@scratchDir}/skippedProbes/#{origFileName}_#{validColNames[ii]}_skipped.txt","a+")))
              skippedWriter.puts(sl[0])
            }
            @skippedProbesExist = true
          end
        }
        fh.close()
        fileHandles.each{|ff| ff.close}
        skippedProbes.each{|ss| if(ss) then ss.close() end}
        missingProbes = File.open("#{@scratchDir}/missingProbes/#{origFileName}_missing.txt","w+")
        cpgUsed.each_key{|cc|
          if(!cpgUsed[cc]) then
            missingProbes.puts(cc)
            @missingProbesExist = true
          end
          cpgUsed[cc] = false
        }
        missingProbes.close()
      end
      $stderr.debugPuts(__FILE__,__method__,"preupload",Time.now)
      uploadWigFiles(@dbApiHelper)
      $stderr.debugPuts(__FILE__,__method__,"postupload",Time.now)
      $stderr.puts "file: #{file.inspect} processed."
    }
    $stderr.debugPuts(__FILE__,__method__,"postprocess",Time.now)

    # Gzip/remove some of the intermediate  files
    compressAndRemoveFiles(cutFileList)
    $stderr.debugPuts(__FILE__,__method__,"postcompress",Time.now)
    if(@totalTrks == @failedTrks.size)
      @emailMessage = "None of the samples could be uploaded as tracks due to failure to upload wig files."
      raise @emailMessage
    end
  end

  def uploadWigFiles(dbHelperObj)
    # Upload the wig files in the 'wigFiles' dir
    fileHash = {}
    @emptyTrks = []
    @failedTrks = []
    aliasUri = ApiCaller.applyDomainAliases(@dbUri)
    uri = URI.parse(aliasUri)
    host = uri.host
    rcscUri = uri.path
    rr = /([^= \t]+)\s*=\s*(?:(?:([^ \t"']+))|(?:"([^"]+)")|(?:'([^']+)'))/ # regular expression for parsing track header
    @totalTrks = 0
    Dir.entries("wigFiles").each { |wigFile|
      next if(wigFile == '.' or wigFile == '..' or wigFile !~ /\.wig$/)
      next if(fileHash.key?("wigFiles/#{wigFile}"))
      @totalTrks += 1
      wigReader = File.open("wigFiles/#{wigFile}")
      fileHash["wigFiles/#{wigFile}"] = nil
      trackHeader = wigReader.readline.strip
      trackHash = {}
      trackHeader.scan(rr) { |md|
        trackHash[md[0]] = "#{md[1]}#{md[2]}#{md[3]}" if(!trackHash.has_key?(md[0]))
      }
      wigReader.close()
      # Add track to hash
      trkName = trackHash['name']
      @trkHash[trkName] = nil
      # If the user has opted to delete existing tracks with matching names, we need to nuke them from the target database before proceeding with the upload
      if(@deleteDupTracks)
        apiCaller = WrapperApiCaller.new(host, "#{rcscUri}/trk/#{CGI.escape(trkName)}", @userId)
        apiCaller.get()
        if(apiCaller.succeeded?) # Track exists, nuke it
          apiCaller.delete()
          if(!apiCaller.succeeded?)
            $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to delete pre-existing track:#{trkName.inspect} (during a re-attempt)\nAPI Response:\n#{apiCaller.respBody.inspect}")
            raise "Error: Could not delete pre-existing track: #{trkName.inspect} (during a re-attempt) from target database."
          else
            $stderr.debugPuts(__FILE__, __method__, "STATUS", "Pre-existing track: #{trkName.inspect} deleted.")
          end
        end
      end
      # Upload track
      numLines = `wc -l wigFiles/#{wigFile}`.split(" ")[0]
      if(numLines.to_i == 1)
        @emptyTrks << trkName
        next
      end
      uploadWig("wigFiles/#{wigFile}", trkName, dbHelperObj)
      # Set the special attributes (rcovTrack)
      attrRsrc = "#{rcscUri}/trk/#{CGI.escape(trkName)}/attribute/rcovTrack/value?"
      attrRsrc << "gbKey=#{dbHelperObj.extractGbKey(@dbUri)}" if(dbHelperObj.extractGbKey(@dbUri))
      payload = { "data" => {"text" => "#{@arrayDb.chomp("?")}/trk/#{CGI.escape(@roiTrack)}?gbKey=#{@roiGbKey}"} }
      apiCaller = WrapperApiCaller.new(@host, attrRsrc, @userId)
      apiCaller.put(payload.to_json)
      if(!apiCaller.succeeded?)
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Failed to set attribute")
      end
      # Methylation status
      attrRsrc = "#{rcscUri}/trk/#{CGI.escape(trkName)}/attribute/isMethylation/value?"
      attrRsrc << "gbKey=#{dbHelperObj.extractGbKey(@dbUri)}" if(dbHelperObj.extractGbKey(@dbUri))
      payload = { "data" => {"text" => "true" } }
      apiCaller = WrapperApiCaller.new(@host, attrRsrc, @userId)
      apiCaller.put(payload.to_json)
    }
  end

  def compressAndRemoveFiles(cutFileList)
    # Remove all '.bin' files
    Dir.entries(".").each { |file|
      next if(file == '.' or file == '..')
      `rm #{file}` if(file =~ /\.bin$/)
    }
    `rm -rf wigFiles`
    `rm -rf expandedFiles`
    # Gzip all 'cut' files
    cutFileList.each { |file|
      `zip #{file}.zip #{file}`
    }
    `zip roi.bed.zip roi.bed`
    `rm roi.bed`
    if(File.exists?(@fileName)) then
      `zip #{@fileName}.zip #{@fileName}`
      `rm -rf #{@fileName}`
    end
  end

  # [+inputFile+] wig file to be uploaded into Genboree
  # [+returns+] nil
  def uploadWig(inputFile, trkName, dbHelperObj)
    @failedTrks = []
    command = "importWiggleInGenboree.rb"
    command <<  " -u #{@userId} -d #{@refSeqId} -g #{CGI.escape(@groupName)} -J #{@jobId} -t #{CGI.escape(trkName)} -i #{CGI.escape(inputFile)} "
    command << " -j . -F --dbrcKey #{@genbConf.dbrcKey} -G "
    outFile = "./#{CGI.escape(trkName)}.importWiggle.out"
    errFile = "./#{CGI.escape(trkName)}.importWiggle.err"
    command << " > #{outFile} 2> #{errFile}"
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Launching sub-process: #{command}")
    # Check if track is already present (For example: Track Copier creates an empty track before calling this method)
    targetUri = URI.parse(@dbUri)
    apiCaller = WrapperApiCaller.new(targetUri.host, "#{targetUri.path}/trk/#{CGI.escape(@trackName)}/annos/count?", @userId)
    apiCaller.get()
    emptyTrk = nil
    # If call fails, assume track not present
    if(!apiCaller.succeeded?)
      apiCaller.setRsrcPath("#{targetUri.path}/trk/#{CGI.escape(@trackName)}")
      apiCaller.put() # Create an empty track
      emptyTrk = true
    else
      emptyTrk = (apiCaller.parseRespBody['data']['count'] > 0 ? false : true)
    end
    apiCaller = WrapperApiCaller.new(targetUri.host, "#{targetUri.path}/trk/#{CGI.escape(@trackName)}/attribute/gbPartialEntity/value?", @userId)
    payload = { "data" => { "text" => 1 } }
    apiCaller.put({}, payload.to_json)
    `#{command}`
    exitObj = $?.dup()
    # Untag the track
    payload = { "data" => { "text" => 0 } }
    apiCaller.put({}, payload.to_json)
    # Check if the sub script ran successfully
    if(exitObj.exitstatus != 0)
      # Upload failed. If track was empty, nuke it.
      if(emptyTrk)
        apiCaller = WrapperApiCaller.new(targetUri.host, "#{targetUri.path}/trk/#{CGI.escape(@trackName)}?", @userId)
        apiCaller.delete()
      end
      @failedTrks << trkName
      $stderr.puts "Sub-process failed: #{command}\n\nCheck #{outFile} and #{errFile} for more information. "
    end
    Dir.entries(".").each { |file|
      if(file =~ /\.bin/)
        host = URI.parse(@dbUri).host
        rcscUri = URI.parse(@dbUri).path
        rsrcPath = "#{rcscUri}/file/#{CGI.escape(file)}/data?fileType=bin"
        rsrcPath << "&gbKey=#{dbHelperObj.extractGbKey(@dbUri)}" if(dbHelperObj.extractGbKey(@dbUri))
        apiCaller = WrapperApiCaller.new(host, rsrcPath, @userId)
        apiCaller.put({}, File.open(file))
        if(!apiCaller.succeeded?)
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Error:\n#{apiCaller.respBody.inspect}")
          raise "API Call to transfer bin file failed."
        else
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "bin file: #{file} transferred to target db. Removing local copy...")
          `rm -f #{file}`
        end
      end
    }
  end

  # Downloads ROI Track
  # [+returns+] nil
  def getRoi()
    $stderr.puts "Downloading roi Track..."
    uri = URI.parse(@arrayDb)
    rcscUri = uri.path
    rcscUri << "/trk/#{@roiTrack}/annos?format=bed&gbKey=#{@roiGbKey}&ucscTrackHeader=false"
    apiCaller = WrapperApiCaller.new(uri.host, rcscUri, @userId)
    ww = File.open("#{@scratchDir}/roi.bed", "w")
    apiCaller.get() {|chunk| ww.print chunk}
    ww.close()
    if(!apiCaller.succeeded?)
      raise "'getting' roi track failed:\napiCaller respBody: #{apiCaller.respBody.inspect} #{apiCaller.rsrcPath}"
    end
  end

  # Downloads array/probe file
  # [+retuns+] nil
  def getArrayFile()
    $stderr.puts "Downloading array file..."
    `mkdir #{@scratchDir}/expandedFiles`
    # Put the file in a new dir since it may be an archive of files and we will need to extract the archive before processing
    @fileName = CGI.escape(File.basename(@fileApiHelper.extractName(@arrayFile)))
    ww = File.open(@fileName, "w")
    aliasUri = ApiCaller.applyDomainAliases("#{@arrayFile}")
    uri = URI.parse(aliasUri)
    rcscUri = uri.path
    rcscUri = rcscUri.chomp("?")
    rcscUri << "/data?"
    rcscUri << "gbKey=#{@fileApiHelper.extractGbKey(aliasUri)}" if(@fileApiHelper.extractGbKey(aliasUri))
    apiCaller = WrapperApiCaller.new(uri.host, rcscUri, @userId)
    apiCaller.get() { |chunk| ww.print chunk}
    ww.close
    $stderr.puts "download completed"
    if(!apiCaller.succeeded?)
      raise "'getting' file: #{fileName.inspect} failed:\napiCaller respBody: #{apiCaller.respBody.inspect}"
    end
    `cp #{@fileName} #{@scratchDir}/expandedFiles`
  end

  def addToolTitle(jsonObj)
    jsonObj['context']['toolTitle'] = @toolConf.getSetting('ui', 'label')
    return jsonObj
  end

  # parses the json input file
  # [+inputFile+] json file
  # [+returns+] nil
  def parseInputFile(inputFile)
    jsonObj = JSON.parse(File.read(inputFile))
    @arrayFile = jsonObj['inputs'][0]
    @fileName = CGI.escape(File.basename(@fileApiHelper.extractName(@arrayFile)))
    @dbUri = jsonObj['outputs'][0]
    dbrcFile = File.expand_path(ENV['DBRC_FILE'])
    @toolIdStr = jsonObj['context']['toolIdStr']
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr)
    jsonObj = addToolTitle(jsonObj)
    @dbrcKey = jsonObj['context']['apiDbrcKey']
    @adminEmail = jsonObj['context']['gbAdminEmail']
    @userId = jsonObj['context']['userId']
    @jobId = jsonObj['context']['jobId']
    @context = jsonObj['context']
    @userEmail = jsonObj['context']['userEmail']
    @userLogin = jsonObj['context']['userLogin']
    @roiTrack = jsonObj['settings']['roiTrack']
    @arrayDb = jsonObj['settings']['arrayDb']
    @roiKey = jsonObj['settings']['roiKey']
    @analysisName = jsonObj['settings']['analysisName']
    @trackName = nil
    lffType = jsonObj['settings']['lffType']
    lffSubType = jsonObj['settings']['lffSubType']
    @roiGbKey = jsonObj['settings']['roiGbKey']
    @refSeqId = jsonObj['settings']['refSeqId']
    @deleteDupTracks = jsonObj['settings']['deleteDupTracks']
    @keywordType = jsonObj['settings']['keywordType']
    @fileFormat = jsonObj['settings']['fileFormat']
    ignoreColsWithKeyword = jsonObj['settings']['ignoreColsWithKeyword']
    @ignoreColsWithKeyword = []
    if(ignoreColsWithKeyword)
      @ignoreColsWithKeyword = ignoreColsWithKeyword.split(',')
    end
    @groupName = @grpApiHelper.extractName(@dbUri)
    @dbName = @dbApiHelper.extractName(@dbUri)
    @trackName = "#{lffType}:#{lffSubType}" if(!lffType.nil? and !lffType.empty? and !lffSubType.nil? and !lffSubType.empty?)
    dbrc = BRL::DB::DBRC.new(dbrcFile, @dbrcKey)
    @user = dbrc.user
    @pass = dbrc.password
    @host = dbrc.driver.split(/:/).last
    @scratchDir = jsonObj['context']['scratchDir']
    @toolPrefix = jsonObj['context']['toolScriptPrefix']
    @scratchDir = "." if(@scratchDir.nil? or @scratchDir.empty?)
    @missingProbesExist = false
    @skippedProbesExist = false
  end

  # Displays error message and quits
  # [+msg+]  error message
  #  [+returns+] nil
  def displayErrorMsgAndExit(msg)
    $stderr.puts "ERROR:\n #{msg}"
    $stderr.puts "ERROR Backtrace:\n #{msg.backtrace.join("\n")}"
    @emailMessage = msg.to_s if(@emailMessage.nil? or @emailMessage.empty?)
    sendErrorEmail()
    exit(14)
  end

  def buildEmailBodyPrefix(msg)
    # defaults if things very very wrong (no json file even)
    userFirstName = 'User'
    userLastName = ''
    toolTitle = 'Array Data Importer'

    # use appropriate info from json file if available
    if(@context and @context.is_a?(Hash))
      userFirstName = @context['userFirstName'] if(@context['userFirstName'])
      userLastName = @context['userLastName'] if(@context['userLastName'])
      toolTiitle = @context['toolTitle'] if(@context['toolTitle'])
    end
    buff = ''
    buff << "\nHello #{userFirstName} #{userLastName},\n\n#{msg}\n\nJOB SUMMARY:\n"
    buff << <<-EOS
    JobID          : #{@jobId}
    Analysis Name  : #{@analysisName}
    EOS
    return buff
  end

  def sendEmail(emailTo, subject, body)
    self.class.sendEmail(emailTo, subject, body)
  end

  def self.sendEmail(emailTo, subject, body)
    genbConf = ENV['GENB_CONFIG']
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    emailer = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)

    # Email to user
    if(!emailTo.nil?)
      emailer.addRecipient(emailTo)
      emailer.addRecipient(genbConfig.gbAdminEmail)
      emailer.setHeaders(genbConfig.gbFromAddress, emailTo, subject)
      emailer.setMailFrom(genbConfig.gbFromAddress)
      emailer.addHeader("Bcc: #{genbConfig.gbBccAddress}")
      body ||= "There was an unknown problem."
      emailer.setBody(body)
      emailer.send()
    end
  end

  def sendSuccessEmail()
    # Build message body
    buff = buildEmailBodyPrefix("Your Array Data Importer job has completed successfully.")
    buff << "\nThe following array/probe file has been imported: \n"
    buff << " #{CGI.unescape(File.basename(@arrayFile.chomp("?")))}\n"
    #buff << "\nYou will get email notifications once the wig tracks(s) have been uploaded.\n\n"
    buff << "\nThe following tracks were uploaded in the target database:\n\n"
    @trkHash.each_key { |key|
      buff << "#{key}\n"
    }
    buff << "\n\nThe Genboree Team"
    if(@fileFormat == 'tracksAsBlocks') then
      probesSkipped = false
      @skippedHash.each_key { |key|
        if(!@skippedHash[key].empty?)
          probesSkipped = true
          break
        end
      }
      unless(probesSkipped)
        @missingHash.each_key { |key|
          if(!@missingHash[key].empty?)
            probesSkipped = true
            break
          end
        }
      end
      if(probesSkipped)
        buff << "\n\nPlease note that some of the probes could not be processed due to the following errors:\n\n"
        @skippedHash.each_key { |key|
          if(!@skippedHash[key].empty?)
            buff << "Probes skipped due to Non-Numeric Scores (#{CGI.unescape(key)}):\n"
            buffIO = StringIO.new(@skippedHash[key])
            buffIO.each_line { |line|
              buff << " #{line}"
            }
            buffIO.close()
          end
        }
        @missingHash.each_key { |key|
          if(!@missingHash[key].empty?)
            buff << "Probes skipped due to Unknown Names (#{CGI.unescape(key)}):\n"
            buffIO = StringIO.new(@missingHash[key])
            buffIO.each_line { |line|
              buff << " #{line}"
            }
            buffIO.close()
          end
        }
      end
      if(!@failedTrks.empty?)
        buff << "\nThe following tracks could not be uploaded because there was a problem uploading their wig file:\n\n"
        @failedTrks.each { |trk|
          buff << "#{trk}\n"  
        }
      end
    else
      probeBuff = <<-EOS
  File Location in the Genboree Workbench:
  Group    : #{@groupName}
  Database : #{@dbName}
  Path to File:
  Files
  * ArrayDataImporter
    * #{@analysisName}
      EOS
      if(@missingProbesExist) then
        `zip -r missingProbes.zip ./missingProbes`
        $stderr.debugPuts(__FILE__,__method__,"premiss",Time.now)
        uploadDataFile("missingProbes.zip","missingProbes.zip")
        $stderr.debugPuts(__FILE__,__method__,"postmiss",Time.now)
        buff << "\n\nPlease note that some of the probes in the ROI track did not have scores in one or more samples. The details of these probes broken out by sample are available in missingProbes.zip in the results area.\n\n"
        probeBuff << "      * missingProbes.zip\n"
      end
      if(@skippedProbesExist) then
        `zip -r skippedProbes.zip ./skippedProbes`
        $stderr.debugPuts(__FILE__,__method__,"preskip",Time.now)
        uploadDataFile("skippedProbes.zip","skippedProbes.zip")
        $stderr.debugPuts(__FILE__,__method__,"postskip",Time.now)
        buff << "\n\nPlease note that some of the probes were skipped either due to non-numeric values or unknown names. The details of these probes broken out by sample are available in skippedProbes.zip in the results area.\n\n"
        probeBuff << "      * skippedProbes.zip\n"
      end
      if(!@emptyTrks.empty?)
        probeBuff << "The following tracks could not be uploaded because their corresponding sample columns did not have any valid scores:\n\n"
        @emptyTrks.each { |trk|
          probeBuff << "#{trk}\n"  
        }
      end
      if(!@failedTrks.empty?)
        probeBuff << "The following tracks could not be uploaded because there was a problem uploading their wig file:\n\n"
        @failedTrks.each { |trk|
          probeBuff << "#{trk}\n"  
        }
      end
      if(@missingProbesExist or @skippedProbesExist or !@emptyTrks.empty? or !@failedTrks.empty?)
        buff << probeBuff
      end
      `rm -rf skippedProbes`
      `rm -rf missingProbes`
    end

    sendEmail(@userEmail, "GENBOREE NOTICE: Your #{@context['toolTitle']} completed", buff)
    $stderr.puts "STATUS: All Done"
  end

  def uploadDataFile(srcPath,destPath)
    aliasUri = ApiCaller.applyDomainAliases(@dbUri)
    uri = URI.parse(aliasUri)
    host = uri.host
    rsrcUri = uri.path
    restPath = "#{rsrcUri}/file/ArrayDataImporter/#{CGI.escape(@analysisName)}/#{destPath}/data"
    apicaller = WrapperApiCaller.new(@host,restPath,@userId)
    infile = File.open(srcPath,"r")
    apicaller.put(infile)
    infile.close
    if apicaller.succeeded?
      $stderr.debugPuts(__FILE__, __method__, "SUCCESS", "Uploaded file #{srcPath} to #{destPath}")
    else
      errMsg = "Failed to upload #{srcFilePath} to #{destFilePath} file "
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "#{errMsg}")
      $stderr.debugPuts(__FILE__, __method__, "DEBUG", "apiCaller.respBody:#{apicaller.respBody.inspect}")
    end
  end


  # sends error email to recipients about the job status
  # [+returns+] no return value
  def sendErrorEmail()
    genbConf = ENV['GENB_CONFIG']
    @jobId = "Unknown Job Id" if(@jobId.nil?)
    genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
    @userEmail = genbConfig.gbAdminEmail if(@userEmail.nil?)

    # EMAIL TO USER:
    # appropriate tool title
    if(@context and @context['toolTitle'])
      toolTitle = @context['toolTitle']
    else
      toolTitle = 'Array Data Importer'
    end

    # email body
    @emailMessage = "There was an unknown problem." if(@emailMessage.nil? or @emailMessage.empty?)
    body = buildEmailBodyPrefix("Unfortunately your #{toolTitle} job has failed. Please contact the Genboree Team (#{genbConfig.gbAdminEmail}) with the error details for help with this problem.\n\nERROR DETAILS:\n\n#{@emailMessage}")
    body << "\n\n- The Genboree Team"

    # send email with subject and body
    sendEmail(@userEmail, "GENBOREE NOTICE: Your #{toolTitle} job failed", body)
  end

end


# Class for running the script and parsing args
class RunScript

  VERSION_NUMBER="1.0"
  DEFAULTUSAGEINFO="

  Author: Sameer Paithankar

  Description: This tool is intended to used for uploading samples via the workbench. The tool imports array based data given a ROI Track and a probe/array data file
  by generating a wig file and uploading it in Genboree.
  -j  --inputFile                     => input file in json format
  -v  --version                       => Version of the program
  -h  --help                          => Display help

  "
  def self.printUsage(additionalInfo=nil)
    puts DEFAULTUSAGEINFO
    puts additionalInfo unless(additionalInfo.nil?)
    if(additionalInfo.nil?)
      exit(0)
    else
      exit(15)
    end
  end

  def self.printVersion()
    puts VERSION_NUMBER
    exit(0)
  end

  def self.parseArgs()
    optsArray=[
      ['--inputFile','-j',GetoptLong::REQUIRED_ARGUMENT],
      ['--version','-v',GetoptLong::NO_ARGUMENT],
      ['--help','-h',GetoptLong::NO_ARGUMENT]
    ]
    progOpts=GetoptLong.new(*optsArray)
    optsHash=progOpts.to_hash
    if(optsHash.key?('--help'))
      printUsage()
    elsif(optsHash.key?('--version'))
      printVersion()
    end
    printUsage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    return optsHash
  end

  def self.performArrayDataImporterWrapper(optsHash)
    arrayDataImportWrappererObj = ArrayDataImporterWrapper.new(optsHash)
  end

end

optsHash = RunScript.parseArgs()
RunScript.performArrayDataImporterWrapper(optsHash)
