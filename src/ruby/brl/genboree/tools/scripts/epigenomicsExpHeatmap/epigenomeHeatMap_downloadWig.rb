#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/wrapperApiCaller'
require 'brl/normalize/index_sort'

include GSL
include BRL::Genboree::REST

class SignalSimilarity
  def initialize(optsHash)
    @db             = optsHash['--db']
    @grp            = optsHash['--grp']
    @wgrp           = optsHash['--wgrp']
    @wdb            = optsHash['--wdb']
    @wTrack         = optsHash['--wTrack']
    @rTrack         = optsHash['--rTrack']
    @host           = optsHash['--host']
    @user           = optsHash['--user']
    @pass           = optsHash['--pwd']
    @resolution     = optsHash['--resolution'].to_i
    @spanAggFunction = optsHash['--spanAggFunction']
    @userId          = optsHash['--userId']
    @output          = File.expand_path(optsHash['--output'])
    system("mkdir -p #{@output}")
  end

  def withROI
    ##MADE CHANGES FOR DIRECT SCRIPTING FOR ALEX STUFF
    # TODO: why is genboree.org being hardcoded?? This needs to be fixed.
    apicaller = WrapperApiCaller.new("genboree.org", "", @userId)
    begin
      wTrack = "http://www.genboree.org/REST/v1/grp/#{CGI.escape(@wgrp)}/db/#{CGI.escape(@wdb)}/trk/#{CGI.escape(@wTrack)}"
      path = "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/annos?format=lff&scoreTrack={scrTrack}&spanAggFunction={span}&emptyScoreValue={esValue}"
      #path = "/REST/v1/grp/#{@grp}/db/#{@db}/trk/#{@rTrack}/annos?format=lff&scoreTrack={scrTrack}&spanAggFunction={span}&emptyScoreValue={esValue}"
      apicaller.setRsrcPath(path)
      @buff = ''
      system("mkdir -p #{@output}")
      $stderr.debugPuts(__FILE__, __method__, "STATUS", "Template path: #{path.inspect} ; FILLED apiCaller rsrcPath: " +
        apicaller.fillApiUriTemplate({:grp => @grp, :db => @db, :trk => @rTrack, :scrTrack => wTrack, :esValue => "NaN", :format => "lff", :span => @spanAggFunction }))
      saveFile = File.open("#{@output}/#{CGI.escape(@wTrack)}","w+")
      ## downloading lff/bedgraph file
      httpResp = apicaller.get(
      {
         :grp      => @grp,
         :db       => @db,
         :trk      => @rTrack,
         :scrTrack => wTrack,
         :esValue  => "NaN",
         :format   => "lff",
         :span     => @spanAggFunction
      }) { |chunck|
        fullChunk = "#{@buff}#{chunck}"
        @buff = ''
        fullChunk.each_line { |line|
          if(line[-1].ord == 10)
            saveFile.write line
          else
            @buff += line
          end
        }
      }
      saveFile.close
    rescue => err
      $stderr.puts "ERROR raised: #{err.message}\n#{err.backtrace.join("\n")}"
    end

    if(apicaller and apicaller.succeeded?)
      $stdout.puts "successfully downloaded file"
    else
      errMsg = "apicaller failed. httpResponse: #{apicaller.httpResponse.inspect} ; rsrcPath:\n  #{apicaller.rsrcPath.inspect}"
      $stderr.debugPuts(__FILE__, __method__, "ERROR", errMsg)
      @exitCode = 152
      raise errMsg
    end
  end

  def wigDownload
    ## MADE CHANGES FOR ALEX STUFF
    apicaller = WrapperApiCaller.new("genboree.org", "", @userId)
    ##Downloading offset file to get the length of each chromosome
    chrHash = {}
    restPath1 = "/REST/v1/grp/{grp}/db/{db}/eps"
    apicaller.setRsrcPath(restPath1)
    apicaller.get(
		{
			:grp => @wgrp,
			:db  => @wdb
		})
    eps =  apicaller.parseRespBody()

    for it in 0...eps["data"]["entrypoints"].size
	    chrHash[eps["data"]["entrypoints"][it]["name"]] = eps['data']['entrypoints'][it]['length']
    end

    path = "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/annos?format=vwig&span={resolution}&spanAggFunction={span}&emptyScoreValue={esValue}"
    apicaller.setRsrcPath(path)
    @buff = ''
    puts path
    saveFile = File.open("#{@output}/#{CGI.escape(@wTrack)}","w+")
    saveFile2 = File.open("#{@output}/#{CGI.escape(@wTrack)}.wig","w+")
    @startPoint = 0
    @endPoint = 0
    @chr = ""
    ##Downloading wig files
    httpResp = apicaller.get(
    {
      :grp      => @wgrp,
      :db       => @wdb,
      :trk      => @wTrack,
      :span     => @spanAggFunction,
      :resolution => @resolution,
      :esValue  => "4290772992"
    }) { |chunck|
      fullChunk = "#{@buff}#{chunck}"
      @buff = ''
      fullChunk.each_line { |line|
        if(line[-1].ord == 10)
          saveFile2.write line
          if(line =~ /variable/)
            @startPoint = 0
            @chr = line.split(/chrom=/)[1].split(/span/)[0].strip!
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
    if(apicaller.succeeded?)
      $stderr.puts "successfully downloaded  wig file"
    else
      $stderr.puts apicaller.parseRespBody().inspect
      $stderr.puts "API response; statusCode: #{apicaller.apiStatusObj['statusCode']}, message: #{apicaller.apiStatusObj['msg']}"
      @exitCode = apicaller.apiStatusObj['statusCode']
      raise "#{apicaller.apiStatusObj['msg']}"
    end
  end

  def SignalSimilarity.usage(msg='')
          unless(msg.empty?)
            puts "\n#{msg}\n"
          end
          puts "

        PROGRAM DESCRIPTION:
           Pairwise epigenome comparison tool
        COMMAND LINE ARGUMENTS:
          --db           | -d => ROI database
          --grp          | -g => ROI group
          --wdb          | -D => WIG database
          --wgrp         | -G => WIG group
          --wTrack       | -w => wig track
          --rTrack       | -r => ROI
          --user         | -u => user name
          --pwd          | -p => password
          --spanAggFunction | -S => spanAggFunction
          --resolution   |  -R => Resolution
          --output       | -o => output
          --useROI       | -U => True if useROI else false
          --help         | -h => [Optional flag]. Print help info and exit.

       usage:

    ruby downloadWig.rb  -D 'Data Freeze 2 Repository' -G 'Epigenomics Roadmap Repository'  -o . -w 'BLEC:MeDIP 70' -r Gene:RefSeq -g arpit_group -d test6 -u arpit -p *** -S avg

    PLEASE BE SURE THE ROI TRACK AND WIG TRACK ARE FROM SAME VERSION OF GENOME.

        ";
            exit;
  end #

  # Process Arguements form the command line input
  def SignalSimilarity.processArguements()
    # We want to add all the prop_keys as potential command line options
    optsArray = [ ['--db'  ,    '-d', GetoptLong::REQUIRED_ARGUMENT],
                   ['--grp',     '-g', GetoptLong::REQUIRED_ARGUMENT],
                   ['--wdb'  ,    '-D', GetoptLong::REQUIRED_ARGUMENT],
                   ['--wgrp',     '-G', GetoptLong::REQUIRED_ARGUMENT],
                   ['--wTrack'  ,'-w', GetoptLong::REQUIRED_ARGUMENT],
                   ['--rTrack',  '-r', GetoptLong::REQUIRED_ARGUMENT],
                   ['--user'    ,'-u', GetoptLong::REQUIRED_ARGUMENT],
                   ['--userId'    ,'-I', GetoptLong::REQUIRED_ARGUMENT],
                   ['--spanAggFunction', '-S', GetoptLong::REQUIRED_ARGUMENT],
                   ['--output'  ,'-o', GetoptLong::REQUIRED_ARGUMENT],
                   ['--resolution' , '-R' , GetoptLong::REQUIRED_ARGUMENT],
                   ['--pwd' , '-p', GetoptLong::REQUIRED_ARGUMENT],
                   ['--useROI'  ,'-U', GetoptLong::OPTIONAL_ARGUMENT],
                   ['--help'      ,'-h', GetoptLong::NO_ARGUMENT]
                ]
    progOpts = GetoptLong.new(*optsArray)
    SignalSimilarity.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
    optsHash = progOpts.to_hash

    Coverage if(optsHash.empty? or optsHash.key?('--help'));
    return optsHash
  end
end

optsHash = SignalSimilarity.processArguements()
performQCUsingFindPeaks = SignalSimilarity.new(optsHash)
if(optsHash['--useROI'])
   performQCUsingFindPeaks.withROI()
else
   performQCUsingFindPeaks.wigDownload
end
