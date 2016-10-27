#!/usr/bin/env ruby
require 'fileutils'
require 'brl/util/util'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/unlockedRefEntity.rb'
require 'brl/genboree/rest/em/deferrableBodies/deferrableUCSCBigFileBody'
require 'brl/genboree/abstract/resources/wigFile'
require 'brl/genboree/genboreeUtil'
require 'brl/cluster/clusterJob'
require 'brl/cluster/clusterJobManager'

module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace

  class TrackBigWig < BRL::REST::Resources::GenboreeResource
    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :get => true, :put => true, :delete => true, :head => true }
    RSRC_TYPE = 'bigWig'


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
      return %r{^/REST/v1/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/bigWig$}     # Look for /REST/v1/grp/{grp}/db/{db}/trk/{trk}/attribute/{attributeName}/[aspect] URIs
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
      if(initStatus == :OK)
        # Init the resource instance vars
        @genbConf = BRL::Genboree::GenboreeConfig.load()
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @trackName = Rack::Utils.unescape(@uriMatchData[3]).strip
        # Init URL vars
        @sendConfirmEmail = (@nvPairs['sendConfirmEmail'] == 'false') ? false : true
        # Init config vars
        @bwFileName = @genbConf.gbTrackAnnoBigWigFile
        @ftypeRow = nil
        # Init and check group & database exist and are accessible
        initStatus = initGroupAndDatabase()
        if(initStatus)
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
        end
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
    # For this resource a get reads the bigWig file that's stored on disk,
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
          # /data/genboree/dataFiles/grp/{groupId}/db/{refseqId}/trk/{trackName}/trackAnnos.bw

          path = BRL::Genboree::Abstract::Resources::UCSCBigFile.makeDirPath(@genbConf, @groupId, @refseqRecs.first['refSeqId'], @ftypeHash['ftypeid'])
          fileNameFull = "#{path}/#{@bwFileName}"
          if(File.exists?(fileNameFull))
            # Set response headers that are required by UCSC
            @resp['Last-Modified'] = File.mtime(fileNameFull).strftime("%a, %d %b %Y %H:%M:%S %Z")
            @resp['Content-Type'] = 'application/octet-stream'
            @resp['Accept-Ranges'] = 'bytes'
            # Debug message below. Can remove once stable
            #$stderr.puts "DEBUG: UCSC_bigWig: #{Time.now} : Request for #{@trackName.inspect} Received #{(headOnly)?"HEAD":"GET"} request for bigWig HTTP_RANGE: #{@req.env['HTTP_RANGE'].inspect}"
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
            @apiError = BRL::Genboree::GenboreeError.new(:'Not Found', "There is no bigWig file for this resource. PUT it first")
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

    # The PUT method for this resource initiates the process for creating the wig file.
    # Launch process that will
    #  - create wigFile
    #  - run UCSC convertor on the file.
    #
    def put()
      initStatus = initOperation()
      if(initStatus == :OK)
        # Create the directory
        path = BRL::Genboree::Abstract::Resources::UCSCBigFile.makeDirPath(@genbConf, @groupId, @refseqRecs.first['refSeqId'], @ftypeHash['ftypeid'])
        FileUtils.mkdir_p(path) unless(File.symlink?(path)) # If not present, false; if dir, false. (mkdir_p fails for symlinks)
        # First, let's get the dir of the file and cd to it. This will be helpful/safe when launching uploader process.
        FileUtils.cd(path)

        # Touch a file which is deleted when done.
        # presence of file indicates that the job is incomplete
        # There could be a situation where there is a bigwig file and a status file,
        # if the bigwig file was from a previous job
        FileUtils.touch('bigWig.jobSubmitted')
        gc = BRL::Genboree::GenboreeConfig.load
        useCluster = gc.useClusterForAPI
        # use TaskWrapper
        # URL escape the command and append it to a genbTaskWrapper command
        bwCmd = "#{gc.toolScriptPrefix}genbBigWigFile.rb" +
                " -g #{CGI.escape(@groupName)}" +
                " -d #{CGI.escape(@dbName)}" +
                " -t #{CGI.escape(@trackName)}" +
                " -b #{@bwFileName}" +
                " -z #{@bwFileName+'.tgz'}" +
                " -n #{@rsrcHost}"
        bigWigWrapperEmail = nil
        if(@sendConfirmEmail)
          userRows = @dbu.getUserByUserId(@userId)
          emailAddress = userRows.first['email']
          bwCmd += " -e #{emailAddress}"
          bigWigWrapperEmail = emailAddress
        end
        # should we use the cluster?
        if(useCluster != "true")
          bwCmd += " 2> genbBigWigFile.err "
          # Make task command:
          # -- note, it's safest to URL encode arguments to genbTaskWrapper.rb whose values are based on user-input (db names, user names, etc.)
          # -- they will be decoded automatically if detected
          # -- obviously, if the value contains an escape sequence itself, then it MUST be encoded (such that the string "Demo%20123" becomes "Demo%2520123" for example)
          @cmdBase =  "genbTaskWrapper.rb -y -c #{CGI.escape(bwCmd)} -g #{ENV['GENB_CONFIG']} "
          @cmdBase << " -v "
          @cmdBase << " -o genbTaskWrapper.out -e genbTaskWrapper.err > genbTaskWrapper.launch.output 2>&1 "
          @cmdBase << " & " # necessary to run in background, since genbTaskWrapper.rb will -detach- itself
          $stderr.puts "\nAPI CREATE BIGWIG: #{@cmdBase.inspect}"
          # Execute command...should return right away
          $stderr.puts "BEFORE launching genbTaskWrapper => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
          `#{@cmdBase}`
          @cmdExitStatus = $?
          $stderr.puts "AFTER launching genbTaskWrapper => (Mem: #{BRL::Util::MemoryInfo.getMemUsageStr()})"
          $stderr.puts "\nAPI CREATE BIGWIG FILE AS DETACHED BACKGROUND PROCESS. Exit status: #{@cmdExitStatus.exitstatus}"
          #return @cmdExitStatus
          @statusName = :Accepted
          @statusMsg = "The bigWig file for this track will be generated.  Note that if there are a very large number of annotations, the job may be deferred until later in the day when resouces become available."
        else # launch it on the cluster
          system("mkdir -p #{path}") # make sure the path exists
          suDbDbrc = BRL::Genboree::GenboreeUtil.getSuperuserDbrc()
          bwCmd = "wigToBigWigWrapper.rb -g #{CGI.escape(@groupName)} -d #{CGI.escape(@dbName)} -t #{CGI.escape(@trackName)} -b #{@bwFileName} -k #{suDbDbrc.key} -K #{gc.dbrcKey} -R #{@rsrcHost}"
          bwCmd << " -e #{bigWigWrapperEmail}" if(bigWigWrapperEmail)
          @jobId = "apiBigWigClusterJob-#{Time.now.to_f}"
          #clusterJob = BRL::Cluster::ClusterJob.new("#{@jobId}", nil, "gbApiHeavy", gc.clusterAdminEmail, false)
          clusterJob = BRL::Cluster::ClusterJob.new("#{@jobId}", nil, "gbMultiCore", gc.clusterAdminEmail, false)
          contextHash = {
            "pbsDirectives" => {
              "cores" => "-l nodes=1:ppn=4"
            }
          }
          clusterJob.jsonContextString = contextHash.to_json

          clusterJob.commands << CGI.escape(bwCmd)
          clusterJob.commands << CGI.escape("ssh #{gc.internalHostnameForCluster} 'rm -f #{path}/bigWig.jobSubmitted' ")
          clusterJobManager = BRL::Cluster::ClusterJobManager.new(gc.schedulerDbrcKey, gc.schedulerTable)
          @schedJobId = clusterJobManager.insertJob(clusterJob)
          @statusName = :Accepted
          @statusMsg = "Job: #{@jobId} with id: #{@schedJobId} inserted into the cluster queue."
          $stderr.puts "Job: #{@jobId} with id: #{@schedJobId} inserted into the cluster queue."
        end
      end
      # If something wasn't right, represent as error
      @resp = representError() if(@statusName != :OK)
      return @resp
    end


    # Removes the bigWig file from disk.
    def delete()
      initStatus = initOperation()
      if(initStatus == :OK)
        path = BRL::Genboree::Abstract::Resources::UCSCBigFile.makeDirPath(@genbConf, @groupId, @refseqRecs.first['refSeqId'], @ftypeHash['ftypeid'])
        bwFullPath = "#{path}/#{@bwFileName}"
        FileUtils.rm_f(bwFullPath)
        @statusName, @statusMsg = :OK, "The bigwig file has been deleted for this resource."
      end
      # If something wasn't right, represent as error
      @resp = representError()
      return @resp
    end

    #------------------------------------------------------------------
    # HELPERS:
    #------------------------------------------------------------------



  end # class TrackBigWig
end ; end ; end # module BRL ; module REST ; module Resources
#!/usr/bin/env ruby
