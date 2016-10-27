#!/usr/bin/env ruby
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/hashEntity'

#--
module BRL ; module REST ; module Resources                # <- resource classes must be in this namespace
#++

  # TracksSettings - get/set/delete track color, styles, etc
  #
  # Data representation classes used:
  class TracksSettings < BRL::REST::Resources::GenboreeResource
    include BRL::Genboree::Abstract::Resources

    # INTERFACE: Map of what http methods this resource supports ( <tt>{ :get => true, :put => false }</tt>, etc } ).
    # Empty default means all are inherently false). Subclasses will override this, obviously.
    HTTP_METHODS = { :put => true, :get => true, :delete => true }
    SUPPORTED_ASPECTS = {'color' => nil, 'style' => nil, 'defaultStyle' => nil, 'defaultColor' => nil, 'order' => nil, 'defaultOrder' => nil, 'urlDescLabel' => nil}
    # INTERFACE. CLEANUP: Inheriting classes should also implement any specific
    # cleanup that might save memory and aid GC. Their version should call super()
    # so any parent cleanup() will be done also.
    # [+returns+] +nil+
    def cleanup()
      super()
      @refseqRow.clear() if(@refseqRow)
      @refseqRow = @entityName = @dbName = @refSeqId = @groupId = @groupName = nil
    end

    # INTERFACE: return a Regexp that will match a correctly formed URI for this resource
    # The pattern will be applied against the URI's _path_.
    # [+returns+] This +Regexp+: <tt>^/REST/#{VER_STR}/grp/([^/\?]+)/db/([^/\?]+)/trk/([^/\?]+)/attribute/([^/\?]+)(?:/([^/\?]+))?</tt>
    def self.pattern()
      return %r{^/REST/v1/grp/([^/\?]+)/db/([^/\?]+)/trks/(color|defaultColor|style|defaultStyle|order|defaultOrder|url|urlLabel|urlDescription|urlDescLabel)$}     # Look for /REST/v1/grp/{grp}/db/{db}/trks/aspect URIs
    end

    # INTERFACE: return integer from 1 to 10 that indicates whether the regexp/resource is
    # highly specific and should be examined early on, or whether it is more generic and
    # other resources should be matched for first.
    #
    # This class needs to be a higher priority than BRL::REST::Resources::Track
    # so that 'attribute' will be considered a resource and handled by this class as opposed to a track aspect
    #
    # [+returns+] The priority, from 1 to 10.
    def self.priority()
      return 8  # This is a pretty dedicated and specific URL, process it before any generic aspect type patterns
    end

    def initOperation()
      initStatus = super()
      if(initStatus == :OK)
        @groupName = Rack::Utils.unescape(@uriMatchData[1])
        @dbName = Rack::Utils.unescape(@uriMatchData[2])
        @aspect = Rack::Utils.unescape(@uriMatchData[3])
        if(!SUPPORTED_ASPECTS.has_key?(@aspect))
          initStatus = @statusName = :'Bad Request'
          @statusMsg = "BAD_REQUEST: Unknown aspect: #{@aspect.inspect}. Supported aspects include: (#{SUPPORTED_ASPECTS.keys.join(",")})"
        else
          initStatus = initGroupAndDatabase()  
        end
      end
      return initStatus
    end
    
    # Process a GET operation on this resource.
    # _returns_ - Rack::Response instance
    def get()
      initStatus = initOperation()
      @apiError = nil
      if(initStatus == :OK)
        begin
          @ftypesHash = BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes_fast(@refSeqId, @userId, true, @dbu)
          user = ( @aspect =~ /^default/ ? 0 : @userId )
          recs = nil
          map = {}
          allDbs = @dbu.selectFlaggedDbNamesByRefSeqId(@refSeqId)
          tmplDbs = []
          origDb = nil
          allDbs.each { |db|
            if(db['isUserDb'] == 0)
              tmplDbs << db['databaseName']   
            else
              origDb = db['databaseName']
            end
          }
          
          @ftypesHash.each_key { |key|
            map[key] = nil  
          }
          # If defaultColor/defaultStyle is requested, first query the template databases since the settings may only be stored on the template database for some of the template tracks.
          if(@aspect =~ /^default/)
            tmplDbs.each { |db|
              @dbu.setNewDataDb(db)
              if(@aspect =~ /Color/)
                recs = @dbu.selectTracksColorMap(user, @ftypesHash.keys)
              elsif(@aspect =~ /Style/)
                recs = @dbu.selectTracksStyleNameMap(user, @ftypesHash.keys)
              else # Must be order
                recs = @dbu.selectTracksOrderMap(user, @ftypesHash.keys)
              end
              updateMap(recs, map)
            }
          end
          @dbu.setNewDataDb(origDb)
          if(@aspect =~ /color/i)
            recs = @dbu.selectTracksColorMap(user, @ftypesHash.keys)
          elsif(@aspect =~ /Style/i) # Style
            recs = @dbu.selectTracksStyleNameMap(user, @ftypesHash.keys)
          elsif(@aspect =~ /^url/)
            if(@aspect == "urlDescLabel") # Get everything            
              recs = @dbu.selectTracksDescMap(@ftypesHash.keys, true)
            # To-do:
            elsif(@aspect == "url")
              
            elsif(@aspect == "urlLabel")
              
            else # Must be urlDescription
              
            end
          else
            recs = @dbu.selectTracksOrderMap(user, @ftypesHash.keys)
          end
          updateMap(recs, map)
          respEntity = BRL::Genboree::REST::Data::HashEntity.new(@connect, map)
          @statusName = configResponse(respEntity)
        rescue => err
          initStatus = @statusName = :'Internal Server Error'
          @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err}\n\n#{err.backtrace.join("\n")}")
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      if(!@apiError.nil?)
        @statusName, @statusMsg = @apiError.type, @apiError.message
        initStatus = @statusName
      end
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
    

    # Process a PUT operation on this resource.
    # _returns_ - Rack::Response instance
    def put()
      initStatus = initOperation()
      @apiError = nil
      @isAdmin = (@groupAccessStr == 'o')
      if((@aspect == 'defaultColor' or @aspect == 'defaultStyle') and !@isAdmin)
        initStatus = @statusName = :'Forbidden'
        @statusMsg = "You do not have access to #{@aspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}"
      end
      if(initStatus == :OK)
        begin
          entities = parseRequestBodyForEntity(['HashEntity']) # A simple hash table mapping tracks with whatever aspect the user wants to set
          if(entities.nil?)
            # If we have an @apiError set, use it, else set a generic one.
            @apiError = BRL::Genboree::GenboreeError.new(:'Bad Request', "BAD_REQUEST: To call PUT on this resource, the payload must be a HashEntity")
          elsif(entities == :'Unsupported Media Type')
            # If we have an @apiError set, use it, else set a generic one.
            @apiError = BRL::Genboree::GenboreeError.new(:'Unsupported Media Type', "BAD_REQUEST: The payload is not a HashEntity")
          else
            hashMap = entities.hash
            @ftypesHash = {}
            ftypeRecs = @dbu.selectAllFtypes(true, true)
            ftypeRecs.each { |ftypeRec|
              @ftypesHash["#{ftypeRec['fmethod']}:#{ftypeRec['fsource']}"] = ftypeRec['ftypeid']  
            }
            missingFtypes = []
            hashMap.keys.each { |trkName|
              if(!@ftypesHash.key?(trkName))
                missingFtypes << trkName.split(':') 
              end
            }
            if(!missingFtypes.empty?)
              @dbu.insertFtypes(missingFtypes, missingFtypes.size)
              ftypeRecs = @dbu.selectAllFtypes(true, true)
              ftypeRecs.each { |ftypeRec|
                @ftypesHash["#{ftypeRec['fmethod']}:#{ftypeRec['fsource']}"] = ftypeRec['ftypeid']  
              }
            end
            if(@aspect =~ /color/i) # NOTE: Only supports hex values
              setColor(hashMap)
            elsif(@aspect =~ /style/i) # Style
              setStyle(hashMap)
            elsif(@aspect =~ /^url/)
              setUrlDesc(hashMap)
            else # order
              setOrder(hashMap)
            end
            respEntity = BRL::Genboree::REST::Data::HashEntity.new(@connect, {})
            @statusName = configResponse(respEntity)
            @statusMsg = "The #{@aspect}s were successfully set/updated. "
          end
        rescue => err
          initStatus = @statusName = :'Internal Server Error'
          @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err}\n\n#{err.backtrace.join("\n")}")
        end
      else
        @statusName = initStatus
      end
      # If something wasn't right, represent as error
      if(!@apiError.nil?)
        @statusName, @statusMsg = @apiError.type, @apiError.message
        initStatus = @statusName
      end
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
    # Process a Delete operation on this resource.
    # _returns_ - Rack::Response instance
    def delete()
      initStatus = initOperation()
      @isAdmin = (@groupAccessStr == 'o')
      if((@aspect =~ /^default/) and !@isAdmin)
        initStatus = @statusName = :'Forbidden'
        @statusMsg = "You do not have access to #{@aspect} in database #{@dbName.inspect} in user group #{@groupName.inspect}"
      end
      if(initStatus == :OK)
        begin
          user = ( @aspect =~ /^default/ ?  0 : @userId)
          if(@aspect =~ /style/i)
            rowsDeleted = @dbu.deleteFeaturetoStyleRecsByUserId(user)
          elsif(@aspect =~ /color/i)
            @dbu.deleteFeaturetoColorRecsByUserId(user)
          else # Order
            @dbu.deleteFeatureSortRecsByUserId(user)
          end
          respEntity = BRL::Genboree::REST::Data::TextEntityList.new(@connect)
          @statusName = configResponse(respEntity)
          @statusMsg = "The #{@aspect}s were successfully deleted. "
        rescue => err
          initStatus = @statusName = :'Internal Server Error'
          @statusMsg = "INTERNAL_SERVER_ERROR: #{err}"
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{err}\n\n#{err.backtrace.join("\n")}")
        end
      end
      @resp = representError() if(@statusName != :OK)
      return @resp
    end
    
    #################
    # Helper methods
    #################
    def updateMap(recs, map)
      recs.each { |rec|
        trkName = rec['trackName']
        next if(trkName.nil? or trkName.empty?)
        if(@aspect =~ /color/i)
          map[trkName] = rec['value']
        elsif(@aspect =~ /style/i)
          map[trkName] = rec['name']
        elsif(@aspect =~ /^url/i)
          tmpHash = {'label' => '', 'url' => '', 'description' => ''}
          tmpHash['label'] = rec['label'] if(rec['label'])
          tmpHash['url'] = rec['url'] if(rec['url'])
          tmpHash['description'] = rec['description'] if(rec['description'])
          map[trkName] = tmpHash
        else
          map[trkName] = rec['sortKey']
        end
      }
    end
    
    def setUrlDesc(hashMap)
      insertRecs = []
      hashMap.each_key { |key|
        urlDesc = hashMap[key]
        url = ""
        label = ""
        description = ""
        if(urlDesc)
          url = ( urlDesc['url'] ? urlDesc['url'] : '')
          label = ( urlDesc['label'] ? urlDesc['label'] : '')
          description = ( urlDesc['description'] ? urlDesc['description'] : '')
        end
        insertRecs << [@ftypesHash[key], url, description, label]
      }
      if(!insertRecs.empty?)
        @dbu.insertRecords(:userDB, 'featureurl', insertRecs, false, insertRecs.size, 4, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", ['url', 'description', 'label'])
      end
    end
  
    def setOrder(hashMap)
      user = ( @aspect == 'defaultOrder' ?  0 : @userId)
      insertRecs = []
      hashMap.each_key { |trk|
        insertRecs << [@ftypesHash[trk], user, hashMap[trk]]  
      }
      if(!insertRecs.empty?)
        @dbu.insertRecords(:userDB, 'featuresort', insertRecs, false, insertRecs.size, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", 'sortKey')
      end
    end
    
    def setColor(hashMap)
      colors = hashMap.values
      colorHash = {}
      colorRecs = @dbu.selectAllColors()
      colorRecs.each { |rec|
        colorHash[rec['value']] = rec['colorId']  
      }
      # Collect a list of colors not already in the table
      missingColors = []
      colors.each { |color|
        missingColors << [color] if(!colorHash.key?(color) and !missingColors.map { |xx| xx.include?(color) }.reduce(:|) )
      }
      if(!missingColors.empty?)
        @dbu.insertRecords(:userDB, 'color', missingColors, true, missingColors.size, 1, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
        colorRecs = @dbu.selectAllColors()
        colorRecs.each { |rec|
          colorHash[rec['value']] = rec['colorId']  
        }
      end
      insertRecs = []
      user = ( @aspect == 'defaultColor' ?  0 : @userId)
      hashMap.each_key { |trk|
        colorId = colorHash[hashMap[trk]]
        insertRecs << [@ftypesHash[trk], user, colorId] 
      }
      if(!insertRecs.empty?)
        @dbu.insertRecords(:userDB, 'featuretocolor', insertRecs, false, insertRecs.size, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", 'colorId')
      end
    end
    
    def setStyle(hashMap)
      styles = hashMap.values
      styleHash = {}
      styleRecs = @dbu.selectAllStyles()
      styleRecs.each { |rec|
        styleHash[rec['name']] = rec['styleId']  
      }
      # Collect a list of styles not already in the table
      missingstyles = []
      styles.each { |style|
        missingstyles << [style] if(!styleHash.key?(style))
      }
      if(!missingstyles.empty?)
        @dbu.insertRecords(:userDB, 'style', missingstyles, true, missingstyles.size, 1, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
        styleRecs = @dbu.selectAllstyles()
        styleRecs.each { |rec|
          styleHash[rec['name']] = rec['styleId']  
        }
      end
      insertRecs = []
      user = ( @aspect == 'defaultStyle' ?  0 : @userId)
      hashMap.each_key { |trk|
        styleId = styleHash[hashMap[trk]]
        insertRecs << [@ftypesHash[trk], user, styleId] 
      }
      if(!insertRecs.empty?)
        @dbu.insertRecords(:userDB, 'featuretostyle', insertRecs, false, insertRecs.size, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", 'styleId')
      end
    end
    
  end # class TrackAttributeMap
end ; end ; end # module BRL ; module REST ; module Resources
