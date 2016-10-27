package org.genboree.tabular ;

import java.util.Vector ;
import java.util.Comparator ;

/**
 * An extended {@link Comparator} class specifically used for sorting
 * {@link Table}s.  This {@link Comparator} uses the {@link Header} objects
 * that are specified as sort columns to perform the comparisons used for
 * the sort.
 * @author sgdavis@bioneos.com
 */
public class TabularComparator implements Comparator<Row>
{
  private boolean reverse ;
  private Header[] sortHeaders ;

  public TabularComparator(Vector<Header> headers)
  {
    this(headers, false) ;
  }

  public TabularComparator(Vector<Header> headers, boolean reverseSort)
  {
    reverse = reverseSort ;
    
    // Determine and order the sort headers
    int count = 0 ;
    for(Header head : headers)
      if(head.isSortedOn())
        count++ ;
    sortHeaders = new Header[count] ;
    for(Header head : headers)
      if(head.isSortedOn())
        sortHeaders[head.getSortOrder() - 1] = head ;
  }

  public int compare(Row left, Row right)
  {
    for(Header head : sortHeaders)
    {
      // First check for null values
      if(left.cells[head.column - 1] == null && right.cells[head.column - 1] == null)
        continue ;
      else if(left.cells[head.column - 1] == null)
        return -1 * (reverse ? -1 : 1) ;
      else if(right.cells[head.column - 1] == null)
        return 1 * (reverse ? -1 : 1) ;

      // Now check for the special term "{varies}"
      // NOTE: It is currently possible for the user to enter this value and
      //  notice an incorrect behavior, but unlikely because of the unique
      //  term.  However, in the future this might (should) be changed.
      if(left.cells[head.column - 1].toString().equals("{varies}") &&
        right.cells[head.column - 1].toString().equals("{varies}"))
        continue ;
      else if(left.cells[head.column - 1].toString().equals("{varies}"))
        return 1 * (reverse ? -1 : 1) ;
      else if(right.cells[head.column - 1].toString().equals("{varies}"))
        return -1 * (reverse ? -1 : 1) ;

      // No nulls, so perform correct object comparisons
      if(head.dataType == Header.MIXED)
      {
        if(left.cells[head.column - 1] instanceof String
          || right.cells[head.column - 1] instanceof String)
        {
          // Regular old String comparison must be done
          int stringCompare = (left.cells[head.column - 1]).toString().compareTo(
            right.cells[head.column - 1].toString());
          if(stringCompare != 0) return stringCompare * (reverse ? -1 : 1) ;
        }
        else if(left.cells[head.column - 1] instanceof String[]
          || right.cells[head.column - 1] instanceof String[])
        {
          if(!(left.cells[head.column - 1] instanceof String[]) &&
            right.cells[head.column - 1] instanceof String[])
            return -1 * (reverse ? -1 : 1) ;
          else if(left.cells[head.column - 1] instanceof String[] &&
            !(right.cells[head.column - 1] instanceof String[]))
            return 1 * (reverse ? -1 : 1) ;
        }
        else if(left.cells[head.column - 1] instanceof Integer)
        {
          if(right.cells[head.column - 1] instanceof Integer)
          {
            // Integer <-> Integer comparison
            int leftInt = ((Integer) left.cells[head.column - 1]).intValue() ;
            int rightInt = ((Integer) right.cells[head.column - 1]).intValue() ;
            if(leftInt < rightInt) return -1 * (reverse ? -1 : 1) ;
            else if(leftInt > rightInt) return 1 * (reverse ? -1 : 1) ;
          }
          else if(right.cells[head.column - 1] instanceof Double)
          {
            // Integer <-> Double
            double leftDouble = ((Integer) left.cells[head.column - 1]).doubleValue() ;
            double rightDouble = ((Double) right.cells[head.column - 1]).doubleValue() ;
            if(leftDouble < rightDouble) return -1 * (reverse ? -1 : 1) ;
            else if(leftDouble > rightDouble) return 1 * (reverse ? -1 : 1) ;
            else if(leftDouble == rightDouble) return -1 * (reverse ? -1 : 1) ;
          }
        }
        else if(left.cells[head.column - 1] instanceof Double)
        {
          if(right.cells[head.column - 1] instanceof Integer)
          {
            // Double <-> Integer
            double leftDouble = ((Double) left.cells[head.column - 1]).doubleValue() ;
            double rightDouble = ((Integer) right.cells[head.column - 1]).doubleValue() ;
            if(leftDouble < rightDouble) return -1 * (reverse ? -1 : 1) ;
            else if(leftDouble > rightDouble) return 1 * (reverse ? -1 : 1) ;
            else if(leftDouble == rightDouble) return 1 * (reverse ? -1 : 1) ;
          }
          else if(right.cells[head.column - 1] instanceof Double)
          {
            // Double <-> Double
            double leftDouble = ((Double) left.cells[head.column - 1]).doubleValue() ;
            double rightDouble = ((Double) right.cells[head.column - 1]).doubleValue() ;
            if(leftDouble < rightDouble) return -1 * (reverse ? -1 : 1) ;
            else if(leftDouble > rightDouble) return 1 * (reverse ? -1 : 1) ;
          }
        }
      }
      else if(head.dataType == Header.INTEGER)
      {
        int leftInt = ((Integer) left.cells[head.column - 1]).intValue() ;
        int rightInt = ((Integer) right.cells[head.column - 1]).intValue() ;
        if(leftInt < rightInt) return -1 * (reverse ? -1 : 1) ;
        else if(leftInt > rightInt) return 1 * (reverse ? -1 : 1) ;
      }
      else if(head.dataType == Header.DOUBLE)
      {
        double leftDouble = ((Double) left.cells[head.column - 1]).doubleValue() ;
        double rightDouble = ((Double) right.cells[head.column - 1]).doubleValue() ;
        if(leftDouble < rightDouble) return -1 * (reverse ? -1 : 1) ;
        else if(leftDouble > rightDouble) return 1 * (reverse ? -1 : 1) ;
      }
      else if(head.dataType == Header.STRING_ARRAY)
      {
        String leftStr = "", rightStr = "" ;

        if(!(left.cells[head.column - 1] instanceof String[]) &&
          right.cells[head.column - 1] instanceof String[])
          return -1 * (reverse ? -1 : 1) ;
        else if(left.cells[head.column - 1] instanceof String[] &&
          !(right.cells[head.column - 1] instanceof String[]))
          return 1 * (reverse ? -1 : 1) ;
        else if(left.cells[head.column - 1] instanceof String &&
          right.cells[head.column - 1] instanceof String)
        {
          int stringCompare = ((String) left.cells[head.column - 1]).compareTo(
            (String) right.cells[head.column - 1]);
          if(stringCompare != 0) return stringCompare * (reverse ? -1 : 1) ;
        }
      }
      else
      {
        // Compare this column as Strings as a last ditch sorting effort
        // NOTE: This could be made more efficient by generating String 
        //  CollationKey Objects prior to the sort.
        int stringCompare = ((String) left.cells[head.column - 1]).compareTo(
          (String) right.cells[head.column - 1]);
        if(stringCompare != 0) return stringCompare * (reverse ? -1 : 1) ;
      }
    }

    return 0 ;
  }

  public String toString()
  {
    StringBuilder order = new StringBuilder() ;
    for(Header head : sortHeaders)
      order.append(order.length() == 0 ? "" : ", ").append(head.column) ;
    return order.toString() ;
  }

  public boolean equals(Object o)
  {
    if(o instanceof TabularComparator)
      return ((TabularComparator) o).toString().equals(toString()) ;
    else
      return false ;
  }
}
