 /*Copyright 2002 Richardson Publications*/
package org.genboree.util;

import java.io.*;
import java.util.ArrayList;

public class ReadFile
{
    private String fileName = null;
    private int bufferSize = 1000000;
    private long length = 0;
    private byte[] contentFileInBytes;

    public ReadFile ()
    {}
    
    public ReadFile (String fileName, int bufferSize)
    {
        this.setFileName (fileName);
        this.setBufferSize (bufferSize);    
    }
    
    public ReadFile (String fileName)
    {
        this(fileName, 10000000);
    }
    
    public void setFileName (String fileName)
    {
        this.fileName = fileName;    
    }
    
    public String getFileName()
    {
        return this.fileName;    
    }
    
    public void setBufferSize (int bufferSize)
    {
        this.bufferSize = bufferSize;
    }
    
    public int getBufferSize ()
    {
        return this.bufferSize;    
    }
    
    public ArrayList read () throws java.io.FileNotFoundException, java.io.IOException
    {
        FileReader fr = new FileReader (this.getFileName());
        BufferedReader br = new BufferedReader (fr);
        ArrayList aList = new ArrayList (this.getBufferSize());
        
        String line = null;
        while (     (line = br.readLine()) != null)
        {
            aList.add(line);
        }
        
        br.close();
        fr.close();
        
        return aList;
    }

    public String readEntireFile()
    {

        FileReader fr = null;
        StringBuffer b = null;
        File currentFile = null;
        long lengthOfCurrentFile = 0;

        try
        {
            currentFile = new File(getFileName());
            lengthOfCurrentFile = currentFile.length();

            if(lengthOfCurrentFile < 1) return null;

            fr = new FileReader(getFileName());
            BufferedReader br = new BufferedReader (fr, (int)lengthOfCurrentFile);
            b = new StringBuffer();
            String line;
            while ((line = br.readLine()) != null)
            {
                b.append(line + "\n");
            }

            br.close();
            fr.close();
        }
        catch (FileNotFoundException e)
        {
            System.err.println("Exception caught in ReadFile#readEntireFile not file found " + getFileName());
            e.printStackTrace(System.err);
        }
        catch (IOException e)
        {
            System.err.println("Exception caught in ReadFile#readEntireFile IOException " + getFileName());
            e.printStackTrace(System.err);
        }


        return b.toString();
    }

  // Returns the contents of the file in a byte array.
    public void setBytesFromEntireFile() throws IOException {
        File tempFile = new File(this.getFileName());
        InputStream is = new FileInputStream(tempFile);

        // Get the size of the file
        long length = tempFile.length();

        // You cannot create an array using a long type.
        // It needs to be an int type.
        // Before converting to an int type, check
        // to ensure that file is not larger than Integer.MAX_VALUE.
        if (length > Integer.MAX_VALUE) {
            // File is too large
        }

        // Create the byte array to hold the data
        contentFileInBytes = new byte[(int)length];

        // Read in the bytes
        int offset = 0;
        int numRead = 0;
        while (offset < contentFileInBytes.length
               && (numRead=is.read(contentFileInBytes, offset, contentFileInBytes.length-offset)) >= 0) {
            offset += numRead;
        }

        // Ensure all the bytes have been read in
        if (offset < contentFileInBytes.length) {
            throw new IOException("Could not completely read file "+tempFile.getName());
        }

        // Close the input stream and return bytes
        is.close();

    }


    public static void main (String args[])    //include main for testing purposes
    {
        int i;
        if( args.length < 1 )
        {
            System.out.println( "Please specify a file name to read with path" );
            System.exit(0);
        }

        try
        {
            ReadFile rf = new ReadFile(args[0]);
            ArrayList a = rf.read();
            for (i = 0; i < a.size(); i++) {
                System.out.println((String)(a.get(i)));
            }
        }
        catch (Exception e)
        {
            System.out.println (e.getMessage());    
        }
    }
}
