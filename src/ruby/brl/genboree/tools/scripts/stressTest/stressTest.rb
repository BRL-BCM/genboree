#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/abstract/resources/user'

userId = 1466 #raghuram
hostNames={:prod => "genboree.org", :dev =>"10.15.5.109"}
apiCaller=BRL::Genboree::REST::ApiCaller.new(hostNames[:dev],"/REST/v1/genboree/tool/stressTest/job",Abstraction::User.getHostAuthMapForUserId(nil, userId))
apiCaller.put(File.read(ARGV[0]))
puts apiCaller.respBody
exit