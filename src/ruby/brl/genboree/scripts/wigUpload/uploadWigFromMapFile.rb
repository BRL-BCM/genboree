#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'brl/util/util'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST

# ##############################################################################
# CONSTANTS
# ##############################################################################
URI_PATT = "/REST/v1/grp/{grp}/db/{db}/annos?format=wig&trackName={trk}"
GB_HOST = "valine.brl.bcmd.bcm.edu"
GB_GRP = "paithank_group"
GB_DB = "Freeze 1 - Full Repo"

@mapFileName = ARGV[0].strip
@user = ARGV[1].strip
puts "Password: "
@pass = $stdin.gets()
@pass.strip!

unless(@mapFileName.empty?)
  if(File.exist?(@mapFileName))
    @mapFile = File.open(@mapFileName)
    apiCaller = ApiCaller.new(GB_HOST, URI_PATT, @user, @pass)
    @mapFile.each_line { |line|
      next if(line !~ /\S/ or line =~ /^\s*#/)
      wigFileName, desc, trkName = line.split(/\t/)
      trkName.strip!
      $stderr.puts "STATUS: About to upload wig file for track #{trkName.inspect}."
      wigFileName.strip!
      #wigFileName.sub!(/\.bw$/, ".gz")
      findOut = `find . -type f -name "#{wigFileName}"`
      if($?.success? and findOut and findOut =~ /\S/)
        findOut.strip!
        $stderr.puts "    STATUS: Found wig file here: #{findOut.inspect}"
        wigFile = File.open(findOut)
        $stderr.puts "    STATUS: About to transfer for upload"
        t1 = Time.now
        hr = apiCaller.put( {:grp => GB_GRP, :db => GB_DB, :trk => trkName}, wigFile )
        if(apiCaller.succeeded?)
          apiCaller.parseRespBody
          $stderr.puts "    STATUS: File transferred. Response status: #{apiCaller.apiStatusObj['statusCode'].inspect}"
        else # error
          $stderr.puts "    ERROR: File upload failed. response:\n#{apiCaller.respBody}"
        end
        $stderr.puts "    STATUS: Transfer time taken: #{Time.now - t1} sec for file size #{File.size(findOut)}"
        wigFile.close unless(wigFile.closed?)
      else # wig file not found
        $stderr.puts "ERROR: file #{wigFileName.inspect} not found under current directory!"
      end
      $stderr.puts '-' * 50
    }
  end
  @mapFile.close
end
