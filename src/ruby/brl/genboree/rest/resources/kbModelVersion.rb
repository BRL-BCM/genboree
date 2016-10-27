#!/usr/bin/env ruby

require 'brl/genboree/rest/resources/kbModelVersions'
require 'brl/genboree/kb/kbDoc'

module BRL ; module REST ; module Resources

  class KbModelVersion < BRL::REST::Resources::KbModelVersions
  
    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbModelVersion'
    PREDEFINED_VERS = ['PREV', 'CURR', 'HEAD']
    def cleanup()
      super()
      @version = nil
    end

    def self.pattern()
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/model/ver/([^/\?]+)}
    end

    def self.priority()
      return 9
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @version = Rack::Utils.unescape(@uriMatchData[4]).to_s.strip
        if(PREDEFINED_VERS.include?(@version))
          @version = @version
        else
          @version = @version.to_f
        end        
        @diffVersion = (  @nvPairs['diffVersion']  ? @nvPairs['diffVersion'] : false )
        if(@diffVersion)
          @diffVersion.strip!
          if(PREDEFINED_VERS.include?(@diffVersion))
            @diffVersion = @diffVersion
          else
            @diffVersion = @diffVersion.to_f
          end
        end
        @tabbedFormat = @nvPairs['tabbedFormat'].to_s.upcase.to_sym if(@nvPairs['tabbedFormat'])
        @tabbedFormat = :TABBED_PROP_NESTING unless(@tabbedFormat)
      end
      return initStatus
    end

    def get()
      begin
        @docId = initPath()
        versionsHelper = @mongoKbDb.versionsHelper('kbModels') rescue nil
        if(versionsHelper.nil?)
          @statusName = :"Internal Server Error"
          @statusMsg = "Failed to access versions collection for collection: 'kbModels'"
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end
        dbRef = BSON::DBRef.new('kbModels', @docId)
        # get specified version of the document
        allVers = nil
        if(PREDEFINED_VERS.include?(@version))
          allVers = versionsHelper.allVersions(dbRef)
          if(@version == 'HEAD' or @version == 'CURR')
            versionDoc = allVers.last
          else # PREV
            # Make sure the doc has more than one version to return the 'PREV' version
            if(allVers.size > 1)
              versionDoc = allVers[allVers.size-2]
            else
              @statusName = :"Not Found"
              @statusMsg = "There is no 'PREV' version for this model document. There is only one version (HEAD) for this document."
              raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)            
            end
          end
        else
          versionDoc = versionsHelper.getVersion(@version, dbRef)
        end
        if(versionDoc.nil?)
          @statusName = :"Not Found"
          @statusMsg = "Requested version #{@version} for the model does not exist."
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end
        unless(@diffVersion)
          versionEntity = BRL::Genboree::REST::Data::KbDocVersionEntity.from_json(versionDoc)
          @statusName = configResponse(versionEntity) # sets @resp
        else
          @repFormat = :UDIFF if(@repFormat == :JSON) # Override the default format when doing udiffs
          if(@repFormat != :UDIFF and @repFormat != :UDIFFHTML)
            @statusName = :'Bad Request'
            @statusMsg = "UNSUPPORTED_FORMAT: The diff format you provided is not supported. Supported formats include udiff and udiffhtml"
            raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          end
          # Get the doc to diff against
          if(PREDEFINED_VERS.include?(@diffVersion))
            unless(allVers)
              allVers = versionsHelper.allVersions(dbRef)
            end
            if(@diffVersion == 'HEAD' or @diffVersion == 'CURR')
              diffVersionDoc = allVers.last
            else # PREV
              # Make sure the doc has more than one version to return the 'PREV' version
              if(allVers.size > 1)
                diffVersionDoc = allVers[allVers.size-2]
              else
                @statusName = :"Not Found"
                @statusMsg = "There is no 'PREV' version for this model document. There is only one version (HEAD) for this document."
                raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)            
              end
            end
          else
            diffVersionDoc = versionsHelper.getVersion(@diffVersion, dbRef)
          end
          if(diffVersionDoc.nil?)
            @statusName = :"Not Found"
            @statusMsg = "Requested version #{@diffVersion}  does not exist."
            raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          end
          # Extract the 'document' part (content) from the version
          versionModelDoc = versionDoc.getPropVal('versionNum.content')
          diffVersionModelDoc = diffVersionDoc.getPropVal('versionNum.content')
          # Instantiate the KbDoc class with the two versions and remove unwanted keys
          kbDocVersion = BRL::Genboree::KB::KbDoc.new(versionModelDoc)
          kbDocDiffVersion = BRL::Genboree::KB::KbDoc.new(diffVersionModelDoc)
          modelVerDoc = kbDocVersion.getPropVal('name.model')
          modelDiffVerDoc = kbDocDiffVersion.getPropVal('name.model')
          # Produce tabbed versions of the docs to do to a diff
          diff = ""
          versionModelDocTabbed = ""
          diffVersionModelDocTabbed = ""
          producer = ( @tabbedFormat == :TABBED_PROP_NESTING ? BRL::Genboree::KB::Producers::NestedTabbedModelProducer.new() : BRL::Genboree::KB::Producers::FullPathTabbedModelProducer.new() )
          producer.produce(modelVerDoc) { |line| versionModelDocTabbed << "  #{line}\n" }
          producer.produce(modelDiffVerDoc) { |line| diffVersionModelDocTabbed << "  #{line}\n" }
          # For a HTML response, no configResponse() is required
          if(@repFormat == :UDIFFHTML)
            diff = Diffy::Diff.new(versionModelDocTabbed, diffVersionModelDocTabbed, :include_plus_and_minus_in_html => true, :include_diff_info => true, :context => 50_000 ).to_s(:html)
            resp = "<div>No differences found</div>"
            if(!diff.empty?)
              resp = ""
              diff.each_line { |line|
                if(line =~ /<span>---/)
                  resp << "<li><span>--- <b>#{@collName} - Model</b> <span class=\"del\">(Global version Id: #{@version})</span></span></li>\n"
                elsif(line =~ /<span>\+\+\+/)
                  resp << "<li><span>--- <b>#{@collName} - Model</b> <span class=\"del\">(Global version Id: #{@diffVersion})</span></span></li>\n"
                else
                  resp << line
                end
              }
              resp = ( resp =~ /li/ ? resp : "<div>No differences found</div>" )
            end
            @statusName = :OK
            @resp.status = HTTP_STATUS_NAMES[@statusName]
            @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:HTML]
            if(@resp.body.respond_to?(:size))
              @resp['Content-Length'] = @resp.body.size.to_s
            end
            @resp.body = resp
          else # default to :text
            diff = Diffy::Diff.new(versionModelDocTabbed, diffVersionModelDocTabbed, :include_diff_info => true, :context => 50_000).to_s(:text)
            resp = ""
            if(diff.empty?)
              resp = "No Difference found."
            else # Replace diffy's process names in the header lines with version numbers
              lcount = 0
              diff.each_line { |line|
                if(lcount == 0)
                  resp << "--- #{@collName} - Model (Global Version Id: #{@version})\n"
                elsif(lcount == 1)
                  resp << "--- #{@collName} - Model (Global Version Id: #{@diffVersion})\n"
                else
                  resp << line
                end
                lcount += 1  
              }
            end
            @statusName = :OK
            @resp.status = HTTP_STATUS_NAMES[@statusName]
            @resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:TEXT]
            if(@resp.body.respond_to?(:size))
              @resp['Content-Length'] = @resp.body.size.to_s
            end
            @resp.body = resp
          end
        end
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace)
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end
  end
end ; end ; end
