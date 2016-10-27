## #!/usr/local/brl/local/bin/ruby
require 'cgi'

module BRL ; module Net

## Basic template class to subclass and override its methods
## when implementing your own handlers.
class FastCGIHandler

  # REQUIRED: new() will be called with 2 params, 'cgi' and 'env'.
  # Use them for any generic info you need to setup.
  # BUT handleRequest() and clear() will be given request-specific 'cgi' and 'env'
  # Set up GLOBAL stuff here, used for all requests
  def initialize(cgi, env)
  end
  
  # REQUIRED: implement a handleRequest() method. No args.
  # Set up REQUEST-SPECIFIC stuff here, and process the request
  def handleRequest(cgi, env)
    # REQUIRED: set appropriate HTTP headers (including content-type)
    headersStr = cgi.header( { 'type' => 'text/plain' } )
    cgi.print(headersStr)
    cgi.print("#{Time.now} Template service handled request\n\n")
    
    raise(NotImplementedError, "ERROR: you didn't override template's handleRequest()")
  end
  
  # REQUIRED: implement a clear() method to clean up cached stuff, etc
  # TESTING: don't implement clear()
  def clear(cgi=nil, env=nil)
    raise(NotImplementedError, "ERROR: you didn't override template's handleRequest()")
  end
    
end

class NotImplementedError < ScriptError ; end

end ; end

# REQUIRED: Return object instance to FCGI eval, so obj.handleRequest() can be called.
# NOTE: We should have 'cgi' and 'env' from the ruby-cgi.frb dispatch binding.
#  - cgi is a CGI instance and has things like cgi.out, cgi.err, cgi.in, cgi.print
#  - env is a hash of various cgi name-value variables
obj = begin
        # REQUIRED: Instantiate the object
        obj = FastCGIHandler.new(cgi, env)
      rescue Exception => err
        obj = err
      end
