#!/usr/bin/env ruby

require 'rubygems'
require 'cgi'
require 'json'
require 'highline'
require 'brl/util/util'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

host = 'localhost'
cacheUrlBase = '/REST/v1/grp/{grp}/db/{db}/browserCache'

# Welcome
puts "\nWelcome to the Browser Cache Clearing Utility!"
puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n\n"
# Get group & db from args if possible (consume ARGV)
group = ARGV.shift
db = ARGV.shift
# Ask if host is correct
puts "Genboree host to clear cache at is #{host.inspect}"
print "If correct, type 'yes' or 'y'; if not, provide host instead: "
hostAnswer = gets.strip
host = hostAnswer unless(hostAnswer =~ /^yes|y$/)
# Ask for group and database if wasn't on command line
# - group name
if(group.nil?)
  print "Group name: "
  group = gets.chomp
end
# - db name
if(db.nil?)
  print "User database name: "
  db = gets.chomp
end
# Get user and p/w for authentication
print "User name: "
usr = gets.strip
# Use highline for pw
hiLine = HighLine.new()
pw = (hiLine.ask("Password: ") { |question| question.echo = "*"})
# Feedback
puts "Clearing cache for user db #{db.inspect} in group #{group.inspect} on Genboree host #{host.inspect}"
# ApiCaller
apiCaller = ApiCaller.new(host, cacheUrlBase, usr, pw)
httpResp = apiCaller.delete( { :grp => group, :db => db } )
if(apiCaller.succeeded?)
  puts "    DONE!"
else
  puts "    FAILED! :(\n    Error response\n\n"
  apiCaller.parseRespBody()
  puts "    - Status Code:    #{apiCaller.apiStatusObj['statusCode']}"
  puts "    - Status Message: #{apiCaller.apiStatusObj['msg']}"
end
puts ""

exit(0)
