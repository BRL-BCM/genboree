/*
 * GraphGenerator.java
 *
 * Created on August 10, 2004, 11:03 AM
 */

package org.genboree.svgGraph;

import org.genboree.svgGraph.*;
import java.util.*;
import java.io.*;


/**
 *
 * @author  Ming-Te Cheng
 */
public class GraphGenerator {
    
    /** Width of graph. */
    protected int width = 500;
    
    /** Height of graph. */
    protected int height = 500;    
    
    /** Contains list of nodes in graph. */
    protected ArrayList nodeList = new ArrayList();
    
    /** Contains list of edges in graph. */
    protected ArrayList edgeList = new ArrayList();        
    
    /** Output *.svg file. */
    protected File svgOutputFile;
    
    /** Writes output to *.svg file. */
    protected PrintWriter svgOutputFileWriter;
    
    /** Creates a new instance of GraphGenerator. */
    public GraphGenerator() {
    }
    
    /** Creates a new instance of GraphGenerator. 
     *  @param svgOutputFile                *.svg output file.     
     */
    public GraphGenerator( File svgOutputFile )
    {         
        openSVGOutputFile( svgOutputFile );
    }
    
    /** Creates a new instance of GraphGenerator. 
     *  @param svgOutputFile                *.svg output file.
     *  @param height                       Height of graph.
     *  @param width                        Width of graph.
     */
    public GraphGenerator( File svgOutputFile, int height, int width )
    {         
        openSVGOutputFile( svgOutputFile );
        this.height = height;
        this.width = width;
    }
    
    /** Opens *.svg output file for writing. 
     *  @param svgOutputFile                *.svg output file.
     */
    public void openSVGOutputFile( File svgOutputFile )
    {
        this.svgOutputFile = svgOutputFile;
       
        try {
            svgOutputFileWriter = new PrintWriter( new FileWriter( this.svgOutputFile ) );            
        }
        catch( Exception ex )
        {
            ex.printStackTrace();            
        }
    }
    
    /** Closes *.svg output file. */
    public void closeSVGOutputFile()
    {
        try {
            if ( this.svgOutputFileWriter != null )
            {   
                svgOutputFileWriter.close();
                svgOutputFileWriter = null;
            }
        }
        catch( Exception ex )
        {
            ex.printStackTrace();            
        }
    }
    
    /** Adds node to list of nodes and place it at default coordinate.
     *  @param nodeName                     Name of node to be added.
     */
    public void addNode( String nodeName )
    {       
        nodeList.add( new Node( nodeName ) );
    }       

    /** Removes node from list of nodes.
     *  @param nodeName                     Name of node to be removed.
     */
    public void removeNode( String nodeName )
    {
        // search entire list of nodes and find matching node name
        for ( int i = 0; i < nodeList.size(); i++ )
        {           
            if ( ( (Node) nodeList.get( i ) ).getName().equals( nodeName ) )
            {
                nodeList.remove( i );
                break;
            }
        }       	
    }
    
    /** Moves node from current coordinate to new coordinate.
     *  @param nodeName                     Name of node to be moved.
     *  @param x                            New x-coordinate.
     *  @param y                            New y-coordinate.
     */
    public void moveNode( String nodeName, int x, int y )
    {
        try
        {
            getNode( nodeName ).setCoordinate( x, y );
        }
        catch ( NullPointerException ex )
        { }            
    }   
    
    /** Moves node from current coordinate to new coordinate.
     *  @param nodeName                     Name of node to be moved.
     *  @param coordinate                   New xy-coordinate.     
     */
    public void moveNode( String nodeName, int [] coordinate )
    {
        moveNode( nodeName, coordinate[0], coordinate[1] );   
    }   
    
    /** Gets node from list of nodes.
     *  @param nodeName                     Name of node to be retrieved.
     *  @throws NullPointerException         Node to be retrieved cannot be found.
     */
    public Node getNode( String nodeName ) throws NullPointerException
    {
        // search entire list of nodes and find matching node name
        for ( int i = 0; i < nodeList.size(); i++ )
        {
            if ( ( (Node) nodeList.get( i ) ).getName().equals( nodeName ) )
                return (Node) nodeList.get( i );
        }
        
        throw new NullPointerException( "Node '" + nodeName + "' cannot be found." );        
    }   
    
    /** Gets node index value from list of nodes.
     *  @param nodeName                     Name of node whose index value is to be retrieved.
     *  @throws NullPointerException         Node cannot be found.
     *  @return                             Index number of node.
     */
    public int getNodeIndex( String nodeName )
    {
        // search entire list of nodes and find matching node name
        for ( int i = 0; i < nodeList.size(); i++ )
        {
            if ( ( (Node) nodeList.get( i ) ).getName().equals( nodeName ) )
                return i;
        }        
        
        throw new NullPointerException( "Node '" + nodeName + "' cannot be found." );        
    }
   
    /** Adds edge at specified coordinates.
     *  @param edgeName                     Name of edge to be added.
     *  @param xSource                      Source x-coordinate.
     *  @param ySource                      Source y-coordinate.
     *  @param xDestination                 Destination x-coordinate.
     *  @param yDestination                 Destination y-coordinate.
     *  @param distance                     Distance of edge.
     */
    public void addEdge( String edgeName, int xSource, int ySource, int xDestination, int yDestination, double distance )
    {
        edgeList.add( new Edge( edgeName, xSource, ySource, xDestination, yDestination, distance ) );        
    }
    
    /** Adds edge at specified coordinates.
     *  @param edgeName                     Name of edge to be added.
     *  @param sourceCoordinate             Source xy-coordinate.
     *  @param destinationCoordinate        Destination xy-coordinate.
     *  @param distance                     Distance of edge.
     */
    public void addEdge( String edgeName, int [] sourceCoordinate, int [] destinationCoordinate, double distance )
    {
        edgeList.add( new Edge( edgeName, sourceCoordinate, destinationCoordinate, distance ) );        
    }
    
    /** Adds edge at default cooordinates.
     *  @param edgeName                     Name of edge to be added.
     *  @param distance                     Distance of edge.
     */
    public void addEdge( String edgeName, double distance )
    {
        edgeList.add( new Edge( edgeName, distance ) );
    }
    
