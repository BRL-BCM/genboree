#!/usr/bin/env ruby
=begin
=end

# ##############################################################################
# $Copyright:$
# ##############################################################################
# ##############################################################################
# VERSION INFO
# ##############################################################################
# $Id: gameXML_classify.rb 8681 2007-09-12 13:39:15Z andrewj $
# $Header: //brl-depot/brl/src/ruby/brl/formatMapper/gameXML_classify.rb#5 $
# $LastChangedDate: 2007-09-12 08:39:15 -0500 (Wed, 12 Sep 2007) $
# $LastChangedDate: 2007-09-12 08:39:15 -0500 (Wed, 12 Sep 2007) $
# $Change: 25671 $
# $HeadURL: svn://proline.brl.bcm.tmc.edu/brl-repo/brl/src/ruby/brl/formatMapper/gameXML_classify.rb $
# $LastChangedRevision: 8681 $
# $LastChangedBy: andrewj $
# ##############################################################################

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################
require 'getoptlong'						# for GetoptLong class (command line option parse)
require 'brl/util/util'					# for to_hash extension of GetoptLong class
require 'brl/util/propTable'
require 'brl/util/textFileUtil' # For TextReader/Writer classes
require 'rexml/document'
include REXML

# ##############################################################################
# Prepare some script globals and things
# ##############################################################################
class AnnotBin
	attr_accessor :name, :doc, :txtRE
	
	def initialize(name, doc, txtRE)
		@name,@doc,@txtRE = name,doc,txtRE		
	end
end

# ##############################################################################
# Constants
# ##############################################################################
ANNOT_BINS = {
							'PSEUDO' => AnnotBin.new('PSEUDO', Document.new(), /^LOCUS: Pseudogene/),
							'DELETE' => AnnotBin.new('DELETE', Document.new(), /^DELETE/),
							'HOLD'   => AnnotBin.new('HOLD', Document.new(), /^HOLD/),
							'NOVEL'  => AnnotBin.new('NOVEL', Document.new(), /^LOCUS: Novel/),
							'KNOWN_ALTERED' => AnnotBin.new('KNOWN_ALTERED', Document.new(), /(^Base change)|(supports extension of)|(^Gene merge)/),
							'KNOWN_WARN'    => AnnotBin.new('KNOWN_WARN', Document.new(), /(?:does not match genomic)|(?:^Evidence on wrong strand)|(?:^Genomic sequence[^>]*not present)|(?:^weird organism)|(?:Translation stop not found)/),
							'KNOWN'					=> AnnotBin.new('KNOWN', Document.new(), nil)
						}
ANNOT_BINS.each { |key, bin|	bin.doc.add_element('annotations') }
ANNOT_OUTS = {
							'PSEUDO' => File.new('pseudo.preMunged.game.xml', 'w+'),
							'DELETE' => File.new('delete.preMunged.game.xml', 'w+'),
							'HOLD'   => File.new('hold.preMunged.game.xml', 'w+'),
							'NOVEL'  => File.new('novel.preMunged.game.xml', 'w+'),
							'KNOWN_ALTERED' => File.new('known_altered.preMunged.game.xml', 'w+'),
							'KNOWN_WARN'    => File.new('known_warn.preMunged.game.xml', 'w+'),
							'KNOWN'					=> File.new('known.preMunged.game.xml', 'w+')
						}

# ##############################################################################
# Maybe useful functions
# ##############################################################################
def remk1(srcElem, parentElem, tagString)
	elem = parentElem.add_element(srcElem.elements[tagString].name)
	elem.text = srcElem.elements[tagString].text
	return elem
end

def reform1(srcElem, parentElem, nameString)
	elem = parentElem.add_element(nameString)
	elem.text = srcElem.text.strip.gsub(/\n/,'')
	return elem
end

def classify(node)
	nType = nil
	nText = node.has_text?() ? node.text : ''
	ANNOT_BINS.each { |key, bin|
		next if(key == 'KNOWN')
		if(nText =~ bin.txtRE)
			nType = key
			break
		end
	}
	return nType	
end

# ##############################################################################
# MAIN
# ##############################################################################
# Check args quick
unless(ARGV.size > 0)
	$stderr.puts "\n\nPROPER USAGE:\n\n\tgameXML_classify.rb <preMunge.xml>\n\n"
	exit(134)
end

# Loop over each file and process
ARGV.each { |fileName|
	unless(File.exists?(fileName))
		$stderr.puts "\n\nWARNING: the file '#{fileName}' doesn't exist! Skipping."
		next
	end
	# which chromosome?
	fileName =~ /\/?([1-90XYMxym]+)_[^\/]+\.xml/
	chrID = $1
	chrStr = 'chr'+chrID
	# Parse file
	inFile = File.new(fileName)
	idoc = Document.new(inFile)

	# Go through each annotation and try to classify it by annotComment and then by feature comment
	# Put features in correct place
	aType = nil 
	idoc.elements.each('annotations') { |top|
		top.elements.each('annotation') { |annot|
			annot.attributes['targetName'] = chrStr
			aType = nil
			annot.elements.each('annotComment') { |comm|
				aType = classify(comm)
				break unless(aType.nil?)
			}
			unless(aType.nil?)	# then put whole annotation into proper bin
				ANNOT_BINS[aType].doc.elements['annotations'].add_element(annot)
			else	# Have to classify feature-by-feature. Big pain.
				annot.elements.each('feature') { |feat|
					# create a holder annotation
					holder = Element.new('annotation')
					holder.attributes['targetName'] = chrStr
					holder.attributes['name'] = annot.attributes['name']
					te = Element.new('type') ; te.text = annot.elements['type'].text
					holder.add_element(te)
					annot.elements.each('annotComment') { |aComm|
						ace = Element.new('annotComment') ; ace.text = aComm.text
						holder.add_element(ace)
					}
					holder.add_element(feat)
					# Check the feature and decide which bin it goes in
					fType = nil
					feat.elements.each('featureComment') { |featComm|
						fType = classify(featComm)
						break unless(fType.nil?)
					}
					if(fType.nil?)	# then put this feature into proper bin
						ANNOT_BINS['KNOWN'].doc.elements['annotations'].add_element(holder)
					else
						begin
							ANNOT_BINS[fType].doc.elements['annotations'].add_element(holder)
						rescue => err
							$stderr.puts "\n\nERROR: bad classification? \n\nftype:\t'#{fType}'\n\tfeat:\n'#{feat.to_s}'\n\nannot:\n'#{annot.to_s}'\n\n"
							$stderr.puts err.message
							$stderr.puts err.backtrace.join("\n")
						end
					end
				}
			end
		}
	}
}

# Output the annotations in each bin
ANNOT_OUTS.each { |binKey, file|
	# Have we got any annotations?
	puts "binKey: '#{binKey}'"
	cc = 0 ; ANNOT_BINS[binKey].doc.root.each_element('annotation') { |xx| cc += 1 }
	if(cc > 0) # then we have annotations to output
		ANNOT_BINS[binKey].doc.write(file,1)
	end
	file.close
}

exit(0)
