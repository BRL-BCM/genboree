package org.genboree.upload;

import org.genboree.util.*;
import org.genboree.upload.LffConstants;
import org.genboree.dbaccess.GenboreeUpload;
import org.genboree.dbaccess.DBAgent;
import org.genboree.downloader.AnnotationDownloader;

import java.io.PrintWriter;
import java.io.FileWriter;
import java.io.IOException;

public class UpdateDatabase
{
    public static void printUsage()
    {
        System.out.print("usage: UpdateDatabase ");
        System.out.println(
                "-d databaseName \n " +
                "\t-u genboreeUserId \n" +
                "Optional [\n" +
                "\t-o transform to old format\n" +
                "]\n");
        return;
    }



    public static void main(String[] args)
    {
        String databaseName = null;
        String fileName = null;
        String refseqId = null;
        String inputFormat = null;
        String[] tracks = null;
        String[] genboreeIds = new String[1];
        boolean debugging = true;
        boolean individualizedEmails = false;
        boolean ignoreEntryPoints = false;
        boolean deleteAnnotations = false;
        boolean deleteEntryPoints = false;
        boolean compression = true;
        boolean validate = true;
        boolean suppressEmail = false;
        boolean deleteAnnotationsAndFtypes = false;
        int bufferSize = 0;
        boolean setBufferSize = false;
        int sleepTime = LffConstants.uploaderSleepTime;
        boolean modifySleepTime = false;
        boolean oldFormat = false;
        DBAgent myDb = null;
        AnnotationDownloader currentDownload = null;
        boolean isDatabaseInNewFormat = false;
        boolean toNewFormat = true;
        String temporaryDir = "/tmp/databaseUpdates";
        String userId = null;
        int genboreeUserId = -1;




        genboreeIds[0] = "7";

        int exitError = 0;

        if(args.length < 2 )
        {
            printUsage();
            System.exit(-1);
        }

        if(args.length >= 1)
        {

            for(int i = 0; i < args.length; i++ )
            {
                if(args[i].compareToIgnoreCase("-d") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        databaseName = args[i];
                    }
                }
                 else if( args[ i ].compareToIgnoreCase( "-u" ) == 0 )
                {
                  i++;
                  if( args[ i ] != null )
                  {
                    userId = args[ i ];
                    genboreeUserId = Util.parseInt(userId, -1);
                  }
                }
                else if(args[i].compareToIgnoreCase("-o") == 0)
                {
                    oldFormat = true;
                }
            }
        }
        else
        {
            printUsage();
            System.exit(-1);
        }


        myDb = DBAgent.getInstance();
        isDatabaseInNewFormat = GenboreeUtils.isDatabaseUsingNewFormat(databaseName);
        if(isDatabaseInNewFormat && oldFormat)
        {
            toNewFormat = false;
        }
        else if(!isDatabaseInNewFormat && !oldFormat)
        {
            toNewFormat = true;
        }
        else
        {

            System.err.print("Appears that database " + databaseName + " is ");
            if(isDatabaseInNewFormat)
                System.err.print("in the new format already ");
            else
                System.err.print(" in the old format ");
            if(oldFormat)
                System.err.print("and you want to transform it to the old format");
            else
                System.err.print(" and you want to transform it to the new format");

            System.err.println();
            System.err.flush();
            System.exit(5);
        }
        tracks = GenboreeUpload.fetchTracksFromDatabase(myDb, databaseName, genboreeUserId);
        java.util.Date currentDate = new java.util.Date();
        DirectoryUtils.createNewDir(temporaryDir, databaseName);
        fileName =  temporaryDir + "/" + databaseName + "/" + GenboreeUtils.generateUniqueKey(currentDate.toString()) + "_big.lff";
        currentDownload = new AnnotationDownloader( myDb,  databaseName, genboreeUserId, tracks);
        currentDownload.downloadAnnotations(fileName);

        GenboreeUtils.updateVPDatabase(databaseName, toNewFormat);
        refseqId = GenboreeUtils.fetchRefSeqIdFromDatabaseName(databaseName);

        if(refseqId == null || refseqId.length() < 1)
        {
            GenboreeUtils.updateVPDatabase(databaseName, !toNewFormat);
            System.err.println("Appears that database " + databaseName + " is not a current genboree database refseqId = " + refseqId);
            System.err.flush();
            System.exit(5);
        }



        org.genboree.upload.Uploader uploader = new Uploader( refseqId, fileName, genboreeIds, inputFormat, suppressEmail);


        if(uploader.isMissingInfo())
        {
            GenboreeUtils.updateVPDatabase(databaseName, !toNewFormat);
            printUsage();
            System.exit(-1);
        }

        uploader.setDebug(debugging);
        uploader.setIgnoreEntryPoints(ignoreEntryPoints);
        uploader.setDeleteAnnotations(deleteAnnotations);
        uploader.setDeleteAnnotationsAndFtypes(deleteAnnotationsAndFtypes);
        uploader.setDeleteEntryPoints(deleteEntryPoints);
        uploader.setCompressContent(compression);
        uploader.setSleepTime(sleepTime);
        uploader.setValidateFile(validate);
        if(setBufferSize)
            uploader.setMaxNumberOfInserts(bufferSize);

        uploader.setIndividualEmails(individualizedEmails);
        uploader.setCleanOldTables(true);


        Thread thr2 = new Thread(uploader);
        thr2.start();

        try
        {
            thr2.join() ;
        }
        catch (InterruptedException e)
        {
            GenboreeUtils.updateVPDatabase(databaseName, !toNewFormat);
            e.printStackTrace(System.err);
        }
        exitError = uploader.getErrorLevel();

        if( exitError == 0 )
        {
            System.out.println("File was Updated successfully!");
            System.out.flush();
        }
        else if( exitError == 10)
        {
            System.out.println("File was Updated but with some errors!");
            System.out.flush();
        }
        else
        {
            GenboreeUtils.updateVPDatabase(databaseName, !toNewFormat);
            System.out.println("ERROR problems with database = " + databaseName + " was unable to upload too many errors error level = " + exitError);
            System.out.flush();
        }
        System.exit(exitError);


    }
}


