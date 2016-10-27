require 'brl/dataStructure/rtree3.rb'

tree3 = BRL::DataStructure::RTree.new(2,4)

dd = [] 
ii = nil
ARGV[0].to_i.times {|ii| rect = [ (rand(1000)-500), (rand(1000)-500), (rand(1000)-500), (rand(1000)-500) ] ; dd << rect }

rec = nil
dd.each { |rec| tree3.insert(rec.object_id, rec) }

