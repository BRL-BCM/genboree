package org.genboree.dbaccess;

import java.io.*;
import java.util.*;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import javax.xml.parsers.*;
import org.xml.sax.helpers.*;
import org.xml.sax.*;
import org.genboree.util.Util;

public class VGPaint extends DefaultHandler
{
    private static final VGPFcategory[] fcatTemplArr = new VGPFcategory[0];
    private static final VGPFtype[] ftypeTemplArr = new VGPFtype[0];

    protected String databaseName;
    public String getDatabaseName() { return databaseName; }
    public void setDatabaseName( String databaseName ) { this.databaseName = databaseName; }
    protected String description;
    public String getDescription() { return description; }
    public void setDescription( String description ) { this.description = description; }
    protected String dsnSource;
    public String getDsnSource() { return dsnSource; }
    public void setDsnSource( String dsnSource ) { this.dsnSource = dsnSource; }

    public VGPaint()
    {
    }

    public VGPaint(String nameXmlFile) throws IOException, SAXException, ParserConfigurationException {
        FileInputStream fin;
        fin = new FileInputStream(nameXmlFile);
        this.deserialize( fin );
        fin.close();
    }

    public static class VGPFtype implements Comparable
    {
        protected int orientation;
        public int getOrientation() { return orientation; }
        public void setOrientation( int orientation ) { this.orientation = orientation; }
        protected String source;
        public String getSource() { return source; }
        public void setSource( String source ) { this.source = source; }
        protected String method;
        public String getMethod() { return method; }
        public void setMethod( String method ) { this.method = method; }
        protected boolean display;
        public boolean getDisplay() { return display; }
        public void setDisplay( boolean display ) { this.display = display; }
        protected String abbreviation;
        public String getAbbreviation() { return abbreviation; }
        public void setAbbreviation( String abbreviation ) { this.abbreviation = abbreviation; }
        protected String color;
        public String getColor() { return color; }
        public void setColor( String color ) { this.color = color; }

        protected VGPFtype() {}
        public String getDisplayableName() { return getMethod()+":"+getSource(); }
        public String toString() { return getDisplayableName(); }
        public int compareTo( Object o ) { return toString().compareTo(o.toString()); }
    }

    public static class VGPFcategory
    {
        protected int index;
        public int getIndex() { return index; }
        public void setIndex( int index ) { this.index = index; }
        protected String orientation;
        public String getOrientation() { return orientation; }
        public void setOrientation( String orientation ) { this.orientation = orientation; }
        protected int order;
        public int getOrder() { return order; }
        public void setOrder( int order ) { this.order = order; }
        protected String name;
        public String getName() { return name; }
        public void setName( String name ) { this.name = name; }
        protected String description;
        public String getDescription() { return description; }
        public void setDescription( String description ) { this.description = description; }
        protected String abbreviation;
        public String getAbbreviation() { return abbreviation; }
        public void setAbbreviation( String abbreviation ) { this.abbreviation = abbreviation; }

        protected VGPFcategory() {}
    }

    public static class VGPFentrypoint implements Comparable
    {
        protected String name;
        public String getName() { return name; }
        public void setName( String name ) { this.name = name; }
        protected boolean display;
        public boolean getDisplay() { return display; }
        public void setDisplay( boolean display ) { this.display = display; }
        protected String center_header;
        public String getCenter_header() { return center_header; }
        public void setCenter_header( String center_header ) { this.center_header = center_header; }
        protected String abbreviation;
        public String getAbbreviation() { return abbreviation; }
        public void setAbbreviation( String abbreviation ) { this.abbreviation = abbreviation; }

        protected VGPFentrypoint() {}

        protected Vector cats = new Vector();
        protected Vector eps = new Vector();
        public void reset()
        {
            cats.clear();
            eps.clear();
        }
        public int getFcategoryCount() { return cats.size(); }
        public VGPFcategory getFcategoryAt( int idx ) { return (VGPFcategory) cats.elementAt(idx); }
        public void addFcategory( VGPFcategory c )
        {
            cats.addElement( c );
            eps.addElement( new Vector() );
        }
        public void removeFcategory( int idx )
        {
            cats.removeElementAt( idx );
            eps.removeElementAt( idx );
        }

