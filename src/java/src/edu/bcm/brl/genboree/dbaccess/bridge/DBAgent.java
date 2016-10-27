package edu.bcm.brl.genboree.dbaccess.bridge ;

import java.io.* ;
import java.sql.* ;
import java.util.* ;
import java.util.concurrent.* ;
import org.genboree.dbaccess.bridge.* ;

// Implementation of DB Bridge for getting MySQL connections.
// The DriverManager will load the appropriate DB driver based on the JDBC url.
// It's expected this will make use of MySQL's Connector/J, if installed. But
// it could be something else the installers put into place. This code, and the org.genboree.* code,
// doesn't care what driver library is used to implement connections to MySQL.
public class DBAgent implements org.genboree.dbaccess.bridge.DBBridge
{
  //--------------------------------------------------------------------------
  // CLASS VARIABLES
  //--------------------------------------------------------------------------
  protected static final int NUM_CONN_RETRIES = 3 ;
  protected static final String SELECT_ONE = "select 1" ;

  //--------------------------------------------------------------------------
  // CLASS STATIC INITIALIZER (load/instantiate class we need)
  //--------------------------------------------------------------------------
  static
  {
    try
    {
      Class.forName( "com.mysql.jdbc.Driver" ).newInstance() ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: Failed to load MySQL driver class 'com.mysql.jdbc.Driver'. Missing corresponding .jar or a classpath issue, maybe?" +
                         "       Exception details:\n" +
                         ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
  }

  //--------------------------------------------------------------------------
  // CLASS METHODS
  //--------------------------------------------------------------------------
  // Convenience helper method for "sleep()" as found in most other languages.
  public static void sleep(long duration)
  {
    try
    {
      Thread.sleep(duration) ;
    }
    catch(Exception ex)
    {
    }
    return ;
  }

  // Checks if Connection is working or not.
  // Java's Connection.isClosed() does NOT check that the connections is open and working.
  // It just tells you if someone called "Connection.close()" on that object; which
  // is not too useful--the server could have closed the connection for some reason (e.g.
  // inactivity if caching/pooling connections)
  public static boolean isConnClosed(Connection conn)
  {
    boolean retVal = true ;
    Statement stmt = null ;
    if(conn != null)
    {
      try
      {
        if(!conn.isClosed())
        {
          stmt = conn.createStatement() ;
          // PPP: this test does not work with Percona 5.6 - probably new mysql-connector is required
          // stmt.setMaxRows(1) ;
          // stmt.executeQuery(SELECT_ONE) ;
          // Not closed, ('select 1' succeeded)
          retVal = false ;
        }
      }
      catch(Exception ex)
      {
        // OK, it was closed ('select 1' failed)
        retVal = true ;
      }
      finally
      {
        if(stmt != null)
        {
          try
          {
            stmt.close() ;
          }
          catch(Exception ex2)
          {}
        }
      }
    }
    return retVal ;
  }

  //--------------------------------------------------------------------------
  // INSTANCE VARIABLES
  //--------------------------------------------------------------------------
  protected ConcurrentHashMap url2ConnectionCache ;
  protected ConcurrentHashMap connection2urlCache ;

  //--------------------------------------------------------------------------
  // CONSTRUCTORS / FINALIZERS
  //--------------------------------------------------------------------------
  public DBAgent()
  {
    this.url2ConnectionCache = new ConcurrentHashMap() ;
    this.connection2urlCache = new ConcurrentHashMap() ;
  }

  // When finalizer called during GC, try to properly shut down each cached connection.
  protected void finalize() throws Throwable
  {
    Iterator iter = this.url2ConnectionCache.keySet().iterator() ;
    while(iter.hasNext())
    {
      String dbName = (String)iter.next() ;
      Connection conn = (Connection)this.url2ConnectionCache.get(dbName) ;
      try
      {
        conn.close() ;
        this.url2ConnectionCache.remove(dbName) ;
        this.connection2urlCache.remove(conn) ;
      }
      catch(Exception ex)
      {
        // Ok, close failed for whatever reason. We're finalizing here.
      }
    }
    return ;
  }

  //--------------------------------------------------------------------------
  // PUBLIC INSTANCE METHODS
  //--------------------------------------------------------------------------
  // 'Close' the connection appropriately.
  // Because we're caching all connections for the getConnection(...) methods,
  // this method actually doesn't do anything.
  public void closeConnection(Connection conn)
  {
    // We don't want to close cached connections, we want to re-use them.
    // HOWEVER, if it's an uncached Connection we should indeed close it since
    // it won't be reused and the code that asked for it says it's done with it.
    if( conn != null && !this.connection2urlCache.containsKey(conn) )
    {
      try
      {
        if(!DBAgent.isConnClosed(conn))
        {
          conn.close() ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: BRL's DBAgent.closeConnection(C) => couldn't close Connection...should have been able to. Details: " + ex.getMessage()) ;
        ex.printStackTrace(System.err) ;
      }
    }
    return ;
  }

  // Get connection based on the driverStr (jdbc url), username, and password and using
  // caching/pooling if available.
  public Connection getConnection(String driverStr, String userName, String passwd)
  {
    return this.getConnection(driverStr, userName, passwd, true, null) ;
  }

  // Get connection based on the driverStr (jdbc url), username, and password and using
  // caching/pooling as indicated by the useConnCache argument.
  public Connection getConnection(String driverStr, String userName, String passwd, boolean useConnCache)
  {
    return this.getConnection(driverStr, userName, passwd, useConnCache, null) ;
  }

  // Get connection based on the driverStr (jdbc url), username, and password and using
  // caching/pooling and connection params as indicated by the useConnCache and params arguments.
  public Connection getConnection(String driverStr, String userName, String passwd, boolean useConnCache, Properties params)
  {
    Connection conn = null ;
    int connectTries = 0 ;
    boolean handledException = false ;
    // If we fail to get a connection, we'll try a few more times. Maybe limit reached or something.
    while(connectTries < this.NUM_CONN_RETRIES)
    {
      try
      {
        connectTries++ ;
        // If asked, try to use connection cache/pool:
        if(useConnCache)
        {
          conn = (Connection)this.url2ConnectionCache.get(driverStr) ;
        }
        // If conn is null (generally means not from cache) or is closed somehow (generally from cache but got closed)
        if(conn == null || DBAgent.isConnClosed(conn))
        {
          //System.err.println("NOTE: DBAgent bridge needs a new connection. Existing connection either null (" + (conn == null) + ") or closed (" + DBAgent.isConnClosed(conn) + ")") ;
          if(params == null)
          {
            // ARJ: do everything through Property object
            // conn = DriverManager.getConnection(driverStr, userName, passwd) ;
            params = new Properties() ;
          }
          // ARJ: Authentication info
          params.setProperty("user", userName) ;
          params.setProperty("password", passwd) ;
          // ARJ: try to use MySQL compression if at all possible
          params.setProperty("useCompression", "true") ;
          conn = DriverManager.getConnection(driverStr, params) ;
          //System.err.println("NOTE: DBAgent bridge created new Connection on Attempt " + connectTries + " of " + this.NUM_CONN_RETRIES) ;

          if(useConnCache)
          {
            this.url2ConnectionCache.put(driverStr, conn) ;
            this.connection2urlCache.put(conn, driverStr) ;
            //System.err.println("NOTE: DBAgent bridge cached new Connection") ;
          }
        }
        /*else
        {
          System.err.println("NOTE: DBAgent bridge found a non-null, non-closed Connection") ;
        }*/
      }
      catch( Exception ex )
      {
        handledException = true ;
        System.err.println("--------------------------------------------------------------------------") ;
        System.err.println("WARNING: [not necessarily fatal] Couldn't connect to database. Attempt " + connectTries + " of " + this.NUM_CONN_RETRIES + " maximum number of attempts to reconnect.") ;
        System.err.println("  If haven't reached maximum number of retries yet, will attempt to reestablish the connection in 1500ms.") ;
        System.err.println("  For reference: The connection exception message was: " + ex.getMessage()) ;
        System.err.println("  For reference: The stack trace of where the error occured was: ") ;
        ex.printStackTrace(System.err) ;
        System.err.println("--------------------------------------------------------------------------") ;
        // Try to clean up conn if somehow got one
        try
        {
          if(conn != null)
          {
            conn.close() ;
          }
        }
        catch(Exception ex2)
        {}
        sleep(1500) ;
      }

      // Did we get a Connection ok? No Exceptions or anything?
      if(conn != null)
      {
        break ; // Yes, so we're done.
      }
      else // No exception, but got null connection from DriverManager?
      {
        if(!handledException) // don't print this warning if we've already warned about having to retry the connection.
        {
          System.err.println((new java.util.Date()).toString() + " WARNING: edu.bcm.brl.genboree.dbaccess.bridge.DBAgent#getConnection(...): JDBC gave a null connection for jdbcUrl = " + driverStr + " and username " + userName ) ;
          sleep(1500) ;
        }
        else
        {
          handledException = false ;
        }
      }
    }
    return conn ;
  }
}
