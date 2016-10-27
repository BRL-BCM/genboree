require 'cgi'
require 'brl/util/util'
require 'erubis'

module BRL ; module Net

class ErubisContext < Hash
  attr_accessor :cgi, :env, :outHdrs, :didHdrs, :didResult

  def initialize(cgi, env, outHdrs={}, didHdrs=false, didResult=false)
    @cgi, @env, @outHdrs, @didHdrs, @didResult = cgi, env, outHdrs, didHdrs, didResult
    super()
  end

  def isFCGI?()
    return ( (!@cgi.nil? and @env.key?('FCGI_ROLE')) ? true : false )
  end

  def includeFile(relFilePath, interpret=true)
    retVal = nil
    fullFilePath = @env['DOCUMENT_ROOT'] + relFilePath
    if(interpret)
      erubyObj = Erubis::Eruby.load_file(fullFilePath)
      context = self # make 'context' variable available, since binding() sets the scope to eval erubyObj in?? Maybe....
      retVal = erubyObj.result(binding())
    else
      File.open(fullFilePath) { |file|
        retVal = file.read()
      }
    end
    return retVal
  end

  def printHdrs()
    unless(@didHdrs)
      headerStr = @cgi.header( @outHdrs )
      @cgi.print(headerStr)
      @didHdrs = true
    end
    return
  end

  def prepForHtml(flush=false)
    @outHdrs['type'] = 'text/html'
    @outHdrs['status'] = '200 OK'
    self.printHdrs() if(flush)
    return
  end

  def prepForText(flush=false) # Tell apache we're going to send some text
    @outHdrs['type'] = 'text/plain'
    @outHdrs['status'] = '200 OK'
    self.printHdrs() if(flush)
    return
  end

  def prepForContentType(typeStr, flush=false)
    @outHdrs['type'] = typeStr
    @outHdrs['status'] = '200 OK'
    self.printHdrs() if(flush)
    return
  end

  def prepRelocate(url)	# Tell apache we want to redirect to a different url
		@outHdrs['type'] = 'text/html'
		@outHdrs['status'] = '302 Found'
		@outHdrs['Location'] = url
		self.printHdrs()
		@didHdrs = true
		@didResult = true
		return
  end

  def getServerName(stripPort=true)
    httpHost = @env['HTTP_HOST']
    httpHost.gsub!(/:\d+$/, '') if(stripPort) # shouldn't be necessary
    return httpHost
  end
end

end ; end
