package org.genboree.genome;

import java.util.*;

import org.genboree.dbaccess.*;

public class FType
{
    protected String fmethod;
    public String getFmethod() { return fmethod; }

    protected String fsource;
    public String getFsource() { return fsource; }

    protected VGPaint.VGPFtype vgpft;

    protected boolean display = true;
    public boolean getDisplay() { return display; }

    protected String abbreviation = "#";
    public String getAbbreviation() { return abbreviation; }

    protected String color = "#888888";
    public String getColor() { return color; }

    protected ArrayList groups = new ArrayList( 10 );
    public int getNumberGroups() { return groups.size(); }
    public Group getGroupAt( int idx ) { return (Group)groups.get(idx); }

    protected Hashtable htGroups = new Hashtable();
    public Group defineGroup( String name )
    {
        Group grp = (Group) htGroups.get( name );
        if( grp == null )
        {
            grp = new Group( name );
            htGroups.put( name, grp );
            groups.add( grp );
        }
        return grp;
    }

    public String getName() { return fmethod+":"+fsource; }
    public String toString() { return fmethod+":"+fsource; }

    public FType( String fmethod, String fsource )
    {
        this.fmethod = fmethod;
        this.fsource = fsource;
    }

    public void setVisualParameters( VGPaint.VGPFtype vgpft )
    {
        this.vgpft = vgpft;
        if( vgpft == null ) return;
        abbreviation = vgpft.getAbbreviation();
        if( abbreviation == null ) abbreviation = "#";
        color = vgpft.getColor();
        if( color == null ) color = "#888888";
        display = vgpft.getDisplay();
    }
}
