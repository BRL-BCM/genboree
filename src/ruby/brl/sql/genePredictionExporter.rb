#!/usr/bin/env ruby
$VERBOSE = 1

require 'ucscExporter'

genePredictionExporter = BRL::SQL::UcscExporter.new

#genePredictionExporter.genePrediction("genscan","Gene","Genscan","")
#genePredictionExporter.genePrediction("softberryGene")
#genePredictionExporter.genePrediction("twinscan","Gene","Twinscan","")
#genePredictionExporter.genePrediction("tigrGeneIndex","Gene","TIGRGeneIndex","")

#genePredictionExporter.genePredictionFlat("refFlat","Gene","RefSeq","")

#genePredictionExporter.mRNA_EST_Blat("all_mrna","mRNA","mRNA","")
genePredictionExporter.mRNA_EST_Blat("human","chrN_est","EST","EST","Human")

#genePredictionExporter.mRNA_EST_Blat("human","chrN_blastzTightMouse","blastzTightMouse","BlastZ","TightMouse")