    /** Removes edge from list of edges.
     *  @param edgeName                     Name of edge to be removed.
     */
    public void removeEdge( String edgeName )
    {
        String [] splitEdgeName;
        StringBuffer inverseEdgeNameBuffer = new StringBuffer();       
                
        for ( int i = 0; i < edgeList.size(); i++ )
        {
            // find inverse edge name
            splitEdgeName = ( (Edge) edgeList.get(i) ).getName().split( "-" );
            inverseEdgeNameBuffer.setLength( 0 );
            inverseEdgeNameBuffer.append( createEdgeName( splitEdgeName[1], splitEdgeName[0] ) );
                        
            if ( ( (Edge) edgeList.get(i) ).getName().equals( edgeName ) == true ||
                 inverseEdgeNameBuffer.toString().equals( edgeName ) == true )
            {
                edgeList.remove(i);               
                break;
            }            
        }        
    }    

    /** Moves edge on graph.
     *  @param firstNode                    First Node of edge to be moved.
     *  @param secondNode                   Second Node of edge to be moved.
     *  @param sourceCoordinate             Source xy-coordinate.
     *  @param destinationCoordinate        Destination xy-coordinate.     
     */
    public void moveEdge( Node firstNode, Node secondNode, int [] sourceCoordinate, int [] destinationCoordinate )
    {        
        moveEdge( getEdge( firstNode.getName(), secondNode.getName() ),
            sourceCoordinate, destinationCoordinate );            
    }    
    
    /** Moves edge on graph.
     *  @param firstNode                    First Node of edge to be moved.
     *  @param secondNode                   Second Node of edge to be moved.
     *  @param xSourceCoordinate            Source x-coordinate.
     *  @param ySourceCoordinate            Source x-coordinate.
     *  @param xDestinationCoordinate       Destination x-coordinate.
     *  @param yDestinationCoordinate       Destination y-coordinate.       
     */
    public void moveEdge( Node firstNode, Node secondNode, int xSourceCoordinate, int ySourceCoordinate, 
        int xDestinationCoordinate, int yDestinationCoordinate )
    {        
        moveEdge( getEdge( firstNode.getName(), secondNode.getName() ),
            xSourceCoordinate, ySourceCoordinate, xDestinationCoordinate, yDestinationCoordinate );
    }

    /** Moves edge on graph.
     *  @param firstNodeName                Name of first node of edge to be moved.
     *  @param secondNodeName               Name of second Node of edge to be moved.
     *  @param sourceCoordinate             Source xy-coordinate.
     *  @param destinationCoordinate        Destination xy-coordinate.     
     */
    public void moveEdge( String firstNodeName, String secondNodeName, int [] sourceCoordinate, int [] destinationCoordinate )
    {        
        moveEdge( getEdge( firstNodeName, secondNodeName ),
            sourceCoordinate, destinationCoordinate );            
    }    
    
    /** Moves edge on graph.
     *  @param firstNodeName                Name of first node of edge to be moved.
     *  @param secondNodeName               Name of second Node of edge to be moved.
     *  @param xSourceCoordinate            Source x-coordinate.
     *  @param ySourceCoordinate            Source x-coordinate.
     *  @param xDestinationCoordinate       Destination x-coordinate.
     *  @param yDestinationCoordinate       Destination y-coordinate.      
     */
    public void moveEdge( String firstNodeName, String secondNodeName, int xSourceCoordinate, int ySourceCoordinate, 
        int xDestinationCoordinate, int yDestinationCoordinate )
    {        
        moveEdge( getEdge( firstNodeName, secondNodeName ),
            xSourceCoordinate, ySourceCoordinate, xDestinationCoordinate, yDestinationCoordinate );
    }
    
    /** Moves edge on graph.
     *  @param edge                         Edge to be moved.     
     *  @param sourceCoordinate             Source xy-coordinate.
     *  @param destinationCoordinate        Destination xy-coordinate.     
     */
    public void moveEdge( Edge edge, int [] sourceCoordinate, int [] destinationCoordinate )
    {        
        moveEdge( edge.getName(), sourceCoordinate[0], sourceCoordinate[1],
            destinationCoordinate[0], destinationCoordinate[1] );        
    }  
    
    /** Moves edge on graph.
     *  @param edge                         Edge to be moved.     
     *  @param xSourceCoordinate            Source x-coordinate.
     *  @param ySourceCoordinate            Source x-coordinate.
     *  @param xDestinationCoordinate       Destination x-coordinate.
     *  @param yDestinationCoordinate       Destination y-coordinate.     
     */
    public void moveEdge( Edge edge, int xSourceCoordinate, int ySourceCoordinate,
        int xDestinationCoordinate, int yDestinationCoordinate )
    {        
        moveEdge( edge.getName(), xSourceCoordinate, ySourceCoordinate,
            xDestinationCoordinate, yDestinationCoordinate );
    }      
    
    /** Moves edge on graph.
     *  @param edgeName                     Name of edge to be moved.
     *  @param sourceCoordinate             Source xy-coordinate.
     *  @param destinationCoordinate        Destination xy-coordinate.     
     */
    public void moveEdge( String edgeName, int [] sourceCoordinate, int [] destinationCoordinate )
    {
        moveEdge( edgeName, sourceCoordinate[0], sourceCoordinate[1],
            destinationCoordinate[0], destinationCoordinate[1] );        
    }
    
    /** Moves edge on graph.
     *  @param edgeName                     Name of edge to be moved.
     *  @param xSourceCoordinate            Source x-coordinate.
     *  @param ySourceCoordinate            Source x-coordinate.
     *  @param xDestinationCoordinate       Destination x-coordinate.
     *  @param yDestinationCoordinate       Destination y-coordinate.     
     */
    public void moveEdge( String edgeName, int xSourceCoordinate, int ySourceCoordinate,
        int xDestinationCoordinate, int yDestinationCoordinate )
    {
        String [] splitEdgeName;
        StringBuffer inverseEdgeNameBuffer = new StringBuffer();       
        int xSource = xSourceCoordinate;
        int ySource = ySourceCoordinate;
        int xDestination = xDestinationCoordinate;
        int yDestination = yDestinationCoordinate;
        
                
        for ( int i = 0; i < edgeList.size(); i++ )
        {
            // find inverse edge name
            splitEdgeName = ( (Edge) edgeList.get(i) ).getName().split( "-" );
            inverseEdgeNameBuffer.setLength( 0 );
            inverseEdgeNameBuffer.append( createEdgeName( splitEdgeName[1], splitEdgeName[0] ) );
                        
            if ( ( (Edge) edgeList.get(i) ).getName().equals( edgeName ) == true )
            {
                ( (Edge) edgeList.get(i) ).setSourceCoordinate( xSource, ySource );
                ( (Edge) edgeList.get(i) ).setDestinationCoordinate( xDestination, yDestination );
                break;
            }
            else if ( inverseEdgeNameBuffer.toString().equals( edgeName ) == true )
            {
                getEdge( inverseEdgeNameBuffer.toString() ).setSourceCoordinate( xSource, ySource );
                getEdge( inverseEdgeNameBuffer.toString() ).setDestinationCoordinate( xDestination, yDestination );
                break;
            }            
        }                
    }
    
