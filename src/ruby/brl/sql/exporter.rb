#!/usr/bin/env ruby
$VERBOSE = 1

require 'ucscSqlExporter'

genePredictionExporter = BRL::SQL::UcscSqlExporter.new

#genePredictionExporter.genePrediction("human","genscan","Gene","Genscan","Human")
#genePredictionExporter.genePrediction("softberryGene")
#genePredictionExporter.genePrediction("twinscan","Gene","Twinscan","")
#genePredictionExporter.genePrediction("tigrGeneIndex","Gene","TIGRGeneIndex","")

#genePredictionExporter.genePredictionFlat("human","refFlat","Gene","RefSeq","Human")

#genePredictionExporter.mRNA_EST_Blat("all_mrna","mRNA","mRNA","")
#genePredictionExporter.mRNA_EST_Blat("human","chrN_est","EST","EST","Human")

#genePredictionExporter.mRNA_EST_Blat("human","chrN_blastzTightMouse","blastzTightMouse","BlastZ","TightMouse")
genePredictionExporter.mRNA_EST_Blat("human","chrN_blastzBestMouse","blastzBestMouse","BlastZ","BestMouse")
#genePredictionExporter.mRNA_EST_Blat("human","chrN_blastzMm2","blastzMouse","BlastZ","Mouse")


