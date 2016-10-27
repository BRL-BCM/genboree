
require 'brl/util/util'

module BRL ; module Net

class FCGIErubyUtil	
	def self.prepForHtml(cgi, env, outHdrs)	# Tell we're going to make some html
		outHdrs['type'] = 'text/html'
	end

	def self.isFCGI?(cgi, env, outHdrs)
		return ( (!cgi.nil? and env.key?('FCGI_ROLE')) ? true : false )
  end
end

end ; end