    /** Gets edge from list of edges.
     *  @param edgeName                     Name of edge to be retrieved.
     *  @throws NullPointerException         Node to be retrieved cannot be found.
     */
    public Edge getEdge( String edgeName ) throws NullPointerException
    {                        
        // find inverse edge name
        String [] splitEdgeName = edgeName.split( "-" );        
        StringBuffer inverseEdgeNameBuffer = 
            new StringBuffer( createEdgeName( splitEdgeName[1], splitEdgeName[0] ));        
                
        for ( int i = 0; i < edgeList.size(); i++ )
        {
            if ( ( (Edge) edgeList.get(i) ).getName().equals( edgeName ) ||
                 ( (Edge) edgeList.get(i) ).getName().equals( inverseEdgeNameBuffer.toString() ) )
                return (Edge)( edgeList.get(i) );
        }               
        
        throw new NullPointerException( "Edge '" + edgeName + "' cannot be found." );
    }
    
    /** Gets edge from list of edges.
     *  @param nodeName1                    Name of first node of edge.
     *  @param nodeName2                    Name of second node of edge.
     *  @throws NullPointerException         Node to be retrieved cannot be found.
     */
    public Edge getEdge( String nodeName1, String nodeName2 ) throws NullPointerException
    {        
        return getEdge( createEdgeName( nodeName1, nodeName2 ) );
    }
    
    /** Gets edge from list of edges.
     *  @param node1                        First node of edge.
     *  @param node2                        Second node of edge.
     *  @throws NullPointerException         Node to be retrieved cannot be found.
     */
    public Edge getEdge( Node node1, Node node2 ) throws NullPointerException
    {        
        return getEdge( createEdgeName( node1.getName(), node2.getName() ) );
    }
    
    /** Gets edge from list of edges.
     *  @param edge                         Edge to be retrieved.     
     *  @throws NullPointerException         Node to be retrieved cannot be found.
     */
    public Edge getEdge( Edge edge ) throws NullPointerException
    {        
        return getEdge( edge.getName() );
    }
    
    /** Connects nodes with edges.
     *  @param sourceNode                   Node to be connected from.
     *  @param destinationNode              Node to be connected to.
     *  @param distance                     Distance value of connection.
     */
    public void connectNodes( Node sourceNode, Node destinationNode, double distance )
    {                        
        connectNodes( sourceNode.getName(), destinationNode.getName(), distance );
    }
    
    /** Connects nodes with edges.
     *  @param sourceNodeName               Name of node to be connected from.
     *  @param destinationNodeName          Name of node to be connected to.
     *  @param distance                     Distance value of connection.
     */
    public void connectNodes( String sourceNodeName, String destinationNodeName, double distance )
    {                        
        StringBuffer edgeNameBuffer = new StringBuffer();
        
        try
        {   
            edgeNameBuffer.append( createEdgeName( sourceNodeName, destinationNodeName ) );
            
            addEdge( edgeNameBuffer.toString(), distance );
            
            getNode( sourceNodeName ).addConnectedNode( 
                getNode( destinationNodeName ), 
                getEdge( edgeNameBuffer.toString() )
                );
            getNode( destinationNodeName ).addConnectedNode( 
                getNode( sourceNodeName ),
                getEdge( edgeNameBuffer.toString() )
                );
        }
        catch ( NullPointerException ex ) // source or destination node's not found
        {
            System.out.println( ex.toString() );
        }
    }        
    
    /** Detaches connection between specified nodes.
     *  @param nodeName1                    Name of first node.
     *  @param nodeName2                    Name of second node.
     */
    public void detachNodes( String nodeName1, String nodeName2 )
    {
        StringBuffer edgeNameBuffer = new StringBuffer();
        
        try
        {
            edgeNameBuffer.append( createEdgeName( nodeName1, nodeName2 ) );
            
            getNode( nodeName1 ).removeConnectedNode( 
                getNode( nodeName2 ), 
                getEdge( edgeNameBuffer.toString() ) 
                );
            getNode( nodeName2 ).removeConnectedNode( 
                getNode( nodeName1 ), 
                getEdge( edgeNameBuffer.toString() )
                );
            
            removeEdge( edgeNameBuffer.toString() );
        }
        catch ( NullPointerException ex ) // source or destination node's not found
        {
            System.out.println( ex.toString() );
        }      
        
    }
    
    /** Detaches connection between specified nodes.
     *  @param node1                         First node.
     *  @param node2                         Second node.
     */
    public void detachNodes( Node node1, Node node2 )
    {        
        detachNodes( node1.getName(), node2.getName() );
    }
          
    /** Creates edge name.
     *  @param node1                        First node.
     *  @param node2                        Second node.
     *  @return                             Edge name.
     */
    public String createEdgeName( Node node1, Node node2 )
    {        
        return createEdgeName( node1.getName(), node2.getName() );
    }
    
    /** Creates edge name
     *  @param nodeName1                    Name of first node.
     *  @param nodeName2                    Name of second node.
     *  @return                             Edge name.
     */
    public String createEdgeName( String nodeName1, String nodeName2 )
    {
        StringBuffer edgeNameBuffer = new StringBuffer();
        edgeNameBuffer.append( nodeName1 );
        edgeNameBuffer.append( "-" );
        edgeNameBuffer.append( nodeName2 );
        
        return edgeNameBuffer.toString();
    }
        
    /** Clears list of nodes and edges. */
    public void clearAllLists()
    {
        clearNodeList();
        clearEdgeList();
    }    
    
    /** Clears list of nodes. */
    public void clearNodeList() { nodeList.clear(); }
    
