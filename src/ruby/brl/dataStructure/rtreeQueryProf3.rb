require 'brl/dataStructure/rtree3.rb'

tree3 = BRL::DataStructure::RTree.new(2,4)

dd = [] 
ii = nil
ARGV[0].to_i.times {|ii| rect = [ (rand(1000)-500), (rand(1000)-500), (rand(1000)-500), (rand(1000)-500) ] ; dd << rect }

rec = nil
dd.each { |rec| tree3.insert(rec.id, rec) }

pp = []
ii = nil
ARGV[1].to_i.times {|ii| point = [ (rand(2000)-1000), (rand(2000)-1000) ] ; pp << point }

pp.each { |point| tree3.queryPoint(point) }


