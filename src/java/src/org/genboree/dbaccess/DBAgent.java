package org.genboree.dbaccess ;

import java.lang.* ;
import java.lang.reflect.* ;
import java.io.* ;
import java.sql.* ;
import java.util.* ;
import org.genboree.dbaccess.bridge.* ;
import org.genboree.dbaccess.util.* ;
import org.genboree.util.* ;

public class DBAgent
{
  //--------------------------------------------------------------------------
  // CLASS VARIABLES
  //--------------------------------------------------------------------------
  protected static Class dbBridgeClass = null ; // The DB Bridge class to get connections from. This is only set once, when this class loads
  protected static DBBridge dbBridge = null ; // Instance of the DB Bridge class to get connections from. This is only set once, when this class loads
  protected static DBAgent instance = null ;

  //--------------------------------------------------------------------------
  // CLASS STATIC INITIALIZER (load/instantiate class we need)
  //--------------------------------------------------------------------------
  static
  {
    System.err.println("STATUS: Attempt to load configured DB Bridge class") ;
    // Load the configured DB Bridge class
    DBAgent.loadDBBridgeClass() ;
    System.err.println("STATUS: Loaded configured DB Bridge " + DBAgent.dbBridgeClass) ;
    // Instantiate the configured DBBridge class
    try
    {
      System.err.println("STATUS: Attempt to instantiate configured DB Bridge class...") ;
      DBAgent.dbBridge = (DBBridge)DBAgent.dbBridgeClass.newInstance() ;
      System.err.println("STATUS: Instantiated configured DB Bridge class: " + DBAgent.dbBridge) ;
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: failed to instantiate the configured DB Bridge class.\n" +
                         "       Configured DB Bridge class name is: " + (DBAgent.dbBridgeClass == null ? "null/not set!" : DBAgent.dbBridgeClass.getName()) + "\n" +
                         "       Exception details:\n" +
                         ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
  }

  //--------------------------------------------------------------------------
  // CLASS METHODS
  //--------------------------------------------------------------------------
  // Load the DB Bridge class indicated in the configuration file
  public static Class loadDBBridgeClass()
  {
    DBAgent dbBridgeClass = null ;
    if(DBAgent.dbBridgeClass == null)
    {
      // Get name of configured DB Bridge class to use
      String dbBridgeClassStr = GenboreeConfig.getConfigParam("dbBridgeClass") ;
      System.err.println("STATUS: ... configured DB Bridge class to use is " + dbBridgeClassStr) ;
      // Load the class
      try
      {
        System.err.println("STATUS: ... load this class") ;
        DBAgent.dbBridgeClass = Class.forName(dbBridgeClassStr) ;
        System.err.println("STATUS: ... class successfully loaded (" + DBAgent.dbBridgeClass + ")") ;
      }
      catch(ClassNotFoundException cnfe)
      {
        System.err.println("FAILED: could not load actual class for " + dbBridgeClassStr) ;
        cnfe.printStackTrace(System.err) ;
      }
    }
    return DBAgent.dbBridgeClass ;
  }

  // Weird prep error method. Returns array of lines of the error. Also ensures error logged to stderr so it's not skipped.
  protected static String[] reportErrorStat( Exception ex, String loc )
  {
    String nl = System.getProperty( "line.separator" ) ;
    StringWriter swTmp = new StringWriter() ;
    PrintWriter buffWriter = new PrintWriter(swTmp) ;
    buffWriter.print(ex.getClass().getName()) ;
    if( ex instanceof SQLException )
    {
      buffWriter.println(" ; SQL Error Code=" + ((SQLException)ex).getErrorCode()) ;
    }
    if( loc != null )
    {
      buffWriter.println("Location: " + loc) ;
    }
    ex.printStackTrace( buffWriter ) ;
    buffWriter.close() ;
    String errMsg = swTmp.toString() ;
    // Let's ensure this error is not just going to be ignored...make sure to log it!
    System.err.println( "--------------------------------------------------------------------------\n" +
                        "DB ERROR:\n" +
                        errMsg +
                        "--------------------------------------------------------------------------\n") ;
    String[] rc = errMsg.split(nl) ;
    return rc ;
  }

  //--------------------------------------------------------------------------
  // INSTANCE VARIABLES
  //--------------------------------------------------------------------------
  protected String defaultDbName = "genboree" ;
  protected String[] lastError = null ;
  protected String userName = null ;
  protected String pass = null ;
  protected String userId = null ;
  protected String _log = null ;

  //--------------------------------------------------------------------------
  // CONSTRUCTORS
  //--------------------------------------------------------------------------
  public DBAgent()
  {
  }

  public static synchronized DBAgent getInstance()
  {
    if(instance == null)
    {
      instance = new DBAgent() ;
    }
    return instance ;
  }

  //--------------------------------------------------------------------------
  // PUBLIC INSTANCE METHODS
  //--------------------------------------------------------------------------
  // Get connection to default database (main genboree database); use caching/pooling if available.
  public Connection getConnection() throws SQLException
  {
    return this.getConnection(null, true, null) ;
  }

  // Get connection to database; use caching/pooling, if available.
  public Connection getConnection( String dbName ) throws SQLException
  {
    return this.getConnection(dbName, true, null) ;
  }

  // Get connection to database; use caching/pooling as indicated.
  public Connection getConnection( String dbName, boolean useConnCache ) throws SQLException
  {
    return this.getConnection(dbName, useConnCache, null) ;
  }

  // Get connection to database; use caching/pooling & properties as indicated.
  public Connection getConnection( String dbName, boolean useConnCache, Properties params ) throws SQLException
  {
    Connection conn = null ;
    // If not connecting to specific database, connect to the default/main database (usually 'genboree')
    if(dbName == null)
    {
      dbName = this.getDefaultDbName() ;
    }
    // FIRST: Read connection info from config file (needed in all cases)
    String machineName = GenboreeConfig.getConfigParam("machineName") ;
    String machineNameAlias = GenboreeConfig.getConfigParam("machineNameAlias") ;
    Dbrc dbrc = new Dbrc(System.getenv("DBRC_FILE")) ;
    HashMap dbrcRec = dbrc.getRecordByHost(machineName, "JDBC") ;
    String userName = (String)dbrcRec.get("user") ;
    String passwd = (String)dbrcRec.get("password") ;
    String dbHost = (String)dbrcRec.get("host") ;
    // Did we get all the configuration we need from machineName? If not, try machineNameAlias.
    if(dbHost == null || userName == null || passwd == null)
    {
      dbrcRec = dbrc.getRecordByHost(machineNameAlias, "JDBC") ;
      userName = (String)dbrcRec.get("user") ;
      passwd = (String)dbrcRec.get("password") ;
      dbHost = (String)dbrcRec.get("host") ;
    }
    // At this point, should have info needed via machineName or machineNameAlias, unless there is a problem:
    if(dbHost == null || userName == null || passwd == null)
    {

      System.err.println("ERROR: Unable to read configuration file " + Constants.DBACCESS_PROPERTIES) ;
      System.err.println("       Bad configuration parameters: dbHost => " +
                         dbHost + " ; userName => " +
                         userName + " ; passwd => " +
                         (passwd == null ? "BAD/null" : "OK")) ;
      conn = null ;
    }
    else // Yes, we have suitable config info...proceed
    {
      // SECOND: Get Connection to main genboree database (needed in all cases, but for different things)
      String mainDbUrl = "jdbc:mysql://" + dbHost + ":16002/" + this.getDefaultDbName() ;  // WATCH OUT <- hardcoded port number
      // Get connection to main genboree database, use caching/pooling as indicated
      Connection mainGenbConn = DBAgent.dbBridge.getConnection(mainDbUrl, userName, passwd, useConnCache) ;
      // Did we get the connection we need to the main genboree database?
      if(mainGenbConn == null) // No.
      {
        System.err.println("ERROR: failed to get connection to database.") ;
        System.err.println("       Driver string => " +
                           mainDbUrl + " ; userName => " +
                           userName + " ; passwd => " +
                           (passwd == null ? "BAD/null" : "Provided...check that it's right")) ;
      }
      else // Yes, we have connection to main genboree database
      {
        // THIRD: is a Connection to the main/default genboree database requested?
        if(dbName == this.getDefaultDbName()) // Yes
        {
          // IF SO: (1) return connection to main database
          conn = mainGenbConn ;
        }
        else
        {
          // IF NOT:
          // (2) find hostName for this database from main genboree database
          String hostName = Database2HostTable.getHostForDbName(dbName, mainGenbConn) ;
          // Did we get a hostName?
          if(hostName == null || (hostName.length() == 0)) // No.
          {
            // (3) return connection to that hostName+database
            conn = null ;
            System.err.println("ERROR: failed to get a connection to user database '" + dbName + "'. Looks like we can't locate the host for that database.") ;
          }
          else // Yes, we have a hostName for the Genboree user database
          {
            // (4) get connection to user database at the indicated host
            String dbUrl = "jdbc:mysql://" + hostName + ":16002/" + dbName ;  // WATCH OUT <- hardcoded port number
            // Get connection to database, use caching/pooling as indicated
            conn = DBAgent.dbBridge.getConnection(dbUrl, userName, passwd, useConnCache) ;
            // Did we get the connection we need to the main genboree database?
            if(conn == null) // No.
            {
              System.err.println("ERROR: failed to get connection to user database. Got connection to main Genboree database and retrieved a hostname for the use datatbase, but connection to that host failed.") ;
              System.err.println("       Driver string => " +
                                 dbUrl + " ; userName => " +
                                 userName + " ; passwd => " +
                                 (passwd == null ? "BAD/null" : "Provided...check that it's right")) ;
            }
          }
          // Clean up the connection to the mainGenbConn since we only used it to get the host for the user database
          // -- this ensures connections to mainGenb database are closed when a no-cached connection to a user database is asked for
          this.closeConnection(mainGenbConn) ;
        }
      }
    }
    return conn ;
  }

  // Get connection to database; do NOT cache/pool.
  public Connection getNoCacheConnection( String dbName ) throws SQLException
  {
    return this.getConnection(dbName, false, null) ;
  }

  // Uses DB Bridge to close the connection; may involve removing it from a cache/pool
  // or just closing the connection, or something else.
  public void closeConnection(Connection conn)
  {
    DBAgent.dbBridge.closeConnection(conn) ;
    return ;
  }

  // Get connection to JUST the database host, not to any particular database.
  // None of these connections are cached.
  public Connection getDatabaseHostConnection(String dbHost)
  {
    Connection conn = null ;
    if(dbHost != null)
    {
      String dbUrl = "jdbc:mysql://" + dbHost + ":16002/" ;  // WATCH OUT <- hardcoded port number
      // FIRST: Read connection info from config file (needed in all cases)
      String userName = GenboreeConfig.getConfigParam("userName") ;
      String passwd = GenboreeConfig.getConfigParam("passwd") ;
      // Did we get all the configuration we need?
      if(dbHost == null || userName == null || passwd == null)
      {
        System.err.println("ERROR: DBAgent.getDatabaseHost(S) => Unable to read configuration file " + Constants.DBACCESS_PROPERTIES) ;
        System.err.println("       Bad configuration parameters: userName => " +
                           userName + " ; passwd => " +
                           (passwd == null ? "BAD/null" : "OK")) ;
        conn = null ;
      }
      else
      {
        conn = DBAgent.dbBridge.getConnection(dbUrl, userName, passwd, false) ;
        if(conn == null)
        {
          System.err.println("ERROR: DBAgent.getDatabaseHost(S) => Unable to get connection to raw db host via '" + dbUrl +
                             "' ; userName => " + userName + " ; passwd => " +
                             (passwd == null ? "BAD/null" : "OK")) ;
          conn = null ;
        }
      }
    }
    return conn ;
  }

  // Create a new database named dbName on the indicated host
  public boolean createNewUserDatabase(String dbHost, String dbName)
  {
    boolean retVal = false ;
    if(dbHost != null && (dbHost.length() > 0) && dbName != null && (dbName.length() > 0))
    {
      Statement stmt = null ;
      Connection conn = null ;
      try
      {
        // Get connection to dbHost (no database...hopefully)
        conn = this.getDatabaseHostConnection(dbHost) ;
        // Did we get a Connection to the db host ok?
        if(conn == null) // No.
        {
          System.err.println("ERROR: DBAgent.createNewUserDatabase(S,S) => Unable to get connection to the db host itself, can't create new database there.") ;
          retVal = false ;
        }
        else // Yes, we have a Connection to the db host itself.
        {
          // Try to create database there.
          String sql = "create database " + dbName ;
          stmt = conn.createStatement() ;
          int rowCount = stmt.executeUpdate(sql) ;
          retVal = true ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: DBAgent.createNewUserDatabase(S,S) => Failed to create new database '" + dbName + "' on host '" + dbHost + "'. Details: " + ex.getMessage()) ;
        ex.printStackTrace(System.err) ;
        retVal = false ;
      }
      finally
      {
        this.safelyCleanup(null, stmt, conn) ;
      }
    }
    return retVal ;
  }

  // Drop a user database from the appropriate host machine
  public boolean dropUserDatabase(String dbName)
  {
    boolean retVal = false ;
    // Get appropriate host machine name
    if(dbName != null && (dbName.length() > 0))
    {
      Connection mainDbConn = null ;
      Connection conn = null ;
      Statement stmt = null ;
      try
      {
        mainDbConn = this.getConnection() ;
        String hostName = Database2HostTable.getHostForDbName(dbName, mainDbConn) ;
        this.closeConnection(mainDbConn) ;
        if(hostName == null || (hostName.length() <= 0))
        {
          System.err.println("ERROR: DBAgent.dropUserDatabase(S) => Failed to get hostName for existing database '" + dbName + "'.") ;
          retVal = false ;
        }
        else
        {
          // Get a connection to that machine (no database)
          conn = this.getDatabaseHostConnection(hostName) ;
          if(conn == null)
          {
            System.err.println("ERROR: DBAgent.dropUserDatabase(S) => Got null connection to user database host machine '" + hostName + "'.") ;
            retVal = false ;
          }
          else
          {
            // Drop the database
            String sql = "drop database " + dbName ;
            stmt = conn.createStatement() ;
            int rowCount = stmt.executeUpdate(sql) ;
            retVal = true ;
          }
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: DBAgent.dropUserDatabase(S) => Failure using connections/executing statements. Details: " + ex.getMessage() ) ;
        ex.printStackTrace(System.err) ;
        retVal = false ;
      }
      finally
      {
        this.safelyCleanup(null, stmt, conn) ;
      }
    }
    return retVal ;
  }

  // Verify that we can get a good connection to the database server.
  public boolean isValid() throws SQLException
  {
    return (this.getConnection() != null) ;
  }

  // Tries to safely clean up the provided ResultSet, Statement, and connection
  public boolean safelyCleanup(ResultSet rs, Statement stmt, Connection conn)
  {
    boolean retVal = true ;
    if(rs != null)
    {
      try
      {
        rs.close() ;
      }
      catch(Exception ex)
      {
        retVal = false ;
      }
    }
    if(stmt != null)
    {
      try
      {
        stmt.close() ;
      }
      catch(Exception ex)
      {
        retVal = false ;
      }
    }
    if(conn != null)
    {
      try
      {
        this.closeConnection(conn) ;
      }
      catch(Exception ex)
      {
        retVal = false ;
      }
    }
    return retVal ;
  }

  // Class version of the above for cases without conn to clean up [yet]
  public static boolean safelyCleanup(ResultSet rs, Statement stmt)
  {
    boolean retVal = true ;
    if(rs != null)
    {
      try
      {
        rs.close() ;
      }
      catch(Exception ex)
      {
        retVal = false ;
      }
    }
    if(stmt != null)
    {
      try
      {
        stmt.close() ;
      }
      catch(Exception ex)
      {
        retVal = false ;
      }
    }
    return retVal ;
  }

  // Retrieves user info from the database using the
  // username/password/userId supplied by the array and returns the full name of the user.
  public String setUserInfo( String[] uinf )
  {
    String rc = null ;
    this.userName = uinf[0] ;
    this.pass = uinf[1] ;
    this.userId = uinf[2] ;
    try
    {
      Connection conn = this.getConnection() ;
      if(conn != null)
      {
        this.lastError = null ;
        PreparedStatement pstmt = conn.prepareStatement("SELECT firstName, lastName, userId FROM genboreeuser WHERE name like binary ? and password like binary ?" ) ;
        pstmt.setString( 1, this.userName ) ;
        pstmt.setString( 2, this.pass ) ;
        ResultSet rs = pstmt.executeQuery() ;
        if(rs.next())
        {
          String fn = rs.getString(1) ;
          String ln = rs.getString(2) ;
          uinf[2] = userId = rs.getString(3) ;
          fn = (fn == null ? "" : fn.trim()) ;
          ln = (ln == null ? "" : ln.trim()) ;
          rc = userName ;
          if( (fn + ln).length() != 0 )
          {
            rc = (fn + " " + ln) ;
          }
        }
        pstmt.close() ;
        this.closeConnection(conn) ;
      }
    }
    catch( Exception ex )
    {
      this.lastError = this.reportError( ex, "DBAgent.setUserInfo()" ) ;
      this.userName = null ;
    }
    return rc ;
  }

  // Execute the supplied query on the supplied database, using the the bindVars if any
  public DbResourceSet executeQuery( String dbName, String query, String[] bindVars ) throws SQLException
  {
    ResultSet rs = null ;
    PreparedStatement pstmt = null ;
    DbResourceSet dbSet = null;
    Connection conn = this.getConnection(dbName) ;
    if(conn != null)
    {
      this.lastError = null ;
      try
      {
        pstmt = conn.prepareStatement(query) ;
        for(int ii = 0; ii < bindVars.length; ii++)
        {
          pstmt.setString( ii+1, bindVars[ii] ) ;
        }
        rs = pstmt.executeQuery() ;
      }
      catch(Exception ex)
      {
        this.lastError = this.reportError(ex, "DBAgent.executeQuery(" + dbName + "," + query + ")" ) ;
      }
      finally
      {
        this.closeConnection(conn) ;
        // TODO: Statement and ResultSet don't get cleaned up...we need to reorg this so they can be!
        // - the best (least distruptive) way would be to return a kind of DBResourceSet that has the
        //   DBAgent, Connection, Statement, ResultSet and the using code can get the ResultSet out
        //   and then call an appropriate close method that would close, clean, and null-ify the
        //   resources in the set (which for good measure should be set to null also).
      }
    }
    dbSet = new DbResourceSet(rs, pstmt, conn, this);
    return dbSet;
  }

  // Execute the supplied query on the supplied database, no bindVars needed
  public DbResourceSet executeQuery( String dbName, String query ) throws SQLException
  {
    System.err.println("ERROR: SQL INJECTION ATTACK?? using bare SQL without Bind Variables via DBAgent.executeQuery(S,S). Causes CRASHING and is a easy INJECTION ATTACK location. Use version that bindVars argument.") ;
    return this.executeQuery(dbName, query, new String[0]) ;
  }

  // Execute the supplied query on the default genboree database (main genboree database usually)
  public DbResourceSet executeQuery( String query ) throws SQLException
  {
    return this.executeQuery( null, query ) ;
  }

  // Execute the supplied update on the supplied database
  public int executeUpdate( String dbName, String query )
  {
    System.err.println("ERROR: SQL INJECTION ATTACK?? using bare SQL without Bind Variables via DBAgent.executeUpdate(S,S). Causes CRASHING and is a easy INJECTION ATTACK location. Use version that bindVars argument.") ;
    int rc = -1 ;
    Connection conn = null ;
    Statement stmt = null ;
    try
    {
      conn = this.getConnection(dbName) ;
      if(conn != null)
      {
        this.lastError = null ;
        stmt = conn.createStatement() ;
        rc = stmt.executeUpdate(query) ;
      }
    }
    catch(Exception ex)
    {
      this.lastError = this.reportError( ex, "DBAgent.executeUpdate(" + dbName + "," + query + ")" ) ;
    }
    finally
    {
      this.safelyCleanup(null, stmt, conn) ;
    }
    return rc ;
  }

  // Execute the supplied insert on the supplied databse
  public int executeInsert(String dbName, String query) throws SQLException
  {
    System.err.println("ERROR: SQL INJECTION ATTACK?? using bare SQL without Bind Variables via DBAgent.executeInsert(S,S). Causes CRASHING and is a easy INJECTION ATTACK location. Use version that bindVars argument.") ;
    int rc = -1 ;
    Connection conn = this.getConnection(dbName);
    Statement stmt = null ;
    if(conn != null)
    {
      try
      {
        stmt = conn.createStatement() ;
        stmt.executeUpdate(query) ;
        rc = this.getLastInsertId(conn) ;
      }
      catch(Exception ex)
      {
        this.lastError = this.reportError( ex, "DBAgent.executeInsert(" + dbName + "," + query + ")" ) ;
      }
      finally
      {
        this.safelyCleanup(null, stmt, conn) ;
      }
    }
    return rc ;
  }

  // Get last insert id on the supplied connection
  public int getLastInsertId(Connection conn)
  {
    int rc = -1 ;
    Statement stmt = null ;
    ResultSet rs = null ;
    try
    {
      stmt = conn.createStatement() ;
      rs = stmt.executeQuery( "SELECT LAST_INSERT_ID()" ) ;
      if(rs.next())
      {
        rc = rs.getInt(1) ;
      }
    }
    catch(Exception ex)
    {
      this.lastError = this.reportError( ex, "DBAgent.getLastInsertId()" ) ;
    }
    finally
    {
      this.safelyCleanup(rs, stmt, null) ;
    }
    return rc ;
  }

  // Return table schemas as arrays of lines for all tables in supplied database.
  public String[][] fetchSchema(String dbName) throws SQLException
  {
    String[][] rc = null ;
    Connection conn = this.getConnection(dbName) ;
    Statement stmt = null ;
    Statement stmtd = null ;
    ResultSet rs = null ;
    ResultSet rsd = null ;
    if(conn != null)
    {
      try
      {
        stmt = conn.createStatement() ;
        stmtd = conn.createStatement() ;
        rs = stmt.executeQuery( "SHOW TABLES" ) ;
        Vector vv = new Vector() ;
        while(rs.next())
        {
          String tbName = rs.getString(1) ;
          rsd = stmtd.executeQuery("SHOW CREATE TABLE " + tbName) ;
          if(rsd.next())
          {
            String[] ss = new String[4] ;
            ss[0] = tbName ;
            ss[1] = rsd.getString(2) ;
            vv.addElement(ss) ;
          }
          rsd.close() ;
        }
        rc = new String[vv.size()][4] ;
        vv.copyInto(rc) ;
      }
      catch(Exception ex)
      {
        this.lastError = this.reportError( ex, "DBAgent.fetchSchema(" + dbName + ")" ) ;
      }
      finally
      {
        this.safelyCleanup(rs, stmt, conn) ;
        stmtd.close() ;
      }
    }
    return rc ;
  }

  // Get log string for errors collected via log() function of this object (don't like this)
  public String getLog()
  {
    String ss = this._log ;
    this._log = null ;
    return ss ;
  }

  // Add a line to this object's log
  public String log( String ss )
  {
    this._log = (this._log == null ? ss : (this._log + "\n" + ss)) ;
    return ss;
  }

  // Get default Genboree db name ('genboree' by default)
  public String getDefaultDbName()
  {
    return this.defaultDbName ;
  }

  // Set default Genboree db name (should be left alone as 'genboree'...)
  public void setDefaultDbName( String dbName )
  {
    if( dbName == null )
    {
      dbName = "genboree" ;
    }
    this.defaultDbName = dbName ;
  }

  // Format and report an exception as an error...used a lot for the sql stuff in this class (unfortunately).
  public String[] reportError( Exception ex, String loc )
  {
    this.lastError = reportErrorStat( ex, loc ) ;
    return this.lastError ;
  }

  // Last exception recorded in this object
  public String[] getLastError()
  {
    return this.lastError ;
  }

  // Clear last exception in this object
  public void clearLastError()
  {
    this.lastError = null ;
  }
}
