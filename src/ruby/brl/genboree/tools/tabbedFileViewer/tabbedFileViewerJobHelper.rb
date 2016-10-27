require 'json'
require 'brl/util/util'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/tools/workbenchJobHelper'
require 'brl/genboree/tools/uploadAnnotations/uploadAnnotationsJobHelper'

module BRL ; module Genboree ; module Tools
  class TabbedFileViewerJobHelper < WorkbenchJobHelper

    TOOL_ID = 'tabbedFileViewer'

    # Instance vars that should be overridden to launch the job
    def initialize(toolIdStr, genbConf=nil, dbu=nil, *args)
      super(toolIdStr, genbConf, dbu, args)
      self.class.commandName = "#{@genbConf.toolScriptPrefix}tabbedFileViewerUploadWrapper.rb"
    end

    def fillClientContext(wbJobEntity)
      wbJobEntity = super(wbJobEntity)

      # Specify our necessary context values
      header = Array.new()
      estRecords = 1
      sampleSize = 10
      sortMethodThreshold = 1_000_000
      sortMethod = 'quick'

      begin
        unless(wbJobEntity.inputs[0].nil?())
          matchData = nil

          # Currently we only support DatabaseFiles
          # TODO: Is this right? How would we handle any file? (project files...)
          if(wbJobEntity.inputs[0] =~ BRL::Genboree::REST::Helpers::FileApiUriHelper::NAME_EXTRACTOR_REGEXP)
            # Set our file path info in the context for our tool to use
            db = CGI.escape(@fileApiHelper.dbApiUriHelper.extractName(wbJobEntity.inputs[0]))
            grp = CGI.escape(@fileApiHelper.dbApiUriHelper.grpApiUriHelper.extractName(wbJobEntity.inputs[0]))
            file = CGI.escape(@fileApiHelper.extractName(wbJobEntity.inputs[0]))
            filePath = "#{@genbConf.gbDataFileRoot}/grp/#{grp}/db/#{db}/#{file}"
            wbJobEntity.context['file'] = filePath

            # Now try to read our header line to deliver to client
            # In an attempt to get the most accurate representation of the header line, we search the
            # comments lines (what constitutes the header block) and split to find a line that
            # contains the same number of columns as the first data row (split on the tab). This is
            # used as the header line and column names are derived from that line.
            if(File.file?(filePath))
              file = File.new(filePath)
              readLine = file.readline().chomp()
              headerLines = Array.new()
              numOfDataCols = 0
              dataLine = nil
              matchData = nil
              lffReqNum = 10

              # Because our data file could be large (or massive), we process line by line until we reach data
              while(dataLine.nil? and !readLine.nil? and !file.eof?)
                if(matchData = readLine.match(%r{^\s*#+(.+)}))
                  headerLines << readLine
                  readLine = file.readline().chomp()
                else
                  dataLine = readLine
                  numOfDataCols = dataLine.split("\t").size()
                end
              end

              headerLines.each { |headerLine|
                # Perform tests to see if we have a suspect header line
                # 1. Check for 'Fields: <a>, <b>, <c> which follows the Blast tab delimited format
                # 2. Check the number of data columns versus header columns (split on \t)
                if((matchData = headerLine.match(%r{^\s*#+\s*Fields\s*:\s*((?:[^,]+,?\s*)+)})) and (matchData[1].split(',').size() == numOfDataCols))
                  header = matchData[1].split(',').map { |col| col.to_s().strip().capitalize() }
                  break
                elsif((matchData = headerLine.match(%r{^\s*#+(.+)})) and (matchData[1].split("\t").size() >= lffReqNum))
                  # We have a header that at least has the required number of LFF fields, we make a guess that this is an LFF header line and go with it
                  # This is a pretty safe assumption as if the line has more than 10 fields that are tab separated, it is probably a header line anyways
                  header = matchData[1].split("\t").map { |col| col.to_s().strip().capitalize() }
                  break
                end
              }

              if(header.empty?())
                # We did not find a header row that matched our columns, so use a generic header
                1.upto(dataLine.split("\t").size()) { |num|
                  header << getGeneralColumnHeader(num)
                }
              end
              file.rewind()

              # Attempt to set the sort method by estimating the number of records
              count = 0
              totRecLength = 0

              while(count < sampleSize)
                begin
                  line = file.readline()
                  next if(line.match(%r{^\s*(#.*|$)$}))

                  totRecLength += file.readline().length()
                  count += 1
                rescue EOFError
                  # Do nothing, we are finished
                  break
                end
              end

              estRecords = (totRecLength == 0) ? 0 : (file.stat().size() / (totRecLength / 10))
            end

            wbJobEntity.context['header'] = header
            wbJobEntity.context['sortMethod'] = (estRecords <= sortMethodThreshold) ? 'quick' : 'long'


            # Set our track info in case they want to upload annotation to an existing track
            # NOTE: We need to unescape our strings here because they come from the escaped URI
            # TODO: Could this be done in a better way? Ajax when the user decides they want
            #       to upload instead of taking the time here?
            trackInfo = BRL::Genboree::Tools::UploadAnnotationsJobHelper::getTrackInfo(CGI.unescape(db), CGI.unescape(grp), @genbConf)

            # Make our tracks available to the client
            wbJobEntity.context['tracks'] = trackInfo['tracks']

            # When the upload is actually performed, we will also need groupName/Id and refseqName/Id, send along now since we have them
            wbJobEntity.context['groupName'] = trackInfo['grpName']
            wbJobEntity.context['groupId'] = trackInfo['grpId']
            wbJobEntity.context['refseqName'] = trackInfo['dbName']
            wbJobEntity.context['refseqId'] = trackInfo['refSeqId']
          end
        end
      rescue RuntimeError => e
        # Any excepion here should be of a server error nature
        @workbenchJobObj.context['wbErrorName'] = :'Internal Server Error'
        @workbenchJobObj.context['wbErrorMsg'] = e.message + ' Please contact your Genboree administrator.'
        @workbenchJobObj.context['wbErrorDetails'] = e.backtrace.join("<br/>\n")
      end

      return wbJobEntity
    end

    def cleanJobObj(workbenchJobObj)
      workbenchJobObj = super(workbenchJobObj)
      genbConf = ENV['GENB_CONFIG']
      genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
      workbenchJobObj.settings['dbuKey'] = genbConfig.dbrcKey
      return workbenchJobObj
    end

    def getGeneralColumnHeader(colNum)
      colHeader = ''

      if(colNum > 26)
        # Determine what our base is, one deep (A), two deep (AA), three deep (AAA), etc
        base = (colNum - 1) / 26
        colHeader = getGeneralColumnHeader(base)
        colHeader += getGeneralColumnHeader(colNum - (26 * base))
      else
        colHeader = (colNum + 64).chr
      end

      return colHeader
    end
  end
end ; end ; end # module BRL ; module Genboree ; module Tools
