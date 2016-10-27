package org.genboree.dbaccess.util ;

import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.* ;

public class DbUtil
{
  public static String makeSQLSet(ArrayList valueList)
  {
    StringBuffer buff = new StringBuffer(4096) ;
    buff.append("( ") ;
    if(valueList != null && !valueList.isEmpty())
    {
      Iterator iter = valueList.iterator() ;
      while(iter.hasNext())
      {
        Object value = iter.next() ;
        buff.append(value.toString()) ;
        if(iter.hasNext())
        {
          buff.append(",") ;
        }
      }
    }
    else // empty list, will return "( null )" so that a SQL statement made with empty set won't fail at least.
    {
      buff.append("null") ;
    }
    buff.append(" )") ;
    return buff.toString();
  }
}
