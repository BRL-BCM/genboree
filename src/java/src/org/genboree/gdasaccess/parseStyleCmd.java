package org.genboree.gdasaccess;

import java.io.*;
import java.util.*;
import java.net.URL;
import javax.xml.parsers.*;
import org.xml.sax.helpers.*;
import org.xml.sax.*;

public class parseStyleCmd
{
    protected String id;
    public String getId() { return id; }
    public void setId( String id ) { this.id = id; }
    protected String featureType;
    public String getFeatureType() { return featureType; }
    public void setFeatureType( String featureType ) { this.featureType = featureType; }
    protected String name;
    public String getName() { return name; }
    public void setName( String name ) { this.name = name; }
    protected String description;
    public String getDescription() { return description; }
    public void setDescription(String description ) { this.description = description; }
    protected String color;
    public String getColor() { return color; }
    public void setColor( String color ) { this.color = color; }

    public void clear()
    {
        id = featureType = name = description = color = "";
    }

    public parseStyleCmd()
    {
        clear();
    }

    public static class StyleCmdParser extends DefaultHandler
    {
        protected Vector v = new Vector();
        protected parseStyleCmd curr = null;

        public void characters( char[] ch, int start, int len )
            throws SAXException
        {
            return;
        }

        public void startElement( String uri, String localName, String qName,
            Attributes attr )
            throws SAXException
        {
            if( qName.compareToIgnoreCase("STYLE") == 0 )
            {
                curr = new parseStyleCmd();
                curr.setId( attr.getValue("id") );
                curr.setFeatureType( attr.getValue("featureType") );
                curr.setName( attr.getValue("name") );
                curr.setDescription( attr.getValue("description") );
                curr.setColor( attr.getValue("color") );
            }
        }

        public void endElement( String uri, String localName, String qName )
            throws SAXException
        {
            if( qName.compareToIgnoreCase("STYLE")==0 && curr!=null )
            {
                v.addElement( curr );
                curr = null;
            }
        }

        public parseStyleCmd[] getStyles()
        {
            parseStyleCmd[] rc = new parseStyleCmd[ v.size() ];
            v.copyInto( rc );
            return rc;
        }
    }

    public static parseStyleCmd[] fetchStyles( String gdasUrl )
    {
        try
        {
            URL url = new URL( gdasUrl );
            InputStream in = url.openStream();
            SAXParser sp = SAXParserFactory.newInstance().newSAXParser();
            StyleCmdParser epp = new StyleCmdParser();
            sp.parse( in, epp );
            in.close();
            return epp.getStyles();
        } catch( Exception ex ) {}
        return null;
    }


    public static void main(String args[])
    {
        int i = 0;
        parseStyleCmd[] rseps = parseStyleCmd.fetchStyles("http://localhost/java-bin/das/genboree_5mmm2kend8daf46fa5abcd1819cffech/styles?userId=7");

        for(i = 0; i < rseps.length; i++)
        {
            System.out.print(rseps[i].getFeatureType().concat(" "));
	        System.out.print(rseps[i].getId().concat(" ") );
            System.out.print(rseps[i].getName().concat(" "));
   	        System.out.println(rseps[i].getColor());
            System.out.println(rseps[i].getColor().substring(1,rseps[i].getColor().length()));
        }
    }
}
