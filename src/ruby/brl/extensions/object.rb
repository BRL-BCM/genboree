#!/bin/env ruby
require 'brl/util/util'

class Object

  # Mainly to provide uniform interface for classes overriding this method, such
  #   as {SimpleDelegator}. If not overridden, simply returns the result of {#is_a?}
  # @param [Class] aClass The class to test against. Does this instance behave as if it
  #   is an instance of @aClass@?
  # @return [Boolean] if this object will behave exactly as an instance of @aClass@
  def acts_as?(aClass)
    return self.is_a?(aClass)
  end

  # Mainly to provide uniform interface for regular Hashes & Arrays that may have
  #   {#to_serializable} called on them in the GenboreeKB code (which is really anticipating
  #   {BRL::Genboree::KB::KbDoc} which has its specific implementation of this method.)
  # @param [Object] obj The object to serialize
  # @return [Object] Returns @self@. Uniform interface only.
  def to_serializable(obj=self)
    return self
  end
end
