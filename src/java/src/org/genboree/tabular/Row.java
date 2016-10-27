package org.genboree.tabular ;

import java.util.Vector ;
import java.util.ArrayList ;
import org.genboree.dbaccess.DbFtype ;

/**
 * This class stores the tabular data representing a single Annotation. It is
 * used heavily by the {@link Table} class to provide lazy loading capabilities
 * and memory management techniques.
 */
public class Row
{
  private int db;
  private int fid ;
  private ArrayList<Integer> fids ;
  private int trackId ;

  // Protected so the TabularComparator can directly access the array
  protected Object[] cells ;

  /**
   * Create a Row object.  The database name, fid, group name, {@link DbFtype}
   * (for track information), and gclass are required to define a row.  This
   * data constitutes the smallest amount of information that must be cached
   * for every piece of annotation (row in a Tabular display).  The remainder
   * of the data for this Row can be grabbed from the database during the
   * fill command.
   * @param dbIndex
   *   The index representing the database name to which this Row belongs.  The
   *   actual db name is stored in an array in the Table object that created
   *   this Row object.
   * @param id
   *   The fid of this row in the database.
   * @param ftypeId
   *   The internal DB id for the ftype of this row.
   * @param columns
   *   The number of columns for which this Row will store data.
   */
  public Row(int dbIndex, int id, int ftypeId, int columns)
  {
    db = dbIndex ;
    fid = id ;
    fids = null ;
    trackId = ftypeId ;

    cells = new Object[columns] ;
    for(int pos = 0; pos < columns; pos++) cells[pos] = null ;
  }

  public int getDb()
  {
    return db ;
  }

  public int getId()
  {
    return fid ;
  }

  public int getFtypeId()
  {
    return trackId ;
  }

  /** 
   * Add a fdata2 ID (fid) to the group represented by this Row.  A call to
   * this method will effectively turn this Row into an Annotation group,
   * resulting in the isGrouped() method always returning true on this object.
   * @param fid
   *   The new fid to add to the main fid used when creating this Row object.
   */
  public void addId(int fid)
  {
    if (fids == null)
      fids = new ArrayList<Integer>() ;
    fids.add(fid) ;
  }
  
  /**
   * Get a list of all of the fids for this Row.  This will include the id
   * specified by the getId() method.
   * @return
   *   All of the fids for the data represented in this Row.  In an ungrouped
   *   Row, this method will return an array of size 1.  In a grouped Row, this
   *   array will be the size of all of the Annotation in this group.
   */
  public int[] getIds()
  {
    int[] ids;
    if (fids != null)
      ids = new int[fids.size() + 1] ;
    else
      ids = new int[1] ;

    ids[0] = getId() ;
    if(fids != null)
      for(int fid = 0; fid < fids.size(); fid++)
        ids[fid + 1] = fids.get(fid) ;

    return ids ;
  }

  /**
   * Determine if this Row object represents an Annotation group or a single
   * piece of annotation.
   * @return
   *   False, unless the addId(int) method has been called on this object to
   *   assign a second fid to this Row.
   */
  public boolean isGrouped()
  {
    return (fids != null) ;
  }


  /**
   * Fill in the value of a single cell in this Row object.  This method is
   * used internally by the Table class when building the original Row objects
   * as well as when Rows are actually displayed (any 'clear'ed data will need
   * to be re-filled).  The supplied data value will replace any existing value
   * previously assigned to the same cell.
   */
  protected void fill(Object value, Header header)
  {
    if(header.column <= 0 || header.column > cells.length)
      throw new IllegalArgumentException("Invalid column value: " + header.column) ;
    // NOTE: Because of performance concerns, this check is not necessary
    // In order to ensure minimum memory usage, however, empty Strings should
    // not be assigned to elements, null should be used instead.
    //if(value != null && value.trim().length() == 0) cells[header.column - 1] = null ;
    //else cells[header.column - 1] = value ;
    cells[header.column - 1] = value ;
  }

