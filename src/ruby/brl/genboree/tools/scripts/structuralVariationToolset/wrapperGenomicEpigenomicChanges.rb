#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'fileutils'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/rest/helpers/databaseApiUriHelper'
require 'brl/genboree/rest/helpers/trackApiUriHelper'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/toolConf'

include BRL::Genboree::REST

class SVReport

  ##Intitialization of data
  def initialize(optsHash)
    @inputJson    = File.expand_path(optsHash['--jsonFile'])
    jsonObj       = JSON.parse(File.read(@inputJson))

    @input        = jsonObj["inputs"]
    @outputArray  = jsonObj["outputs"]
    @output       = jsonObj["outputs"][0]

    @gbConfFile   = jsonObj["context"]["gbConfFile"]
    @apiDBRCkey   = jsonObj["context"]["apiDbrcKey"]
    @scratch      = jsonObj["context"]["scratchDir"]
    @email        = jsonObj["context"]["userEmail"]
    @user_first   = jsonObj["context"]["userFirstName"]
    @user_last    = jsonObj["context"]["userLastName"]
    @username     = jsonObj["context"]["userLogin"]

    @toolIdStr = jsonObj['context']['toolIdStr']
    @genbConf = BRL::Genboree::GenboreeConfig.load(ENV['GENB_CONFIG'])
    @toolConf = BRL::Genboree::Tools::ToolConf.new(@toolIdStr, @genbConf)
    @toolTitle = @toolConf.getSetting('ui', 'label')

    @gbAdminEmail = jsonObj["context"]["gbAdminEmail"]
    @jobID        = jsonObj["context"]["jobId"]
    @userId       = jsonObj["context"]["userId"]

    @radius         = jsonObj["settings"]["radius"]
    @analysisName   = jsonObj["settings"]["analysisName"]
    @uploadLffFile  = jsonObj["settings"]["uploadLff"]
    @resolution     = jsonObj["settings"]["resolution"].to_i
    @span           = jsonObj["settings"]["span"]
    @zScore         = jsonObj["settings"]["zScore"].to_f
    @normalization  = jsonObj["settings"]["normalization"]


    @fileNameBuffer = []

    @cgiAnalysisName  = CGI.escape(@analysisName)
    @filAnalysisName  = @cgiAnalysisName.gsub(/%[0-9a-f]{2,2}/i, "_")

    @grph       = BRL::Genboree::REST::Helpers::GroupApiUriHelper.new(@gbConfFile)
    @dbhelper   = BRL::Genboree::REST::Helpers::DatabaseApiUriHelper.new(@gbConfFile)
    @trackhelper= BRL::Genboree::REST::Helpers::TrackApiUriHelper.new(@gbConfFile)

    ##pulling out upload location specifications
    @output     = @output.chomp('?')
    @dbOutput   = @dbhelper.extractName(@output)
    @grpOutput  = @grph.extractName(@output)
    uriOutput   = URI.parse(@output)
    @hostOutput = uriOutput.host
    @pathOutput = uriOutput.path

    @uri        = @grph.extractPureUri(@output)
    dbrc        = BRL::DB::DBRC.new(nil, @apiDBRCkey)
    @pass       = dbrc.password
    @user       = dbrc.user
    @uri        = URI.parse(@input[0])
    @host       = @uri.host
    @exitCode   = ""
    @success    = false
    ##Converting all the BAM files to SAM. Driver is not capable of dealing multi-format files.

    dbVersion()
    puts @genome
    @targetGenomicFile = "/cluster.shared/data/groups/brl/fasta/#{@genome}/#{@genome}.wholeGene.lff"
    @tgpFileLocation = "/cluster.shared/data/groups/brl/fasta/#{@genome}/#{@genome}.1000genomes.sv.lff"
    @localTrkLocation = ""
  end

  ##searching for two tracks from the input
  def searchTracks()
    trk_reg_exp = %r{^http://[^/]+/REST/v1/grp/[^/]+/db/[^/]+/trk/([^/\?]+)}
    @tracks = []
    @svDirectories = []
    ii = 0
    jj = 0
    @input.each { |file|
      if(file =~ trk_reg_exp)
        @tracks[ii] = file
        ii += 1
        if( ii == 3)
          rasie " More than two wigs"
          break
        end
      else
        @svDirectories[jj] = file
        jj += 1
      end
      }

  end

  ##Check output dbversion, to look for correct tgp File Location
  def dbVersion()

    uri         = URI.parse(@output)
    host        = uri.host
    path        = uri.path
    apicaller   = WrapperApiCaller.new(host,"",@userId)
    path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
    apicaller.setRsrcPath(path)
    httpResp    = apicaller.get
    temp        = apicaller.parseRespBody()
    @genome     = temp["data"]["version"]
    @genome     = "hg18"
  end

  ##Main to call all other functions
  def main()
    begin
      system("mkdir -p #{@scratch}")
      Dir.chdir(@scratch)
      @outputDir = "#{@scratch}/signal-search/#{@filAnalysisName}"
      system("mkdir -p #{@outputDir}")
      searchTracks()
      @tracks.each {|track|
        track.chomp!('?')
        $stdout.puts "downloading #{track}"
        @gbKey = ( @dbhelper.extractGbKey(track) ? @dbhelper.extractGbKey(track) : nil )
        db          = @dbhelper.extractName(track)
        grp         = @grph.extractName(track)
        uri         = URI.parse(track)
        host        = uri.host
        pathOutput  = uri.path
        trk         = pathOutput.split(/\/trk\//)[1]
        wigDownload(host, grp, db, trk, @resolution, @span)
        @localTrkLocation << "#{CGI.escape(File.basename(track))},"
      }
      @localTrkLocation.chomp!(",")
      downloadData()
      callTool()
      processLinks()
      uploadData()
      sendSuccessEmail()
    rescue => err
      $stderr.puts err.backtrace.join("\n")
      sendFailureEmail(err)
    end
  end


  ##Download two tracks in wig format
  def wigDownload(host, grp, db, trk, resolution, span)
    apicaller = WrapperApiCaller.new(host,"",@userId)
    ##Downloading offset file to get the length of each chromosome
    chrHash = {}
    restPath1 = "/REST/v1/grp/{grp}/db/{db}/eps"
    restPath1 << "?gbKey=#{@gbKey}" if(@gbKey)
    apicaller.setRsrcPath(restPath1)
    apicaller.get(
                    {
                      :grp => CGI.unescape(grp),
		      :db  => CGI.unescape(db)
		    }
		  )
    if apicaller.succeeded?
      $stdout.puts "successfully downloaded EPS file"
    else
      $stderr.puts apicaller.respBody()
      $stderr.puts apicaller.parseRespBody().inspect
      $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
      @exitCode = apicaller.apiStatusObj['statusCode']
      $stderr.puts "#{apicaller.apiStatusObj['msg']}"
    end
    eps =  apicaller.parseRespBody()

    for it in 0...eps["data"]["entrypoints"].size
      chrHash[eps["data"]["entrypoints"][it]["name"]] = eps['data']['entrypoints'][it]['length']
    end

    path = "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/annos?format=vwig&span={resolution}&spanAggFunction={span}&emptyScoreValue={esValue}"
    path << "&gbKey=#{@gbKey}" if(@gbKey)
    apicaller.setRsrcPath(path)
    @buff = ''
    saveFile = File.open("#{@outputDir}/#{trk}","w+")
    saveFile2 = File.open("#{@outputDir}/#{trk}.wig","w+")
    @startPoint = 0
    @endPoint = 0
    @chr = ""
    ##Downloading wig files
    httpResp = apicaller.get(
                              {
                                :grp      => CGI.unescape(grp),
                                :db       => CGI.unescape(db),
                                :trk      => CGI.unescape(trk),
                                :span     => span,
                                :resolution => resolution.to_i,
                                :esValue  => "4290772992"
                              }
                            ){|chunck|
                                fullChunk = "#{@buff}#{chunck}"
                                @buff = ''

                                fullChunk.each_line { |line|
                                  if(line[-1].ord == 10)
                                    saveFile2.write line
                                    if(line =~ /variable/)
                                      @startPoint = 0
                                      @chr  =line.split(/chrom=/)[1].split(/span/)[0].strip!
                                    end
                                    unless(line=~/track/ or line =~/variable/)
                                      columns = line.split(/\s/)
                                      score = columns[1]
                                      @endPoint = columns[0].to_i + @resolution
                                      if(@endPoint > chrHash[@chr])
                                        @endPoint = chrHash[@chr]
                                      end
                                      saveFile.write("#{@lffClass}\t#{@chr}:#{@startPoint}-#{@endPoint}\t#{@lffType}\t#{@lffSubType}\t#{@chr}\t#{@startPoint}\t#{@endPoint}\t+\t0\t#{score}\n")
                                      @startPoint = @endPoint
                                    end
                                  else
                                    @buff += line
                                  end
                                  }
                                }
    saveFile.close
    saveFile2.close
    if apicaller.succeeded?
      $stdout.puts "successfully downloaded #{trk} wig file"
    else
      $stderr.puts apicaller.respBody()
      $stderr.puts apicaller.parseRespBody().inspect
      $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
      @exitCode = apicaller.apiStatusObj['statusCode']
      $stderr.puts "#{apicaller.apiStatusObj['msg']}"
    end
  end


  ##Download all the SAM/BAM files
  def downloadData()
    begin
    ii = 0
    @localFileLocation = ""
    @svDirectories.each {|file|
      file  = file.chomp('?')
      saveFile    = File.open("#{@outputDir}/#{File.basename(file)}.sv.lff","w+")
      $stdout.puts "Downloading #{File.basename(file)} file:"
      @db         = @dbhelper.extractName(file)
      @grp        = @grph.extractName(file)
      uri         = URI.parse(file)
      host        = uri.host
      path        = uri.path
      path        = path.gsub(/\/files\//,'/file/')
      apicaller   = WrapperApiCaller.new(host,"",@userId)
      pathR       = "#{path}/#{File.basename(file)}.sv.lff/data?"
      pathR << "gbKey=#{@dbhelper.extractGbKey(file)}" if(@dbhelper.extractGbKey(file))

      $stdout.puts pathR
      apicaller.setRsrcPath(pathR)
      httpResp    = apicaller.get(){|chunk|
        saveFile.print chunk
      }

      if apicaller.succeeded?
        $stdout.puts "Successfully downloaded #{file} "
      else
        $stderr.puts apicaller.parseRespBody()
        $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
        @exitCode = apicaller.apiStatusObj['statusCode']
        raise "#{apicaller.apiStatusObj['msg']}"
      end
      @localFileLocation << "#{@outputDir}/#{File.basename(file)}.sv.lff,"
      ii += 1
      saveFile.close
    }
    @localFileLocation.chomp!(",")
    rescue => err
      $stderr.puts err.backtrace.join("\n")
      raise "Error"
    end
  end


  ##Calling main driver tool
  def callTool()
    cmd = "driverGenomicEpigenomicChange.rb -s #{@scratch} -t '#{@localTrkLocation}' "
    cmd <<" -a #{@filAnalysisName} -r #{@resolution} -R #{@radius} -l l -L L -S -a intersection -o #{@outputDir}/#{@filAnalysisName}.report "
    cmd <<" > #{@outputDir}/svReport.log 2>#{@outputDir}/svReport.error.log"
    $stdout.puts cmd
    system(cmd)
    if(!$?.success?)
      @exitCode = $?.exitstatus
      raise "driverSVReport.rb didn't work"
    end
  end

  ##Building links in project area
  def processLinks()
    cmd = "importAndBuildGenes.rb -i #{@outputDir} -j #{@scratch}/jobFile.json >  #{@outputDir}/projectLink.log 2> #{@outputDir}/projectLink.error.log"
    $stdout.puts cmd
    system(cmd)
  end

  #Upload generated data to specifed database in geboree
  def uploadUsingAPI(studyName,fileName,filePath)
    restPath = @pathOutput
    path     = restPath +"/file/#{CGI.escape("Structural Variation")}/#{CGI.escape("Genomic Epigenomic Change")}/#{studyName}/#{fileName}/data"
    path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
    @apicaller.setRsrcPath(path)
    infile   = File.open("#{filePath}","r")
    @apicaller.put(infile)
    if @apicaller.succeeded?
      $stdout.puts "Successfully uploaded #{fileName} "
    else
      $stderr.puts @apicaller.parseRespBody()
      $stderr.puts "API response; statusCode: #{@apicaller.apiStatusObj['statusCode']}, message: #{@apicaller.apiStatusObj['msg']}"
      @exitCode = @apicaller.apiStatusObj['statusCode']
      raise "#{@apicaller.apiStatusObj['msg']}"
    end
    uploadedPath = restPath+"/file/#{CGI.escape("Structural Variation")}/#{CGI.escape("Genomic Epigenomic Change")}/#{studyName}/#{fileName}"
    @apiRSCRpath = CGI.escape(uploadedPath)
  end

 ##Upload geneList
 def uploadData()
      @apicaller = WrapperApiCaller.new(@hostOutput,"",@userId)
      restPath = @pathOutput
      @success = false
      uploadUsingAPI(@cgiAnalysisName, "geneList.txt","#{@outputDir}/#{@filAnalysisName}")
      @success = true
  end



  def sendFailureEmail(errMsg)
    body =
        "
        Hello #{@user_first.capitalize} #{@user_last.capitalize}

        Your #{@toolTitle} job was unsuccessful.

        Job Summary:
        JobID                  : #{@jobID}
        Analysis Name          : #{@analysisName}


        Error Message : #{errMsg}
        Exit Status   : #{@exitCode}
        Please Contact the Genboree team with above information.

        The Genboree Team"

        subject = "Genboree: Your #{@toolTitle} job was unsuccessful"
      if (!@email.nil?) then
        sendEmail(subject,body)
      end

       ##Deleting file from workbech created by UI
         apicaller = WrapperApiCaller.new(@hostOutput,"",@userId)
         restPath = @pathOutput
         path = restPath +"/file/#{CGI.escape("Structural Variation")}/#{CGI.escape("Genomic Epigenomic Change")}/#{@cgiAnalysisName}/jobFile.json"
         path << "?gbKey=#{@dbhelper.extractGbKey(@output)}" if(@dbhelper.extractGbKey(@output))
         apicaller.setRsrcPath(path)
         apicaller.delete()
         $stdout.puts apicaller.parseRespBody()
  end


  def sendSuccessEmail
      body =
      "
Hello #{@user_first.capitalize} #{@user_last.capitalize}

Your #{@toolTitle} job is complete successfully.

Job Summary:
  JobID                  : #{@jobID}
  Analysis Name          : #{@analysisName}

Result File Location in the Genboree Workbench:
    Group : #{@grpOutput}
    DataBase : #{@dbOutput}
    Path to File:
    Files
    * Structural Variation
      * GenomicEpigenomicChange
        * #{@analysisName}

The Genboree Team

Result File URLs (click or paste in browser to access file):
  FILE: geneList.txt
  URL:
  http://#{@hostOutput}/java-bin/apiCaller.jsp?fileDownload=true&promptForLogin=true&rsrcPath=#{@apiRSCRpath}/data

            "
      subject = "Genboree: Your #{@toolTitle} job is complete "
      if (!@email.nil?) then sendEmail(subject,body) end
  end

  ##Email
  def sendEmail(subjectTxt, bodyTxt)

    email = BRL::Util::Emailer.new()
    email.setHeaders("genboree_admin@genboree.org", @email, subjectTxt)
    email.setMailFrom('genboree_admin@genboree.org')
    email.addRecipient(@email)
    email.addRecipient("genboree_admin@genboree.org")
    email.setBody(bodyTxt)
    email.send()
  end

  def SVReport.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

    PROGRAM DESCRIPTION:
    driverInsertSizeCollect wrapper for Cancer workbench
    COMMAND LINE ARGUMENTS:
    --file         | -j => Input json file
    --help         | -h => [Optional flag]. Print help info and exit.

    usage:

    ruby wrapperInsertSizeCollect.rb -f jsonFile
    ";
    exit;
  end #

  # Process Arguments form the command line input
  def SVReport.processArguments()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ ['--jsonFile' ,'-j', GetoptLong::REQUIRED_ARGUMENT],
                  ['--help'     ,'-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    SVReport.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash

    SVReport.usage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end
end

begin
optsHash = SVReport.processArguments()
SVReport = SVReport.new(optsHash)
SVReport.main()
    rescue => err
      $stderr.puts "Details: #{err.message}"
      $stderr.puts err.backtrace.join("\n")
     #SVReport.sendFailureEmail(err.message)
end
