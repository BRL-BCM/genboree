package org.genboree.tabular ;

import java.util.Set ;
import java.util.Vector ;
import java.util.Arrays ;
import java.util.HashMap ;
import java.sql.ResultSet ;
import java.sql.Statement ;
import java.sql.Connection ;
import java.sql.SQLException ;
import java.sql.PreparedStatement ;
import java.net.URLEncoder ;
import java.io.UnsupportedEncodingException ;
import org.genboree.dbaccess.DBAgent ;
import org.genboree.dbaccess.DbFtype ;
import org.genboree.util.GenboreeConfig ;

/**
 * This class defines the memory structure for a tabular layout and contains
 * references to all of the requested data.  This structure is optimized to
 * lazily load some pieces of data from the database server as requested.  When
 * the class is contructed, it builds two main structures:
 * <ul>
 * <li>The {@link Header} class that defines the {@link Table} layout.</li>
 * <li>A {@link Vector} of {@link Row} Objects that contain enough information
 * to load the data for any Annotation (or group).  This Object might not
 * actually load some of its data until it is requested, for example, sequence
 * data.</li>
 * </ul>
 */
public class Table
{
  // Internal class constants
  private static final int MAX_STACK = 10 ;
  private static final int DEFAULT_RANGE = 25 ;
  // External constants
  public static final int UNGROUPED = 1 ;
  public static final int GROUPED_TERSE = 0 ;
  public static final int GROUPED_VERBOSE = 2 ;

  private Vector<Range> stack = new Vector<Range>() ;
  private String[] dbNames ;
  private Vector<Header> headers ;
  private Row[] data ;
  private int size = 0 ;
  private int groupMode ;
  private String queryUrl ;

  // Sort information
  private boolean reverseSort = false ;
  private boolean sorted = false ;

  /**
   * Create a Java object representing a Tabular Layout, with terse annotation
   * groups, no sort, and all available locations.
   * @param db
   *   The {@link DBAgent} from which to grab database connections for SQL.
   * @param tracks
   *   A {@link Vector} of {@link DbFtype} objects that represent all of the
   *   data tracks from which annotations will be gathered to create this
   *   {@link Table} object.
   * @param columns
   *   An encoded String that represents the attributes that will be displayed
   *   in the columns of this {@link Table}.
   */
  public Table(DBAgent db, Vector<DbFtype> tracks, String columns)
  {
    this(db, tracks, columns, GROUPED_TERSE, null, null) ;
  }

  /**
   * Create a Java object representing a Tabular Layout with no sort, and
   * annotation from all available locations.
   * @param db
   *   The {@link DBAgent} from which to grab database connections for SQL.
   * @param tracks
   *   A {@link Vector} of {@link DbFtype} objects that represent all of the
   *   data tracks from which annotations will be gathered to create this
   *   {@link Table} object.
   * @param columns
   *   An encoded String that represents the attributes that will be displayed
   *   in the columns of this {@link Table}.
   * @param groupMode
   *   The type of annotation grouping used for this {@link Table}.
   */
  public Table(DBAgent db, Vector<DbFtype> tracks, String columns, int groupMode)
  {
    this(db, tracks, columns, groupMode, null, null) ;
  }

  /**
   * Create a Java object representing a Tabular Layout with the default terse
   * annotation grouping.
   * @param db
   *   The {@link DBAgent} from which to grab database connections for SQL.
   * @param tracks
   *   A {@link Vector} of {@link DbFtype} objects that represent all of the
   *   data tracks from which annotations will be gathered to create this
   *   {@link Table} object.
   * @param columns
   *   An encoded String that represents the attributes that will be displayed
   *   in the columns of this {@link Table}.
   * @param sort
   *   An encoded String that represents what attributes to use for sorting the
   *   rows of this {@link Table}.  Can be null.
   * @param entryPoint
   *   An encoded String that restricts the annotation to be displayed in this
   *   {@link Table} to a certain location in the genome, encoded in the
   *   standard 'landmark' format.  Can be null.
   */
  public Table(DBAgent db, Vector<DbFtype> tracks, String columns, String sort, String entryPoint)
  {
    this(db, tracks, columns, GROUPED_TERSE, sort, entryPoint) ;
  }

