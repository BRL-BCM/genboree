package org.genboree.dbaccess;

import org.genboree.util.Util;
import java.sql.*;
import java.util.*;

public class DatabaseList
{
    private static void printError( DBAgent db, java.io.PrintStream out )
    {
        String[] err = db.getLastError();
        db.clearLastError();
        if( err != null )
        for( int i=0; i<err.length; i++ ) out.println( err[i] );
    }

/*
    /www/jdks/j2sdk1.4.1_01/bin/java -classpath GDASServlet.jar org.genboree.dbaccess.DatabaseList 77 78
*/
    public static void main( String[] args )
        throws Exception
    {
        int i;
        if( args.length < 1 )
        {
            System.out.println( "Usage: java org.genboree.dbaccess.DatabaseList Id1 [Id2 Id3 ...]" );
            return;
        }

        DBAgent db = DBAgent.getInstance();
        Vector v = new Vector();

        for( i=0; i<args.length; i++ )
        {
            Refseq rseq = new Refseq();
            rseq.setRefSeqId( args[i] );
            rseq.fetch( db );
            if( db.getLastError() != null )
            {
                printError( db, System.err );
                return;
            }
            String[] dbNames = rseq.fetchDatabaseNames( db );
            if( dbNames!=null )
            {
                for( int j=0; j<dbNames.length; j++ )
                {
                    if( !v.contains(dbNames[j]) ) v.addElement( dbNames[j] );
                }
            }
        }

        for( i=0; i<v.size(); i++ )
        {
            String dbName = (String) v.elementAt( i );
            System.out.println( dbName );
        }

    }
}
