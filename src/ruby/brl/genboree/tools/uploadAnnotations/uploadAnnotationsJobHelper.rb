require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/workbenchJobHelper'
require 'brl/genboree/helpers/expander'
require 'brl/genboree/helpers/fileUploadUtils'
require "brl/genboree/rest/helpers/fileApiUriHelper"
require "brl/genboree/rest/helpers/databaseApiUriHelper"

module BRL ; module Genboree ; module Tools
  class UploadAnnotationsJobHelper < WorkbenchJobHelper
    include BRL::Genboree::Helpers
    TOOL_LABEL = :hidden
    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
    end

    # Override the fillClientContext method to add tracks for the specified output DB
    # for the client, so it can check if the track exists in the UI
    def fillClientContext(wbJobEntity)
      wbJobEntity = super(wbJobEntity)
      outputDbUri = wbJobEntity.outputs[0]

      # If we have no outputDb, the rules helper should fail and show the help dialog, so just return
      return wbJobEntity if(outputDbUri.nil? or outputDbUri.empty?)

      # Connect to our appropriate db
      begin
        # Get our dbName and grpName so we can gather tracks
        dbName = @dbApiHelper.extractName(outputDbUri)
        grpName = @dbApiHelper.grpApiUriHelper.extractName(outputDbUri)
        trackInfo = self.class.getTrackInfo(dbName, grpName, @genbConf)

        # Make our tracks available to the client
        wbJobEntity.context['tracks'] = trackInfo['tracks']

        # When the upload is actually performed, we will also need groupName/Id and refseqName/Id, send along now since we have them
        wbJobEntity.context['groupName'] = trackInfo['grpName']
        wbJobEntity.context['groupId'] = trackInfo['grpId']
        wbJobEntity.context['refseqName'] = trackInfo['dbName']
        wbJobEntity.context['refseqId'] = trackInfo['refSeqId']
      rescue RuntimeError => e
        # Any excepion here should be of a server error nature
        @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
        @workbenchJobObj.context['wbErrorMsg'] = e.message + ' Please contact your Genboree administrator.'
        @workbenchJobObj.context['wbErrorDetails'] = e.backtrace.join("<br/>\n")
      end

      return wbJobEntity
    end

    def executionCallback()
      return Proc.new() { |workbenchJobObj|
        debug = true
        success = true

        # Get required server information that the job will need
        @workbenchJobObj = fillServerContext(workbenchJobObj)
        settings = @workbenchJobObj.settings
        context = @workbenchJobObj.context
        annotFileRsrc = @workbenchJobObj.inputs.first()
        useCluster = (@genbConf.useClusterForGBUpload == "true" || @genbConf.useClusterForGBUpload == "yes")

        begin
          # NOTE: All of these upload scripts have varying levels of escaping which becomes problematic when a variable actually
          # needs proper escaping (for example, VGP Hg18 for Test => VGP%20Hg18%20for%20Test). Also, the  upload logs and
          # gzip'ping of files assumes that the current working directory is acceptable. For the workbench files, this will not be ok
          # as our workbench visible directory structure will be pollutated. To get around all of these issues, we instead start
          # by copying our designated data file to the temporary genboreeUploads directory and operate all of the annotation
          # uploading from there. This has the added benefit that all troubleshooting for annot. uploads (be it from workbench or web)
          # can be performed similarly with files in the expected locations (mainly the genboreeUploads/ path)
          # Initialize our uploads location
          dbUtil = BRL::Genboree::DBUtil.new(@genbConf.dbrcKey, nil)
          refseq = dbUtil.selectRefseqById(context['refseqId'])
          if(refseq.nil? or refseq.empty?)
            # We should never have this error, but check to be safe
            raise RuntimeError.new("User database for ID '#{context['refseqId']}' could not be found!")
          else
            refseq = refseq.first()
          end
          uploadDir = FileUploadUtils.createFinalDir(BRL::Genboree::Constants::UPLOADDIRNAME, refseq['databaseName'], context['userLogin'])
          $stderr.puts("Genboree uploads directory => #{uploadDir}") if(debug)

          # Need to extract file name from uri - The actual data file path looks like:
          # <gbDataFileRoot>/grp/<HTML escaped grpName>/db/<HTML escaped dbName>/<file>
          # NOTE: The passed dbName, grpName, refseqId all refer to our OUTPUT db, so we need to get our input file grp/db from the input resource
          dbName = @fileApiHelper.dbApiHelper.extractName(annotFileRsrc)
          grpName = @fileApiHelper.dbApiHelper.grpApiUriHelper.extractName(annotFileRsrc)
          inputFile = "#{@genbConf.gbDataFileRoot}/grp/#{CGI.escape(grpName)}/db/#{CGI.escape(dbName)}/#{@fileApiHelper.extractName(annotFileRsrc)}"

          # Now copy our source file to our genboreeUploads location
          cpCmd = "cp #{inputFile} #{uploadDir} 2>&1"
          $stderr.puts("Copy command for src file to genboree uploads => #{cpCmd}") if(debug)
          output = `#{cpCmd}`
          raise RuntimeError.new("An error occurred while trying to copy the source file to genboree uploads location: #{output}") unless(output.empty?)

          # Copy executed, we need to update our input file so it points to the newly created file in genboree uploads
          inputFile = "#{uploadDir}/#{File.basename(inputFile)}"

          # Handle the compression settings
          # NOTE: This code is taken from htdocs/genboree/upload.rhtml
          expanderObj = Expander.new(inputFile)
          expanderObj.debug = false
          inflateCmd = expanderObj.getInflateCmd()
          if(inflateCmd)
            if(useCluster)
              # inflateCmd will have THIS machine's dirs in path to file. We want those to be "current working dir"
              # wherever the job is being run:
              pathOnly = File.dirname(inputFile)
              inflateCmd.gsub!(pathOnly, ".")
            end
            nameOfExtractedFile = expanderObj.uncompressedFileName
            $stderr.puts("DEBUG: inflateCmd => #{inflateCmd.inspect}") if(debug)
          else
            nameOfExtractedFile = inputFile
          end

          # Set some final values in specOpts now that we have calculated it
          context['specOpts']['inflateCmd'] = inflateCmd
          context['specOpts']['hostname'] = @genbConf.internalHostnameForCluster

          # If we are not going to work on the cluster, we have to expand our file now
          expanderObj.extract() if(inflateCmd and not useCluster)

          # All information should be gathered, perform the actual upload
          success = FileUploadUtils.upload(context['inputFormat'], nameOfExtractedFile, inputFile, context['userId'], context['refseqId'], useCluster, @genbConf, context['specOpts'], debug)
        rescue => e
          success = false
          $stderr.puts("An error occurred while trying to upload annotations from the Genboree Workbench: #{e}\n #{e.backtrace.join()}")
        end

        success
      }
    end

    def self.getTrackInfo(dbName, grpName, genbConf)
      trackInfo = Hash.new()

      # Connect to our appropriate db
      begin
        dbUtil = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil)

        # To get the appropriate tracks, we need to connect to the right databse for the group
        group = dbUtil.selectGroupByName(grpName)
        if(group.nil? or group.empty?)
          # We should never have this error, but check to be safe
          raise RuntimeError.new("The group '#{grpName}' could not be found in the database!")
        else
          group = group.first()
        end

        refseq = dbUtil.selectRefseqByNameAndGroupId(dbName, group['groupId'])
        if(refseq.nil? or refseq.empty?)
          # We should never have this error, but check to be safe
          raise RuntimeError.new("User database for '#{dbName}' could not be found!")
        else
          refseq = refseq.first()
        end

        # With refseq name, set dataDbName, needed to get tracks for the db/group
        dbUtil.setNewDataDb(refseq['databaseName'])

        # Now get all our tracks, loop through them building a hash
        tracks = Array.new()
        dbTracks = dbUtil.selectAllFtypes()
        unless(dbTracks.nil?)
          dbTracks.each_with_index { |ftype, index|
            # We need to pass the class along for inserts
            ftypeClass = dbUtil.selectAllFtypeClasses(ftype['ftypeid']).first()

            # If for some reason we did not get a class for this ftype, we need to skip it and move on
            next if(ftypeClass.nil?)

            # NOTE: Does the track name need to be escaped?
            # NOTE: If so, use CGI.escape since it is extended in brl/util/util.rb to properly convert '+' to '%20' (used throughout Genboree)
            tracks << [ index, ftype['fmethod'] + ':' + ftype['fsource'], ftypeClass['gclass'] ]
            #tracks << { 'trackName' => CGI.escape(ftype['fmethod']) + ':' + CGI.escape(ftype['fsource']), 'class' => ftypeClass['gclass'] }
          }
        end

        trackInfo['tracks'] = tracks
        trackInfo['grpName'] = grpName
        trackInfo['grpId'] = group['groupId']
        trackInfo['dbName'] = dbName
        trackInfo['refSeqId'] = refseq['refSeqId']
      rescue => e
        $stderr.puts "[ERROR] Tracks could not be gathered: #{e}\n #{e.backtrace.join()}"
        raise RuntimeError.new("The tracks could not be gathered for this group and database")
      end

      return trackInfo
    end

  end
end ; end ; end # module BRL ; module Genboree ; module Tools
