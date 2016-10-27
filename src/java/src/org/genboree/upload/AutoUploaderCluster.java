package org.genboree.upload ;

import java.util.* ;
import org.genboree.util.* ;

// This AutoUploader uses UploaderCluster and thus does NOT do:
// - File decompression
// - Lockfile permission
// - Email sending
// - Validate LFF etc
// - Compress results/intermediaries
// - Task table updates
public class AutoUploaderCluster
{
  // ------------------------------------------------------------------
  // CLASS METHODS
  // ------------------------------------------------------------------
  public static void printUsage()
  {
    System.out.print("usage: AutoUploader ") ;
    System.out.println(
      "-f fileName -r refseqId \n " +
      "Optional [\n" +
      "\t-u genboreeUserId \n" +
      "\t-t typeOfFile ( lff, blat, blast or agilent) \n" +  //, or gff ) ] ");
      "\t-x { delete Entry Points} \n" +
      "\t-o { delete Annotations } \n" +
      "\t-d { delete data tables and ftype tables } \n"+
      "\t-n { ignore entryPoints default update/insert entryPoints } \n" +
      "\t-b { set the debugging off } \n" +
      "\t-p sleep time between inserts \n" +
      "\t-w numberOfInserts (default Number of Inserts = " + LffConstants.defaultNumberOfInserts + ")\n" +
      "\t--segment Agilent to lff only \n" +
      "\t--histogram Agilent to lff only\n" +
      "\t--type passed to transformers \n" +
      "\t--class passed to transformers \n" +
      "\t--gainloss Agilent to lff only\n" +
      "\t--subtypepassed to transformers \n" +
      "\t --AnyAdditional argument to pass\n" +
      "]\n") ;
  }

  public static void main(String[] args)
  {
    String fileName = null;
    String usersId = null;
    String refseqId = null;
    String inputFormat = null;
    String genboreeId = null;
    String bufferString = null;
    boolean debugging = true;
    boolean ignoreEntryPoints = false;
    boolean deleteAnnotations = false;
    boolean deleteEntryPoints = false;
    boolean deleteAnnotationsAndFtypes = false;
    int bufferSize = 0 ;
    boolean setBufferSize = false;
    int sleepTime = LffConstants.uploaderSleepTime;
    boolean modifySleepTime = false;
    HashMap extraOptions = new HashMap();
    String groupPermission = null;
    int exitError = 0 ;

    if(args.length < 4)
    {
      printUsage() ;
      System.exit(-1) ;
    }
    else
    {
      // ------------------------------------------------------------------
      // Parse Args (separate method?)
      for(int i = 0; i < args.length; i++ )
      {
        if(args[i].compareToIgnoreCase("-f") == 0)
        {
          i++;
          if(args[i] != null)
          {
            fileName = args[i];
          }
        }
        else if(args[i].compareToIgnoreCase("-u") == 0)
        {
          i++;
          if(args[i] != null)
          {
            genboreeId = args[i] ;
          }
        }
        else if(args[i].compareToIgnoreCase("-b") == 0)
        {
          debugging = false ;
        }
        else if(args[i].startsWith("--") )
        {
           String tempArg = args[i];
           tempArg = tempArg.replaceFirst("--", "");
           String[] nameValue = tempArg.split("=");
           if(nameValue.length == 1)
           {
               extraOptions.put(nameValue[0], "");
           }
           else if(nameValue.length == 2)
           {
                extraOptions.put(nameValue[0], nameValue[1]);
           }
           else
           {
                System.err.println("The argument passed " + args[i] + " is incorrect argument would be ignored");
                System.err.flush();
           }
        }
        else if(args[i].compareToIgnoreCase("-n") == 0)
        {
          ignoreEntryPoints = true;
        }
        else if(args[i].compareToIgnoreCase("-x") == 0)
        {
          deleteEntryPoints = true;
          deleteAnnotationsAndFtypes = true;
        }
        else if(args[i].compareToIgnoreCase("-o") == 0)
        {
          deleteAnnotations = true;
        }
        else if(args[i].compareToIgnoreCase("-d") == 0)
        {
          deleteAnnotationsAndFtypes = true;
        }
        else if(args[i].compareToIgnoreCase("-w") == 0)
        {
          i++;
          if(args[i] != null)
          {
            bufferString = args[i];
            bufferSize = Util.parseInt(bufferString , -1);
            if(bufferSize > 0)
            {
              setBufferSize = true;
            }
          }
        }
        else if(args[i].compareToIgnoreCase("-p") == 0)
        {
          i++;
          if(args[i] != null)
          {
            bufferString = args[i] ;
            sleepTime = Util.parseInt(bufferString , -1) ;
            if(sleepTime > -1)
            {
              modifySleepTime = true ;
            }
          }
        }
        else if(args[i].compareToIgnoreCase("-r") == 0)
        {
          i++;
          if(args[i] != null)
          {
            refseqId = args[i] ;
          }
        }
        else if(args[i].compareToIgnoreCase("-t") == 0)
        {
          i++;
          if(args[i] != null)
          {
            inputFormat = args[i];
          }
        }
      }
    }

    int i = 0;
    // User allowed to upload?
    groupPermission = GenboreeUtils.fetchGroupIdFromRefseqIdAndUserCanWrite(refseqId, genboreeId, false) ;
    if(groupPermission == null)
    {
      System.err.print("FORBIDDEN: the user id" + genboreeId + " does not have permission to upload to refSeqid  " + refseqId) ;
      System.exit(45) ;
    }

    // Should be able to upload.
    // - Make upload driver instance:
    org.genboree.upload.UploaderCluster uploader = new UploaderCluster(refseqId, fileName, genboreeId, inputFormat) ;
    if(uploader.isMissingInfo())
    {
      printUsage() ;
      System.err.println("FATAL ERROR: not enough information was provided to the uploader for it to proceed.") ;
      System.exit(46) ;
    }

    // - Configure upload driver:
    uploader.setDebug(debugging);
    if(extraOptions.size() > 0)
    {
      uploader.setExtraOptions(extraOptions) ;
    }

    uploader.setIgnoreEntryPoints(ignoreEntryPoints);
    uploader.setDeleteAnnotations(deleteAnnotations);
    uploader.setDeleteAnnotationsAndFtypes(deleteAnnotationsAndFtypes);
    uploader.setDeleteEntryPoints(deleteEntryPoints);
    uploader.setSleepTime(sleepTime);
    if(setBufferSize)
    {
      uploader.setMaxInsertSize(bufferSize) ;
    }

    // - Run upload driver:
    uploader.run() ;

    // - Collect exit status, suitable feedback, etc.
    exitError = uploader.getErrorLevel() ;
    // - Try carefully to output feedback from the upload driver
    try
    {
      System.out.println(uploader.constructFeedback()) ;
    }
    catch(Throwable th)
    {
      // record the error to Stderr
      System.err.println("FATAL ERROR: Could not construct suitable feedback (lack of robustness or default state variables in constructFeedback(). (uploader's errorLevel was " + exitError + "):");
      th.printStackTrace( System.err ) ;
      exitError = 74 ;
    }
    System.exit(exitError) ;
  }
}
