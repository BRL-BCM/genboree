# A rackup Rack file. For use with thin or other rackup-enabled web server

# ##############################################################################
# REQUIRED LIBRARIES
# ##############################################################################
require 'rack/showexceptions'
require 'rack/utils'
require 'brl/util/util'
require 'brl/rest/resource'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/data/entity'
require 'brl/rackups/thin/genboreeRESTRackup'

# ##############################################################################
# MAIN: called by Rackup handler to initialize service:
use Rack::ShowExceptions # turns on fancy html exceptions in browser... TODO: remove this once working
genbRackup = GenboreeRESTRackup.new( ["brl/rest/resources", "brl/genboree/rest/resources", "brl/genboree/rest/extensions/*/resources", "brl/genboree/tools/*"] )
# Now that we have a GenboreeRESTRackup instance, make sure to switch
# ApiCaller.usageContext to :serverEmbedded rather than default of :standalone
# - This only happens HERE, in .ru, and thus is only for servers.
# - Outside of a server, the aggressive timeouts & reattempt settigns are used by ApiCaller
BRL::Genboree::REST::ApiCaller.usageContext = :serverEmbedded
# ------- this is workaround allowing for larger POST requests
if Rack::Utils.respond_to?("key_space_limit=")
  Rack::Utils.key_space_limit = 64*1024*1024 # 1024 times the default size
end
# -------
run genbRackup
