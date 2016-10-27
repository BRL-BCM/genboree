package org.genboree.dbaccess.util;

import java.sql.*;
import org.genboree.dbaccess.*;

// Class for -selected- useful actions on the database2host table
public class TasksTable {
  // Get the command for a specific task. Connection to main genboree database required.
  public static String getCmdFromId(long id) {
    String command = null;
    DBAgent db = null;
    PreparedStatement stmt = null;
    ResultSet rs = null;
    Connection conn = null;
    String sql = "select command from tasks where id = ? ";

    try {
      db = DBAgent.getInstance();
      conn = db.getConnection();
      stmt = conn.prepareStatement(sql);
      stmt.setLong(1, id);
      rs = stmt.executeQuery();
      if (rs.next()) {
        command = rs.getString("command");
      }
    }
    catch (Exception ex) {
      System.err.println("ERROR: TasksTable#getCmdFromId() => exception getting cmd of a task.");
      System.err.println(ex.getMessage());
      ex.printStackTrace(System.err);
    }
    finally {
      db.safelyCleanup(rs, stmt, conn);
      return command;
    }
  }




  public static boolean truncateTasksTable() {
    boolean retVal = false;
    DBAgent db = null;
    PreparedStatement stmt = null;
    String sql = "TRUNCATE tasks";
    Connection conn = null;
    ResultSet rs = null;


    try {
      db = DBAgent.getInstance();
      conn = db.getConnection();
      stmt = conn.prepareStatement(sql);
      int rowsDeleted = stmt.executeUpdate();
      if (rowsDeleted > 0)
      {
        retVal = true;
      }
      else
      {
        System.err.println("ERROR: TasksTable::truncateTaskTable => truncate table '" +
                "' didn't delete rows. This is not right, why?");
        retVal = false;
      }
    }
    catch (Exception ex) {
      System.err.println("ERROR: TasksTable::truncateTaskTable => exception truncating table tasks ='" +
              "'. Details: " + ex.getMessage());
      ex.printStackTrace(System.err);
      retVal = false;
    }
    finally {
      db.safelyCleanup(rs, stmt, conn);
      return retVal;
    }

  }

  public static boolean deleteATask(long id) {
    boolean retVal = false;
    DBAgent db = null;
    PreparedStatement stmt = null;
    String sql = "DELETE FROM tasks WHERE id = ? ";
    Connection conn = null;
    ResultSet rs = null;

    if (id < 1 )
      return retVal;

    try {
      db = DBAgent.getInstance();
      conn = db.getConnection();
      stmt = conn.prepareStatement(sql);
      stmt.setLong(1, id);
      int rowsDeleted = stmt.executeUpdate();
      if (rowsDeleted == 1) {
        retVal = true;
      } else {
        System.err.println("ERROR: TasksTable::deleteATask => deleting the id  = '" +
                id + "' didn't delete exactly 1 row (deleted " + rowsDeleted + " rows). This is not right, why?");
        retVal = false;
      }
    }
    catch (Exception ex) {
      System.err.println("ERROR: TasksTable::deleteATask => exception deleting the task id ='" +
              id + "'. Details: " + ex.getMessage());
      ex.printStackTrace(System.err);
      retVal = false;
    }
    finally {
      db.safelyCleanup(rs, stmt, conn);
      return retVal;
    }

  }

  // Insert new record into Task table (generally when running a new application on genboree).
  // NOTE: At this time, we don't allow even *trying* to insert a new record for a database that
  // is ALREADY in the table. We check explicitly for this case, since it would be an error.
  // Connection to main genboree database required.


  public static long insertNewTask(String cmd, long state)
  {
    return insertNewTask(cmd, state, true);
  }

