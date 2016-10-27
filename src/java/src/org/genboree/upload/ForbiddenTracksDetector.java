package org.genboree.upload;

import org.genboree.dbaccess.*;
import org.genboree.util.Util;
import org.genboree.util.GenboreeUtils;


import java.util.HashMap;
import java.io.FileReader;
import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.IOException;

public class ForbiddenTracksDetector
{
  protected DBAgent db = null;
  protected String lffFile;
  protected int genboreeUserId;
  protected int refSeqId;
  protected String refSeqIdStr;
  protected int maxNumberOfColumnsInLff = 15;
  protected HashMap trackHash = null;
  protected HashMap forbiddenTrackHash = null;
  protected boolean successfullyParsed = false;
  protected String mainDb = null;
  protected String sharedDbs[] = null;
  protected String forbiddenTrackArray[] = null;
  protected String commaSeparatedListOfFT = null;

  public ForbiddenTracksDetector( String lffFile, int genboreeUserId, String refSeqIdStr )
  {
    int refSeqId = Util.parseInt( refSeqIdStr, -1 );
    if( refSeqId > 0 && genboreeUserId > 0 )
    {
      this.refSeqId = refSeqId;
      this.refSeqIdStr = refSeqIdStr;
      this.genboreeUserId = genboreeUserId;
      this.lffFile = lffFile;
    } else
    {
      this.refSeqIdStr = null;
      this.genboreeUserId = -1;
      this.lffFile = null;
    }
    if( this.lffFile != null )
      successfullyParsed = parseLffFile();

    setDbNames();
    validateTracks();
  }

  public void clearForbiddenTracks()
  {
    this.refSeqId = -1;
    this.refSeqIdStr = null;
    this.genboreeUserId = -1;
    this.lffFile = null;
    this.db = null;
    this.trackHash = null;
    this.forbiddenTrackHash = null;
    this.successfullyParsed = false;
    this.mainDb = null;
    this.sharedDbs = null;
  }

  public ForbiddenTracksDetector()
  {
  }

  public void resetForbiddenTracks( String lffFile, int genboreeUserId, String refSeqIdStr )
  {
    clearForbiddenTracks();
    int refSeqId = Util.parseInt( refSeqIdStr, -1 );
    if( refSeqId > 0 && genboreeUserId > 0 )
    {
      this.refSeqId = refSeqId;
      this.refSeqIdStr = refSeqIdStr;
      this.genboreeUserId = genboreeUserId;
      this.lffFile = lffFile;
    } else
    {
      this.refSeqIdStr = null;
      this.genboreeUserId = -1;
      this.lffFile = null;
    }
    setDbNames();

    if( this.lffFile != null )
      successfullyParsed = parseLffFile();


    validateTracks();

  }

  public void setLffFile( String lffFile )
  {
    this.lffFile = lffFile;
  }

  public void setGenboreeUserId( int genboreeUserId )
  {
    this.genboreeUserId = genboreeUserId;
  }

  public void setRefSeqIdStr( String refSeqIdStr )
  {
    this.refSeqIdStr = refSeqIdStr;
  }

  public String getMainDb()
  {
    return mainDb;
  }

  public HashMap getTrackHash()
  {
    return trackHash;
  }

  public boolean isSuccessfullyParsed()
  {
    return successfullyParsed;
  }

  public String[] getSharedDbs()
  {
    return sharedDbs;
  }

  public HashMap getForbiddenTrackHash()
  {
    return forbiddenTrackHash;
  }

  public void setForbiddenTrackHash( HashMap forbiddenTrackHash )
  {
    this.forbiddenTrackHash = forbiddenTrackHash;
  }


