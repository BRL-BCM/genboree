require 'brl/genboree/kb/validators/modelValidator'
mv = BRL::Genboree::KB::Validators::ModelValidator.new()

biosampleModel = JSON.parse( File.read("biosample.json"))
mv.validateModel(biosampleModel)
mv.validationErrors


runModel = JSON.parse( File.read("run.json"))
mv.validateModel(runModel)
mv.validationErrors


studyModel = JSON.parse( File.read("study.json"))
mv.validateModel(studyModel)
mv.validationErrors

submissionModel = JSON.parse( File.read("submission.json"))
mv.validateModel(submissionModel)
mv.validationErrors

analysisModel = JSON.parse( File.read("analysis.json"))
mv.validateModel(analysisModel)
mv.validationErrors

experimentModel = JSON.parse( File.read("experiment.json"))
mv.validateModel(experimentModel)
mv.validationErrors
