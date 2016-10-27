package org.genboree.gdasaccess;

import java.io.*;
import java.util.*;
import java.net.URL;
import javax.xml.parsers.*;
import org.xml.sax.helpers.*;
import org.xml.sax.*;

public class RefseqEntryPoint
{
    protected String id;
    public String getId() { return id; }
    public void setId( String id ) { this.id = id; }
    protected String segmentName;
    public String getSegmentName() { return segmentName; }
    public void setSegmentName( String segmentName ) { this.segmentName = segmentName; }
    protected String size;
    public String getSize() { return size; }
    public void setSize( String size ) { this.size = size; }
    protected String start;
    public String getStart() { return start; }
    public void setStart( String start ) { this.start = start; }
    protected String stop;
    public String getStop() { return stop; }
    public void setStop( String stop ) { this.stop = stop; }
    protected String entryPointClass;
    public String getEntryPointClass() { return entryPointClass; }
    public void setEntryPointClass( String entryPointClass ) { this.entryPointClass = entryPointClass; }
    protected String orientation;
    public String getOrientation() { return orientation; }
    public void setOrientation( String orientation ) { this.orientation = orientation; }
    protected String subparts;
    public String getSubparts() { return subparts; }
    public void setSubparts( String subparts ) { this.subparts = subparts; }
    protected String referencePointSection;
    public String getReferencePointSection() { return referencePointSection; }
    public void setReferencePointSection( String refPSection ) { referencePointSection = refPSection; }


    public void clear()
    {
        id = size = start = stop = entryPointClass = orientation = subparts = "";
    }

    public RefseqEntryPoint()
    {
        clear();
    }

    public static class EntryPointParser extends DefaultHandler
    {
        protected Vector v = new Vector();
        protected RefseqEntryPoint curr = null;

        public void characters( char[] ch, int start, int len )
            throws SAXException
        {
            if( curr != null ) curr.setSegmentName(
                (new String(ch, start, len)).trim() );
        }

        public void startElement( String uri, String localName, String qName,
            Attributes attr )
            throws SAXException
        {
            if( qName.compareToIgnoreCase("SEGMENT") == 0 )
            {
                curr = new RefseqEntryPoint();
                curr.setId( attr.getValue("id") );
                curr.setSize( attr.getValue("size") );
                curr.setStart( attr.getValue("start") );
                curr.setStop( attr.getValue("stop") );
                curr.setEntryPointClass( attr.getValue("class") );
                curr.setOrientation( attr.getValue("orientation") );
                curr.setSubparts( attr.getValue("subparts") );
            }
        }

        public void endElement( String uri, String localName, String qName )
            throws SAXException
        {
            if( qName.compareToIgnoreCase("SEGMENT")==0 && curr!=null )
            {
                v.addElement( curr );
                curr = null;
            }
        }

        public RefseqEntryPoint[] getEntryPoints()
        {
            RefseqEntryPoint[] rc = new RefseqEntryPoint[ v.size() ];
            v.copyInto( rc );
            return rc;
        }
    }

    public static RefseqEntryPoint[] fetchEntryPoints( String gdasUrl )
    {
        try
        {
            URL url = new URL( gdasUrl );
            InputStream in = url.openStream();
            SAXParser sp = SAXParserFactory.newInstance().newSAXParser();
            EntryPointParser epp = new EntryPointParser();
            sp.parse( in, epp );
            in.close();
            return epp.getEntryPoints();
        } catch( Exception ex ) {
		System.err.println("gdasUrl = " + gdasUrl);
		ex.printStackTrace(System.err);

	}
        return null;
    }

    public void generateEntryPointSection( String url)
    {
         int i = 0;
         RefseqEntryPoint[] rseps = RefseqEntryPoint.fetchEntryPoints(url + "/entry_points");
        String refPSection  = new String();

         refPSection.concat("[reference_points]\n");
         refPSection.concat("#id   class   length\n");
          for(i = 0; i < rseps.length; i++)
          {
              refPSection.concat(rseps[i].getId() + "    ");
              refPSection.concat("Chromosome  ");
              refPSection.concat(rseps[i].getSize() + "\n");
          }
         referencePointSection  = refPSection;
     }


    public static void main(String args[])
    {
         int i = 0;
         RefseqEntryPoint[] rseps = RefseqEntryPoint.fetchEntryPoints("http://localhost/java-bin/das/genboree_5mmm2kend8daf46fa5abcd1819cffech/entry_points");
         System.out.println("[reference_points]");
         System.out.println("#id   class   length");
          for(i = 0; i < rseps.length; i++)
          {
              System.out.print(rseps[i].getId() + "    ");
              System.out.print("Chromosome  ");
              System.out.print(rseps[i].getSize() + "\n");
          }
     }
}

