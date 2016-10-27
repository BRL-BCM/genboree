# Require validator class
require 'brl/genboree/kb/validators/modelValidator'
require 'brl/genboree/kb/validators/docValidator'

# Instantiate a validator object
mv = BRL::Genboree::KB::Validators::ModelValidator.new()
dv = BRL::Genboree::KB::Validators::DocValidator.new()
# Read in & parse model's .json file:
# . returns Ruby nested hash data structure for the model
# . for example, from /usr/local/brl/home/genbadmin/tmp/arj/clingen/tmp on dev
externModel = JSON.parse( File.read("data_model.yml.json") )
litModel = JSON.parse( File.read("Lit.model.json") )

# Validate model, check error messages
# - validateModel() returns true if ok, false if bad model
# - it will put useful error message(s) into ModelValidator#validationErrors
# - may also want to check ModelValidator#validationWarnings I suppose
mv.validateModel(litModel) # => true (model OK)
mv.validationErrors # => [] (empty array because no errors to report)

mv.validateModel(externModel) # => true (model BAD)
mv.validationErrors # =>  ["ERROR: the root property must have the 'identifier' field, which must have the value true. i.e. the model explicitly asserts that the root property will be the unique document identifier in the collection (models must 'sign off' on this, it will not be assumed automatically). "]

# ------------------------------------------------------------------
require 'brl/db/dbrc'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

genbConf = BRL::Genboree::GenboreeConfig.load('/usr/local/brl/local/apache/genboree.config.properties')
dbrc = BRL::DB::DBRC.new()
gbHost = "10.15.5.109"
dbrcRec = dbrc.getRecordByHost(gbHost, :api)
apiCaller = ApiCaller.new(gbHost, "", dbrcRec[:user], dbrcRec[:password])

# ------------------------------------------------------------------
apiCaller.setRsrcPath("/REST/v1/grp/{grp}/kb/{kb}/coll/{collName}/model")
hr = apiCaller.get({ :grp => "ARJ.a", :kb => "GbKb - Test 2", :collName => "Cases & Predictions", :props => [ "ClinGenDbID.dbsnpID", "ClinGenDbID" ], :mode => "keyword", :op => "or", :val => "1", :lim => "", :det => true })
puts apiCaller.respBody
apiCaller.parseRespBody
caseModel = apiCaller.apiDataObj

mv.validateModel(caseModel)
mv.knownPropsMap(caseModel["properties"])

# ------------------------------------------------------------------
apiCaller.setRsrcPath("/REST/v1/grp/{grp}/kb/{kb}/coll/{collName}/model")
hr = apiCaller.get({ :grp => "ARJ.a", :kb => "GbKb - Test 2", :collName => "Lit. Curation Examples", :props => [ "ClinGenDbID.dbsnpID", "ClinGenDbID" ], :mode => "keyword", :op => "or", :val => "1", :lim => "", :det => true })
puts apiCaller.respBody
apiCaller.parseRespBody
litModel = apiCaller.apiDataObj

mv.validateModel(litModel)
mv.knownPropsMap(litModel["properties"])

# ------------------------------------------------------------------
apiCaller.setRsrcPath("/REST/v1/grp/{grp}/kb/{kb}/coll/{collName}/doc/{docId}")
hr = apiCaller.get({ :grp => "ARJ.a", :kb => "GbKb - Test 2", :collName => "Lit. Curation Examples", :docId => "MYH7:c.19881G>A -- Primary Familial Hypertrophic Cardiomyopathy", :det => false })
puts apiCaller.respBody
apiCaller.parseRespBody
litDoc1 = apiCaller.apiDataObj

dv.validateDoc(litDoc1, litModel)
dv.validationErrors
# VS
dv.validateDoc(litDoc1, caseModel)
dv.validationErrors # Props are CASE SENSITIVE
# VS
dv.validateDoc(litDoc1, externModel)
dv.validationErrors # Completely wrong doc

# ------------------------------------------------------------------
apiCaller.setRsrcPath("/REST/v1/grp/{grp}/kb/{kb}/coll/{collName}/docs?detailed={det}")
hr = apiCaller.get({ :grp => "ARJ.a", :kb => "GbKb - Test 2", :collName => "Lit. Curation Examples", :docId => "MYH7:c.19881G>A -- Primary Familial Hypertrophic Cardiomyopathy", :det => true })
apiCaller.parseRespBody
allLitDocs = apiCaller.apiDataObj

hr = apiCaller.get({ :grp => "ARJ.a", :kb => "GbKb - Test 2", :collName => "Cases & Predictions", :docId => "MYH7:c.19881G>A -- Primary Familial Hypertrophic Cardiomyopathy", :det => true })
apiCaller.parseRespBody
allCaseDocs = apiCaller.apiDataObj

allLitDocs.each_index { |ii|
  $stderr.puts "===> Lit. Doc ##{ii+1}: #{dv.validateDoc(allLitDocs[ii], litModel) ? '**VALID**' : '**INVALID**'}"
  dv.validationErrors.each { |err|
    $stderr.puts "     - #{err}"
  }
  $stderr.puts "     Trace:\n\n"
  $stderr.puts dv.validationMessages.reverse.join("\n")
  $stderr.puts '-'*70
}

allCaseDocs = apiCaller.apiDataObj
allCaseDocs.each_index { |ii|
  $stderr.puts "===> Case Doc ##{ii+1}: #{dv.validateDoc(allCaseDocs[ii], caseModel) ? '**VALID**' : '**INVALID**'}"
  dv.validationErrors.each { |err|
    $stderr.puts "     - #{err}"
  }
  $stderr.puts "     Trace:\n\n"
  $stderr.puts dv.validationMessages.reverse.join("\n")
  $stderr.puts '-'*70
}

# ------------------------------------------------------------------
