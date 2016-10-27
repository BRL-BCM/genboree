package org.genboree.genome;

import java.sql.*;
import java.util.*;

import org.genboree.dbaccess.*;
import org.genboree.util.Util;

public class EPoint
{
    protected int id;
    public int getId() { return id; }
    public void setId( int id ) { this.id = id; }

    protected DbFref fref;
    public DbFref getFref() { return fref; }

    public String getName() { return fref.getRefname(); }
    protected long size;
    public long getSize() { return size; }

    protected String entryPointType = "Chromosome";
    public String getEntryPointType() { return entryPointType; }

    protected VGPaint.VGPFentrypoint vfep;
    public VGPaint.VGPFentrypoint getVGPFentrypoint() { return vfep; }

    public boolean getDisplay() { return vfep.getDisplay(); }
    public String getAbbreviation() { return vfep.getAbbreviation(); }

    protected ArrayList categories = new ArrayList(10);
    public Category getCategoryAt( int idx )
    {
        return (Category)categories.get(idx);
    }
    public int getNumberCategories() { return categories.size(); }

    protected ChromosomeTemplate chromTemplate;
    public ChromosomeTemplate getChromosomeTemplate() { return chromTemplate; }

    protected Genome genome;
    public Genome getGenome() { return genome; }

    protected Hashtable htFtypes;
    protected ArrayList fTypes = null;
    public ArrayList getFTypes()
    {
        if( fTypes == null ) fetchData();
        return fTypes;
    }
    public int getNumFTypes()
    {
        if( fTypes == null ) fetchData();
        return fTypes.size();
    }

    public EPoint( DbFref fref, Genome genome, ChromosomeTemplate chromTemplate )
    {
        this.fref = fref;
        size = Util.parseLong( fref.getRlength(), 0L );
        this.genome = genome;
        this.chromTemplate = chromTemplate;
    }

    public void setVisualProperties( VGPaint.VGPFentrypoint vfep )
    {
        this.vfep = vfep;
        int ncat = vfep.getFcategoryCount();
        for( int i=0; i<ncat; i++ )
        {
            Category c = new Category( this, i );
            categories.add( c );
        }
    }

    private void fetchData()
    {
        fTypes = new ArrayList( 10 );
        htFtypes = new Hashtable();

// if( true ) return;

        Refseq rseq = getGenome().getRefseq();
        DBAgent db = getGenome().getDBAgent();
        DbResourceSet dbRes = null;
        ResultSet rs = null;

        try {

        dbRes = rseq.fetchRecordsFirst( db, null, null, null, getName(), "cg" );
        rs = dbRes.resultSet;
        while( rs != null )
        {
            while( rs.next() )
            {
                String gname = rs.getString("name");
                String fmethod = rs.getString("type");
                String fsource = rs.getString("subtype");
                long fstart = rs.getLong("start");
                long fstop = rs.getLong("stop");

                String ftName = fmethod+":"+fsource;
                FType ft = (FType) htFtypes.get( ftName );
                if( ft == null )
                {
                    ft = new FType( fmethod, fsource );
                    htFtypes.put( ftName, ft );
                }

                Group grp = ft.defineGroup( gname );
                grp.addAnnotation( fstart, fstop );

            }
            dbRes.close();
            dbRes = rseq.fetchRecordsNext( db );
            rs = dbRes.resultSet;
        }


        } catch( Exception ex ) {}

        fTypes.addAll( htFtypes.values() );

    }
}
