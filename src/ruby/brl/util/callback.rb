require 'brl/util/util'

# --------------------------------------------------------------------
# CRIBBED EXACTLY FROM Eventmachine::Callback
# * There is no EM-stuff here actually. Just very useful Callback-object
#   creation that can be used in a number of places.
# * Extracted from EM so don't have dependency if want to use it for other things.
# * And so they don't improve-it-away
# --------------------------------------------------------------------

module BRL
  # Utility method for coercing arguments to an object that responds to :call.
  # Accepts an object and a method name to send to, or a block, or an object
  # that responds to :call.
  #
  # @example BRL.Callback used with a block. Returns that block.
  #
  #  cb = BRL.Callback do |msg|
  #    puts(msg)
  #  end
  #  # returned object is a callable
  #  cb.call('hello world')
  #
  #
  # @example BRL.Callback used with an object (to be more specific, class object) and a method name, returns an object that responds to #call
  #
  #  cb = BRL.Callback(Object, :puts)
  #  # returned object is a callable that delegates to Kernel#puts (in this case Object.puts)
  #  cb.call('hello world')
  #
  #
  # @example BRL.Callback used with an object that responds to #call. Returns the argument.
  #
  #  cb = BRL.Callback(proc{ |msg| puts(msg) })
  #  # returned object is a callable
  #  cb.call('hello world')
  #
  #
  # @overload Callback(object, method)
  #   Wraps `method` invocation on `object` into an object that responds to #call that proxies all the arguments to that method
  #   @param [Object] Object to invoke method on
  #   @param [Symbol] Method name
  #   @return [<#call>] An object that responds to #call that takes any number of arguments and invokes method on object with those arguments
  #
  # @overload Callback(object)
  #   Returns callable object as is, without any coercion
  #   @param [<#call>] An object that responds to #call
  #   @return [<#call>] Its argument
  #
  # @overload Callback(&block)
  #   Returns block passed to it without any coercion
  #   @return [<#call>] Block passed to this method
  #
  # @raise [ArgumentError] When argument doesn't respond to #call, method name is missing or when invoked without arguments and block isn't given
  #
  # @return [<#call>]
  def self.Callback(object = nil, method = nil, &blk)
    if(object and method)
      lambda { |*args| object.__send__ method, *args }
    else
      if(object.respond_to?(:call))
        object
      else
        blk || raise(ArgumentError)
      end
    end
  end # self.Callback
end # BRL
