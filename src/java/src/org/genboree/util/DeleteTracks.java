package org.genboree.util;

import org.genboree.dbaccess.GenboreeUpload;
import org.genboree.dbaccess.DBAgent;
import org.genboree.downloader.AnnotationDownloader;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.SQLException;
import java.util.Hashtable;
import java.util.Enumeration;
import java.util.ArrayList;

public class DeleteTracks
{
    public static void printUsage()
    {
        System.out.print("usage: DeleteTracks ");
        System.out.println(
                "-d databaseName \n" +
                "Optional [\n" +
                "\t-s { slow method check the fdata2 for the trackId}\n" +
                "\t-r { recreate tracks previously removed }\n" +
                "]\n");
        return;
    }

    public static void main(String[] args)
    {
        String databaseName = null;
        ArrayList tracksIds = null;
        DBAgent myDb = null;
        Connection conn = null;
        int minTrack = 0;
        String tempIdStr = null;
        int trackId = 0;
        int inverse = 0;
        boolean slow = false;
        boolean recreate = false;
        java.util.Date now = null;




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
                    if(args[i] != null){
                        databaseName = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-s") == 0)
                {
                    slow = true;
                }
                else if(args[i].compareToIgnoreCase("-r") == 0){
                    recreate = true;
                }
            }
        }
        else
        {
            printUsage();
            System.exit(-1);
        }

        myDb =  DBAgent.getInstance();

        try {
            conn = myDb.getConnection( databaseName );
        } catch (SQLException e) {
            System.err.println("Unable to generate connection for databaseName = " + databaseName);
            System.err.flush();
        }

        minTrack = GenboreeUpload.fetchMinTrackIdsFromFdatabase(conn);
        if(minTrack >= 0)
            minTrack = -1;
        else
            minTrack = minTrack -1;



        if(!slow)
                tracksIds = GenboreeUpload.fetchTrackIdsFromFtype(conn);
        else
            tracksIds = GenboreeUpload.fetchTrackIdsFromDatabase(conn);
        if(tracksIds == null)
        {
             System.err.println("No tracks present in database = " + databaseName);
             System.err.flush();
        }

        for(int i = 0 ; i < tracksIds.size(); i++)
        {
            tempIdStr = (String)tracksIds.get(i);
            trackId = Util.parseInt(tempIdStr, 0);
            if(trackId > 0 && !recreate)
                inverse = trackId - Math.abs(trackId * 2);
            else if(trackId < 0 && recreate)
                inverse = trackId + Math.abs(trackId * 2);
            else
                System.err.println("The trackId is 0 or error with flags trackId = " + trackId + " recreate = " + recreate + " method = " + slow);

            if(trackId != 0)
            {
                now = new java.util.Date() ;
                System.err.println("Before updating track = " + trackId + " to track = " + inverse + " " + now.toString());
                System.err.flush();
                GenboreeUpload.updateFtypeidInDatabase(conn, trackId, inverse);
                now = new java.util.Date() ;
                System.err.println("After updating track = " + trackId + " to track = " + inverse+ " " + now.toString());
                System.err.flush();
            }

            System.err.println(" The value for trackId is " + trackId + " and the inverse is " + inverse);
            System.err.println("The trackId is  " + trackId + " recreate = " + recreate + " method = " + slow);
            System.err.flush();


        }
    }
}


