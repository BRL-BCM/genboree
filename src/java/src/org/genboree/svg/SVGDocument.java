package org.genboree.svg;

import java.util.Vector;
import java.util.Hashtable;
import java.util.Enumeration;
import java.io.IOException;
import java.io.File;
import java.io.OutputStream;

import java.awt.Dimension;
import java.awt.Rectangle;
import java.awt.Color;
import java.awt.geom.Rectangle2D;

import org.apache.batik.util.XMLResourceDescriptor;
import org.apache.batik.dom.svg.SAXSVGDocumentFactory;
import org.apache.batik.transcoder.TranscoderException;
import org.apache.batik.transcoder.Transcoder;
import org.apache.batik.transcoder.TranscodingHints;
import org.apache.batik.transcoder.TranscoderInput;
import org.apache.batik.transcoder.TranscoderOutput;
import org.apache.batik.transcoder.image.ImageTranscoder;
import org.apache.batik.transcoder.image.PNGTranscoder;
import org.apache.batik.transcoder.image.TIFFTranscoder;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.w3c.dom.Node;

import org.genboree.util.Util;

public class SVGDocument
{
    static
    {
        System.setProperty( "java.awt.headless", "true" );
    }

    protected Document doc = null;
    public Document getDocument() { return doc; }
    public void setDocument( Document doc ) { this.doc = doc; }

    public SVGDocument() {}

    public void loadDocument( String uri )
        throws IOException
    {
	    String parser = XMLResourceDescriptor.getXMLParserClassName();
        SAXSVGDocumentFactory f = new SAXSVGDocumentFactory(parser);
        doc = f.createDocument(uri);
    }

    public void loadDocument( File f )
        throws IOException
    {
        loadDocument( f.toURL().toString() );
    }

    public SVGDocument( File f )
        throws IOException
    {
        loadDocument( f );
    }

    public Element getRoot()
    {
        return doc.getDocumentElement();
    }

    public Dimension getSize()
    {
        Element root = getRoot();
        int w = Util.parseInt( root.getAttributeNS(null, "width"), -1 );
        int h = Util.parseInt( root.getAttributeNS(null, "height"), -1 );
        return new Dimension( w, h );
    }

    // Map Element, representing a single entry in the image map
    public static class MapElement
    {
        public String href;
        public String onclick;
        public Rectangle rect;
    }

    protected static Rectangle2D.Double getElementRect( Element elem )
    {
		double x = (double) Util.parseInt( elem.getAttributeNS(null,"x"), 0 );
		double y = (double) Util.parseInt( elem.getAttributeNS(null,"y"), 0 );
		double w = (double) Util.parseInt( elem.getAttributeNS(null,"width"), 0 );
		double h = (double) Util.parseInt( elem.getAttributeNS(null,"height"), 0 );
		return new Rectangle2D.Double( x, y, w, h );
    }

