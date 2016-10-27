package org.genboree.dbaccess ;

import java.sql.* ;
import org.genboree.dbaccess.* ;

// STRUCT! (not Class; instance variables available to all)
// - For passing around all the resources used in methods that return a
//   ResultSet. (e.g. DBAgent.executeQuery()). Instead we return one of these
//   and then we close() this instance to make sure all the related resources
//   get closed.
public class DbResourceSet
{
  public ResultSet resultSet ;
  public Statement stmt ;
  public Connection conn ;
  public DBAgent db ;

  public DbResourceSet()
  {
    resultSet = null ;
    stmt = null ;
    conn = null ;
    db = null ;
  }

  public DbResourceSet(ResultSet rs, Statement stmt, Connection conn, DBAgent db)
  {
    this.resultSet = rs ;
    this.stmt = stmt ;
    this.conn = conn ;
    this.db = db ;
  }

  public void close()
  {
    if(db != null)
    {
      db.safelyCleanup(this.resultSet, this.stmt, this.conn) ;
    }
    else
    {
      DBAgent.safelyCleanup(this.resultSet, this.stmt) ;
    }
    return ;
  }
}