        public int getFtypeCount( VGPFcategory c )
        {
            int idx = cats.indexOf( c );
            if( idx < 0 ) return 0;
            Vector v = (Vector) eps.elementAt( idx );
            return v.size();
        }
        public VGPFtype findFtype( VGPFcategory c, String method, String source )
        {
            int idxc = cats.indexOf( c );
            if( idxc < 0 ) return null;
            Vector v = (Vector) eps.elementAt( idxc );
            for( int i=0; i<v.size(); i++ )
            {
                VGPFtype ft = (VGPFtype) v.elementAt( i );
                if( ft.getSource().equals(source) && ft.getMethod().equals(method) )
                    return ft;
            }
            return null;
        }
        public VGPFtype getFtypeAt( VGPFcategory c, int idx )
        {
            int idxc = cats.indexOf( c );
            Vector v = (Vector) eps.elementAt( idxc );
            return (VGPFtype) v.elementAt( idx );
        }
        public void addFtype( VGPFcategory c, VGPFtype t )
        {
            int idxc = cats.indexOf( c );
            Vector v = (Vector) eps.elementAt( idxc );
            v.addElement( t );
        }
        public void removeFtype( VGPFcategory c, int idx )
        {
            int idxc = cats.indexOf( c );
            Vector v = (Vector) eps.elementAt( idxc );
            v.removeElementAt( idx );
        }

        public VGPFtype[] getFtypes()
        {
            Vector v = new Vector();
            for( int i=0; i<eps.size(); i++ )
            {
                v.addAll( (Collection)eps.elementAt(i) );
            }
            VGPFtype[] rc = (VGPFtype[]) v.toArray( ftypeTemplArr );
            Arrays.sort( rc );
            return rc;
        }

        public String getDisplayableName() { return getName(); }
        public String toString() { return getDisplayableName(); }
        public int compareTo( Object o ) { return toString().compareTo(o.toString()); }
    }

    protected Vector feps = new Vector();

    public int getFentrypointCount() { return feps.size(); }
    public VGPFentrypoint getFentrypointAt( int idx )
    {
        return (VGPFentrypoint) feps.elementAt( idx );
    }
    public VGPFentrypoint findEntryPoint( String name )
    {
        int n = getFentrypointCount();
        for( int i=0; i<n; i++ )
        {
            VGPFentrypoint ep = getFentrypointAt( i );
            if( name.equals(ep.getName()) ) return ep;
        }
        return null;
    }
    public VGPFentrypoint defineFentrypoint( String name, boolean display,
        String center_header, String abbreviation )
    {
        VGPFentrypoint ep = findEntryPoint( name );
        if( ep == null )
        {
            ep = new VGPFentrypoint();
            ep.setName( name );
            ep.setDisplay( display );
            ep.setCenter_header( center_header );
            ep.setAbbreviation( abbreviation );
            feps.addElement( ep );
        }
        return ep;
    }

    protected Vector fcats = new Vector();
    public int getFcategoryCount() { return fcats.size(); }
    public VGPFcategory getFcategoryAt( int idx )
    {
        return (VGPFcategory) fcats.elementAt( idx );
    }
    public VGPFcategory findFcategory( String name )
    {
        int n = getFcategoryCount();
        for( int i=0; i<n; i++ )
        {
            VGPFcategory c = getFcategoryAt( i );
            if( name.equals(c.getName()) ) return c;
        }
        return null;
    }
    public VGPFcategory defineFcategory( String orientation, int order, String name,
        String description, String abbreviation )
    {
        VGPFcategory c = findFcategory( name );
        if( c == null )
        {
            c = new VGPFcategory();
            c.setIndex( fcats.size() );
            c.setOrientation( orientation );
            c.setOrder( order );
            c.setName( name );
            c.setDescription( description );
            c.setAbbreviation( abbreviation );
            fcats.addElement( c );
        }
        return c;
    }
    public VGPFcategory[] getFcategories()
    {
        return (VGPFcategory[]) fcats.toArray( fcatTemplArr );
    }

