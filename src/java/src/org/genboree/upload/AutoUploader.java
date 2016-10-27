package org.genboree.upload;

import org.genboree.util.*;

import java.util.HashMap;

public class AutoUploader
{
    public static void printUsage()
    {
        System.out.print("usage: AutoUploader ");
        System.out.println(
                "-f fileName -r refseqId \n " +
                "Optional [\n" +
                "\t-u genboreeUserIds (comma delimited eg: 1,2,3)\n" +
                "\t-t typeOfFile ( lff, blat, blast or agilent) \n" +  //, or gff ) ] ");
                "\t-x { delete Entry Points} \n" +
                "\t-s { suppress email } \n" +
                "\t-o { delete Annotations } \n" +
                "\t-d { delete data tables and ftype tables } \n"+
                "\t-n { ignore entryPoints default update/insert entryPoints } \n" +
                "\t-b { set the debugging off } \n" +
                "\t-p sleep time between inserts \n" +
                "\t-i { send individual emails } \n" +
                "\t-w numberOfInserts (default Number of Inserts = " + LffConstants.defaultNumberOfInserts + ")\n" +
                "\t-z { turn compression off default on } \n" +
                "\t-v { turn validation off default on } \n" +
                "\t-k { turn task insertion off default on } \n" +
                "\t-y { taskId, if taskId is not present and taskid is provided error would be generated } \n" +
                "\t--segment Agilent to lff only \n" +
                "\t--histogram Agilent to lff only\n" +
                "\t--type passed to transformers \n" +
                "\t--class passed to transformers \n" +
                "\t--gainloss Agilent to lff only\n" +
                "\t--subtypepassed to transformers \n" +
                "\t --AnyAdditional argument to pass\n" +
                "]\n");
    }



    public static void main(String[] args)
    {
        String fileName = null;
        String usersId = null;
        String refseqId = null;
        String inputFormat = null;
        String[] genboreeIds = null;
        String bufferString = null;
        boolean debugging = true;
        boolean individualizedEmails = false;
        boolean ignoreEntryPoints = false;
        boolean deleteAnnotations = false;
        boolean deleteEntryPoints = false;
        boolean compression = true;
        boolean validate = true;
        boolean insertTask = true;
        long taskId = -1;
        boolean suppressEmail = false;
        boolean deleteAnnotationsAndFtypes = false;
        int bufferSize = 0;
        boolean setBufferSize = false;
        int sleepTime = LffConstants.uploaderSleepTime;
        boolean modifySleepTime = false;
        HashMap extraOptions = new HashMap();
        String groupPermissing = null;
        boolean permissionToUseDb = false;


        int exitError = 0;

        if(args.length < 4 )
        {
            printUsage();
            System.exit(-1);
        }

        if(args.length >= 1)
        {

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
                        usersId  = args[i];
                        if(usersId.indexOf(",") > -1)
                            genboreeIds = usersId.split(",");
                        else
                        {
                            genboreeIds = new String[1];
                            genboreeIds[0] = usersId;
                        }
                    }
                }
                else if(args[i].compareToIgnoreCase("-b") == 0)
                {
                    debugging = false;
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
                else if(args[i].compareToIgnoreCase("-z") == 0)
                {
                    compression = false;
                }
                else if(args[i].compareToIgnoreCase("-v") == 0)
                {
                    validate = false;
                }
                else if(args[i].compareToIgnoreCase("-k") == 0)
                {
                    insertTask = false;
                }
                else if(args[i].compareToIgnoreCase("-x") == 0)
                {
                    deleteEntryPoints = true;
                    deleteAnnotationsAndFtypes = true;
                }
                else if(args[i].compareToIgnoreCase("-i") == 0)
                {
                    individualizedEmails = true;
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
                        if(bufferSize > 0) setBufferSize = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-y") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        taskId = Util.parseLong(bufferString , -1);
                        if(taskId > 0)
                           insertTask = false;
                    }
                }
                else if(args[i].compareToIgnoreCase("-s") == 0)
                {
                    suppressEmail = true;
                }
                else if(args[i].compareToIgnoreCase("-p") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        sleepTime = Util.parseInt(bufferString , -1);
                        if(sleepTime > -1)
                            modifySleepTime = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-r") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        refseqId = args[i];
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
        else
        {
            printUsage();
            System.exit(-1);
        }
        
        permissionToUseDb = GenericDBOpsLockFile.getPermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);
        int i = 0;
        String tempUserid = "-1";
        while( i < genboreeIds.length  )
        {
          tempUserid = genboreeIds[i];
          // Check if the job has been submitted by the super user.
          if(tempUserid.equals(GenboreeConfig.getConfigParam("gbSuperuserId")))
          {
            groupPermissing = "true";
          }
          else
          {
            groupPermissing = GenboreeUtils.fetchGroupIdFromRefseqIdAndUserCanWrite(refseqId , tempUserid, false);// Checking if user has permission to write into database
          }
          i++;
          if(groupPermissing != null)
              break;
        }
        if(groupPermissing == null)
        {

            System.err.print("AutoUploader ERROR: the user id");
            if(genboreeIds.length > 1)
              System.err.print("s ");
            else
              System.err.print(" ");
            for(int a = 0; a < genboreeIds.length; a++)
            {
              System.err.print(" " + genboreeIds[a]);
            }
            System.err.println(" do not have permission to upload to refSeqid  " + refseqId );
            GenericDBOpsLockFile.releasePermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);
            System.exit(45);
        }



        if(usersId == null || genboreeIds == null)
                suppressEmail = true;

        permissionToUseDb = GenericDBOpsLockFile.releasePermissionForDbOperation(GenericDBOpsLockFile.MAIN_GENB_DB);

        org.genboree.upload.Uploader uploader = new Uploader( refseqId, fileName, genboreeIds , inputFormat, suppressEmail);
        if(uploader.isMissingInfo())
        {
            printUsage();
            System.exit(-1);
        }

        uploader.setDebug(debugging);
        if(extraOptions.size() > 0)
            uploader.setExtraOptions(extraOptions) ;

        uploader.setCommandLine(true);
        uploader.setIgnoreEntryPoints(ignoreEntryPoints);
        uploader.setDeleteAnnotations(deleteAnnotations);
        uploader.setDeleteAnnotationsAndFtypes(deleteAnnotationsAndFtypes);
        uploader.setDeleteEntryPoints(deleteEntryPoints);
        uploader.setCompressContent(compression);
        uploader.setSleepTime(sleepTime);
        uploader.setValidateFile(validate);
        uploader.setInsertTask(insertTask);
        uploader.setTaskId(taskId);
        if(setBufferSize)
            uploader.setMaxNumberOfInserts(bufferSize);


//        System.err.println("Want to know there the stderr is going ");
//
//            for(int i = 0; i < args.length; i++ )
//            {
//                System.err.println(args[i] + " ");
//
//            }
//        System.err.flush();

        uploader.setIndividualEmails(individualizedEmails);
        Thread thr2 = new Thread(uploader);
        thr2.start();

        try
        {
            thr2.join() ;
        }
        catch (InterruptedException e)
        {
            e.printStackTrace(System.err);
        }
        exitError = uploader.getErrorLevel();
        //  System.err.println(uploader.getStderr());
        if( exitError == 0 )
        {
            System.out.println("File was Uploaded successfully!");
            System.out.flush();
        }
        System.exit(exitError);

    }

}