  public boolean parseLffFile()
  {
    FileReader frd = null;
    BufferedReader in = null;
    boolean success = false;
    try
    {
      String s;
      frd = new FileReader( lffFile );
      in = new BufferedReader( frd );
      trackHash = new HashMap();

      while( ( s = in.readLine() ) != null )
      {
        String track[] = null;
        track = returnTrack( s );
        if( track == null ) continue;
        String key = track[ 0 ] + ":" + track[ 1 ];
        if( trackHash.get( key ) == null )
          trackHash.put( key, track );
      }
      success = true;

    } catch( FileNotFoundException e )
    {
      e.printStackTrace( System.err );
      success = false;
    } catch( IOException e )
    {
      e.printStackTrace( System.err );
      success = false;
    }
    finally
    {
      return success;
    }
  }


  protected String[] returnTrack( String str )
  {
    String line = str.trim();
    String[] data = line.split( "\t" ); // 99% of the time we need to do this anyway
    String type = null;
    String subType = null;
    String[] track = new String[2];

    if( line == null || line.length() < 1 || line.charAt( 0 ) == '#' ) return null;
    if( data.length < 8 ) return null;

    if( data.length >= 10 && data.length <= maxNumberOfColumnsInLff )
    {
      type = data[ 2 ].trim();
      subType = data[ 3 ].trim();
      track[ 0 ] = type;
      track[ 1 ] = subType;
      return track;
    } else
    {
      return null;
    }
  }

  protected void setDbNames()
  {
    int i = 0;
    int a = 0;
    String allDbs[] = null;

    db = DBAgent.getInstance();
    allDbs = GenboreeUpload.returnDatabaseNames( db, refSeqIdStr, false );
    mainDb = GenboreeUtils.fetchMainDatabaseName( refSeqIdStr, false );
    if( allDbs != null && allDbs.length > 0 )
    {
      sharedDbs = new String[allDbs.length];
      for( i = 0; i < allDbs.length; i++ )
      {
        String databaseName = allDbs[ i ];
        if( !databaseName.equalsIgnoreCase( mainDb ) )
        {
          sharedDbs[ a ] = databaseName;
          a++;
        }
      }
    }

  }

  protected boolean validateTracks()
  {
    forbiddenTrackHash = new HashMap();

    if( trackHash != null && trackHash.size() > 0 )
    {
      for( Object key : trackHash.keySet() )
      {
        String[] track = ( String[] )trackHash.get( ( String )key );
        if( TrackPermission.isTrackAllowed( mainDb, track[ 0 ], track[ 1 ], genboreeUserId, false ) )
          forbiddenTrackHash.put( key, "false" );
        else
          forbiddenTrackHash.put( key, "true" );
      }

      // Now I need to loop into shared dbs may be we want to have different rules for shared tracks???
      // A possibility is that we do not give permission to users to upload the same track in the local db
      for( int i = 0; i < sharedDbs.length; i++ )
      {
        if(sharedDbs[i] != null)
        { 
        for( Object key : trackHash.keySet() )
        {
          String[] track = ( String[] )trackHash.get( ( String )key );
          if( !TrackPermission.isTrackAllowed( sharedDbs[ i ], track[ 0 ], track[ 1 ], genboreeUserId, false ) )
          {
            forbiddenTrackHash.put( key, "true" );
          }
//          else   // We only overwrite the permissions if the shared tracks specifically limits the use of the track
//            permissionTracks.put( key, "false" );
        }
      }
      }
      return true;
    } else
      return true;
  }


  protected boolean hasForbiddenTracks()
  {
    for( Object key : forbiddenTrackHash.keySet() )
    {
      String value = ( String )forbiddenTrackHash.get( ( String )key );
      if( value.equalsIgnoreCase( "true" ) )
        return true;
    }

    return false;
  }

  public String[] getArrayWithForbiddenTracks()
  {
    int numberOfForbiddenTracks = 0;

    int i = 0;
    for( Object key : forbiddenTrackHash.keySet() )
    {
      String value = ( String )forbiddenTrackHash.get( ( String )key );
      if( value.equalsIgnoreCase( "true" ) )
        numberOfForbiddenTracks++;
    }

    if( numberOfForbiddenTracks < 1 ) return null;

    forbiddenTrackArray = new String[numberOfForbiddenTracks];
    for( Object key : forbiddenTrackHash.keySet() )
    {
      String value = ( String )forbiddenTrackHash.get( ( String )key );
      if( value.equalsIgnoreCase( "true" ) )
      {
        forbiddenTrackArray[ i ] = ( String )key;
        i++;
      }
    }
    return forbiddenTrackArray;

  }

