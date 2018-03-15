#!/usr/bin/env ruby

require 'brl/genboree/rest/data/numericEntity'
require 'brl/genboree/rest/resources/kbDocVersions'
require 'brl/genboree/kb/kbDoc'

module BRL ; module REST ; module Resources
  class KbDocVersion < BRL::REST::Resources::KbDocVersions

    HTTP_METHODS = { :get => true }
    RSRC_TYPE = 'kbDocVersion'
    PREDEFINED_VERS = ['PREV', 'CURR', 'HEAD' ]
    SUPPORTED_ASPECTS = {
      'versionNum' => true
    }
    DEFAULT_VERSION_REC_FIELDS = [
      'versionNum.value',
      'versionNum.properties.timestamp.value',
      'versionNum.properties.author.value',
      'versionNum.properties.docRef.value'
    ]
    DEFAULT_DIFF_FIELDS = [ 'versionNum.properties.content.value' ] # The content.value is the versioned doc

    def cleanup()
      super()
      @version = nil
    end

    def self.pattern()
      # In addtion to an 'aspect', also supports specifying some specific version record fields via 'versionFields' and, separately,
      #   some specific content fields via 'contentFields'; both use KbDoc prop paths. Furthermore, can specify whether to get
      #   the full sub-trees ('valueObj') or just the value ('valueOnly') for the version fields via 'versionFieldsValue' and,
      #   separately, for the content fields via 'contentFieldsValue'.
      #   The versionFields or contentFields values are CSV--if you have internal commas within the field names, you need to
      #   escape them with a real backslash (i.e. TWO-character sequence \, will protect them in the CSV) when building your URL.
      return %r{^/REST/#{VER_STR}/grp/([^/\?]+)/kb/([^/\?]+)/coll/([^/\?]+)/doc/([^/\?]+)/ver/([^/\?]+)(?:$|/([^/\?]+)$)}
    end

    def self.priority()
      return 9
    end

    def initOperation()
      $stderr.debugPuts(__FILE__, __method__, 'TIME', "Entered.") ; tt = Time.now
      initStatus = super() # This will set usual @gbGroup, @gbKb, @collName, etc, and do initGroupAndKb() and initColl()
      if(initStatus == :OK)
        # Version the request is for:
        @version = Rack::Utils.unescape(@uriMatchData[5]).to_s.strip.upcase
        @aspect = (@uriMatchData[6].nil?) ? nil : Rack::Utils.unescape(@uriMatchData[6])
        if(PREDEFINED_VERS.include?(@version))
          @version = @version
        else
          @version = @version.to_f
        end

        # Look for versionNumOnly (old way was via param, new way is via '/versionNum' aspect)
        if( !@detailed or @aspect == 'versionNum' or ( @nvPairs.key?('versionNumOnly') and @nvPairs['versionNumOnly'].to_s.autoCast(true) == true ) )
          @versionNumOnly = true
        else
          @versionNumOnly = false
        end

        # Look for version diffing info
        @diffVersion = (  @nvPairs['diffVersion']  ? @nvPairs['diffVersion'] : false )
        if(@diffVersion)
          @diffVersion = @diffVersion.to_s.strip.upcase
          if(PREDEFINED_VERS.include?(@diffVersion))
            @diffVersion = @diffVersion
          else
            @diffVersion = @diffVersion.to_f
          end
        end

        # Looks for tabbedFormat request
        @tabbedFormat = @nvPairs['tabbedFormat'].to_s.upcase.to_sym if(@nvPairs['tabbedFormat'])
        @tabbedFormat = :TABBED_PROP_NESTING unless(@tabbedFormat)
      end

      $stderr.debugPuts(__FILE__, __method__, 'TIME', " done method in #{Time.now.to_f - tt.to_f}sec") ; tt = Time.now
      return initStatus
    end

    def get()
      begin
        tt = Time.now
        initPath()
        $stderr.debugPuts(__FILE__, __method__, 'TIME', "initPath done for #{@docName.inspect} and version #{@version.inspect} - accum'd time #{Time.now.to_f - tt.to_f}")  ; tt = Time.now
        dataHelper = @mongoDch # from initColl()
        if(@versionsHelper.nil?)
          @statusName = :"Internal Server Error"
          @statusMsg = "Failed to access versions collection for data collection #{@collName}"
          raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
        end
        # get specified version of the document
        # A. Is this a request for @versionNumOnly ? Simple and efficient to handle.
        if( @versionNumOnly )
          versionNum = @versionsHelper.getVersionNum( @version, @docDbRef )
          if( versionNum )
            versionEntity = BRL::Genboree::REST::Data::NumericEntity.new(@connect, versionNum.to_i)
          else
            @statusName = :"Not Found"
            @statusMsg = "Requested version #{@version.inspect} for the document #{@docName.inspect} does not exist."
            raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          end

          $stderr.debugPuts(__FILE__, __method__, 'TIME', "got just versionNum #{versionNum.inspect} for #{@docName.inspect} (about to configResponse) - #{Time.now.to_f - tt.to_f}") ; tt = Time.now
          @statusName = configResponse(versionEntity) # sets @resp
        else # B. being asked for the version doc itself or possibly a diff result.
          # Are we asked for specific props in the record only? This is only available if saying detailed=true.
          if( @detailed )
            @desiredFields = buildAllOutputFields( true )
            $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "The expanded desired props are:\n\t#{@desiredFields.join("\n\t") rescue '[NONE]'}")
          else # Not detailed, so fields spec is irrelevant
            @versionFields = @contentFields = @desiredFields = nil
          end

          versionDoc = @versionsHelper.getVersionDoc( @version, @docDbRef, @desiredFields )
          $stderr.debugPuts(__FILE__, __method__, 'TIME', "got whole version doc for version #{@version.inspect} (#{versionDoc.class}) of #{@docName.inspect} in #{Time.now.to_f - tt.to_f} ; it has these paths:\n\n#{versionDoc.allPaths.inspect rescue '[FAIL]'}\n\n") ; tt = Time.now

          if( versionDoc.nil? )
            @statusName = :"Not Found"
            @statusMsg = "Requested version #{@version.inspect} for the document #{@docName.inspect} does not exist."
            raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
          else
            if( !@diffVersion ) # Client just wants the version doc/info. No udiff.
              $stderr.debugPuts(__FILE__, __method__, 'TIME', "non-nil versionDoc for #{@version.inspect} of #{@docName.inspect}\n\n#{versionDoc.inspect}\n\n")
              versionEntity = BRL::Genboree::REST::Data::KbDocVersionEntity.from_json(versionDoc)
              $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "versionEntity:\n\n#{versionEntity.inspect}\n\n")
              $stderr.debugPuts(__FILE__, __method__, 'TIME', "we got the whole record for #{@version.inspect} of #{@docName.inspect}, now prepped as a KbDocVersionEntity - #{Time.now.to_f - tt.to_f}") ; tt = Time.now
              @statusName = configResponse(versionEntity) # sets @resp
            else # Client wants a udiff between two versions of a document.
              $stderr.debugPuts(__FILE__, __method__, 'TIME', "Doing some udiff thing of #{@version.inspect} vs #{@diffVersion.inspect}, no more timing - #{Time.now.to_f - tt.to_f}") ; tt = Time.now

              # NOT OPTIMIZED. ORIGINAL CODE, including use of "allVers" (O(N) performance)
              #   when getting specific version docs (O(1) performance) should have been done instead.
              @repFormat = :UDIFF if(@repFormat == :JSON) # Override the default format when doing udiffs
              $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "@repFormat: #{@repFormat.inspect}")
              if(@repFormat != :UDIFF and @repFormat != :UDIFFHTML)
                @statusName = :'Bad Request'
                @statusMsg = "UNSUPPORTED_FORMAT: The diff format you provided is not supported. Supported formats include udiff and udiffhtml"
                raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
              end
              # Get the doc to diff against
              @desiredFields = DEFAULT_DIFF_FIELDS unless( @desiredFields.is_a?(Array) )
              diffVersionDoc = @versionsHelper.getVersionDoc( @diffVersion, @docDbRef, @desiredFields )

              if( @diffVersion == 'PREV' and diffVersionDoc.nil? )
                @statusName = :"Not Found"
                @statusMsg = "There is no 'PREV' version for this document. There is only one version (HEAD) for this document."
                raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
              end

              if(diffVersionDoc.nil?)
                @statusName = :"Not Found"
                @statusMsg = "Requested version to diff against: #{@diffVersion} for the document #{@docName} does not exist."
                raise BRL::Genboree::GenboreeError.new(@statusName, @statusMsg)
              else
                # Extract the 'document' part (content) from the version
                versionDoc = versionDoc.getPropVal('versionNum.content')
                diffVersionDoc = diffVersionDoc.getPropVal('versionNum.content')
                $stderr.debugPuts(__FILE__, __method__, 'DEBUG', ">>>> DIFF this versionDoc:\n\n#{versionDoc.inspect}\n\n>>>> vs this diffVersionDoc:\n\n#{diffVersionDoc.inspect}\n\n")
                # Instantiate the KbDoc class with the two versions and remove unwanted keys
                docKbVersion = BRL::Genboree::KB::KbDoc.new(versionDoc)
                docKbDiffVersion = BRL::Genboree::KB::KbDoc.new(diffVersionDoc)
                docKbVersion.cleanKeys!(BRL::Genboree::REST::EM::DeferrableBodies::DeferrableKbDocsBody::KEYS_TO_CLEAN)
                docKbDiffVersion.cleanKeys!(BRL::Genboree::REST::EM::DeferrableBodies::DeferrableKbDocsBody::KEYS_TO_CLEAN)
                # Make sure the order of the props in the doc follows the model
                versionDoc = dataHelper.transformIntoModelOrder(versionDoc, { :doOutCast => true, :castToStrOK => true})
                diffVersionDoc = dataHelper.transformIntoModelOrder(diffVersionDoc, { :doOutCast => true, :castToStrOK => true})
                # Produce tabbed versions of the docs to do to a diff
                diff = ""
                versionDocTabbed = ""
                diffVersionDocTabbed = ""
                producer = ( @tabbedFormat == :TABBED_PROP_NESTING ? BRL::Genboree::KB::Producers::NestedTabbedDocProducer.new(@model) : BRL::Genboree::KB::Producers::FullPathTabbedDocProducer.new(@model) )
                producer.produce(versionDoc) { |line| versionDocTabbed << "  #{line}\n" }
                producer.produce(diffVersionDoc) { |line| diffVersionDocTabbed << "  #{line}\n" }
                # For a HTML response, no configResponse() is required
                if(@repFormat == :UDIFFHTML)
                  $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Doing HTML Udiff via Diffy ...")
                  diff = Diffy::Diff.new(versionDocTabbed, diffVersionDocTabbed, :include_plus_and_minus_in_html => true, :include_diff_info => true, :context => 50_000 ).to_s(:html)
                  $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "diff: #{diff.class} ; empty? #{diff.empty?.inspect}")
                  resp = ""
                  if(!diff.empty?)
                    diff.each_line { |line|
                      if(line =~ /<span>---/)
                        resp << "<li><span>--- <b>#{@docName}</b> <span class=\"del\">(Global version Id: #{@version})</span></span></li>\n"
                      elsif(line =~ /<span>\+\+\+/)
                        resp << "<li><span>+++ <b>#{@docName}</b> <span class=\"ins\">(Global version Id: #{@diffVersion})</span></span></li>\n"
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
                else # default to :udiff
                  diff = Diffy::Diff.new(versionDocTabbed, diffVersionDocTabbed, :include_diff_info => true, :context => 50_000).to_s(:text)
                  resp = ""
                  if(diff.empty?)
                    resp = "No Difference found."
                  else # Replace diffy's process names in the header lines with version numbers
                    lcount = 0
                    diff.each_line { |line|
                      if(lcount == 0)
                        resp << "--- #{@docName} (Global Version Id: #{@version})\n"
                      elsif(lcount == 1)
                        resp << "+++ #{@docName} (Global Version Id: #{@diffVersion})\n"
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
            end
          end
        end
      rescue => err
        if(err.is_a?(BRL::Genboree::GenboreeError))
          @statusName = err.type
          @statusMsg = err.message
        else
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.message)
          $stderr.debugPuts(__FILE__, __method__, "API_ERROR", err.backtrace.join("\n"))
          @statusName = :"Internal Server Error"
          @statusMsg = err.message
        end
      end
      @resp = representError() unless((200..299).include?(HTTP_STATUS_NAMES[@statusName]))
      return @resp
    end
  end

  # ----------------------------------------------------------------
  # HELPERS
  # ----------------------------------------------------------------

end ; end ; end
