#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################


module BRL ;  module Util

class TimingUtil
  # ############################################################################
	# CONSTANTS
	# ############################################################################
	
	# ############################################################################
	# ATTRIBUTES
	# ############################################################################
  attr_accessor :vTimes, :vMsgs
  
  def initialize()
    @vTimes = []
    @vMsgs = []
    self.addMsg("TIMING STARTED AT: " + Time.now().to_s)
  end
  
  def addMsg(msg)
    @vTimes << Time.now()
    @vMsgs << msg 
    return
  end
    
  def writeTimingReport(writer)
    currDate = @vTimes[0]
    currMsg = @vMsgs[0]
    writer.puts currMsg 
    writer.puts '' 

    nextDate = nil
    (1...@vTimes.size()).each { |ii|
      nextDate = @vTimes[ii]
      currMsg = @vMsgs[ii]
      elapsedTime = (nextDate - currDate)
      writer.puts "    #{currMsg}: #{elapsedTime.to_i / 60} min #{elapsedTime.to_i % 60} sec"
      currDate = nextDate
    }
    writer.puts ''
    writer.puts "TIMING REPORTED AT: " + nextDate.to_s
    writer.flush() if(writer.respond_to?(:flush))
    return
  end
  
  alias :<< :addMsg
end

end ; end

# ############################################################################
# MAIN (quick unit test)
# ############################################################################
if(__FILE__ == $0)
  @timer = BRL::Util::TimingUtil.new()
  puts "\n\nStart unit test; 20 sec sleep with addMsg() test..."
  sleep(20)
  @timer.addMsg("- Done sleeping for 20 sec")
  puts "...done 20 sec sleep. Now do 65 sec sleep with << test..."
  sleep(65)
  @timer << "- Done sleeping for 65 more sec"
  puts "...done 65 sec sleep. Now write timing report to $stdout and $stderr."
  @timer.writeTimingReport($stdout)
  @timer.writeTimingReport($stderr)
end