  /**
   * Fill in the value of a single cell in this Row object.  This method is
   * used internally by the Table class when building the original Row objects
   * as well as when Rows are actually displayed (any 'clear'ed data will need
   * to be re-filled).
   *
   * This version of the method will perform a group-safe fill.  What this
   * means is that the method will use the groupMode variable as a hint for how
   * to handle each column differently when representing a group.  The details
   * of this are in the Genboree Help section, but basically AVPs and a few
   * other columns will be represented by either the String "various" when in
   * terse group mode, or a String[] when in verbose mode.  In ungrouped mode,
   * the supplied value will replace any previously set value for the same cell.
   */
  protected void fill(Object value, Header header, int groupMode)
  {
    if(header.column <= 0 || header.column > cells.length)
      throw new IllegalArgumentException("Invalid column value: " + header.column) ;

    // First deal with magic for ATTRIBUTE_ID columns
    if(header.type.getId() == ColumnType.ATTRIBUTE_ID && header.dataType != Header.MIXED)
    {
      if(header.dataType == Header.UNKNOWN)
      {
        if(value instanceof Double) header.dataType = Header.DOUBLE ;
        else if(value instanceof Integer) header.dataType = Header.INTEGER ;
        else header.dataType = Header.STRING ;
      }
      else if((header.dataType == Header.INTEGER && !(value instanceof Integer)) ||
        (header.dataType == Header.DOUBLE && !(value instanceof Double)) ||
        (header.dataType == Header.STRING && !(value instanceof String)))
      {
        header.dataType = Header.MIXED ;
      }
    }

    // No value set yet, use the supplied value
    if(cells[header.column - 1] == null)
    {
      cells[header.column - 1] = value ;
      return ;
    }

    // Deal with special cases for group mode
    if(groupMode == Table.UNGROUPED)
    {
      cells[header.column - 1] = value ;
    }
    else
    {
      if(header.type.getId() == ColumnType.START_ID || header.type.getId() == ColumnType.STOP_ID
        || header.type.getId() == ColumnType.QSTART_ID || header.type.getId() == ColumnType.QSTOP_ID)
      {
        // Special cases for starts and stops (use most outside boundaries)
        Integer intObj = (Integer) value ;
        if(header.type.getId() == ColumnType.START_ID || header.type.getId() == ColumnType.QSTART_ID)
        {
          // Use the smallest start value
          if(intObj.compareTo((Integer) cells[header.column - 1]) < 0)
            cells[header.column - 1] = value ;
        }
        else if(header.type.getId() == ColumnType.STOP_ID || header.type.getId() == ColumnType.QSTOP_ID)
        {
          // Use the largest stop value
          if(intObj.compareTo((Integer) cells[header.column - 1]) > 0)
            cells[header.column - 1] = value ;
        }
      }
      else if(header.type.getId() == ColumnType.SCORE_ID)
      {
        // Running average assuming current score is based on (# fids - 1)
        double current = ((Double) cells[header.column - 1]).doubleValue() ;
        double newVal = ((Double) value).doubleValue() ;
        int size = 1 ;
        if(fids != null) size = fids.size() + 1 ;
        cells[header.column - 1] = new Double((current * (size - 1) + newVal) / size) ;
      }
      else if(groupMode == Table.GROUPED_VERBOSE)
      {
        if(header.type.getId() == ColumnType.CLASS_ID || header.type.getId() == ColumnType.ATTRIBUTE_ID ||
          header.type.getId() == ColumnType.SEQUENCE_ID || header.type.getId() == ColumnType.COMMENT_ID ||
          header.type.getId() == ColumnType.TYPE_ID || header.type.getId() == ColumnType.SUBTYPE_ID ||
          header.type.getId() == ColumnType.ENTRY_POINT_ID || header.type.getId() == ColumnType.PHASE_ID)
        {
          // First determine if we must add a new value
          boolean add = true ;
          int size = 2 ;
          if(cells[header.column - 1] instanceof String)
          {
            add = !cells[header.column - 1].equals(value.toString()) ;
          }
          else if(cells[header.column - 1] instanceof String[])
          {
            String[] values = (String[]) cells[header.column - 1] ;
            size = 1 + values.length ;
            for(int pos = 0; pos < values.length; pos++)
              add = add && !(values[pos].equals(value.toString())) ;
          }
          else if(cells[header.column - 1] instanceof Double 
            || cells[header.column - 1] instanceof Integer)
          {
            if(!cells[header.column - 1].toString().equals(value.toString()))
            {
              // Convert existing value into a String for the STRING_ARRAY code
              cells[header.column - 1] = cells[header.column - 1].toString() ;
              header.dataType = Header.MIXED ;
              add = true ;
            }
            else
            {
              add = false ;
            }
          }

          // No new value, just a repeat
          if(!add) return ;

          // New value so swap to a String[], unless already MIXED
          if(header.dataType != Header.MIXED) header.dataType = Header.STRING_ARRAY ;

          // Create a String[] from the values
          String[] newCell = new String[size] ;
          newCell[0] = value.toString() ;
          if(cells[header.column - 1] instanceof String)
          {
            if(((String)cells[header.column - 1]).compareTo(value.toString()) <= 0)
            {
              newCell[0] = (String) cells[header.column - 1] ;
              newCell[1] = value.toString() ;
            }
            else
            {
              newCell[0] = value.toString() ;
              newCell[1] = (String) cells[header.column - 1] ;
            }
          }
          else if(cells[header.column - 1] instanceof String[])
          {
            // Insertion sort
            boolean inserted = false ;
            String[] values = (String[]) cells[header.column - 1] ;
            for(int pos = 0; pos < values.length; pos++)
            {
              if(!inserted && values[pos].compareTo(value.toString()) >= 0)
              {
                newCell[pos] = value.toString() ;
                inserted = true ;
              }
              newCell[pos + (inserted ? 1 : 0)] = values[pos] ;
            }
            if(!inserted) newCell[values.length] = value.toString() ;
          }

          // Assign the new array
          cells[header.column - 1] = newCell ;
        }
      }
      else if(groupMode == Table.GROUPED_TERSE)
      {
        if(header.type.getId() == ColumnType.CLASS_ID || header.type.getId() == ColumnType.ATTRIBUTE_ID ||
          header.type.getId() == ColumnType.SEQUENCE_ID || header.type.getId() == ColumnType.COMMENT_ID ||
          header.type.getId() == ColumnType.TYPE_ID || header.type.getId() == ColumnType.SUBTYPE_ID ||
          header.type.getId() == ColumnType.ENTRY_POINT_ID || header.type.getId() == ColumnType.PHASE_ID)
        {
          if(!cells[header.column - 1].equals(value))
          {
            // Set the varies attribute
            cells[header.column - 1] = "{varies}" ;

            // Do the datatype magic for ATTRIBUTE columns
            if(header.dataType != Header.STRING) header.dataType = Header.MIXED ;
          }
        }
      }
    }
  }

