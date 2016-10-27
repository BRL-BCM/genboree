
require 'brl/net/servlets/testServlet'

server = HTTPServer.new(:Port => 10987)
server.mount('/', TestServlet, 'MOUNT ARG1.')

trap('INT') { server.shutdown }
trap('TERM') { server.shutdown }
server.start
