#!/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/script/scriptDriver' # Should be using this class properly, but we're not here
require 'brl/genboree/rest/apiCaller'
require 'brl/db/dbrc'
require 'brl/genboree/tools/alleleReg_v1/sAConfig'
require 'brl/genboree/tools/alleleReg_v1/theRegistrar'
require 'brl/genboree/tools/alleleReg_v1/allele'
require 'brl/genboree/tools/alleleReg_v1/generic_constructor'
require 'brl/genboree/tools/alleleReg_v1/genomic_constructor'
require 'brl/genboree/tools/alleleReg_v1/aminoacid_constructor'
require 'brl/genboree/tools/alleleReg_v1/refseq_apis'
require 'brl/genboree/tools/alleleReg_v1/position_normalize'
require 'brl/genboree/tools/alleleReg_v1/allele_generate_hash'
require 'brl/genboree/tools/alleleReg_v1/myclasses'
require 'brl/genboree/tools/alleleReg_v1/refseq_to_URI'
require 'brl/genboree/tools/alleleReg_v1/check_reg_status'
require 'brl/genboree/tools/alleleReg_v1/generate_canonical_allele'
require 'brl/genboree/tools/alleleReg_v1/identifier'
require 'brl/genboree/tools/alleleReg_v1/canonicalAllele'
require 'brl/genboree/tools/alleleReg_v1/get_genomic_allele'
require 'brl/genboree/tools/alleleReg_v1/coordTransform'
require 'brl/genboree/tools/alleleReg_v1/make_hgvs'
require 'brl/genboree/tools/alleleReg_v1/match_hgvs_to_all_patterns'
require 'brl/genboree/tools/alleleReg_v1/register_canonical_allele'
require 'brl/genboree/tools/alleleReg_v1/register_simple_allele'
require 'brl/genboree/tools/alleleReg_v1/update_ca_uri_using_simple_allele_uri'
require 'brl/genboree/tools/alleleReg_v1/update_ca_uri_using_uri'
require 'brl/genboree/tools/alleleReg_v1/add_related_simple_allele'
require 'brl/genboree/tools/alleleReg_v1/reverse_complement'
require 'brl/genboree/tools/alleleReg_v1/ca_from_api_call'
require 'brl/genboree/tools/alleleReg_v1/get_canonical_allele_by_uri'
require 'brl/genboree/tools/alleleReg_v1/register_canonical_allele_using_hash'
require 'brl/genboree/tools/alleleReg_v1/get_document_id'

include BRL::Genboree::REST

