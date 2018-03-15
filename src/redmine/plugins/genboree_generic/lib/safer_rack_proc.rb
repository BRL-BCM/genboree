# Callback-based code relies on dev callbacks to be safe and not raise
#   un-rescued exceptions that can kill the process. Where you have full
#   control of the process flow (Genboree API), your infrastructure can
#   make callbacks safe with little work. But where you have only partial
#   controll of the process flow (Rails), if you're employing callbacks for
#   deferred requests and aiding non-blocking request handling, you should
#   employ this class to try to intercept poorly handled dev callbacks in
#   order to protect rails/rack from getting killed by nasty exceptions in
#   dev callbacks.
# @note To use this class, you must ~cast incoming Proc args or code-blocks to SaferProc via
#   SaferRackProc.new( rackCallback, &Proc.new) if(block_given?) or
#   if a Proc arg was given instead then SaferRackProc.new( rackCallback, &callback ) or all in one:
#   cb = ( block_given? SaferProc.new( rackCallback, &Proc.new ) : SaferPoc.new( rackCallback, &callback ).
#   Even if devs handed you an actual SaferProc they themselves created, it is
#   converted to Proc by the "&" operator they used when making the call.
# @note Due to need for the appropriate Rack callback, which expects the response triple and which will
#   be used to respond directly to the client when dev code fails and is caught by this fallback class,
#   it's best to use this in classes (e.g. Controllers, lib classes) which mixin GbMixin::AsyncRenderHelper and
#   employ GbMixin::AsyncRenderHelper#initRackEnv sensibly in order to extract the Rack callback (i.e. from
#   'async.callback' key in Rack env). Not required, but you had better supply a rackCallback Proc yourself then.
class SaferRackProc < Proc

  # No calling new(). Use a factory method to get instance.
  private_class_method :new

  attr_accessor :rackCallback

  # CONSTRUCTOR. Get a new SaferRackProc by supplying the Rack callback which will be used
  #   to respond to the client directly in case of callback code exceptions and the actual callback
  #   code as is normal for Proc.new.
  # @param [Proc] rackCallback The rack callback used to send a response to the client. Typically found
  #   at 'async.callback' key in the Rack env. It takes a single argument: the Array with 3 elements (code,
  #   headers, payload).
  # @param [Proc] callback Optional, but if missing there must be a code block provided. This is the code block
  #   for this Proc subclass. Will be called via call().
  # @return [SaferRackProc, nil] Either instance of this class or nil if there is no non-nil callback arg and
  #   no callback (i.e. dev error)
  def self.withRackCallback( rackCallback, &callback )
    if( block_given? )
      cb = Proc.new
    elsif( callback.is_a?(Proc) )
      cb = callback
    else # no code block and callback is nil (or non-Proc at least)
      cb = nil
    end
    return ( cb.is_a?(Proc) ? new( rackCallback, &cb ) : nil )
  end

  # Override Proc#call in order to surround it with aggressive begin-rescue.
  def call( *args )
    begin
      super( *args )
    rescue Exception => err
      begin
        $stderr.debugPuts(__FILE__, __method__, 'FATAL DEV BUG', "Dev's callback raised an Exception that they didn't rescue and properly handle. This could have killed this Ruby process in some flows-of-control. Protected by SaferRackroc. Exception from dev's code:\n    Error class: #{err.class rescue '<< N/A?? >>'}\n    Error message: #{err.message rescue '<< N/A? >>'}\n    Error trace:\n\n#{err.backtrace.join("\n") rescue '<< N/A? >>'}\n\n") rescue nil
        msg = "{ \"msg\" : \"BUG CAUGHT. Unsafe code failed to detect or handle an error condition. The request may not have been successful or only partially successful. Details have been logged; contact administrators for assistance resolving this error and any corruption that resulted.\" }"
        rackCallbackArg = [ 500, { 'Content-Type' => 'application/json', 'Content-Length' => msg.length.to_s }, msg ]
        $stderr.debugPuts(__FILE__, __method__, 'FATAL DEV BUG', "(Follow-Up) Attempting to call rackCallback Proc with this argument:\n\n#{rackCallbackArg.inspect}\n\n")
        rackCallback.call( rackCallbackArg )
      rescue Exception => eerr # wow can't even do basic logging
        $stderr.puts "***MAJOR BUG*** - RACK ERROR: Could not log error in #{__FILE__}:#{__method__} and/or could not respond to client about error via RACK CALLBACK. ***MAJOR BUG***\n    Error class: #{eerr.class rescue '<< N/A?? >>'}\n    Error message: #{eerr.message rescue '<< N/A? >>'}\n    Error trace:\n\n#{eerr.backtrace.join("\n") rescue '<< N/A? >>'}\n\n"
        nil
      end
    end
  end

  # CONSTRUCTOR. Create a new SaferRackProc by supplying the Rack callback which will be used
  #   to respond to the client directly in case of callback code exceptions and the actual callback
  #   code as is normal for Proc.new.
  # @param [Proc] rackCallback The rack callback used to send a response to the client. Typically found
  #   at 'async.callback' key in the Rack env. It takes a single argument: the Array with 3 elements (code,
  #   headers, payload).
  # @param [Proc] callback Optional, but if missing there must be a code block provided. This is the code block
  #   for this Proc subclass. Will be called via call().
  def initialize( rackCallback, &callback )
    cb = (block_given? ? Proc.new : callback)
    super( &cb ) # call Proc.new like it normally expects
    self.rackCallback = rackCallback
  end

  private
end
