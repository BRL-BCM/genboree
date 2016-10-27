package org.genboree.dbaccess;


import java.util.*;
import org.genboree.util.*;


import java.util.Arrays;

public class TestDownloadTracks
{
  public static void printUsage()
  {
    System.out.print( "usage: TestDownloadTracks " );
    System.out.println(
            "-r refSeqId  " +
            "-u genboreeUserId " +
            "\n" );
  }


  public static void main( String[] args )
  {
    DbFtype[] trackArray = null;
    DBAgent myDb = null;
    int refseqId = -1;
    int genboreeUserId = -1;
    int iDisplayEmptyTracks = 1;
    String viewEP = null;
    String[] classes = null;
    Hashtable ftypesbyClasses = null;
    String[] trackNames = null;
    boolean allEntryPoints= false;

    int exitError = 0;

    if( args.length < 2 )
    {
      printUsage();
      System.exit( -1 );
    }

    if( args.length >= 1 )
    {
      for( int i = 0; i < args.length; i++ )
      {
        if( args[ i ].compareToIgnoreCase( "-r" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            refseqId = Util.parseInt( args[ i ], -1 );
          }
        }
        else if( args[ i ].compareToIgnoreCase( "-u" ) == 0 )
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

    if( iDisplayEmptyTracks > 0 ) allEntryPoints = true;
    trackArray = GenboreeUpload.fetchTracksFromRefSeqIdEntryPoint( myDb, "" + refseqId, viewEP, allEntryPoints, genboreeUserId );
    Arrays.sort( trackArray, new GclassFtypeComparator() );
    trackNames = GenboreeUpload.fetchTrackNames( trackArray );
    classes = GenboreeUpload.fetchClassNames( trackArray );
    ftypesbyClasses = GenboreeUpload.fetchHashWithVectorsOfFtypesPerClass( trackArray, classes );


/*  for(Iterator it = ftypesbyClasses.entrySet().iterator(); it.hasNext();  )
  {
    Map.Entry entry = (Map.Entry)it.next();
    String key = (String)entry.getKey() ;
    Vector value = (Vector)entry.getValue() ;
    for(int a = 0; a < value.size(); a++)
    {
      DbFtype tempValue = (DbFtype)value.get( a );
      String fmethodFsource = tempValue.getFmethod() + ":" + tempValue.getFsource();
      System.out.println("The initial key is " + key + " and the initial value is " + fmethodFsource + " (" + tempValue.getFtypeid() + ")");
    }
  }*/

       if( ftypesbyClasses != null && ftypesbyClasses.size() > 0 )
      {
        for( Object key : ftypesbyClasses.keySet() )
        {
          Vector value = ( Vector )ftypesbyClasses.get( ( String )key );
          for(int a = 0; a < value.size(); a++)
          {
            DbFtype tempValue = (DbFtype)value.get( a );
            String fmethodFsource = tempValue.getFmethod() + ":" + tempValue.getFsource();
            String databaseName = tempValue.getDatabaseName();
            int ftypeId = tempValue.getFtypeid();
            String info = new StringBuffer().append( ftypeId ).append( " [" ).append( databaseName ).append("]").toString();
//            System.out.println("Class = " + key + " and track = " + fmethodFsource + " (" + info + ")");
            System.out.println(fmethodFsource + "\t(" + info + ")");
          }
        }
      }




  }
}


