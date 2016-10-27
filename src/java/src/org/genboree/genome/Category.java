package org.genboree.genome;

import java.util.*;

import org.genboree.dbaccess.*;

public class Category
{
    protected EPoint epoint;
    protected VGPaint.VGPFentrypoint vfep;
    protected int vgpIndex;
    protected VGPaint.VGPFcategory vgpCategory;

    protected ArrayList fTypes = new ArrayList( 10 );
    public ArrayList getFTypes() { return fTypes; }
    public int getNumberFtypes() { return fTypes.size(); }
    public FType getFtypeAt( int idx )
    {
        return (idx < getNumberFtypes()) ? (FType)fTypes.get(idx) : (FType)null;
    }

    public String getOrientation() { return vgpCategory.getOrientation(); }

    public Category( EPoint epoint, int idx )
    {
        this.epoint = epoint;
        vfep = epoint.getVGPFentrypoint();
        vgpIndex = idx;
        vgpCategory = vfep.getFcategoryAt( vgpIndex );

        ArrayList allFtypes = epoint.getFTypes();
        Iterator itr = allFtypes.iterator();
        while( itr.hasNext() )
        {
            FType ft = (FType) itr.next();
            VGPaint.VGPFtype vgpft = vfep.findFtype( vgpCategory, ft.getFmethod(), ft.getFsource() );
            if( vgpft != null )
            {
                ft.setVisualParameters( vgpft );
                fTypes.add( ft );
            }
        }
    }
}
