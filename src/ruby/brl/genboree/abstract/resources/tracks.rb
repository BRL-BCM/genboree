#!/usr/bin/env ruby
require 'thread'
require 'rack'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/abstract/resources/track'
require 'brl/genboree/abstract/resources/ucscBigFile'
require 'brl/rest/resource'
require 'brl/genboree/rest/helpers'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/textEntity'
require 'brl/genboree/rest/data/trackEntity'
require 'brl/genboree/rest/data/attributesEntity'
require 'brl/genboree/rest/data/ooAttributeValueDisplayEntity'
require 'brl/genboree/rest/data/attributeValueDisplayEntity'
require 'brl/genboree/rest/data/ooAttributeEntity'
require 'brl/genboree/rest/data/attributeValueEntity'

#--
# Pre-declare namespace
module BRL ; module Genboree ; module Abstract ; module Resources
end ; end ; end ; end
# Because of misleading name ("Abstract" classes are something specific in OOP and Java,
# this has lead to confusion amongst newbies), I think this shorter Constant should
# be made available by all Abstract::Resources classes. Of course, we should only set
# the constant once, so we use const_defined?()...
Abstraction = BRL::Genboree::Abstract::Resources unless(Module.const_defined?(:Abstraction))
#++

module BRL ; module Genboree ; module Abstract ; module Resources

  # This class provides methods for managing tracks
  class Tracks
    # ------------------------------------------------------------------
    # CONSTANTS
    # ------------------------------------------------------------------
    UCSC_BIGFILE_TYPES = [
      :bigWig,
      :bigBed
    ]

    ENTITY_TYPE = 'ftype' # Tracks actually
    # ------------------------------------------------------------------
    # ACCESSORS
    # ------------------------------------------------------------------
    # DbUtil instance,
    attr_accessor :dbu
    # GenboreeConfig instance
    attr_accessor :genbConf
    # refSeqId of the database that the tracks are in
    attr_accessor :refSeqId
    # an ftypesHash object (Prepared from BRL::Genboree::GenboreeDBHelper.getAllAccessibleFtypes())
    attr_accessor :ftypesHash
    # Hash for storing ftypeids for user and shared dbs by database names
    attr_accessor :ftypesDbHash
    # User id (used when getting display/default settings)
    attr_accessor :userId
    # Hash for storing only attribute names and values
    attr_accessor :attributesHash
    # Hash for storing attributes only the display components (rank, flags and color)
    attr_accessor :attributesWithDisplayHash
    # Hash for storing only annoAttributes
    attr_accessor :annoAttributesHash
    # Hash for storing only classes
    attr_accessor :classesHash
    # Hash for storing only url, label and description
    attr_accessor :urlDescriptionHash
    # Hash for storing only description
    attr_accessor :descriptionHash
    # Array of track attributes names (Strings) that we care about (default is nil == no filter i.e. ALL attributes)
    attr_accessor :attributeList
    # Hash for storing UCSC big* file info
    attr_accessor :bigFileHash
    # Hash for storing number of annotations
    attr_accessor :numAnnosHash

    # [+dbu+]
    # [+refSeqId+]
    # [ftypesHash]
    # [+userId+]
    # [connect]
    # [+returns+] nil
    def initialize(dbu, refSeqId, ftypesHash, userId, connect=true)
      @dbu, @refSeqId, @ftypesHash, @userId, @connect = dbu, refSeqId, ftypesHash, userId, connect
      @genbConf = BRL::Genboree::GenboreeConfig.load()
      @ftypesDbHash = @sharedDbs = @userDb = nil
      @attributesHash = @annoAttributesHash = @classesHash = @urlDescriptionHash = @attributesWithDisplayHash = @descriptionHash = @attributeList = nil
      @bigFileHash = nil
      @ftypeIdHash = {}
      tt = Time.now
      initFtypesDbHash()
    end

    # Gets all the information required for a detailed response object
    # [+returns+] nil
    def getEntity(refBase, filterType=nil, filter=nil, detailed="false", list=true)
      retVal = nil
      # Get the attributes
      case detailed
      when "true", "ooMaxDetails", "maxDetails", "yes", true
        # Get the attributes (only values)
        #tt = Time.now
        updateAttributes()
        # Get the attributes (with display/default display)
        #$stderr.puts "Time for getting attributes: #{Time.now - tt}"
        #tt = Time.now
        updateAttributesWithDisplay()
        #$stderr.puts "Time for getting attributes with display: #{Time.now - tt}"
        # Next get the description, url and labels
        #tt = Time.now
        updateUrlDescription()
        #$stderr.puts "Time for getting urlDescription: #{Time.now - tt}"
        # Next get the classes
        #tt = Time.now
        updateClasses()
        #$stderr.puts "Time for getting classes: #{Time.now - tt}"
        # Finally get the annoAttributes
        #tt = Time.now
        updateAnnoAttributes()
        #$stderr.puts "Time for getting annoAttributes: #{Time.now - tt}"
        # Next get big* file info
        #tt = Time.now()
        updateBigFileInfo()
        #$stderr.puts "Time for getting big* file info: #{Time.now - tt}"
        updateNumAnnos()
      when "minDetails", "ooMinDetails", "no", "false", nil, false
        # Get the attributes (only values)
        #tt = Time.now
        updateAttributes()
        #$stderr.puts "Time for getting attributes: #{Time.now - tt}"
        # Next get the description, url and labels
        #tt = Time.now
        updateDescription()
        #$stderr.puts "Time for getting description: #{Time.now - tt}"
        # Next get the classes
        #tt = Time.now
        updateClasses()
        #$stderr.puts "Time for getting classes: #{Time.now - tt}"
        # Next get big* file info
        #tt = Time.now()
        updateBigFileInfo()
        #$stderr.puts "Time for getting big* file info: #{Time.now - tt}"
        updateNumAnnos()
      else
        raise "Unknown detailed type: #{detailed.inspect}"
      end
      if(list)
        retVal = getEntityModelForList(filterType, filter, refBase, detailed)
      else
        retVal = getEntityModel(refBase, detailed)
      end
      return retVal
    end

    # Explicit clean up to help prevent memory leaks
    def clear()
      @dbu = @refSeqId = nil
      @ftypesHash.clear() if(@ftypesHash)
      @ftypesDbHash.clear() if(@ftypesDbHash)
      @bigFileHash.clear() if(@bigFileHash)
    end

    def makeBigFileDateStr(bigFileDir, bigFileName)
      dateStr = nil
      path = "#{bigFileDir}/#{bigFileName}"
      if(File.exist?(path))
        dateStr = File.mtime(path).strftime("%Y-%m-%d %H:%M")
      end
      return dateStr
    end

    def initAllHashes()
      initAttributesHash()
      initAnnoAttributesHash()
      initClassesHash()
      initAttributesWithDisplayHash()
      initUrlDescriptionHash()
    end

    def initBigFileHash()
      @bigFileHash = Hash.new { |hh,kk| hh[kk] = { :bigWig  => "",  :creationTime => "" } }
    end

    def initDescriptionHash()
      @descriptionHash = {}
    end
    
    def initNumAnnosHash()
      @numAnnosHash = {}
    end

    def initAttributesHash()
      @attributesHash = Hash.new { |hh, kk|
        hh[kk] = {}
      }
    end

    def initAnnoAttributesHash()
      @annoAttributesHash = Hash.new { |hh, kk|
        hh[kk] = {}
      }
    end

    def initClassesHash()
      @classesHash = Hash.new { |hh, kk|
        hh[kk] = {}
      }
    end

    def initAttributesWithDisplayHash()
      @attributesWithDisplayHash = Hash.new { |hh, kk|
        hh[kk] = Hash.new { | ii, jj|
          ii[jj] = {
            :defaultDisplay => {
                                :rank => "",
                                :color => "",
                                :flags => ""
                              },
            :display => {
                                :rank => "",
                                :color => "",
                                :flags => ""
                              }
          }
        }
      }
    end

    def initUrlDescriptionHash()
      @urlDescriptionHash = Hash.new { |hh, kk|
        hh[kk] =  {
                    :url => "",
                    :description => "",
                    :urlLabel => ""
                  }
      }
    end

    # Initialize @ftypesDbHash (Hash for storing ftypeids for user and shared dbs by database names)
    # [+returns] nil
    def initFtypesDbHash()
      @ftypesDbHash = {
                           :userDb => {},
                           :sharedDb => {}
                      }
      @ftypesHash.each_key { |key|
        dbNames = @ftypesHash[key]['dbNames']
        dbNames.each { |db|
          dbName = db['dbName']
          ftypeid = db['ftypeid']
          dbType = db['dbType']
          @ftypeIdHash[key] = ftypeid
          if(!@ftypesDbHash[dbType].has_key?(dbName))
            tmpHash = {}
            tmpHash[dbName] = [ftypeid]
            @ftypesDbHash[dbType] = tmpHash
          else
            @ftypesDbHash[dbType][dbName] << ftypeid
          end
        }
      }
      @sharedDbs = @ftypesDbHash[:sharedDb]
      @userDb = @ftypesDbHash[:userDb]
    end

    def getAnnoAttributesEntityList(tname)
      # add unique attribute names (annotation attributes) to this track entity as a Text list
      # annoAttributes currently doesn't support refs (not CURRENTLY addressable), so first arg set to false not @connect
      annoAttributesEntityList = BRL::Genboree::REST::Data::TextEntityList.new(false)
      attrNames = @annoAttributesHash[tname]
      annoAttributesEntityList.importFromRawData(attrNames.keys)
      return annoAttributesEntityList
    end

    def getAttributesEntityList(tname)
      # add attributes (track wide AVPs/metadata)
      # OOAttributeValueDisplayEntityList currently doesn't support refs (not CURRENTLY addressable), so first arg set to false not @connect
      attributesEntityList = BRL::Genboree::REST::Data::OOAttributeValueDisplayEntityList.new(false)
      attrHash = @attributesHash[tname]
      displayHash = @attributesWithDisplayHash[tname]
      attrHash.each_key { |attrName|
        value = attrHash[attrName]
        display = displayHash[attrName][:display]
        defaultDisplay = displayHash[attrName][:defaultDisplay]
        # AttributeDisplayEntity currently doesn't support refs (not CURRENTLY addressable), so first arg set to false not @connect
        displayEntity = BRL::Genboree::REST::Data::AttributeDisplayEntity.new(false, display[:rank], display[:color], display[:flags])
        # AttributeDisplayEntity currently doesn't support refs (not CURRENTLY addressable)  , so first arg set to false not @connect
        defaultDisplayEntity = BRL::Genboree::REST::Data::AttributeDisplayEntity.new(false, defaultDisplay[:rank], defaultDisplay[:color], defaultDisplay[:flags])
        # AttributeValueDisplayEntity currently doesn't support refs (not CURRENTLY addressable), so first arg set to false not @connect
        attributesEntityList << BRL::Genboree::REST::Data::OOAttributeValueDisplayEntity.new(false, attrName, value, displayEntity, defaultDisplayEntity)
      }
      return attributesEntityList
    end

    def filterValue(tname, filterType, filter)
      filtered = true
      if(@attributesHash[tname].has_key?(filterType))
        filterValue = @attributesHash[tname][filterType]
        if(!filterValue.nil? and filterValue == filter)
          filtered = false
        end
      end
      return filtered
    end

    # Constructs the appropriate attributes entity
    # [+detailed+] type of response requested
    # [+tname+] track name
    # [+returns+] retVal: one of the existing attributes entity type
    def getAttributes(detailed, tname)
      retVal = nil
      case detailed
      when "true", "ooMaxDetails", "maxDetails", "yes", true
        if(detailed != "ooMaxDetails") # Attributes will be a hash of AttributeValueDisplayEntity objects keyed by the attribute names
          attributes = @attributesHash[tname]
          # AttributeValueDisplayEntityHash currently doesn't support refs (not CURRENTLY addressable), so first arg set to false not @connect
          attributesValueDisplayHash = BRL::Genboree::REST::Data::AttributeValueDisplayEntityHash.new(false)
          displayHash = @attributesWithDisplayHash[tname]
          attributes.each_key { |attrName|
            value = attributes[attrName]
            display = displayHash[attrName][:display]
            defaultDisplay = displayHash[attrName][:defaultDisplay]
            # AttributeDisplayEntity currently doesn't support refs (not CURRENTLY addressable), so first arg set to false not @connect
            displayEntity = BRL::Genboree::REST::Data::AttributeDisplayEntity.new(false, display[:rank], display[:color], display[:flags])
            # AttributeDisplayEntity currently doesn't support refs (not CURRENTLY addressable)  , so first arg set to false not @connect
            defaultDisplayEntity = BRL::Genboree::REST::Data::AttributeDisplayEntity.new(false, defaultDisplay[:rank], defaultDisplay[:color], defaultDisplay[:flags])
            # AttributeValueDisplayEntity currently doesn't support refs (not CURRENTLY addressable), so first arg set to false not @connect
            attributesValueDisplayHash[attrName] = BRL::Genboree::REST::Data::AttributeValueDisplayEntity.new(false, value, displayEntity, defaultDisplayEntity)
          }
          retVal = attributesValueDisplayHash
        else # attributes will be an array of OOAttributeValueDisplayEntity objects
          retVal = getAttributesEntityList(tname)
        end
      when "minDetails", "false", "ooMinDetails", "no", false, nil
        if(detailed == "ooMinDetails") # The attributes field will be an array of OOAttributeEntity objects
          # OOAttributeEntityList currently doesn't support refs (not CURRENTLY addressable), so first arg set to false not @connect
          retVal = BRL::Genboree::REST::Data::OOAttributeEntityList.new(false)
          @attributesHash[tname].each_key { |attrName|
            # OOAttributeEntity currently doesn't support refs (not CURRENTLY addressable), so first arg set to false not @connect
            retVal << BRL::Genboree::REST::Data::OOAttributeEntity.new(false, attrName, @attributesHash[tname][attrName])
          }
        else # The attributes field will be a simple hash
          # OOAttributeEntity currently doesn't support refs (not CURRENTLY addressable), so first arg set to false not @connect
          retVal = BRL::Genboree::REST::Data::AttributeValueEntityHash.new(false, @attributesHash[tname])
        end
      end
      return retVal
    end

    def getEntityModel(refBase, detailed)
      tt = Time.now
      trackEntity = BRL::Genboree::REST::Data::DetailedTrackEntity.new(@connect)
      tname = @ftypesHash.keys[0]
      case detailed
      when "true", "ooMaxDetails", "maxDetails", "yes", true
        tmpTrkHash = @urlDescriptionHash[tname]
        desc = tmpTrkHash[:description]
        url = tmpTrkHash[:url]
        urlLabel = tmpTrkHash[:urlLabel]
        classes = @classesHash[tname]
        # Classes not currently individually addressible (no refs support, will just be empty), so first arg set to false not @connect
        classesList = BRL::Genboree::REST::Data::TextEntityList.new(false)
        classesList.importFromRawData(classes.keys)
        trackEntity.name = tname
        trackEntity.description = desc
        trackEntity.url = url
        trackEntity.urlLabel = urlLabel
        trackEntity.classes = classesList
        trackEntity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(tname)}")
        trackEntity.annoAttributes = getAnnoAttributesEntityList(tname)
        trackEntity.attributes = getAttributes(detailed, tname)
        trackEntity.bigWig = @bigFileHash[tname][:bigWig]
        trackEntity.bigBed = @bigFileHash[tname][:bigBed]
      when "minDetails", "false", "ooMinDetails", "no", false, nil
        description = @descriptionHash[tname]
        classes = @classesHash[tname]
        # Classes not currently individually addressible (no refs support, will just be empty), so first arg set to false not @connect
        classesList = BRL::Genboree::REST::Data::TextEntityList.new(false)
        classesList.importFromRawData(classes.keys)
        url = urlLabel = annoAttributes = attributes = nil
        attributes = getAttributes(detailed, tname)
        trackEntity.name = tname
        trackEntity.description = description
        trackEntity.url = url
        trackEntity.urlLabel = urlLabel
        trackEntity.classes = classesList
        trackEntity.attributes = attributes
        trackEntity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(tname)}")
        trackEntity.annoAttributes = annoAttributes
        trackEntity.bigWig = @bigFileHash[tname][:bigWig]
        trackEntity.bigBed = @bigFileHash[tname][:bigBed]
      end
      trackEntity.dbId = @ftypeIdHash[tname]
      trackEntity.numAnnos = @numAnnosHash[tname] ? @numAnnosHash[tname] : 0  
      return trackEntity
    end

    def getEntityModelForList(filterType, filter, refBase, detailed)
      tt = Time.now
      trackListEntity = BRL::Genboree::REST::Data::DetailedTrackEntityList.new(@connect)
      case detailed
      when "true", "ooMaxDetails", "maxDetails", "yes", true
        @ftypesHash.keys.sort { |aa, bb|
          aa.downcase <=> bb.downcase
        }.each { |tname|
          tmpTrkHash = @urlDescriptionHash[tname]
          desc = tmpTrkHash[:description]
          url = tmpTrkHash[:url]
          urlLabel = tmpTrkHash[:urlLabel]
          classes = @classesHash[tname]
          # Classes not currently individually addressible (no refs support, will just be empty), so first arg set to false not @connect
          classesList = BRL::Genboree::REST::Data::TextEntityList.new(false)
          classesList.importFromRawData(classes.keys)
          trkEntity = BRL::Genboree::REST::Data::DetailedTrackEntity.new(@connect, tname, desc, url, urlLabel, classesList)
          trkEntity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(tname)}")
          trkEntity.annoAttributes = getAnnoAttributesEntityList(tname)
          trkEntity.attributes = getAttributes(detailed, tname)
          trkEntity.bigWig = @bigFileHash[tname][:bigWig]
          trkEntity.bigBed = @bigFileHash[tname][:bigBed]
          #Check filter (if any) for this track
          if(!filter.nil? and !filterType.nil?)
            trackListEntity << trkEntity unless(filterValue(tname, filterType, filter))
          else
            trackListEntity << trkEntity
          end
          trkEntity.dbId = @ftypeIdHash[tname]
          trkEntity.numAnnos = @numAnnosHash[tname] ? @numAnnosHash[tname] : 0
        }
      when "minDetails", "false", "ooMinDetails", "no", false, nil
        @ftypesHash.keys.sort { |aa, bb|
          aa.downcase <=> bb.downcase
        }.each { |tname|
          description = @descriptionHash[tname]
          classes = @classesHash[tname]
          # Classes not currently individually addressible (no refs support, will just be empty), so first arg set to false not @connect
          classesList = BRL::Genboree::REST::Data::TextEntityList.new(false)
          classesList.importFromRawData(classes.keys)
          url = urlLabel = annoAttributes = attributes = nil
          attributes = getAttributes(detailed, tname)
          trkEntity = BRL::Genboree::REST::Data::DetailedTrackEntity.new(@connect, tname, description, url, urlLabel, classesList, annoAttributes, attributes)
          trkEntity.makeRefsHash("#{refBase}/#{Rack::Utils.escape(tname)}")
          trkEntity.bigWig = @bigFileHash[tname][:bigWig]
          trkEntity.bigBed = @bigFileHash[tname][:bigBed]
          #Check filter (if any) for this track
          if(!filter.nil? and !filterType.nil?)
            trackListEntity << trkEntity unless(filterValue(tname, filterType, filter))
          else
            trackListEntity << trkEntity
          end
          trkEntity.dbId = @ftypeIdHash[tname]
          trkEntity.numAnnos = @numAnnosHash[tname] ? @numAnnosHash[tname] : 0
        }
      end
      #$stderr.debugPuts(__FILE__, __method__, "TIMING", "Creating response entity list: #{Time.now - tt}")
      return trackListEntity
    end

    # Get info about big* file presence and date
    def updateBigFileInfo()
      # Init
      initBigFileHash()
      # Get user's database name
      refseqRows = @dbu.selectRefseqById(@refSeqId)
      userDbName = refseqRows.first['refseqName']
      # Get user's group name
      publicGroupId = @genbConf.publicGroupId || nil
      groupRows = @dbu.getGroupsByRefseqId(@refSeqId, publicGroupId)
      groupName = groupRows.first['groupName']
      # Get big* file names
      bwFileName = @genbConf.gbTrackAnnoBigWigFile
      bbFileName = @genbConf.gbTrackAnnoBigBedFile
      # Iterate over each track
      @ftypesHash.each_key { |trkName|
        # 1. big* file dir:
        bigFileDir = BRL::Genboree::Abstract::Resources::UCSCBigFile.makeDirPath(@genbConf, groupRows.first['groupId'], @refSeqId, @ftypesHash[trkName]['ftypeid'])
        # 2. Look for bigWig
        dateStr = makeBigFileDateStr(bigFileDir, bwFileName)
        @bigFileHash[trkName][:bigWig] = dateStr
        # 3. Look for bigBed
        dateStr = makeBigFileDateStr(bigFileDir, bbFileName)
        @bigFileHash[trkName][:bigBed] = dateStr
      }
    end

    def updateDescription()
      initDescriptionHash()
      @sharedDbs.each_key { |key|
        ftypeidList = @sharedDbs[key]
        @dbu.setNewDataDb(key)
        updateDescriptionHash(ftypeidList)
      }
      @userDb.each_key { |key|
        ftypeidList = @userDb[key]
        @dbu.setNewDataDb(key)
        updateDescriptionHash(ftypeidList)
      }
    end
    
    def updateNumAnnos()
      initNumAnnosHash()
      @sharedDbs.each_key { |key|
        ftypeidList = @sharedDbs[key]
        @dbu.setNewDataDb(key)
        updateNumAnnosHash(ftypeidList)
      }
      @userDb.each_key { |key|
        ftypeidList = @userDb[key]
        @dbu.setNewDataDb(key)
        updateNumAnnosHash(ftypeidList)
      }
    end

    def updateAttributes(attributeList=@attributeList, mapType='full', aspect='map')
      initAttributesHash()
      @sharedDbs.each_key { |key|
        ftypeidList = @sharedDbs[key]
        @dbu.setNewDataDb(key)
        updateAttributesHash(ftypeidList, attributeList, mapType, aspect)
      }
      @userDb.each_key { |key|
        ftypeidList = @userDb[key]
        @dbu.setNewDataDb(key)
        updateAttributesHash(ftypeidList, attributeList, mapType, aspect)
      }
    end

    def updateAttributesWithDisplay(attributeList=@attributeList)
      initAttributesWithDisplayHash()
      @sharedDbs.each_key { |key|
        ftypeidList = @sharedDbs[key]
        @dbu.setNewDataDb(key)
        updateAttributesWithDisplayHash(ftypeidList, attributeList)
      }
      @userDb.each_key { |key|
        ftypeidList = @userDb[key]
        @dbu.setNewDataDb(key)
        updateAttributesWithDisplayHash(ftypeidList, attributeList)
      }
    end

    def updateUrlDescription()
      initUrlDescriptionHash()
      @sharedDbs.each_key { |key|
        ftypeidList = @sharedDbs[key]
        @dbu.setNewDataDb(key)
        updateUrlDescriptionHash(ftypeidList)
      }
      @userDb.each_key { |key|
        ftypeidList = @userDb[key]
        @dbu.setNewDataDb(key)
        updateUrlDescriptionHash(ftypeidList)
      }
    end

    def updateClasses()
      initClassesHash()
      @sharedDbs.each_key { |key|
        ftypeidList = @sharedDbs[key]
        @dbu.setNewDataDb(key)
        updateClassesHash(ftypeidList)
      }
      @userDb.each_key { |key|
        ftypeidList = @userDb[key]
        @dbu.setNewDataDb(key)
        updateClassesHash(ftypeidList)
      }
    end

    def updateAnnoAttributes()
      initAnnoAttributesHash()
      attNameIds = []
      @sharedDbs.each_key { |key|
        ftypeidList = @sharedDbs[key]
        @dbu.setNewDataDb(key)
        ftype2AttributeNameRecs = @dbu.selectTrackNameToAnnoAttributes(ftypeidList)
        ftype2AttributeNameRecs.each { |rec|
          @annoAttributesHash[rec['trackName']][rec['name']] = true
        }
      }
      @userDb.each_key { |key|
        ftypeidList = @userDb[key]
        @dbu.setNewDataDb(key)
        ftype2AttributeNameRecs = @dbu.selectTrackNameToAnnoAttributes(ftypeidList)
        ftype2AttributeNameRecs.each { |rec|
          @annoAttributesHash[rec['trackName']][rec['name']] = true
        }
      }
    end

    # Requires @dbu to be connected to the right db
    # [+ftypeidList+] An array of ftypeids
    # [+returns] nil
    def updateDescriptionHash(ftypeidList)
      descRecs = @dbu.selectDescriptionByFtypeIds(ftypeidList)
      descRecs.each { |rec|
        @descriptionHash[rec['trackName']] = rec['description']
      }
    end
    
    def updateNumAnnosHash(ftypeidList)
      descRecs = @dbu.selectFtypeCountByFtypeIds(ftypeidList)
      descRecs.each { |rec|
        trkName = rec['trackName']
        if(!@numAnnosHash.key?(trkName))
          @numAnnosHash[trkName] = rec['numberOfAnnotations'] 
        else
          @numAnnosHash[trkName] += rec['numberOfAnnotations']
        end
      }
    end

    # Requires @dbu to be connected to the right db
    # [+ftypeidList+] An array of ftypeids
    # [+returns] nil
    def updateClassesHash(ftypeidList)
      classRecs = @dbu.selectAllFtypeClasses(ftypeidList)
      classRecs.each { |rec|
        tmpHash = @classesHash[rec['trackName']]
        className = rec['gclass']
        if(!tmpHash.has_key?(className))
          tmpHash[className] = true
        end
      }
    end

    # Requires @dbu to be connected to the right db
    # [+ftypeidList+] An array of ftypeids
    # [+attributeList+] - [optional; default=nil] Only get info for attributes in this array (should be array of attribute name Strings)
    # [+returns] nil
    def updateAttributesHash(ftypeidList, attributeList=@attributeList, mapType='full', aspect='map')
      startTime = Time.now
      # Make the query without any user
      if(aspect == 'map')
        if(mapType == 'full')
          attributesInfoRecs = @dbu.selectFtypeAttributesInfoByFtypeIdList(ftypeidList, attributeList)
          attributesInfoRecs.each { |rec|
            @attributesHash[rec['trackName']][rec['name']] = rec['value']
          }
        elsif(mapType == 'attrNames')
          attributesInfoRecs = @dbu.selectFtypeAttributeNamesMapByFtypeIdList(ftypeidList, attributeList)
          attributesInfoRecs.each { |rec|
            @attributesHash[rec['trackName']][rec['name']] = nil
          }
        elsif(mapType == 'attrValues')
          attributesInfoRecs = @dbu.selectFtypeAttributeValuesMapByFtypeIdList(ftypeidList)
          attributesInfoRecs.each { |rec|
            @attributesHash[rec['trackName']][rec['value']] = nil
          }
        else
          raise "Unknown mapType: #{mapType.inspect}"
        end
      elsif(aspect == 'names')
        attributesInfoRecs = @dbu.selectFtypeAttributeNamesForAllTracks()
        attributesInfoRecs.each { |rec|
          @attributesHash[rec['attributeName']][nil] = nil
        }
      elsif(aspect == 'values')
        attributesInfoRecs = @dbu.selectFtypeAttributeValuesForAllTracks()
        attributesInfoRecs.each { |rec|
          @attributesHash[rec['attributeValue']][nil] = nil
        }
      else
        raise "Unknown aspect: #{aspect.inspect}"
      end
    end

    # Requires @dbu to be connected to the right db
    # [+ftypeidList+] An array of ftypeids
    # [+attributeList+] - [optional; default=nil] Only get info for attributes in this array (should be array of attribute name Strings)
    # [+returns] nil
    def updateAttributesWithDisplayHash(ftypeidList, attributeList=@attributeList)
      # Make the query with the default user: 0
      attributesInfoRecs = @dbu.selectFtypeAttributesDisplayInfoByFtypeIdList(ftypeidList, 0, attributeList)
      attributesInfoRecs.each { |rec|
        defaultDisplayHash = @attributesWithDisplayHash[rec['trackName']][rec['name']][:defaultDisplay]
        defaultDisplayHash[:rank] = rec['rank']
        defaultDisplayHash[:color] = rec['color']
        defaultDisplayHash[:flags] = rec['flags']
      }
      # Make the query with the user: @userId
      attributesInfoRecs = @dbu.selectFtypeAttributesDisplayInfoByFtypeIdList(ftypeidList, @userId, attributeList)
      attributesInfoRecs.each { |rec|
        displayHash = @attributesWithDisplayHash[rec['trackName']][rec['name']][:display]
        displayHash[:rank] = rec['rank']
        displayHash[:color] = rec['color']
        displayHash[:flags] = rec['flags']
      }
    end

    # Requires @dbu to be connected to the right db
    # [+ftypeidList+] An array of ftypeids
    # [+returns] nil
    def updateUrlDescriptionHash(ftypeidList)
      urlRecs = @dbu.selectFeatureurlByFtypeIds(ftypeidList)
      urlRecs.each { |rec|
        tmpTrkHash = @urlDescriptionHash[rec['trackName']]
        tmpTrkHash[:description] = rec['description']
        tmpTrkHash[:url] = rec['url']
        tmpTrkHash[:urlLabel] = rec['label']
      }
    end
  end
end ; end ; end ; end
