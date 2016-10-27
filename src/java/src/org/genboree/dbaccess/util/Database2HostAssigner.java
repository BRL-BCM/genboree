package org.genboree.dbaccess.util ;

import java.sql.* ;
import org.genboree.dbaccess.* ;
import org.genboree.dbaccess.util.* ;
import org.genboree.util.* ;

// Class for deciding what host machine to assign a new database to.
// Mainly used to figure out what machine to put a new database on.
// Generally, the main genboree database's database2host table will be
// updated with the info as part of the assignment.
public class Database2HostAssigner
{
  // Assign dbName to a host machine and update the genboree.database2host table
  public static String assignNewDbToHost(DBAgent db, String dbName)
  {
    return Database2HostAssigner.assignNewDbToHost(db, dbName, true) ;
  }

  // Assign dbName to a host machine and update the genboree.database table if updateDatabase2HostTable says to.
  // NOTE: This version simply assigned ALL new databases to the SAME MACHINE, which is specified in the
  // Genboree config file. Later versions will use a little or a lot more information to decide where the
  // new database should be placed.
  public static String assignNewDbToHost(DBAgent db, String dbName, boolean updateDatabase2HostTable)
  {
    String retVal = null ;
    if(dbName != null)
    {
      // Read default user database machine from config file
      String defaultHost = GenboreeConfig.getConfigParam("defaultUserDbHost") ;
      // Did we read sensible parameter value?
      if(defaultHost == null) // No.
      {
        System.err.println("ERROR: Unable to read configuration file " + Constants.DBACCESS_PROPERTIES) ;
        System.err.println("       Bad configuration file? Is it missing defaultUserDbHost? Value retrieved is => " + defaultHost ) ;
        retVal = null ;
      }
      else // Yes, continue.
      {
        retVal = defaultHost ;
        // If we were told to, update the genboree.database2host table
        if(updateDatabase2HostTable)
        {
          // Get connection to main Genboree database
          try
          {
            Connection mainDbConn = db.getConnection() ;
            boolean insertOk = Database2HostTable.insertNewDbname2HostPair(dbName, retVal, mainDbConn) ;
            if(!insertOk)
            {
              System.err.println("ERROR: Database2HostAssigner.assignNewDbToHost(S,b) => failed to insert dbName, host pair (" + dbName + ", " + retVal + "). Error details logged.") ;
              retVal = null ;
            }
            db.closeConnection(mainDbConn) ;
          }
          catch(Exception ex)
          {
            System.err.println("ERROR: Database2HostAssigner.assignNewDbToHost(S,b) => problem getting connection? Details: " + ex.getMessage()) ;
            ex.printStackTrace(System.err) ;
          }
        }
      }
    }
    return retVal ;
  }
}
