package org.genboree.downloader ;

import org.genboree.tabular.* ;
import java.util.Vector ;
import java.sql.Connection ;
import java.sql.SQLException ;
import org.json.JSONObject ;
import org.json.JSONException ;
import org.genboree.dbaccess.Refseq ;
import org.genboree.dbaccess.DbFtype ;
import org.genboree.dbaccess.DBAgent ;
import org.genboree.dbaccess.TabularLayout ;

/**
 * This class provides a stand alone tool to use the java org.genboree.tabular.*
 * classes to download data from a user database in a tabular format (non-LFF).
 * The data can be formatted using a tabular layout provided in JSON format, or
 * the name of a saved layout in the database.  The data will be output as a
 * tab-delimited string printed out on standard out (System.out).  If no layout
 * name or JSON layout are provided as arguments to this downloader, it will
 * simply output the data with the default layout.
 */
class TabularDownloader
{
  /** The default tabular layout */
  public static final String DEFAULT_LAYOUT = 
    "{" + 
    "'columns':'lName,lType,lSubtype,lEntry Point,lStart,lStop', " + 
    "'sort':'lEntry Point,lStart', " + 
    "'groupMode':'terse' " +
    "}" ;
  /** 
   * The size of the blocks used to partially fill the table rows
   * (tradeoff between startup speed / throughput) 
   */
  public static final int BLOCK_SIZE = 10000 ;