  /**
   * Create a Java object representing a Tabular Layout.
   * @param db
   *   The {@link DBAgent} from which to grab database connections for SQL.
   * @param tracks
   *   A {@link Vector} of {@link DbFtype} objects that represent all of the
   *   data tracks from which annotations will be gathered to create this
   *   {@link Table} object.
   * @param columns
   *   An encoded String that represents the attributes that will be displayed
   *   in the columns of this {@link Table}.
   * @param groupMode
   *   The type of annotation grouping used for this {@link Table}.
   * @param sort
   *   An encoded String that represents what attributes to use for sorting the
   *   rows of this {@link Table}.  Can be null.
   * @param entryPoint
   *   An encoded String that restricts the annotation to be displayed in this
   *   {@link Table} to a certain location in the genome, encoded in the
   *   standard 'landmark' format.  Can be null.
   */
  public Table(DBAgent db, Vector<DbFtype> tracks, String columns, int groupMode, String sort, String entryPoint)
  {
    // Build the query URL
    try
    {
      queryUrl="&columns=" + URLEncoder.encode(columns, "UTF-8") ;
      if(sort != null)
        queryUrl += "&sort=" + URLEncoder.encode(sort, "UTF-8") ;
      for(DbFtype track : tracks)
        if(queryUrl.indexOf("trackName=" + URLEncoder.encode(track.getTrackName(), "UTF-8")) == -1)
          queryUrl+= "&trackName=" + URLEncoder.encode(track.getTrackName(), "UTF-8") ;
      if(entryPoint != null)
        queryUrl += "&landmark=" + URLEncoder.encode(entryPoint, "UTF-8") ;
      if(groupMode != UNGROUPED)
        queryUrl += "&group_mode=" + (groupMode == GROUPED_VERBOSE ? "verbose" : "terse") ;
    }
    catch(UnsupportedEncodingException e)
    {
      queryUrl = "" ;
    }

    // Set our group mode
    this.groupMode = groupMode ;

    //
    // Organize our data tracks by database to begin with
    //
    HashMap<String, Vector<DbFtype>> dbMap = new HashMap<String, Vector<DbFtype>>() ;
    for(DbFtype track : tracks)
    {
      // Build a new Vector if needed
      if(!dbMap.containsKey(track.getDatabaseName()))
        dbMap.put(track.getDatabaseName(), new Vector<DbFtype>()) ;

      // Map this DbFtype track to its database name
      ((Vector<DbFtype>) dbMap.get(track.getDatabaseName())).add(track) ;
    }
    dbNames = new String[dbMap.keySet().size()] ;
    int dbPos = 0 ;
    for(String dbName : dbMap.keySet())
    {
      dbNames[dbPos] = dbName ;
      dbPos++ ;
    }

    //
    // Build the Headers from the encoded column / sort strings
    //
    headers = new Vector<Header>() ;
    if (columns == null) columns = "" ;
    if (sort == null) sort = "" ;
    int cut = 0 ;
    while(columns.length() > 0)
    {
      cut = columns.indexOf(",", cut + 1) ;
      if(cut > 0 && columns.charAt(cut - 1) == '\\') continue ;

      // Grab the first column value (with escaped commas)
      String value = "" ;
      if(cut == -1)
      {
        value = columns ;
        columns = "" ;
       }
      else
      {
        value = columns.substring(0, cut) ;
        columns = columns.substring(cut + 1) ;
        cut = 0 ;
      }
      value = value.replaceAll("\\\\,", ",") ;

      // Create the header object
      String display = value.substring(1) ;
      if(value.charAt(0) == 'a')
      {
        headers.add(new Header(new ColumnType(display), headers.size() + 1, true)) ;
      }
      else
      {
        // TODO - this could be simplified if we used JSON column descriptions
        //  and included the ColumnType.XXX_ID value along with the name.
        if(display.equals("Edit Link"))
          headers.add(new Header(ColumnType.EDIT, headers.size() + 1, true)) ;
        else if(display.equals("Class"))
          headers.add(new Header(ColumnType.CLASS, headers.size() + 1, true)) ;
        else if(display.equals("Name"))
          headers.add(new Header(ColumnType.NAME, headers.size() + 1, true)) ;
        else if(display.equals("Type"))
          headers.add(new Header(ColumnType.TYPE, headers.size() + 1, true)) ;
        else if(display.equals("Subtype"))
          headers.add(new Header(ColumnType.SUBTYPE, headers.size() + 1, true)) ;
        else if(display.equals("Entry Point"))
          headers.add(new Header(ColumnType.ENTRY_POINT, headers.size() + 1, true)) ;
        else if(display.equals("Start")) 
         headers.add(new Header(ColumnType.START, headers.size() + 1, true)) ;
        else if(display.equals("Stop"))
          headers.add(new Header(ColumnType.STOP, headers.size() + 1, true)) ;
        else if(display.equals("Strand"))
          headers.add(new Header(ColumnType.STRAND, headers.size() + 1, true)) ;
        else if(display.equals("Phase"))
          headers.add(new Header(ColumnType.PHASE, headers.size() + 1, true)) ;
        else if(display.equals("Score"))
          headers.add(new Header(ColumnType.SCORE, headers.size() + 1, true)) ;
        else if(display.equals("Query Start"))
          headers.add(new Header(ColumnType.QSTART, headers.size() + 1, true)) ;
        else if(display.equals("Query Stop"))
          headers.add(new Header(ColumnType.QSTOP, headers.size() + 1, true)) ;
        else if(display.equals("Sequence"))
          headers.add(new Header(ColumnType.SEQUENCE, headers.size() + 1, true)) ;
        else if(display.equals("Freeform Comments"))
          headers.add(new Header(ColumnType.COMMENT, headers.size() + 1, true)) ;
      }
    }
    // Now handle the sort string
    cut = 0 ;
    int pos = 1 ;
    while(sort.length() > 0)
    {
      cut = sort.indexOf(",", cut + 1) ;
      if(cut > 0 && sort.charAt(cut - 1) == '\\') continue ;

      // Grab the first column value (with escaped commas)
      String value = "" ;
      if(cut == -1)
      {
        value = sort ;
        sort = "" ;
      }
      else
      {
        value = sort.substring(0, cut) ;
        sort = sort.substring(cut + 1) ;
        cut = 0 ;
      }
      value = value.replaceAll("\\\\,", ",") ;

      // Create the header object
      // TODO - this could be simplified if we used JSON column descriptions
      //  and included the ColumnType.XXX_ID value along with the name.
      String display = value.substring(1) ;
      int colTypeId = ColumnType.UNDEFINED_ID ;
      if(value.charAt(0) == 'l')
      {
        if(display.equals("Edit Link")) colTypeId = ColumnType.UNDEFINED_ID ;
        else if(display.equals("Class")) colTypeId = ColumnType.CLASS_ID ;
        else if(display.equals("Name")) colTypeId = ColumnType.NAME_ID ;
        else if(display.equals("Type")) colTypeId = ColumnType.TYPE_ID ;
        else if(display.equals("Subtype")) colTypeId = ColumnType.SUBTYPE_ID ;
        else if(display.equals("Entry Point")) colTypeId = ColumnType.ENTRY_POINT_ID ;
        else if(display.equals("Start")) colTypeId = ColumnType.START_ID ;
        else if(display.equals("Stop")) colTypeId = ColumnType.STOP_ID ;
        else if(display.equals("Strand")) colTypeId = ColumnType.STRAND_ID ;
        else if(display.equals("Phase")) colTypeId = ColumnType.PHASE_ID ;
        else if(display.equals("Score")) colTypeId = ColumnType.SCORE_ID ;
        else if(display.equals("Query Start")) colTypeId = ColumnType.QSTART_ID ;
        else if(display.equals("Query Stop")) colTypeId = ColumnType.QSTOP_ID ;
        else if(display.equals("Sequence")) colTypeId = ColumnType.SEQUENCE_ID ;
        else if(display.equals("Freeform Comments")) colTypeId = ColumnType.COMMENT_ID ;
      }
      else
      {
        colTypeId = ColumnType.ATTRIBUTE_ID ;
      }

      if ((colTypeId == ColumnType.ATTRIBUTE_ID && containsHeader(colTypeId, display)) ||
        (containsHeader(colTypeId) && colTypeId != ColumnType.ATTRIBUTE_ID))
      {
        // Column is already used to display a value
        for(Header header : headers)
          if((header.getType().getId() == ColumnType.ATTRIBUTE_ID && value.charAt(0) == 'a') ||
             (header.getType().getId() != ColumnType.ATTRIBUTE_ID && value.charAt(0) == 'l'))
            if(header.toString().equals(display))
              header.setSortOrder(pos) ;
      }
      else
      {
        // Column has not been added.  Add an undisplayed column for sorting.
        if(colTypeId == ColumnType.UNDEFINED_ID)
          headers.add(new Header(ColumnType.EDIT, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.CLASS_ID)
          headers.add(new Header(ColumnType.CLASS, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.NAME_ID)
          headers.add(new Header(ColumnType.NAME, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.TYPE_ID)
          headers.add(new Header(ColumnType.TYPE, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.SUBTYPE_ID)
          headers.add(new Header(ColumnType.SUBTYPE, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.ENTRY_POINT_ID)
          headers.add(new Header(ColumnType.ENTRY_POINT, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.START_ID)
          headers.add(new Header(ColumnType.START, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.STOP_ID)
          headers.add(new Header(ColumnType.STOP, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.STRAND_ID)
          headers.add(new Header(ColumnType.STRAND, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.PHASE_ID)
          headers.add(new Header(ColumnType.PHASE, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.SCORE_ID)
          headers.add(new Header(ColumnType.SCORE, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.ATTRIBUTE_ID)
          headers.add(new Header(new ColumnType(display), headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.SEQUENCE_ID)
          headers.add(new Header(ColumnType.SEQUENCE, headers.size() + 1, false, pos)) ;
        else if(colTypeId == ColumnType.COMMENT_ID)
          headers.add(new Header(ColumnType.COMMENT, headers.size() + 1, false, pos)) ;
      }

      pos++ ;
    }

    // Add more additional headers if necessary for the Gbrowser link 
    if(containsHeader(ColumnType.NAME_ID))
    {
      // Invisible headers for the Entry Point, Start, and Stop so that we can
      // make the links back to the gbrowser
      if(!containsHeader(ColumnType.ENTRY_POINT_ID))
        headers.add(new Header(ColumnType.ENTRY_POINT, headers.size() + 1, false)) ;
      if(!containsHeader(ColumnType.START_ID))
        headers.add(new Header(ColumnType.START, headers.size() + 1, false)) ;
      if(!containsHeader(ColumnType.STOP_ID))
        headers.add(new Header(ColumnType.STOP, headers.size() + 1, false)) ;
    }

    //
    // Handle Entry Point limit
    //
    int epStart = 0, epStop = Integer.MAX_VALUE ;
    if(entryPoint != null)
    {
      try
      {
        if(entryPoint.lastIndexOf('-') != entryPoint.length() - 1)
          epStop = Integer.parseInt(entryPoint.substring(entryPoint.lastIndexOf('-') + 1)) ;
        entryPoint = entryPoint.substring(0, entryPoint.lastIndexOf('-')) ;
        if(entryPoint.indexOf(':') != entryPoint.length() - 1)
          epStart = Integer.parseInt(entryPoint.substring(entryPoint.indexOf(':') + 1)) ;
        entryPoint = entryPoint.substring(0, entryPoint.indexOf(':')) ;
        if(entryPoint.length() == 0) entryPoint = null ;
      }
      catch(NumberFormatException e)
      {
        entryPoint = null ;
      }
      catch(IndexOutOfBoundsException e)
      {
        entryPoint = null ;
      }
    }

    //
    // Outside loop for each DB
    //
    int dataPos = 0 ;
    int maxRows = GenboreeConfig.getIntConfigParam("tabularMaxRows", Integer.MAX_VALUE) ;
    if(maxRows <= 0) maxRows = Integer.MAX_VALUE ;
    data = new Row[Math.min(Utility.getAnnotationCount(db, tracks), maxRows)] ;
    for(int dbName = 0; dbName < dbNames.length; dbName++)
    {
      // Build the ftypeid list for this database
      StringBuilder ids = new StringBuilder() ;
      for(DbFtype track : (Vector<DbFtype>) dbMap.get(dbNames[dbName]))
        ids.append(ids.length() == 0 ? "" : ", ").append(track.getFtypeid()) ;

      // Create a Annotation Group Name map
      HashMap<String, Integer> nameMap = null ;
      if(groupMode != UNGROUPED)
        nameMap = new HashMap<String, Integer>() ;

      // Grab the database connection
      try
      {
        Connection conn = db.getConnection(dbNames[dbName]) ;
        if(conn != null)
        {
          Statement st = conn.createStatement() ;
          ResultSet rs = null ;

          // NOTE: The folowing line is very important.  With this setting
          //  the Statement will be put in a forward-only, read one row at
          //  a time mode.  This will allow us to handle much larger datasets
          //  than we previously could handle, and actually improve
          //  performance at that same time.
          st.setFetchSize(Integer.MIN_VALUE) ;

          // First deal with gclass (have to use SQL because DbFtype doesn't
          //  have this data by default).  We will skip this step if possible. 
          // This can be done independant of each Annotation element so we will
          //  do it first before grabbing fid's and related data...
          // Multiple group assignments will be displayed seperated by commas.
          HashMap<DbFtype, String> gclasses = new HashMap<DbFtype, String>() ;
          if (containsHeader(ColumnType.CLASS_ID))
          {
            String query = "SELECT f2g.ftypeid, g.gclass FROM gclass g, ftype2gclass f2g " ;
            query += "WHERE g.gid=f2g.gid AND f2g.ftypeid IN (" + ids + ")" ;
            rs = st.executeQuery(query) ;
            while(rs.next())
            {
              for(DbFtype track : (Vector<DbFtype>) dbMap.get(dbNames[dbName]))
              {
                if(track.getFtypeid() == rs.getInt(1))
                {
                  StringBuilder current = new StringBuilder() ;
                  if(gclasses.get(track) != null) 
                    current.append(gclasses.get(track)) ;
                  if(current.indexOf(rs.getString(2)) == -1)
                    current.append(current.length() == 0 ? "" : ", ").append(rs.getString(2)) ;
                  gclasses.put(track, current.toString()) ;
                }
              }
            }
          }

          // Now grab the simple data for all of our rows
          // (This does not include any AVPs, or the fidText rows)
          // NOTE: We limit the rows returned for memory usage purposes
          String query = "SELECT f.fid, f.gname, f.ftypeid, f.fstart, f.fstop, f.fscore, " ;
          query += "f.fstrand, f.fphase, f.ftarget_start, f.ftarget_stop, f.rid" ;
          if(entryPoint != null)
          {
            query += ", fr.refName FROM fdata2 f, fref fr " ;
            query += "WHERE f.ftypeid IN (" + ids + ") AND fr.rid=f.rid " ;
            query += "AND fr.refName='" + entryPoint + "' AND " ;
            query += "((f.fstart>=" + epStart + " AND f.fstart<=" + epStop + ") " ;
            query += "OR (f.fstop>=" + epStart + " AND f.fstop<=" + epStop + ") " ;
            query += "OR (f.fstart<" + epStart + " AND f.fstop>" + epStop + "))" ;
          }
          else if(containsHeader(ColumnType.ENTRY_POINT_ID))
          {
            query += ", fr.refName FROM fdata2 f, fref fr " ;
            query += "WHERE f.ftypeid IN (" + ids + ") AND fr.rid=f.rid " ;
          }
          else
          {
            query += " FROM fdata2 f WHERE f.ftypeid IN (" + ids + ") " ;
          }

          query += " LIMIT " + maxRows ;

long timer ;
timer = System.currentTimeMillis() ;

          rs = st.executeQuery(query) ;
System.err.println("tabular.Table - Query for Lff defs: " + (System.currentTimeMillis() - timer) + "ms") ;
timer = System.currentTimeMillis() ;
            
          // Now the inner loop
          while(rs.next())
          {
            // Handle this unexpected error
            if(dataPos >= data.length)
            {
              if(dataPos != maxRows)
                System.err.println("tabular.Table: Warning! Actual annotation count is " +
                  "greater than count gathered from ftypeCount table.") ;
              break ;
            }

            // Find the DbFtype for this annotation
            DbFtype current = null ;
            for(DbFtype track : (Vector<DbFtype>) dbMap.get(dbNames[dbName]))
              if(track.getFtypeid() == rs.getInt(3))
                current = track ;

            // Create a Row or get a reference to our group
            Row annotation = null ;
            String nameMapStr = rs.getString(2) + "-" + rs.getInt(3) + "-" + rs.getInt(11) ;
            if(groupMode != UNGROUPED && nameMap.get(nameMapStr) != null)
            {
              annotation = data[nameMap.get(nameMapStr)] ;
              annotation.addId(rs.getInt(1)) ;
            }
            else
            {
              // New annotation, or not part of a group yet
              annotation = new Row(dbName, rs.getInt(1), current.getFtypeid(), headers.size()) ;
              data[dataPos] = annotation ;
              dataPos++ ;
              size++ ;

              // Add to the name map, if we are grouped
              if(groupMode != UNGROUPED)
                nameMap.put(nameMapStr, dataPos - 1) ;
            }

            // Add any Lff default info to the Row (if displayed)
            for(Header head : headers)
            {
              if (head.type.getId() == ColumnType.UNDEFINED_ID || 
                head.type.getId() == ColumnType.ATTRIBUTE_ID ||
                head.type.getId() == ColumnType.SEQUENCE_ID ||
                head.type.getId() == ColumnType.COMMENT_ID) continue ;

              // Fill any values we can
              if(head.type.getId() == ColumnType.CLASS_ID)
                annotation.fill(gclasses.get(current), head, groupMode) ;
              else if(head.type.getId() == ColumnType.NAME_ID)
                annotation.fill(rs.getString(2), head) ;
              else if(head.type.getId() == ColumnType.TYPE_ID)
                annotation.fill(current.getFmethod(), head, groupMode) ;
              else if(head.type.getId() == ColumnType.SUBTYPE_ID)
                annotation.fill(current.getFsource(), head, groupMode) ;
              else if(head.type.getId() == ColumnType.START_ID)
                annotation.fill(new Integer(rs.getInt(4)), head, groupMode) ;
              else if(head.type.getId() == ColumnType.STOP_ID)
                annotation.fill(new Integer(rs.getInt(5)), head, groupMode) ;
              else if(head.type.getId() == ColumnType.SCORE_ID)
                annotation.fill(rs.getDouble(6), head, groupMode) ;
              else if(head.type.getId() == ColumnType.STRAND_ID)
                annotation.fill(new Character(rs.getString(7).charAt(0)), head) ;
              else if(head.type.getId() == ColumnType.PHASE_ID)
                annotation.fill(new Integer(rs.getInt(8)), head, groupMode) ;
              else if(head.type.getId() == ColumnType.QSTART_ID)
                annotation.fill(new Integer(rs.getInt(9)), head, groupMode) ;
              else if(head.type.getId() == ColumnType.QSTOP_ID)
                annotation.fill(new Integer(rs.getInt(10)), head, groupMode) ;
              else if(head.type.getId() == ColumnType.ENTRY_POINT_ID)
                annotation.fill(rs.getString(12), head, groupMode) ;
            }
          }
System.err.println("tabular.Table - Fill Lff defs: " + (System.currentTimeMillis() - timer) + "ms") ;
System.err.println("tabular.Table - Num fids: " + getRowCount()) ;

          // Close our Statement
          st.close() ;
        }
        else
        {
          System.err.println("tabular.Table: Cannot get DB connection to : " + dbNames[dbName]) ; 
        }
      }
      catch (SQLException e)
      {
        System.err.println("tabular.Table: Problem creating Table from DB (" + dbNames[dbName] + "):" + e) ;
      }
    }

    // Table is unsorted after initialization (if a sort was specified)
    sorted = (sort == null) ;

    // Handle empty rows (probably due to grouping)
    // NOTE: This is not peak memory efficient and could be avoided if we modify
    //   TabularComparator to support pushing null Rows to the bottom of the
    //   list during any Arrays.sort() call.  If peak memory usage continues to
    //   be an issue this should be one of the first changes implemented.
    if (size != data.length)
    {
      Row[] copy = new Row[size] ;
      for(int i = 0; i < size; i++)
        copy[i] = data[i] ;
      data = copy ;
    }
  }

  /**
   * Grab the {@link Header} object that represents the specified
   * column.
   * @param column
   *   The 1-based number of the column.
   * @return
   *   The Header object for that column, or null for an invalid column number.
   */
  public Header getHeader(int column)
  {
    if(column <= 0 || column > headers.size()) return null ;

    return headers.get(column - 1) ;
  }

  /**
   * Get the database name String for the supplied row.  Since {@link Row}s
   * store only an index to the internal dbNames array in the Table, in order
   * to get the actual database name you must query the {@link Table} object.
   * @param targetRow
   *   The target Row object for which the db name is desired.
   * @return
   *   The database name from which the targetRow object was created.
   */
  public String getDb(Row targetRow)
  {
    return dbNames[targetRow.getDb()] ;
  }

  /**
   * Get the Row object for the specified row of the table.
   * @param row
   *   The 0-based index of a row from this Table object.
   * @return
   *   The Row object or null for an invalid Row index.
   */
  public Row getRow(int row)
  {
    if(row < 0 || row >= getRowCount()) return null ;
    // TODO - if(!isFilled(row)) fill(row, row) ;
    return data[row] ;
  }

  /**
   * Directly grab a value for a cell from this Table.
   * @param row
   *   The 0-based row index of the cell.
   * @param col
   *   The 1-based column number for this cell.
   * @return
   *   A String representing the value of the cell, not necessarily the actual
   *   data object stored in the Table, but a String representation of that
   *   value that is suitable for display.
   */
  public String getValue(int row, int col)
  {
    if(row < 0 || row >= getRowCount()) return null ;
    if(col <= 0 || col > headers.size()) return null ;
    if(data[row] == null) return null ;
    // TODO - if(!isFilled(row)) fill(row, row) ;
    return data[row].get(col) ;
  }

  /*
   * Checks a row to see if a fill() has already been called for a Range that
   * contains that row.
   */
  private boolean isFilled(int row)
  {
    for(Range range : stack)
      if(range.contains(new Range(row, row)))
        return true ;
    return false ;
  }

  /**
   * The number of {@link Row}s in this Table.
   * @return
   *   The number of {@link Row}s in this Table.
   */
  public int getRowCount()
  {
    return size ;
  }

  /**
   * The number of columns in this Table, including columns that are used only
   * to store values for the sorting order, not for display.
   * @return
   *   The total number of columns in this Table including hidden ones.
   */
  public int getColumnCount()
  {
    return headers.size() ;
  }

  /**
   * The number of visible columns in this Table.
   * @return
   *   The number of visible columns in this Table, not including any columns
   *   that are not marked for display.
   */
  public int getVisibleColumnCount()
  {
    int total = 0;
    for(Header header : headers)
      if(header.isDisplayed())
        total++ ;

    return total ;
  }

  /**
   * Generate the query portion of a URL that can generate the same data that
   * is currently stored by this Table.
   * @return 
   *   A URL that can be used to create a Table object using the 
   *   tabularDisplay.jsp page.
   *   <p>Note: this url will refer to the original sort order that was used
   *   when creating this Table.  That sort order may have changed before the
   *   call to this method, so the data might be in a different order than the
   *   current object.</p>
   *   <p>Note: This url deliberatly drops the Refseq parameter from this url.
   *   That parameter must be supplied externally to this method.</p>
   */
  public String getQueryUrl()
  {
    return queryUrl ;
  }

  /**
   * Determine if a certain type of column ({@link ColumnType}) is in use by
   * this {@link Table} object.  The column may or may not be displayed.
   * @param columnId
   *   The id for the column type as defined by the constants in the
   *   {@link ColumnType} class.
   * @return
   *   True if this type of column is used, false if not.
   */
  public boolean containsHeader(int columnId)
  {
    for(Header header : headers)
      if(header.type.getId() == columnId)
        return true ;
    
    return false ;
  }

  /**
   * Determine if a certain type of column ({@link ColumnType}) is in use by
   * this {@link Table} object and has the same attribute name as the specified
   * String.  This is useful with the ATTRIBUTE_ID type of column because many
   * attribute names can be used for this type of column.  The column may or
   * may not be displayed.
   * @param columnId
   *   The id for the column type as defined by the constants in the
   *   {@link ColumnType} class.
   * @param name
   *   The name (display name) of the attribute displayed by the column.
   * @return
   *   True if this type of column is used and has a matching attribute name.
   */
  public boolean containsHeader(int columnId, String name)
  {
    for(Header header : headers)
      if(header.type.getId() == columnId && header.type.getDisplayName().equals(name))
        return true ;
    
    return false ;
  }

  /**
   * Impose a new sorting order other than the order passed to the constructor
   * during Table creation.  This new order will retain the previous sort and
   * only add new attributes to the start of the sort order.
   * @param column
   *   The column number (1-based) of the attribute to use for sorting.
   * @param reverse
   *   Perform a descending sort instead of the default ascending sort.
   */
  public void sort(int column, boolean reverse)
  {
    // Set the sort direction
    sorted = sorted && (reverseSort == reverse) ;
    reverseSort = reverse ;

    // Determine if we need to change the sort order, or add a new sort col
    boolean newColumn = !headers.get(column - 1).isSortedOn() ;
    boolean newOrder = !newColumn && headers.get(column - 1).getSortOrder() != 1 ;
    sorted = sorted && !newColumn && !newOrder ;

    if(newOrder)
    {
      // Change the sort order
      int old = headers.get(column - 1).getSortOrder() ;
      headers.get(column - 1).setSortOrder(1) ;

      // Percolate the change
      for(Header head : headers)
        if(head.isSortedOn() && head.getSortOrder() < old && head.getColumn() != column)
          head.setSortOrder(head.getSortOrder() + 1) ;
    }
    else if(newColumn)
    {
      for(Header head : headers)
        if(head.isSortedOn())
          head.setSortOrder(head.getSortOrder() + 1) ;
      headers.get(column - 1).setSortOrder(1) ;
    }
  }

  /*
   * Helper method that actually performs the work necessary to sort the Table
   * according to the sorting order that had been specified at Table creation
   * time as well as by calling the sort(int, bool) method after Table 
   * creation.
   */
  private void doSort(DBAgent db)
  {
    // Clear the Stack (Range values will not map correctly after sort)
    for(Range range : stack)
      for(int row = range.start; row < range.stop; row++)
        if(data[row] != null)
          data[row].clear(headers) ;
    stack = new Vector<Range>() ;

    // Gather the sort columns data for all rows
    // First setup the attribute names we must gather for sorting
long timer = System.currentTimeMillis() ;
    StringBuilder atts = new StringBuilder() ;
    for(Header header : headers)
      if(header.type.getId() == ColumnType.ATTRIBUTE_ID && header.isSortedOn() && !header.isFilled())
        atts.append((atts.length() == 0 ? "" : ", ") + "'" + header.toString() + "'") ;

    // Only gather data if we ned to (this is an expensive SQL join)
    if(atts.length() > 0)
    {
      // Now loop through each db, gathering AVP data for each Row
      HashMap<Integer, Integer> map = new HashMap<Integer, Integer>() ;
      for(int dbName = 0; dbName < dbNames.length; dbName++)
      {
        // First build a list of fids, and a map back to their respective row index
        StringBuilder fids = new StringBuilder() ;
        for(int rowPos = 0; rowPos < getRowCount(); rowPos++)
        {
          // Skip this fid
          if(data[rowPos].getDb() != dbName) continue ;

          // Add this fid(s) whild building the fid -> row map
          for(int id : data[rowPos].getIds())
          {
            fids.append((fids.length() == 0 ? "" : ",")).append(id) ;
            map.put(id, rowPos) ;
          }
        }

        // Now the actual SQL
        try
        {
          Connection conn = db.getConnection(dbNames[dbName]) ;
          if(conn != null && fids.length() > 0)
          {
            String query = "SELECT f2a.fid, an.name, av.value " ;
            query += "FROM attNames an, attValues av, fid2attribute f2a " ;
            query += "WHERE an.name IN (" + atts + ") AND f2a.fid IN (" + fids + ") AND " ;
            query += "f2a.attNameId = an.attNameId AND f2a.attValueId = av.attValueId " ;
            Statement st = conn.createStatement() ;

            ResultSet rs = st.executeQuery(query) ;
            while(rs.next())
            {
              // NOTE: Could speed up with Hashmap for Headers
              for(Header head : headers)
              {
                if(head.type.getId() != ColumnType.ATTRIBUTE_ID) continue ;

                if(head.toString().equals(rs.getString(2)))
                {
                  // First test for data type (String/Int/Double)
                  boolean done = false;
                  try
                  {
                    if(!done)
                    {
                      data[map.get(rs.getInt(1))].fill(Integer.parseInt(rs.getString(3)), head, groupMode) ;
                      done = true ;
                    }
                  }
                  catch (NumberFormatException e)
                  {
                    done = false ;
                  }
                  try
                  {
                    if(!done) 
                    {
                      data[map.get(rs.getInt(1))].fill(Double.parseDouble(rs.getString(3)), head, groupMode) ;
                      done = true ;
                    }
                  }
                  catch (NumberFormatException e)
                  {
                    done = false ;
                  }

                  // Not Int or Double, must be String
                  if(!done) data[map.get(rs.getInt(1))].fill(rs.getString(3), head, groupMode) ;
                  break ;
                }
              }
            }

            // Done with all queries
            st.close() ;
          }
          else if(conn == null)
          {
            System.err.println("tabular.Table.doSort(): Cannot get DB connection to : " + dbName) ; 
          }
        }
        catch (SQLException e)
        {
          System.err.println("tabular.Table.doSort(): Problem gathering AVP sort info from DB (" +
            dbName + "):" + e) ;
        }
      }
    }
System.err.println("tabular.Table - get sort AVPs: " + (System.currentTimeMillis() - timer) + "ms") ;

    // Perform the actual sort
timer = System.currentTimeMillis() ;
    Arrays.sort(data, new TabularComparator(headers, reverseSort)) ;
System.err.println("tabular.Table - Arrays.sort: " + (System.currentTimeMillis() - timer) + "ms") ;

    // Keep track of our sort related variables
    sorted = true ;
    for(Header header : headers)
      if(header.isSortedOn())
        header.setFilled(true) ;
  }

  /**
   * Gather all data including AVPs for the specified Rows.  The Table will
   * lazily gather AVP data for memory and performance concerns, so a Row
   * object may not always contain all of its data, unless it has been first
   * 'filled' by this method.
   * @param start
   *   The 0-based index of the first Row object to fill with all of its data.
   * @param stop
   *   The 0-based index of 1 + the last Row object to fill (just like the
   *   Java substring arguments.
   */
  public synchronized void fill(DBAgent db, int start, int stop)
  {
    if(data.length == 0) return ;

    // Always sort data prior to allowing any fills()
    if(!sorted) doSort(db) ;

    // Fix invalid Ranges
    if(start < 0) start = 0 ;
    if(stop >= getRowCount()) stop = getRowCount() - 1 ;

    // First check if this Range has already been filled
    Range newRange = new Range(start, stop) ;
    System.err.println("tabular.Table.fill(): Filling " + newRange.start + " to " + newRange.stop) ;
    for(Range range : stack)
    {
      if(range.contains(newRange))
      {
        // Move this Range to the top of the Stack
        stack.remove(range) ;
        stack.insertElementAt(range, 0) ;
        System.err.println("tabular.Table.fill(): Range already filled, moved to top of Stack.") ;
        return ;
      }
    }

    // Now fill this entire Range
long timer = System.currentTimeMillis() ;
    doFill(db, newRange.start, newRange.stop) ;
System.err.println("tabular.Table.fill(): doFill() took " + (System.currentTimeMillis() - timer) + " ms") ;

    // Add this Range to the Stack and clear() as necessary
    stack.insertElementAt(newRange, 0) ;
    if(stack.size() > MAX_STACK)
    {
      Range removed = stack.remove(MAX_STACK) ;
      System.err.println("tabular.Table.fill(): Stack full.  Clearing rows " + 
        removed.start + " to " + removed.stop) ;
      for(int pos = removed.start; pos <= removed.stop; pos++)
        data[pos].clear(headers) ;
    }
    
    // Report memory usage for debugging
    System.err.println("tabular.Table: Used Memory: " + 
      org.genboree.util.Util.commify(org.genboree.util.MemoryUtil.usedMemory()/1024/1024) + "MB") ;
  }

  /*
   * Helper method to fill a set of Rows.  Performs the required SQL query
   * to obtain any AVPs and information from the fidText table (seq, comments).
   */
  private void doFill(DBAgent db, int start, int stop)
  {
    // Grab all the missing data from the attValues table
    StringBuilder atts = new StringBuilder() ;
    for(Header header : headers)
      if(header.type.getId() == ColumnType.ATTRIBUTE_ID  && !header.isSortedOn())
        atts.append((atts.length() == 0 ? "" : ", ") + "'" + header.toString() + "'") ;

    try
    {
      for(int dbName = 0; dbName < dbNames.length; dbName++)
      {
        Connection conn = db.getConnection(dbNames[dbName]) ;
        if(conn == null)
        {
          System.err.println("tabular.Table.doFill(): Cannot find connection for " + dbNames[dbName]) ;
          return ;
        }
        Statement st = null ;

        // Map fids to row positions
        HashMap<Integer, Integer> map = new HashMap<Integer, Integer>() ;
        StringBuilder ids = new StringBuilder() ;
        for(int target = start; target <= stop; target++)
        {
          if(data[target].getDb() == dbName)
          {
            for(int id : data[target].getIds())
            {
              ids.append((ids.length() == 0 ? "" : ",")).append(id) ;
              map.put(id, target) ;
            }
          }
        }

        // Grab info from the AVP tables (if required)
        if(atts.length() > 0 && ids.length() > 0)
        {
          String query = "SELECT f2a.fid, an.name, av.value " ;
          query += "FROM attNames an, attValues av, fid2attribute f2a " ;
          query += "WHERE an.name IN (" + atts + ") AND f2a.fid IN (" + ids + ") AND " ;
          query += "f2a.attNameId = an.attNameId AND f2a.attValueId = av.attValueId " ;
          if(st == null) st = conn.createStatement() ;
          ResultSet rs = st.executeQuery(query) ;
          
          while(rs.next())
          {
            for(Header head : headers)
            {
              if(head.type.getId() != ColumnType.ATTRIBUTE_ID) continue ;

              if(head.toString().equals(rs.getString(2)))
              {
                // Use proper type detection for any AVP rows
                boolean done = false;
                try
                {
                  if(!done)
                  {
                    data[map.get(rs.getInt(1))].fill(Integer.parseInt(rs.getString(3)), head, groupMode) ;
                    done = true ;
                  }
                }
                catch (NumberFormatException e)
                {
                  done = false ;
                }
                try
                {
                  if(!done) 
                  {
                    data[map.get(rs.getInt(1))].fill(Double.parseDouble(rs.getString(3)), head, groupMode) ;
                    done = true ;
                  }
                }
                catch (NumberFormatException e)
                {
                  done = false ;
                }

                // Not Int or Double, must be String
                if(!done) data[map.get(rs.getInt(1))].fill(rs.getString(3), head, groupMode) ;
                break ;  // Out of headers loop
              }
            }
          }
        }

        // Grab the sequence and comments (if required)
        if(containsHeader(ColumnType.SEQUENCE_ID) ||
           containsHeader(ColumnType.COMMENT_ID))
        {
          String query = "SELECT fid, ftypeid, textType, text FROM fidText WHERE fid IN (" + ids + ")" ;
          if(st == null) st = conn.createStatement() ;
          ResultSet rs = st.executeQuery(query) ;

          String seq = "", comment = "" ;
          while(rs.next())
          {
            if(rs.getString(3).equals("s"))
            {
              for(Header head : headers)
              {
                if(head.type.getId() == ColumnType.SEQUENCE_ID)
                {
                  data[map.get(rs.getInt(1))].fill(rs.getString(4), head, groupMode) ;
                  break ; // Out of headers loop
                }
              }
            }
            else if(rs.getString(3).equals("t") && 
              rs.getInt(2) == data[map.get(rs.getInt(1))].getFtypeId())
            {
              for(Header head : headers)
              {
                if(head.type.getId() == ColumnType.COMMENT_ID)
                {
                  data[map.get(rs.getInt(1))].fill(rs.getString(4), head, groupMode) ;
                  break ; // Out of headers loop
                }
              }
            }
          }
        }

        // Close our Statement
        if(st != null) st.close() ;
      }
    }
    catch (SQLException e)
    {
      System.err.println("tabular.Table.doFill(): DB error while filling rows: " + e) ;
    }
  }

  /**
   * Delete all cached data from this Table Object.  Due to an odd problem with
   * page scope variables staying resident in memory until the session is
   * removed, this method was implemented to allow for the removal of all
   * cached data stored by this Table Object.  Obviously, this method should
   * only be called immediately before a Table Object is discarded.
   */
  public void destroy()
  {
    data = new Row[0] ;
    size = 0 ;
  }

  /*
   * Inner class that is used to keep track of the rows in the Table that have
   * been filled or not, for reduction of memory footprint.
   */
  class Range
  {
    private int start ;
    private int stop ;

    public Range(int start, int stop)
    {
      this.start = (start <= stop) ? start : stop ;
      this.stop = (start <= stop) ? stop : start ;
    }

    public int getStart() 
    {
      return start ; 
    }
    public int getStop()
    {
      return stop ;
    }

    public boolean contains(Range r)
    {
      return (r.start >= start && r.stop <= stop) ;
    }
  }
}
