#!/usr/bin/env ruby

# A script to copy over files using the API (copied files to the Workbench files area)
require 'uri'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/wrapperApiCaller'
include BRL::Genboree::REST

if(ARGV.size == 0)
  $stderr.puts("Usage: fileApiTransfer.rb userId somefile.txt escapedFileUri")
end
userId = ARGV[0]
fileName = ARGV[1]
url = CGI.unescape(ARGV[2])
urlObj = URI.parse(url)
apiCaller = WrapperApiCaller.new(urlObj.host, urlObj.path, userId)
apiCaller.put({}, File.open(fileName))
if(!apiCaller.succeeded?)
  $stderr.puts("Failed to copy file: #{fileName.inspect}\nAPI Response: #{apiCaller.respBody}")
  exit(21)
else
  $stderr.puts("File transferred successfully.")
  exit(0)
end