    /** Gets list of nodes.
     *  @return                             List of nodes.
     */
    public ArrayList getNodeList() { return nodeList; }
    
    /** Clears list of edges. */
    public void clearEdgeList() { edgeList.clear(); }
        
    /** Gets list of edges.
     *  @return                             List of edges.
     */
    public ArrayList getEdgeList() { return edgeList; }
    
    /** Generates *.svg output graph file. */
    public void generateGraph()
    {   
        setToDefault();
        arrangeElements();
        
        openSVGOutputFile( svgOutputFile );
        
        StringBuffer edgeNameBuffer = new StringBuffer();
        StringBuffer edgeDistanceBuffer = new StringBuffer();
        
        try
        {            
            // write "header" of svg file.
            svgOutputFileWriter.println( "<?xml version=\"1.0\" standalone=\"no\"?>" );
            svgOutputFileWriter.print( "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 20000802//EN\" " );
            svgOutputFileWriter.println( "\"http://www.w3.org/TR/2000/CR-SVG-20000802/DTD/svg-20000802.dtd\">" );
            svgOutputFileWriter.println( "" );
            svgOutputFileWriter.println( "<svg width=\"" + width + "\" height=\"" + height + "\" onload=\"LoadHandler(evt)\">" );
            svgOutputFileWriter.println( "" );           

            // transpose to center of graph.
            svgOutputFileWriter.println( "<g transform=\"translate( " + ( width / 2 ) + ", " + ( height / 2 ) + " )\">");
            
            // draw edges
            svgOutputFileWriter.println( "  <g style=\"stroke:grey;fill:none;stroke-width:1.0;\">" );
            for ( int i = 0; i < edgeList.size(); i++ )
            {                
                int xSourceCoordinate = ( (Edge) edgeList.get( i ) ).getXSourceCoordinate();
                int ySourceCoordinate = ( (Edge) edgeList.get( i ) ).getYSourceCoordinate();                
                int xDestinationCoordinate = ( (Edge) edgeList.get( i ) ).getXDestinationCoordinate();
                int yDestinationCoordinate = ( (Edge) edgeList.get( i ) ).getYDestinationCoordinate();
                int xEdgeLabelCoordinate = Math.abs( xDestinationCoordinate - xSourceCoordinate ) / 2 + 
                    Math.min( xSourceCoordinate, xDestinationCoordinate );
                int yEdgeLabelCoordinate = Math.abs( yDestinationCoordinate - ySourceCoordinate ) / 2 +
                    Math.min( ySourceCoordinate, yDestinationCoordinate );
                edgeNameBuffer.setLength( 0 );                
                edgeNameBuffer.append( ( (Edge) edgeList.get( i ) ).getName() );
                edgeNameBuffer.append( " : " );
                edgeDistanceBuffer.setLength( 0 );
                edgeDistanceBuffer.append( "Distance= " );
                edgeDistanceBuffer.append( ( (Edge) edgeList.get( i ) ).getDistance() );
                                
                svgOutputFileWriter.println( "    <line " +
                    "x1=\"" + xSourceCoordinate + "\" " +
                    "y1=\"" + ySourceCoordinate + "\" " +
                    "x2=\"" + xDestinationCoordinate + "\" " +
                    "y2=\"" + yDestinationCoordinate + "\" " +
                    ">"
                    );
                svgOutputFileWriter.println( "      <title>" 
                    + edgeNameBuffer.toString()
                    + edgeDistanceBuffer.toString()
                    + "</title>" );
                svgOutputFileWriter.println( "    </line>" );
                
                if ( ( xDestinationCoordinate > xSourceCoordinate && yDestinationCoordinate < ySourceCoordinate ) ||
                     ( xDestinationCoordinate < xSourceCoordinate && yDestinationCoordinate > ySourceCoordinate ) )
                {
                    xEdgeLabelCoordinate += ( Math.max( xSourceCoordinate, xDestinationCoordinate ) - xEdgeLabelCoordinate ) / 10;
                    yEdgeLabelCoordinate += ( Math.min( ySourceCoordinate, yDestinationCoordinate ) - yEdgeLabelCoordinate ) / 10;
                    
                    svgOutputFileWriter.println( "    <text " +
                        "x=\"" + xEdgeLabelCoordinate + "\" " +
                        "y=\"" + yEdgeLabelCoordinate + "\" " +
                        "style=\"text-anchor:right;font-style:italic;fill:black;stroke:black;\" >"
                        );
                    svgOutputFileWriter.println( "      " + ( (Edge) edgeList.get( i ) ).getDistance() );
                    svgOutputFileWriter.println( "      <title>" 
                        + edgeNameBuffer.toString()
                        + edgeDistanceBuffer.toString()
                        + "</title>" );                    
                    svgOutputFileWriter.println( "    </text>" );                                                     
                }
                else
                {
                    if ( ( xDestinationCoordinate > xSourceCoordinate && yDestinationCoordinate > ySourceCoordinate ) ||
                         ( xDestinationCoordinate < xSourceCoordinate && yDestinationCoordinate < ySourceCoordinate ) )
                    {
                        xEdgeLabelCoordinate += ( Math.max( xSourceCoordinate, xDestinationCoordinate ) - xEdgeLabelCoordinate ) / 10;
                        yEdgeLabelCoordinate += ( Math.max( ySourceCoordinate, yDestinationCoordinate ) - yEdgeLabelCoordinate ) / 10;
                    }
                    
                    svgOutputFileWriter.println( "    <text " +
                        "x=\"" + xEdgeLabelCoordinate + "\" " +
                        "y=\"" + yEdgeLabelCoordinate + "\" " +
                        "style=\"text-anchor:left;font-style:italic;fill:black;stroke:black;\" >" 
                        );
                    svgOutputFileWriter.println( "      " + ( (Edge) edgeList.get( i ) ).getDistance() );
                    svgOutputFileWriter.println( "      <title>" 
                        + edgeNameBuffer.toString()
                        + edgeDistanceBuffer.toString()
                        + "</title>" );                    
                    svgOutputFileWriter.println( "    </text>" );                    
                }                
            }
            svgOutputFileWriter.println( "  </g>" );
            
            svgOutputFileWriter.println( "" );
            
            // draw nodes
            svgOutputFileWriter.println( "  <g style=\"stroke:black;fill:white;stroke-width:1.0;" + "\">" );
            for ( int i = 0; i < nodeList.size(); i++ )
            {
                int xCoordinate = ( (Node) nodeList.get( i ) ).getXCoordinate();
                int yCoordinate = ( (Node) nodeList.get( i ) ).getYCoordinate();
                
                svgOutputFileWriter.println( "    <circle " +
                    "cx=\"" + xCoordinate + "\" " +
                    "cy=\"" + yCoordinate + "\" " +
                    "r=\"20\" />" 
                    );                
                svgOutputFileWriter.println( "    <text " +
                    "x=\"" + xCoordinate + "\" " +
                    "y=\"" + yCoordinate + "\" " +
                    "style=\"text-anchor:middle;fill:black;stroke:black;\" >" );
                svgOutputFileWriter.println( "      " + ( (Node) nodeList.get( i ) ).getName() );
                svgOutputFileWriter.println( "      <title>" 
                    + ( (Node) nodeList.get( i ) ).getName()                    
                    + "</title>" );     
                svgOutputFileWriter.println( "    </text>" );                    
            }
            svgOutputFileWriter.println( "  </g>" );
            svgOutputFileWriter.println( "" );
            svgOutputFileWriter.println( "</g>" );
            svgOutputFileWriter.println( "" );
            
            svgOutputFileWriter.println( "<script xlink:href=\"Title.js\" />" );
            svgOutputFileWriter.println( "<script><![CDATA[" );
            svgOutputFileWriter.println( "function LoadHandler(event)" );
            svgOutputFileWriter.println( "{" );
            svgOutputFileWriter.println( "  new Title(event.getTarget().getOwnerDocument(), 12);" );
            svgOutputFileWriter.println( "}" );
            svgOutputFileWriter.println( "]]></script>" );
            
            
            // write "footer" of svg file.
            svgOutputFileWriter.println( "</svg>" );
        }
        catch( Exception ex )
        {
            ex.printStackTrace();
        }        
        
        closeSVGOutputFile();
    }
    
