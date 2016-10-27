require 'iconv'
require 'uri'
require 'open-uri'
require 'nokogiri'
require 'brl/util/callback'

module BRL ; module Sites ; module Orphanet
  # Read and parse the full set of Orphanet docs into KbDocs suitable for storing in a collection,
  # and later query/retrieval.
  # * Requires the location of the XML files directory.
  # * Can be used to download the files from http://www.orphadata.org and populate/replace files
  #   in the xmlDir. Or just use existing files.                            
  class OrphanetImporterExporter
    ORPHA_DATA_VERSION_XPATH = '//JDBOR/@version'
    ORPHA_REC_CSS_SELECT = 'DisorderList > Disorder > OrphaNumber'
    XML_FILE_CONFS = [
      {
        :dataSet  => 'Disorders',
        :fileName => 'disorders.xml',
        :url      => 'http://www.orphadata.org/data/xml/en_product1.xml'
      },
      {
        :dataSet =>  'Epidemiology - Age of Onset and Death',
        :fileName => 'epidemiologies_ages.xml',
        :url      => 'http://www.orphadata.org/data/xml/en_product2_ages.xml'
        },
      {
        :dataSet =>  'Epidemiology - Prevalences',
        :fileName => 'epidemiologies_prevalences.xml',
        :url      => 'http://www.orphadata.org/data/xml/en_product2_prev.xml'
      },
      {
        :dataSet =>  'Clinical Signs',
        :fileName => 'clinical_signs.xml',
        :url      => 'http://www.orphadata.org/data/xml/en_product4.xml'
      },
      {
        :dataSet =>  'Clinical Signs - Thesaurus',
        :fileName => 'clinical_signs_thesaurus.xml',
        :url      => 'http://www.orphadata.org/data/xml/en_product5.xml'
      },
      {
        :dataSet =>  'Gene Associations',
        :fileName => 'gene_associations.xml',
        :url      => 'http://www.orphadata.org/data/xml/en_product6.xml'
      },
      {
        :dataSet =>  'Linear Classification',
        :fileName => 'linear_classification.xml',
        :url      => 'http://www.orphadata.org/data/xml/en_product7.xml'
      }
    ]

    attr_accessor :xmlDir
    attr_accessor :orphaData, :dataVersion
    attr_accessor :forceDownload, :saveDocJson, :downloadMissing
    
    def initialize(xmlDir, opts={})
      @opts = opts
      @forceDownload = (@opts[:forceDownload] == true)
      @downloadMissing = (@opts[:downloadMissing] == true)
      @orphaData = Hash.new { |hh, kk| hh[kk] = {} }
      @dataVersion = nil
      @xmlDir = xmlDir
      if(!@xmlDir.is_a?(String) or !File.exist?(@xmlDir))
        raise ArgumentError, "ERROR: The directory #{@xmlDir.inspect} does not exist. Can't read and maybe write files there."
      elsif(@downloadMissing and @forceDownload)
        raise ArgumentError, "ERROR: Ambiguous intentions. Can't try to use this class in BOTH download-missing AND force-download mode; decide what you are trying to do and use that mode specifically (or default, download nothing mode)."
      end
    end

    def loadData()
      sane = sanityCheck()
      $stderr.debugPuts(__FILE__, __method__, 'STATUS', "Sane: #{sane.inspect}")
      examineFiles()
      $stderr.debugPuts(__FILE__, __method__, 'STATUS', "Done examining XML data files.")
      # Load data into @orphaData
      XML_FILE_CONFS.each { |conf|
        prop = conf[:dataSet]
        filePath = fullPath(conf[:fileName])
        xmlDoc = Nokogiri::XML( File.read( filePath ) )
        unless(@dataVersion) # read the xml data version unless we already have from a previous file
          versionAttr = xmlDoc.xpath( ORPHA_DATA_VERSION_XPATH )
          if(versionAttr and !versionAttr.empty?)
            @dataVersion = versionAttr.first.value rescue nil
          end
        end
        orphanetElems = xmlDoc.css(ORPHA_REC_CSS_SELECT)
        orphanetElems.each { |orphanetElem|
          rec = orphanetElem.parent # the Disorder record we want to store
          # @todo XML seems to be ISO-8859-1, at least in some cases. This will break some text-processing libraries
          #   like JSON. Below we have transliterated to UTF-8, which should be enough for JSON to proceed and may
          #   work for (a) maintaining correct content and (b) "just working" within a web page [MAYBE]. IF transliteration
          #   down to ASCII is needed, do NOT do it directly from ISO-8859-1--transliteration to ASCII does bad things to
          #   umlauts. Rather do ISO-8859-1 -> UTF-8, then apply some common/standard clean up gsubs on the utf8 string
          #   like utf8.gsub(/\303\274/, "u") etc, and THEN translit to ASCII when done. Here some commonly encountered
          #   non-ASCII that should probably be handled specifically via gsubs to prevent ü becoming 2 chars "u
          #   which can cause you no end of problem: ³ , Ä , Å , Ç , á , ä , ç , è , é , ë , í , ï , ñ , ó , ö , ÷ , ü.
          #   Iconv.conv("ASCII//TRANSLIT", "UTF-8", str.to_s)
          utf8xml = Iconv.conv("UTF-8//TRANSLIT", "ISO-8859-1", rec.to_s)
          @orphaData[orphanetElem.text][prop] = utf8xml
        }
        $stderr.debugPuts(__FILE__, __method__, 'STATUS', "Done parsing data from #{conf[:fileName].inspect}")
      }

      return @orphaData
    end

    # ---------------------------------------------------------------
    # INTERNAL METHODS
    # ----------------------------------------------------------------

    def sanityCheck()
      retVal = true
      # If forcing download, then dir must be writable and any existing Orphanet files must be writable
      if(@forceDownload)
        if(File.writable?(@xmlDir))
          retVal = XML_FILE_CONFS.all? { |xmlRec|
            filePath = fullPath( xmlRec[:fileName] )
            if(File.exist?(filePath))
              rv = File.writable?(filePath)
            end
            rv
          }
          unless(retVal)
            raise RuntimeError, "ERROR: Being used in force download mode, but 1+ files in target directory #{@xmlDir.inspect }are not writable."
          end
        else
          raise RuntimeError, "ERROR: Being used in force download mode, but target directory #{@xmlDir.inspect} is not writable."
        end
      elsif(@downloadMissing)
        # If not forcing download, then if any file is missing or empty, the dir must be writable
        anyMissing = XML_FILE_CONFS.any? { |xmlRec|
          filePath = fullPath( xmlRec[:fileName] )
          ( !File.exist?(filePath) or File.size?(filePath) )
        }
        if(anyMissing) # then at least 1 xml file doesn't yet exist
          unless(File.writable?(@xmlDir))
            raise RuntimeError, "ERROR: Being used in download missing mode, and one or more of the xml files doesn't exist, but can't write downloaded file to dir #{@xmlDir.inspect}."
          end
        end
      end

      # If saving KbDoc JSON, the dir must be writable.
      if(@saveDocJson and (!File.writable?(@xmlDir) or (File.exist?(@docJsonFile.to_s) and !File.writable?(@docJsonFile.to_s))))
        raise RuntimeError, "ERROR: Being used iin save doc JSON mode, but target directory #{@xmlDir.inspect} or target file #{@doJsonFile.inspect} is not writable."
      end

      return retVal
    end
    
    def examineFiles()
      XML_FILE_CONFS.each { |conf|
        fullPath = fullPath( conf[:fileName] )
        if(@forceDownload or (@downloadMissing and !File.size?(fullPath)))
          bytesWritten = downloadFile(conf)
          $stderr.debugPuts(__FILE__, __method__, 'STATUS', "Downloaded #{bytesWritten.inspect} for #{conf[:fileName].inspect}")
        else
          $stderr.debugPuts(__FILE__, __method__, 'STATUS', "Not downloading #{conf[:fileName].inspect}; @forceDownload: #{@forceDownload.inspect} ; @downloadMissing: #{@downloadMissing.inspect} ; file size: #{File.size?(fullPath)}")

        end
      }
    end

    def downloadFile(conf)
      byteCount = nil
      url = conf[:url]
      open(url) { |urlFh|
        if(urlFh.status.first !~ /^2/)
          raise IOError, "Received non-OK response from orphadata.org server when tryingto retrieve #{conf[:dataSet]} dataset file via url #{url.inspect}. Received code: #{urlFh.status.inspect}."
        else
          targetPath = fullPath(conf[:fileName])
          File.open(targetPath, "w+") { |fh|
            byteCount = fh.write( urlFh.read() )
          }
        end
      }
      return byteCount
    end

    def fullPath(fileName)
      return "#{@xmlDir}/#{fileName}"
    end
  end
end ; end ; end # module BRL ; module Sites ; module GeneReviews
