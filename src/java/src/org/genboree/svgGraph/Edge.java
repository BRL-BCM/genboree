/*
 * Edge.java
 *
 * Created on August 10, 2004, 10:34 AM
 */

package org.genboree.svgGraph;

import java.math.*;

/**
 *
 * @author  Ming-Te Cheng
 */
public class Edge {
     
    /** Name of edge.*/
    protected String edgeName;
    
    /** Name of source coordinate */
    protected String sourceName;
    
    /** Name of destination coordinate */
    protected String destinationName;
    
    /** Source xy-coordinate of edge. */
    protected Integer [] sourceCoordinate = new Integer [2];
    
    /** Destination xy-coordinate of edge. */
    protected Integer [] destinationCoordinate = new Integer [2];    
    
    /** String containing the distance of edge. */
    protected String distanceString;
    
    /** Distance value of edge. */
    protected double distance;
    
    /** Creates a new instance of Edge. */
    public Edge() 
    {
        this( null );        
    }
    
    /** Creates a new instance of Edge. 
     *  @param name                     Name of edge.     
     */
    public Edge( String name )
    {
        this( name, 0, 0, 0, 0, 0 );        
    }
    
    /** Creates a new instance of Edge.
     *  @param name                     Name of edge.
     *  @param distance                 Distance of edge.
     */
    public Edge( String name, double distance )
    {
        this( name, 0, 0, 0, 0, distance );        
    }
    
    /** Creates a new instance of Edge. 
     *  @param name                     Name of edge.
     *  @param sourceCoordinate         Source xy-coordinate of edge.
     *  @param destinationCoordinate    Destination xy-coordinate of edge.
     *  @param distance                 Distance of edge.
     */
    public Edge( String name, int [] sourceCoordinate, int [] destinationCoordinate, double distance )
    {
        this( name,
            sourceCoordinate[0], sourceCoordinate[1],
            destinationCoordinate[0], destinationCoordinate[1],
            distance
            );       
    }
       
    /** Creates a new instance of Edge. 
     *  @param name                     Name of edge.
     *  @param x1                       Source x-coordinate of edge.
     *  @param y1                       Source y-coordinate of edge.
     *  @param x2                       Destination x-coordinate of edge.
     *  @param y2                       Destination y-coordinate of edge.
     *  @param distance                 Distance of edge.
     */
    public Edge( String name, int x1, int y1, int x2, int y2, double distance )
    {
        String [] splitEdgeName = name.split( "-" );
        
        setName( name );
        setSourceName( splitEdgeName[0] );
        setDestinationName( splitEdgeName[1] );
        setSourceCoordinate( x1, y1 );
        setDestinationCoordinate( x2, y2 );
        setDistance( distance );
    }

    /** Sets name of edge.
     *  @param name                     Name of edge.
     */
    public void setName( String name )
    {
        edgeName = name;        
    }
    
    /** Sets name of source coordiante.
     *  @param sourceName               Name of source coordinate.
     */
    public void setSourceName( String sourceName )
    {
        this.sourceName = sourceName;        
    }
    
    /** Sets name of destination coordiante.
     *  @param destinationName          Name of destination coordinate.
     */
    public void setDestinationName( String destinationName )
    {
        this.destinationName = destinationName;        
    }
    
    /** Sets distance string of edge.
     *  @param distanceString           Distance string of edge.
     */
    public void setDistanceString( String distanceString )
    {
        this.distanceString = distanceString;       
        
        if ( distance != Double.parseDouble( this.distanceString ) )
            distance = Double.parseDouble( this.distanceString );
    }
    
    /** Sets x-coordinate of source point.
     *  @param x                        x-coordinate of source point.
     */
    public void setXSourceCoordinate( int x ) 
    { 
        sourceCoordinate[0] = new Integer( x );         
    }
    
    /** Sets y-coordinate of source point.
     *  @param y                        y-coordinate of source point.
     */
    public void setYSourceCoordinate( int y ) 
    { 
        sourceCoordinate[1] = new Integer( y );         
    }
    
