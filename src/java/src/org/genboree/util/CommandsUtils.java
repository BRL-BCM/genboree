package org.genboree.util;

import java.io.*;
import java.util.*;
import java.util.zip.GZIPOutputStream;

public class CommandsUtils
{
  public static boolean changePermission(String fileName, String permission)
  {
    Process pr = null;
    String localStdout = "";
    String localStderr = "";
    int localErrorLevel = -1;
    boolean success = false;

    String cmd = "/bin/chmod " + permission + " " + fileName;

    try
    {
        pr = Runtime.getRuntime().exec(cmd);
        InputStream p_in = pr.getInputStream();
        InputStream p_err = pr.getErrorStream();
        StringBuffer outString = new StringBuffer();
        StringBuffer errString = new StringBuffer();

        int outPutCharCollector;
        int cnt = 0;
        while( (outPutCharCollector = p_in.read()) != -1 )
        {
            outString.append( (char)outPutCharCollector );
            if( ++cnt > 2048 ) break;
        }
        localStdout = outString.toString();

        errString.setLength( 0 );
        cnt = 0;
        while( (outPutCharCollector = p_err.read()) != -1 )
        {
            errString.append( (char)outPutCharCollector );
            if( ++cnt > 2048 ) break;
        }
        localStderr = errString.toString();
        localErrorLevel = pr.waitFor();
        if(localErrorLevel == 0)
        success = true;
            pr.destroy();
    } catch( Exception ex01 )
    {
        System.err.println("DirectoryUtils#changePermission: Error during changing permission to file " + fileName);
        System.err.println("    the stdout is " + localStdout);
        System.err.println("    the stderr is " + localStderr);
        System.err.println("    the error level is " + localErrorLevel);
        ex01.printStackTrace(System.err);
        System.err.flush();
    }
    finally
    {
        return success;
    }
  }

  // Java 1.5 - needed for System.getenv()
  // This method turns the current environment in to a String[] suitable for use
  // in Runtime.exec() calls so you can pass the current environment on to sub-processes.
  // Java is kinda dumb in that it doesn't do this by default.
  public static String[] createEnvVarArray()
  {
    // Loop through each item in OUR environment and add it to the list
    Map env = System.getenv() ;
    String[] envArrayList = new String[env.size()] ;
    int envCount = 0 ;
    for(Iterator iter = env.entrySet().iterator(); iter.hasNext(); )
    {
      Map.Entry entry = (Map.Entry)iter.next() ;
      envArrayList[envCount] = ("" + entry.getKey() + "=" + entry.getValue()) ;
      envCount += 1 ;
    }
    return envArrayList ;
  }

  public static HashMap runCommandaCollectInfo(String command, String dir)
  {
    return runCommandaCollectInfo(command, null, dir) ;
  }

  // env here will be IGNORED NOW. Not needed. Make sure tomcat is running in a properly
  // set up environment.
  public static HashMap runCommandaCollectInfo(String command, String[] env, String dir)
  {
    System.err.println("RUN COMMAND: " + command) ;
    Process pr = null;
    String localStdout = "";
    String localStderr = "";
    int localErrorLevel = -1;
    HashMap outPut = null;
    int maxBytes = 1000000; //8192; //4096;//2048;
    String[] realEnv = createEnvVarArray() ;
    outPut = new HashMap();
    try
    {
      // Run the sub-process:
      pr = Runtime.getRuntime().exec(command, realEnv, new File(dir));
      // Placeholders for the stdout and stderr of the sub-process:
      StringBuffer prStdoutBuffer = new StringBuffer() ;
      StringBuffer prStderrBuffer = new StringBuffer() ;
      // Get the streams for the sub-process' stdout and stderr:
      InputStream p_in = pr.getInputStream();
      InputStream p_err = pr.getErrorStream();
      // Start the threads who *asynchronously gobble the sub-process' two streams:
      // (This helper class is defined at the top of this file)
      InputStreamHandler prStdoutHandler = new InputStreamHandler( prStdoutBuffer, p_in ) ;
      InputStreamHandler prStderrHandler = new InputStreamHandler( prStderrBuffer, p_err ) ;
      // Wait for sub-process to end (which truly happens when *both* its stderr and stdout are emptied by someone):
      localErrorLevel = pr.waitFor();
      // Just to be clean, there is no way the stream handler threads can be doing stuff, so:
      prStdoutHandler.join() ;
      prStderrHandler.join() ;
      // Capture stream content as strings and store in the output Hash
      localStdout = prStdoutBuffer.toString() ;
      outPut.put("stdout", localStdout) ;
      localStderr = prStderrBuffer.toString() ;
      outPut.put("stderr", localStderr);
      Integer errorLevel = new Integer(localErrorLevel);
      outPut.put("errorLevel", errorLevel);
      pr.destroy();
    }
    catch( Exception ex01 )
    {
      ex01.printStackTrace(System.err);
      System.err.flush();
    }
    finally
    {
      return outPut;
    }
  }