  public static long insertNewTask(String cmd, long state, boolean doCache)
  {
    boolean retVal = false;
    ResultSet rs = null;
    DBAgent db = null;
    PreparedStatement stmt = null;
    String sql = "INSERT INTO tasks (id, command, timestamp, state) VALUES(null, ?, now(), ?)";
    String sqlLastId = "SELECT LAST_INSERT_ID()";
    long lastId = -1;
    Connection conn = null;


    if (cmd != null && (cmd.length() > 0) && state >= 0) // Yes.
    {
      try {
        db = DBAgent.getInstance();
        if(doCache)
              conn = db.getConnection();
            else
              conn = db.getNoCacheConnection(null);

        stmt = conn.prepareStatement(sql);
        stmt.setString(1, cmd);
        stmt.setLong(2, state);
        int numRowsInserted = stmt.executeUpdate();

        // pop style hash
        if (numRowsInserted > 0) {
          retVal = true;

          stmt = conn.prepareStatement(sqlLastId);

          rs = stmt.executeQuery();
          if (rs.next()) {
            lastId = rs.getLong(1);
          }
        } else {
          System.err.println("ERROR: TaskTable.insertNewTask(S,S) => insertion of cmd, state pair didn't insert 1 row as expected." +
                  ". cmd => '" + cmd + "' ; state => '" + state + "'.");
        }

      }
      catch (SQLException ex1) {
        ex1.printStackTrace(System.err);
      }
      catch (Exception ex) {
        System.err.println("ERROR: TaskTable.insertNewTask(S,S) => SQL insert of cmd, state pair threw exception and failed. Details: " + ex.getMessage());
        ex.printStackTrace(System.err);
        retVal = false;
      }
      finally {
        db.safelyCleanup(rs, stmt, conn);
        return lastId;
      }
    } else // No.
    {
      System.err.println("ERROR: TaskTable.insertNewTask(S,S) called with bad arguments...neither cmd nor state can be null" +
              "cmd => " + cmd + " ; state => " + state);
    }
    return lastId;
  }

  // Set a particular state bit for the provided taskId
  // eg TaskTable.setStateBit(2830, Constants.PENDING)
  // Returns number of rows updated
  // - Note, you can even use this to set multiple bits at the same time
  //   TaskTable.setStateBits(2830, Constants.PENDING | Constants.ERROR)
  public static int setStateBits(long id, long stateBits)
  {
    return setStateBits(id, stateBits, true);
  }


  public static int setStateBits(long id, long stateBits, boolean doCache)
  {
    int numRowsUpdated = 0 ;
    ResultSet rs = null ;
    DBAgent db = null ;
    PreparedStatement stmt = null ;
    String sql = "UPDATE tasks set state = (state | ?) where id = ?" ;
    Connection conn = null ;

    if(id < 0)
    {
      System.err.println("TaskTable.setStateBit(l,l) => Unable to update the status due to bad task id");
    }
    else if(stateBits < 0)
    {
      System.err.println("TaskTable.setStateBit(l,l) => Unable to update the status due to bad state bit");
    }
    else
    {
      try
      {
        db = DBAgent.getInstance() ;
        if(doCache)
          conn = db.getConnection();
        else
          conn = db.getNoCacheConnection(null);
        stmt = conn.prepareStatement(sql) ;
        stmt.setLong(1, stateBits) ;
        stmt.setLong(2, id) ;
        numRowsUpdated = stmt.executeUpdate() ;

        if(numRowsUpdated <= 0)
        {
          System.err.println( "TaskTable.setStateBit(l,l) => ERROR: => update of status, id pair didn't update 1 row as expected." +
                  ". id => '" + id + "' ; state => '" + stateBits + "'.") ;
        }
      }
      catch(Exception ex1)
      {
        System.err.println( "TaskTable.setStateBit(l,l) => ERROR: => exception updating state bits." +
                ". id => '" + id + "' ; state => '" + stateBits + "'.") ;
        ex1.printStackTrace(System.err) ;
      }
      finally
      {
        db.safelyCleanup(rs, stmt, conn);
      }
    }
    return numRowsUpdated ;
  }

