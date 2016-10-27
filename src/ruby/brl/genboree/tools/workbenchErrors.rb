
module BRL ; module Genboree ; module Tools

class WorkbenchUIError < StandardError
  attr_accessor :statusName, :statusMsg

  def initialize(statusName, statusMsg, *args)
    super(*args)
    @statusName = statusName
    @statusMsg = statusMsg
  end
end

end ; end ; end
