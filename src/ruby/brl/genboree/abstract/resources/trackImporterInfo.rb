require 'json'
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'

module BRL ; module Genboree ; module Abstract ; module Resources
  CachedInfo = Struct.new(:sources, :classesBySource)
  MappingInfoRec = Struct.new(:key, :source, :lffClass, :lffType, :lffSubtype, :overrideLffClass, :overrideLffType, :overrideLffSubType, :recommended)
  ImporterInfoRec = Struct.new(:key, :source, :lffClass, :lffType, :lffSubtype, :converter, :configFile, :sqlFile, :dataFile, :outFile, :overrideLffClass, :overrideLffType, :overrideLffSubType, :recommended)

  class TrackImporterInfo
    # What genome build / assembly version is this for?
    attr_accessor :build
    # Importer data (Hash by key)
    attr_accessor :importerInfo
    # Hash of tracks (keys) that should be imported by default.
    attr_accessor :recommended
    # Cached data
    attr_accessor :cachedInfo

    def initialize(build, genbConf=nil)
      @build = build.to_s.strip().downcase()
      @importerInfo = {}
      @recommended = {}
      @cachedInfo = CachedInfo.new()
      @genbConf = (genbConf or BRL::Genboree::GenboreeConfig.load())
      load()
    end

    def load()
      @rsrcDir = @genbConf.resourcesDir
      # Read the recommended file
      @recommendedFile = "#{@rsrcDir}/importer/#{@build}/#{@genbConf.recommendedForImportFile}"
      reader = BRL::Util::TextReader.new(@recommendedFile)
      reader.each_line { |line|
        next if(line !~ /\S/ or line =~ /^\s*\#/)
        line.strip!
        @recommended[line] = true
      }
      reader.close()
      # Read the info file
      @importInfoFile = "#{@rsrcDir}/importer/#{@build}/#{@genbConf.importerInfoFile}"
      reader = BRL::Util::TextReader.new(@importInfoFile)
      reader.each_line { |line|
        next if(line !~ /\S/ or line =~ /^\s*\#/)
        line.strip!
        fields = line.split(/\t/)
        rec = ImporterInfoRec.new(*fields)
        rec.recommended = (@recommended[rec.key] ? true : false) # the ?: handles both types of "false": missing as a key (nil value) and real "false" value
        @importerInfo[rec.key] = rec
      }
      reader.close()
      return @importerInfo
    end

    def getImporterInfoRecord(trkKey, recType=:mappingInfo)
      rec = @importerInfo[trkKey.to_s.strip]
      return (recType == :mappingInfo ? MappingInfoRec.new(rec.key, rec.source, rec.lffClass, rec.lffType, rec.lffSubtype, rec.overrideLffClass, rec.overrideLffType, rec.overrideLffSubType, rec.recommended) : rec)
    end

    def getImporterInfoRecords(trkKeys, recType=:mappingInfo)
      retVal = []
      trkKeys.each { |trkKey|
        rec = @importerInfo[trkKey.to_s.strip]
        retVal << (recType == :mappingInfo ? MappingInfoRec.new(rec.key, rec.source, rec.lffClass, rec.lffType, rec.lffSubtype, rec.overrideLffClass, rec.overrideLffType, rec.overrideLffSubType, rec.recommended) : rec)
      }
      return retVal
    end

    def getTrackImporterInfo(srcFilter=nil, classFilter=nil, typeFilter=nil, recommendedFilter=nil, recType=:mappingInfo)
      retVal = []
      @importerInfo.each_value { |rec|
        next if(srcFilter and (rec.source != srcFilter))
        next if(classFilter and (rec.lffClass != classFilter))
        next if(typeFilter and (rec.lffType != typeFilter))
        next if(!recommendedFilter.nil? and (rec.recommended != recommendedFilter))
        retVal << (recType == :mappingInfo ? MappingInfoRec.new(rec.key, rec.source, rec.lffClass, rec.lffType, rec.lffSubtype, rec.overrideLffClass, rec.overrideLffType, rec.overrideLffSubType, rec.recommended) : rec)
      }
      return retVal
    end

    def sources()
      if(@cachedInfo.sources.nil?)
        sources = {}
        # [re]cache the classes for each sources as well
        @cachedInfo.classesBySource = {} if(@cachedInfo.classesBySource.nil?)
        classesBySource = Hash.new { |hh, kk| hh[kk] = {} }
        @importerInfo.each_value { |rec|
          sources[rec.source] = true
          classesBySource[rec.source][rec.lffClass] = true
        }
        @cachedInfo.sources = sources.keys.sort { |aa, bb| aa.downcase <=> bb.downcase }
        sortedClassesBySource = {}
        classesBySource.each_key { |src|
          classes = classesBySource[src].keys.sort { |aa, bb| aa.downcase <=> bb.downcase }
          @cachedInfo.classesBySource[src] = classes
        }
      end
      return @cachedInfo.sources
    end

    def classes(srcFilter=nil)
      self.sources() if(@cachedInfo.classesBySource.nil?)
      if(srcFilter)
        retVal = @cachedInfo.classesBySource[srcFilter]
      else
        retVal = []
        @cachedInfo.classesBySource.each_key { |src|
          retVal += @cachedInfo.classesBySource[src]
        }
      end
      return retVal
    end

    def types(srcFilter=nil, classFilter=nil)
      foundTypes = {}
      @importerInfo.each_value { |rec|
        next if(srcFilter and (rec.source != srcFilter))
        next if(classFilter and (rec.lffClass != classFilter))
        foundTypes[rec.lffType] = true
      }
      return foundTypes.keys.sort { |aa, bb| aa.downcase <=> bb.downcase }
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module Abstract ; module Resources