  // Toggle a particular state bit for the provided taskId. If on, it will be off. If off, it will be on.
  // eg TaskTable.toggleStateBits(2830, Constants.PENDING)
  // Returns number of rows updated
  // - Note, you can even use this to toggle multiple bits at the same time
  //   TaskTable.toggleStateBits(2830, Constants.PENDING | Constants.ERROR)
  public static int toggleStateBits(long id, long stateBits)
  {
    int numRowsUpdated = 0 ;
    ResultSet rs = null ;
    DBAgent db = null ;
    PreparedStatement stmt = null ;
    String sql = "UPDATE tasks set state = (state ^ ?) where id = ?" ;
    Connection conn = null ;

    if(id < 0)
    {
      System.err.println("TaskTable.toggleStateBits(l,l) => Unable to update the status due to bad task id");
    }
    else if(stateBits < 0)
    {
      System.err.println("TaskTable.toggleStateBits(l,l) => Unable to update the status due to bad state bit");
    }
    else
    {
      try
      {
        db = DBAgent.getInstance() ;
        conn = db.getConnection() ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setLong(1, stateBits) ;
        stmt.setLong(2, id) ;
        numRowsUpdated = stmt.executeUpdate() ;

        if(numRowsUpdated <= 0)
        {
          System.err.println( "TaskTable.toggleStateBits(l,l) => ERROR: => update of status, id pair didn't update 1 row as expected." +
                  ". id => '" + id + "' ; state => '" + stateBits + "'.") ;
        }
      }
      catch(Exception ex1)
      {
        System.err.println( "TaskTable.toggleStateBits(l,l) => ERROR: => exception updating state bits." +
                ". id => '" + id + "' ; state => '" + stateBits + "'.") ;
        ex1.printStackTrace(System.err) ;
      }
      finally
      {
        db.safelyCleanup(rs, stmt, conn);
      }
    }
    return numRowsUpdated ;
  }

  // Clear (unset) a particular state bit for the provided taskId
  // eg TaskTable.clearStateBits(2830, Constants.PENDING)
  // Returns number of rows updated
  // - Note, you can even use this to clear multiple bits at the same time
  //   TaskTable.clearStateBits(2830, Constants.PENDING | Constants.ERROR)
  public static int clearStateBits(long id, long stateBits)
  {
    return clearStateBits(id, stateBits, true);
  }
  public static int clearStateBits(long id, long stateBits, boolean doCache)
  {
    int numRowsUpdated = 0 ;
    ResultSet rs = null ;
    DBAgent db = null ;
    PreparedStatement stmt = null ;
    String sql = "UPDATE tasks set state = (state & ~?) where id = ?" ;
    Connection conn = null ;

    if(id < 0)
    {
      System.err.println("TaskTable.clearStateBits(l,l) => Unable to update the status due to bad task id");
    }
    else if(stateBits < 0)
    {
      System.err.println("TaskTable.clearStateBits(l,l) => Unable to update the status due to bad state bit");
    }
    else
    {
      try
      {
        db = DBAgent.getInstance() ;

        if(doCache)
          conn = db.getConnection();
        else
          conn = db.getNoCacheConnection(null);
        stmt = conn.prepareStatement(sql) ;
        stmt.setLong(1, stateBits) ;
        stmt.setLong(2, id) ;
        numRowsUpdated = stmt.executeUpdate() ;

        if(numRowsUpdated <= 0)
        {
          System.err.println( "TaskTable.clearStateBits(l,l) => ERROR: => update of status, id pair didn't update 1 row as expected." +
                  ". id => '" + id + "' ; state => '" + stateBits + "'.") ;
        }
      }
      catch(Exception ex1)
      {
        System.err.println( "TaskTable.clearStateBits(l,l) => ERROR: => exception updating state bits." +
                ". id => '" + id + "' ; state => '" + stateBits + "'.") ;
        ex1.printStackTrace(System.err) ;
      }
      finally
      {
        db.safelyCleanup(rs, stmt, conn);
      }
    }
    return numRowsUpdated ;
  }