    /** Arranges all edges' and nodes' xy-coordinates */
    public void arrangeElements()
    {              
        // xy-coordinate buffers
        double [] v = { 0.0, 0.0 };
        double [] newCoordinate = { 0.0, 0.0 };
        
        // node and edge buffers
	Node referenceNode = null;
        Node currentNode = null;
        Node previousNode = null;
        Edge currentEdge = null;               
                        
        double nodeAngle = 0.0;
        double deltaX = 0.0;
        double deltaY = 0.0; 
        double distance = 0.0;               
        
        // make adjustments
        // assume that length of edge - 1 = number of nodes skipped
        // ex: distance of 2 = one node was skipped
        ArrayList leftNodesList = new ArrayList();
        ArrayList rightNodesList = new ArrayList();
        
        for ( int i = 0; i < edgeList.size(); i++ )
        {                           
            currentEdge = (Edge)( edgeList.get(i) );            
            leftNodesList.clear();
            rightNodesList.clear();
            int leftNodesCounter = 0;
            int rightNodesCounter = 0;            
            double angleToXAxis = 0.0;
            
            int idx = getNodeIndex( currentEdge.getSourceName() );            
            leftNodesList.add( getNode( currentEdge.getSourceName() ) );
            while ( idx != getNodeIndex( currentEdge.getDestinationName() ) )
            {
                leftNodesCounter++;                
                
                idx--;
                if ( idx < 0 )
                    idx = nodeList.size() - 1;                
                
                leftNodesList.add( getNode( ( (Node)( nodeList.get(idx) ) ).getName() ) );
            }
                                    
            idx = getNodeIndex( currentEdge.getSourceName() );
            rightNodesList.add( getNode( currentEdge.getSourceName() ) );
            while ( idx != getNodeIndex( currentEdge.getDestinationName() ) )
            {
                rightNodesCounter++;
                
                idx = ( idx + 1 ) % nodeList.size();
                
                rightNodesList.add( getNode( ( (Node)( nodeList.get(idx) ) ).getName() ) );
            }            
                        
            int numNodesSkipped = Math.min( leftNodesCounter, rightNodesCounter ) - 1;
                        
            if ( Math.round( currentEdge.getDistance() ) - 1 != numNodesSkipped )
            {               
                if ( currentEdge.getDestinationCoordinate()[1] == currentEdge.getSourceCoordinate()[1] )
                {
                    if ( currentEdge.getDestinationCoordinate()[0] > currentEdge.getSourceCoordinate()[0] )
                        angleToXAxis = 0;
                    else
                        angleToXAxis = Math.PI;
                }
                else if ( currentEdge.getDestinationCoordinate()[0] == currentEdge.getSourceCoordinate()[0] )
                {
                    if ( currentEdge.getDestinationCoordinate()[1] > currentEdge.getSourceCoordinate()[1] )
                        angleToXAxis = Math.PI / 2;
                    else
                        angleToXAxis = 3 * Math.PI / 2;                    
                }
                else                          
                {
                    deltaX = currentEdge.getDestinationCoordinate()[0] - currentEdge.getSourceCoordinate()[0];
                    deltaY = currentEdge.getDestinationCoordinate()[1] - currentEdge.getSourceCoordinate()[1];
                  
                    angleToXAxis = Math.atan( deltaY / deltaX );
                }                
                
                rotateAll( angleToXAxis, ( (Node)( nodeList.get(0) ) ).getCoordinate() );                
                
                if ( currentEdge.getXSourceCoordinate() < currentEdge.getXDestinationCoordinate() )
                {                 
                    rotateAll( Math.PI, ( (Node)( nodeList.get(0) ) ).getCoordinate() );    
                }
                
                currentEdge.setXSourceCoordinate( (int)(
                    currentEdge.getXSourceCoordinate() +
                    ( ( currentEdge.getDistance() - 1 - numNodesSkipped ) * 100 ) / 2 )
                    );

                currentEdge.setXDestinationCoordinate( (int)(
                    currentEdge.getXDestinationCoordinate() -
                    ( ( currentEdge.getDistance() - 1 - numNodesSkipped ) * 100 ) / 2 )
                    );
                
                getNode( currentEdge.getSourceName() ).setCoordinate( currentEdge.getSourceCoordinate() );
                getNode( currentEdge.getDestinationName() ).setCoordinate( currentEdge.getDestinationCoordinate() );                                
            
                
                nodeAngle = 0.0;
                deltaX = 0.0;
                deltaY = 0.0; 
                distance = 0.0;                                                            
                
                for ( int j = 1; j < leftNodesList.size() / 2; j++ )
                {                       
                    deltaX = ( (Node)( leftNodesList.get(j) ) ).getXCoordinate() - 
                             ( (Node)( leftNodesList.get(j-1) ) ).getXCoordinate();
                    deltaY = ( (Node)( leftNodesList.get(j) ) ).getYCoordinate() -
                             ( (Node)( leftNodesList.get(j-1) ) ).getYCoordinate(); 
                    
                    if ( deltaY == 0 )
                    {
                        if ( deltaX < 0 )
                            nodeAngle = Math.PI;
                        else
                            nodeAngle = 0;                        
                    }
                    else if ( deltaX == 0 )
                    {
                        if ( deltaY < 0 )
                            nodeAngle = Math.PI / 2;
                        else
                            nodeAngle = 3 * Math.PI / 2;
                    }
                    else
                        nodeAngle = Math.atan( deltaY / deltaX ) / ( leftNodesList.size() - 1 - j );                    
                    
                    distance = Math.sqrt( Math.pow( deltaX, 2 ) + Math.pow( deltaY, 2 ) );                                                                                                                        
                    
                    if ( Math.round( currentEdge.getDistance() ) - 1 >= numNodesSkipped )
                    {                            
                        ( (Node)( leftNodesList.get(j) ) ).setXCoordinate( (int)(
                            ( (Node)( leftNodesList.get(j) ) ).getXCoordinate() +
                            distance * Math.cos( nodeAngle ) / ( j + 1 )
                            ) );                 
                            
                        ( (Node)( leftNodesList.get(j) ) ).setYCoordinate( (int)(
                           ( (Node)( leftNodesList.get(j) ) ).getYCoordinate() +
                           distance * Math.sin( nodeAngle ) / ( j + 1 )
                           ) );                         
                    }
                    else
                    {                                                   
                        ( (Node)( leftNodesList.get(j) ) ).setXCoordinate( (int)(
                            ( (Node)( leftNodesList.get(j) ) ).getXCoordinate() -
                            distance * Math.cos( nodeAngle ) / ( j + 1 )
                            ) );
                                                                           
                        ( (Node)( leftNodesList.get(j) ) ).setYCoordinate( (int)(
                            ( (Node)( leftNodesList.get(j) ) ).getYCoordinate() -
                            distance * Math.sin( nodeAngle ) / ( j + 1 )
                            ) );
                    }                    
                    try
                    {
                        moveEdge( ( (Node)( leftNodesList.get(j-1) ) ), 
                                  ( (Node)( leftNodesList.get(j) ) ),
                                  ( (Node)( leftNodesList.get(j-1) ) ).getCoordinate(),
                                  ( (Node)( leftNodesList.get(j) ) ).getCoordinate() );                        
                    }
                    catch ( NullPointerException e ) { }                    
                }                
               
                int leftLimit; 
                if ( leftNodesList.size() % 2 == 0 )
                    leftLimit = leftNodesList.size() / 2 - 1;
                else
                    leftLimit = leftNodesList.size() / 2;
                
                for ( int j = leftNodesList.size() - 2; j > leftLimit; j-- )
                {                                             
                    deltaX = ( (Node)( leftNodesList.get(j) ) ).getXCoordinate() -
                             ( (Node)( leftNodesList.get(j+1) ) ).getXCoordinate();
                    deltaY = ( (Node)( leftNodesList.get(j) ) ).getYCoordinate() -
                             ( (Node)( leftNodesList.get(j+1) ) ).getYCoordinate();                   
                    
                    if ( deltaY == 0 )
                    {
                        if ( deltaX < 0 )
                            nodeAngle = Math.PI;
                        else
                            nodeAngle = 0;                        
                    }
                    else if ( deltaX == 0 )
                    {
                        if ( deltaY < 0 )
                            nodeAngle = Math.PI / 2;
                        else
                            nodeAngle = 3 * Math.PI / 2;
                    }
                    else
                        nodeAngle = Math.atan( deltaY / deltaX ) / j;                    
                                                            
                    distance = Math.sqrt( Math.pow( deltaX, 2 ) + Math.pow( deltaY, 2 ) );                                  
                    
                    if ( Math.round( currentEdge.getDistance() ) - 1 >= numNodesSkipped )
                    {                            
                        ( (Node)( leftNodesList.get(j) ) ).setXCoordinate( (int)(
                            ( (Node)( leftNodesList.get(j) ) ).getXCoordinate() -
                            distance * Math.cos( nodeAngle ) / ( leftNodesList.size() - j )
                            ) ); 
                                                        
                        ( (Node)( leftNodesList.get(j) ) ).setYCoordinate( (int)(
                            ( (Node)( leftNodesList.get(j) ) ).getYCoordinate() -
                            distance * Math.sin( nodeAngle ) / ( leftNodesList.size() - j )
                            ) );
                    }                    
                    else
                    {
                        ( (Node)( leftNodesList.get(j) ) ).setXCoordinate( (int)(
                            ( (Node)( leftNodesList.get(j) ) ).getXCoordinate() +
                            distance * Math.cos( nodeAngle ) / ( leftNodesList.size() - j )
                            ) ); 
                                                        
                        ( (Node)( leftNodesList.get(j) ) ).setYCoordinate( (int)(
                            ( (Node)( leftNodesList.get(j) ) ).getYCoordinate() -
                            distance * Math.sin( nodeAngle ) / ( leftNodesList.size() - j )
                            ) );
                    }                        
                    try
                    {
                        moveEdge( ( (Node)( leftNodesList.get(j) ) ), 
                                  ( (Node)( leftNodesList.get(j+1) ) ),
                                  ( (Node)( leftNodesList.get(j) ) ).getCoordinate(),
                                  ( (Node)( leftNodesList.get(j+1) ) ).getCoordinate() );
                    }
                    catch ( NullPointerException e ) { }                    
                }
                
                moveEdge( ( (Node)( leftNodesList.get( leftNodesList.size() / 2 - 1 ) ) ), 
                          ( (Node)( leftNodesList.get( leftNodesList.size() / 2 ) ) ),
                          ( (Node)( leftNodesList.get( leftNodesList.size() / 2 - 1 ) ) ).getCoordinate(),
                          ( (Node)( leftNodesList.get( leftNodesList.size() / 2 ) ) ).getCoordinate() );                        
                
                
                rotateAll( Math.PI, ( (Node)( nodeList.get(0) ) ).getCoordinate() );
                nodeAngle = 0.0;
                deltaX = 0.0;
                deltaY = 0.0; 
                distance = 0.0;
                
                for ( int j = 1; j < rightNodesList.size() / 2; j++ )
                {                       
                    deltaX = ( (Node)( rightNodesList.get(j) ) ).getXCoordinate() - 
                             ( (Node)( rightNodesList.get(j-1) ) ).getXCoordinate();
                    deltaY = ( (Node)( rightNodesList.get(j) ) ).getYCoordinate() -
                             ( (Node)( rightNodesList.get(j-1) ) ).getYCoordinate(); 
                    
                    if ( deltaY == 0 )
                    {
                        if ( deltaX < 0 )
                            nodeAngle = Math.PI;
                        else
                            nodeAngle = 0;                        
                    }
                    else if ( deltaX == 0 )
                    {
                        if ( deltaY < 0 )
                            nodeAngle = Math.PI / 2;
                        else
                            nodeAngle = 3 * Math.PI / 2;
                    }
                    else
                        nodeAngle = Math.atan( deltaY / deltaX ) / ( rightNodesList.size() - 1 - j );                    
                    
                    distance = Math.sqrt( Math.pow( deltaX, 2 ) + Math.pow( deltaY, 2 ) );                                                                                                                        
                    
                    if ( Math.round( currentEdge.getDistance() ) - 1 >= numNodesSkipped )
                    {                            
                        ( (Node)( rightNodesList.get(j) ) ).setXCoordinate( (int)(
                            ( (Node)( rightNodesList.get(j) ) ).getXCoordinate() +
                            distance * Math.cos( nodeAngle ) / ( j + 1 )
                            ) );                        
                            
                        ( (Node)( rightNodesList.get(j) ) ).setYCoordinate( (int)(
                           ( (Node)( rightNodesList.get(j) ) ).getYCoordinate() +
                           distance * Math.sin( nodeAngle ) / ( j + 1 )
                           ) );                         
                    }
                    else
                    {                                                   
                        ( (Node)( rightNodesList.get(j) ) ).setXCoordinate( (int)(
                            ( (Node)( rightNodesList.get(j) ) ).getXCoordinate() -
                            distance * Math.cos( nodeAngle ) / ( j + 1 )
                            ) );                        
                        ( (Node)( rightNodesList.get(j) ) ).setYCoordinate( (int)(
                            ( (Node)( rightNodesList.get(j) ) ).getYCoordinate() -
                            distance * Math.sin( nodeAngle ) / ( j + 1 )
                            ) );
                    }                    
                    try
                    {
                        moveEdge( ( (Node)( rightNodesList.get(j-1) ) ), 
                                  ( (Node)( rightNodesList.get(j) ) ),
                                  ( (Node)( rightNodesList.get(j-1) ) ).getCoordinate(),
                                  ( (Node)( rightNodesList.get(j) ) ).getCoordinate() );                        
                    }
                    catch ( NullPointerException e ) { }                    
                }                
               
                int rightLimit; 
                if ( rightNodesList.size() % 2 == 0 )
                    rightLimit = rightNodesList.size() / 2 - 1;
                else
                    rightLimit = rightNodesList.size() / 2;
                
                for ( int j = rightNodesList.size() - 2; j > rightLimit; j-- )
                {                                             
                    deltaX = ( (Node)( rightNodesList.get(j) ) ).getXCoordinate() -
                             ( (Node)( rightNodesList.get(j+1) ) ).getXCoordinate();
                    deltaY = ( (Node)( rightNodesList.get(j) ) ).getYCoordinate() -
                             ( (Node)( rightNodesList.get(j+1) ) ).getYCoordinate();                   
                    
                    if ( deltaY == 0 )
                    {
                        if ( deltaX < 0 )
                            nodeAngle = Math.PI;
                        else
                            nodeAngle = 0;                        
                    }
                    else if ( deltaX == 0 )
                    {
                        if ( deltaY < 0 )
                            nodeAngle = Math.PI / 2;
                        else
                            nodeAngle = 3 * Math.PI / 2;
                    }
                    else
                        nodeAngle = Math.atan( deltaY / deltaX ) / j;                    
                                                            
                    distance = Math.sqrt( Math.pow( deltaX, 2 ) + Math.pow( deltaY, 2 ) );                                  
                    
                    if ( Math.round( currentEdge.getDistance() ) - 1 >= numNodesSkipped )
                    {                            
                        ( (Node)( rightNodesList.get(j) ) ).setXCoordinate( (int)(
                            ( (Node)( rightNodesList.get(j) ) ).getXCoordinate() -
                            distance * Math.cos( nodeAngle ) / ( rightNodesList.size() - j )
                            ) ); 
                                                        
                        ( (Node)( rightNodesList.get(j) ) ).setYCoordinate( (int)(
                            ( (Node)( rightNodesList.get(j) ) ).getYCoordinate() -
                            distance * Math.sin( nodeAngle ) / ( rightNodesList.size() - j )
                            ) );
                    }                    
                    else
                    {
                        ( (Node)( rightNodesList.get(j) ) ).setXCoordinate( (int)(
                            ( (Node)( rightNodesList.get(j) ) ).getXCoordinate() +
                            distance * Math.cos( nodeAngle ) / ( rightNodesList.size() - j )
                            ) ); 
                                                        
                        ( (Node)( rightNodesList.get(j) ) ).setYCoordinate( (int)(
                            ( (Node)( rightNodesList.get(j) ) ).getYCoordinate() -
                            distance * Math.sin( nodeAngle ) / ( rightNodesList.size() - j )
                            ) );
                    }                        
                    try
                    {
                        moveEdge( ( (Node)( rightNodesList.get(j) ) ), 
                                  ( (Node)( rightNodesList.get(j+1) ) ),
                                  ( (Node)( rightNodesList.get(j) ) ).getCoordinate(),
                                  ( (Node)( rightNodesList.get(j+1) ) ).getCoordinate() );
                    }
                    catch ( NullPointerException e ) { }                    
                }                
                 
                
                moveEdge( ( (Node)( rightNodesList.get( rightNodesList.size() / 2 - 1 ) ) ), 
                          ( (Node)( rightNodesList.get( rightNodesList.size() / 2 ) ) ),
                          ( (Node)( rightNodesList.get( rightNodesList.size() / 2 - 1 ) ) ).getCoordinate(),
                          ( (Node)( rightNodesList.get( rightNodesList.size() / 2 ) ) ).getCoordinate() );
                
                //rotateAll( -1 * angleToXAxis, ( (Node)( nodeList.get(0) ) ).getCoordinate() );
            }           
        }
        
        // move edges to correct coordinates
        for ( int i = 0; i < edgeList.size(); i++ )
        {
            currentEdge = (Edge)( edgeList.get(i) );
            
            moveEdge( currentEdge, 
                getNode( currentEdge.getSourceName() ).getCoordinate(),
                getNode( currentEdge.getDestinationName() ).getCoordinate() );
        }
        
        centerAll();        
    }
    
