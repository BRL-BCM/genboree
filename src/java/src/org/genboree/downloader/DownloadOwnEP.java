package org.genboree.downloader;

import org.genboree.dbaccess.DBAgent;
import org.genboree.util.GenboreeUtils;
import org.genboree.util.Util;

public class DownloadOwnEP
{
  public static void printUsage()
  {
    System.out.print( "usage: DownloadOwnEP " );
    System.out.println(
            "-d databaseName \n" +
            "-u genboreeUserId\n" );
    return;
  }


  public static void main( String[] args )
  {
    String databaseName = null;
    String fileName = null;
    String[] tracks = null;
    DBAgent myDb = null;
    AnnotationDownloader currentDownload = null;
    String temporaryDir = "/tmp/databaseUpdates";
    String refseqId = null;
    int genboreeUserId = -1;


    if( args.length < 3 )
    {
      printUsage();
      System.exit( -1 );
    }

    if( args.length >= 1 )
    {

      for( int i = 0; i < args.length; i++ )
      {
        if( args[ i ].compareToIgnoreCase( "-d" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            databaseName = args[ i ];
          }
        } else if( args[ i ].compareToIgnoreCase( "-u" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            genboreeUserId = Util.parseInt( args[ i ], -1 );
          }
        }
      }
    } else
    {
      printUsage();
      System.exit( -1 );
    }


    myDb = DBAgent.getInstance();

    refseqId = GenboreeUtils.fetchRefSeqIdFromDatabaseName( databaseName );
    fileName = temporaryDir + "/" + databaseName + "_entryPoints.lff";
    currentDownload = new AnnotationDownloader( myDb, refseqId, genboreeUserId );
    currentDownload.printChromosomes( fileName );

  }
}


