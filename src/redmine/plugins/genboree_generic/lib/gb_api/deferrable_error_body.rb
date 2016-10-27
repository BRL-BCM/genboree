
module GbApi
  # For streaming an error message back. Very simple.
  class DeferrableErrorBody

    def initialize(errorMsg)
      $stderr.debugPuts(__FILE__, __method__, '>>>>>> DEBUG', "NASTY ERROR! (#{errorMsg.inspect}")
      @errorMsg = errorMsg
    end

    def each()
      yield @error
    end
  end
end