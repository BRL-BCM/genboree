package org.genboree.upload;

import java.util.*;
import org.genboree.util.Util;

public class TDReceiver
{
    protected Hashtable ht = new Hashtable();
    protected Vector vSect = new Vector();
    protected String sSect = "[reference_points]";
    protected String sSectMeta = sSect + "_meta";
    protected String sSectCons = sSect + "_consumer";
    protected String[] mSect = null;
    protected boolean first_line = true;
    protected TDConsumer consumer = null;

    public TDReceiver()
    {
        ht.put( sSect, vSect );
    }

    public void setSection( String sect )
    {
        if( sect == null ) return;
        sSect = sect;
        sSectMeta = sSect + "_meta";
        sSectCons = sSect + "_consumer";
        vSect = (Vector) ht.get( sSect );
        mSect = (String []) ht.get( sSectMeta );
        consumer = (TDConsumer) ht.get( sSectCons );
        if( vSect == null )
        {
            vSect = new Vector();
            ht.put( sSect, vSect );
            first_line = true;
        }
        else first_line = (vSect.size() == 0);
    }

    public void setMeta( String[] meta )
    {
        mSect = meta;
        if( mSect == null ) ht.remove( sSectMeta );
        else ht.put( sSectMeta, mSect );
    }

    public void setConsumer( TDConsumer c )
    {
        consumer = c;
        if( consumer == null ) ht.remove( sSectCons );
        else ht.put( sSectCons, consumer );
    }

    public String[] getMeta() { return mSect; }

    public int keyToIndex( String key )
    {
        if( key == null || mSect == null ) return -1;
        for( int i=0; i<mSect.length; i++ )
            if( mSect[i].equalsIgnoreCase(key) ) return i;
        return -1;
    }

    public int getLength()
    {
        return vSect.size();
    }

    public String getValueAt( int row, int col )
    {
        if( row < 0 || col < 0 || row >= vSect.size() ) return null;
        String[] rc = (String []) vSect.elementAt( row );
        if( col >= rc.length ) return null;
        return rc[col];
    }

    public void addLine( String s )
    {
        s = s.trim();
        if( s.length() == 0 ) return;
        if( s.startsWith("#") )
        {
            if( first_line )
            {
                String[] rm = Util.parseString( s.substring(1), '\t' );
                if( rm != null )
                {
                    setMeta( rm );
                    if( consumer != null ) consumer.setMeta( rm );
                }
                first_line = false;
            }
            return;
        }
        if( s.startsWith("[") && s.endsWith("]") )
        {
            setSection( s );
            return;
        }
        String[] rc = Util.parseString( s, '\t' );
        if( rc != null )
        {
            if( consumer != null ) consumer.consume( this, rc );
            else vSect.addElement( rc );
        }
    }

}