    public void rotateAll( double angle, int [] ref )
    {
        Node currentNode = null;
        Edge currentEdge = null;
        
        double [] v = { 0, 0 };
   
        for ( int i = 0; i < nodeList.size(); i++ )
        {
            currentNode = (Node)( nodeList.get(i) );
            
            v[0] = (double)( currentNode.getXCoordinate() - ref[0] );
            v[1] = (double)( currentNode.getYCoordinate() - ref[1] );
            v[0] = Math.cos( angle ) * ( currentNode.getXCoordinate() - ref[0] ) + 
                   Math.sin( angle ) * ( currentNode.getYCoordinate() - ref[1] ); 
            v[1] = ( -1 * Math.sin( angle ) ) * ( currentNode.getXCoordinate() - ref[0] ) +
                   Math.cos( angle ) * ( currentNode.getYCoordinate() - ref[1] );
            v[0] += ref[0];
            v[1] += ref[1];
            currentNode.setCoordinate( (int)( v[0] ), (int)( v[1] ) );
        }
        for ( int i = 0; i < edgeList.size(); i++ )
        {
            currentEdge = (Edge)( edgeList.get(i) );
            
            moveEdge( currentEdge, 
                getNode( currentEdge.getSourceName() ).getCoordinate(),
                getNode( currentEdge.getDestinationName() ).getCoordinate() );
        }                    
    }
    
