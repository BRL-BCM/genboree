package org.genboree.dbaccess.util;

import org.genboree.dbaccess.DBAgent;
import org.genboree.dbaccess.DbFref;
import org.genboree.util.Util;


import java.sql.*;
import java.util.HashMap;


public class Fdata2Binning
{

  protected long minFbin = 1000L;
  protected long maxFbin = 100000000L;
  protected DBAgent db = null;
  protected String databaseName = null;
  protected Connection databaseConnection = null;
  protected DbFref[] refs = null;
  protected HashMap chromosomeNameToProp = null;
  protected HashMap entryPointIdToProp = null;

  public Fdata2Binning( String dbName )
  {

    databaseName = dbName;
    try
    {
      db = DBAgent.getInstance();
      databaseConnection = db.getConnection( databaseName, false );
      if(databaseConnection == null)
      {
        System.err.println("Unable to stablish a DATABASE CONNECTION in Fdata2Binning::init with database = " + databaseName);
        System.exit(234);
      }
      refs = DbFref.fetchAll( databaseConnection );
      chromosomeNameToProp = new HashMap();
      entryPointIdToProp = new HashMap();

        for(int i=0; i< refs.length; i++ )
        {
            chromosomeNameToProp.put( refs[i].getRefname(), refs[i] );
            entryPointIdToProp.put( refs[i].getRid(), refs[i]);
        }

      setMaxMinBins(true);


    } catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception init Fdata2Binning" );
    }
  }

  public Fdata2Binning( Connection databaseConnection)
  {
    try
    {

      if(databaseConnection == null)
      {
        System.err.println("Unable to stablish a DATABASE CONNECTION in Fdata2Binning::init with database = " + databaseName);
        System.exit(234);
      }
      this.databaseConnection = databaseConnection;
      refs = DbFref.fetchAll( databaseConnection );
      chromosomeNameToProp = new HashMap();
      entryPointIdToProp = new HashMap();

        for(int i=0; i< refs.length; i++ )
        {
            chromosomeNameToProp.put( refs[i].getRefname(), refs[i] );
            entryPointIdToProp.put( refs[i].getRid(), refs[i]);
        }

      setMaxMinBins(false);


    } catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception init Fdata2Binning" );
    }
  }

  public Fdata2Binning( Connection databaseConnection, DbFref[] refs )
  {
    try
    {

      if(databaseConnection == null)
      {
        System.err.println("Unable to stablish a DATABASE CONNECTION in Fdata2Binning::init with database = " + databaseName);
        System.exit(234);
      }
      this.databaseConnection = databaseConnection;
      this.refs = refs;
      chromosomeNameToProp = new HashMap();
      entryPointIdToProp = new HashMap();

        for(int i=0; i< refs.length; i++ )
        {
            chromosomeNameToProp.put( refs[i].getRefname(), refs[i] );
            entryPointIdToProp.put( refs[i].getRid(), refs[i]);
        }

      setMaxMinBins(false);


    } catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception init Fdata2Binning" );
    }
  }



  public HashMap getEntryPointIdToProp()
  {
    return entryPointIdToProp;
  }

  public HashMap getChromosomeNameToProp()
  {
    return chromosomeNameToProp;
  }

  private void setMaxMinBins(boolean closeDb)
  {
    String maxMinBinQuery = "SELECT fvalue FROM fmeta WHERE fname=?";
    try
    {
      PreparedStatement pstmt = databaseConnection.prepareStatement( maxMinBinQuery );
      pstmt.setString( 1, "MIN_BIN" );
      ResultSet rs = pstmt.executeQuery();
      if( rs.next() ) minFbin = rs.getLong( 1 );
      pstmt.setString( 1, "MAX_BIN" );
      rs = pstmt.executeQuery();
      if( rs.next() ) maxFbin = rs.getLong( 1 );
      if(closeDb)
        db.safelyCleanup(rs, pstmt, databaseConnection);
      else
      {
        rs.close();
        pstmt.close();
      }
    } catch( Exception ex )
    {
      ex.printStackTrace( System.err );
      System.err.println( "Exception on Fdata2Binning#setMaxMinBin" );
    }

  }


  public String generateMaxMinBinToQuery( long startPosition, long endPosition, int entryPointId )
  {
    StringBuffer theQuery = null;
    int first = 1;
    StringBuffer middleQuery = null;
    long tier = maxFbin;
    DbFref epProp = null;
    long tempVal = -1;



      if(entryPointId > 0)
      {
        epProp = (DbFref)entryPointIdToProp.get(entryPointId);
      }
      else
        return "";

       if(startPosition <= 0)
      {
        startPosition = 1;
      }
      else
      {
        if(startPosition > epProp.getLength())
          startPosition = epProp.getLength();
      }

      if(endPosition <= 0)
      {
        endPosition = epProp.getLength();
      }
      else
      {
        if(endPosition > epProp.getLength())
          endPosition = epProp.getLength();
      }
      if(startPosition > endPosition)
      {
        tempVal = endPosition;
        endPosition = startPosition;
        startPosition = tempVal;
      }


    middleQuery = new StringBuffer();
    middleQuery.append("AND (fstop >= ").append(startPosition).append(" AND fstart <= ");
    middleQuery.append(endPosition).append(" ) AND rid = ").append(entryPointId).append( " ");

    theQuery = new StringBuffer();
    if( tier >= minFbin )
      theQuery.append("(");

    while( tier >= minFbin )
    {
      String firstArg = null;
      String secondArg = null;
      String startFormat = null;
      String stopFormat = null;

      if( first == 0 )
        theQuery.append(" OR ");
      startFormat = returnFractionOfBin( startPosition, tier );
      firstArg = tier + "." + startFormat;
      stopFormat = returnFractionOfBin( endPosition, tier );
      secondArg = tier + "." + stopFormat;

      if( firstArg.equalsIgnoreCase( secondArg ) )
        theQuery.append("fbin = ").append(firstArg);
      else
        theQuery.append("fbin BETWEEN ").append(firstArg).append(" AND ").append(secondArg);

      first = 0;
      tier = tier / 10;
    }

    if( first == 0 )
      theQuery.append(" ) ").append(middleQuery.toString());

    return theQuery.toString();
  }


  private String returnFractionOfBin( long valueRequested, long tier )
  {
    long myNum;
    String newStr = null;
    String tempString = null;
    int lengthString = 0;

    myNum = valueRequested / tier;
    tempString = "" + myNum;

    lengthString = tempString.length();


    switch( lengthString )
    {
      case 0:
        newStr += "000000";
        break;
      case 1:
        newStr = "00000" + tempString;
        break;
      case 2:
        newStr = "0000" + tempString;
        break;
      case 3:
        newStr = "000" + tempString;
        break;
      case 4:
        newStr = "00" + tempString;
        break;
      case 5:
        newStr = "0" + tempString;
        break;
      case 6:
        newStr = tempString;
        break;
      default:
        newStr = tempString;
        break;
    }

    return newStr;
  }

  public static String generateBinningClause(Connection con, long start, long end, String chromosomeName, int entryPointId)
  {
    HashMap chromosomeNameToProp = null;
    HashMap entryPointIdToProp = null;
    DbFref epProp = null;
    Fdata2Binning fdata2BinningObj = null;
    long tempVal = -1;
    String binningClause = "";
    long startPosition = start;
    long endPosition = end;

    if(con != null)
    {
      fdata2BinningObj = new Fdata2Binning(con);
      if(entryPointId > 0)
      {
        entryPointIdToProp = fdata2BinningObj.getEntryPointIdToProp();
        epProp = (DbFref)entryPointIdToProp.get(entryPointId);
      }
      else if(chromosomeName != null && chromosomeName.length() > 0)
      {
        chromosomeNameToProp = fdata2BinningObj.getChromosomeNameToProp();
        epProp = (DbFref)chromosomeNameToProp.get(chromosomeName);
      }
      else
      {
        return binningClause;
      }


      if(epProp == null)
      {
        System.err.println("Error in Fdata2Binning::generateBinningClause the epProp is null" );
        return null;
      }

      if(entryPointId <= 0 && chromosomeName != null)
        entryPointId = epProp.getRid();


      if(startPosition <= 0)
      {
        startPosition = 1;
      }
      else
      {
        if(startPosition > epProp.getLength())
          startPosition = epProp.getLength();
      }

      if(endPosition <= 0)
      {
        endPosition = epProp.getLength();
      }
      else
      {
        if(endPosition > epProp.getLength())
          endPosition = epProp.getLength();
      }

      if(startPosition > endPosition)
      {
        tempVal = endPosition;
        endPosition = startPosition;
        startPosition = tempVal;
      }

      binningClause = fdata2BinningObj.generateMaxMinBinToQuery( startPosition, endPosition, entryPointId );

    }
    return binningClause;

  }


  public static String generateBinningClause(Connection con, DbFref[] theRefs, long start, long end, String chromosomeName, int entryPointId)
  {
    HashMap chromosomeNameToProp = null;
    HashMap entryPointIdToProp = null;
    DbFref epProp = null;
    Fdata2Binning fdata2BinningObj = null;
    long tempVal = -1;
    String binningClause = "";
    long startPosition = start;
    long endPosition = end;

    if(con != null)
    {
      fdata2BinningObj = new Fdata2Binning(con, theRefs);
      if(entryPointId > 0)
      {
        entryPointIdToProp = fdata2BinningObj.getEntryPointIdToProp();
        epProp = (DbFref)entryPointIdToProp.get(entryPointId);
      }
      else if(chromosomeName != null && chromosomeName.length() > 0)
      {
        chromosomeNameToProp = fdata2BinningObj.getChromosomeNameToProp();
        epProp = (DbFref)chromosomeNameToProp.get(chromosomeName);
      }
      else
      {
        return binningClause;
      }


      if(epProp == null)
      {
        System.err.println("Error in Fdata2Binning::generateBinningClause the epProp is null" );
        return null;
      }

      if(entryPointId <= 0 && chromosomeName != null)
        entryPointId = epProp.getRid();


      if(startPosition <= 0)
      {
        startPosition = 1;
      }
      else
      {
        if(startPosition > epProp.getLength())
          startPosition = epProp.getLength();
      }

      if(endPosition <= 0)
      {
        endPosition = epProp.getLength();
      }
      else
      {
        if(endPosition > epProp.getLength())
          endPosition = epProp.getLength();
      }

      if(startPosition > endPosition)
      {
        tempVal = endPosition;
        endPosition = startPosition;
        startPosition = tempVal;
      }

      binningClause = fdata2BinningObj.generateMaxMinBinToQuery( startPosition, endPosition, entryPointId );

    }
    return binningClause;

  }



  public static String generateBinningClause(String databaseName, long start, long end, String chromosomeName, int entryPointId)
  {
    HashMap chromosomeNameToProp = null;
    HashMap entryPointIdToProp = null;
    DbFref epProp = null;
    Fdata2Binning fdata2BinningObj = null;
    long tempVal = -1;
    String binningClause = "";
    long startPosition = start;
    long endPosition = end;

    if(databaseName != null && databaseName.length() > 0)
    {
      fdata2BinningObj = new Fdata2Binning(databaseName);
      if(entryPointId > 0)
      {
        entryPointIdToProp = fdata2BinningObj.getEntryPointIdToProp();
        epProp = (DbFref)entryPointIdToProp.get(entryPointId);
      }
      else if(chromosomeName != null && chromosomeName.length() > 0)
      {
        chromosomeNameToProp = fdata2BinningObj.getChromosomeNameToProp();
        epProp = (DbFref)chromosomeNameToProp.get(chromosomeName);
      }
      else
      {
        return binningClause;
      }


      if(epProp == null)
      {
        System.err.println("Error in Fdata2Binning::generateBinningClause the epProp is null" );
        return null;
      }

      if(entryPointId <= 0 && chromosomeName != null)
        entryPointId = epProp.getRid();


      if(startPosition <= 0)
      {
        startPosition = 1;
      }
      else
      {
        if(startPosition > epProp.getLength())
          startPosition = epProp.getLength();
      }

      if(endPosition <= 0)
      {
        endPosition = epProp.getLength();
      }
      else
      {
        if(endPosition > epProp.getLength())
          endPosition = epProp.getLength();
      }

      if(startPosition > endPosition)
      {
        tempVal = endPosition;
        endPosition = startPosition;
        startPosition = tempVal;
      }

      binningClause = fdata2BinningObj.generateMaxMinBinToQuery( startPosition, endPosition, entryPointId );

    }
    return binningClause;

  }

  public static void printUsage()
  {
    System.out.print( "usage: Fdata2Binning " );
    System.out.println(
            "-d databaseName\n " +
                    "Optional [\n" +
                    "\t-x test static method\n" +
                    "\t-i startPosition \n" +
                    "\t-t endPosition \n" +
                    "\t-p entryPointId \n" +
                    "\t-e chromosome name \n" +
                    "]\n" );
    return;
  }

  public static void main( String[] args )
  {
    long startPosition = -1;
    long endPosition = -1;
    long tempVal = -1;
    int entryPointId = -1;
    String chromosomeName = null;
    String databaseName = null;
    String bufferString = null;
    HashMap chromosomeNameToProp = null;
    HashMap entryPointIdToProp = null;
    DbFref epProp = null;
    String minMax = null;
    boolean testingStatic = false;

    if( args.length == 0 )
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
        }
        else if( args[ i ].compareToIgnoreCase( "-i" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            bufferString = args[ i ];
            startPosition = Util.parseLong( bufferString, -1 );
          }
        }
        else if( args[ i ].compareToIgnoreCase( "-t" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            bufferString = args[ i ];
            endPosition = Util.parseLong( bufferString, -1 );
          }
        }
        else if( args[ i ].compareToIgnoreCase( "-p" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            bufferString = args[ i ];
            entryPointId = Util.parseInt( bufferString, -1 );
          }
        }
        else if( args[ i ].compareToIgnoreCase( "-e" ) == 0 )
        {
          if( args[ i + 1 ] != null )
          {
            chromosomeName = args[ i + 1 ];
          }
        }
        else if( args[ i ].compareToIgnoreCase( "-x" ) == 0 )
        {
          testingStatic = true;
        }
      }
    }

    if(testingStatic)
    {
      minMax = Fdata2Binning.generateBinningClause(databaseName, startPosition, endPosition, chromosomeName, entryPointId);
      System.out.println("the minMax is:\n" + minMax);
      System.exit( 0 );
    }

    if(databaseName != null && databaseName.length() > 0)
    {
      Fdata2Binning fdata2BinningObj = new Fdata2Binning(databaseName);
      if(entryPointId > 0)
      {
        entryPointIdToProp = fdata2BinningObj.getEntryPointIdToProp();
        epProp = (DbFref)entryPointIdToProp.get(entryPointId);
      }
      else if(chromosomeName != null && chromosomeName.length() > 0)
      {
        chromosomeNameToProp = fdata2BinningObj.getChromosomeNameToProp();
        epProp = (DbFref)chromosomeNameToProp.get(chromosomeName);
      }


      if(epProp == null)
      {
        System.err.println("the epProp is null" );
        return;
      }

      if(entryPointId <= 0 && chromosomeName != null)
        entryPointId = epProp.getRid();


      if(startPosition <= 0)
      {
        startPosition = 1;
      }
      else
      {
        if(startPosition > epProp.getLength())
          startPosition = epProp.getLength();
      }

      if(endPosition <= 0)
      {
        endPosition = epProp.getLength();
      }
      else
      {
        if(endPosition > epProp.getLength())
          endPosition = epProp.getLength();
      }

      if(startPosition > endPosition)
      {
        tempVal = endPosition;
        endPosition = startPosition;
        startPosition = tempVal;
      }

      minMax = fdata2BinningObj.generateMaxMinBinToQuery( startPosition, endPosition, entryPointId );
      System.out.println("the minMax is:\n" + minMax);

    }


  }

}