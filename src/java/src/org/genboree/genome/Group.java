package org.genboree.genome;

import java.util.*;

public class Group
{
    protected String name;
    public String getName() { return name; }

    protected long ePointStartPosition = Long.MAX_VALUE;
    public long getEPointStartPosition() { return ePointStartPosition; }

    protected long ePointStopPosition = Long.MIN_VALUE;
    public long getEpointStopPosition() { return ePointStopPosition; }

    public Group( String name )
    {
        this.name = name;
    }

    public void addAnnotation( long start, long stop )
    {
        if( ePointStartPosition > start ) ePointStartPosition = start;
        if( ePointStopPosition < stop ) ePointStopPosition = stop;
    }
}