    protected Vector ftypes = new Vector();
    public int getFtypeCount() { return ftypes.size(); }
    public VGPFtype getFtypeAt( int idx )
    {
        return (VGPFtype) ftypes.elementAt( idx );
    }
    public int indexOfFtype( VGPFtype ft ) { return ftypes.indexOf(ft); }
    public VGPFtype findFtype( String source, String method )
    {
        int n = getFtypeCount();
        for( int i=0; i<n; i++ )
        {
            VGPFtype t = getFtypeAt( i );
            if( source.equals(t.getSource()) && method.equals(t.getMethod()) ) return t;
        }
        return null;
    }
    public VGPFtype defineFtype( int orientation, String source, String method,
        boolean display, String abbreviation, String color )
    {
        VGPFtype t = findFtype( source, method );
        if( t == null )
        {
            t = new VGPFtype();
            t.setOrientation( orientation );
            t.setSource( source );
            t.setMethod( method );
            t.setDisplay( display );
            t.setAbbreviation( abbreviation );
            t.setColor( color );
            int idx = Arrays.binarySearch( ftypes.toArray(), t );
            if( idx < 0 ) idx = -(idx + 1);
            ftypes.insertElementAt( t, idx );
        }
        return t;
    }


    // SAX Parser callback
    private VGPFentrypoint curEp = null;
    private VGPFcategory curCat = null;
    private VGPFtype curFt = null;
    private boolean in_fcat_list = false;
    private boolean in_ftype_list = false;
    private Hashtable htFt = new Hashtable();

    public void startElement( String uri, String localName, String qName,
        Attributes attr )
        throws SAXException
    {
        if( qName == null ) return;
        qName = qName.toUpperCase();
        if( qName.equals("FREFSEQ") )
        {
            setDatabaseName( attr.getValue("databaseName") );
            setDescription( attr.getValue("description") );
            setDsnSource( attr.getValue("dsnSource") );
            feps.clear();
            fcats.clear();
            ftypes.clear();
            htFt.clear();
            curEp = null;
            curCat = null;
            curFt = null;
            in_fcat_list = false;
            in_ftype_list = false;
        }
        else if( qName.equals("FCATEGORYLIST") )
        {
            in_fcat_list = true;
        }
        else if( qName.equals("FTYPELIST") )
        {
            in_ftype_list = true;
        }
        else if( qName.equals("FENTRYPOINT") )
        {
            String sDispl = attr.getValue("display");
            if( sDispl == null ) sDispl = "y";
            else sDispl = sDispl.toLowerCase();
            boolean display = sDispl.startsWith("y");
            curEp = defineFentrypoint( attr.getValue("name"), display,
                attr.getValue("center_header"), attr.getValue("abbreviation") );
        }
        else if( qName.equals("FCATEGORY") )
        {
            if( in_fcat_list )
            {
                int order = Util.parseInt( attr.getValue("order"), getFcategoryCount()+1 );
                curCat = defineFcategory( attr.getValue("orientation"), order, attr.getValue("name"),
                    attr.getValue("description"), attr.getValue("abbreviation") );
            }
            else
            {
                if( curEp == null ) return;
                int idx = Util.parseInt( attr.getValue("id"), -1 );
                if( idx>=0 && idx<getFcategoryCount() )
                    curCat = getFcategoryAt( idx );
                curEp.addFcategory( curCat );
            }
        }
        else if( qName.equals("FTYPE") )
        {
            if( in_ftype_list )
            {
                int ori = Util.parseInt( attr.getValue("category"), 0 );
                if( ori<0 || ori>=getFcategoryCount() ) ori = 0;
                String sDispl = attr.getValue("display");
                if( sDispl == null ) sDispl = "y";
                else sDispl = sDispl.toLowerCase();
                boolean display = sDispl.startsWith("y");
                curFt = defineFtype( ori, attr.getValue("source"),
                    attr.getValue("method"), display,
                    attr.getValue("abbreviation"), attr.getValue("color") );
                htFt.put( attr.getValue("id"), curFt );
            }
            else
            {
                if( curEp == null || curCat == null ) return;
                curFt = (VGPFtype) htFt.get( attr.getValue("id") );
                if( curFt != null )
                {
                    curEp.addFtype( curCat, curFt );
                }
/*
                int idx = Util.parseInt( attr.getValue("id"), -1 );
                if( idx>=0 && idx<getFtypeCount() )
                {
                    curFt = getFtypeAt( idx );
                    curEp.addFtype( curCat, curFt );
                }
*/
            }
        }
    }
    public void endElement( String uri, String localName, String qName )
        throws SAXException
    {
        if( qName == null ) return;
        qName = qName.toUpperCase();
        if( qName.equals("FREFSEQ") )
        {
            curEp = null;
            curCat = null;
            curFt = null;
            in_fcat_list = false;
            in_ftype_list = false;
        }
        else if( qName.equals("FCATEGORYLIST") )
        {
            in_fcat_list = false;
        }
        else if( qName.equals("FTYPELIST") )
        {
            in_ftype_list = false;
        }
        else if( qName.equals("FENTRYPOINT") )
        {
            curEp = null;
        }
        else if( qName.equals("FCATEGORY") )
        {
            curCat = null;
        }
        else if( qName.equals("FTYPE") )
        {
            curFt = null;
        }
    }

