package org.genboree.util;

import org.genboree.dbaccess.DBAgent;
import org.genboree.downloader.AnnotationDownloader;
import org.genboree.dbaccess.DbFref;
import org.genboree.upload.LffConstants;
import org.genboree.upload.HttpPostInputStream;
import org.genboree.upload.GroupAssigner;

import java.io.*;
import java.util.zip.*;
import java.util.*;
import java.util.Date;
import java.sql.*;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.net.InetAddress;
import java.text.SimpleDateFormat;




public class ExtractExactAnnotationFromLff
{



    public static void printUsage()
    {
        System.out.print("usage: ExtractExactAnnotationFromLff ");
        System.out.println("\n" +
                "\t-f fileWithListAccessions\n" +
                "\t-l lffFile\n" +
                "\t-o outPutFileName\n");
        return;
    }
    public static void main(String[] args) throws Exception
    {
        String lffFile = null;
        String fileWithListAccessions = null;
        String tempName = null;
        String myFile = null;
        PrintWriter fout = null;
        StringBuffer buffer = null;
        File outFile = null;



        if(args.length < 2 )
        {
            printUsage();
            System.exit(-1);
        }


        if(args.length > 1)
        {

            for(int i = 0; i < args.length; i++ )
            {
                if(args[i].compareToIgnoreCase("-f") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        fileWithListAccessions = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-l") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        lffFile = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-o") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        myFile = args[i];
                    }
                }
                else {}
            }
        }
        else
        {
            printUsage();
            System.exit(-1);
        }

        /*
        buffer = DirectoryUtils.getSubsetGenes(lffFile, fileWithListAccessions, myFile);

        if(buffer != null && buffer.length() > 2) System.out.println(buffer.toString());
        */

        if(myFile != null)
        {
            outFile = new File(myFile);
            if(!outFile.exists())
            {
                boolean created = outFile.createNewFile();
            }
            fout = new PrintWriter( new FileWriter(outFile) );
        }
        else
            fout = new PrintWriter(System.out);


        HashMap elements = DirectoryUtils.loadFileWithNamesIntoHash(fileWithListAccessions);

        if(elements == null || elements.size() < 1)
        {
            System.err.println("The hashMap is empty");
            fout.close();
            System.exit(0);
        }

        if(lffFile != null)
        {
            DirectoryUtils.extractExactAnnotationFromLff(fileWithListAccessions, lffFile, fout);
        }

        fout.close();

        System.exit(0);
    }
}