    public void centerAll()
    {
        // shifting values
        int shiftX = 0;
        int shiftY = 0;
        
        // middle point values
        int middleX = 0;
        int middleY = 0;
        
        int highestX = 0;
        int lowestX = 0;
        int highestY = 0;
        int lowestY = 0;
        
        Node currentNode = null;
        Edge currentEdge = null;
        
        // shift elements to center of graph
        for ( int i = 0; i < nodeList.size(); i++ )
        {
            currentNode = (Node)( nodeList.get(i) );
            
            if ( i == 0 )
            {
                highestX = currentNode.getXCoordinate();
                highestY = currentNode.getYCoordinate();
            
                lowestX = currentNode.getXCoordinate();
                lowestY = currentNode.getYCoordinate();                                        
            }
            else
            {
                highestX = Math.max( highestX, currentNode.getXCoordinate() );
                highestY = Math.max( highestY, currentNode.getYCoordinate() );
            
                lowestX = Math.min( lowestX, currentNode.getXCoordinate() );
                lowestY = Math.min( lowestY, currentNode.getYCoordinate() );        
            }            
        }        
        
        middleX = ( ( highestX - lowestX ) / 2 ) + lowestX;
        middleY = ( ( highestY - lowestY ) / 2 ) + lowestY;
        
        shiftX = middleX;
        shiftY = middleY;
        
        for ( int i = 0; i < nodeList.size(); i++ )
        {
            currentNode = (Node)( nodeList.get(i) );
            
            currentNode.setXCoordinate( currentNode.getXCoordinate() - shiftX );
            currentNode.setYCoordinate( currentNode.getYCoordinate() - shiftY );
        }        
        for ( int i = 0; i < edgeList.size(); i++ )
        {
            currentEdge = (Edge)( edgeList.get(i) );
            
            moveEdge( currentEdge, 
                getNode( currentEdge.getSourceName() ).getCoordinate(),
                getNode( currentEdge.getDestinationName() ).getCoordinate() );
        }
    }
    
