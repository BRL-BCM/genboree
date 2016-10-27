/*
 * Node.java
 *
 * Created on August 10, 2004, 10:22 AM
 */


package org.genboree.svgGraph;

import org.genboree.svgGraph.*;
import java.util.*;


/**
 *
 * @author Ming-Te Cheng
 */
public class Node {
    
    /** Name of the node. */
    protected String nodeName;
    
    /** xy-coordinate of node. */
    protected Integer [] coordinate = new Integer [2];
    
    /** List of nodes connected to this node. */
    protected ArrayList connectedNodesList = new ArrayList();
    
    /** List of edges connected from this node to its neighboring nodes */
    protected ArrayList connectedEdgesList = new ArrayList();
    
    /** Adds node connected to this node into list. 
     *  @param node                     Node connected to this node.
     *  @param edge                     Connected edge.
     */    
    public void addConnectedNode( Node node, Edge edge )
    {
        connectedNodesList.add( node );
        connectedEdgesList.add( edge );
    }
    
    /** Removes node connected to this node. 
     *  @param node                     Node connected to this node.     
     *  @param edge                     Connected edge.
     */
    public void removeConnectedNode( Node node, Edge edge )
    {
        connectedNodesList.remove( node );
        connectedEdgesList.remove( edge );
    }
    
    /** Gets list of nodes connected to this node. 
     *  @return                         List of nodes connected to this node.
     */
    public ArrayList getConnectedNodesList() { return connectedNodesList; }
    
    /** Gets list of edges connected to this node.
     *  @return                         List of edges connected to this node.
     */
    public ArrayList getConnectedEdgesList() { return connectedEdgesList; }
    
    /** Gets name of node from list of connected nodes.
     *  @param index                    Index number.
     *  @return                         Node name of connected node.
     */
    public String getConnectedNodeName( int index ) 
    { 
        return ( (Node)( connectedNodesList.get( index ) ) ).getName();
    }       
    
    /** Gets number of nodes connected to this node.
     *  @return                         Size of list of nodes connected to this node.
     */
    public int countConnectedNodes() { return connectedNodesList.size(); }     
    
    /** Gets number of edges connected to this node.
     *  @return                         Size of list of edges connected to this node.
     */
    public int countConnectedEdges() { return connectedEdgesList.size(); }     
    
    /** Determines whether node connected to this node exists.
     *  @param connectedNodeName        Requesting node name.
     *  @return                         Connected node exists.
     */
    public boolean connectedNodeExists( String connectedNodeName )
    {       
        for ( int i = 0; i < connectedNodesList.size(); i++ )
        {               
            if ( ( (Node)( connectedNodesList.get( i ) ) ).getName().equals( connectedNodeName ) )
                return true;
        }
        
        return false;
    }    
    
    /** Creates a new instance of Node. */
    public Node() {
        this( null );
    }      
    
    /** Creates a new instance of Node.
     *  @param name         Name of node.     
     */
    public Node( String name )
    {
        this( name, 0, 0 );    
    }
    
    /** Creates a new instance of Node.
     *  @param name         Name of node.
     *  @param coordinate   xy-coordinate of node.
     */
    public Node( String name, int [] coordinate )
    {
        this( name, coordinate[0], coordinate[1] );
    }
    
    /** Creates a new instance of Node. 
     *  @param name         Name of node.
     *  @param x            x-coordinate of node.
     *  @param y            y-coordinate of node.
     */
    public Node( String name, int x, int y )
    {       
        setName( name );
        setCoordinate( x, y );        
    }
    
    /** Sets name of node.
     *  @param name         Name of node.
     */
    public void setName( String name ) { nodeName = name; }
    
    /** Sets x-coordinate of node.     
     *  @param x            x-coordinate of node.
     */
    public void setXCoordinate( int x ) { this.coordinate[0] = new Integer( x ); }
    
    /** Sets y-coordinate of node.     
     *  @param y            y-coordinate of node.
     */
    public void setYCoordinate( int y ) { this.coordinate[1] = new Integer( y ); }
    
    /** Sets xy-coordinate of node.     
     *  @param x            x-coordinate of node.
     *  @param y            y-coordinate of node.
     */
    public void setCoordinate( int x, int y )
    {
        setXCoordinate( x );
        setYCoordinate( y );
    }
    
    /** Sets xy-coordinate of node.     
     *  @param coordinate   xy-coordinate of node.     
     */
    public void setCoordinate( int [] coordinate )
    {
        setCoordinate( coordinate[0], coordinate[1] );
    }
    
    /** Gets name of node.     
     *  @return             Name of node.
     */
    public String getName() { return nodeName; }
    
    /** Gets x-coordinate of node.     
     *  @return             x-coordinate of node.
     */
    public int getXCoordinate() { return coordinate[0].intValue(); }
    
    
    /** Gets y-coordinate of node.     
     *  @return             y-coordinate of node.
     */
    public int getYCoordinate() { return coordinate[1].intValue(); }
    
    
    /** Gets xy-coordinate of node.     
     *  @return             xy-coordinate of node.
     */
    public int [] getCoordinate()
    {
        int [] coordinate = { getXCoordinate(), getYCoordinate() };       
        return coordinate;
    }       
    
    
}