	protected void processA( Element a, Vector vec )
	{
        Element root = getRoot();

		MapElement mel = new MapElement();
		mel.onclick = a.getAttributeNS( null, "onclick" );
		mel.href = a.getAttribute( "href" );

        org.w3c.dom.NamedNodeMap nnm = a.getAttributes();
        for( int j=0; j<nnm.getLength(); j++ )
        {
            Node nod = nnm.item(j);
            String ln = nod.getLocalName();
            if( ln == null ) continue;
            if( ln.equals("href") ) mel.href = nod.getNodeValue();
        }

		Rectangle2D.Double cRect = null;
		Node pn;
		Element elem;

		NodeList nl = a.getChildNodes();
		for( int i=0; i<nl.getLength(); i++ )
		{
			Node n = nl.item(i);
			if( !(n instanceof Element) ) continue;
			elem = (Element) n;
			if( !elem.getTagName().equals("rect") ) continue;
			cRect = getElementRect( elem );
		}


		for( pn=a.getParentNode(); pn != null; pn = pn.getParentNode() )
		{
			if( !(pn instanceof Element) ) return;
			elem = (Element) pn;
			Rectangle2D.Double r = getElementRect( elem );
			if( cRect == null ) cRect = r;
			else
			{
				int[] coords = new int[4];
				int n = 0;
				String[] scoords = Util.parseString( elem.getAttributeNS(null,"viewBox"), ' ' );
				for( int i=0; i<scoords.length; i++ )
				{
					int ival = Util.parseInt(scoords[i], -1);
					if( ival >= 0 ) coords[n++] = ival;
					if( n >= 4 ) break;
				}
				double x = (double) coords[0];
				double y = (double) coords[1];
				double w = (double) coords[2];
				double h = (double) coords[3];
				double rx = r.width / w;
				double ry = r.height / h;
				if( ry < rx ) rx = ry;
				double dy = (r.height - h*rx)/2;
				double dx = (r.width - w*rx)/2;

				cRect.x = (cRect.x + x) * rx + r.x + dx;
				cRect.y = (cRect.y + y) * rx + r.y + dy;
				cRect.width *= rx;
				cRect.height *= rx;
			}
			if( pn == root ) break;
		}
		if( pn == null || cRect==null ) return;

		mel.rect = new Rectangle( (int)(cRect.x + 0.5), (int)(cRect.y + 0.5),
		    (int)(cRect.width + 0.5), (int)(cRect.height + 0.5) );
		vec.addElement( mel );
	}

	protected void findElementsA( Element elem, Vector vec )
	{
		String tagName = elem.getTagName();
		boolean is_svg = tagName.equals("svg");
		boolean is_a = tagName.equals("a");
		if( is_a )
		{
			try
			{
				processA( elem, vec );
			} catch( Exception ex ) {}
		}
		else if( is_svg )
		{
			NodeList nl = elem.getChildNodes();
			for( int i=0; i<nl.getLength(); i++ )
			{
				Node n = nl.item(i);
				if( n instanceof Element ) findElementsA( (Element)n, vec );
			}
		}
	}

    public MapElement[] getImageMap()
    {
        Vector v = new Vector();

        findElementsA( getRoot(), v );

        MapElement[] rc = new MapElement[ v.size() ];
        v.copyInto( rc );
        return rc;
    }

    public void export( OutputStream out, String format, double scale, Hashtable hints )
        throws IOException, TranscoderException
    {
        Transcoder tr = null;
        String _format = format.toLowerCase();
        if( _format.equals("gif") )
        {
            tr = new GIFTranscoder();
        }
        else if( _format.equals("png") )
        {
            tr = new PNGTranscoder();
        }
        else if( _format.equals("tiff") || _format.equals("tif") )
        {
            tr = new TIFFTranscoder();
        }
        else throw new RuntimeException( "Unsupported format: "+format );

        if( hints != null )
        {
            for( Enumeration en = hints.keys(); en.hasMoreElements(); )
            {
                Object _key = en.nextElement();
                if( _key instanceof TranscodingHints.Key )
                    tr.addTranscodingHint( (TranscodingHints.Key)_key, hints.get(_key) );
            }
        }
        else
        {
            tr.addTranscodingHint( ImageTranscoder.KEY_BACKGROUND_COLOR, Color.white );
            tr.addTranscodingHint( ImageTranscoder.KEY_PIXEL_UNIT_TO_MILLIMETER, new Float((2.54f / 360) * 10) );
        }

        if( scale > 0. )
        {
            Dimension d = getSize();
            tr.addTranscodingHint( ImageTranscoder.KEY_WIDTH, new Float(d.width*scale) );
            tr.addTranscodingHint( ImageTranscoder.KEY_HEIGHT, new Float(d.height*scale) );
        }

        TranscoderInput input = new TranscoderInput( getDocument() );
        TranscoderOutput output = new TranscoderOutput( out );
        tr.transcode( input, output );
        out.flush();
    }
}