#!/usr/bin/env ruby

#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
require 'brl/util/util'


class DrivePashVGP
  DEBUG = true
  def initialize(optsHash)
		@optsHash = optsHash
		setParameters()
	end

  def setParameters()
    @lffFile = @optsHash['--lffFile']
    @cytoBandFile = @optsHash['--cytobandFile']
    @chromosomeDefFile= @optsHash['--chromosomeSizes']
    @outputDirectory = @optsHash['--outputDirectory']
    @projectPrefix = @optsHash['--projectPrefix']
    @databaseRefSeq = @optsHash['--genbRefSeq']
    @serverURL = @optsHash['--webserver']
    @trackColor = @optsHash['--trackColor']
    @figureTitle = @optsHash['--figureTitle']
    @figureSubtitle = @optsHash['--figureSubtitle']
    @display = @optsHash['--display']
    if(@display==nil)
      @display = "score"
    else
      @display = "#{@display}"
    end
    if (@optsHash.key?('--oneGraph')) then
      @oneGraph = true
      if (@figureTitle.nil?) then
				$stderr.puts "The graph title must be provided if the one graph option is selected!"
				exit(2)
      end
    else
      @oneGraph = false
    end
    if (@trackColor==nil) then
      setColors()
    else
      @colors = @trackColor.split(/,/)
    end
  end

  def setColors()
  @colors = Array.new()
	@colors.push("#FF0000")
	@colors.push("#0000FF")
	@colors.push("#00FF00")
	@colors.push("#00FFFF")
	@colors.push("#FFFF00")
	@colors.push("#FF00FF")
	@colors.push("#008000")
	@colors.push("#000080")
	@colors.push("#C0C0C0")
	@colors.push("#808080")
	@colors.push("#808000")
	@colors.push("#008080")
	@colors.push("#800080")
	@colors.push("#FFFFFF")
	@colors.push("#800000")
	@colors.push("#000000")
	0.upto(20) {|i|
		@colors.push("#000000")
	}

  end

  def analyzeTracks()
    l = nil
    @trackStruct = Struct.new("TrackStruct", :track, :sum, :numberOfElements, :mean, :stdDevSum, :stdDev)
    @trackList = {}
    r = BRL::Util::TextReader.new(@lffFile)
    r.each {|l|
      f = l.split(/\t/)
      track = "#{f[2]}:#{f[3]}"
      if (!@trackList.key?(track)) then
        @trackList[track]=@trackStruct.new(track, f[9].to_f, 1, 0, 0)
      else
        trackStruct = @trackList[track]
        trackStruct.sum += f[9].to_f
        trackStruct.numberOfElements += 1
      end
    }
    r.close()
    $stderr.puts "Tracks: #{@trackList.keys.join("; ")}" if (DEBUG)
    if (@trackList.size>36) then
			$stderr.puts "driveVGP.rb supports up to 36 tracks. Exiting ..."
			exit(1)
    end
    # compute mean and stddev for each track
    t = nil
    @trackList.keys.each {|t|
      trackStruct = @trackList[t]
      trackStruct.mean = trackStruct.sum / trackStruct.numberOfElements
    }
    r = BRL::Util::TextReader.new(@lffFile)
    r.each {|l|
      f = l.split(/\t/)
      track = "#{f[2]}:#{f[3]}"
      if (!@trackList.key?(track)) then
        $stderr.puts "could not find track #{track} the second time around"
        exit(2)
      else
        trackStruct = @trackList[track]
        trackStruct.stdDevSum += (f[9].to_f - trackStruct.mean)*(f[9].to_f - trackStruct.mean)
      end
    }
    r.close()
    @trackList.keys.each {|t|
      trackStruct = @trackList[t]
      trackStruct.stdDev = Math.sqrt(trackStruct.stdDevSum / trackStruct.numberOfElements)
      $stderr.puts "Track #{t} has mean #{trackStruct.mean}, #{trackStruct.numberOfElements} elements and #{trackStruct.stdDev} standard deviation" if (DEBUG)
    }
  end

  def work()
    # determine tracks present in the lff file
    analyzeTracks()
    #prepare vgp output dir
    @vgpOutputDirBase = "#{@outputDirectory}/vgp.#{Process.pid}"
    system("mkdir -p #{@vgpOutputDirBase}")
    system("mkdir -p #{@outputDirectory}/genb^^additionalPages")
    system("mkdir -p #{@outputDirectory}/genb^^additionalFiles")
    system("mkdir -p #{@outputDirectory}/scripts")

    generateVGPGraphs()
    prepareForProjectUpload()
  end

	def outputCommonParts(w, track, trackOutputDir, graphType)
		# generate json file for genome view
    # lff files
    w.puts "{"
    w.print "\t\"lffFiles\" : [\"#{@lffFile}\""
    if (@cytoBandFile!=nil) then
      w.print ", \"#{@cytoBandFile}\""
    end
    w.puts "],"
    # chr definitions
    w.puts "\t\"chrDefinitionFile\" : \"#{@chromosomeDefFile}\","
    w.puts "\t\"outputDirectory\" : \"#{trackOutputDir}\","
    w.puts "\t\"outputFormat\" : \"png\","
    if (track.nil?) then
			# one graph most likely
			w.puts "\t\"figureTitle\" : \"#{@figureTitle}\","
    else
			if (!@figureTitle.nil?)
				w.puts "\t\"figureTitle\" : \"#{@figureTitle}\","
			else
				w.puts "\t\"figureTitle\" : \"Coverage of #{track}\","
			end

    end
		if (!@figureSubtitle.nil?) then
			w.puts "\t\"subtitle\" : \"#{@figureSubtitle}\","
		else
			w.puts "\t\"subtitle\" : \"\","
		end

    w.puts "\t\"yAxisLabelFormat\" : \"left\","
    w.puts "\t\"xAxisLabel\" : \"Chromosome\","
    w.puts "\t\"yAxisLabel\" : \"Base-pair (bp)\","

    if (graphType=="genome") then
      w.puts "\t\"genomeView\" : {"
      w.puts "\t\t\"width\" : 1280,"
      w.puts "\t\t\"height\" : 600,"
      w.puts "\t\t\"margin\" :1"
      w.puts "\t},"
    else
      w.puts "\t\"chromosomeView\" : {"
      w.puts "\t\t\"width\" : 400,"
      w.puts "\t\t\"height\" : 600"
      w.puts "\t},"
    end

    w.puts "\t\"chromosomeLabels\" : \"true\","
    w.puts "\t\"legend\" : {"
    w.puts "\t\t\"position\" : \"bottom\","
    w.puts "\t\t\"border\" : true"
    w.puts "\t},"

    if (@cytoBandFile!=nil) then
      w.puts "\t\"referenceTrack\" : {"
      w.puts "\t\t\"Cyto:Band\" : "
      w.puts "\t\t["
      w.puts "\t\t\t{"
      w.puts "\t\t\t\"displayName\" : \"Cytoband\","
      w.puts "\t\t\t\"drawingStyle\" : \"cytoband\","
      w.puts "\t\t\t\"margin\" : 5,"
      w.puts "\t\t\t\"width\" : 8,"
      w.puts "\t\t\t\"zIndex\" : #{@zIndex}"
      @zIndex += 1
      w.puts "\t\t\t}"
      w.puts "\t\t]"
      w.puts "\t},"
    end
	end

	def generateGraphForAllTracks(graphType)
		if (graphType!="genome" && graphType!="chromosome") then
      $stderr.print "graph type not specified"
      exit(0)
    end
    script = "#{@outputDirectory}/scripts/script.oneGraph.#{Process.pid}.#{graphType}.json"
    trackOutputDir = "#{@vgpOutputDirBase}/vgp.oneGraph.#{Process.pid}"
    system ("mkdir -p #{trackOutputDir}")
    @zIndex = 0
    w = BRL::Util::TextWriter.new(script)
    outputCommonParts(w, nil, trackOutputDir, graphType)
    w.puts "\t\"tracks\" : {"
		# ordering ?
		trackIndex = 0
		@trackList.keys.each {|track|
			w.puts "\t\t\"#{track}\" : "
			w.puts "\t\t["
			w.puts "\t\t\t{"
			w.puts "\t\t\t\"displayName\" : \"#{track.tr(":"," ")}\","
			# note: users get to rename the tracks
			# they also get to choose meaningful display names
			if(@display == "score")
			  w.puts "\t\t\t\"drawingStyle\" : \"score\","
			elsif(@display == "block")
			  w.puts "\t\t\t\"drawingStyle\" : \"block\","
			end
			w.puts "\t\t\t\"margin\" : 5,"
			if (graphType=='genome') then
				w.puts "\t\t\t\"width\" : 30,"
			else
				w.puts "\t\t\t\"width\" : 150,"
			end
			w.puts "\t\t\t\"maxScore\" : #{@trackList[track].mean + 2*@trackList[track].stdDev},"
			w.puts "\t\t\t\"color\" : \"#{@colors[trackIndex]}\","
			w.puts "\t\t\t\"zIndex\" : #{@zIndex}"
			w.puts "\t\t\t}"
			w.puts "\t\t]"
			if (trackIndex<@trackList.size-1) then
				w.puts ","
			end
			trackIndex+=1
			@zIndex +=1
		}
		w.puts "\t}"
    w.puts "}"
    w.close()
    vgpCommand = "vgp.rb -p #{script}"
    $stderr.puts "vgp command=#{vgpCommand}"
    system(vgpCommand)
	end


  def generateGraphForTrack(track, graphType)
    if (graphType!="genome" && graphType!="chromosome") then
      $stderr.print "graph type not specified"
      exit(0)
    end
    track =~ /(\S+):(\S+)/
    script = "#{@outputDirectory}/scripts/script.#{CGI.escape(track)}.#{graphType}.json"
    trackOutputDir = "#{@vgpOutputDirBase}/vgp.#{CGI.escape(track)}"
    system ("mkdir -p #{trackOutputDir}")
    @zIndex = 0
    w = BRL::Util::TextWriter.new(script)

		outputCommonParts(w, track, trackOutputDir, graphType)

    w.puts "\t\"tracks\" : {"
    w.puts "\t\t\"#{track}\" : "
    w.puts "\t\t["
    w.puts "\t\t\t{"
    w.puts "\t\t\t\"displayName\" : \"#{track.tr("_:","  ")}\","
    # note: users get to rename the tracks
    # they also get to choose meaningful display names
    if(@display == "score")
      w.puts "\t\t\t\"drawingStyle\" : \"score\","
    elsif(@display == "block")
      w.puts "\t\t\t\"drawingStyle\" : \"block\","
    end
    
    w.puts "\t\t\t\"margin\" : 5,"
    if (graphType=='genome') then
      w.puts "\t\t\t\"width\" : 30,"
    else
      w.puts "\t\t\t\"width\" : 150,"
    end
    w.puts "\t\t\t\"maxScore\" : #{@trackList[track].mean + 2*@trackList[track].stdDev},"
    w.puts "\t\t\t\"color\" : \"#FF0000\","
    w.puts "\t\t\t\"zIndex\" : #{@zIndex}"
    w.puts "\t\t\t}"
    w.puts "\t\t]"
    w.puts "\t}"

    w.puts "}"
    w.close()
    vgpCommand = "vgp.rb -p #{script}"
    $stderr.puts "vgp command=#{vgpCommand}"
    system(vgpCommand)
  end

  def generateVGPGraphs()
    track = nil

		if (@oneGraph) then
			generateGraphForAllTracks("genome")
			generateGraphForAllTracks("chromosome")
		else
			@trackList.keys.each { |track|
				generateGraphForTrack(track, "genome")
				generateGraphForTrack(track, "chromosome")
			}
    end
  end


  def prepareProjectFiles(track)
    trackOutputDir = "#{@vgpOutputDirBase}/vgp.#{CGI.escape(track)}"
    # generate output dir in genb^... dirs
    genbFilesDir = "#{@outputDirectory}/genb^^additionalFiles/vgp.#{CGI.escape(track)}"
    genbPagesDir = "#{@outputDirectory}/genb^^additionalPages/vgp.#{CGI.escape(track)}"
    system("mkdir #{genbFilesDir}")
    system("mkdir #{genbPagesDir}")
    # copy html pages
    mvPagesCommand = "mv  #{trackOutputDir}/html/*.html #{genbPagesDir}"
    $stderr.puts "executing mv pages command #{mvPagesCommand}"
    system(mvPagesCommand)
    # copy images
    mvFilesCommand = "mv  #{trackOutputDir}/images/*.png #{genbFilesDir}"
    $stderr.puts "executing mv files command #{mvFilesCommand}"
    system(mvFilesCommand)
    # properly annotate each html file
    htmlFileList = Dir["#{genbPagesDir}/*html"]
    htmlFileList.each {|htmlFile|
      $stderr.puts "Fixing file #{htmlFile}" if (DEBUG)
      sleep(1)
      r = BRL::Util::TextReader.new(htmlFile)
      l = nil
      w = File.open("#{htmlFile}.tmp", "w")
      r.each { |l|
        if (l=~ /^(.*SRC=")..\/images(.*)$/) then
          w.puts "#{$1}#{@serverURL}/#{CGI.escape("#{@projectPrefix}/genb^^additionalFiles/vgp.#{CGI.escape(track)}")}#{$2}"
        else
          w.print l
        end
      }

      if (htmlFile =~ /genome/) then
        w.puts "<script type=\"text/javascript\"  src=\"#{@projectPrefix}/genb^^additionalPages/vgp.#{CGI.escape(CGI.escape(track))}/vgpCallbacks_genome.js\"> </script>"
      else
        w.puts "<script type=\"text/javascript\"  src=\"#{@projectPrefix}/genb^^additionalPages/vgp.#{CGI.escape(CGI.escape(track))}/vgpCallbacks.js\"> </script>"
      end
      r.close()
      w.close()
      system("mv #{htmlFile}.tmp #{htmlFile}")
    }


    # generate vgpCallback files
    vgpCallbacksFile = "#{genbPagesDir}/vgpCallbacks.js"
    vgpCallbacks_genomeFile = "#{genbPagesDir}/vgpCallbacks_genome.js"

    #TODO: take db as parameter

    w = BRL::Util::TextWriter.new(vgpCallbacksFile)

    w.puts "
function chromosomeClicked(chrName, chrStart, chrStop, yPxStart, yPxStop)
{
  window.location = (\"#{@serverURL}/java-bin/gbrowser.jsp?refSeqId=#{@databaseRefSeq}\" +
                    \"&entryPointId=\" + chrName +
                    \"&from=\" + chrStart +
                    \"&to=\" + chrStop) ;
  return false ;
}

function calloutClicked(annoName, chrName, chrStart, chrStop, yPxStart, yPxStop)
{
  window.location = (\"#{@serverURL}/java-bin/gbrowser.jsp?refSeqId=#{@databaseRefSeq}\" +
                    \"&entryPointId=\" + chrName +
                    \"&from=\" + (chrStart - 0.10 * (chrStop-chrStart)) +
                    \"&to=\" + (chrStop + 0.10 * (chrStop-chrStart))) ;
  return false ;
}

function figureTitleClicked(figTitle, chrName)
{
  return false ;
}

function yAxisClicked(yAxisTick, chrName, chrStart, chrStop, yPxStart, yPxStop)
{
  window.location = (\"#{@serverURL}/java-bin/gbrowser.jsp?refSeqId=#{@databaseRefSeq}\" +
                    \"&entryPointId=\" + chrName +
                    \"&from=\" + chrStart +
                    \"&to=\" + chrStop) ;
  return false ;
}

function yAxisLabelClicked(yAxisLabel, chrName)
{
  return false ;
}

function emptyAreaClicked(chrName)
{
  return false;
}
"
    w.close()

    w = BRL::Util::TextWriter.new(vgpCallbacks_genomeFile)
w.puts "
function chromosomeClicked(chrName, chrStart, chrStop, yPxStart, yPxStop)
{
  window.location = (\"#{@serverURL}/#{@projectPrefix}/genb^^additionalPages/vgp.#{CGI.escape(CGI.escape(track))}/\" + chrName + \"ImageMap.html\") ;
  return true ;
}

function calloutClicked(annoName, chrName, chrStart, chrStop, yPxStart, yPxStop)
{
  window.location = (\"#{@serverURL}/java-bin/gbrowser.jsp?refSeqId=#{@databaseRefSeq}\" +
                    \"&entryPointId=\" + chrName +
                    \"&from=\" + chrStart +
                    \"&to=\" + chrStop) ;
  return true ;
}

function figureTitleClicked(figTitle, chrName)
{
}

function yAxisClicked(yAxisTick, chrName, chrStart, chrStop, yPxStart, yPxStop)
{
}

function yAxisLabelClicked(yAxisLabel, chrName)
{
}

function emptyAreaClicked(chrName)
{
  if(chrName)
  {
    window.location = (\"#{@serverURL}/#{@projectPrefix}/genb^^additionalPages/vgp.#{CGI.escape(CGI.escape(track))}/\" + chrName + \"ImageMap.html\") ;
  }
  return true ;
}


"
    w.close()

  end

  def prepareForProjectUpload()
    if (@oneGraph) then
			track = "oneGraph.#{Process.pid}"
			prepareProjectFiles(track)
    else
			track = nil
	    @trackList.keys.each { |track|
	      prepareProjectFiles(track)
	    }
	  end
  end

  def DrivePashVGP.processArguments()
		# We want to add all the prop_keys as potential command line options
		optsArray =	[ ['--lffFile',           '-l', GetoptLong::REQUIRED_ARGUMENT],
									['--cytobandFile',      '-c', GetoptLong::OPTIONAL_ARGUMENT],
									['--chromosomeSizes',   '-C', GetoptLong::REQUIRED_ARGUMENT],
									['--outputDirectory',   '-o', GetoptLong::REQUIRED_ARGUMENT],
									['--projectPrefix',     '-P', GetoptLong::REQUIRED_ARGUMENT],
									['--genbRefSeq',        '-D', GetoptLong::REQUIRED_ARGUMENT],
									['--webserver',         '-w', GetoptLong::REQUIRED_ARGUMENT],
									['--trackColors',       '-T', GetoptLong::OPTIONAL_ARGUMENT],
									['--oneGraph',          '-O', GetoptLong::OPTIONAL_ARGUMENT],
									['--figureTitle',       '-F', GetoptLong::OPTIONAL_ARGUMENT],
									['--figureSubtitle',    '-f', GetoptLong::OPTIONAL_ARGUMENT],
									['--display',           '-d', GetoptLong::OPTIONAL_ARGUMENT],
                  ['--help',             '-h', GetoptLong::NO_ARGUMENT]
								]

		progOpts = GetoptLong.new(*optsArray)
		optsHash = progOpts.to_hash
		DrivePashVGP.usage() if(optsHash.key?('--help'));

		unless(progOpts.getMissingOptions().empty?)
			DrivePashVGP.usage("USAGE ERROR: some required arguments are missing")
		end

		DrivePashVGP.usage() if(optsHash.empty?);
		return optsHash
	end

	def DrivePashVGP.usage(msg='')
			unless(msg.empty?)
				puts "\n#{msg}\n"
			end
			puts "
PROGRAM DESCRIPTION:
  Utility that takes in a resulting lff file, containing coverage
information, and generate VGP graphs for all tracks and for individual
tracks. Next, the VGP results are packaged for project display.


COMMAND LINE ARGUMENTS:
  --lffFile          | -l   => required argument
  --cytobandFile     | -c   => [optional] file containing the cytoband
  --chromosomeSizes  | -C   => file containing chromosomes sizes
  --outputDirectory  | -o   => output directory
  --projectPrefix    | -P   => http prefix of the target project
  --genbRefSeq       | -D   => Genboreee refseq id
  --webserver        | -w   => web server where projects live
  --trackColors      | -T   => [optional] comma separated list of colors used for the tracks
  --oneGraph         | -O   => [optional] combine all tracks in one graph; by default one graph is generated per track
  --figureTitle      | -F   => [optional] graph title; required if oneGraph is selected
  --figureSubtitle   | -f   => [optional] graph subtitle
  --display          | -d   => [optional] (default: score) choose between score and block
  --help             | -h   => [optional flag] Output this usage info and exit

USAGE:

";
			exit(2);
	end
end


########################################################################################
# MAIN
########################################################################################

# Process command line options
optsHash = DrivePashVGP.processArguments()
# Instantiate analyzer using the program arguments
vgpDriver = DrivePashVGP.new(optsHash)
# Analyze this !
vgpDriver.work()
exit(0);
