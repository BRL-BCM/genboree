require 'brl/util/util'

module BRL; module Genboree; module Abstract; module Resources
  class AbstractStreamer

    #############
    # INTERFACE #
    #############
    # Inclusion of the lines 
    #   super()
    #   unless(self.class.method_defined?(:child_each))
    #     alias :child_each :each
    #     alias :each :parent_each
    #   end
    # in the child initalize() that is defining each() will add this decorator
    # @todo there may be a better hook for this like self.inherited or self.method_added
    #   (but neither of those two seem to suffice)
    # @note this class MUST NOT define child_each with the above unless clause (which is necessary
    #   to prevent infinite recursive alias)

    attr_accessor :totalYield
    attr_accessor :callback

    def initialize
      @totalYield = 0
      @callback = Proc.new { |xx| xx } # default callback is to simply return 
    end

    # Provide decorator around each() to count the byte size of yielded chunks
    def parent_each
      retVal = child_each { |xx|
        @totalYield += xx.to_s.size
        yield xx
      }
      @callback.call(@totalYield)
      return retVal
    end  
  end

  # Alternative to AbstractStreamer, possibly simpler and less intrusive
  class StreamerDelegator
    attr_accessor :totalYield
    attr_accessor :callback
    attr_accessor :delegate

    def initialize(delegate)
      @totalYield = 0
      @callback = Proc.new { |xx| xx }
      @delegate = delegate
    end

    def each
      retVal = nil
      if(self.delegate.respond_to?(:each))
        retVal = self.delegate.each { |xx|
          @totalYield += xx.to_s.size
          yield xx
        }
        @callback.call(@totalYield)
      end
      return retVal
    end
  end
end; end; end; end
