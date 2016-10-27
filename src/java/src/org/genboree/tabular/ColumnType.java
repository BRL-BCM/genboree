package org.genboree.tabular ;

/**
 * The class is a utility class for the tabular layout feature, providing a
 * single location for the data associated with the standard LFF columns.  This
 * class is tailored to its use within the org.genboree.tabular package, so it
 * will not be very useful outside of that package because of the narrow focus
 * during design of this class.
 * <p>Created on: September 11, 2008</p>
 * @author sgdavis@bioneos.com
 */
public class ColumnType
{
  private String display ;
  private String table ;
  private String field ;
  private int col ;
  private boolean required ;
  private boolean sortable ;

  // Constants
  public static final int UNDEFINED_ID = 0 ;
  public static final int CLASS_ID = 1 ;
  public static final int NAME_ID = 2 ;
  public static final int TYPE_ID = 3 ;
  public static final int SUBTYPE_ID = 4 ;
  public static final int ENTRY_POINT_ID = 5 ;
  public static final int START_ID = 6 ;
  public static final int STOP_ID = 7 ;
  public static final int STRAND_ID = 8 ;
  public static final int PHASE_ID = 9 ;
  public static final int SCORE_ID = 10 ;
  public static final int QSTART_ID = 11 ;
  public static final int QSTOP_ID = 12 ;
  public static final int ATTRIBUTE_ID = 13 ;
  public static final int SEQUENCE_ID = 14 ;
  public static final int COMMENT_ID = 15 ;

  /**
   * The public constructor for this class only allows for the creation of 
   * <code>ATTRIBUTE</code> types with a user defined display name.
   * @param name
   *   The display name to be used for this Attribute ColumnType.
   */
  public ColumnType(String name)
  {
    this(name, "attValues", "value", ATTRIBUTE_ID, false, true) ;
  }

  /**
   * The full constructor for this class is private so that only ATTRIBUTE type
   * Column Types can be create with a different display name than what is
   * pre-defined by the LFF standard.
   */
  private ColumnType(String displayName, String dbTable, String dbField, int column, 
    boolean require, boolean sort)
  {
    display = displayName ;
    table = dbTable ;
    field = dbField ;
    col = column ;
    required = require ;
    sortable = sort ;
  }

  /** 
   * As specified by the LFF specifications.
   * @return
   *   True for required LFF columns.
   */
  public boolean isRequired()
  {
    return required ;
  }

  /**
   * Hint to the tabular layout setup page, to indicate if the UI should
   * provide the user with a way to sort by this type of attribute.  Things
   * like 'Edit Link' cannot be sorted upon, likewise, sorting on 'Sequence'
   * is not allowed for performance and correctneww reasons.
   * @return
   *  True if the attribute represented by this ColumnType can be sorted upon.
   */
  public boolean isSortable()
  {
    return sortable ;
  }

  /**
   * The id for this  object, refering to the constants defined by this class.
   * @return
   *   One of the constants for this class, representing a LFF attribute.
   */
  public int getId()
  {
    return col ;
  }

  /** 
   * Get the name of the database table that should be queried to get the
   * information represented by this attribute.  Current unused, but might be
   * in the future.
   */
  public String getDatabaseTable()
  {
    return table ;
  }

  /** 
   * Get the name of the field in the database table that would store the
   * information represented by this attribute.  Current unused, but might be
   * in the future.
   */
  public String getDatabaseName()
  {
    return field ;
  }

  /**
   * Get the String used to represent this attribute in the UI components.
   * This String may use capitalization and contain spaces.
   * @return
   *   A String to represent this attribute in the UI.
   */
  public String getDisplayName()
  {
    return display ;
  }

  /**
   * Get the standard ColumnTypes that will exist regardless of the user's
   * Track selection.  The LFF standard 13th column, 'Attributes', is omitted
   * form this list because it will be handled differently based on the tracks
   * that are selected by the user.
   */
  public static ColumnType[] getTabularDefaults()
  {
    return new ColumnType[] 
    {
      EDIT,
      CLASS, 
      NAME,
      TYPE,
      SUBTYPE,
      ENTRY_POINT,
      START,
      STOP,
      STRAND,
      PHASE,
      SCORE,
      QSTART,
      QSTOP,
      SEQUENCE,
      COMMENT
    } ;
  }

  public String toString()
  {
    return display ;
  }

  /* The following classes represent the 13 columns in the LFF format */
  public static final ColumnType EDIT = new ColumnType("Edit Link", "", "", UNDEFINED_ID, false, false) ;
  public static final ColumnType CLASS = new ColumnType("Class", "gclass", "gclass", CLASS_ID, true, true) ;
  public static final ColumnType NAME = new ColumnType("Name", "fdata2", "gname", NAME_ID, true, true) ;
  public static final ColumnType TYPE = new ColumnType("Type", "ftype", "fmethod", TYPE_ID, true, true) ;
  public static final ColumnType SUBTYPE = new ColumnType("Subtype", "ftype", "fsource", SUBTYPE_ID, true, true) ;
  public static final ColumnType ENTRY_POINT = new ColumnType("Entry Point", "fref", "refName", ENTRY_POINT_ID, true, true) ;
  public static final ColumnType START = new ColumnType("Start", "fdata2", "fstart", START_ID, true, true) ;
  public static final ColumnType STOP = new ColumnType("Stop", "fdata2", "fstop", STOP_ID, true, true) ;
  public static final ColumnType STRAND = new ColumnType("Strand", "fdata2", "fstrand", STRAND_ID, true, true) ;
  public static final ColumnType PHASE = new ColumnType("Phase", "fdata2", "fphase", PHASE_ID, true, true) ;
  public static final ColumnType SCORE = new ColumnType("Score", "fdata2", "fscore", SCORE_ID, true, true) ;
  public static final ColumnType QSTART = new ColumnType("Query Start", "fdata2", "ftarget_start", QSTART_ID, false, true) ;
  public static final ColumnType QSTOP = new ColumnType("Query Stop", "fdata2", "ftarget_stop", QSTOP_ID, false, true) ;
  public static final ColumnType ATTRIBUTE = new ColumnType("Attributes", "attValues", "value", ATTRIBUTE_ID, false, true) ;
  public static final ColumnType SEQUENCE = new ColumnType("Sequence", "fidText", "text", SEQUENCE_ID, false, false) ;
  public static final ColumnType COMMENT = new ColumnType("Freeform Comments", "fidText", "text", COMMENT_ID, false, false) ;
}