  public static HashMap transformToLff(String fileToProcess, String fileFormat, HashMap extraOptions)
  {
    File originalFile = null ;
    File parentDir = null ;
    File tempFile = null ;
    String cmd = null ;
    originalFile = new File(fileToProcess) ;
    parentDir = new File(originalFile.getParent()) ;
    tempFile =  new File(parentDir, originalFile.getName() + ".lff") ;
    String fullPathToFinalFile = null ;
    int formatId = -1 ;
    String[] formatSupported = {"lff", "blat", "blast", "agilent","pash", "wig"} ; // In the future we may support these formats: "pash", "gff"};
    String blat2lff = Constants.BLAT2LFF ;
    String blast2lff = Constants.BLAST2LFF ;
    String gff2lff = Constants.GFF2LFF ;
    String agilent2lff = Constants.AGILENT2LFF ;
    String pashTwo2lff = Constants.PASHTWO2LFF ;
    String wigUpload = Constants.WIGUPLOAD;
    String[] realEnv = createEnvVarArray() ;

    // Build the extra-arguments string
    String extraCommandStr = null ;
    if(extraOptions != null && !extraOptions.isEmpty())
    {
      StringBuffer extraCommands = new StringBuffer() ;
      Iterator keyIter = extraOptions.keySet().iterator() ;
      while(keyIter.hasNext())
      {
        // Get the name of the arg and add it to the extra-arguments string
        String myName = (String) keyIter.next() ;
        extraCommands.append(" --").append(myName) ;
        // If there is a non-null value, add it to the extra-arguments string too
        String myValue = (String) extraOptions.get(myName) ;
        if(myValue != null && !myValue.equalsIgnoreCase("")) // Null values indicate a flag-only option
        {
          // Escape value for command-line usage (put within a '' string, escpaping any ' marks and spaces in the value)
          myValue = Util.urlEncode(myValue) ;
          extraCommands.append("=").append(myValue) ;
        }
      }
      extraCommandStr = extraCommands.toString() ;
    }

    HashMap outPutFromProgram = null ;
    Integer tempErrorLevel = null ;

    // Determine which format the upload file is in
    if(fileFormat == null)
    {
      formatId = 0 ;
    }
    else
    {
      for(int ii = 0; ii < formatSupported.length; ii++)
      {
        if(fileFormat.equalsIgnoreCase(formatSupported[ii]))
        {
          formatId = ii ;
          break ; // done, why keep searching?
        }
      }
    }

    // Construct arg string (same process for all commands: standardArgs + extraArgs)
    String argsStr = " -f " + originalFile.getAbsolutePath() + " -o " + tempFile.getAbsolutePath() + extraCommandStr ;
    // Construct the command to run
    switch(formatId)
    {
      case 0:
        fullPathToFinalFile = fileToProcess ;
        outPutFromProgram = new HashMap() ;
        outPutFromProgram.put("stdout", " ") ;
        outPutFromProgram.put("stderr", " ") ;
        outPutFromProgram.put("errorLevel", new Integer(0)) ;
        break ;
      case 1:
        cmd = blat2lff + argsStr ;
        break;
      case 2:
        cmd = blast2lff + argsStr ;
        break ;
      case 3:
        cmd = agilent2lff  + argsStr ;
        break ;
      case 4:
        cmd = pashTwo2lff + argsStr ;
        break ;
      case 5:
        cmd = wigUpload + argsStr;
        break ;
    /*  case 4:
        cmd = gff2lff + argsStr ;
        break ;
    */
      default:
        outPutFromProgram = new HashMap() ;
        outPutFromProgram.put("stdout", " ") ;
        outPutFromProgram.put("stderr", fileFormat + " is not supported at the moment") ;
        outPutFromProgram.put("errorLevel", new Integer(30)) ;
        break ;
    }
    // Run command, if appropriate
    if(formatId > 0 && formatId <= 4)
    {
      outPutFromProgram = CommandsUtils.runCommandaCollectInfo(cmd, parentDir.getAbsolutePath()) ;
      tempErrorLevel = (Integer)outPutFromProgram.get("errorLevel") ;
      fullPathToFinalFile = tempFile.getAbsolutePath() ;
    }
    outPutFromProgram.put("formatedFile", fullPathToFinalFile) ;
    return outPutFromProgram;
  }

    public static HashMap extractUnknownCompressedFile(String fileName)
    {
        boolean debugging = false;
        HashMap outPutFromProgram = null;

        outPutFromProgram = extractUnknownCompressedFile(fileName, debugging);

        return outPutFromProgram;

    }

    public static HashMap extractUnknownCompressedFile(String fileName, boolean debugging)
    {
        boolean success = false;
        String uncompressedFile = null;
        HashMap outPutFromProgram = null;
        if(debugging)
        {
            System.err.println("Inside the extractUnknownCompressedFile original file name = " + fileName);
        }
        Expander expandFile = new Expander(fileName);
        expandFile.setDebug(debugging);
        expandFile.run();
        success = expandFile.isSuccess();
        if(success)
            uncompressedFile = expandFile.getUncompressedFileName();


        if(!success && debugging)
        {
            System.err.println("Expanded failed at this point why?");
        }

        outPutFromProgram = new HashMap();
        outPutFromProgram.put("stdout", expandFile.getStdout());
        outPutFromProgram.put("stderr", expandFile.getStderr());
        outPutFromProgram.put("errorLevel", new Integer(expandFile.getErrorLevel()));
        outPutFromProgram.put("uncompressedFile", uncompressedFile);
        if(debugging)
        {
            System.err.println("Inside the extractUnknownCompressedFile adding uncompressed name = " + uncompressedFile);
        }

        return outPutFromProgram;
    }

