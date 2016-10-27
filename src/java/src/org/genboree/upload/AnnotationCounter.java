package org.genboree.upload;

import org.genboree.dbaccess.DBAgent;
import org.genboree.util.GenboreeUtils;
import java.sql.*;
import java.util.ArrayList;


public class AnnotationCounter
{

  protected DBAgent db = null;
  protected String databaseName = null;
  protected String refseqId = null;
  protected Connection databaseConnection = null;


  public AnnotationCounter( String refSeqId, String databasename, String listOfTrackIds )
  {

    if( databasename == null && refSeqId == null )
    {
      System.err.println( "missing databaseName" );
      return;
    }
    else if( refSeqId != null && databasename == null )
    {
      this.refseqId = refSeqId;
      databaseName = GenboreeUtils.fetchMainDatabaseName( refseqId );
    }
    else if( refSeqId == null && databasename != null )
      this.databaseName = databasename;
    else
    {
      this.refseqId = refSeqId;
      this.databaseName = databasename;
    }

    if( databaseName == null )
    {
      System.err.println( "wrong databaseName " + databaseName );
      return;
    }

    try
    {
      boolean isGenboreeDatabase = false;
      db = DBAgent.getInstance();
      databaseConnection = db.getConnection( databaseName );
      if( databaseConnection == null )
      {
        System.err.println( "Unable to create connection to Database " + databaseName );
        System.err.flush();
        System.exit( 10 );
      }

      isGenboreeDatabase = GenboreeUtils.verifyIfDabaseLookLikeGenboree_r_Type( databaseConnection, databaseName );

      if( !isGenboreeDatabase )
      {
        System.err.println( "Database " + databaseName + " does not look like a genboree database" );
        System.err.flush();
        System.exit( 10 );
      }
      cleanFtypeCountTable( listOfTrackIds );
      fillFtypeCount( listOfTrackIds );
    }
    catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception trying to find empty groups for databaseName = " + databaseName );
      System.err.flush();
    }
    finally
    {
      return;
    }
  }






  public void cleanFtypeCountTable(String listOfTrackIds)
  {
    String cleanFtypeCountSqlStatement = null;
    if(listOfTrackIds == null || listOfTrackIds.length() < 1)
      cleanFtypeCountSqlStatement = "TRUNCATE TABLE ftypeCount";
    else
      cleanFtypeCountSqlStatement = "DELETE FROM ftypeCount where ftypeId in (" + listOfTrackIds + ")";

    try
    {

      Statement stmt = databaseConnection.createStatement();
      stmt.executeUpdate( cleanFtypeCountSqlStatement );


      stmt.close();

    } catch( Exception ex )
    {
      System.err.println( "Exception during truncating tables" );
      System.err.println( "Databasename = " + databaseName );
      System.err.flush();
    }
  }

  public void fillFtypeCount(String listOfTrackIds)
  {
    String fillTable = null;
    if(listOfTrackIds == null || listOfTrackIds.length() < 1)
      fillTable = "INSERT INTO ftypeCount (SELECT ftypeid, COUNT(*) FROM fdata2 GROUP BY ftypeid)";
    else
      fillTable = "INSERT INTO ftypeCount (SELECT ftypeid, COUNT(*) FROM fdata2 WHERE ftypeid in (" + listOfTrackIds + ") GROUP BY ftypeid)";

    try
    {
      Statement stmt = databaseConnection.createStatement();
      stmt.executeUpdate( fillTable );
      stmt.close();

    } catch( Exception ex )
    {
      System.err.println( "Exception during fill tables" );
      System.err.println( "Databasename = " + databaseName );
      System.err.flush();
    }
  }


  public static void updateCountTableUsingTrackIds(Connection databaseConnection, String listOfTrackIds)
  {
    stCleanFtypeCountTable(databaseConnection, listOfTrackIds);
    stFillFtypeCount(databaseConnection, listOfTrackIds);
  }


  public static void updateCountTableUsingFids( Connection databaseConnection, String listOfFids )
  {
    String listOfTrackIds = null;
    listOfTrackIds = GenboreeUtils.getFtypeIdsFromFids( databaseConnection, listOfFids );
    if( listOfTrackIds == null || listOfTrackIds.length() < 1 )
      return;
    else
    {
      stCleanFtypeCountTable( databaseConnection, listOfTrackIds );
      stFillFtypeCount( databaseConnection, listOfTrackIds );
    }
  }

  

  public static void stCleanFtypeCountTable(Connection databaseConnection, String listOfTrackIds)
  {
    String cleanFtypeCountSqlStatement = null;
    if(listOfTrackIds == null || listOfTrackIds.length() < 1)
      cleanFtypeCountSqlStatement = "TRUNCATE TABLE ftypeCount";
    else
      cleanFtypeCountSqlStatement = "DELETE FROM ftypeCount where ftypeId in (" + listOfTrackIds + ")";
    

    try
    {

      Statement stmt = databaseConnection.createStatement();
      stmt.executeUpdate( cleanFtypeCountSqlStatement );
      stmt.close();

    } catch( Exception ex )
    {
      ex.printStackTrace(System.err);
      System.err.println( "Exception during stCleanFtypeCountTable" );
      System.err.flush();
    }
  }

  public static void stFillFtypeCount(Connection databaseConnection, String listOfTrackIds)
  {
    String fillTable = null;
    if(listOfTrackIds == null || listOfTrackIds.length() < 1)
      fillTable = "INSERT INTO ftypeCount (SELECT ftypeid, COUNT(*) FROM fdata2 GROUP BY ftypeid)";
    else
      fillTable = "INSERT INTO ftypeCount (SELECT ftypeid, COUNT(*) FROM fdata2 WHERE ftypeid in (" + listOfTrackIds + ") GROUP BY ftypeid)";

    try
    {
      Statement stmt = databaseConnection.createStatement();
      stmt.executeUpdate( fillTable );
      stmt.close();

    } catch( Exception ex )
    {
      ex.printStackTrace(System.err);
      System.err.println( "Exception during stFillFtypeCount" );
      System.err.println( "Exception during fill tables" );
      System.err.flush();
    }
  }





  public static void printUsage()
  {
    System.out.print("usage: AnnotationCounter");
    System.out.println(
            "-r refseqid ( or -d databaseName ) -f commaSeparatedListFtypeIds\n" +
                    "]\n");
    return;
  }

  public static void main(String[] args) throws Exception
  {
    String refseqId = null;
    AnnotationCounter annotationCounter;
    String bufferString = null;
    String databaseName = null;
    String listOfTrackIds = null;


    if(args.length == 0 )
    {
      printUsage();
      System.exit(-1);
    }


    if(args.length >= 1)
    {

      for(int i = 0; i < args.length; i++ )
      {
        if(args[i].compareToIgnoreCase("-r") == 0)
        {
          i++;
          if(args[i] != null)
          {
            refseqId = args[i];
          }
        }
        else if(args[i].compareToIgnoreCase("-d") == 0)
        {
          i++;
          if(args[i] != null)
          {
            databaseName = args[i];
          }
        }
        else if(args[i].compareToIgnoreCase("-f") == 0)
        {
          i++;
          if(args[i] != null)
          {
            listOfTrackIds = args[i];
          }
        }


        else
        {
          printUsage();
          System.exit(-1);
        }


        annotationCounter = new AnnotationCounter( refseqId, databaseName, listOfTrackIds );

        System.exit(0);

      }



    }
  }
}
