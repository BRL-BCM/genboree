#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'hpricot'
require 'open-uri'

NCBI_NUC_DBS = [ 'nuccore', 'nucest', 'nucgss' ]

def searchNCBI(accNum)
  fastaElem = nil
  NCBI_NUC_DBS.each { |dbName|
    url = "http://www.ncbi.nlm.nih.gov/sites/entrez?term=#{accNum}&cmd=raw&db=#{dbName}&dopt=fasta"
    doc = Hpricot(open(url))
    fastaElem = doc.search("div.recordbody")
    break unless(fastaElem.nil? or fastaElem.empty?)
  }
  return fastaElem
end

$stdin.each { |accNum|
  accNum.strip!
  next if(accNum !~ /\S/ or accNum =~ /^#/)
  doc = Hpricot(open(url))
  fastaElem = searchNCBI(accNum)
  if(fastaElem.nil? or fastaElem.empty?)
    $stderr.puts "#{accNum} not found nuccore, nucest, nucgss databases at NCBI."
  else
    puts fastaElem.innerHTML
  end
  sleep(1 + rand(2))
}

exit(0)