  public String getCommaSeparatedListOfTracks()
  {
    StringBuffer tempStringBuffer = null;
    String arrayOfForbiddentracks[] = getArrayWithForbiddenTracks();
    commaSeparatedListOfFT = null;

     if( forbiddenTrackArray != null && forbiddenTrackArray.length > 0 )
    {
     tempStringBuffer = new StringBuffer(200);
      for( int i = 0; i < forbiddenTrackArray.length; i++ )
      {
        tempStringBuffer.append(forbiddenTrackArray[ i ]);
        if(i < (forbiddenTrackArray.length - 1))
          tempStringBuffer.append(", ");

      }
      commaSeparatedListOfFT = tempStringBuffer.toString();
    }
    return commaSeparatedListOfFT;
  }


  public static void printUsage()
  {
    System.out.print( "usage: CheckForForbiddenTracks " );
    System.out.println(
            "-r refSeqId  " +
                    "-u genboreeUserId " +
                    "-f lffFile " +
                    "\n" );
  }


  public static void main( String[] args )
  {
    String refseqId = null;
    int genboreeUserId = -1;
    String fileName = null;
    HashMap forbiddenTrackHash = null;
    HashMap trackHash = null;
    String mainDb = null;
    String shareDbs[] = null;
    String forbiddenTrackArray[] = null;

    int exitError = 0;

    if( args.length < 3 )
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
            refseqId = args[ i ];
          }
        } else if( args[ i ].compareToIgnoreCase( "-f" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            fileName = args[ i ];
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

    ForbiddenTracksDetector forbiddenTracks = new ForbiddenTracksDetector( fileName, genboreeUserId, refseqId );
    trackHash = forbiddenTracks.getTrackHash();
    forbiddenTrackHash = forbiddenTracks.getForbiddenTrackHash();
    forbiddenTrackArray = forbiddenTracks.getArrayWithForbiddenTracks();

    mainDb = forbiddenTracks.getMainDb();
    shareDbs = forbiddenTracks.getSharedDbs();


    System.out.println( "The main db is " + mainDb );
    for( int i = 0; i < shareDbs.length; i++ )
    {
      System.out.println( "The shared db[" + i + "] = " + shareDbs[ i ] );
    }


    if( trackHash != null && trackHash.size() > 0 )
    {
      for( Object key : trackHash.keySet() )
      {
        String value[] = ( String[] )trackHash.get( ( String )key );
        System.out.println( "The track = " + ( String )key + " with a value of " + value[ 0 ] + " and " + value[ 1 ] );
      }
    }

    if( forbiddenTrackHash != null && forbiddenTrackHash.size() > 0 )
    {
      for( Object key : forbiddenTrackHash.keySet() )
      {
        String value = ( String )forbiddenTrackHash.get( ( String )key );
        System.out.println( "is the track " + ( String )key + " forbidden? " + value );

      }
    }

    System.out.println( "Has the db forbidden tracks? " + forbiddenTracks.hasForbiddenTracks() );
    if( forbiddenTrackArray != null && forbiddenTrackArray.length > 0 )
    {
      System.out.println( "The forbidden tracks are: " );
      for( int i = 0; i < forbiddenTrackArray.length; i++ )
      {
        System.out.print( forbiddenTrackArray[ i ]);
        if(i < (forbiddenTrackArray.length - 1))
          System.out.print(", ");

      }
      System.out.println();
      System.out.flush();
    }

    System.out.println( "printing the list directly " + forbiddenTracks.getCommaSeparatedListOfTracks() );
    System.out.flush();

  }


}
