package org.genboree.util;


import org.genboree.dbaccess.util.TasksTable;

import java.io.InputStream;


public class TaskWrapper implements Runnable
{

  protected String cmd = null;
  protected Thread thr = null;
  protected boolean appendTaskId = false;
  protected long taskId = -1;
  protected int errorLevel;
  protected StringBuffer stderr;
  protected StringBuffer stdout;
  protected String appendToEnd = "";


  public TaskWrapper( String command )
  {
    setCmd( command );
    initializeStringBuffers();
  }


  public TaskWrapper( String command, boolean appendTaskId )
  {
    setCmd( command );
    this.appendTaskId = appendTaskId;
    initializeStringBuffers();
  }

  public void initializeStringBuffers()
  {
    stderr = new StringBuffer( 200 );
    stdout = new StringBuffer( 200 );
  }

  public String getStderr()
  {
    return stderr.toString();
  }

  public void setStderr( String stderr )
  {
    this.stderr.append( stderr );
  }

  public String getStdout()
  {
    return stdout.toString();
  }

  public void setStdout( String stdout )
  {
    this.stdout.append( stdout );
  }

  public int getErrorLevel()
  {
    return errorLevel;
  }

  public void setErrorLevel( int errorLevel )
  {
    this.errorLevel = errorLevel;
  }

  public long getTaskId()
  {
    return taskId;
  }

  public boolean isAppendTaskId()
  {
    return appendTaskId;
  }

  public void setCmd( String command )
  {
    this.cmd = Util.urlDecode( command );
  }

  public void setAppendToEnd( String appendToEndStr )
  {
    appendToEnd = Util.urlDecode( appendToEndStr );
  }

  public String getAppendToEnd()
  {
    return appendToEnd;
  }

  // env here will be IGNORED NOW. Not needed. Make sure tomcat is running in a properly
  // set up environment.
  private void runCommand()
  {
//    System.err.println( "RUN COMMAND: " + cmd + appendToEnd );
    Process pr = null;
    String[] arrayOfCommands;
    String localStdout = "";
    String localStderr = "";
    int localErrorLevel = -1;
    try
    {
      // Run the sub-process:
      arrayOfCommands = cmd.split( " " );
//            pr = Runtime.getRuntime().exec(arrayOfCommands);

      pr = Runtime.getRuntime().exec( cmd + " " + appendToEnd );
      System.err.println( "TaskWrapper ---> After starting the process the command is " + cmd + " " + appendToEnd );
     System.err.flush();

      // Placeholders for the stdout and stderr of the sub-process:
      StringBuffer prStdoutBuffer = new StringBuffer();
      StringBuffer prStderrBuffer = new StringBuffer();
      // Get the streams for the sub-process' stdout and stderr:
      InputStream p_in = pr.getInputStream();
      InputStream p_err = pr.getErrorStream();
      // Start the threads who *asynchronously gobble the sub-process' two streams:
      // (This helper class is defined at the top of this file)
      InputStreamHandler prStdoutHandler = new InputStreamHandler( prStdoutBuffer, p_in );
      InputStreamHandler prStderrHandler = new InputStreamHandler( prStderrBuffer, p_err );
      // Wait for sub-process to end (which truly happens when *both* its stderr and stdout are emptied by someone):
      localErrorLevel = pr.waitFor();
      // Just to be clean, there is no way the stream handler threads can be doing stuff, so:
      prStdoutHandler.join();
      prStderrHandler.join();
      // Capture stream content as strings and store in the output Hash
      localStdout = prStdoutBuffer.toString();
      setStdout( localStdout );
      localStderr = prStderrBuffer.toString();
      setStderr( localStderr );
      setErrorLevel( localErrorLevel );
      pr.destroy();
//      System.err.println("the taskwrapper has an exit value of " + getErrorLevel() + " and the taskTable state is " + TasksTable.getStateFromId( getTaskId() ));
      if( getErrorLevel() == 0 )
        TasksTable.clearStateBits( getTaskId(), Constants.RUNNING_STATE | Constants.PENDING_STATE );
      else
        TasksTable.setStateBits( getTaskId(), Constants.FAIL_STATE );
//      System.err.println("the taskwrapper has an exit value of " + getErrorLevel() + " and the taskTable state is " + TasksTable.getStateFromId( getTaskId() ));
    }
    catch( Throwable th )
    {
      TasksTable.setStateBits( getTaskId(), Constants.FAIL_STATE );
      System.err.println( "ERROR: Uploader#run(): " + th.toString() );
      th.printStackTrace( System.err );
      System.err.flush();
    }

  }

  private void createATask()
  {
    taskId = TasksTable.insertNewTask( cmd, Constants.PENDING_STATE );
//    System.err.println( "Inside the taskWrapper The id in the TaskTable is " + taskId + "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\n\n" );
//    System.err.println( cmd );
  }


  public boolean startIt()
  {
    try
    {
      thr = new Thread( this );
      thr.setDaemon( true );
      thr.start();
      return thr.isDaemon();
    }
    catch( Exception ex )
    {
      System.err.print( "The thread fail!!" );
      ex.printStackTrace( System.err );
    }
    finally
    {
      return false;
    }
  }

  public void run()
  {

    // create a urldecoded string with cmd
    // insert a task

    createATask();
    if( isAppendTaskId() )
    {
      String appendTask = " -y " + getTaskId();
      cmd += appendTask;
    }
    runCommand();
    // Need to check if the error is ok
    // if error level == 0 set 0 as the task state
    // if error leve > 0 set the task state as error

//    System.err.println( "The stdout is " + getStdout() );
//    System.err.println( "The Stderr is " + getStderr() );

//    System.err.println( "The error Level is " + getErrorLevel() );
//    System.err.flush();


  }


  public static void printUsage()
  {
    System.out.print( "usage: TaskWrapper " );
    System.out.println(
            "-c command(url encoded) -a appendTaskId -e appendToEnd \n " );

  }


  public static void main( String[] args )
  {
    String command = null;
    boolean appendTaskId = false;
    String appendToEnd = null;


    int exitError = 0;

    if( args.length < 2 )
    {
      printUsage();
      System.exit( -1 );
    }

    if( args.length >= 1 )
    {

      for( int i = 0; i < args.length; i++ )
      {
        if( args[ i ].compareToIgnoreCase( "-c" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            command = args[ i ];
          }
        } else if( args[ i ].compareToIgnoreCase( "-e" ) == 0 )
        {
          i++;
          if( args[ i ] != null )
          {
            appendToEnd = args[ i ];
          }
        } else if( args[ i ].compareToIgnoreCase( "-a" ) == 0 )
        {
          appendTaskId = true;
        }
      }

    } else
    {
      printUsage();
      System.exit( -1 );
    }


    TaskWrapper taskWrapper = new TaskWrapper( command, appendTaskId );
    if( appendToEnd != null && appendToEnd.length() > 0 )
      taskWrapper.setAppendToEnd( appendToEnd );

//        System.err.println("Want to know there the stderr is going ");
//
//        for (int i = 0; i < args.length; i++)
//        {
//            System.err.println(args[i] + " ");
//
//        }
//        System.err.flush();

    Thread thr2 = new Thread( taskWrapper );
    thr2.start();

    try
    {
      thr2.join();
    }
    catch( InterruptedException e )
    {
      e.printStackTrace( System.err );
    }
    exitError = taskWrapper.getErrorLevel();
    //  System.err.println(uploader.getStderr());
    if( exitError == 0 )
    {
      System.out.println( "File was Uploaded successfully!" );
      System.out.flush();
    }
    System.exit( exitError );

  }

}


