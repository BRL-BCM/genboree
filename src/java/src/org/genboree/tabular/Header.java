package org.genboree.tabular ;

/**
 * This class is used to define the headers of a tabular layout.  It is used
 * heavily by the {@link Table} class when defining {@link Row}s and filling
 * them with the proper data in the proper order. Column and sort orders are
 * both 1-based values.  Anything under 1 is used to indicate that this Header
 * is not displayed or sorted respectively.
 */
public class Header
{
  private boolean visible ;
  private int sort ;
  private boolean filled ;

  // For direct access by the Row class
  protected int column ;
  protected int dataType ;
  protected ColumnType type ;

  // Constants for type enumeration
  public static final int STRING = 0 ;
  public static final int INTEGER = 1 ;
  public static final int DOUBLE = 2 ;
  public static final int STRAND = 3 ;
  public static final int CHROMOSOME = 4 ;
  public static final int STRING_ARRAY = 5 ;
  public static final int MIXED = 6 ;
  public static final int UNKNOWN = 7 ;

  public Header(ColumnType type, int col, boolean visible)
  {
    this(type, col, visible, -1) ;
  }

  public Header(ColumnType type, int col, boolean visible, int sortOrder)
  {
    this.type = type ;
    this.column = col ;
    this.visible = visible ;
    this.sort = sortOrder ;
    filled = false ;

    // Now define the data type used to represent the data for this column.
    // This will depend on the ColumnType of this column.
    if(type.getId() == ColumnType.ENTRY_POINT_ID) dataType = CHROMOSOME ;
    else if(type.getId() == ColumnType.START_ID) dataType = INTEGER ;
    else if(type.getId() == ColumnType.STOP_ID) dataType = INTEGER ;
    else if(type.getId() == ColumnType.STRAND_ID) dataType = STRAND ;
    else if(type.getId() == ColumnType.PHASE_ID) dataType = INTEGER ;
    else if(type.getId() == ColumnType.SCORE_ID) dataType = DOUBLE ;
    else if(type.getId() == ColumnType.QSTART_ID) dataType = INTEGER ;
    else if(type.getId() == ColumnType.QSTOP_ID) dataType = INTEGER ;
    else if(type.getId() == ColumnType.ATTRIBUTE_ID) dataType = UNKNOWN ;
    else dataType = STRING ;
  }

  public boolean isDisplayed()
  {
    return visible ;
  }

  public int getColumn()
  {
    return column ;
  }

  public boolean isSortedOn()
  {
    return (sort > 0) ;
  }

  public int getSortOrder()
  {
    return sort ;
  }

  public ColumnType getType()
  {
    return type ;
  }

  public int getDataType()
  {
    return dataType ;
  }

  public boolean isFilled()
  {
    return filled ;
  }

  public void setFilled(boolean fill)
  {
    filled = fill ;
  }

  public void setSortOrder(int sortOrder)
  {
    sort = sortOrder ;
  }

  public String toString()
  {
    return type.getDisplayName() ;
  }
}
