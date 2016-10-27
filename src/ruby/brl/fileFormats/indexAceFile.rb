#!/usr/bin/env ruby
require 'brl/fileFormats/aceFile'

aceFile = ARGV[0]
idx = BRL::FileFormats::AceFileIndexer.new()
idx.indexFile(aceFile)
idx.saveIndex(aceFile + '.idx')
idx.clear()
exit(0)

