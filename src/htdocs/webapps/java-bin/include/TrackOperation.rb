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
    uploaderCmd << " -f #{@outputFileName}"
    uploaderCmd << " -t lff -z"
    begin
      system(uploaderCmd)      
    rescue => err
      $stderr.puts "Error in uploading tracks #{err.to_s}"
      $stderr.puts "#{err.backtrace.join("\n")}"
    end      
  end

  def printUsage
    puts "One or more required arguments are missing"
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
             ['--minOverlap',   '-v', GetoptLong::REQUIRED_ARGUMENT]]             
               
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
queryAndConvertTracks
executeOperation
uploadNewTrack