class SimpleAlleleRegistrar
  # ------------------------------------------------------------------
  # @return [String,nil] If non-nil, an explanation of the error that prevented canonical allele URL registration and/or retrieval
  attr_reader   :errMsg
  # @return [String] The URL of the tool configuration KB doc, providing pointers to key resources like decoder data, key collections,
  #  key query docs needed, etc.
  attr_reader :confDocUrl
  # ------------------------------------------------------------------
  # @return [Hash] A map of 1+ Genboree hosts (each host is a key) pointing to a 2-column Array containing the USER_NAME and
  #   SHA1(username+password) respectively. ApiCaller knows how to deal with this map--selecting the appropriate host--
  #   when it is provided as the 3rd arguement to its constructor. apiCaller = ApiCaller.new(host, path, hostAuthMap).
  attr_reader :hostAuthMap
  # ------------------------------------------------------------------
  # @return [Hash,nil] <Genboree Infrastructure> For use within Genboree web-server process. Will be set by infrastructure to
  #   appropriate value to allow proper ApiCaller usage in self-request scenarios.
  attr_accessor :rackEnv
  # @return [Hash,nil] <Genboree Infrastructure> For use within Genboree web-server process. Will be set by infrastructure to
  #   appropriate value to allow proper ApiCaller usage in self-request scenarios.
  attr_accessor :domainAlias
  # @param [String] confDocUrl The URL of the tool configuration KB doc, providing pointers to key resources like decoder data, key collections,
  #  key query docs needed, etc.
  # @param [Hash] hostAuthMap A map of 1+ Genboree hosts (each host is a key) pointing to a 2-column Array containing the USER_NAME and
  #   SHA1(username+password) respectively. ApiCaller knows how to deal with this map--selecting the appropriate host--
  #   when it is provided as the 3rd arguement to its constructor. apiCaller = ApiCaller.new(host, path, hostAuthMap).
  # @raise ArgumentError
  attr_accessor :parsedConfig
  attr_accessor :decoderHash
  attr_accessor :apiCaller

  def initialize(confDocUrl, hostAuthMap)
    # Initialize state variables
    @rackEnv = {}
    @domainAlias = nil

    # Some sanity check on confDocUrl
    confDocUri = URI.parse(confDocUrl) rescue nil
    if(confDocUri.is_a?(URI) and confDocUri.host.to_s =~ /\S/ and confDocUri.scheme.to_s =~ /\S/ and confDocUri.path.to_s =~ /\S/)
      @confDocUrl = confDocUrl
    else
      raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"ERROR: The configuration KB Doc URL argument (#{confDocUrl.inspect}) doesn't look like a full & valid URL.")
    end

    @hostAuthMap = hostAuthMap
  end

  # Setup for doing api calls and registering alleles etc.
  def init()
    confDocUri = URI.parse(@confDocUrl) rescue nil
    # set ApiCaller, that will be sent around and recycled
    # note that assuming that the config url is the url of host
    # if your config is on one host and api to do downstream things on other host this might not work
    apiCaller = ApiCaller.new(confDocUri.host, "", @hostAuthMap)
    apiCaller.initInternalRequest(@rackEnv, @domainAlias)
    # reusable apiCaller that will be passed around
    @apiCaller = apiCaller

    # get the configuration file
    $stderr.puts "Setting the apiCaller to get configuration"
    apic = self.apiCaller
    apic.setRsrcPath(confDocUri.path)
    apic.get

    if(apic.succeeded?)
      begin
        $stderr.puts "Processing config file and initializing SAConfig"
        # parsing kb config
        kbConfig = SAConfig.new(apic.parseRespBody)
      rescue => err
        msg = "Could not initialize simple allele using config KB Doc at URL #{@confDocUrl.inspect}. Possibly BAD config file."
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{msg} ApiCaller resp body when getting conf file:\n\n#{apic.respBody}\n\n")
        raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',msg)
      end
    else # failed
      msg = "Could not retrieve tool config doc at URL #{@confDocUrl.inspect} via the API. Possibly BAD URL or no permission."
      $stderr.debugPuts(__FILE__, __method__, "ERROR", "#{msg} ApiCaller http response was #{apic.httpResponse.inspect} and resp body when getting conf file:\n\n#{apic.respBody or 'N/A'}\n\n")
      raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',msg)
    end
    $stderr.puts "Storing in class accessor"
    @parsedConfig = kbConfig

    $stderr.puts "please see the parsed config here"
    $stderr.puts kbConfig.inspect

    # getting decoder document
    $stderr.puts "Getting decoder document"
    confDocUri = URI.parse(kbConfig.hgvsDecode_path) rescue nil
    confDocUri.nil?  ? (raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Could not parse uri of hgvs decoder")) : ("")

    # get the decoder document
    $stderr.puts "Setting the apiCaller to get decoder document"
    apic = self.apiCaller
    apic.setRsrcPath(confDocUri.path)
    apic.get
    apic.parseRespBody["data"].size == 0 ? (raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Apicall to get decoder return no data")) : ("")
    @decoderHash  = apic.parseRespBody["data"]
    $stderr.puts apic.inspect
    $stderr.puts "Done with populating decoderHash"
    # pass the decoder document, config and  hgvs to rest of the program
    #$stderr.debugPuts(__FILE__, __method__, "STATUS", "Constructor. Instance state:\n  - @confDocUrl = #{@confDocUrl.inspect}\n  - @hostAuthMap = #{@hostAuthMap ? "\n#{hh = @hostAuthMap.deep_clone ; hh.each_value { |vv| vv[1] = '~~REDACTED~~' } ; JSON.pretty_generate(hh)}" : nil}")
  end

  # @param [String] value The string record to retrieve or register as an Allele. Currenly only hgvs strings are supported.
  # @param [String] type The kind of value being provided. Only :hgvs is support right now, but consider addition of :vcf or similar in the future
  # @return [String,nil] If non-nil, the Canonical Allele URL for the allele. If nil, something when wrong and @errMsg will be consulted.
  #def hgvsToJSON
  #end

  def canonicalAlleleURL(value, type=:hgvs)
    init()
    #use config, decoder json and hgvs to generate simple allele
    retVal = nil
    if(type == :hgvs)
      begin
        #pass the config, decoder and json to the method who knows that with them
        abc = TheRegistrar.new(self.parsedConfig, self.decoderHash,self.apiCaller)
        retVal = abc.parseHGVS(value)
      rescue => err
        @errMsg = err.message
        retVal = nil
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Problem running allele registration tool. Passed error message to client: #{@errMsg.inspect}")
      end
    else
      retVal = nil
      @errMsg = "BAD TYPE: The input type #{type.inspect} currently cannot be used to retrieve a canonical allele URL, nor register a new simple allele record and return the associated newly generated cannonical allele URL."
    end
    return retVal
  end
end

########################################################################
# MAIN
########################################################################
# IF we are running this file (and not using it as a library), run it:

if($0 and File.exist?($0) and (BRL::Script::runningThisFile?($0, __FILE__, true)) rescue true)
  # Two args, Genboree host and hgvs
  if(ARGV.size != 2)
    $stderr.puts "\nUSAGE: simpleAlleleRegistrar.rb {gbHost} {hgvsStr}\n\n"
    exit(134)
  else
    # Get the two args
    gbHost, hgvsStr = *ARGV
    gbHost = URI.parse(gbHost)  #raise puts "Error parsing URI passed in"
    # Build a ~valid hostAuthMap from a single dbrc record
    # - Not hard to convert ALL "API:" type records to a more full hostAuthMap if needed
    #   in order to connect to several genboree instances via private user+pass info.
    dbrc = BRL::DB::DBRC.new()
    hostAuthMap = dbrc.getHostAuthMap(gbHost.host, :api)
    # Instantiate
    sar = SimpleAlleleRegistrar.new(gbHost.to_s, hostAuthMap)

    #sar.parsedConfig.gene_path
    #JSON::pretty_generate sar.decoderHash

    # Get canonical allele for hgvs
    caUrl = sar.canonicalAlleleURL(hgvsStr, :hgvs)

    if(caUrl)
      puts "\nCanonical Allele URL for #{hgvsStr.inspect} is:\n    #{caUrl.inspect}\n\n"
    else # error
      puts "\nError getting canoncial allele URL for #{hgvsStr.inspect}:\n    #{sar.errMsg}\n\n"
    end
  end
end
