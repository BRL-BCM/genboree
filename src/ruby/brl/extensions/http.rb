#!/bin/env ruby
require 'net/http'
require 'brl/util/util'

# Adds a ::Net::HTTP::Purge class that can be used in the long-hand way to
#   send HTTP requests with the "PURGE" method (say to Varnish or our nginx caching proxy)
# @example Just make a request the non-shortcut way:
#   http = ::Net::HTTP::new(host) # or ::Net::HTTP::new(host, port)
#   req = ::Net::HTTP::Purge.new( "#{rsrcPath}?#{queryString}" )
#   resp = http.request(req)
class ::Net::HTTP::Purge < Net::HTTPRequest
  METHOD = 'PURGE'
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = true
end
