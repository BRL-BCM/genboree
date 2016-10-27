package org.genboree.dbaccess;

import java.util.*;
import java.sql.*;

public class SetSortOrder
{

    public static void setFtypeSort( String refSeqId, int userId )
        throws Exception
    {
        DBAgent db = DBAgent.getInstance();
        Refseq rseq = new Refseq();
        rseq.setRefSeqId( refSeqId );
        rseq.fetch( db );
        GenboreeUpload[] uplds = GenboreeUpload.fetchAll( db, refSeqId, null, userId );
        Migrator.setFdataSort( db, rseq.getDatabaseName(), uplds );
    }

    public static void main( String[] args )
        throws Exception
    {
        for( int i=0; i<args.length; i++ )
            setFtypeSort( args[i] , 7);
    }

}