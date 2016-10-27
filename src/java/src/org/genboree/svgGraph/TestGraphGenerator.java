/*
 * TestGraphGenerator.java
 *
 * Created on August 10, 2004, 12:10 PM
 */

import org.genboree.svgGraph.*;
import java.util.*;
import java.io.*;

/**
 *
 * @author  mc147591
 */
public class TestGraphGenerator extends GraphGenerator{  
    
    /** Creates a new instance of TestGraphGenerator */
    public TestGraphGenerator( File svgOutputFile, int width, int height ) {
        super( svgOutputFile, width, height );
    }
        
    public static void main( String args[] )
    {
        File testFile = new File( "C:\\src\\work\\brl-depot\\genboree\\genboreeCode\\src\\org\\genboree\\svgGraph\\testGraphGenerator.svg" );
        
        TestGraphGenerator test = new TestGraphGenerator( testFile, 800, 800 );
            
                
        test.addNode( "node1" );
        test.addNode( "node2" );
        test.addNode( "node3" );
        test.addNode( "node4" );        
        test.addNode( "node5" );
        test.addNode( "node6" );
        test.addNode( "node7" );        
        test.addNode( "node8" );
        test.addNode( "node9" );
        test.addNode( "node10" );

        test.connectNodes( "node1", "node2", 1.0 );
        test.connectNodes( "node2", "node3", 1.0 );
        test.connectNodes( "node3", "node4", 1.0 );
        test.connectNodes( "node4", "node5", 1.0 );
        test.connectNodes( "node5", "node6", 1.0 );
        test.connectNodes( "node6", "node7", 1.0 );
        test.connectNodes( "node7", "node8", 1.0 );
        test.connectNodes( "node8", "node9", 1.0 );     
        test.connectNodes( "node9", "node10", 1.0 );        
        test.connectNodes( "node10", "node1", 1.0 );
        test.connectNodes( "node8", "node1",8 );
        //test.connectNodes( "node1", "node5", 3 );
        
        //test.connectNodes( "node7", "node9", 2.0 );
        

/*        test.connectNodes( "node6", "node7", 1.0 );
        test.connectNodes( "node7", "node8", 1.0 );
        test.connectNodes( "node8", "node9", 1.0 );
        test.connectNodes( "node9", "node1", 1.0 );*/
//        test.connectNodes( "node1", "node6", 1.0 );
        
        
	test.generateGraph();
                
        System.out.println( "TestGraphGenerator complete." );
    }    
}