  /**
   * The main class of the downloader, to setup and output the annotation data
   * in the specified tabular layout.
   */
  public static void main(String[] args)
  {
    //////
    // First process all of the arguments
    // Expecting:
    //   --refseq=id
    //   --trackName=track (1 or more)
    // Optional:
    //   --layout=layout  OR
    //   --layoutName=name
    //   --landmark=lm
    int databaseId = -1, userId = -1 ;
    Vector<String> tracks = null ;
    String landmark = null, layoutName = null ;
    JSONObject layout = null ;
    for(String arg : args)
    {
      if(arg.indexOf("--refseq=") == 0)
      {
        try
        {
          databaseId = Integer.parseInt(arg.substring(arg.indexOf("=") + 1)) ;
        }
        catch(NumberFormatException e)
        {
          System.err.println("The refSeqId must be a valid Genboree refSeqId (integer)") ;
          usage() ;
        }
      }
      else if(arg.indexOf("--trackName=") == 0)
      {
        if(tracks == null) tracks = new Vector<String>() ;
        tracks.addElement(arg.substring(arg.indexOf("=") + 1)) ;
      }
      else if(arg.indexOf("--landmark=") == 0)
      {
        landmark = arg.substring(arg.indexOf("=") + 1) ;
      }
      else if(arg.indexOf("--layoutName=") == 0)
      {
        layoutName = arg.substring(arg.indexOf("=") + 1) ;
      }
      else if(arg.indexOf("--layout=") == 0)
      {
        try
        {
          layout = new JSONObject(arg.substring(arg.indexOf("=") + 1)) ;
        }
        catch(JSONException e)
        {
          e.printStackTrace() ;
          System.err.println(arg) ;
          System.err.println("Badly formatted layout provided as argument (bad JSON)") ;
          usage() ;
        }
      }
      else if(arg.indexOf("--user=") == 0)
      {
        try
        {
          userId = Integer.parseInt(arg.substring(arg.indexOf("=") + 1)) ;
        }
        catch(NumberFormatException e)
        {
          System.err.println("The user id must be a valid Genboree user id (integer)") ;
          usage() ;
        }
      }
      else
      {
        usage() ;
      }
    }
    
    if(layoutName == null && layout == null)
    {
      // Use default layout
      try
      {
        layout = new JSONObject(DEFAULT_LAYOUT) ;
      }
      catch(JSONException e)
      {
        System.err.println("DEFAULT_LAYOUT constant is bad!?!?") ;
        layout = null ;
      }
    }

    // Now check for required arguments
    if(databaseId == -1)
    {
      System.err.println("Missing required argument --refseq") ;
      usage() ;
    }
    else if(tracks == null || tracks.size() == 0)
    {
      System.err.println("Missing or improperly formed parameter --trackName") ;
      usage() ;
    }
    else if(userId == -1)
    {
      System.err.println("Missing required argument --user") ;
      usage() ;
    }

    //////
    // Create the database connection
    DBAgent db = DBAgent.getInstance() ;

    //////
    // Setup the Refseq and DbFtype's in preparation for the download
    // First make the Refseq
    Refseq database = new Refseq() ;
    database.setRefSeqId("" + databaseId) ;
    boolean connected = false ;
    try
    {
      connected = database.fetch(db) ;
    }
    catch(SQLException e)
    {
      System.err.println("SQL exception when fetching refseq: " + e) ;
      connected = false ;
    }

    // Present any errors to the user
    if(!connected)
    {
      System.err.println("Problem connecting to database with refSeqId: " + databaseId) ;
      System.exit(-2) ;
    }

    // Second grab the tracks vector
    Vector<DbFtype> trackList = Utility.getTracksFromNames(db, userId, database, tracks.toArray(new String[0])) ;

    //////
    // Now handle the layout as needed
    String columns = "", sort = "" ;
    int groupMode = Table.GROUPED_TERSE ;
    if(layoutName != null)
    {
      // Grab layout from database and transform into JSON
      try
      {
        Connection conn = db.getConnection(database.getDatabaseName()) ;
        TabularLayout dbLayout = TabularLayout.fetchByName(conn, layoutName) ;
        if(dbLayout == null)
        {
          System.err.println("No such layout in the database (" + layoutName + ")") ;
          usage() ;
        }
        layout = new JSONObject(dbLayout.toJson()) ;
      }
      catch(JSONException e)
      {
        System.err.println("Badly formed JSON from TabularLayout.toJson():\n" + e) ;
        layout = null ;
      }
      catch(SQLException e)
      {
        System.err.println("Problem connecting to user database and fetching tabular layout:\n" + e) ;
        layout = null ;
      }
    }

    // Now pull out necessary layout sections
    if(layout != null)
    {
      // Layout was provided (or default layout)
      try
      {
        columns = layout.getString("columns") ;
        if(layout.has("sort")) sort = layout.getString("sort") ;
        if(layout.has("groupMode"))
        {
          if(layout.getString("groupMode").equals("terse")) groupMode = Table.GROUPED_TERSE ;
          else if(layout.getString("groupMode").equals("verbose")) groupMode = Table.GROUPED_VERBOSE ;
          else groupMode = Table.UNGROUPED ;
        }
      }
      catch(JSONException e)
      {
        System.err.println("Badly formed JSON from tabular layout: " + layout.toString()) ;
        System.err.println("Error is: " + e) ;
        System.exit(-3) ;
      }
    }
    else
    {
      // Problem has occurred, cannot output data
      System.err.println("Problem gathering layout... no valid layout data could be found!") ;
      System.err.println("Provided data:\n") ;
      System.err.println("\tlayoutName: " + layoutName) ;
      System.err.println("\tlayout:     " + layout) ;
      System.exit(-3) ;
    }

    //////
    // Create the Table object
    Table table = new Table(db, trackList, columns, groupMode, sort, landmark) ;

    //////
    // And finally, output to stdout (filling the table in blocks)
    // Skip the edit links
    for(int block = 0; block < ((table.getRowCount() - 1) / BLOCK_SIZE) + 1; block++)
    {
      // Calculate the stop of the block
      int stop = ((block + 1) * BLOCK_SIZE - 1 >= table.getRowCount()) ?
        table.getRowCount() - 1 : (block + 1) * BLOCK_SIZE - 1 ;

      // Fill this block
      table.fill(db, block * BLOCK_SIZE, stop) ;

      // Output this block's data (Skipping Edit Links)
      for(int row = block * BLOCK_SIZE; row <= stop; row++)
      {
        int firstCol = 1 ;
        if(table.getHeader(1).getType().getId() == ColumnType.UNDEFINED_ID)
          firstCol = 2 ;
        for(int col = firstCol; col <= table.getVisibleColumnCount(); col++)
          if(table.getHeader(col).getType().getId() != ColumnType.UNDEFINED_ID)
            System.out.print(((col == firstCol) ? "" : "\t") + table.getRow(row).get(col)) ;
        System.out.println("") ;
      }
    }
  }

  /**
   * Reminder of the proper usage for this downloader from the CLI.
   */
  public static void usage()
  {
    System.err.println("usage:\njava " + TabularDownloader.class.getName()) ;
    System.err.println("\t\t--refseq=id --trackName=track [... --trackName=track] --user=userId") ;
    System.err.println("\t\t[--landmark=lm] [--layoutName=name OR --layout=layout]") ;
    System.err.println("\n\n\tid\tThe refSeqId for a user database to grab the annotations from") ;
    System.err.println("\ttrack\tThe name of a track for which to grab data.") ;
    System.err.println("\t\tThis argument can be included multiple times for multiple tracks.") ;
    System.err.println("\tuserId\tThe ID of a Genboree user with permission to access this Track data.") ;
    System.err.println("\tlm\tA string representation of a landmark: entry_point:start-stop") ;
    System.err.println("\tname\tThe name of a saved layout in the user " + 
      "database specified by --refseq.") ;
    System.err.println("\tlayout\tA JSON formatted layout object " + 
      "(required: \"columns\", optional: \"sort\", \"groupMode\")") ;
    System.exit(-1) ;
  }
}
