#!/bin/env ruby
require 'brl/util/util'

class Object

  # Probably one of the key things to grok about Ruby: the metaclass.
  # While Foo is a class and Foo.class is of course Class, each object/instance
  #   has a SPECIFIC instance of Class that is ITS Foo class...i.e. per-object Class (!!).
  #   This is called the "metaclass" in ruby. You can add stuff to the metaclass for a specific
  #   instance without affecting the general class. Fun. And useful for several things.
  # This implementation is from Rails. Likely formalized into current versions of Ruby.
  unless( Object.new.respond_to?( :metaclass) )
    def metaclass
      class << self ; self ; end
    end
  end

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
