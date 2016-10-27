#!/bin/env ruby
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/script/scriptDriver' # Should be using this class properly, but we're not here
require 'brl/db/dbrc'

class MockSimpleAlleleRegistrar
  THE_ONLY_CANONICAL_ALLELE = "http://10.15.6.65/reg/allele/CA043298847185603"
  FAKE_REG_TOOL_CONFIG_DOC  = "http://genboree.org/REST/v1/grp/GenboreeKB%20Test/kb/GenboreeKB%20Test/coll/Biosamples/doc/KBTEST-TESTDOC2-BS"

  # CLASS "INSTANCE" VARIABLES (real class variables with accessors)
  # - Can be set once by infrastructure code, like Genboree web server code
  # - Initialized here to sensible defaults for command-line (non-server) usage
  # - Accessible via MockSimpleAlleleRegistrar.domainAlias
  class << self
    # @return [Hash,nil] <Genboree Infrastructure> For use within Genboree web-server process. Will be set by infrastructure to
    #   appropriate value to allow proper ApiCaller usage in self-request scenarios.
    attr_accessor :domainAlias
    MockSimpleAlleleRegistrar.domainAlias = nil
  end

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


  # @param [String] confDocUrl The URL of the tool configuration KB doc, providing pointers to key resources like decoder data, key collections,
  #  key query docs needed, etc.
  # @param [Hash] hostAuthMap A map of 1+ Genboree hosts (each host is a key) pointing to a 2-column Array containing the USER_NAME and
  #   SHA1(username+password) respectively. ApiCaller knows how to deal with this map--selecting the appropriate host--
  #   when it is provided as the 3rd arguement to its constructor. apiCaller = ApiCaller.new(host, path, hostAuthMap).
  # @raise ArgumentError
  def initialize(confDocUrl, hostAuthMap)
    # Initialize state variables
    @rackEnv = {}
    # Some sanity check on confDocUrl
    confDocUri = URI.parse(confDocUrl) rescue nil
    if(confDocUri.is_a?(URI) and confDocUri.host.to_s =~ /\S/ and confDocUri.scheme.to_s =~ /\S/ and confDocUri.path.to_s =~ /\S/)
      @confDocUrl = confDocUrl
    else
      raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"ERROR: The configuration KB Doc URL argument (#{confDocUrl.inspect}) doesn't look like a full & valid URL.")
    end
    @hostAuthMap = hostAuthMap
    $stderr.debugPuts(__FILE__, __method__, "STATUS", "Constructor. Instance state:\n  - @confDocUrl = #{@confDocUrl.inspect}\n  - @hostAuthMap = #{@hostAuthMap ? "\n#{hh = @hostAuthMap.deep_clone ; hh.each_value { |vv| vv[1] = '~~REDACTED~~' } ; JSON.pretty_generate(hh)}" : nil}")
  end

  # @param [String] value The string record to retrieve or register as an Allele. Currenly only hgvs strings are supported.
  # @param [String] type The kind of value being provided. Only :hgvs is support right now, but consider addition of :vcf or similar in the future
  # @return [String,nil] If non-nil, the Canonical Allele URL for the allele. If nil, something when wrong and @errMsg will be consulted.
  def canonicalAlleleURL(value, type=:hgvs)
    retVal = nil
    if(type == :hgvs)
      retVal = THE_ONLY_CANONICAL_ALLELE
    else # some other type, maybe supported in future
      retVal = nil
      errMsg = "BAD TYPE: The input type #{type.inspect} currently cannot be used to retrieve a canonical allele URL, nor register a new simple allele record and return the associated newly generated cannonical allele URL."
    end
    return retVal
  end
end

########################################################################
# MAIN
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Two args, Genboree host and hgvs
  if(ARGV.size != 2)
    $stderr.puts "\nUSAGE: mockSimpleAlleleRegistrar.rb {gbHost} {hgvsStr}\n\n"
    exit(134)
  else
    # Get the two args
    gbHost, hgvsStr = *ARGV
    # Build a ~valid hostAuthMap from a single dbrc record
    # - Not hard to convert ALL "API:" type records to a more full hostAuthMap if needed
    #   in order to connect to several genboree instances via private user+pass info.
    dbrc = BRL::DB::DBRC.new()
    hostAuthMap = dbrc.getHostAuthMap(gbHost, :api)
    # Instantiate
    sar = MockSimpleAlleleRegistrar.new(MockSimpleAlleleRegistrar::FAKE_REG_TOOL_CONFIG_DOC, hostAuthMap)
    # Get canonical allele for hgvs
    caUrl = sar.canonicalAlleleURL(hgvsStr, :hgvs)
    if(caUrl)
      puts "\nCanonical Allele URL for #{hgvsStr.inspect} is:\n    #{caUrl.inspect}\n\n"
    else # error
      puts "\nError getting canoncial allele URL for #{hgvsStr.inspect}:\n    #{sar.errMsg}\n\n"
    end
  end
end