    public void deserialize( InputStream in )
        throws SAXException, ParserConfigurationException, IOException
    {
        curEp = null;
        curCat = null;
        curFt = null;
        in_fcat_list = false;
        in_ftype_list = false;
        SAXParser sp = SAXParserFactory.newInstance().newSAXParser();
        sp.parse( in, this );
    }

    public void serialize( OutputStream _out )
    {
        PrintStream out = new PrintStream( _out );

        out.println( "<?xml version=\"1.0\" standalone=\"yes\"?>" );
        out.println( "<!DOCTYPE VGPAINT SYSTEM \"http://www.genboree.org/dtd/vgpaint.dtd\">" );
        out.println( "<VGPAINT>" );
        out.println( "  <FREFSEQ databaseName=\""+getDatabaseName()+
        "\" description=\""+Util.htmlQuote(getDescription())+
        "\" dsnSource=\""+getDsnSource()+"\">" );

        int i;

        int ncats = getFcategoryCount();
        out.println();
        out.println( "    <FCATEGORYLIST>" );
        for( i=0; i<ncats; i++ )
        {
            VGPaint.VGPFcategory c = getFcategoryAt( i );
            out.println( "      <FCATEGORY id=\""+i+
            "\" name=\""+Util.htmlQuote(c.getName())+
            "\" orientation=\""+c.getOrientation()+
            "\" description=\""+Util.htmlQuote(c.getDescription())+
            "\" order=\""+c.getOrder()+
            "\" abbreviation=\""+Util.htmlQuote(c.getAbbreviation())+"\"/>" );
        }
        out.println( "    </FCATEGORYLIST>" );

        int nftypes = getFtypeCount();
        out.println();
        out.println( "    <FTYPELIST>" );
        for( i=0; i<nftypes; i++ )
        {
            VGPaint.VGPFtype ft = getFtypeAt( i );
            out.println( "      <FTYPE id=\""+i+
            "\" category=\""+ft.getOrientation()+
            "\" method=\""+Util.htmlQuote(ft.getMethod())+
            "\" source=\""+Util.htmlQuote(ft.getSource())+
            "\" display=\""+(ft.getDisplay()?"yes":"no")+
            "\" abbreviation=\""+Util.htmlQuote(ft.getAbbreviation())+
            "\" color=\""+ft.getColor()+"\"/>" );
        }
        out.println( "    </FTYPELIST>" );

        int neps = getFentrypointCount();
        for( int iep=0; iep<neps; iep++ )
        {
            VGPaint.VGPFentrypoint ep = getFentrypointAt( iep );
            out.println();
            out.println( "    <FENTRYPOINT name=\""+Util.htmlQuote(ep.getName())+
            "\" center_header=\""+Util.htmlQuote(ep.getCenter_header())+
            "\" display=\""+(ep.getDisplay()?"yes":"no")+
            "\" abbreviation=\""+Util.htmlQuote(ep.getAbbreviation())+"\">" );

            int nc = ep.getFcategoryCount();
            for( int ic=0; ic<nc; ic++ )
            {
                VGPaint.VGPFcategory c = ep.getFcategoryAt( ic );
                int nft = ep.getFtypeCount( c );
                if( nft == 0 ) continue;
                out.println( "      <FCATEGORY id=\""+c.getIndex()+"\">" );

                for( int ift=0; ift<nft; ift++ )
                {
                    VGPaint.VGPFtype ft = ep.getFtypeAt( c, ift );
                    int idx = ftypes.indexOf( ft );
                    if( idx >= 0 )
                        out.println( "        <FTYPE id=\""+idx+"\"/>" );
                }

                out.println( "      </FCATEGORY>" );
            }

            out.println( "    </FENTRYPOINT>" );
        }

        out.println();
        out.println( "  </FREFSEQ>" );
        out.println( "</VGPAINT>" );
        out.flush();
    }

    public static String guessAbbr( String s )
    {
        if( s == null ) s = "";
        StringBuffer sb = new StringBuffer( s );
        StringBuffer tb = new StringBuffer();
        boolean in_dig = false;
        for( int i=0; i<sb.length(); i++ )
        {
            char c = sb.charAt(i);
            if( Character.isDigit(c) )
            {
                tb.append( c );
                in_dig = true;
            }
            else if( in_dig ) break;
        }
        return tb.toString();
    }

