package org.genboree.dbaccess.bridge ;

import java.util.* ;
import java.sql.* ;

public interface DBBridge
{
  // Get a DB connection using a JDBC driver string & default caching/pooling & default properties.
  public Connection getConnection(String driverStr, String userName, String passwd) ;

  // Get a DB connection using a JDBC driver string & caching/pooling as indicated.
  // - if useConnCache==false, must NOT cache/pool the supplied connection
  public Connection getConnection(String driverStr, String userName, String passwd, boolean useConnCache) ;

  // Get a DB connection using a JDBC driver string & caching/pooling & properties as indicated.
  // - if useConnCache==false, must NOT cache/pool the supplied connection
  public Connection getConnection(String driverStr, String userName, String passwd, boolean useConnCache, Properties params) ;

  // Close/clean the connection appropriately (may involve deregistering or something from conn pool)
  public void closeConnection(Connection conn) ;
}
