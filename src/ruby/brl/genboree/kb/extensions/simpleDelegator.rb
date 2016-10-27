#!/bin/env ruby

require 'delegate'
require 'brl/util/util'
require 'brl/genboree/kb/extensions/object'

class SimpleDelegator

  # Address the fact that {#is_a?} on delegators will test false even when
  #   the delegate object is exactly the correct type of class. This is because
  #   {#is_a?} tests against this class--which is SimpleDelegator--when probably you
  #   wanted to check against the delegate (i.e. {#__getobj__}).
  # Rather than break {#is_a?} with unexpected functionality by overriding its
  #   behavior, we implement {#acts_as?} here which overrides our implementation
  #   in {Object#acts_as?}
  # @param [Class] aClass The class to test against. Does this instance behave as if it
  #   is an instance of @aClass@?
  # @return [Boolean] if this object will behave exactly as an instance of @aClass@
  def acts_as?(aClass)
    retVal = self.__getobj__.is_a?(aClass)
    unless(retVal) # It's not that class literally, but may be something that itself is delegating to such a class...follow the chain...
      retVal = self.__getobj__.acts_as?(aClass)
    end
    return retVal
  end
end