    public static void gZipFile(String inputFileName, String outFilename)
    {
        byte[] buf = new byte[1024];

        if(inputFileName == null)
        {
            System.err.println("Unable to gzip the files inputFile name missing");
            return;
        }

        if(outFilename == null || outFilename.length() < 1)
        {
            System.err.println("Missing output name");
            return;
        }

        if(inputFileName.endsWith(".gz")) return;


        File checkArchive = new File(inputFileName);
        File archiveParent = new File(checkArchive.getParent());

        if(archiveParent.exists() && archiveParent.isDirectory() && !archiveParent.canWrite())
        {
            System.err.println("Unable to write archive in directory " + archiveParent.getAbsolutePath() + " not enough permissions");
            return;
        }
        if(checkArchive == null)
        {
            System.err.println("Unable to gzip problems with the file name provided " + inputFileName);
            return;
        }

        if(!checkArchive.exists() || checkArchive.isDirectory())
        {
            System.err.println("Unable to gzip file, look like file is either a directory or does not exits " + inputFileName);
            return;
        }

        if(!checkArchive.canWrite())
        {
            System.err.println("Unable to overwrite existing file with archive not enough permissions" + inputFileName);
            return;
        }


        try {
         GZIPOutputStream out = new GZIPOutputStream(new FileOutputStream(outFilename));

         // Open the input file
         FileInputStream in = new FileInputStream(inputFileName);

         // Transfer bytes from the input file to the GZIP output stream

         int len;
         while ((len = in.read(buf)) > 0) {
             out.write(buf, 0, len);
         }
         in.close();


         out.finish();
         out.close();

        } catch (IOException e) {
            e.printStackTrace(System.err);
        }
    }

    public static void gZipFile( String inputFileName)
    {

        if(inputFileName == null)
        {
            System.err.println("Unable to gzip the files inputFile name missing");
            return;
        }



        File checkArchive = new File(inputFileName);
        File archiveParent = new File(checkArchive.getParent());

        if(archiveParent.exists() && archiveParent.isDirectory() && !archiveParent.canWrite())
        {
            System.err.println("Unable to write archive in directory " + archiveParent.getAbsolutePath() + " not enough permissions");
            return;
        }
        if(checkArchive == null)
        {
            System.err.println("Unable to gzip problems with the file name provided " + inputFileName);
            return;
        }

        if(!checkArchive.exists() || checkArchive.isDirectory())
        {
            System.err.println("Unable to gzip file, look like file is either a directory or does not exits " + inputFileName);
            return;
        }

        if(!checkArchive.canWrite())
        {
            System.err.println("Unable to overwrite existing file with archive not enough permissions" + inputFileName);
            return;
        }

        int errorLevel = -1;
        String stderr = null;
        String stdout = null;

        try {
             String gzipUtil = "/usr/bin/gzip -f ";
            String cmd = gzipUtil +  inputFileName;
            HashMap returnValues = CommandsUtils.runCommandaCollectInfo(cmd, null, archiveParent.getAbsolutePath());
            Integer tempErrorLevel = (Integer)returnValues.get("errorLevel");
            errorLevel =tempErrorLevel.intValue();
             stderr = (String)returnValues.get("stderr");
             stdout = (String)returnValues.get("stdout");


        } catch (Exception e) {
            System.err.println("DirectoryUtils.gZipFile errorLevel = " + errorLevel + " stderr = " + stderr + " stdout = " + stdout);
            e.printStackTrace(System.err);
        }
    }



    public static void printUsage()
    {
        System.out.print("usage: DirectoryCreator ");
        System.out.println("\n" +
                "-g genboreeUserId\n" +
                "-u upladId\n" +
                "-f fid\n");
        return;
    }
    public static void main(String[] args) throws Exception
    {
        boolean validFid = false;
        String userId = null;
        String uploadId = null;
        String fid = null;


        if(args.length < 6 )
        {
            printUsage();
            System.exit(-1);
        }


        if(args.length > 1)
        {

            for(int i = 0; i < args.length; i++ )
            {
                if(args[i].compareToIgnoreCase("-g") == 0)
                {
                                       i++;
                    if(args[i] != null)
                    {
                        userId = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-u") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        uploadId = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-f") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        fid = args[i];
                    }
                }

            }

        }
        else
        {
            printUsage();
            System.exit(-1);
        }


        validFid = GenboreeUtils.verifyUpladIdAndFid(userId, uploadId, fid);

        if(validFid)
            System.out.println("Valid information");
        else
            System.out.println("Wrong information");

        System.exit(0);
    }
}
