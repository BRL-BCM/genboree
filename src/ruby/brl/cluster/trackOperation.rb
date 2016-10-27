#!/usr/bin/env ruby
require 'cgi'
require 'brl/util/util'
require 'brl/genboree/dbUtil'

  def queryAndConvertTracks
    trackNames = ""
    trackNames << "#{CGI.escape(@firstTrack)}"
    @secondTracks.each{|secondTrack| trackNames << ",#{CGI.escape(secondTrack)}"}
    classpath =  "/usr/local/brl/local/apache/htdocs/common/lib/servlet-api.jar:"
    classpath << "/usr/local/brl/local/apache/htdocs/common/lib/mysql-connector-java.jar:"
    classpath << "/usr/local/brl/local/apache/htdocs/common/lib/activation.jar:"
    classpath << "/usr/local/brl/local/apache/htdocs/common/lib/mail.jar:"
    classpath << "/usr/local/brl/local/apache/java-bin/WEB-INF/lib/GDASServlet.jar"
    annoDownloaderCmd = "java -classpath #{classpath} -Xmx1800M  org.genboree.downloader.AnnotationDownloader"
    annoDownloaderCmd << " -b"
    annoDownloaderCmd << " -u #{@userId}"
    annoDownloaderCmd << " -r #{@refSeqId}"
    annoDownloaderCmd << " -m #{trackNames}"
    annoDownloaderCmd << " > #{@workFileName}"
    puts annoDownloaderCmd
    begin
      system(annoDownloaderCmd)
    rescue => err
      $stderr.puts "Error in querying and converting tracks #{err.to_s}"
      $stderr.puts "#{err.backtrace.join("\n")}"
    end
  end

  def executeOperation
    retVal = 0
    lffIntersectCmd = "lffIntersect.rb"
    lffIntersectCmd << " -V"
    (firstTrackTypeName,firstTrackSubTypeName) = @firstTrack.split(/:/)   
    lffIntersectCmd << " -f #{CGI.escape(firstTrackTypeName)}:#{CGI.escape(firstTrackSubTypeName)}"
    lffIntersectCmd << " -s"
    trackNames = ""
    @secondTracks.each{|secondTrack| 
      (secondTrackTypeName,secondTrackSubTypeName) = secondTrack.split(/:/)
      trackNames << ",#{CGI.escape(secondTrackTypeName)}:#{CGI.escape(secondTrackSubTypeName)}"
    }
    trackNames = trackNames.gsub(/^,/,"")
    lffIntersectCmd << " #{CGI.escape(trackNames)}"
    lffIntersectCmd << " -l #{CGI.escape(@workFileName)}"
    lffIntersectCmd << " -o #{CGI.escape(@outputFileName)}"
    lffIntersectCmd << " -n #{CGI.escape(@newTrackTypeName)}:#{CGI.escape(@newTrackSubTypeName)}"
    lffIntersectCmd << " -r #{@radius}" unless @radius.nil?
    lffIntersectCmd << " -m #{@minNumOverlaps}" unless @minNumOverlaps.nil?
    lffIntersectCmd << " -c #{CGI.escape(@newTrackClassName)}"
    lffIntersectCmd << " -a" unless @conditionAll.nil?    
    begin
      $stderr.puts lffIntersectCmd
      system(lffIntersectCmd)
    rescue => err
      $stderr.puts "Error in executing lffIntersect #{err.to_s}"
      $stderr.puts "#{err.backtrace.join("\n")}"
      
    end

  end

  def uploadNewTrack    
    classpath =  "/usr/local/brl/local/apache/htdocs/common/lib/servlet-api.jar:"
    classpath << "/usr/local/brl/local/apache/htdocs/common/lib/mysql-connector-java.jar:"
    classpath << "/usr/local/brl/local/apache/htdocs/common/lib/activation.jar:"
    classpath << "/usr/local/brl/local/apache/htdocs/common/lib/mail.jar:"
    classpath << "/usr/local/brl/local/apache/java-bin/WEB-INF/lib/GDASServlet.jar"
    uploaderCmd = "java -classpath #{classpath} -Xmx1800M  org.genboree.upload.AutoUploader"    
    uploaderCmd << " -u #{@userId}"
    uploaderCmd << " -r #{@refSeqId}"
    uploaderCmd << " -f ./#{@outputFileName}"
    uploaderCmd << " -t lff -z"
    
    
    begin
      if(@useClusterForUpload)
      uploaderWrapperCmd = "uploadWrapper.rb -o #{@clusterOutputDir} -i ./#{@outputFileName} -c #{CGI.escape(uploaderCmd)} -p #{@parentJobName}"
      system(uploaderWrapperCmd)
    else
      system(uploaderCmd)
    end
    rescue => err
      $stderr.puts "Error in uploading tracks #{err.to_s}"
      $stderr.puts "#{err.backtrace.join("\n")}"
    end      
  end



  def printUsage
     puts "PROGRAM DESCRIPTION:
     This script is analogous to the TrackOperation java class and is intended to ba ruby version which performs only lff intersect at this point. The argument it accepts are below.
            [['--help',         '-h', GetoptLong::NO_ARGUMENT],             
             ['--condition',    '-c', GetoptLong::OPTIONAL_ARGUMENT],
             ['--refSeqId',     '-r', GetoptLong::REQUIRED_ARGUMENT],
             ['--genbUserId',   '-g', GetoptLong::REQUIRED_ARGUMENT],
             ['--firstTrack',   '-f', GetoptLong::REQUIRED_ARGUMENT],
             ['--secondTrack',  '-s', GetoptLong::REQUIRED_ARGUMENT],
             ['--newTrack',     '-n', GetoptLong::REQUIRED_ARGUMENT],
             ['--workFile',     '-w', GetoptLong::REQUIRED_ARGUMENT],
             ['--outputFile',   '-o', GetoptLong::REQUIRED_ARGUMENT],
             ['--radius',       '-d', GetoptLong::REQUIRED_ARGUMENT],
             ['--minOverlap',   '-v', GetoptLong::REQUIRED_ARGUMENT],
             ['--clusterOutputDir', GetoptLong::OPTIONAL_ARGUMENT],
             ['--parentJobName',  GetoptLong::OPTIONAL_ARGUMENT]
             ]
      The clusterOutputDir and parentJobName flags are to be used only when the upload portion of the lff intersect is to be run on a cluster. They should both be specified for
      cluster operation. If both are not specified, the upload is handled locally"
     exit(2)
  end
  
  optsArray = [['--help',         '-h', GetoptLong::NO_ARGUMENT],             
             ['--condition',    '-c', GetoptLong::OPTIONAL_ARGUMENT],
             ['--refSeqId',     '-r', GetoptLong::REQUIRED_ARGUMENT],
             ['--genbUserId',   '-g', GetoptLong::REQUIRED_ARGUMENT],
             ['--firstTrack',   '-f', GetoptLong::REQUIRED_ARGUMENT],
             ['--secondTrack',  '-s', GetoptLong::REQUIRED_ARGUMENT],
             ['--newTrack',     '-n', GetoptLong::REQUIRED_ARGUMENT],
             ['--workFile',     '-w', GetoptLong::REQUIRED_ARGUMENT],
             ['--outputFile',   '-o', GetoptLong::REQUIRED_ARGUMENT],
             ['--radius',       '-d', GetoptLong::REQUIRED_ARGUMENT],
             ['--minOverlap',   '-v', GetoptLong::REQUIRED_ARGUMENT],
             ['--clusterOutputDir', GetoptLong::OPTIONAL_ARGUMENT],
             ['--parentJobName',  GetoptLong::OPTIONAL_ARGUMENT]
             ]  
               
