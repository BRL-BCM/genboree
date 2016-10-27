require 'brl/db/dbrc'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/kb/mongoKbDatabase'
gbHost = "10.15.5.109"
dbrc = BRL::DB::DBRC.new()
dbrcRec = dbrc.getRecordByHost(gbHost, :api)
mongoDbrcRec = dbrc.getRecordByHost(gbHost, :nosql)
apiCaller = BRL::Genboree::REST::ApiCaller.new(gbHost, "", dbrcRec[:user], dbrcRec[:password])

gbGroup = "exRNA Metadata"
gbKbName = "exRNA MD"
gbDbName = "KB:exRNA MD"

mongoDbName = BRL::Genboree::KB::MongoKbDatabase.constructMongoDbName(gbHost, gbGroup, gbKbName)
mdb = BRL::Genboree::KB::MongoKbDatabase.new(mongoDbName, mongoDbrcRec[:driver], { :user => mongoDbrcRec[:user], :pass => mongoDbrcRec[:password]} )
mdb.name
mdb.db.class
createStatus = mdb.create()

dbu = BRL::Genboree::DBUtil.new("DB:#{gbHost}", nil, nil)
grpRecs = dbu.selectGroupByName(gbGroup)
groupId = grpRecs.first['groupId']
insertStatus = dbu.insertKb(groupId, gbDbName, gbKbName, mongoDbName)

gbUser = 'sailakss'

newCollName = 'Studies'
exrnaStudiesModel = JSON.parse( File.read( "/home/sailakss/sai/tabbedModels/models_8282014/study.json"))
modelsHelper = mdb.modelsHelper
exrnaStudiesModelKbDoc = modelsHelper.docTemplate(newCollName)
exrnaStudiesModelKbDoc.setPropVal("name.model", exrnaStudiesModel)
collStatus = mdb.createUserCollection(newCollName, gbUser, exrnaStudiesModelKbDoc)

newCollName = 'Runs'
exrnaRunsModel = JSON.parse( File.read( "/home/sailakss/sai/tabbedModels/models_8282014/run.json"))
modelsHelper = mdb.modelsHelper
exrnaRunsModelKbDoc = modelsHelper.docTemplate(newCollName)
exrnaRunsModelKbDoc.setPropVal("name.model", exrnaRunsModel)
collStatus = mdb.createUserCollection(newCollName, gbUser, exrnaRunsModelKbDoc)

newCollName = 'Experiments'
exrnaExperimentsModel = JSON.parse( File.read( "/home/sailakss/sai/tabbedModels/models_8282014/experiment.json"))
modelsHelper = mdb.modelsHelper
exrnaExperimentsModelKbDoc = modelsHelper.docTemplate(newCollName)
exrnaExperimentsModelKbDoc.setPropVal("name.model", exrnaExperimentsModel)
collStatus = mdb.createUserCollection(newCollName, gbUser, exrnaExperimentsModelKbDoc)

newCollName = 'Analyses'
exrnaAnalysesModel = JSON.parse( File.read( "/home/sailakss/sai/tabbedModels/models_8282014/analysis.json"))
modelsHelper = mdb.modelsHelper
exrnaAnalysesModelKbDoc = modelsHelper.docTemplate(newCollName)
exrnaAnalysesModelKbDoc.setPropVal("name.model", exrnaAnalysesModel)
collStatus = mdb.createUserCollection(newCollName, gbUser, exrnaAnalysesModelKbDoc)

newCollName = 'Submissions'
exrnaSubmissionsModel = JSON.parse( File.read( "/home/sailakss/sai/tabbedModels/models_8282014/submission.json"))
modelsHelper = mdb.modelsHelper
exrnaSubmissionsModelKbDoc = modelsHelper.docTemplate(newCollName)
exrnaSubmissionsModelKbDoc.setPropVal("name.model", exrnaSubmissionsModel)
collStatus = mdb.createUserCollection(newCollName, gbUser, exrnaSubmissionsModelKbDoc)

newCollName = 'Biosamples'
exrnaBiosamplesModel = JSON.parse( File.read( "/home/sailakss/sai/tabbedModels/models_8282014/biosample.json"))
modelsHelper = mdb.modelsHelper
exrnaBiosamplesModelKbDoc = modelsHelper.docTemplate(newCollName)
exrnaBiosamplesModelKbDoc.setPropVal("name.model", exrnaBiosamplesModel)
collStatus = mdb.createUserCollection(newCollName, gbUser, exrnaBiosamplesModelKbDoc)
