package org.genboree.util;

import java.io.*;
import java.util.*;


public class RunExternalProcess implements Runnable {
    protected String cmd = null;
    HashMap outPut = null;
    protected Thread thr = null;
    protected final String nohup = "/usr/bin/nohup";
    protected int errorLevel;
    protected StringBuffer stderr;
    protected StringBuffer stdout;

    public RunExternalProcess(String command)
    {
        StringBuffer tempCmd =  new StringBuffer(200);

        tempCmd.append(nohup).append(" ").append(command);

        setCmd(tempCmd.toString());

        initializeStringBuffers();
        startIt();
        System.err.println("After starting the process the cmd is " + cmd);
        System.err.flush();

    }


    public void setStderr(String stderr)
    {
        this.stderr.append(stderr);
    }

    public String getStderr()
    {
        return stderr.toString();
    }

    public String getStdout()
    {
        return stdout.toString();
    }

    public void setStdout(String stdout)
    {
        this.stdout.append(stdout);
    }

    public int getErrorLevel()
    {
        return errorLevel;
    }

    public void setErrorLevel(int errorLevel)
    {
        this.errorLevel = errorLevel;
    }


    public void setCmd(String cmd)
    {
        this.cmd = cmd;
    }


    public void initializeStringBuffers()
    {
        stderr = new StringBuffer(200);
        stdout = new StringBuffer(200);
    }

    // env here will be IGNORED NOW. Not needed. Make sure tomcat is running in a properly
    // set up environment.
    public void runCommandaCollectInfo(String command)
    {
        System.err.println("RUN COMMAND: " + command);
        Process pr = null;
        String localStdout = "";
        String localStderr = "";
        int localErrorLevel = -1;
        int maxBytes = 1000000; //8192; //4096;//2048;
        outPut = new HashMap();
        try
        {
            // Run the sub-process:

            pr = Runtime.getRuntime().exec(command);
            // Placeholders for the stdout and stderr of the sub-process:
            StringBuffer prStdoutBuffer = new StringBuffer();
            StringBuffer prStderrBuffer = new StringBuffer();
            // Get the streams for the sub-process' stdout and stderr:
            InputStream p_in = pr.getInputStream();
            InputStream p_err = pr.getErrorStream();
            // Start the threads who *asynchronously gobble the sub-process' two streams:
            // (This helper class is defined at the top of this file)
            InputStreamHandler prStdoutHandler = new InputStreamHandler(prStdoutBuffer, p_in);
            InputStreamHandler prStderrHandler = new InputStreamHandler(prStderrBuffer, p_err);
            // Wait for sub-process to end (which truly happens when *both* its stderr and stdout are emptied by someone):
            localErrorLevel = pr.waitFor();
            // Just to be clean, there is no way the stream handler threads can be doing stuff, so:
            prStdoutHandler.join();
            prStderrHandler.join();
            // Capture stream content as strings and store in the output Hash
            localStdout = prStdoutBuffer.toString();
            localStderr = prStderrBuffer.toString();
            setStdout(localStdout);
            setStderr(localStderr);
            setErrorLevel(localErrorLevel);
            pr.destroy();
        }
        catch (Throwable th)
        {

            System.err.println("ERROR: Uploader#run(): " + th.toString());
            th.printStackTrace(System.err);
            System.err.flush();
        }
        finally
        {
            // I am not sure what to do in here
            if (getErrorLevel() == 0)
                System.err.println("RunExternalProcess was successful");
            else
                System.err.println("RunExternalProcess failed !!!!!!!!!!!!!!!!");
        }
    }


    public boolean startIt()
    {
        try
        {
            thr = new Thread(this);
            thr.setDaemon(true);
            thr.start();
            return thr.isDaemon();
        }
        catch (Exception ex)
        {
            System.err.print("The thread fail!!");
            ex.printStackTrace(System.err);
        }
        finally 
        {
            return false;
        }
    }

    public void run()
    {
        runCommandaCollectInfo(cmd);
        System.err.println("The stdout is " + getStdout());
        System.err.println("The Stderr is " + getStderr());
        System.err.println("The error Level is " + getErrorLevel());
        System.err.flush();
    }


}