    // DB specific stuff
    public String fetchRefSeqId( DBAgent db )
    {
        String rc = "#";
        DbResourceSet dbRes = null;
        ResultSet rs = null;
        String dbName = getDatabaseName();
        if( dbName == null ) return rc;
        try
        {
            dbRes = db.executeQuery("SELECT refSeqId FROM refseq WHERE databaseName='"+dbName+"'" );
            rs = dbRes.resultSet;
            if( rs.next() ) rc = rs.getString(1);
        } catch( Exception ex )
        {
            System.err.print("Exception on VGPaint::fetchRefSeqId");
            ex.printStackTrace(System.err);
            db.reportError(ex,"VGPaint.fetchRefSeqId()");
        }
        return rc;
    }

    protected String refSeqId = "#";
    protected Refseq refseq = null;
    public Refseq getRefseq() { return refseq; }
    protected GenboreeUpload[] guplds = null;
    protected String[] dbNames = null;

    public boolean initDBaccess( DBAgent db, String refSeqId, int genboreeUserId ) throws SQLException {
        if( refSeqId == null ) return false;
        this.refSeqId = refSeqId;
        refseq = new Refseq();
        refseq.setRefSeqId( refSeqId );
        if( !refseq.fetch(db) ) return false;
        setDatabaseName( refseq.getDatabaseName() );
        setDescription( refseq.getRefseqName() );
        setDsnSource( "" );
        guplds = GenboreeUpload.fetchAll( db, refSeqId, null, genboreeUserId );
        dbNames = refseq.fetchDatabaseNames( db );
        return dbNames != null;
    }

    public boolean fetchEntryPoints( DBAgent db )
    {
        if( refseq == null || dbNames == null ) return false;

		int i;

        DbFref[] srcEps = DbFref.fetchAll( db, dbNames );

		int nsz = srcEps.length;
		VGPFentrypoint[] eps = new VGPFentrypoint[nsz];
		for( i=0; i<nsz; i++ )
		{
			String id = srcEps[i].getRefname();
			String ab = guessAbbr( id );
			eps[i] = defineFentrypoint( id, true, "Chromosome "+ab, ab );
        }

		feps.clear();
		for( i=0; i<nsz; i++ )
		{
			feps.addElement( eps[i] );
		}
        return true;
    }

    public boolean fetchTracks( DBAgent db, int genboreeUserId  ) throws SQLException {
        if( refseq == null || dbNames == null ) return false;

        VGPFcategory[] acats = getFcategories();
        if( acats.length < 1 ) return false;
        int i, j;

        String[] cabrs = new String[ acats.length ];
        for( i=0; i<acats.length; i++ )
        {
            String ab = acats[i].getAbbreviation();
            if( ab==null || ab.length()==0 ) ab = " ";
            cabrs[i] = ab.substring(0,1).toUpperCase();
        }

        Vector vFtypes = new Vector();

        int neps = getFentrypointCount();
        for( int epi=0; epi<neps; epi++ )
        {
            VGPFentrypoint ep = getFentrypointAt( epi );

            ep.reset();
            for( i=0; i<acats.length; i++ ) ep.addFcategory( acats[i] );

            DbFtype[] trks = refseq.fetchTracks( db, dbNames, ep.getName(), genboreeUserId );
            if( trks == null ) continue;

		    for( j=0; j<trks.length; j++ )
		    {
			    String method = trks[j].getFmethod();
			    String source = trks[j].getFsource();
			    if( source.equalsIgnoreCase("Chromosome") ||
				    source.equalsIgnoreCase("Sequence") )
				    continue;
				int ori = 0;
				for( ori=0; ori<cabrs.length; ori++ )
				    if( source.toUpperCase().startsWith(cabrs[ori]) ) break;
				if( ori >= cabrs.length ) ori = 0;
		        VGPFtype ft = defineFtype( ori, source, method, true,
		            guessAbbr(source), "#45E6E6" );
		        ori = ft.getOrientation();
				if( ori < 0 || ori >= acats.length ) ori = 0;
		        ep.addFtype( acats[ori], ft );
		        if( !vFtypes.contains(ft) ) vFtypes.addElement( ft );
		    }

        }

        ftypes = vFtypes;

        return true;
    }

