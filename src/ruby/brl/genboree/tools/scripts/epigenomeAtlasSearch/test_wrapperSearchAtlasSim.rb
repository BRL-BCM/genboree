#!/usr/bin/env ruby

require 'brl/genboree/rest/apiCaller'
require 'brl/db/dbrc'
require 'brl/util/emailer'
require 'brl/util/util'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'json'
require 'getoptlong'
require 'rubygems'
require 'uri'
require 'fileutils'
include BRL::Genboree::REST

class WrapperSearchAtlasSim

  def initialize(optsHash)
	@optsHash = optsHash
	json =  @optsHash['--jsonFile']
	noPermCheck = @optsHash['--noPermCheck']
	@prefix = "searchAtlasSim_"
	@outputfile = @prefix+"output.txt"
	@jsonObj = nil
	@noPermCheck = noPermCheck
	@gbLock = nil
  @gbLockFileKey = nil
	@jobid = nil
	@cfname = nil
	@inputfname = nil
	@inputurl = nil
	@inputver = nil
	@roi = nil
	@roifname = nil
	@roiurl = nil
	@roiver = nil
	@useGenboreeRoiScores = nil
	@targetfnames = Array.new()
	@targeturls = Array.new()
	@targetvers = Array.new()
	@targettracks = Array.new()
	@targettrackdescriptions = Array.new()
	@targettrackbrowserurls = Array.new()
	@targetlist = nil
	@targettracklist = nil
	@step = "variable"
	@outputurl = nil
	@experimentName = nil
	@haveRoiTrk = false
	@resolution = "span=20"
	@apiUserName = nil
	@userFirstName = nil
	@userLastName = nil
	@userPasswd = nil
	@userEmail = nil
	@userId = nil
	@tempDir = nil     #"tmp/"
	@gbAdminEmail = nil
	@command = nil
	@result = nil

	unless File.exist?(json)
		raise "Problem reading the standard tool interface config file."
	end

	#getParams(json)
	begin
		@jsonObj = JSON.parse(File.read(json))
	rescue
		raise "Problem parsing json file: " + $!
	end

	user = nil
	pass = nil
	host = nil
	begin
		#dbrcFile = File.expand_path("~/.dbrc")
		dbrcFile = File.expand_path(ENV['DBRC_FILE'])
		dbrcKey = @jsonObj['context']['apiDbrcKey']
		dbrc = BRL::DB::DBRC.new(dbrcFile, dbrcKey)
		user = dbrc.user
		pass = dbrc.password
		host = dbrc.driver.split(/:/).last
	rescue
		raise "cannot read .dbrc file: " + $!
	end

	@jobid = @jsonObj["context"]["jobId"]
	@apiUserName = user
	@userFirstName = @jsonObj["context"]["userFirstName"]
	@userLastName = @jsonObj["context"]["userLastName"]
	@userPasswd = pass
	@userEmail = @jsonObj["context"]["userEmail"]
	@userId = @jsonObj["context"]["userId"]
	@gbAdminEmail = @jsonObj["context"]["gbAdminEmail"]

	if(@jobid == nil or @apiUserName == nil or @userPasswd == nil or @userEmail == nil)
		raise "Problem parsing the standard tool interface config file."
	end

	@tempDir = File.expand_path(@jsonObj["context"]["scratchDir"])
	if @tempDir == nil
		@tempDir = File.expand_path("tmp/")
	else
		@tempDir = @tempDir + "/"
	end
	unless File.exist?(@tempDir) and File.writable?(@tempDir)
		#FileUtils.rm_r @tempDir
	#else
		raise "could not write on temporary directory"
	end
	#FileUtils.mkdir_p @tempDir


	if @jsonObj.has_key?("settings")
		@experimentName = @jsonObj["settings"]["experimentName"]
		@freeze = ( (@jsonObj["settings"]["freeze"] == "freeze1") ? "atlasDataFreeze" : "atlasDataFreeze2" )
    haveRoiTrkSetting = @jsonObj["settings"]["haveRoiTrk"]
    if(haveRoiTrkSetting.is_a?(String))
      haveRoiTrkSetting.strip!
      @haveRoiTrk = ( (haveRoiTrkSetting =~ /^(?:true|yes)$/i) ? true : false)
    else # assume boolean
      @haveRoiTrk = haveRoiTrkSetting
    end

    useGenboreeRoiScores = @jsonObj["settings"]["useGenboreeRoiScores"]
    if(useGenboreeRoiScores.is_a?(String))
      useGenboreeRoiScores.strip!
      @useGenboreeRoiScores = ( (useGenboreeRoiScores =~ /^(?:true|yes)$/i) ? true : false)
    else # assume boolean
      @useGenboreeRoiScores = useGenboreeRoiScores
    end

		raise "Problem using Genboree ROI scores : a ROI track is required." if @haveRoiTrk == false and @useGenboreeRoiScores == true

		case @jsonObj["settings"]["resolution"]
			when "high"
				@resolution = (@haveRoiTrk ? "span=1000" : "span=10000")
			when "medium"
				@resolution = (@haveRoiTrk ? "span=1000" : "span=10000")
			when "low"
				@resolution = (@haveRoiTrk ? "span=1000" : "span=10000")
			else
				@resolution = (@haveRoiTrk ? "span=1000" : "span=10000")
		end
	end
  end


  def submitJob()
  	@gbLock = nil
    @gbLockFileKey = @jsonObj['context']['gbLockFileKey'].to_sym
    begin
      loop {
        @gbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(@gbLockFileKey)
        hasPermission = (@noPermCheck or @gbLock.getPermission(false))
        puts hasPermission.class
        if(hasPermission)
          cmdResult =  @useGenboreeRoiScores ? executesearchAtlasSimUsingGenboreeROIScore() : executesearchAtlasSim()
          if cmdResult == true
            if summary = readFileContent("#{@prefix}summary.txt")
              if putResultFile() and putResultSummaryFile(summary)
                sendSuccessEmail(summary)
              else
                description = "Could not upload output data."
                sendFatalErrorEmail(description)
                $stderr.puts "Could not upload output data."
              end
            else
              description = "Error occurred while running the SearchAtlasSim tool."
              sendFatalErrorEmail(description)
              $stderr.puts "Error occurred while running the SearchAtlasSim tool."
            end
            compressTempFiles()
          else
            if $?.exitstatus == 57
              description = "The data would not provide enough vector length for correlation."
              sendFatalErrorEmail(description)
            else
              description = "Could not execute the SearchAtlasSim tool."
              sendFatalErrorEmail(description)
            end

            compressTempFiles()
            $stderr.puts "Could not execute the SearchAtlasSim tool."
          end
          @noPermCheck = false if(@noPermCheck)
          @gbLock.releasePermission() unless(@noPermCheck)
          break
        else
          sleepTime = BRL::Genboree::LockFiles::GenericDbLockFile.sleepTimeScaledBySize(10_000_000, 30, 1800, 7)
          sleep(sleepTime)
        end
      }
    rescue Exception => err
      if(!@noPermCheck and @gbLock.is_a?(BRL::Genboree::LockFiles::GenericDbLockFile))
        @gbLock.releasePermission()
      end
      compressTempFiles()
      $stderr.puts err.message()
      $stderr.puts err.backtrace.join("\n")

      description = err.message()
      unless(description =~ /^Could not/)
        description = "Unexpected Error at #{err.backtrace.join("\n")}"
        sendFatalErrorEmail(description)
      else
        sendFatalErrorEmail(description)
      end
    end
  end

  def executesearchAtlasSim()
    puts "running searchAtlasSim....."
    @cfname = getChromInfo(@jsonObj["inputs"][0])
    if(@cfname == nil)
      #puts "Error: cannot create chromosome information from #{@jsonObj["inputs"][0]}"
      raise "Could not download chromosome information from #{@jsonObj["inputs"][0]}."
    end

    @inputurl = @jsonObj["inputs"][0]
    @inputver = getChromVersion(@jsonObj["inputs"][0])
    @inputfname = getWigFile(@jsonObj["inputs"][0])
    puts "inputfname : #{@inputfname}"
    if(@inputfname == nil)
      raise "Could not download required input data, #{@jsonObj["inputs"][0]}."
    end

    unless(hasAnnotaion?(@inputfname))
      trackname = getTrackName(@inputurl)
      description = "Could not complete executesearchAtlasSim because the '"+ trackname + "' track is empty."
      #sendFatalErrorEmail(description)
      compressTempFiles()
      raise "ERROR: Could not complete executesearchAtlasSim because the '" + trackname + "' track is empty.\n  File: #{@inputfname.inspect}\n  Input Track: #{@jsonObj['inputs'].first.inspect}"
    end

    if(@haveRoiTrk)
      @roiurl = @jsonObj["inputs"][1]
      @roiver = getChromVersion(@jsonObj["inputs"][1])
      @roifname = getLffTargetFile(@jsonObj["inputs"][1])
      if(@roifname == nil)
        raise "Could not download required region of interest, #{@jsonObj["inputs"][1]}."
      end
      @roi = "-r " + @roifname
    end

    puts "tranfilelist : #{@jsonObj["settings"]["targetTrackListFile"].class}"
    targeturllist = getTargetUrlList(@jsonObj["settings"]["targetTrackListFile"])
    if(targeturllist == nil)
      raise "ERROR: Could not download required target data, #{@jsonObj["settings"]["targetTrackListFile"]}."
    else
      turlptr = File.open(targeturllist, "r")
      tcount = 1
      turlptr.each { |line|
        if(line =~ /\S/)
          cols = line.strip.split(/\t/)
          @targeturls.push(cols[1])
          # We will check the track versions IF the urls with all the atlas data are actual track URLs.
          # If just direct links to files or something, we won't bother checking, just assume same as the input track.
          if(cols[1] =~ %r{/trk/}) # then looks like a track url, check version
            @targetvers.push(getChromVersion(cols[1]))
            trackdescription = getTrackDescription(cols[1])
            @targettrackdescriptions.push(trackdescription)
            trackbrowserurl = getTrackBrowserUrl(cols[1])
            @targettrackbrowserurls.push(trackbrowserurl)
          else # not track url, assume direct url to a wig file (and that version is same as input)
            @targetvers.push(@inputver)
            @targettrackdescriptions.push("")
            @targettrackbrowserurls.push("")
          end

          tfname = getWigFile(cols[1])
          if(tfname == nil)
            raise "ERROR: Could not download required input data for #{cols[0].inspect}.\n  URL: #{cols[1].inspect}."
          end
          @targetfnames.push(tfname)
          unless hasAnnotaion?(tfname)
            description = "Could not complete executesearchAtlasSim because the #{cols[0].inspect} track is empty.\n  URL: #{cols[1].inspect}."
            #sendFatalErrorEmail(description)
            compressTempFiles()
            raise "Could not complete executesearchAtlasSim because the #{cols[0].inspect} track is empty.\n  URL: #{cols[1].inspect}."
          end
          @targettracks.push(cols[0])
        end
        tcount += 1
        #break if tcount == 4  #testversion
      }
      turlptr.close()
    end

    @targetlist = @tempDir + @prefix + "targetfilenamelist.txt"
    targets = File.open(@targetlist,"w")
    targets.puts @targetfnames
    targets.close

    @targettracklist = @tempDir + @prefix + "targettracklist.txt"
    targettracks = File.open(@targettracklist,"w")
    #targettracks.puts @targettracks
    @targettracks.each_index {	|index|
      targettracks.puts "#{@targettracks[index]}\t#{@targetvers[index]}\t#{@targettrackdescriptions[index]}\t#{@targettrackbrowserurls[index]}"
    }
    targettracks.close

    #check genome versions for each input
    @targetvers.each {	|tver|
      unless tver == @inputver
        sendFailEmail()
        compressTempFiles()
        raise "Could not complete executesearchAtlasSim because the databases the tracks come from are not compatible."
      end
    }

    if(@haveRoiTrk)
      unless(@inputver == @roiver)
        sendFailEmail()
        compressTempFiles()
        raise "Could not complete executesearchAtlasSim because the databases the tracks come from are not compatible."
      end
    end

    @outputurl = @jsonObj["outputs"][0]
    if(@outputurl == nil)
      #puts "Error: cannot find the database to load from #{@jsonObj["outputs"][0]}"
      raise "Could not complete executesearchAtlasSim because the output url was not defined."
    end

    @command = "searchAtlasSim.rb -i #{CGI.escape(@inputfname)} -t #{CGI.escape(@targetlist)} #{@roi} -n #{CGI.escape(@targettracklist)} -c #{@cfname} -s #{@step} -o #{@tempDir}#{@outputfile} -D #{@tempDir}"
    puts "Command: "
    puts @command
    return system(@command)
  end


  def executesearchAtlasSimUsingGenboreeROIScore()
    puts "running searchAtlasSim using Genboree ROI score track....."
    @cfname = getChromInfo(@jsonObj["inputs"][0])
    if @cfname == nil
      #puts "Error: cannot create chromosome information from #{@jsonObj["inputs"][0]}"
      raise "Could not download chromosome information from #{@jsonObj["inputs"][0]}."
    end

    @inputurl = @jsonObj["inputs"][0]
    @inputver = getChromVersion(@jsonObj["inputs"][0])
    @inputfname = getBedGraphFile(@jsonObj["inputs"][0], @jsonObj["inputs"][1])
    puts "inputfname : #{@inputfname}"
    if @inputfname == nil
      raise "Could not download required input data, #{@jsonObj["inputs"][0]}."
    end

    #unless hasAnnotaion?(@inputfname)
    #	trackname = getTrackName(@inputurl)
    #	description = "The SearchAtlasSim tool could not be performed because the '"+ trackname + "' track in is empty."
    #	sendFatalErrorEmail(description)
    #	compressTempFiles()
    #	raise "The SearchAtlasSim tool could not be performed because the '" + trackname + "' track is empty."
    #end

    @roiurl = @jsonObj["inputs"][1]
    @roiver = getChromVersion(@jsonObj["inputs"][1])
    unless @inputver == @roiver
      sendFailEmail()
      compressTempFiles()
      raise "Could not complete executesearchAtlasSimUsingGenboreeROIScore becauses the tracks come from are not compatible."
    end
    #@roifname = getLffTargetFile(@jsonObj["inputs"][1])
    #if @roifname == nil
    #	raise "Could not download required region of interest, #{@jsonObj["inputs"][1]}."
    #end
    @roi = "-r usingGenboreeROIScore"

    puts "tranfilelist : #{@jsonObj["settings"]["targetTrackListFile"].class}"
    targeturllist = getTargetUrlList(@jsonObj["settings"]["targetTrackListFile"])
    if targeturllist == nil
      raise "Could not download required target data, #{@jsonObj["settings"]["targetTrackListFile"]}."
    else
      turlptr = File.open(targeturllist,"r")
      tcount = 1
      turlptr.each {	|line|
        if(line =~ /\S/)
          cols = line.strip.split(/\t/)
          @targeturls.push(cols[1])
          # We will check the track versions IF the urls with all the atlas data are actual track URLs.
          # If just direct links to files or something, we won't bother checking, just assume same as the input track.
          if(cols[1] =~ %r{/trk/}) # then looks like a track url, check version
            @targetvers.push(getChromVersion(cols[1]))
            trackdescription = getTrackDescription(cols[1])
            @targettrackdescriptions.push(trackdescription)
            trackbrowserurl = getTrackBrowserUrl(cols[1])
            @targettrackbrowserurls.push(trackbrowserurl)
          else # not track url, assume direct url to a wig file (and that version is same as input)
            @targetvers.push(@inputver)
            @targettrackdescriptions.push("")
            @targettrackbrowserurls.push("")
          end

          tfname = getBedGraphFile(cols[1], @jsonObj["inputs"][1])
          if tfname == nil
            raise "Could not download required input data, #{@jsonObj["inputs"][i]}."
          end
          @targetfnames.push(tfname)
          #unless hasAnnotaion?(tfname)
          #	description = "The SearchAtlasSim tool could not be performed because the '"+ cols[0] + "' track in is empty."
          #	sendFatalErrorEmail(description)
          #	compressTempFiles()
          #	raise "The SearchAtlasSim tool could not be performed because the '" + cols[0] + "' track is empty."
          #end
          @targettracks.push(cols[0])
        end
        tcount += 1
        #break if tcount == 4  #testversion
      }
      turlptr.close()
    end

    @targetlist = @tempDir + @prefix + "targetfilenamelist.txt"
    targets = File.open(@targetlist,"w")
    targets.puts @targetfnames
    targets.close

    @targettracklist = @tempDir + @prefix + "targettracklist.txt"
    targettracks = File.open(@targettracklist,"w")
    #targettracks.puts @targettracks
    @targettracks.each_index {	|index|
      targettracks.puts "#{@targettracks[index]}\t#{@targetvers[index]}\t#{@targettrackdescriptions[index]}\t#{@targettrackbrowserurls[index]}"
    }
    targettracks.close

    #check genome versions for each input
    @targetvers.each {	|tver|
      unless tver == @inputver
        sendFailEmail()
        compressTempFiles()
        raise "Could not complete executesearchAtlasSimUsingGenboreeROIScore becauses databases the tracks come from are not compatible."
      end
    }

    @outputurl = @jsonObj["outputs"][0]
    if @outputurl == nil
      #puts "Error: cannot find the database to load from #{@jsonObj["outputs"][0]}"
      raise "Could not complete executesearchAtlasSimUsingGenboreeROIScore becauses the output url was not defined."
    end

    @command = "searchAtlasSim.rb -i #{CGI.escape(@inputfname)} -t #{CGI.escape(@targetlist)} #{@roi} -k true -n #{CGI.escape(@targettracklist)} -c #{@cfname} -s #{@step} -o #{@tempDir}#{@outputfile} -D #{@tempDir}"
    puts "Command: "
    puts @command
    return system(@command)
  end


  def parseURL(url)
    uriObj = URI.parse(url)
    host = uriObj.host
    puts "host : #{host}"
    path = uriObj.path
    puts "path : #{path}"
    query = uriObj.query
    if query != nil
      if query.size > 0
        query += "&"
      end
    end
    return host, path, query
  end

  def getChromInfo(url)
    host, path, query = parseURL(url)
    resource = path
    resource = resource.gsub(/trk\/\S+/, "eps?format=lff")
    puts "getChromInfo resouce : #{resource}"

    apiCaller = ApiCaller.new(host, resource, @apiUserName, @userPasswd)

    lines = ""
    httpResp = apiCaller.get(){ |buffer|
      lines += buffer
    }
    fname = @tempDir+@prefix+"chrom_size.txt"
    outfile = File.open(fname,"w")
    lines.each{	|line|
      cols = line.split("\t")
      #unless cols[0] =~ /_/ or cols[0] =~ /chrM/
        outfile.puts "#{cols[0]}\t#{cols[2]}"
      #end
    }
    outfile.close
    if apiCaller.succeeded?
      return File.expand_path(fname)
    else
      apiCaller.parseRespBody()
      $stderr.puts "API response; statusCode: #{apiCaller.apiStatusObj['statusCode']}, message: #{apiCaller.apiStatusObj['msg']}"
      return nil
    end
  end


  def getTargetUrlList(url)
    host, path, query = parseURL(url)
    resource = path
    puts "getTargetUrlList resouce : #{resource}"

    apiCaller = ApiCaller.new(host, resource, @apiUserName, @userPasswd)

    fname = @tempDir+@prefix+"targetUrlList.txt"
    outfile = File.open(fname,"w")

    httpResp = apiCaller.get(){	|line|
      outfile.print line
    }
    outfile.close
    if apiCaller.succeeded?
      return File.expand_path(fname)
    else
      apiCaller.parseRespBody()
      $stderr.puts "API response; statusCode: #{apiCaller.apiStatusObj['statusCode']}, message: #{apiCaller.apiStatusObj['msg']}"
      return nil
    end
  end


  def getChromVersion(url)
    host, path, query = parseURL(url)
    resource = path
    resource = resource.gsub(/trk\/\S+/,"version")
    puts "getChromVersion resouce : #{resource}"

    apiCaller = ApiCaller.new(host, resource, @apiUserName, @userPasswd)

    httpResp = apiCaller.get()
    apiCaller.parseRespBody()
    #version = apiCaller.apiDataObj["text"]
    if apiCaller.succeeded?
      version = apiCaller.apiDataObj["text"]
      return version
    else
      $stderr.puts "API response; statusCode: #{apiCaller.apiStatusObj['statusCode']}, message: #{apiCaller.apiStatusObj['msg']}"
      return nil
    end

  end

  def getWigFile(url)
    host, path, query = parseURL(url)
    if(url =~ %r{/trk/}) # then looks like a trk URL...build anno-download URL using that
      resource = path + "/annos?#{query}format=vwig&" + @resolution + "&spanAggFunction=avg"
      resource =~ %r{/trk/([^/]+)}
      trkName = $1.dup
      fname = "#{@tempDir}#{@prefix}#{Time.now().to_f}_#{rand(1000000)}.#{trkName}.wig"
    else # not a track url...assume URL to direct file download and use it directly without modification
      resource = path
      fname = "#{@tempDir}#{@prefix}#{Time.now().to_f}_#{rand(1000000)}.#{File.basename(resource)}"
    end
    puts "getWigFile resouce : #{resource}"

    apiCaller = ApiCaller.new(host, resource, @apiUserName, @userPasswd)

    outfile = File.open(fname, "w+")
    httpResp = apiCaller.get() { |chunk|
      outfile.print chunk
    }
    outfile.close

    if(apiCaller.succeeded?)
      # Do we need to uncompress the downloaded wig data file?
      uncompFile = uncompressFile(fname)
      return File.expand_path(uncompFile)
    else
      $stderr.puts "ERROR: API call failed. HttpResp: #{httpResp.inspect} ; (Code: #{httpResp.code.inspect if(httpResp)}, Message: #{httpResp.message.inspect if(httpResp)}. API response (may be a read adapter if failed in middle of a working call):\n#{apiCaller.respBody.inspect}"
      return nil
    end
  end

  # Note: assumes filePath uncompresses to filePath (if non-proper extension) or
  # to filePath MINUS THE STANDARD extension FOR THE COMPRESSION FORMAT.
  # - returns name of uncompressed file, as per that assumption
  def uncompressFile(filePath)
    retVal = nil
    # Extension
    filePath =~ /^(.+)(\.[^\.]+)$/
    compFile = filePath
    uncompFile = $1
    extension = $2
    # Do appropriate uncompressions (no tools require proper suffix for their TEST command, but some do for UNCOMPRESS command)
    if(system("gzip -t #{filePath}")) # gzip (must be BEFORE zip since gzip can handle zip files too, just not best option)
      compFile, uncomFile = fixCompFileName(filePath, '.gz')
      # Uncompress
      success = system("gunzip #{compFile}")
    elsif(system("bzip2 -t #{filePath}")) # bzip2
      compFile, uncomFile = fixCompFileName(filePath, '.bz2')
      # Uncompress
      success = system("bunzip2 #{compFile}")
    elsif(system("zip -tT #{filePath}")) # zip
      compFile, uncomFile = fixCompFileName(filePath, '.zip')
      # Uncompress
      success = system("unzip #{compFile}")
    else # assume uncompressed
      uncompFile = filePath
      success = true
    end
    # Return name of uncompressed file, according to assumption explained above
    retVal = (success ? uncompFile : nil)
    return retVal
  end

  def fixCompFileName(filePath, properExt)
    filePath =~ /^(.+)(\.[^\.]+)$/
    compFile = filePath
    uncompFile = $1
    extension = $2
    unless(extension == properExt)
      compFile = "#{filePath}#{properExt}"
      FileUtils.mv(filePath, compFile)
      uncompFile = filePath
    end
    return compFile, uncompFile
  end

  def getBedGraphFile(url, roiUrl)
    host, path, query = parseURL(url)
    resource = path + "/annos?format=bedGraph&spanAggFunction=avg&ROITrack={roi}&emptyScoreValue={esValue}"
    puts "getBedGraphFile resouce : #{resource}"
    puts roiUrl

    apiCaller = ApiCaller.new(host, resource, @apiUserName, @userPasswd)


    resource =~ %r{/trk/([^/]+)}
    trkName = $1.dup
    fname = "#{@tempDir}#{@prefix}#{Time.now().to_f}_#{rand(1000000)}.#{trkName}.bed"
    outfile = File.open(fname,"w")

    roiUrl = roiUrl.chomp("?")
    httpResp = apiCaller.get( { :roi => roiUrl, :esValue => "0.0" } ){	|line|
      outfile.print line
    }
    outfile.close
    if(apiCaller.succeeded?)
      return File.expand_path(fname)
    else
      $stderr.puts "ERROR: API call failed. API response:\n#{apiCaller.respBody.inspect}"
      return nil
    end
  end


  def getLffTargetFile(url)
    host, path, query = parseURL(url)
    resource = path+"/annos?format=lff"
    puts "getLffTargetFile resouce : #{resource}"

    apiCaller = ApiCaller.new(host, resource, @apiUserName, @userPasswd)

    fname = @tempDir+Time.now().to_f.round.to_s + '_' + rand(1000000).to_s.rjust(6, '0') +".lff"
    outfile = File.open(fname,"w")

    httpResp = apiCaller.get() { |chunk|
      outfile.print chunk
    }
    outfile.close

    new_fname = @tempDir+@prefix+Time.now().to_f.round.to_s + '_' + rand(1000000).to_s.rjust(6, '0') +".lff"
    puts "New fname : #{new_fname}"
    system("sort -t $'\t' -k 5,5 -k 6,6n #{fname} > #{new_fname}")
    system("rm #{fname}")

    if(apiCaller.succeeded?)
      return File.expand_path(new_fname)
    else
      $stderr.puts "API ERROR: API response (in getLffTargetFile()):\n#{apiCaller.respBody.inspect}"
      return nil
    end
  end


  def getTrackDescription(url)
    host, path, query = parseURL(url)
    resource = path + "/description";
    puts "trackDescription resource : #{resource}"

    apiCaller = ApiCaller.new(host, resource, @apiUserName, @userPasswd)

    httpResp = apiCaller.get()

    if(apiCaller.succeeded?)
      apiCaller.parseRespBody()
      description = apiCaller.apiDataObj['text']
      description = "[Not Available]" if(description == nil or description == "")
    else
      # Perhaps no description set and got back a Not Found or similar
      description = "[Not Available]"
      # But log it just in case it's wrong
      $stderr.puts "API ERROR (?): API response (in getTrackDescription()):\nHttp Resp: #{httpResp.inspect}\nResp Body:\n#{apiCaller.respBody.inspect}"
    end
    return description
  end


  def getTrackBrowserUrl(url)
	host, path, query = parseURL(url)
	browserurl  = "http://#{host}/java-bin/gbrowser.jsp?groupName=#{CGI.escape(getGroupName(url))}&dbName=#{CGI.escape(getDBName(url))}&entryPointId=chr1&from=80000000&to=150000000\n"
	return browserurl
  end


  def isOutputForDatabase?()
	host, path, query = parseURL(@outputurl)
	if path =~ /\/REST\/v1\/grp\/\S+\/db\/\S+/
		return true
    else
		return false
	end
  end


  def putResultFile()
	host, path, query = parseURL(@outputurl)
	#resource = path+"/file/{signalSimilarity/#{CGI.escape(@experimentName)}/results.txt/data"
	resultfile = (@targetfnames.length < 65536) ? "results.xls" : "results.txt"
	resource = isOutputForDatabase?() ? (path+"/file/{dir1}/{dir2}/#{resultfile}/data") : (path+"/file/#{resultfile}/data")

	puts "putResultFile resouce : #{resource}"
	apiCaller = ApiCaller.new(
				host,
				resource,
				@apiUserName,
				@userPasswd)

	fname = (@targetfnames.length < 65536) ?  (@tempDir+@outputfile.gsub(".txt",".xls")) : (@tempDir+@outputfile)
	result = File.open(fname,"r")

	httpResp = isOutputForDatabase?() ? apiCaller.put({:dir1 => "Atlas Search Results", :dir2 => "#{@experimentName}"},result) : apiCaller.put(result)

	if apiCaller.succeeded?
		#apiCaller.parseRespBody()
		result.close()
		return File.expand_path(fname)
	else
		result.close()
		apiCaller.parseRespBody()
		$stderr.puts "API response; statusCode: #{apiCaller.apiStatusObj['statusCode']}, message: #{apiCaller.apiStatusObj['msg']}"
		return nil
	end
  end


  def putResultSummaryFile(summary)
	host, path, query = parseURL(@outputurl)
	#resource = path+"/file/{signalSimilarity/#{CGI.escape(@experimentName)}/results.txt/data"
	resultfile = "resultSummary.txt"
	resource = isOutputForDatabase?() ? (path+"/file/{dir1}/{dir2}/#{resultfile}/data") : (path+"/file/#{resultfile}/data")

	puts "putResultFile resouce : #{resource}"
	apiCaller = ApiCaller.new(
				host,
				resource,
				@apiUserName,
				@userPasswd)

	fname = @tempDir+@prefix+resultfile
	result = File.open(fname,"w")

	result.puts "Job Summary:\n"
	result.puts "    JobID: #{@jobid}\n"
	result.puts "    Input Track: "+getTrackName(@inputurl)+"\n"
	result.puts "    Region of Interest: "+getTrackName(@roiurl)+"\n" unless @roiurl == nil
	result.puts "\n"
	result.puts "Result Summary:\n"
	result.puts summary
	result.close()

	result = File.open(fname,"r")

	httpResp = isOutputForDatabase?() ? apiCaller.put({:dir1 => "Atlas Search Results", :dir2 => "#{@experimentName}"},result) : apiCaller.put(result)
	if apiCaller.succeeded?
		#puts  apiCaller.respBody()
		result.close()
		return File.expand_path(fname)
	else
		result.close()
		apiCaller.parseRespBody()
		$stderr.puts "API response; statusCode: #{apiCaller.apiStatusObj['statusCode']}, message: #{apiCaller.apiStatusObj['msg']}"
		return nil
	end
  end


  def readFileContent(fname)
    content = ""
    path = @tempDir+fname

    if File.exist?(path)
      infile = File.open(path,"r")
      infile.each{	|line|
        content += line
      }
      return content
    else
      return nil
    end
  end


  def hasAnnotaion?(fname)
    buffer = 256
    f = File.new(fname)
    header = f.read(buffer)
    (header =~ /(^variableStep\s+chrom=\S+(\s+span=\d+\n|\n)(\d+)\s+(\d+\.\d+|\d+))/) ? (return true) : (return false)
  end


  def getCommand()
    return @command
  end


  def getUserName()
    return "#{@userFirstName} #{@userLastName}"
  end


  def getTrackName(url)
	host, path, query = parseURL(url)
	path =~ /\/REST\/v1\/grp\/\S+\/db\/\S+\/trk\/(\S+)/
	return CGI.unescape($1)
  end


  def getGroupName(url)
	host, path, query = parseURL(url)
	path =~ /\/REST\/v1\/grp\/(\S+)\/db\/\S+\/trk\/\S+/
	puts "arg : #{$1}"
	return CGI.unescape($1)
  end


  def getDBName(url)
	host, path, query = parseURL(url)
	path =~ /\/REST\/v1\/grp\/\S+\/db\/(\S+)\/trk\/\S+/
	return CGI.unescape($1)
  end


  def getOutputGroupName()
	if @outputurl == nil
		return "None"
	else
		host, path, query = parseURL(@outputurl)
		path =~ /\/REST\/v1\/grp\/(\S+)\/(db|prj)/
		return CGI.unescape($1)
	end
  end

  def getOutputDBName()
	if @outputurl == nil
		return "None"
	else
		host, path, query = parseURL(@outputurl)
		path =~ /\/REST\/v1\/grp\/\S+\/db\/(\S+)/
		return CGI.unescape($1)
	end
  end


  def getOutputProjectName()
	if @outputurl == nil
		return "None"
	else
		host, path, query = parseURL(@outputurl)
		path =~ /\/REST\/v1\/grp\/\S+\/prj\/(\S+)/
		return CGI.unescape($1)
	end
  end


  def getOutputHostName()
 	if @outputurl == nil
		return "None"
	else
		host, path, query = parseURL(@outputurl)
		return host
	end
  end


  def getExperimentName()
	puts ">expname: #{CGI.unescape(@jsonObj["settings"]["experimentName"])}"
	return "#{CGI.unescape(@jsonObj["settings"]["experimentName"])}"
  end


  def sendSuccessEmail(summary)

	subjectTxt = "Genboree: your searchAtlasSim completed successfully."
	bodyTxt = "Hello "+getUserName()+","
	bodyTxt += "\n\n"
	bodyTxt += "Your searchAtlasSim tool run has completed successfully.\n"
	#bodyTxt += "The output data has been scheduled for upload into your database.\n"
	bodyTxt += "\n"
	bodyTxt += "Job Summary:\n"
	bodyTxt += "    JobID: #{@jobid}\n"
	bodyTxt += "    Input Track: "+getTrackName(@inputurl)+"\n"
	bodyTxt += "    Region of Interest: "+getTrackName(@roiurl)+"\n" unless @roiurl == nil
	#tcount = 1
	#@targeturls.each{	|turl|
	#	target = "Target#{tcount}"
	#	trackname = getTrackName(turl)
	#	bodyTxt += "\t#{target}: #{trackname}\n"
	#	tcount += 1
	#}
	bodyTxt += "    The number of targets : #{@targeturls.length}\n"
	bodyTxt += "    This analysis used GenboreeRoiScores\n" if @useGenboreeRoiScores
	bodyTxt += "\n"
	bodyTxt += "Result Summary:\n"
	bodyTxt += "The top 10 target track matches:\n"
	bodyTxt += "    Track Name\tPearson correlation\n"
	bodyTxt += summary
	bodyTxt += "....\n"
	bodyTxt += "\n"
	bodyTxt += "\n"
	bodyTxt += "Result File Location(s):\n"
	bodyTxt += "(Direct links to files are at the end of this email)\n"
	bodyTxt += "    Group: "+getOutputGroupName()+"\n"
	if isOutputForDatabase?()
		bodyTxt += "    Database: "+getOutputDBName()+"\n"
		bodyTxt += "    Path to File:\n"
		bodyTxt += "     Files\n"
		bodyTxt += "     * Atlas Search Results\n"
		bodyTxt += "      * #{getExperimentName()}\n"
		bodyTxt += "       * results.xls\n"
		bodyTxt += "       * resultSummary.txt\n"
		bodyTxt += "\n"
		bodyTxt += "\n"
		bodyTxt += "The Genboree Team\n"
		bodyTxt += "\n\n"
		bodyTxt += "Result File URLs:\n"
		host, path, query = parseURL(@outputurl)
		bodyTxt += "    FILE: results.xls\n"
		rsrcPathToFileData = path+"/file/#{CGI.escape("Atlas Search Results")}/#{CGI.escape(@experimentName)}/results.xls/data"
		bodyTxt += "    URL:\n\n"
		bodyTxt += "    http://#{getOutputHostName()}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape(rsrcPathToFileData)}"
		bodyTxt += "\n\n"
		bodyTxt += "    FILE: resultSummary.txt\n"
		rsrcPathToFileData = path+"/file/#{CGI.escape("Atlas Search Results")}/#{CGI.escape(@experimentName)}/resultSummary.txt/data"
		bodyTxt += "    URL:\n\n"
		bodyTxt += "    http://#{getOutputHostName()}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape(rsrcPathToFileData)}"

	else
		bodyTxt += "    Project: "+getOutputProjectName()+"\n"
		bodyTxt += "    Path to File:\n"
		#bodyTxt += "    Projects\n"
		bodyTxt += "      * results.xls\n"
		bodyTxt += "      * resultSummary.txt\n"
		bodyTxt += "\n"
		bodyTxt += "\n"
		bodyTxt += "The Genboree Team\n"
		bodyTxt += "\n\n"
		bodyTxt += "Result File URLs:\n"
		host, path, query = parseURL(@outputurl)
		bodyTxt += "    FILE: result.xls\n"
		rsrcPathToFileData = path+"/file/results.xls/data"
		bodyTxt += "    URL:\n\n"
		bodyTxt += "    http://#{getOutputHostName()}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape(rsrcPathToFileData)}"
		bodyTxt += "\n\n"
		bodyTxt += "    FILE: resultSummary.txt\n"
		rsrcPathToFileData = path+"/file/resultSummary.txt/data"
		bodyTxt += "    URL:\n\n"
		bodyTxt += "    http://#{getOutputHostName()}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{CGI.escape(rsrcPathToFileData)}"

	end

	sendEmail(subjectTxt,bodyTxt)

  end


  def sendFailEmail()

	subjectTxt = "Genboree: your searchAtlasSim failed."
	bodyTxt = "Hello "+getUserName()+","
	bodyTxt += "\n\n"
	bodyTxt += "Unfortunately, we cannot run the searchAtlasSim tool on the tracks you provided.\n"
	bodyTxt += "\n"
	bodyTxt += "The databases the tracks come from are not compatible.The input\n"
	bodyTxt += "and target data must all be for the same species and the same assembly of that species' genome.\n"
	bodyTxt += "\n"
	bodyTxt += "Job Summary:\n"
	bodyTxt += "    JobID: #{@jobid}\n"
	bodyTxt += "    Input Track: "+getTrackName(@inputurl)+" (genome version: #{@inputver})\n"
	bodyTxt += "    Region of Interest: "+getTrackName(@roiurl)+" (genome version: #{@roiver})\n" unless @roiurl == nil
	#tcount = 1
	#@targeturls.each{	|turl|
	#	bodyTxt += "\tTarget#{tcount}: "+getTrackName(turl)+" (genome version: #{@targetvers[tcount-1]})\n"
	#	tcount += 1
	#}
	bodyTxt += "    The number of targets : #{@targeturls.length}"
	bodyTxt += "\n"
	bodyTxt += "If you can address this problem, we encourage you to rerun the tool.\n"
	bodyTxt += "\n"
	bodyTxt += "Regards,\n"
	bodyTxt += "The Genboree Team\n"
	sendEmail(subjectTxt,bodyTxt)

  end


  def sendFatalErrorEmail(descriptoin)
    subjectTxt = "Genboree: your searchAtlasSim failed"
    bodyTxt = "Hello "+getUserName()+","
    bodyTxt += "\n\n"
    bodyTxt += "Unfortunately, we encountered a fatal problem when trying to run your searchAtlasSim job.\n"
    bodyTxt += "\n"
    bodyTxt += "Job Summary:\n"
    bodyTxt += "\tJobID: #{@jobid}\n"
    bodyTxt += "\n"
    bodyTxt += "Error Summary:\n"
    bodyTxt += "\tError description: #{descriptoin}\n"
    bodyTxt += "\n"
    bodyTxt += "To help resolve this problem, please contact a Genboree Administrator\n"
    bodyTxt += "(genbadmin_admin@genboree.org) with the job and error summaries.\n"
    bodyTxt += "\n"
    bodyTxt += "Regards,\n"
    bodyTxt += "The Genboree Team\n"
    sendEmail(subjectTxt,bodyTxt)
  end


  def sendEmail(subjectTxt, bodyTxt)
    puts "=====email Station===="
    puts @gbAdminEmail
    puts @userEmail

    email = BRL::Util::Emailer.new()
    email.setHeaders(@gbAdminEmail, @userEmail, subjectTxt)
    email.setMailFrom('andrewj@bcm.edu')
    email.addRecipient(@userEmail)
    email.addRecipient(@gbAdminEmail)
    email.setBody(bodyTxt)
    email.send()

    puts "Subj:"
    puts subjectTxt
    puts "Body:"
    puts bodyTxt
  end


  def compressTempFiles()
    Dir.chdir(@tempDir)
    files = Dir.glob("#{@prefix}*")
    files.each{	|f|
      if File.directory?(f)
        system("tar -zcvf #{f}.tar.gz #{f}")
        system("rm -r #{f}")
      else
        system("gzip #{f}")
      end
    }
  end

  def deleteTempDir()
    FileUtils.rm_rf(@tempDir)
  end

  def WrapperSearchAtlasSim.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[
						[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
						[ '--noPermCheck', '-n', GetoptLong::NO_ARGUMENT ],
						[ '--jsonFile', '-j', GetoptLong::REQUIRED_ARGUMENT ]
					]
		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		WrapperSearchAtlasSim.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			WrappersearchAtlasSim.usage("USAGE ERROR: some required arguments are missing")
		end

		#WrappersearchAtlasSim.usage() if(optsHash.empty?);
		return optsHash
  end

  def WrapperSearchAtlasSim.usage(msg='')
		unless(msg.empty?)
			puts "\n#{msg}\n"
		end
		puts "
     == Synopsis

     wrapperSearchSignmalSim.rb: executes searchAtlasSim_.rb with parameters in a JSON file

     == Usage

     wrappersearchAtlasSim_1.0.rb OPTION

     -h, --help:
        shows help

     --jsonFile, -j json_File
        describes arguments for searchAtlasSim.rb
     --noPermCheck
        describes no permission check
    "
    exit(2);
  end
end # end of class WrapperSearchAtlasSim


def sendEmail(subjectTxt, bodyTxt)
  puts "=====Init Error Email Station===="
  gbAdminEmail = "genboree_admin@genboree.org"
  email = BRL::Util::Emailer.new()
  email.setHeaders(gbAdminEmail, userEmail, subjectTxt)
  email.setMailFrom('andrewj@bcm.edu')
  email.addRecipient(gbAdminEmail)
  email.setBody(bodyTxt)
  email.send()

  puts "Subj:"
  puts subjectTxt
  puts "Body:"
  puts bodyTxt
end



# Process command line options
optsHash = WrapperSearchAtlasSim.processArguments()

beginning = Time.now
puts "Wrapper Begin : #{beginning}"

begin
	# Instantiate analyzer using the program arguments
	wrapperSASim = WrapperSearchAtlasSim.new(optsHash)
	# Submit this !
	wrapperSASim.submitJob()
rescue Exception => err
	$stderr.puts err.message()
	$stderr.puts err.backtrace.join("\n")
  subjectTxt = "Genboree: searchAtlasSim Iinitializtion failed"
	description = "Unexpected Error at #{err.backtrace.join("\n")}"
	sendEmail(subjectTxt, description)
end

puts "Now : #{Time.now}"
puts "Wrapper Time elapsed #{Time.now - beginning} seconds"
