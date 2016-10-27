#!/usr/bin/env ruby
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/pipeline/ftp/pollers/poller'
require 'brl/genboree/pipeline/ftp/helpers/lftp'

module BRL ; module Genboree ; module Pipeline ; module FTP ; module Pollers

class FtpPoller < BRL::Genboree::Pipeline::FTP::Pollers::Poller
  VERSION = "1.0"
  COMMAND_LINE_ARGS = {
    "--confFile" => [:REQUIRED_ARGUMENT, "-c", "location of poller configuration file"]
  }
  DESC_AND_EXAMPLES = {
    :description => "Polls FTP locations for newly deposited files to be processed",
    :authors     => [ "Aaron Baker (ab4@bcm.edu)", "Andrew R Jackson (andrewj@bcm.edu)" ],
    :examples    => [
      "#{File.basename(__FILE__)} --confFile=ftpPoller.conf",
      "#{File.basename(__FILE__)} --help"
    ]
  }

  def makeHelper(host=nil, user=nil)
    return BRL::Genboree::Pipeline::FTP::Helpers::Lftp.new(host, user)
  end
end
end; end; end; end; end

if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__))
  BRL::Script::main(BRL::Genboree::Pipeline::FTP::Pollers::FtpPoller)
end
