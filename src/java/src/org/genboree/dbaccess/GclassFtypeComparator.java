package org.genboree.dbaccess;
import java.util.Comparator;

public class GclassFtypeComparator implements Comparator
{
		public int compare( Object o1, Object o2 )
		{
			DbFtype ft1 = (DbFtype)o1;
			DbFtype ft2 = (DbFtype)o2;
			int rc = ft1.getGclass().compareTo(ft2.getGclass());
			if( rc != 0 ) return rc;
			return ft1.toString().compareTo(ft2.toString());
		}
}