    public void loadDefaultColors( DBAgent db, String userId ) throws SQLException {
        int i;
        int nftypes = getFtypeCount();
        if( nftypes == 0 ) return;

        Style[] colors = refseq.fetchColors( db );
        if( colors==null || colors.length==0 ) return;
        int nc = colors.length;
        for( i=0; i<nftypes; i++ )
        {
            VGPFtype ft = getFtypeAt( i );
            ft.setColor( colors[i%nc].color );
        }

        Style[] sm = refseq.fetchStyleMap( db, Util.parseInt(userId,0) );
        if( sm==null || sm.length==0 ) return;
        Hashtable ht = new Hashtable();
        for( i=0; i<sm.length; i++ ) ht.put( sm[i].featureType, sm[i] );

        for( i=0; i<nftypes; i++ )
        {
            VGPFtype ft = getFtypeAt( i );
            Style st = (Style) ht.get( ft.getDisplayableName() );
            if( st != null ) ft.setColor( st.color );
        }
    }

    public boolean updateTracksAndColors( DBAgent db, boolean is_new, String userId ) throws SQLException {
        Hashtable ht = new Hashtable();
        int i, n = getFtypeCount();
        int genboreeUserId = Util.parseInt( userId, -1 );

        if( !is_new )
        for( i=0; i<n; i++ )
        {
            VGPFtype ft = getFtypeAt( i );
            String c = ft.getColor();
            if( !Util.isEmpty(c) ) ht.put( ft, c );
        }

        boolean rc = fetchTracks( db, genboreeUserId );
        loadDefaultColors( db, userId );

        if( is_new ) return rc;

        n = getFtypeCount();
        for( i=0; i<n; i++ )
        {
            VGPFtype ft = getFtypeAt( i );
            String c = (String) ht.get( ft );
            if( c != null ) ft.setColor( c );
        }

        return rc;
    }

    public void validateFtypes()
    {
        VGPFcategory[] acats = getFcategories();
        if( acats.length == 0 ) return;
        int i;
        int neps = getFentrypointCount();
        for( int epi=0; epi<neps; epi++ )
        {
            VGPFentrypoint ep = getFentrypointAt( epi );
            VGPFtype[] fts = ep.getFtypes();
            ep.reset();
            for( i=0; i<acats.length; i++ ) ep.addFcategory( acats[i] );
            for( i=0; i<fts.length; i++ )
            {
		        VGPFtype ft = fts[i];
		        int ori = ft.getOrientation();
				if( ori < 0 || ori >= acats.length ) ori = 0;
		        ep.addFtype( acats[ori], ft );
            }
        }
    }

    // Example of a coorect way to loop across the VGPaint object
    public static void loopOver( VGPaint vgp, PrintStream out )
    {
        int neps = vgp.getFentrypointCount();
        // Loop over fentrypoints
        for( int iep=0; iep<neps; iep++ )
        {
            VGPaint.VGPFentrypoint ep = vgp.getFentrypointAt( iep );
            out.println( "EP: "+ep.getName() );

            int nc = ep.getFcategoryCount();
            // Loop over fcategories
            for( int ic=0; ic<nc; ic++ )
            {
                VGPaint.VGPFcategory c = ep.getFcategoryAt( ic );
                out.println( "  CA: "+c.getName()+"  "+c.getOrientation() );

                int nft = ep.getFtypeCount( c );
                // Loop over ftypes
                for( int ift=0; ift<nft; ift++ )
                {
                    VGPaint.VGPFtype ft = ep.getFtypeAt( c, ift );
                    out.println( "    FT: "+ft.toString() );
                }
            }
        }
    }

