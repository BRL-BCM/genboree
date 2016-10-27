require 'rubygems'
require 'builder'
require 'webrick'
require 'md5'
include WEBrick
include WEBrick::HTTPServlet

class TestServlet < AbstractServlet 
  def initialize(server, mountArg)
    super(server)
    @mountArg = mountArg
  end
  
  def do_GET(req, res)
    return handleGetPost(req, res)
  end
  
  def do_POST(req, res)
    return handleGetPost(req, res)
  end
  
  def handleGetPost(req, res)
    arg1 = req.query['arg1'] or "not found"
    
    res['content-type'] = 'text/xml'
    res.body = makeXML()
    res.status = 200
  end 
  
  def makeXML()
    xml = ''
    doc = Builder::XmlMarkup.new(
            :target => xml,
            :indent => 2
          )
    doc.instruct!(:xml, :version => '1.0', :encoding => 'UTF-8')
    doc.job( :key => MD5::hexdigest(ENV.values.join("\n")) ) {
      doc.fasta( 'content-type' => 'text/fasta' )
      doc.primers {
        doc.lff('content-type' => 'text/lff') { doc.text!( "LFF STUFF\nLFF STUFF\n" ) }
      }
      doc.primer3output { "p3\noutput\nhere\n=\nanother\np3\nrecord\n=" }
    }
    return xml
  end
 
end