  // Get the state for a specific task. Connection to main genboree database required.
  public static long getStateFromId(long id)
  {
    long state = -1;
    DBAgent db = null;
    PreparedStatement stmt = null;
    ResultSet rs = null;
    Connection conn = null;
    String sql = "select state from tasks where id = ? ";
//    System.err.println("TasksTable the query = " + sql + " and the id = " + id);

    try {
      db = DBAgent.getInstance();
      conn = db.getConnection();
      stmt = conn.prepareStatement(sql);
      stmt.setLong(1, id);
      rs = stmt.executeQuery();
      if (rs.next()) {
        state = rs.getLong("state");
      }
    }
    catch (Exception ex) {
      System.err.println("ERROR: TasksTable::getStateFromId() => exception getting the state of a task.");
      System.err.println(ex.getMessage());
      ex.printStackTrace(System.err);
    }
    finally {
      db.safelyCleanup(rs, stmt, conn);
      return state;
    }
  }


  // Get a particular state bit for the provided taskId
  // eg TaskTable.getStateBits(2830, Constants.PENDING)
  // Returns 0 (not set) or stateBits (bits are set)
  // - Note, you can even use this to check if ALL multiple bits at the same time
  //   TaskTable.getStateBits(2830, Constants.PENDING | Constants.ERROR)
  public static int getStateBit(long id, long stateBits)
  {
    int numRowsUpdated = 0 ;
    ResultSet rs = null ;
    DBAgent db = null ;
    PreparedStatement stmt = null ;
    String sql = "select (state & ?) from tasks where = ?" ;
    Connection conn = null ;

    if(id < 0)
    {
      System.err.println("TaskTable.getStateBit(l,l) => Unable to update the status due to bad task id");
    }
    else if(stateBits < 0)
    {
      System.err.println("TaskTable.getStateBit(l,l) => Unable to update the status due to bad state bit");
    }
    else
    {
      try
      {
        db = DBAgent.getInstance() ;
        conn = db.getConnection() ;
        stmt = conn.prepareStatement(sql) ;
        stmt.setLong(1, stateBits) ;
        stmt.setLong(2, id) ;
        numRowsUpdated = stmt.executeUpdate() ;

        if(numRowsUpdated <= 0)
        {
          System.err.println( "TaskTable.getStateBit(l,l) => ERROR: => update of status, id pair didn't update 1 row as expected." +
                  ". id => '" + id + "' ; state => '" + stateBits + "'.") ;
        }
      }
      catch(Exception ex1)
      {
        System.err.println( "TaskTable.getStateBit(l,l) => ERROR: => exception updating state bits." +
                ". id => '" + id + "' ; state => '" + stateBits + "'.") ;
        ex1.printStackTrace(System.err) ;
      }
      finally
      {
        db.safelyCleanup(rs, stmt, conn);
      }
    }
    return numRowsUpdated ;
  }

  // This replaces the whole state value with a new one
  public static boolean updateTaskStatus(long id, Long state)
  {
    boolean retVal = false;
    ResultSet rs = null;
    DBAgent db = null;
    PreparedStatement stmt = null;
    String sql = "UPDATE tasks set state = ? where id = ?";
    Connection conn = null;


    if (id < 0) {
      System.err.println("Unable to update the status in TasksTable::updateTaskStatus missing id");
      return retVal;
    }

    if (state < 0) {
      System.err.println("Unable to update the status in TasksTable::updateTaskStatus missing new status");
      return retVal;
    }

    try {
      db = DBAgent.getInstance();
      conn = db.getConnection();
      stmt = conn.prepareStatement(sql);
      stmt.setLong(1, state);
      stmt.setLong(2, id);
      int numRowsInserted = stmt.executeUpdate();

      // pop style hash
      if (numRowsInserted > 0) {
        retVal = true;


      } else {
        System.err.println("ERROR: TaskTable.updateTaskStatus(S,S) => update of status, id pair didn't updated 1 row as expected." +
                ". id => '" + id + "' ; state => '" + state + "'.");
      }

    }
    catch (SQLException ex1) {
      ex1.printStackTrace(System.err);
    }
    catch (Exception ex) {
      System.err.println("ERROR: TaskTable.insertNewTask(S,S) => SQL insert of cmd, state pair threw exception and failed. Details: " + ex.getMessage());
      ex.printStackTrace(System.err);
    }
    finally {
      db.safelyCleanup(rs, stmt, conn);
      return retVal;
    }
  }


}
