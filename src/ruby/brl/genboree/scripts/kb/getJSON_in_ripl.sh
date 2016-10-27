require 'brl/genboree/kb/converters/nestedTabbedModelConverter'


fileLineReader = File.open("./biosample.tsv")
converter = BRL::Genboree::KB::Converters::NestedTabbedModelConverter.new()
model = converter.parse(fileLineReader)
fileLineReader.rewind() rescue :noRewindWhoCares
biosampleModelJSON = converter.convert(fileLineReader)
File.open("./biosample.json", "w") { |file| file.write(biosampleModelJSON)}

fileLineReader = File.open("./run.tsv")
converter = BRL::Genboree::KB::Converters::NestedTabbedModelConverter.new()
model = converter.parse(fileLineReader)
fileLineReader.rewind() rescue :noRewindWhoCares
runModelJSON = converter.convert(fileLineReader)
File.open("./run.json", "w") { |file| file.write(runModelJSON)}

fileLineReader = File.open("./study.tsv")
converter = BRL::Genboree::KB::Converters::NestedTabbedModelConverter.new()
model = converter.parse(fileLineReader)
fileLineReader.rewind() rescue :noRewindWhoCares
studyModelJSON = converter.convert(fileLineReader)
File.open("./study.json", "w") { |file| file.write(studyModelJSON)}

fileLineReader = File.open("./submission.tsv")
converter = BRL::Genboree::KB::Converters::NestedTabbedModelConverter.new()
model = converter.parse(fileLineReader)
fileLineReader.rewind() rescue :noRewindWhoCares
submissionModelJSON = converter.convert(fileLineReader)
File.open("./submission.json", "w") { |file| file.write(submissionModelJSON)}

fileLineReader = File.open("./experiment.tsv")
converter = BRL::Genboree::KB::Converters::NestedTabbedModelConverter.new()
model = converter.parse(fileLineReader)
fileLineReader.rewind() rescue :noRewindWhoCares
experimentModelJSON = converter.convert(fileLineReader)
File.open("./experiment.json", "w") { |file| file.write(experimentModelJSON)}


fileLineReader = File.open("./analysis.tsv")
converter = BRL::Genboree::KB::Converters::NestedTabbedModelConverter.new()
model = converter.parse(fileLineReader)
fileLineReader.rewind() rescue :noRewindWhoCares
analysisModelJSON = converter.convert(fileLineReader)
File.open("./analysis.json", "w") { |file| file.write(analysisModelJSON)}

