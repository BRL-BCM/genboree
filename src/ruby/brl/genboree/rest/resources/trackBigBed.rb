#!/usr/bin/env ruby
require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/unlockedRefEntity.rb'
require 'brl/genboree/rest/em/deferrableBodies/deferrableUCSCBigFileBody'
require 'brl/genboree/abstract/resources/bedFile'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobManager'
require 'brl/genboree/lockFiles/genericDbLockFile'
require 'brl/genboree/rest/apiCaller'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  class TrackBigBed < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }
    RSRC_TYPE = 'bigBed'

    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
    end

    # INTERFACE: return a +Regexp+ that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/annos$</tt>
    def self.pattern()
      return %r{^/REST/v1/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/bigBed$}     # Look for /REST/v1/grp/{grp}/db/{db}/trk/{trk}/attribute/{attributeName}/[aspect] URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    # [+returns+] The priority, from 1 t o 10.
    def self.priority()
      return 9          # Allow more specific URI handlers involving tracks etc within the database to match first
    end


    def initOperation()
      initStatus = super()
      # Init the resource instance vars
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @groupName = Rack::Utils.unescape(@uriMatchData[1])
      @dbName = Rack::Utils.unescape(@uriMatchData[2])
      @trackName = Rack::Utils.unescape(@uriMatchData[3]).strip
      # Init URL vars
      @sendConfirmEmail = (@nvPairs['sendConfirmEmail'] == 'false') ? false : true
      # Init config vars
      @bbFileName = @genbConf.gbTrackAnnoBigBedFile
      @ftypeRow = nil
      # Init and check group & database exist and are accessible
      initStatus = initGroupAndDatabase()

      # Must check that track exists also...once we launch the downloader it will be impossible to
      # determine if it succeeds or fails, so we want to check as much as possible -now-.
      #
      # Get all the tracks in this user database (includes shared tracks) [that user has access to; superuser has access to everything]
      groupRecs = @dbu.selectGroupByName(@groupName)
      @groupId = groupRecs.first['groupId']
      @refseqRecs = @dbu.selectRefseqByNameAndGroupId(@dbName, @groupId)
      ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes(@refseqRecs.first['refSeqId'], @userId, true, @dbu) # will also have dbRec.dbName & dbRec.ftypeid for the dbs (user, template) track is present in
      # Get just the one ftypeRow matching the track
      @ftypeHash = ftypesHash[@trackName]
      if (@ftypeHash.nil? or @ftypeHash.empty?)
        initStatus = @statusName = :'Not Found'
        @statusMsg = "NO_TRK: There is no track #{@trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
      end

      return initStatus
    end


    def head()
      # alias for get() because the required headers are all set there
      # Use the headOnly parameter in get() to not include the response body
      # unfortunately this is a problem because Content-Length is calculated by
      # by the size of the body
      get(true)
    end


    # Process a GET operation on this resource.
    # For this resource a get reads the bigbed file that's stored on disk,
    # If the file doesn't exist yet, 404
    #
    # This GET suppports range requests
    #
    # [+returns+] <tt>Rack::Response</tt> instance
    def get(headOnly=false)
      initOperation()
      if(@statusName == :OK)
        unless(@ftypeHash.nil? or @ftypeHash.empty?)
          # Get the location of the file on disk
          # path is in the config file
          # /data/genboree/dataFiles/grp/{groupId}/db/{refseqId}/trk/{trackName}/trackAnnos.bb
          path = BRL::Genboree::Abstract::Resources::UCSCBigFile.makeDirPath(@genbConf, @groupId, @refseqRecs.first['refSeqId'], @ftypeHash['ftypeid'])
          fileNameFull = "#{path}/#{@bbFileName}"
          if(File.exists?(fileNameFull))
            # Set response headers that are required by UCSC
            @resp['Last-Modified'] = File.mtime(fileNameFull).strftime("%a, %d %b %Y %H:%M:%S %Z")
            @resp['Content-Type'] = 'application/octet-stream'
            @resp['Accept-Ranges'] = 'bytes'
            # Debug message below. Can remove once stable
            #$stderr.puts "DEBUG:UCSC_bigBed: #{Time.now} : Received #{(headOnly)?"HEAD":"GET"} request for bigWig HTTP_RANGE: #{@req.env['HTTP_RANGE'].inspect}"
            if(headOnly)
              @resp['Content-Length'] = File.size(fileNameFull).to_s
              @resp.status = HTTP_STATUS_NAMES[:OK]
              @resp.body = []
            else
              @resp.status = HTTP_STATUS_NAMES[:'Partial Content']
              # Support range requests, length and offset will be nil if not supplied which will cause the whole file to be read
              length, offset = BRL::Genboree::Abstract::Resources::UCSCBigFile.parseRangeRequest(@req.env['HTTP_RANGE'])
              # UCSC seems to be expecting their Range header echoed back at them via Content-Range. But they break RFC
              # by expecting "0-" which is valid for Requests but not for Responses (last-byte-pos is not optional in Response only Request)
              # - extract actual range (separate from units)
              @req.env['HTTP_RANGE'] =~ /^(?:[^=]+)=\s*(.+)$/
              ucscRangeValue = "bytes #{$1}"
              @resp['Content-Range'] = ucscRangeValue
              $stderr.puts "UCSC DEBUG: ucsc wants wig data. The byte range they request is '#{@req.env["HTTP_RANGE"]}' (which is a lie)\nUCSC DEBUG: Sending back 'Content-Range: #{ucscRangeValue}' (also a lie, and probably not to RFC)"
              deferrableBody = BRL::Genboree::REST::EM::DeferrableBodies::DeferrableUCSCBigFileBody.new(
                :path   => fileNameFull,
                :length => length,
                :offset => offset,
                :yield  => true
              )
              @resp.body = deferrableBody
            end
          else
            @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "There is no bigBed file for this resource. PUT it first")
          end
        else
          @statusName = :'Not Found'
          @statusMsg = "NO_TRK: There is no track #{@trackName.inspect} in database #{@dbName.inspect} in user group #{@groupName.inspect} (or perhaps isn't encoded correctly?)"
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end




    # The PUT method for this resource initiates the process for creating the bed file.
    # Launch process that will
    #  - create bedFile
    #  - run UCSC convertor on the file.
    #
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        # Create the directory
        path = BRL::Genboree::Abstract::Resources::UCSCBigFile.makeDirPath(@genbConf, @groupId, @refseqRecs.first['refSeqId'], @ftypeHash['ftypeid'])
        FileUtils.mkdir_p(path) unless(File.symlink?(path)) # If not present, false; if dir, false. (mkdir_p fails for symlinks)
        puts path
        # First, let's get the dir of the file and cd to it. This will be helpful/safe when launching uploader process.
        FileUtils.cd(path)

        # Touch a file which is deleted when done.
        # presence of file indicates that the job is incomplete
        # There could be a situation where there is a big file and a status file,
        # if the big file was from a previous job
        FileUtils.touch('bigBed.jobSubmitted')

        # use TaskWrapper
        # URL escape the command and append it to a genbTaskWrapper command
        # Make the command to run

        bbCmd = "genbBigBedFile.rb" +
                " -g #{CGI.escape(@groupName)}" +
                " -d #{CGI.escape(@dbName)}" +
                " -t #{CGI.escape(@trackName)}" +
                " -b #{@bbFileName}" +
                #" -z #{@bbFileName+'.tgz'}" +
                " -x " +
                " -n #{@rsrcHost}"
        if(@sendConfirmEmail)
          userRows = @dbu.getUserByUserId(@userId)
          emailAddress = userRows.first['email']
          bbCmd << " -e #{emailAddress}"
        end
        useClusterForAPI = @genbConf.useClusterForAPI
        useClusterForAPI = "false" # set it to false for now
        #Are we supposed to use the cluster for API jobs?
        if(useClusterForAPI == "true" or useClusterForAPI == "yes") then
          # GenbConfig files are at a different location on cluster nodes compared to proline
          bbCmd << " -c #{@genbConf.clusterNodeGenbConfigFile} "
          # Create err file locally for cluster job
          bbCmd << " 2> genbBigBedFile.err "
          # Cluster job Id
          jobId = Time.now.to_i.to_s + "_#{rand(65525)}"
          hostname = ENV["HTTP_HOST"] || @genbConf.machineName
          # Who gets notified about cluster job status changes?
          clusterAdminEmail = 'raghuram@bcm.edu'
          # hostname:path is the output directory for the cluster job to move files to from the temporary working directoryon the node after it is done executing
          # Supply job name, output dir, notification email and a flag to specify whether to retain temp. working dir.
          clusterJob = BRL::Cluster::ClusterJob.new("job-#{jobId}", hostname.strip.to_s + ":" + path, clusterAdminEmail, "false")
          # Suitably modified 'main' command for the cluster job to execute on the node
          clusterJob.commands << CGI.escape(bbCmd)
          # Which resources will this job utilize on the node/ what type of node does it need?
          clusterJob.resources << genbConf.clusterAPIResourceFlag+"=1"

          # Create a resource identifier string for this job which can be used to track resource usage
          # Format is /REST/v1/grp/{grp}/db/{db}/trk/{trk}/bigBed
          apiCaller = BRL::Genboree::REST::ApiCaller.new("proline.brl.bcm.tmc.edu", "/REST/v1/grp/{grp}/db/{db}/trk/{trk}/bigBed")
          rsrcId = apiCaller.fillApiUriTemplate( { :grp => @groupName, :db => @dbName, :trk => @trackName } )
          uri = URI.parse(rsrcId)
          resourceIdentifier = uri.path
          clusterJob.resourcePaths << resourceIdentifier

          # Should the temporary working directory of the cluster job be retained on the node?
          if(@genbConf.retainClusterAPIDir=="true" or @genbConf.retainClusterAPIDir=="yes")
            clusterJob.removeDirectory = "false"
          else
            clusterJob.removeDirectory = "true"
          end
          begin
            # Get a lock in order to submit the job to the scheduler
            @dbLock = BRL::Genboree::LockFiles::GenericDbLockFile.new(:clusterJobDb)
            @dbLock.getPermission()
            clusterJobManager = BRL::Cluster::ClusterJobManager.new(genbConf.schedulerDbrcKey,genbConf.schedulerTable)
            # Put the job in the scheduler table
            schedJobId = clusterJobManager.insertJob(clusterJob)
          rescue Exception => err
            $stderr.puts "#{Time.now.to_s} ERROR: Inserting job into scheduler table"
            $stderr.puts err.to_s
            $stderr.puts err.backtrace.join("\n")
          ensure
            begin
              # Release lock
              @dbLock.releasePermission() unless(@dbLock.nil?)
            rescue Exception => err1
              $stderr.puts "#{Time.now.to_s} ERROR: Releasing lock on lock file #{@dbLock.lockFileName}"
              $stderr.puts err1.to_s
              $stderr.puts err1.backtrace.join("\n")
            end
          end
          if(schedJobId.nil?) then
            $stderr.puts("Error submitting job to the scheduler")
          else
            $stderr.puts("Your Job Id is #{schedJobId}")
          end
        else #Non cluster execution
          # Make task command:
          # -- note, it's safest to URL encode arguments to genbTaskWrapper.rb whose values are based on user-input (db names, user names, etc.)
          # -- they will be decoded automatically if detected
          # -- obviously, if the value contains an escape sequence itself, then it MUST be encoded (such that the string "Demo%20123" becomes "Demo%2520123" for example)
          bbCmd << " -c #{ENV['GENB_CONFIG']} "
          bbCmd << " 2> genbBigBedFile.err "
          @cmdBase =  "genbTaskWrapper.rb -y -c #{CGI.escape(bbCmd)} -g #{ENV['GENB_CONFIG']} "
          @cmdBase << " -v "
  #        @cmdBase << " -o #{CGI.escape(taskErrOutFilesBase)}.out -e #{CGI.escape(taskErrOutFilesBase)}.err > #{taskErrOutFilesBase}.launch.output 2>&1 " if(taskErrOutFilesBase)
          @cmdBase << " -o genbTaskWrapper.out -e genbTaskWrapper.err > genbTaskWrapper.launch.output 2>&1 "
          @cmdBase << " & " # necessary to run in background, since genbTaskWrapper.rb will -detach- itself
          $stderr.puts "\nAPI CREATE BIGBED: #{@cmdBase.inspect}"
          # Execute command...should return right away
          $stderr.puts "BEFORE launching genbTaskWrapper => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
          `#{@cmdBase}`
          @cmdExitStatus = $?
          $stderr.puts "AFTER launching genbTaskWrapper => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
          $stderr.puts "\nAPI CREATE BIGBED FILE AS DETACHED BACKGROUND PROCESS. Exit status: #{@cmdExitStatus.exitstatus}"
          #return @cmdExitStatus
        end
        @statusName = :Accepted
        @statusMsg = "The bigBed file for this track will be generated.  Note that if there are a very large number of annotations, the job may be deferred until later in the day when resouces become available."
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end


    # Removes the bigBed file from disk.
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        path = BRL::Genboree::Abstract::Resources::UCSCBigFile.makeDirPath(@genbConf, @groupId, @refseqRecs.first['refSeqId'], @ftypeHash['ftypeid'])
        bbFullPath = "#{path}/#{@bbFileName}"
        FileUtils.rm_f(bbFullPath)
        @statusName, @statusMsg = :OK, "The bigbed file has been deleted for this resource."
      end
      # If something wasn't right, represent as error
      @resp = representError()
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS:
    #------------------------------------------------------------------



  end # class TrackBigBed
end ; end ; end # module BRL ; module REST ; module Resources
