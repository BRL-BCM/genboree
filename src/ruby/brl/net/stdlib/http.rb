#!/usr/bin/env ruby
require 'net/http'

# DO NOT USE YET, NOT FULLY TESTED

module Net
  # Override the default implementation of send_request_with_body_stream()
  # so it makes use of a configurable read buffer to when writing to
  # the socket.
  class HTTPGenericRequest
    BODY_STREAM_READ_SIZE = 16 * 1024
    attr_accessor :bodyStreamReadSize

    def initialize(m, reqbody, resbody, path, initheader = nil)
      @method = m
      @request_has_body = reqbody
      @response_has_body = resbody
      raise ArgumentError, "HTTP request path is empty" if path.empty?
      @path = path
      initialize_http_header initheader
      self['Accept'] ||= '*/*'
      @body = nil
      @body_stream = nil
      @bodyStreamReadSize = BODY_STREAM_READ_SIZE
    end

    def send_request_with_body_stream(sock, ver, path, f)
      unless content_length() or chunked?
        raise ArgumentError,
            "Content-Length not given and Transfer-Encoding is not `chunked'"
      end
      supply_default_content_type
      write_header sock, ver, path
      if chunked?
        while s = f.read(@bodyStreamReadSize)
          sock.write(sprintf("%x\r\n", s.length) << s << "\r\n")
        end
        sock.write "0\r\n\r\n"
      else
        while s = f.read(@bodyStreamReadSize)
          sock.write s
          $stderr.print "."
        end
      end
    end
  end
end