    public void setToDefault()
    {
        // xy-coordinate buffers
        double [] v = { 0.0, 0.0 };
        double [] newCoordinate = { 0.0, 0.0 };
        
        // node and edge buffers
	Node referenceNode = null;
        Node currentNode = null;
        Node previousNode = null;
        Edge currentEdge = null;
               
        // pre-calculate the angle of each node
        double angle = 2 * Math.PI / nodeList.size();
        
        // place nodes on graph at default positions
        for ( int i = 0; i < nodeList.size(); i++ )
        {
            currentNode = (Node)( nodeList.get(i) );
            
            // place first node at default position on graph
            if ( i == 0 )        
            {    
                currentNode.setCoordinate( 0, 0 );
		referenceNode = currentNode;
            }
            else
            {
                currentNode.setCoordinate( 
                    200 + previousNode.getXCoordinate(), previousNode.getYCoordinate() );
                
                v[0] = (double)( currentNode.getXCoordinate() - referenceNode.getXCoordinate() );
                v[1] = (double)( currentNode.getYCoordinate() - referenceNode.getYCoordinate() );

                newCoordinate[0] = ( v[0] * Math.cos( angle ) ) - ( v[1] * Math.sin( angle ) );
                newCoordinate[1] = ( v[0] * Math.sin( angle ) ) + ( v[1] * Math.cos( angle ) );

                newCoordinate[0] += (double)( referenceNode.getXCoordinate() );
                newCoordinate[1] += (double)( referenceNode.getYCoordinate() );

                currentNode.setCoordinate( (int)( newCoordinate[0] ), (int)( newCoordinate[1] ) );                
            }
                        
            previousNode = currentNode;
        }
                      
        // place edges on graph at default positions
        for ( int i = 0; i < edgeList.size(); i++ )
        {
            currentEdge = (Edge)( edgeList.get(i) );            
            
            moveEdge( currentEdge, 
                getNode( currentEdge.getSourceName() ).getCoordinate(),
                getNode( currentEdge.getDestinationName() ).getCoordinate() );
        }
    }
}