    public static void main( String[] args ){
        VGPaint vgp = null;
        if( args.length < 1 )
        {
            System.out.println( "Please specify VGP XML file" );
            System.exit(0);
        }

        // Create VGPaint object out of an XML file
//        FileInputStream fin = new FileInputStream( args[0] );
//        VGPaint vgp = new VGPaint(fin);
//        vgp.deserialize( fin );
//        fin.close();
//        for( int i=0; i<vgp.getFtypeCount(); i++ )
//        {
//            VGPaint.VGPFtype t = vgp.getFtypeAt( i );
//            System.out.println( t.toString() );
//        }


        try {
            vgp = new VGPaint(args[0]);

            System.out.println("Database Name " + vgp.getDatabaseName());
            System.out.println("Description " +vgp.getDescription());
            System.out.println("Location " +vgp.getDsnSource());


            for (int ep = 0, epCount = vgp.getFentrypointCount(); ep < epCount; ep++)
            {
                VGPFentrypoint myEntryPoint = vgp.getFentrypointAt(ep);
                System.out.print("EntryPoint Name = " + myEntryPoint.getName());
                System.out.print(" Center Header = " + myEntryPoint.getCenter_header());
                System.out.print(" is display = " + myEntryPoint.getDisplay());
                System.out.println(" abbreviation = " + myEntryPoint.getAbbreviation());

            }
            for (int ca = 0, caCount = vgp.getFcategoryCount(); ca < caCount; ca++)
            {
                VGPFcategory myCategory = vgp.getFcategoryAt(ca);
                System.out.print("\tCategory Name = " + myCategory.getName());
                System.out.print(" orientation = " + myCategory.getOrientation());
                System.out.print(" description = " + myCategory.getDescription());
                System.out.print(" order = " + myCategory.getOrder());
                System.out.println(" abbreviation = " + myCategory.getAbbreviation());
            }

            for (int ft = 0, ftCount = vgp.getFtypeCount(); ft < ftCount; ft++)
            {
                VGPFtype myFtype = vgp.getFtypeAt(ft);
                System.out.print("\t\tType Method = " + myFtype.getMethod());
                System.out.print(" Source = " + myFtype.getSource());
                System.out.print(" Orientation = " + myFtype.getOrientation());
                System.out.print(" Display = " + myFtype.getDisplay());
                System.out.print(" Abbreviation = " + myFtype.getAbbreviation());
                System.out.println(" Color = " + myFtype.getColor());
            }
            System.out.println("-----------------------------------------------------\n");

            for (int ep = 0, epCount = vgp.getFentrypointCount(); ep < epCount; ep++)
            {
                VGPFentrypoint myEntryPoint = vgp.getFentrypointAt(ep);
                for (int ca = 0, caCount = myEntryPoint.getFcategoryCount(); ca < caCount; ca++)
                {
                    VGPFcategory myCategory = myEntryPoint.getFcategoryAt(ca);
                    for (int ft = 0, ftCount = myEntryPoint.getFtypeCount(myCategory); ft < ftCount; ft++)
                    {
                        VGPFtype myFtype = myEntryPoint.getFtypeAt(myCategory, ft);
                        System.out.print(" entry point  = " + myEntryPoint.getName());
                        System.out.print(" category = " + myCategory.getName() + " order is " + myCategory.getOrder());
                        System.out.print(" Type abreviation = " + myFtype.getAbbreviation());
                        System.out.println(" full name = " + myFtype.getMethod() + ":" + myFtype.getSource());
                    }
                }
            }

            for (int ep = 0, epCount = vgp.getFentrypointCount(); ep < epCount; ep++)
            {
                VGPFentrypoint myEntryPoint = vgp.getFentrypointAt(ep);
                for (int ca = 0, caCount = myEntryPoint.getFcategoryCount(); ca < caCount; ca++)
                {
                    VGPFcategory myCategory = myEntryPoint.getFcategoryAt(ca);
                    VGPFtype currentFType = myEntryPoint.findFtype(myCategory, "Pash", "Mm1-b3" );
//                    VGPFtype currentFType = findFtypeInEP(myEntryPoint, myCategory, "Pash", "Mm1-b3" );
                    if(currentFType != null)
                        System.out.println("The results are entryPoint " + myEntryPoint.getName() + " category = " + myCategory.getName() + currentFType.getMethod() + ":" + currentFType.getSource() + " with color " + currentFType.getColor());
                }
            }

        } catch (IOException e) {
            e.printStackTrace();  //To change body of catch statement use Options | File Templates.
        } catch (SAXException e) {
            e.printStackTrace();  //To change body of catch statement use Options | File Templates.
        } catch (ParserConfigurationException e) {
            e.printStackTrace();  //To change body of catch statement use Options | File Templates.
        }

        // Serialize VGPaint object back to another XML file
//        try
//        {
//            String outFile = "out.xml";
//            if( args.length > 1 ) outFile = args[1];
//            FileOutputStream fout = new FileOutputStream( outFile );
//            vgp.serialize( fout );
//            fout.close();
//        } catch( Exception ex0 ) { ex0.printStackTrace(); }

//        VGPaint.loopOver( vgp, System.out );
        System.exit(0);
    }

}

