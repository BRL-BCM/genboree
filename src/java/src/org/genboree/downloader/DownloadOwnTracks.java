package org.genboree.downloader;

import org.genboree.dbaccess.GenboreeUpload;
import org.genboree.dbaccess.DBAgent;
import org.genboree.util.Util;

public class DownloadOwnTracks
{
    public static void printUsage()
    {
        System.out.print("usage: DownloadOwnTracks ");
        System.out.println(
                "-d databaseName \n" +
                "-u genboreeUserId \n"
        );
        return;
    }



    public static void main(String[] args)
    {
        String databaseName = null;
        String fileName = null;
        String[] tracks = null;
        String[] genboreeIds = new String[1];
        DBAgent myDb = null;
        AnnotationDownloader currentDownload = null;
        String temporaryDir = "/tmp/databaseUpdates";
        String userId = null;
        int genboreeUserId = -1;

        genboreeIds[0] = "7";


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
           }
        }
        else
        {
            printUsage();
            System.exit(-1);
        }


        myDb = DBAgent.getInstance();

        tracks = GenboreeUpload.fetchTracksFromDatabase(myDb, databaseName, genboreeUserId );
        fileName =  temporaryDir + "/" + databaseName + ".lff";
        currentDownload = new AnnotationDownloader( myDb,   databaseName, genboreeUserId, tracks);
        currentDownload.downloadAnnotations(fileName);



    }
}