    /** Sets x-coordinate of destination point.
     *  @param x                        x-coordinate of destination point.
     */
    public void setXDestinationCoordinate( int x )
    {
        destinationCoordinate[0] = new Integer( x );        
    }
    
    /** Sets y-coordinate of destination point.
     *  @param y                        y-coordinate of destination point.
     */
    public void setYDestinationCoordinate( int y )
    {
        destinationCoordinate[1] = new Integer( y );        
    }
    
    /** Sets xy-coordinate of source point.
     *  @param x                        x-coordinate of source point.
     *  @param y                        y-coordinate of source point.
     */
    public void setSourceCoordinate( int x, int y )
    {
        setXSourceCoordinate( x );  
        setYSourceCoordinate( y );
    }
    
    /** Sets xy-coordinate of source point.
     *  @param coordinate               xy-coordinate of source point.
     */
    public void setSourceCoordinate( int [] coordinate )
    {
        setSourceCoordinate( coordinate[0], coordinate[1] );
    }
    
    /** Sets xy-coordinate of destination point.
     *  @param x                        x-coordinate of destination point.
     *  @param y                        y-coordinate of destination point.
     */
    public void setDestinationCoordinate( int x, int y )
    {
        setXDestinationCoordinate( x );
        setYDestinationCoordinate( y );        
    }
    
    /** Sets xy-coordinate of destination point.
     *  @param coordinate               xy-coordinate of destination point.     
     */
    public void setDestinationCoordinate( int [] coordinate )
    {
        setDestinationCoordinate( coordinate[0], coordinate[1] );
    }
        
    /** Sets distnace value of edge.
     *  @param distance                 Distance value of edge.
     */
    public void setDistance( double distance )
    {
        this.distance = distance;
        setDistanceString( Double.toString( this.distance ) );
    }
    
    /** Gets name of edge.
     *  @return                         Name of edge.
     */
    public String getName() { return edgeName; }
    
    /** Gets name of source coordinate.
     *  @return                         Name of source coordinate.
     */
    public String getSourceName() { return sourceName; }
    
    /** Gets name of destination coordinate.
     *  @return                         Name of destination coordinate.
     */
    public String getDestinationName() { return destinationName; }
    
    /** Gets distance string of edge.
     *  @return                         Distance string of edge.
     */
    public String getDistanceString() { return distanceString; }
    
    /** Gets source x-coordinate of edge.
     *  @return                         Source x-coordinate of edge.
     */
    public int getXSourceCoordinate() { return sourceCoordinate[0].intValue(); }
    
    /** Gets source y-coordinate of edge.
     *  @return                         Source y-coordinate of edge.
     */
    public int getYSourceCoordinate() { return sourceCoordinate[1].intValue(); }
    
    /** Gets destination x-coordinate of edge.
     *  @return                         Destination x-coordinate of edge.
     */
    public int getXDestinationCoordinate() { return destinationCoordinate[0].intValue(); }
    
    /** Gets destination y-coordinate of edge.
     *  @return                         Destination y-coordinate of edge.
     */
    public int getYDestinationCoordinate() { return destinationCoordinate[1].intValue(); }
    
    /** Gets source xy-coordinate of edge.
     *  @return                         Source xy-coordinate of edge.
     */
    public int [] getSourceCoordinate() 
    { 
        int [] sourceCoordinate = { getXSourceCoordinate(), getYSourceCoordinate() };
        return sourceCoordinate;
    }
    
    /** Gets destination xy-coordinate of edge.
     *  @return                         Destination xy-coordinate of edge.
     */
    public int [] getDestinationCoordinate() 
    { 
        int [] destinationCoordinate = { getXDestinationCoordinate(), getYDestinationCoordinate() };
        return destinationCoordinate; 
    }
    
    /** Gets distance value of edge.
     *  @return                         Distance value of edge.
     */
    public double getDistance() { return distance; }            
}
