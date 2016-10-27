package org.genboree.util;

import java.util.Comparator;
import org.genboree.dbaccess.DbFref;

public class EntryPointComparator
  implements Comparator<DbFref>
{
  public int compare(DbFref first, DbFref second)
  {
    // Only handle entry points with names like: chr\d+[_].*
    //   Any other entry points will be compared alphabetically
    if(first.getRefname().indexOf('_') != -1 && second.getRefname().indexOf('_') != -1)
    {
      // Both names have underscores
      try
      {
        int firstInt = Integer.parseInt(first.getRefname().substring(3, first.getRefname().indexOf('_'))) ;
        int secondInt = Integer.parseInt(second.getRefname().substring(3, second.getRefname().indexOf('_'))) ;
        if (firstInt < secondInt) return -1 ;
        else if (firstInt > secondInt) return 1 ;
      }
      catch (NumberFormatException e)
      {
        // Cannot get ints from entry point names
      }

      // Fallback mode: alphabetical order
      return first.getRefname().compareTo(second.getRefname()) ;
    }
    else if (second.getRefname().indexOf('_') != -1)
    {
      // First name does not have an underscore, second does
      return -1 ;
    }
    else if (first.getRefname().indexOf('_') != -1)
    {
      // First name has an underscore, second doesn't
      return 1 ;
    }
    else
    {
      // Both names have no underscores
      try
      {
        if (first.getRefname().length() >= 3 && second.getRefname().length() >= 3)
        {
          int firstInt = Integer.parseInt(first.getRefname().substring(3)) ;
          int secondInt = Integer.parseInt(second.getRefname().substring(3)) ;
          if (firstInt < secondInt) return -1 ;
          else if (firstInt > secondInt) return 1 ;
        }
      }
      catch (NumberFormatException e)
      {
        // Cannot get ints from entry point names
      }

      // Fallback mode: alphabetical order
      return first.getRefname().compareTo(second.getRefname()) ;
    }
  }
}
