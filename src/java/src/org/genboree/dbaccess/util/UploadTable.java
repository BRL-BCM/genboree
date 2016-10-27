package org.genboree.dbaccess.util ;

import java.sql.* ;
import org.genboree.dbaccess.* ;

// Class to query the upload table
public class UploadTable
{
  // Get upload id for a refSeqId + specific dbName
  public static String getUploadIdByRefSeqIdAndDbName(String refSeqId, String dbName, Connection conn)
  {
    String uploadId = null ;
    String sql =  "SELECT upload.uploadId FROM upload, refseq, refseq2upload " +
                  "WHERE refseq.refseqId = refseq2upload.refseqId " +
                  "AND upload.uploadId = refseq2upload.uploadId " +
                  "AND upload.databaseName = ? " +
                  "AND upload.refSeqId = ? " ;
    PreparedStatement pstmt = null ;
    ResultSet resultSet = null ;

    if(refSeqId != null && dbName != null)
    {
      try
      {
        /* TODO upload table has duplicated data need to fix for now I using this dumb query
            SELECT upload.uploadId FROM upload, refseq, refseq2upload WHERE refseq.refseqId =
            refseq2upload.refseqId AND upload.uploadId = refseq2upload.uploadId AND
            upload.databaseName = '$databaseName' and upload.refSeqId = $refseqId;
            the upload.refSeqId needs to be removed right now when quering for a template
            database return all the uploadIds of databases sharing the refseqId */
        pstmt = conn.prepareStatement(sql) ;
        pstmt.setString(1, refSeqId) ;
        pstmt.setString(2, dbName) ;
        resultSet = pstmt.executeQuery() ;
        if(resultSet.next())
        {
          uploadId = resultSet.getString(1) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println( "ERROR: UploadTable#getUploadIdByRefSeqIdAndDbName(S, S, C) => Exception getting the uploadId by refSeqId (" + refSeqId + ") and database name (" + dbName + ") using sql = " + sql) ;
      }
      finally
      {
        DBAgent.safelyCleanup(resultSet, pstmt) ;
      }
    }
    return uploadId ;
  }
}