progOpts = GetoptLong.new(*optsArray)
optsHash = progOpts.to_hash
if(optsHash.key?('--help')) then
  printUsage
end

unless(progOpts.getMissingOptions().empty?)
  printUsage
end
if(optsHash.empty?) then
  printUsage
end


@useClusterForUpload = false
@conditionAll = optsHash['--condition']
@userId = optsHash['--genbUserId']
@refSeqId = optsHash['--refSeqId']
@workFileName = optsHash['--workFile']
@outputFileName = optsHash['--outputFile']
@radius = optsHash['--radius']
@minNumOverlaps = optsHash['--minOverlap']
@firstTrack = optsHash['--firstTrack']
@firstTrack = @firstTrack.gsub(/\s+:\s+/,":")  
@secondTracks =   optsHash['--secondTrack'].split(/,/).map!{|x| CGI.unescape(x)}.map!{|x| x.gsub(/\s+:\s+/,":")}
(@newTrackClassName, @newTrackTypeName, @newTrackSubTypeName) =  optsHash['--newTrack'].split(/,/).map!{|x| CGI.unescape(x)}

# Either specify both options or neither
if ((optsHash['--clusterOutputDir'].nil?)^(optsHash['--clusterOutputDir'].nil?)) then
  printUsage
elsif(!optsHash['--clusterOutputDir'].nil?)
  @useClusterForUpload = true
  @clusterOutputDir = optsHash['--clusterOutputDir']
  @parentJobName = optsHash['--parentJobName']
end


queryAndConvertTracks
executeOperation
uploadNewTrack