  /*
   * Remove any non-permanent cell data to save on memory usage.  Calls to this
   * method are controlled by the 'Ranges' of "active" data stored in the Table
   * object that owns this Row.
   * A cell is considered permanent if it is part of the sort order for this
   * Table, or if it is any of the non-AVP values except for "Sequence" and
   * "Freeform Comments".
   */
  protected void clear(Vector<Header> headers)
  {
    Object[] newCells = new Object[cells.length] ;
    for(int pos = 0; pos < newCells.length; pos++)
    {
      Header header = headers.get(pos) ;
      boolean permanent = (header.type.getId() != ColumnType.ATTRIBUTE_ID && 
        header.type.getId() != ColumnType.SEQUENCE_ID &&
        header.type.getId() != ColumnType.COMMENT_ID) ||
        header.isSortedOn() ;
      newCells[pos] = permanent ? cells[pos] : null ;
    }
    cells = newCells ;
  }

  /**
   * Get the data value for the specified cells (1-based).  This method will
   * automatically handle the csv concatentation for multiple values in a
   * verbosely grouped row.
   * @param column
   *  The column number of the cell to retreive data from, starting at 1.
   * @return
   *  If a bad column value is specified, null is returned.  If column is a
   *  valid value, an empty String will be returned, but never null.
   */
  public String get(int column)
  {
    if(column <= 0 || column > cells.length) return null ;

    if(cells[column - 1] instanceof String[])
    {
      String[] values = (String[]) cells[column - 1] ;
      StringBuilder out = new StringBuilder() ;
      for(int pos = 0; pos < values.length; pos++)
        out.append(out.length() == 0 ? "" : ", ").append(values[pos]) ;
      return out.toString() ;
    }
    else
    {
      return (cells[column - 1] == null ? "" : cells[column - 1].toString()) ;
    }
  }
}
