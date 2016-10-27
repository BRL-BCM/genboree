package org.genboree.genome;

import java.util.*;
import java.sql.SQLException;

import org.genboree.dbaccess.*;
import org.genboree.util.Util;

public class Genome
{
    static
    {
        System.setProperty( "java.awt.headless", "true" );
    }

    protected int userId;
    public int getUserId() { return userId; }

    protected VGPaint vgp;
    public VGPaint getVgp() { return vgp; }

    protected int refSeqId;
    public int getRefSeqId() { return refSeqId; }

    protected ArrayList ePoints = new ArrayList(10);
    public ArrayList getEPoints() { return ePoints; }

    protected ArrayList chromTemplates = new ArrayList(10);
    public ArrayList getChromosomeTemplates() { return chromTemplates; }

    protected GenomeTemplate genomeTemplate = new GenomeTemplate();
    public GenomeTemplate getGenomeTemplate() { return genomeTemplate; }

    public int getNumCategories() { return vgp.getFcategoryCount(); }
    public String getSpecies() { return rseq.getRefseq_species(); }

    protected DBAgent db = DBAgent.getInstance();
    public DBAgent getDBAgent() { return db; }

    protected Refseq rseq = new Refseq();
    public Refseq getRefseq() { return rseq; }

    protected String[] dbNames;
    public String[] getDbNames() { return dbNames; }

    public Genome( VGPaint vgp, int userId ) throws SQLException {
        this.userId = userId;
        this.vgp = vgp;

        rseq.fetch( db, vgp.getDatabaseName() );
        refSeqId = Util.parseInt( rseq.getRefSeqId(), -1 );
        dbNames = rseq.fetchDatabaseNames( db );

        genomeTemplate.setGenomeTemplateId( Util.parseInt(rseq.getFK_genomeTemplate_id(), -1) );
        genomeTemplate.fetch( db );
        chromTemplates = genomeTemplate.getChromosomeTemplates();

        int i, j;
        Hashtable ht = new Hashtable();

        for( i=0; i<dbNames.length; i++ )
        {
            DbFref[] eps = DbFref.fetchAll( db.getConnection(dbNames[i]) );
            for( j=0; j<eps.length; j++ )
            {
                String epName = eps[j].getRefname();
                if( ht.get(epName) == null )
                    ht.put( epName, eps[j] );
            }
        }

        for( Enumeration en=ht.keys(); en.hasMoreElements(); )
        {
            DbFref fref = (DbFref) ht.get( en.nextElement() );
            ChromosomeTemplate cht = findChromosomeTemplate( fref.getRefname() );
// System.out.println( "ChromName: "+cht.getChromosomeTemplateChromName()+
// " StdName: "+cht.getChromosomeTemplateStandardName() );

            EPoint epoint = new EPoint( fref, this, cht );
            VGPaint.VGPFentrypoint vfep = vgp.findEntryPoint( fref.getRefname() );
// System.out.println( "Searching for: "+fref.getRefname() );
            if( vfep == null ) continue;
// System.out.println( "found: "+vfep.getName() );
            epoint.setVisualProperties( vfep );
            ePoints.add( epoint );
        }
        Collections.sort( ePoints, new EntryPointComparatorByAbb() );

        i = 0;
        Iterator itr = ePoints.iterator();
        while( itr.hasNext() )
        {
            EPoint epoint = (EPoint)itr.next();
            epoint.setId( i++ );
        }

    }

    public Genome( int userId, String xmlFile )
            throws java.io.IOException, org.xml.sax.SAXException,
            javax.xml.parsers.ParserConfigurationException, SQLException
    {
        this( new VGPaint(xmlFile), userId );
    }

    public long getSizeBiggestVisibleEntryPoint()
    {
        long rc = 0L;
        Iterator epIterat = ePoints.iterator();
        while(epIterat.hasNext())
        {
            EPoint epoint = (EPoint) epIterat.next();
            if( !epoint.getDisplay() ) continue;
            if( epoint.getSize() > rc ) rc = epoint.getSize();
        }
        return rc;
    }

    public long getSizeBiggestVisibleChromosomeTemplate()
    {
        long rc = 0L;
        Iterator epIterat = ePoints.iterator();
        while(epIterat.hasNext())
        {
            EPoint epoint = (EPoint) epIterat.next();
            if( !epoint.getDisplay() ) continue;
            ChromosomeTemplate cht = epoint.getChromosomeTemplate();
            long sz = (cht == null) ? 0L : cht.getChromosomeTemplateLength();
            if( sz > rc ) rc = sz;
        }
        return rc;
    }

    protected ChromosomeTemplate findChromosomeTemplate( String entryPointName )
    {
        Iterator itr = chromTemplates.iterator();
        while( itr.hasNext() )
        {
            ChromosomeTemplate chro = (ChromosomeTemplate) itr.next();
            if( entryPointName.equals(chro.getChromosomeTemplateStandardName()) )
                return chro;
        }
        return null;
    }

    public EPoint getEpoint( int entryPointId )
    {
        Iterator epIterat = ePoints.iterator();
        while( epIterat.hasNext() )
        {
            EPoint epoint = (EPoint)epIterat.next();
            if(epoint.getId() == entryPointId) return epoint;
        }
        return null;
    }

    public EPoint getEpointFromAbb( String abb )
    {
        Iterator epIterat = ePoints.iterator();
        while( epIterat.hasNext() )
        {
            EPoint epoint = (EPoint)epIterat.next();
            if( epoint.getAbbreviation().equals(abb) ) return epoint;
        }
        return null;
    }

    public static class EntryPointComparatorByAbb
        implements Comparator
    {
        protected int compareStrings( String first, String second )
        {
            if(first == null) first = " ";
            if(second == null) second = " ";

            if(Character.isDigit(first.charAt(0)))
            {
                while(first.length() < 10) first = " " + first;
            }

            if(Character.isDigit(second.charAt(0)))
            {
                while(second.length() < 10) second = " " + second;
            }

            return first.compareTo( second );
        }

        public int compare( Object object1, Object object2 )
        {
            EPoint firstEntryPoint = ( EPoint ) object1;
            EPoint secondEntryPoint = ( EPoint ) object2;
            String first = firstEntryPoint.getAbbreviation();
            String second = secondEntryPoint.getAbbreviation();
            return compareStrings(first, second);
        }

    } // end class epStartPositionComparator


    public static void main( String[] args )
        throws Exception
    {
        Genome g = new Genome( 78, "mouseSynteny.xml" );

        ArrayList eps = g.getEPoints();
        Iterator itr = eps.iterator();
        while( itr.hasNext() )
        {
            EPoint epoint = (EPoint) itr.next();
            System.out.println( "EP: "+epoint.getName()+", sz="+epoint.getSize() );

            VGPaint.VGPFentrypoint vfep = epoint.getVGPFentrypoint();
            if( vfep != null ) System.out.println( "  vgpEP: "+vfep.getName() );

            ChromosomeTemplate cht = epoint.getChromosomeTemplate();
            if( cht != null ) System.out.println(
            "  templ: "+cht.getChromosomeTemplateChromName()+
            " std="+cht.getChromosomeTemplateStandardName()+
            " box="+cht.getChromosomeTemplateBoxSize()+
            " len="+cht.getChromosomeTemplateLength() );
        }

        org.genboree.svg.image.ImageGenerator imgGen =
            new org.genboree.svg.image.ImageGenerator( g, "." );
    }


}
