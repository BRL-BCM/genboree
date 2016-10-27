require 'time'
require 'date'
require 'uri'
require 'json'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/sites/bioOntology'
require 'brl/extensions/units'
require 'brl/extensions/bson'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/util/autoId'
require 'open-uri'

module BRL ; module Genboree ; module KB ; module Validators
  class ModelValidator
  extend ::BRL::Genboree::KB::Util::AutoId

  FIELDS =
  {
    'name'        => { :classes => { String => 'string' },  :default  => nil, :required => true,
      :extractVal => Proc.new { |pp, dflt| xx = pp['name'] ; ( (xx.is_a?(String) and xx =~ /\S/ and xx !~ /\./ and xx !~ /\$/ and xx !~ /^\[.*\]$/  and xx !~ /^\(.*\)$/  and xx !~ /^\{.*\}$/ and xx !~ /^\<.*\>$/  ) ? xx : dflt ) }
    },
    'identifier'  => { :classes => { TrueClass => 'true', FalseClass => 'false' }, :default  => false, :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['identifier'] ; ( ( xx.is_a?(TrueClass) or xx.is_a?(FalseClass) ) ? xx : dflt ) }
    },
    'domain'      => { :classes => { String => 'string' },  :default  => 'string', :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['domain'] ; ( ( xx.is_a?(String) and xx =~ /\S/ ) ? xx : dflt ) }
    },
    'default'     => { :classes => { Object => 'default' },  :default  => nil, :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['default'] ; xx }
    },
    'fixed'       => { :classes => { TrueClass => 'true', FalseClass => 'false' }, :default  => false, :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['fixed'] ; ( ( xx.is_a?(TrueClass) or xx.is_a?(FalseClass) ) ? xx : dflt ) }
    },
    'category'    => { :classes => { TrueClass => 'true', FalseClass => 'false' }, :default  => false, :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['category'] ; ( ( xx.is_a?(TrueClass) or xx.is_a?(FalseClass) ) ? xx : dflt ) }
    },
    'unique'      => { :classes => { TrueClass => 'true', FalseClass => 'false' }, :default  => false, :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['unique'] ; ( ( xx.is_a?(TrueClass) or xx.is_a?(FalseClass) ) ? xx : dflt ) }
    },
    'required'    => { :classes => { TrueClass => 'true', FalseClass => 'false' }, :default  => false, :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['required'] ; ( ( xx.is_a?(TrueClass) or xx.is_a?(FalseClass) ) ? xx : dflt ) }
    },
    'description' => { :classes => { String => 'string' },  :default  => '', :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['description'].strip ; ( xx.is_a?(String) ? xx : dflt ) }
    },
    'index'       => { :classes => { TrueClass => 'true', FalseClass => 'false' }, :default  => false, :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['index'] ; ( ( xx.is_a?(TrueClass) or xx.is_a?(FalseClass) ) ? xx : dflt ) }
    },
    'Object Type' => { :classes => { String => 'string' },  :default  => 'string', :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['Object Type'] ; ( ( xx.is_a?(String) and xx =~ /\S/ ) ? xx : dflt ) }
    },
    'properties'  => { :classes => { Array => 'array' },  :default  => nil, :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['properties'] ; ( xx.acts_as?(Array) ? xx : dflt ) }
    },
    'items'       => { :classes => { Array => 'array' },  :default  => nil, :required => false,
      :extractVal => Proc.new { |pp, dflt| xx = pp['items'] ; ( xx.acts_as?(Array) ? xx : dflt ) }
    }
  }

  # @see http://genboree.org/theCommons/projects/clindata-modelling/wiki/Data_Model_Schema_-_GenboreeKB_Dev for domain-specific documentation
  # @todo would be nice to have framework for domain specific validation error messages
  #   as many domains have multiple steps and a failure at any one of them causes a single
  #   generic validation error rather than a specific one
  # :type           => String with the type/label for this domain.
  # :rootDomain     => Is this domain allowed for a root property?
  # :internal       => Is this a special "internal use only" domain. Like for storing the non-KbDoc model
  #                    or for storing a whole KbDoc whose structure you don't know [in a version record]
  # :defaultVal     => What's the default, but valid, value for this domain? UIs and parsers/converters can use.
  # :autoContent    => Does this domain have automatically generated content capabilities?
  # :searchCategory => What's the general search category for this domain.
  #                    'string', 'int', 'float', 'timestamp', 'boolean', ''
  # :parseDomain    => Proc for parsing the domain value in the model.
  #                    vv   - domain string from model
  #                    *xx  - suck up any other args passed in.
  # :parseVal       => Proc for parsing a value from the doc.
  #                    vv   - the value from the doc
  #                    dflt - what to return if parseVal fails (not valid for this domain, usually nil is used)
  #                    pdom - the return value of parseDomain, used to get key domain info from the model in some cases (regexp, measurement)
  #                    *xx  - suck up other args passed in.
  # :inCast         => [optional; don't put if can use return value from parseVal directly for any casting prior to saving
  #                    If present, then this Proc shall be called with the value from parseVal and the original value prior to saving.
  #                    pv   - the value from parseVal
  #                    vv   - the original value from the doc
  #                    *xx  - suck up other args passed in.
  # :outCast        => [optional; don't put if outgoing cast not needed, i.e. nil ]
  #                    If present, then this Proc shall be called to cast the value coming out of mongo->BSON before
  #                    downstream serialization (like for rest, etc). Currently, downstream serialization is doing a to_s()
  #                    on the value. Sometimes that's not best (Mongo time -> Kb Date ; Mongo time -> Kb Time)
  #                    vv     - the Ruby object for the value, as result of getting out of mongo
  #                    strOK  - Boolean indicating if ok to cast to an appropriate string or not.
  #                    *xx    - suck up other args passed in.
  # :needsCasting   => Proc for scans/monitor scripts only! Used when determining if existing doc needs casting.
  #                    vv   - domain string from model
  #                    *xx  - suck up any other args passed in.
  DOMAINS =
  {
    /^autoID\(/ => {
      :type => 'autoID', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => true, :searchCategory => "string",
      :parseDomain => Proc.new { |vv, *xx| parseAutoIdDomain(vv, xx) },
      :parseVal    => Proc.new { |vv, dflt, pdom, *xx| validateAutoId(vv, dflt, pdom, xx) rescue dflt },
      :needsCasting => Proc.new { |vv, *xx| !(vv.is_a?(String) and vv != 'CONTENT_MISSING') }
    },
    /^autoIDTemplate\(/ => {
      :type => 'autoIDTemplate', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => true, :searchCategory => "string",
      :parseDomain => Proc.new { |vv, *xx| parseAutoIdTemplateDomain(vv, xx) },
      :parseVal    => Proc.new { |vv, dflt, pdom, *xx| validateAutoIdTemplate(vv, dflt, pdom, xx) rescue dflt },
      :needsCasting => Proc.new { |vv, *xx| !(vv.is_a?(String) and vv != 'CONTENT_MISSING') }
    },
    /^bioportalTerm\(/ => {
      :type => 'bioportalTerm', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => false, :searchCategory => "string",
      :parseDomain  => Proc.new { |vv, *xx| genbConf = BRL::Genboree::GenboreeConfig.load(); vv.to_s.strip =~ /^bioportalTerm\((http:\/\/data\.bioontology\.org\/search\?.*)\)/ ; ($& ? BRL::Sites::BioOntology.fromUrl($1, :proxyHost => genbConf.cachingProxyHost, :proxyPort => genbConf.cachingProxyPort) : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( pdom.is_a?(BRL::Sites::BioOntology) ? ( pdom.termInOntology?(vv.to_s) ? pdom.prefLabelForTerm.to_s : dflt ) : dflt ) },
      :needsCasting => Proc.new { |vv, *xx| false }
    },
    /^bioportalTerms\(/ => {
      :type => 'bioportalTerms', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => false, :searchCategory => "string",
      :parseDomain  => Proc.new { |vv, *xx| genbConf = BRL::Genboree::GenboreeConfig.load() ; ontologies = [] ; subtrees = [] ; vv = vv.to_s.gsub(/^bioportalTerms\(/, '') ; vv.to_s.strip.scan(/\(\s*([^\),]+?)\s*,\s*(http(?:(?::\/\/)|(?:%3A%2F%2F)).*?)\s*\)/) { |pairArray| ontologies.push(pairArray.first) ; subtrees.push(pairArray.last) ; } ; ontologies.compact! ; subtrees.compact! ; ( (!ontologies.empty? and !subtrees.empty? and ontologies.size == subtrees.size) ? BRL::Sites::BioOntology.new(ontologies, subtrees, nil, :proxyHost => genbConf.cachingProxyHost, :proxyPort => genbConf.cachingProxyPort) : nil ) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( pdom.is_a?(BRL::Sites::BioOntology) ? ( pdom.termInOntology?(vv.to_s) ? pdom.prefLabelForTerm.to_s : dflt ) : dflt ) },
      :needsCasting => Proc.new { |vv, *xx| false }
    },
    /^boolean$/ => {
      :type => 'boolean', :rootDomain => false, :internal => false, :defaultVal => false, :autoContent => false, :searchCategory => "boolean",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^boolean$/ ; ($& ? 'boolean' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| vv = vv.to_s.strip.autoCast(true) ; if(vv == true or vv == false) then vv else dflt end },
      :needsCasting => Proc.new { |vv, *xx| !( vv.is_a?(TrueClass) or vv.is_a?(FalseClass) ) }
    },
    /^dataModelSchema$/ => {
      :type => 'dataModelSchema', :rootDomain => false, :internal => true, :defaultVal => nil, :searchCategory => "",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^dataModelSchema$/ ; ($& ? 'dataModelSchema' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( vv.is_a?(String) ? JSON.parse(vv.to_s) : ( (vv.acts_as?(Hash) or vv.acts_as?(Array)) ? vv : dflt ) ) rescue dflt },
      :needsCasting => Proc.new { |vv, *xx| false }
    },
    /^date$/ => {
      :type => 'date', :rootDomain => true, :internal => false, :defaultVal => Date.parse(DateTime.now.to_s).to_s, :autoContent => false, :searchCategory => "",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^date$/ ; ($& ? 'date' : nil) },
      # BSON serialization won't convert Date or DateTimes to BSON/Mongo-compatible type. Must use Time, and the actual Time is stored in mongo as object not String.
      # Note: this may affect dumping/presentation of dates in UIs since "date" properties will see a Time-like value (string) in the payload
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( (vv.is_a?(String) and vv.strip =~    /(?:^\d{1,3}\s*[\/\-]\s*\d{1,3}\s*[\/\-]\d+$)|(?:^\d{1,3}\s*\.\s*\d{1,3}\s*\.\d+$)/) ? dflt : ( vv.is_a?(Date) ? Time.parse(vv.to_s) : ( vv.is_a?(Time) ? Time.parse(Date.parse(vv.to_s).to_s) : ( (vv.is_a?(String) or vv.is_a?(DateTime)) ? Time.parse(Date.parse(Time.parse(vv.to_s).to_s).to_s) : dflt ) ) ) ) rescue dflt },
      :outCast      => Proc.new { |vv, strOK, *xx| rr = Date.parse(vv.to_s) ; rr = rr.to_s if(strOK) ; rr },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(Time) }
    },
    /^dbRef$/ => {
      :type => 'dbRef', :rootDomain => true, :internal => true, :defaultVal => nil, :searchCategory => "",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^dbRef$/ ; ($& ? 'dbRef' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( vv.is_a?(BSON::ObjectId) ? vv : (BSON.interpret(vv.to_s.strip) rescue dflt) ) },
      :needsCasting => Proc.new { |vv, *xx| false }
    },
    /^document$/ => {
      :type => 'document', :rootDomain => false, :internal => true, :defaultVal => nil, :searchCategory => "",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^document$/ ; ($& ? 'document' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( vv.is_a?(BRL::Genboree::Kb::KbDoc) ? vv : ( vv.is_a?(String) ? BRL::Genboree::Kb::KbDoc.new(JSON.parse(vv.to_s.strip)) : ( (vv.acts_as?(Hash)) ? BRL::Genboree::Kb::KbDoc.new(vv) : dflt ) ) ) rescue dflt },
      :needsCasting => Proc.new { |vv, *xx| false }
    },
    /^enum\(/ => {
      :type => 'enum', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => false, :searchCategory => "string",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^enum\(\s*(\S.*)\)$/ ; ($1 ? ( hh = {}; $1.gsub(/\\,/, "\v").split(/,/).each { |yy| hh[yy.gsub(/\v/, ',').strip] = true }; hh ) : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| pdom.key?(vv.to_s.strip) ? vv.to_s.strip : dflt  },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(String) }
    },
    /^fileUrl$/ => {
      :type => 'fileUrl', :rootDomain => true, :internal => false, :defaultVal => "", :autoContent => false, :searchCategory => "string",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^fileUrl$/ ; ($& ? 'fileUrl' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( vv = vv.to_s.strip ; vv =~ /^(?:[^:\/ \t\n\?\&]+):\/\/[^\/\?& \t\n]+(?:\/[^\/\?& \t\n]*)+(?:\?|$)/ ? vv : dflt ) rescue dflt },
      :inCast       => Proc.new { |pv, vv, *xx| pv.to_s },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(String) }
    },
    /^float$/ => {
      :type => 'float', :rootDomain => true, :internal => false, :defaultVal => 0.0, :autoContent => false, :searchCategory => "float",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^float$/ ; ($& ? 'float' : dflt) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| vv.to_s.strip =~ /^((?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?)$/i ; ($1 ? $1.to_f : dflt) },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(Float) }
    },
    /^floatRange\(/ => {
      :type => 'floatRange', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => false, :searchCategory => "float",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^floatRange\(\s*((?:-|\+)?[0-9]*\.?[0-9]+(?:e(?:-|\+)?[0-9]+)?)?\s*,\s*((?:-|\+)?[0-9]*\.?[0-9]+(?:e(?:-|\+)?[0-9]+)?)?\s*\)\s*$/ ; ( $& ? ( (!$1.nil? or !$2.nil?) ? ( strt = ( $1 || (-1.0 * Float::MAX) ) ; stp  = ( $2 || Float::MAX ) ; (strt.to_f .. stp.to_f) ) : nil ) : nil ) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| vv.to_s.strip =~ /^((?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?)$/i ; ($1 ? ( pdom.include?($1.to_f) ? $1.to_f : dflt ) : dflt) },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(Float) }
    },
    /^gbAccount$/ => {
      :type => 'gbAccount', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => true, :searchCategory => "",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^gbAccount$/ ; ($& ? 'gbAccount' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| genbConf = BRL::Genboree::GenboreeConfig.load(); dbu = BRL::Genboree::DBUtil.new(genbConf.dbrcKey, nil, nil); recs = dbu.selectUserByName(vv.to_s.strip); recs.first['name'] ? :CONTENT_NEEDED : dflt rescue dflt },
      :inCast       => Proc.new { |pv, vv, *xx| vv.to_s },
      :needsCasting => Proc.new { |vv, *xx| !(vv.is_a?(String) and vv != 'CONTENT_NEEDED') }
    },
    /^int$/ => {
      :type => 'int', :rootDomain => true, :internal => false, :defaultVal => 0, :autoContent => false, :searchCategory => "int",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^int$/ ; ($& ? 'int' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| vv.to_s.strip =~ /^((?:-|\+)?\d+)$/ ; ($1 ? $1.to_i : dflt) },
      :needsCasting => Proc.new { |vv, *xx| vv.is_a?(Integer) }
    },
    /^intRange\(/ => {
      :type => 'intRange', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => false, :searchCategory => "int",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^intRange\(\s*((?:-|\+)?\d+)?\s*,\s*((?:-|\+)?\d+)?\s*\)$/ ; ( $& ? ( (!$1.nil? or !$2.nil?) ? ( strt = ( $1 || (-1 * Integer::MAX64) ) ; stp  = ( $2 || Integer::MAX64 ) ; (strt.to_i .. stp.to_i) ) : nil ) : nil ) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| vv.to_s.strip =~ /^((?:-|\+)?\d+)$/ ; ($1 ? ( pdom.include?($1.to_i) ? $1.to_i : dflt ) : dflt) },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(Integer) }
    },
    /^labelUrl$/ => {
      :type => 'labelUrl', :rootDomain => true, :internal => false, :defaultVal => "", :autoContent => false, :searchCategory => "string",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^labelUrl$/ ; ($& ? 'labelUrl' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( vv = vv.to_s.strip ; vv.gsub!("\\|", "\v") ; splitTerms = vv.split("|") ; splitTerms[0].strip! ; splitTerms[0].gsub!("\v", "|") ; labelOK = splitTerms[0].empty? ? false : true ; splitTerms[1].strip! ; splitTerms[1] = splitTerms[1].is_a?(URI) ? splitTerms[1] : (URI.parse(splitTerms[1].to_s.strip) rescue dflt) ; urlOK = ((!splitTerms[1].is_a?(URI) or (splitTerms[1].is_a?(URI) and splitTerms[1].path == "" and splitTerms[1].host == nil)) ? false : true) ; (labelOK and urlOK) ? splitTerms : dflt) rescue dflt },
      # Note that this casting will work best if both pv and vv are given as arguments. Otherwise, since pv is a two element array, first element will be pv and second element will be vv. I tried to cover this with #{pv.to_s}|#{vv.to_s}, but results may vary.
      :inCast       => Proc.new { |pv, vv, *xx|  pv.is_a?(Array) ? (pv[0].gsub!("|", "\\|") ; pv.join("|")) : "#{pv.to_s}|#{vv.to_s}" },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(String) }
    },
    # Domain for a validated label for a URL
    # Values are |-delimited label|url pairs ; label must be valid against domain in labelUrl({domain})
    /^labelUrl\((.+)\)$/ => {
      :type => 'domainedLabelUrl', :rootDomain => true, :internal => false, :defaultVal => "", :autoContent => false, :searchCategory => "string",
      :parseDomain => Proc.new { |vv, *xx| vv = vv.to_s.strip ; vv =~ /^labelUrl\((.+)\)$/ ; ($& ? { :labelDomain => $1.strip } : nil ) },
      :parseVal => Proc.new { |vv, dflt, pdom, *xx| domainedLabelUrlParseVal(vv, dflt, pdom, *xx) },
      :inCast => Proc.new { |pv, vv, *xx| pv.is_a?(Array) ? (pv[0].gsub!("|", "\\|") ; pv.join("|")) : "#{pv.to_s}|#{vv.to_s}" },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(String) }
    },
    /^measurement\(/ => {
      :type => 'measurement', :rootDomain => false, :internal => false, :defaultVal => nil, :autoContent => false, :searchCategory => "",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^measurement\(([^\)\t\n]+)\)/i ; ($& ? (Unit($1.strip) rescue :UNIT_UNKNOWN) : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( pdom.is_a?(Unit) ? ( valUnit = Unit(vv) rescue dflt ; (valUnit and valUnit.compatible?(pdom) ) ? ( valUnit.convert_to(pdom) * 1.0) : dflt ) : dflt ) },
      :inCast       => Proc.new { |vv, *xx| (vv * 1.0).to_s },
      :needsCasting => Proc.new { |vv, *xx| true }
    },
    /^measurementApprox\(/ => {
      :type => 'measurementApprox', :rootDomain => false, :internal => false, :defaultVal => nil, :autoContent => false, :searchCategory => "",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^measurementApprox\(([^\)\t\n]+)\)/i ; ($& ? (Unit($1.strip) rescue :UNIT_UNKNOWN) : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| parseMeasurementApprox(vv, dflt, pdom, xx) },
      :inCast       => Proc.new { |pv, vv, *xx| pv.to_s.gsub("..", " - ") },
      :needsCasting => Proc.new { |vv, *xx| true }
    },
    /^measurementRange\(/ => {
      :type => 'measurementRange', :rootDomain => false, :internal => false, :defaultVal => nil, :autoContent => false, :searchCategory => "",
      # returns :UNIT_UNKNOWN if unit is unknown or the two units in the range are not compatible
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^measurementRange\(([^,\t\n]+),([^\)\t\n]+)\)/i ; ($& ? ((Unit($1.strip)..Unit($2.strip)) rescue :UNIT_UNKNOWN) : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| parseMeasurementRange(vv, dflt, pdom, xx) },
      :inCast       => Proc.new { |vv, *xx| (vv * 1.0).to_s },
      :needsCasting => Proc.new { |vv, *xx| true }
    },
    /^modeledDocument$/ => {
      :type => 'modeledDocument', :rootDomain => false, :internal => true, :defaultVal => nil, :searchCategory => "",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^modeledDocument$/ ; ($& ? 'modeledDocument' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( vv.is_a?(BRL::Genboree::KB::KbDoc) ? vv : ( vv.is_a?(String) ? BRL::Genboree::KB::KbDoc.new(JSON.parse(vv.to_s.strip)) : ( vv.acts_as?(Hash) ? BRL::Genboree::KB::KbDoc.new(vv) : dflt ) ) ) rescue dflt },
      :needsCasting => Proc.new { |vv, *xx| false }
    },
    /^negFloat$/ => {
      :type => 'negFloat', :rootDomain => true, :internal => false, :defaultVal => 0.0, :autoContent => false, :searchCategory => "float",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^negFloat$/ ; ($& ? 'negFloat' : dflt) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| vv.to_s.strip =~ /^((?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?)$/i ; ( ($1 and $1.to_f <= 0.0) ? $1.to_f : dflt) },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(Float) }
    },
    /^negInt$/ => {
      :type => 'negInt', :rootDomain => true, :internal => false, :defaultVal => 0, :autoContent => false, :searchCategory => "int",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^negInt$/ ; ($& ? 'negInt' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| vv.to_s.strip =~ /^((?:-\d+)|0)$/ ; ($1 ? $1.to_i : dflt) },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(Integer) }
    },
    /^numItems$/ => {
      :type => 'numItems', :rootDomain => false, :internal => false, :defaultVal => 0, :autoContent => false, :searchCategory => "int",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^numItems$/ ; ($& ? 'numItems' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| vv.to_i },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(Integer) }
    },
    /^omim$/ => {
      :type => 'omim', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => true, :searchCategory => "string",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^omim$/ ; ($& ? 'omim' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( vv.to_s.strip =~ /^\d+$/ ? :CONTENT_NEEDED : dflt ) },
      :inCast       => Proc.new { |pv, vv, *xx| vv.to_s },
      :needsCasting => Proc.new { |vv, *xx| !(vv.is_a?(String) and vv != 'CONTENT_NEEDED') }
    },
    /^pmid$/ => {
      :type => 'pmid', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => true, :searchCategory => "string",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^pmid$/ ; ($& ? 'pmid' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( vv.to_s.strip =~ /^\d+$/ ? :CONTENT_NEEDED : dflt ) },
      :inCast       => Proc.new { |pv, vv, *xx| vv.to_s },
      :needsCasting => Proc.new { |vv, *xx| !(vv.is_a?(String) and vv != 'CONTENT_NEEDED') }
    },
    /^posFloat$/ => {
      :type => 'posFloat', :rootDomain => true, :internal => false, :defaultVal => 0.0, :autoContent => false, :searchCategory => "float",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^posFloat$/ ; ($& ? 'posFloat' : dflt) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| vv.to_s.strip =~ /^((?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?)$/i ; ( ($1 and $1.to_f >= 0.0) ? $1.to_f : dflt) },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(Float) }
    },
    /^posInt$/ => {
      :type => 'posInt', :rootDomain => true, :internal => false, :defaultVal => 0, :autoContent => false, :searchCategory => "int",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^posInt$/ ; ($& ? 'posInt' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| vv.to_s.strip =~ /^(\+?\d+)$/ ; ($1 ? $1.to_i : dflt) },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(Integer) }
    },
    # @todo fix the required double-escaping of \ and remove the gsub here ... probably there so can use RAW string in javascript regexp code. Wrong. *Make* the correct javascript.
    /^regexp\(/ => {
      :type => 'regexp', :rootDomain => true, :internal => false, :defaultVal => nil, :autoContent => false, :searchCategory => "string",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^regexp\(\s*(\S.*)\s*\)$/ ; ($1 ? Regexp.new($1.gsub(/\\\\/, '\\')) : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( pdom.is_a?(Regexp) ? (vv.to_s.strip =~ pdom ; ($~ ? $~ : dflt)) : dflt ) },
      :inCast       => Proc.new { |pv, vv, *xx| pv.string },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(String) }
    },
    /^string$/  => {
      :type => 'string', :rootDomain => true, :internal => false, :defaultVal => "", :autoContent => false, :searchCategory => "string",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^string$/ ; ($& ? 'string' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| if(vv.is_a?(String)) then vv.strip ; elsif(vv.nil?) then vv = "" ;else dflt end },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(String) }
    },
    /^timestamp$/ => {
      :type => 'timestamp', :rootDomain => true, :internal => false, :defaultVal => Time.now.to_s, :autoContent => false, :searchCategory => "",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^timestamp$/ ; ($& ? 'timestamp' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( (vv.is_a?(String) and vv.strip =~ /(?:\b\d{1,3}\s*[\/\-]\s*\d{1,3}\s*[\/\-]\d+\b)|(?:\b\d{1,3}\s*\.\s*\d{1,3}\s*\.\d+\b)/) ? dflt : ( vv.is_a?(Time) ? vv : ( (vv.is_a?(String) or vv.is_a?(DateTime) or vv.is_a?(Date)) ? Time.parse(vv.to_s.strip) : dflt ) ) ) rescue dflt },
      :outCast      => Proc.new { |vv, strOK, *xx| rr = Time.parse(vv.to_s) ; rr = rr.rfc822 if(strOK) ; rr },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(Time) }
    },
    /^url$/ => {
      :type => 'url', :rootDomain => true, :internal => false, :defaultVal => "", :autoContent => false, :searchCategory => "string",
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^url$/ ; ($& ? 'url' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| ( vv.is_a?(URI) ? vv : (URI.parse(vv.to_s.strip) rescue dflt) ) },
      :inCast       => Proc.new { |pv, vv, *xx| pv.to_s },
      :needsCasting => Proc.new { |vv, *xx| !vv.is_a?(String) }
    },
    /^\[valueless\]$/  => {
      :type => '[valueless]', :rootDomain => false, :internal => false, :defaultVal => nil, :autoContent => false, :searchCategory => "",
      # @todo: Going forward: let's store nil/null for [valueless], not "" and making sure to cast ""=>nil. Required DocValidator change.
      :parseDomain  => Proc.new { |vv, *xx| vv.to_s.strip =~ /^\[valueless\]$/ ; ($& ? '[valueless]' : nil) },
      :parseVal     => Proc.new { |vv, dflt, pdom, *xx| if(vv.nil? or (vv.is_a?(String) and vv !~ /\S/)) then '' ; else dflt end },
      :inCast       => Proc.new { |pv, vv, *xx| nil },
      :needsCasting => Proc.new { |vv, *xx| true }
    }
  }

  attr_accessor :validationErrors
  attr_accessor :validationWarnings
  attr_accessor :validationMessages
  attr_accessor :nonCoreFields
  attr_accessor :needsCastingPropPaths
  attr_accessor :relaxedRootValidation

  # @return [Hash] Property paths for properties needing indexing.
  #  Values are @Hash@es currently with symbol @:unique@ which is a flag indicating whether the index is unique or not.
  #  The root property is NOT included in this list. It ALWAYS has a unique index on it.
  attr_accessor :indexedProps
  alias_method  :indexedDocLevelProps, :indexedProps
  alias_method :indexedDocLevelProps=, :indexedProps=

  def initialize()
    @validationErrors = []
    @relaxedRootValidation = false
  end

  def validateModel(modelDoc)

    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "modelDoc is a #{modelDoc.class.inspect}")
    @validationErrors = []
    @validationWarnings =  []
    @validationMessages = []
    @needsCastingPropPaths = []
    @itemsListStack = []
    @indexedProps = {}
    @nonCoreFields = {}
    # Set flag indicating we've seen the "identifier"
    # - this will only get reset when entering an "items" list and restored when finished with it
    # - the doc identifier is the id amongst the set of documents and properties within an items
    #   list can have an identifier for id'ing an item amongst the set of items
    @haveIdentifier = false
    # Is this a property-based modelDoc or the actual model data?
    if(modelDoc.is_a?(BRL::Genboree::KB::KbDoc))
      # Assume we can dig out the actual non-prop-oriented model data structure stored at name.model:
      model = modelDoc.getPropVal('name.model') rescue nil
      if(model.nil?)
        # No such property name.model. Assume modelDoc IS the model data structure, converted to a KbDoc but not actually property oriented:
        model = modelDoc
        #@validationErrors << "ERROR: The model parameter is a full BRL::Genboree::KB::KbDoc document, but does not have a valid 'model' sub-property where the actual model data can be found."
      end
    else
      model = modelDoc
    end
    # Start examining the model
    if(@validationErrors.empty?)
      validateRootPropertyDef(model)
    end
    @validationMessages << "DOC\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
    return @validationErrors.empty?
  end

  def validateRootPropertyDef(prop)
    # pathElems is an Array with the current elements of the property path
    # - a _copy_ gets passed forward as we recursively evaluate the model
    #   . a copy so we don't have to pop elements off the end when finishing a recurive call
    # - used to keep track of exactly what property in the model is being assessed
    pathElems = []
    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "prop is a #{prop.class.inspect} ; contents:\n\n#{JSON.pretty_generate(prop)}\n\n")
    if(prop.acts_as?(Hash) and !prop.empty?)
      # First quick check for unknown fields
      prop.each_key { |field|
        unless(FIELDS.key?(field)) # not a known field ; allow & save if not similar to known field
          fieldDowncase = field.downcase
          # Just look for 1 similar field via find()
          similarField = FIELDS.find { |fieldName, fieldRec| (fieldName.downcase == fieldDowncase) }
          if(similarField and !similarField.empty?)
            @validationErrors << "ERROR: You have an unknown property field #{field.inspect} for the root property in your model. This is not an officially-supported field, and may be a typo. It appears to be similar to #{similarField.first.inspect}. Please note that field names are case sensitive."
          else # Not similar. Unlikely to be a typo. Allow and save!
            @nonCoreFields[field] = true
          end
        end
      }
      # If things look good (no possible field typos), proceed with root property validation
      if(@validationErrors.empty?)
        name = FIELDS['name'][:extractVal].call(prop, nil)
        pathElems << name
        begin
          if(name)
            identifier = FIELDS['identifier'][:extractVal].call(prop, nil)
            if(identifier or @relaxedRootValidation)
              domain = FIELDS['domain'][:extractVal].call(prop, 'string')
              if(domain)
                # Known domain?
                domainInfo = DOMAINS.find { |re, rec| domain =~ re }
                if(domainInfo.is_a?(Array) and domainInfo.size == 2)
                  domainRec = domainInfo.last
                  parsedDomain = parseDomain(domain)
                  if(parsedDomain.nil? or parsedDomain == :UNIT_UNKNOWN)
                    if(parsedDomain.nil?)
                      @validationErrors << "ERROR: The value for the 'domain' field (#{domain.inspect}) for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property does not appear to be valid in the model; it is not recognized as one of the allowable domains."
                    elsif(parsedDomain == :UNIT_UNKNOWN)
                      retVal = nil
                      @validationErrors << "ERROR (#{parsedDomain}): The 'domain' field of the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property in the model does not appear to be valid for the #{domainRec[:type].inspect} type domain. The unit you provided is not known; please use a more standard unit abbreviation--typically there are several acceptable aliases--or arrange to have your unit added (Genboree supports hundreds of different units, we can probably add yours). Alternatively, consider a regexp type domain for this property."
                    end
                  else
                    # One of the domains sensible for root property?
                    if(domainRec[:rootDomain] or @relaxedRootValidation)
                      fixed = FIELDS['fixed'][:extractVal].call(prop, nil)
                      if(fixed.nil? or fixed == false or @relaxedRootValidation)
                        category = FIELDS['category'][:extractVal].call(prop, nil)
                        if(category.nil? or category == false or @relaxedRootValidation)
                          unique = FIELDS['unique'][:extractVal].call(prop, nil)
                          if(unique.nil? or unique == true or @relaxedRootValidation)
                            required = FIELDS['required'][:extractVal].call(prop, nil)
                            if(required.nil? or required == true or @relaxedRootValidation)
                              items = FIELDS['items'][:extractVal].call(prop, nil)
                              if(items.nil? or @relaxedRootValidation)
                                default = FIELDS['default'][:extractVal].call(prop, nil)
                                if(default.nil?)
                                  # Set flag indicating we've seen the "identifier"
                                  # - this will only get reset when entering an "items" list and restored when finished with it
                                  # - the doc identifier is the id amongst the set of documents and properties within an items
                                  #   list can have an identifier for id'ing an item amongst the set of items
                                  @haveIdentifier = true
                                  # Seems ok schema for a root property. Validate properties.
                                  validateModelProperties(prop['properties'], pathElems.dup)
                                else
                                  @validationErrors << "ERROR: the root property cannot have a default defined. It is the document identifier and is different for each document; yet the property definition for the root property has a default of #{default.inspect}."
                                end
                              else
                                @validationErrors << "ERROR: the root property cannot itself have a sub-items list. Create a dedicated property which will have the sub-items. The root property can only have sub-properties."
                              end
                            else
                              @validationErrors << "ERROR: the root property must be required; you cannot override this."
                            end
                          else
                            @validationErrors << "ERROR: the root property must be unique; you cannot override this. This is the whole point of it being the document identifier"
                          end
                        else
                          @validationErrors << "ERROR: the 'category' field in the root property either has an improper value--and only valid values will be accepted--or it is valid but set to true. The root property cannot be a category. It is not a category, it is a unique identifier for the document."
                        end
                      else
                        @validationErrors << "ERROR: the 'fixed' field in root property either has an improper value--and only valid values will be accepted--or it is valid but set to true. The root property cannot be fixed/static; i.e. cannot be determined by the model. It must have a document-specific identifier value, rather than a fixed or pre-determined value."
                      end
                    else
                      @validationErrors << "ERROR: #{domain.inspect} cannot be used as a the domain of the root property. Remember, the root property is the document identifier in the collection."
                    end
                  end
                else
                  @validationErrors << "ERROR: #{domain.inspect} is not a supported value for the domain field."
                end
              else
                @validationErrors << "ERROR: if present, the domain's value must be a string and must match one of the known domain types."
              end
            else
              @validationErrors << "ERROR: the root property must have the 'identifier' field, which must have the value true. i.e. the model explicitly asserts that the root property will be the unique document identifier in the collection (models must 'sign off' on this, it will not be assumed automatically). "
            end
          else
            @validationErrors << "ERROR: problem with the 'name' of the root property (#{prop['name'].inspect}). Either the required 'name' field  is missing in the property definition, or it doesn't have a value, or that value cannot be used as a property name. For example, property names cannot contain dot ('.') nor dollar sign ('$'), nor start & end with any matched pairs of '{}', '()', '[]', '<>'."
          end
        rescue => err
          $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating model! Exception when processing #{name.inspect} (current property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'})")
          raise err # reraise...should be caught elsewhere
        end
      end
    else # model arg no good?
      if(@validationErrors.empty?) # then it's not some KbDoc problem we've already handled...it's something else
        @validationErrors << "ERROR: the model parameter is not a filled-in Hash which minimally defines the root-level property. It's either empty or nil."
      end
    end
    @validationMessages << "PROP #{name.inspect}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'}    # (seen total of #{@validationErrors.size} errors at this point)"
    return @validationErrors
  end

  def validateModelProperties(properties, pathElems)
    begin
      if(properties and properties.acts_as?(Array))
        # Keep a list of all properties defined in the properties array (each can only appear once)
        namesHash = Hash.new { |hh, kk| hh[kk] = 0 }
        properties.each { |propDef|
          @validationErrors = validatePropertyDef(propDef, pathElems.dup, namesHash)
        }
        # Check the names list for any that appear twice
        namesHash.each_key { |name|
          if(namesHash[name] > 1)
            @validationErrors << "ERROR: the sub-property #{name.inspect} is defined more than once under #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}. This is not allowed."
          end
        }
      end
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating model! Exception when processing property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}")
      raise err # reraise...should be caught elsewhere
    end
    @validationMessages << "#{' '*(pathElems.size)}SUB-PROPS OF #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
    return @validationErrors
  end

  def validateModelItems(items, pathElems)
    begin
      if(items and items.acts_as?(Array))
        if(items.size == 1)
          # Track any nesting of items-lists within the doc via stack
          @itemsListStack.push(pathElems.join('.')) if(pathElems.is_a?(Array))
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "itemListStack grew to:\n  - #{@itemsListStack.join("\n  - ")}")
          # Clear flag indicating we've seen the "identifier"
          # - this will only get reset when entering an "items" list and restored when finished with it
          # - the doc identifier is the id amongst the set of documents and properties within an items
          #   list can have an identifier for id'ing an item amongst the set of items
          origHaveIdentifier = @haveIdentifier
          @haveIdentifier = false
          propDef = items.first
          # Now check some other root-property type things. Not quite everything the doc root property checks but many are exactly same.
          # - first property (only) must have identifier=true in its root property
          identRec = FIELDS['identifier']
          identVal = identRec[:extractVal].call(propDef, identRec[:default])
          unless(identVal)
            @validationErrors << "ERROR: within the 'items' array for  #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} there must be one single-rooted property definition Hash, and the root property in that definition MUST be an identifier property; but it is not. You must explicitly assert that your root property for items in the list is an identifier (by default properties do not act as identifiers). i.e. the value for the root property MUST be able to act as a unique identifier for items in the list! If you have non-identifier type metadata you also want to store for each item, it will be in sub-properties of this root property."
          end
          # No matter what, this items-identifier propDef WILL be indexed, which we can trigger by ensuring that field is present
          propDef['index'] = true
          # - must have domain that is indentifier friendly (and maybe some other root-prop like checking)
          domainStr = FIELDS['domain'][:extractVal].call(propDef, nil)
          if(domainStr and domainStr =~ /\S/)
            rootDomain = getDomainField(domainStr, :rootDomain)
            if(rootDomain == false) # If domain bad, will be nil; want that caught/reported elsewhere
              @validationErrors << "ERROR: #{domainStr.inspect} cannot be used as a the domain of an identifier property. It is extremely inappropriate for a unique identifier and is likely to not be what you want, or to cause problems you didn't anticipate."
            end
          else # bad domain string
            # no-op, if this was problem, it will be caught in validatePropertDef
          end
          # - no default
          default = FIELDS['default'][:extractVal].call(propDef, nil)
          unless(default.nil?)
            @validationErrors << "ERROR: the root property of items in an item list cannot have a default defined. This root property is the item identifier and is different for each item; yet the property definition for the root property has a default of #{default.inspect}."
          end
          # - must be required
          required = FIELDS['required'][:extractVal].call(propDef, nil)
          unless(required.nil? or required == true)
            @validationErrors << "ERROR: the root property of items in an item list must be required; you cannot override this."
          end
          # - must be unique
          unique = FIELDS['unique'][:extractVal].call(propDef, nil)
          unless(unique.nil? or unique == true)
            @validationErrors << "ERROR: the root property must be unique; you cannot override this. This is the whole point of it being a identifier within the items list."
          end
          # - not fixed
          fixed = FIELDS['fixed'][:extractVal].call(propDef, nil)
          unless(fixed.nil? or fixed == false)
            @validationErrors << "ERROR: the 'fixed' field in root property either has an improper value--and only valid values will be accepted--or it is valid but set to true. The root property cannot be fixed/static; i.e. cannot be determined by the model. It must have a document-specific identifier value, rather than a fixed or pre-determined value."
          end
          # Ok, now that we've checked some root-property like things, recurse into usual validation of the property definition.
          @validationErrors = validatePropertyDef(propDef, pathElems.dup)
          @haveIdentifier = origHaveIdentifier
          # Done with this level of items at least, pop it off the nested items list stack
          @itemsListStack.pop()
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "itemListStack shrunk to:\n  - #{@itemsListStack.join("\n  - ")}")
        else
          @validationErrors << "ERROR: the 'items' field for  #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} should have exactly one property definition Hash within it. Items lists are homogenous, so there is only 1 property definition, and it must be present to indicate the kind of property that can appear within the list."
        end
      end
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating model! Exception when processing property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'})")
      raise err # reraise...should be caught elsewhere
    end
    @validationMessages << "#{' '*(pathElems.size)}ITEMS LIST OF #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'} (#{@validationErrors.size})"
    return @validationErrors
  end

  def validatePropertyDef(propDef, pathElems, namesHash=Hash.new{|hh,kk| hh[kk] = 0})
    if(propDef.acts_as?(Hash) and !propDef.empty? and propDef.key?('name'))
      name = FIELDS['name'][:extractVal].call(propDef, nil)
      begin
        # @todo is name unique next to others at this level?
        if(name)
          pathElems << name
          namesHash[name] += 1
          # First check that propDef only has one of 'properties' or 'items'
          unless(propDef.key?('properties') and propDef.key?('items'))
            # Examine the fields individually
            propDef.each_key { |field|
              if(field != 'name') # handled name already
                # PHASE 1 - Basic check on the field
                if(FIELDS.key?(field))
                  fieldRec = FIELDS[field]
                  quickValidateField(field, fieldRec, propDef, pathElems)
                  if(@validationErrors.empty?)
                    # PHASE 2 - Check some specific cases in more depth
                    # - domain
                    if(field == 'domain')
                      # Known domain? Parseable domain string?
                      value = fieldRec[:extractVal].call(propDef, nil)
                      if(value)
                        parsedDomain = parseDomain(value)
                        if(parsedDomain.nil? or parsedDomain == :UNIT_UNKNOWN)
                          if(propDef.key?('domain'))
                            domainStr = FIELDS['domain'][:extractVal].call(propDef, nil)
                          else
                            domainStr = FIELDS['domain'][:default]
                          end
                          domainRec = getDomainRec(domainStr)
                          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "domainStr:\t#{domainStr.inspect}\npropDef:\t#{JSON.pretty_generate(propDef)}\n")
                          if(parsedDomain.nil?)
                            @validationErrors << "ERROR: The value for the 'domain' field (#{domainStr.inspect}) for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property does not appear to be valid in the model; it is not recognized as one of the allowable domains."
                          elsif(parsedDomain == :UNIT_UNKNOWN)
                            retVal = nil
                            @validationErrors << "ERROR (#{parsedDomain}): The 'domain' field of the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property in the model does not appear to be valid for the #{domainRec[:type].inspect} type domain. The unit you provided is not known; please use a more standard unit abbreviation--typically there are several acceptable aliases--or arrange to have your unit added (Genboree supports hundreds of different units, we can probably add yours). Alternatively, consider a regexp type domain for this property."
                          end
                        else # may be ok
                          # Check some key other fields in propDef to see if compatible with domain ('default' checked in its own section below)
                          # - Check certain fields when domain is '[valueless]'
                          if(value == '[valueless]')
                            # - check 'fixed' field
                            fixedRec = FIELDS['fixed']
                            fixedVal = fixedRec[:extractVal].call(propDef, fixedRec[:default])
                            unless(fixedVal)
                              @validationErrors << "ERROR: Properties with the #{value.inspect} domain MUST also be 'fixed'. But the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property definition in your model, whose domain is #{value.inspect}, indicates the property is NOT fixed and CAN be changed (which is the default for any property). i.e. You must assert that you understand such properties cannot have their value changed by explicitly specifying 'fixed' is true for this property (there is no value to change for this property, you see)."
                            end
                            # - check 'unique' field
                            uniqueRec = FIELDS['unique']
                            uniqueVal = uniqueRec[:extractVal].call(propDef, uniqueRec[:default])
                            if(uniqueVal)
                              @validationErrors << "ERROR: Properties with the #{value.inspect} domain CANNOT also be 'unique'. There will be no value to be unique with! But the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property definition in your model, whose domain is #{value.inspect}, indicates the property's value IS unique. This doesn't make sense."
                            end
                          # - Check certain fields when domain is 'numItems'
                          elsif(value == 'numItems')
                            # - check 'fixed' field - cannot be fixed (number changes dynamically to represent number of items!)
                            fixedRec = FIELDS['fixed']
                            fixedVal = fixedRec[:extractVal].call(propDef, fixedRec[:default])
                            if(fixedVal)
                              @validationErrors << "ERROR: Properties with the #{value.inspect} domain CANNOT be 'fixed'. But the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property definition in your model, whose domain is #{value.inspect}, indicates the property IS fixed and CANNOT be changed."
                            end
                            # Check that property is an item list
                            unless(propDef.key?('items'))
                              @validationErrors << "ERROR: Properties with the #{value.inspect} domain MUST be an item list. But the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property definition in your model, whose domain is #{value.inspect}, does not have an 'items' field."
                            end
                          end
                        end
                      else
                        @validationErrors << "ERROR: The value for the 'domain' field of the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property does not appear to be valid; it is not recognized as one of the allowable domains. Check the syntax carefully, as that may explain why it's no recognized."
                      end
                    # - has identifier when already have one at this point?
                    elsif(field == 'identifier')
                      value = fieldRec[:extractVal].call(propDef, nil)
                      if(@haveIdentifier and value)
                        @validationErrors << "ERROR: The value for the 'identifier' field of the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property is true, but there is already a property tagged as the document or items list identifier property. Can only have one identifier property for a document (the root property) and only one identifier property for items appearing in an items list."
                      end
                    # -if provided, check that default works with parseVal and checkVal?
                    elsif(field == 'default')
                      value = fieldRec[:extractVal].call(propDef, nil)
                      unless(value.nil?)
                        # Need to check default vs domain
                        validInfo = validVsDomain(value, propDef, pathElems, { :castValue => true })
                        unless(validInfo.nil?)
                          # If validInfo is nil, then some problem with the 'domain' prevented us from checking out the value for 'default'
                          # - Error already recorded in @validationErrors by validVsDomain()
                          validInfoResult = validInfo[:result]
                          if(validInfoResult != :VALID and validInfoResult != :CONTENT_NEEDED and validInfoResult != :CONTENT_MISSING)
                            # Then the validation check specific failed (or gave CONTENT_MISSING or CONTENT_NEEDED which are not allowed for
                            # domain defaults) and the validation of 'default' vs 'domain' failed.
                            # Need to record message about this:
                            # - get domain string for our message
                            if(propDef.key?('domain'))
                              domainStr = FIELDS['domain'][:extractVal].call(propDef, nil)
                            else
                              domainStr = FIELDS['domain'][:default]
                            end
                            @validationErrors << "ERROR: The default value provided (#{value.inspect}) for property #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} does not match this property's domain! The default value must be valid within this domain: #{domainStr.inspect}"
                          else
                            # If straight up :VALID, forcibly set the value of the 'default' field to be the _casted_ version
                            propDef[field] = validInfo[:castValue] if(validInfoResult == :VALID)
                          end
                        end
                      else
                        @validationErrors << "ERROR: The default value for property #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} is nil. This is not allowed. If there is a sensible default or initial values, provide it. If you don't want a default applied for this property and/or a default doesn't make sense [e.g. because the field is 'required' and needs a real value from the user] then simply don't specify 'default'."
                      end
                    elsif(field == 'unique')
                      value = fieldRec[:extractVal].call(propDef, nil)
                      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Found UNIQUE value of #{value.inspect} for #{pathElems.join('.').inspect}")
                      unless(value.nil?)
                        propDef['unique'] = value # true of false, capture it
                        if(value) # if unique=true, will need an index as well, unless under an items list somewhere
                          if(@itemsListStack.empty?)
                            propDef['index'] = true
                            $stderr.debugPuts(__FILE__, __method__, "STATUS", "UNIQUE INDEX needed for #{pathElems.join('.').inspect}")
                            @indexedProps[pathElems.join('.')] = { :unique => true } if(pathElems.is_a?(Array))
                          end
                        end
                      end
                    elsif(field == 'index')
                      value = fieldRec[:extractVal].call(propDef, nil)
                      unless(value.nil?)
                        propDef['index'] = value
                        #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Found INDEX value of #{value.inspect} for #{pathElems.join('.').inspect}")
                        if(value) # then note we need to index this property
                          # NEW: we will even index within an items list! Just can't do unique indices within items lists.
                          # We need to look for the 'unique' flag for this property to see what kind of index to make
                          if(propDef.key?('unique'))
                            # - check 'unique' field
                            uniqueRec = FIELDS['unique']
                            uniqueVal = uniqueRec[:extractVal].call(propDef, uniqueRec[:default])
                            #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "    - have unique field with extracted value of: #{uniqueVal.inspect}; but are we under an items list? #{!@itemsListStack.empty?}")
                            # We only make use of the "unique" flag for *indexing* if NOT under an items Array.
                            # - Because "unique" in kb means it's unique in the current list-scope (e.g. unique WITHIN the array)
                            # - But for a Mongo index, unique means it's unique ACROSS DOCUMENTS. Ouch, not the same!
                            if(uniqueVal and @itemsListStack.empty?)  # then seeing unique=true and not under items lists
                              unique = true # we'll use unique flag in index
                            else
                              unique = false
                            end
                          else
                            unique = false
                          end
                          #$stderr.debugPuts(__FILE__, __method__, "STATUS", "#{unique ? 'UNIQUE' : 'NON-UNIQUE'} INDEX needed for #{pathElems.join('.').inspect}")
                          # Add indexed prop info
                          @indexedProps[pathElems.join('.')] = { :unique => unique } if(pathElems.is_a?(Array))
                        end
                      end
                    elsif(field == 'properties')
                      validateModelProperties(propDef[field], pathElems)
                    elsif(field == 'items')
                      validateModelItems(propDef[field], pathElems)
                    else # add any other special processing for specific fields as elsif here
                      # no-op
                    end
                  end
                else # not a known field ; allow & save if not similar to known field
                  fieldDowncase = field.downcase
                  # Just look for 1 similar field via find()
                  similarField = self.class::FIELDS.find { |fieldName, fieldRec| (fieldName.downcase == fieldDowncase) }
                  if(similarField and !similarField.empty?)
                    @validationErrors << "ERROR: You have an unknown property field #{field.inspect} for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} sub-property of #{pathElems.join('.').inspect} which is not an officially-supported field, but which may be a typo. It appears to be similar to #{similarField.first.inspect}. Please note that field names are case sensitive."
                  else # Not similar. Unlikely to be a typo. Allow and save!
                    @nonCoreFields[field] = true
                  end
                end
              end
              # If seen issues, stop processing rest of fields
              break unless(@validationErrors.empty?)
            } # propDef.each_key { |field|
            # Follow-up multi-field checks on propDef if individual fields look ok
            if(@validationErrors.empty?)
              # - non-fixed category? warning
              if( propDef.key?('category') and propDef.key?('fixed') and propDef['category'] and !propDef['fixed'])
                @validationWarnings << "WARNING: the #{name.inspect} property is marked as a category, but it is not fixed. This means anyone can change the 'value' for this category property. Is that what you want? Typically categories are fixed/static (~predefined headers), but this is not a requirement."
              end
            end
          else
            @validationErrors << "ERROR: The property definition for #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} contains both the 'properties' and 'items' fields. A property can have EITHER sub-properties or a homogenous list of sub-items, not both."
          end # unless(propDef.key?('properties') and propDef.key?('items'))
        else
          @validationErrors << "ERROR: problem with the 'name' of the property (#{propDef['name'].inspect}) under the parent #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}. Either the required 'name' field  is missing in the property definition, or it doesn't have a value, or that value cannot be used as a property name. For example, property names cannot contain dot ('.') nor dollar sign ('$'), nor start & end with any matched pairs of '{}', '()', '[]', '<>'."
          # To help trace in validationMessages, get the INVALID name directly:
          pathElems << propDef['name']
        end # if(name)
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "exception while validating model! Exception when processing property #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}")
        raise err # reraise...should be caught elsewhere
      end
    else
      @validationErrors << "ERROR: Invalid definition for a sub-property of #{pathElems.join('.').inspect}. A property definition must be a hash/map with at least the 'name' field."
    end # if(propDef.is_a?(Hash) and !propDef.empty? and propDef.key?('name'))
    @validationMessages << "#{' '*(pathElems.size)}PROP #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}\t=>\t#{@validationErrors.empty? ? 'OK' : 'INVALID'}    # (seen total of #{@validationErrors.size} errors at this point)"
    return @validationErrors
  end # def validatePropertyDef(propDef, pathElems, namesHash)

  def quickValidateField(field, fieldRec, propDef, pathElems)
    begin
      value = fieldRec[:extractVal].call(propDef, nil)
      okClass = fieldRec[:classes].keys.any?{ |fieldClass| value.is_a?(fieldClass) }
      unless(okClass)
        @validationErrors << "ERROR: If provided, the #{field.inspect} field of a property definition must be a: #{FIELDS[field][:classes].values.join(" or ")}. The property definition for #{field.inspect} in the #{pathElems.join('.').inspect} property contains #{propDef[field].inspect} which is invalid."
      else # Right type, can we dig out the value?
        value = fieldRec[:extractVal].call(propDef, nil)
        if(value.nil?)
          @validationErrors << "ERROR: If provided, the #{field.inspect} field of a property definition must be a: #{FIELDS[field][:classes].keys.join(" or ")}. Cannot be null/nil. The property definition for #{field.inspect} in the #{pathElems.join('.').inspect} property contains #{propDef[field].inspect} which is invalid."
        end
      end
    rescue => err
      $stderr.debugPuts(__FILE__, __method__, "FATAL ERROR", "Exception while validating model! Exception when processing property path: #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'}")
      raise err # reraise...should be caught elsewhere
    end
    return @validationErrors
  end

  # Validate a value against a domain
  # @param [Object] value the value to validate against its domain
  # @param [Hash] propDef the property definition from the model that will be used to validate the value
  #   mostly for its 'domain' key for lookup in DOMAINS
  # @param [Array<String>] pathElems tokenized property path for the property being validated
  # returns [Hash, nil] If catastrophic problem while validating, @nil@. Else a {Hash} with validation results}. Keys:
  #   @:result => [Symbol] indicating if the value is valid vs domain or not:
  #     :VALID
  #     :INVALID
  #     :CONTENT_MISSING
  #     :CONTENT_NEEDED
  #   @:needsCasting@ => [boolean, nil] By default nil (missing key and means NOT DETERMINED/UNKNOWN). This is NOT CHECKED
  #     by default since (a) not needed and (b) extra compute time calling @Proc@ during validations. But if you have set
  #     the :needsCastCheck option to true, then @validVsDomain@ will call the appropriate :needsCasting @Proc@ for the
  #     domain and record the result at the @:needsCasting@ key in the return value. This boolean will then indicate
  #     whether the @value@ argument needs casting/normalization or not, and will be filled in regardless of whether
  #     the actual casting is done or not (according to the :castValue option).
  #   @:castValue@ => [Object, various, nil] Unless @opts[:castValue]@ argument is true, this will
  #     be exactly the same as the @value@ argument. If casting is enable this will have the
  #     casted/normalized version of value and be suitable for insertion into the underlying MongoDB
  #     database system. @value@ can be valid/acceptable but be COMPLETELY INAPPROPRIATE/ILLEGAL to
  #     actually store without being normalized to the domain in the model. This may also be @nil@
  #     when @:status => :CONTENT_NEEDED@ or @:status => :CONTENT_MISSING@
  #   When the :result is :CONTENT_NEEDED or :CONTENT_MISSING, additional keys are added which assist with content generation:
  #     @:pathElems (pass through of the parameter)
  #     @:propDef (pass through of the parameter)
  #     @:domainRec the value of DOMAINS associated with the key from propDef['domain']
  #     @:parsedDomain the result of calling the proc at domainRec[:parseDomain] which sometimes
  #       sets up objects that can be used for content generation
  def validVsDomain(value, propDef, pathElems, opts={ :castValue => false, :needsCastCheck => false })
    # Default: not determined as valid and no casting:
    retVal = { :result => :INVALID, :castValue => value }
    needsCastCheck = opts[:needsCastCheck]
    castValue = opts[:castValue]
    # - get domain string
    if(propDef.key?('domain'))
      domainStr = FIELDS['domain'][:extractVal].call(propDef, nil)
    else
      domainStr = FIELDS['domain'][:default]
    end
    if(domainStr)
      # Get the record for that domain
      domainRec = getDomainRec(domainStr)
      if(domainRec)
        # - parse domain
        parsedDomain = domainRec[:parseDomain].call(domainStr, nil)
        if(parsedDomain and parsedDomain != :UNIT_UNKNOWN)
          # - parse value in context of the domain
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "value: #{value.inspect} ; parsedDomain:\n#{parsedDomain.inspect}")
          parseVal = domainRec[:parseVal].call(value, nil, parsedDomain)

          # Are we asked to ADDITIONALLY/OPTIONALLY do the needs casting check on value??
          if(needsCastCheck)
            retVal[:needsCasting] = domainRec[:needsCasting].call(value, nil)
          end

          # parseVal.nil? implicitly handled by default retVal. Failed.
          if(parseVal == :CONTENT_NEEDED or parseVal == :CONTENT_MISSING)
            retVal.merge!({ :result => parseVal, :pathElems => pathElems, :propDef => propDef, :domainRec => domainRec, :parsedDomain => parsedDomain })
          elsif(!parseVal.nil?)
            # Then value is valid vs domain
            retVal[:result] = :VALID
          end
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "retVal:\n#{retVal.inspect}\n\ncastValue: #{castValue.inspect}")
          # Are we being asked to cast the value if needed?
          if(castValue and retVal[:result] != :INVALID)
            # Yes. Can we use parseVal directly as the casted value or do we need to employ this domain's :inCast Proc?
            inCastProc = domainRec[:inCast]
            if(inCastProc)
              # Yes there is a proc for casting parseVal for incoming data, use it.
              retVal[:castValue] = inCastProc.call(parseVal, value)
            else
              retVal[:castValue] = parseVal
            end
          end
        elsif(parsedDomain == :UNIT_UNKNOWN)
          retVal = nil
          @validationErrors << "ERROR (#{parsedDomain}): The 'domain' field (#{domainStr.inspect}) in the definition of the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property in the model does not appear to be valid for the #{domainRec[:type].inspect} type domain. The unit you provided is not known; please use a more standard unit abbreviation--typically there are several acceptable aliases--or arrange to have your unit added (Genboree supports hundreds of different units, we can probably add yours). Alternatively, consider a regexp type domain for this property."
        else
          retVal = nil
          @validationErrors << "ERROR: The value for the 'domain' field (#{domainStr.inspect}) in the definition of the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property in the model does not appear to be valid for the #{domainRec[:type].inspect} type domain. Double-check you are following the correct syntax, especially for enum-, range-, regexp-, and boolean-type domains."
        end
      else
        retVal = nil
        @validationErrors << "ERROR: The value for the 'domain' field (#{domainStr.inspect}) for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property does not appear to be valid in the model; it is not recognized as one of the allowable domains."
      end
    else
      retVal = nil
      @validationErrors << "ERROR: The value for the 'domain' field (#{domainStr.inspect}) for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property does not appear to be valid in the model; it is not recognized as one of the allowable domains."
    end
    return retVal
  end
  def self.validVsDomain(value, propDef, pathElems, opts={ :castValue => false, :needsCastCheck => false })
    obj = self.new()
    obj.validationErrors = []
    rv = obj.validVsDomain(value, propDef, pathElems, opts)
    return rv
  end

  def getDomainStr(propDef)
    domainStr = FIELDS['domain'][:extractVal].call(propDef, nil)
  end

  # Match a domain against one of the keys in DOMAINS
  # @return [NilClass, Hash] the value of the associated key's parseDomain proc;
  #   nil if no matching domain or the parsing fails for a candidate domain
  def getDomainRec(domainStr)
    self.class.getDomainRec(domainStr)
  end
  def self.getDomainRec(domainStr)
    retVal = nil
    domainInfo = DOMAINS.find { |re, rec| domainStr =~ re }
    if(domainInfo.is_a?(Array) and domainInfo.size == 2)
      retVal = domainInfo.last
    end
    return retVal
  end

  def getDomainField(domainStrOrPropDef, field)
    if(domainStrOrPropDef.acts_as?(Hash))
      domainStr = getDomainStr(domainStrOrPropDef)
    end
    retVal = nil
    domainRec = getDomainRec(domainStr)
    if(domainRec)
      retVal = domainRec[field]
    end
    return retVal
  end

  def parseDomain(domainStr)
    retVal = nil
    domainRec = getDomainRec(domainStr)
    if(domainRec)
      retVal = domainRec[:parseDomain].call(domainStr, nil)
    end
    # else # else domainRec is nil and @validationErrors already has messages about this
    return retVal
  end

  def getDefaultValue(propDef, pathElems)
    retVal = nil
    # Determine domain first
    domainStr = (propDef['domain'] or 'string')
    domainRec = getDomainRec(domainStr)
    if(domainRec)
      if(propDef.key?('default'))
        # If has explicit default, make sure matches domain and return it
        defaultFromPropDef = propDef['default']
        unless(defaultFromPropDef.nil?)
          # Need to check default vs domain
          validInfo = validVsDomain(defaultFromPropDef, propDef, pathElems, { :castValue => true })
          if(validInfo)
            if(validInfo[:result] == :VALID)
              retVal = defaultFromPropDef
            else # problem with the default ; not yet recorded in @validationErrors
              @validationErrors << "ERROR: the default provided by the model (#{defaultFromPropDef.inspect} for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property does not match the domain/type for the property (#{domainStr.inspect})."
              retVal = nil
            end
          else # default we retrived is nil; so something wrong in the prodDef and already recorded in @validationErrors
            @validationErrors << "ERROR: The default value for property #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} is nil. This is not allowed. If there is a sensible default or initial values, provide it. If you don't want a default applied for this property and/or a default doesn't make sense [e.g. because the field is 'required' and needs a real value from the user] then simply don't specify 'default'."
            retVal = nil
          end
        else
          @validationErrors << "ERROR: the model has an explicit null/nil for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property. This is not allowed."
        end
      else
        # Else use default for that particular domain
        defaultVal = domainRec[:defaultVal]
        unless(defaultVal.nil?)
          retVal = defaultVal
        else
          retVal = nil
          @validationErrors << "ERROR: there is no sensible automatic default for the #{domainStr.inspect} domain and the model is not providing one. Therefore, cannot provide a sensible default for the  #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property."
        end
      end
    else
      @validationErrors << "ERROR: the property definition for the #{pathElems.is_a?(Array) ? pathElems.join('.').inspect : '{UNKNOWN/BROKEN}'} property specifies an unknown domain #{domainStr.inspect}. This is not allowed."
    end
    return retVal
  end

  def knownPropsMap(propDefsArray, initVal=true)
    if(propDefsArray.acts_as?(Array))
      retVal = {}
      propDefsArray.each { |propDef|
        if(propDef.acts_as?(Hash))
          propName = propDef['name']
          retVal[propName] = initVal if(propName and propName.to_s =~ /\S/)
        end
      }
    else
      retVal = nil
    end
    return retVal
  end

  # Parse a measurement approximation
  # @return [Range<Unit, Unit>] a range object representing the approximation e.g. 10 to 20 degF
  # @see BRL::Genboree::KB::Validators::ModelValidator::DOMAINS
  def self.parseMeasurementApprox(vv, dflt, pdom, *xx)
    rv = dflt
    if(pdom.is_a?(Unit))
      # check if provided value is a range
      rangeRe = /(-?[^-]+)-(.+)/
      matchData = rangeRe.match(vv)
      start = stop = nil
      if(matchData.nil?)
        # try provided value as a singleton
        start = stop = vv
      else
        start = matchData[1]
        stop = matchData[2]
      end

      # infer units as needed
      beginUnit = Unit(start.strip) rescue nil
      endUnit = Unit(stop.strip) rescue nil
      if(beginUnit.nil? or endUnit.nil?)
        rv = dflt
      else
        if(beginUnit.unitless? and endUnit.unitless?)
          # then set units based on the domain
          beginUnit = beginUnit.setUnits(pdom.units)
          endUnit = endUnit.setUnits(pdom.units)
        elsif(beginUnit.unitless? and !endUnit.unitless?)
          # then set units to match the other
          beginUnit = beginUnit.setUnits(endUnit.units)
        elsif(!beginUnit.unitless? and endUnit.unitless?)
          # then set units to match the other
          endUnit = endUnit.setUnits(beginUnits.units)
        else
          # noop
        end

        # verify units are compatible with the domain
        if(beginUnit.compatible_with?(pdom) and endUnit.compatible_with?(pdom))
          rv = ((beginUnit.convert_to(pdom) * 1.0)..(endUnit.convert_to(pdom) * 1.0))
        else
          rv = dflt
        end
      end
    else
      rv = dflt
    end
    return rv
  end

  # @return [Unit, dflt.class] a Unit in the pdom range or dflt.class if failure/otherwise
  def self.parseMeasurementRange(vv, dflt, pdom, *xx)
    rv = dflt
    vv = vv.to_s.strip
    if(pdom.is_a?(Range))
      valUnit = Unit(vv) rescue nil
      unless(valUnit.nil?)
        if(valUnit.unitless?)
          valUnit = valUnit.setUnits(pdom.first.units)
        end
        if(valUnit.compatible?(pdom.first))
          valUnitConv = valUnit.convert_to(pdom.first) * 1.0
          if(pdom.include?(valUnitConv))
            rv = valUnitConv
          end
        end
      end
    end
    return rv
  end

  # @return [NilClass, [String, URI]]
  # @see DOMAINS
  def self.domainedLabelUrlParseVal(vv, dflt, pdom, *xx)
    rv = dflt
    propDef = { "domain" => pdom[:labelDomain] }
    labelUrlDomainRec = getDomainRec("labelUrl")
    if(labelUrlDomainRec.nil?)
      rv = dflt
    else
      labelUrlPdom = labelUrlDomainRec[:parseDomain].call("labelUrl", nil)
      parsedLabelUrl = labelUrlDomainRec[:parseVal].call(vv, dflt, labelUrlPdom)
      if(parsedLabelUrl.nil?)
        rv = dflt
      else
        # then the parsed result is a pair: [string-to-validate, uri-object]
        valid = validVsDomain(parsedLabelUrl[0], propDef, ["mockedPropPath"])
        if(valid[:result] == :VALID)
          # then success! return this same pair
          rv = parsedLabelUrl
        else
          # otherwise not valid, return dflt
          rv = dflt
        end
      end
    end
    return rv
  end
end
end ; end ; end ; end # module BRL ; module Genboree ; module KB ; module Validators
