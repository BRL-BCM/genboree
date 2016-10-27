package org.genboree.util;

import org.genboree.upload.LffConstants;
import org.genboree.upload.HttpPostInputStream;
import org.genboree.util.* ;

import java.io.*;
import java.util.zip.*;
import java.util.*;
import java.util.Date;
import java.sql.*;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.net.InetAddress;
import java.text.SimpleDateFormat;




public class DirectoryUtils
{
    public static final String uploadDirName = Constants.UPLOADDIRNAME;
    public static final String propertiesFile = Constants.DBACCESS_PROPERTIES;

    public static String getValueFromPropertyFile(String property)
    {
        String value = null;
        try {
            ReadConfigFile myConfig = new ReadConfigFile(propertiesFile);
            if (myConfig.getGoodFile()) {
                value = myConfig.getProps().getProperty(property);

            }
        } catch (IOException e) {
            System.err.println("DirectoryUtils#getValueFromPropertyFile: Unable to read properties file " + propertiesFile);
            e.printStackTrace(System.err);
            System.err.flush();
        }

        return  value;
    }

    public static String findIfFileExist(String path, String fileName, String strToReturn)
    {
        String resultingFile = "";
        String fullPathOfFile ;
        String cleanFileName = fileName.replaceFirst("^.*/+", "");
        String cleanPath = path.replaceFirst("/+$", "");

        File filePtr = null;
        File parentDir = null;



         if(fileName == null || cleanFileName == null || cleanFileName.length() < 3)
         {
             System.err.println("fileName (" + fileName + ") is incorrect or cleaning step fail = " + cleanFileName);
             System.err.flush();
             return resultingFile;
         }




        if(path == null || cleanPath == null || cleanPath.length() < 1)
         {
             System.err.println("path to file (" + path + ") is incorrect or cleaning the Path fail = " + cleanPath);
             System.err.flush();
             return resultingFile;
         }



        fullPathOfFile =   cleanPath + "/" +  cleanFileName;

         filePtr = new File(fullPathOfFile);

         if(!filePtr.exists())
         {
             System.err.println("fileName (" + fullPathOfFile + ") does not exist");
             System.err.flush();
             return resultingFile;

         }


         if(filePtr.isDirectory())
         {
             System.err.println("fileName (" + fullPathOfFile + ") is a directory");
             System.err.flush();
             return "";

         }

         if(!filePtr.canRead())
         {
             System.err.println("Unable to read file (" + fullPathOfFile + ") wrong permissions");
             System.err.flush();
             return resultingFile;
         }

        return   strToReturn + "/";
    }


    public static void printErrorMessagesToAFile(String fullPathFile,
                                                 boolean toPrint, StringBuffer bufferToPrint)
    {
        PrintStream pout = null;

        if(toPrint)
        {
            try {
                pout = new PrintStream( new FileOutputStream(fullPathFile) );
            } catch (FileNotFoundException e) {
                e.printStackTrace(System.err);
            }
            pout.println(bufferToPrint.toString());
            pout.flush();
            pout.close();
        }
    }
    public static String join(Collection s, String delimiter)
    {
        StringBuffer buffer = new StringBuffer();
        Iterator iter = s.iterator();
        while (iter.hasNext())
        {
            buffer.append(iter.next());
            if (iter.hasNext())
            {
                buffer.append(delimiter);
            }
        }
        return buffer.toString();
    }


    public static long writeToFile(String nameOffileToSaveData, HttpPostInputStream hpIn, int type, String originalName)
    {
        boolean debugging = true;
        long returnValue = 0;

        returnValue = writeToFile(nameOffileToSaveData, hpIn, type, originalName, debugging);

       return returnValue;
    }
    public static long writeToFile(String nameOffileToSaveData, HttpPostInputStream hpIn, int type, String originalName, boolean debugging)
    {
        FileOutputStream fos = null ;
        long currByteCount = 0 ;
        byte[] buf1 = new byte[8192];
        int len = 0;
        String nameOfExtractedFile = null;
        File tempFile = null;
        HashMap outPutFromProgram = null;
        File fileToSaveData = new File(nameOffileToSaveData);
        File parentDir = new File(fileToSaveData.getParent());
        File originalFile = null;

        try {
            fos = new FileOutputStream(fileToSaveData);
        } catch (FileNotFoundException e)
        {
            System.err.println("Unable to create FileOutputStream for file " + fileToSaveData.getAbsolutePath());
            e.printStackTrace(System.err);
            System.err.flush();
            return 0;
        } catch (IOException e) {
            System.err.println("Unable to create FileOutputStream for file " + fileToSaveData.getAbsolutePath());
            e.printStackTrace(System.err);
            System.err.flush();
            return 0;
        }
        if(debugging)
        {
            System.err.println("The fileToSaveData is " + fileToSaveData.getAbsolutePath() + " the type is " + type);
            System.err.flush();
        }
        try
        {
            /**
             * Write the file to disk (in the genboreeUpload dirs)
             */
            while ((len = hpIn.read(buf1)) != -1)
            {
                fos.write(buf1, 0, len);
                currByteCount += len;
                if ((currByteCount > 0) && ((currByteCount % (1024 * 1024)) == 0))
                {
                    Util.sleep(LffConstants.webUploaderSleepTime);
                }
            }
            fos.close();
            if(debugging)
            {
                System.err.println("before changing name the fileToSaveData = " + fileToSaveData.getAbsolutePath());
                System.err.flush();
            }
            if(originalName != null)
            {
               originalFile = new File(parentDir, originalName);
                  fileToSaveData.renameTo(originalFile);
                  fileToSaveData = originalFile;
            }
            else
            {
                System.err.println("DirectoryUtils writeToFile : original name is null why?");
                System.err.flush();
            }
            if(debugging)
            {
                System.err.println("The originalFile is " + originalFile);
                System.err.println("after changing name the fileToSaveData = " + fileToSaveData.getAbsolutePath());
            }

            /**
             * Uncompress if the file needs it
             */
            outPutFromProgram =  CommandsUtils.extractUnknownCompressedFile(fileToSaveData.getAbsolutePath());
            nameOfExtractedFile = (String)outPutFromProgram.get("uncompressedFile");
            if(debugging)
            {
                System.err.println("The name of extractedFile is " + nameOfExtractedFile);
                System.err.flush();
            }

            /**
             * If the file was uncompressed, overwrite the zip file with the uncompressed file
             */
            if(nameOfExtractedFile != null) //handle zip archives
            {
                if(!nameOfExtractedFile.equalsIgnoreCase(fileToSaveData.getAbsolutePath()))
                {
                    tempFile = new File(nameOfExtractedFile);
                    tempFile.renameTo(fileToSaveData);
                }
            }
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
            System.err.flush();
        } catch (InterruptedException e)
        {
            e.printStackTrace(System.err);
            System.err.flush();
        } catch (Exception e)
        {
            e.printStackTrace(System.err);
            System.err.flush();
        }
        finally
        {
            if(nameOfExtractedFile != null)
                return currByteCount;
            else
                return currByteCount * -1;
        }
    }


    public static int returnTypeOfCompression(String contentTypeAttribute)
    {
        int typeOfCompression = -1;

                if( contentTypeAttribute.startsWith("application/x-zip") )
                    typeOfCompression = 0;
                else if( contentTypeAttribute.startsWith("application/zip") )
                    typeOfCompression = 0;
                else if( contentTypeAttribute.startsWith("application/x-gzip") )
                    typeOfCompression = 1;
                else if( contentTypeAttribute.startsWith("application/x-bzip2") )
                    typeOfCompression = 2;
                else if( contentTypeAttribute.startsWith("text/plain"))
                    typeOfCompression = 3;
                else if( contentTypeAttribute.startsWith("application/octet-stream"))
                    typeOfCompression = 4;
                else
                    typeOfCompression = 5;

        return typeOfCompression;
    }

// Copies src file to dst file.
    // If the dst file does not exist, it is created
    public static void copy(File src, File dst) throws IOException
    {
        InputStream in = new FileInputStream(src);
        OutputStream out = new FileOutputStream(dst);

        // Transfer bytes from in to out
        byte[] buf = new byte[1024];
        int len;
        while ((len = in.read(buf)) > 0) {
            out.write(buf, 0, len);
        }
        in.close();
        out.close();
    }

   public static String returnParticularAttFromMultiPartPostStream(String attributeName, HttpPostInputStream hpIn)
    {
        String temporaryString = null;
        String nameAttribute = null;

        /* Read in multi-part mime data in post */

        try {
            while (hpIn.nextPart()) {
                nameAttribute = hpIn.getPartAttrib("name");

                if (nameAttribute.equalsIgnoreCase(attributeName)) {
                    BufferedReader br = new BufferedReader(new InputStreamReader(hpIn));
                    temporaryString = br.readLine();
                    if (temporaryString != null)
                    {
                        temporaryString = temporaryString.trim();
                        if (!Util.isEmpty(temporaryString))
                        {
                            return temporaryString;
                        }
                    }
                }
            }
        } catch (IOException e)
	{
            e.printStackTrace(System.err);
            System.err.flush();
        }
        return null;
    }

    public static Hashtable saveFileReturnParams(String fileName, HttpPostInputStream hpIn,
                                                 String nameFieldWithFile, String nameFieldPastedData)
    {
        /* Get file to save data to */
        File fileToSaveData = null;
        File temporaryFile = null;
        String temporaryString = null;
        Hashtable parms = null;
        String pasteData = null;
        int part = 0;
        boolean debug = true;
        String fieldWithFile = null;
        int typeOfCompression = -1;
        boolean foundFileWithData = false;
        boolean pasteDataFieldHasData = false;
        boolean hasData = false;
        long currByteCount = 0 ;
        long fileByteCount = 0 ;
        long pasteDataFieldByteCount = 0;
        String nameAttribute = null;
        String fileNameAttribute = null;
        String contentTypeAttribute = null;
        String nameOriginalFile = null;
        String fileContentType = null;

        parms = new Hashtable();
        fileToSaveData = new File( fileName );


        if(nameFieldPastedData == null || nameFieldPastedData.length() < 2)
            pasteData = "paste_data";
        else
            pasteData = nameFieldPastedData;

        if(nameFieldWithFile == null || nameFieldWithFile.length() < 2)
            fieldWithFile = "upload_file";
        else
            fieldWithFile = nameFieldWithFile;


        /* Read in multi-part mime data in post */
        try
        {
            while( hpIn.nextPart() )
            {
                currByteCount = 0 ;
                nameAttribute = hpIn.getPartAttrib( "name" );
                fileNameAttribute = hpIn.getPartAttrib( "filename" );
                contentTypeAttribute = hpIn.getPartAttrib( "Content-Type" );


                /**
                 * process the file
                 */
                if(nameAttribute.equalsIgnoreCase(fieldWithFile) && fileNameAttribute != null)
                {
                    nameOriginalFile = fileNameAttribute.replaceAll("[ ]*", "");
                    int lastLocation = nameOriginalFile.lastIndexOf("\\");
                    if(lastLocation > -1)
                    nameOriginalFile = nameOriginalFile.substring(lastLocation + 1);
                    System.err.println("Name OF ORIGINAL FILE = " + nameOriginalFile);
                    System.err.flush();

                    /**
                     * identify the compression, returns an int value.
                     */
                    typeOfCompression = returnTypeOfCompression(contentTypeAttribute);

                    /**
                     * This looks big, identify everything that happens in writeToFile
                     */
                    currByteCount = writeToFile(fileToSaveData.getAbsolutePath(), hpIn, typeOfCompression, nameOriginalFile);


                    if(currByteCount > 2)
                    {
                        File parentDir = new File(fileToSaveData.getParent());
                        File originalFile = new File(parentDir, nameOriginalFile);
                        fileToSaveData = originalFile;
                        foundFileWithData = true;
                        fileByteCount =  currByteCount;
                        fileContentType = contentTypeAttribute;

                    }
                }
                else if(nameAttribute.equals(pasteData) && fileNameAttribute == null)// special case field where data is pasted form data
                {
                    /**
                     * Writes pasted data to a file
                     * uses different file name temporaryFile
                     * passes null as originalName
                     */
                    typeOfCompression = returnTypeOfCompression(contentTypeAttribute);
                    currByteCount = writeToFile(temporaryFile.getAbsolutePath(), hpIn, typeOfCompression, null);
//                    System.err.println("The currByteCount for the pastData is " + currByteCount);
//                    System.err.flush();
                    if(currByteCount > 10)
                    {
                        pasteDataFieldHasData = true;
                        pasteDataFieldByteCount = currByteCount;
                    }

                }
                else //Reads all the other form fields except the paste_data and the upload_field
                {
                    /**
                     * Add other fields to parms
                     */
                    BufferedReader br = new BufferedReader( new InputStreamReader(hpIn) ) ;
                    temporaryString = br.readLine() ;
                    if(temporaryString != null)
                    {
                        temporaryString = temporaryString.trim();
                        if( !Util.isEmpty(temporaryString) )
                        {
                            parms.put( nameAttribute, temporaryString );
                        }
                    }
                }


                part++;
                if(debug)
                {
                    System.err.println("the name is " + nameAttribute + " the filename = " + fileNameAttribute + "the content-type = " + contentTypeAttribute);
                    System.err.println("At the end of the while loop " +
                            " byteCount = " + currByteCount + " parts = " + part + " Content-Type = " + contentTypeAttribute + " fileName = " + fileNameAttribute);
                    System.err.flush();
                }
            }

            if(foundFileWithData)
            {
  //              temporaryFile.delete();
                hasData = foundFileWithData;
                currByteCount = fileByteCount;
            }
            else if(pasteDataFieldHasData && !foundFileWithData)
            {
                temporaryFile.renameTo(fileToSaveData);
                hasData = pasteDataFieldHasData;
                currByteCount = pasteDataFieldByteCount;
            }
            else
            {
//                fileToSaveData.delete();
//                temporaryFile.delete();
                currByteCount = -1;
            }

            /**
             * Add some information about the file to parms
             */
            parms.put("hasData", "" + hasData);
            parms.put("byteCount", "" + currByteCount);
            if(fileContentType != null)
                parms.put("ContentType", fileContentType);
            if(nameOriginalFile != null)
                parms.put("fileName", nameOriginalFile);
            parms.put("fileToSaveData", fileToSaveData);

//            System.err.println("ORIGINAL NAME AT THE END = " + nameOriginalFile);
//            System.err.println("Name OF ORIGINAL FILE AT THE END = " + fileToSaveData.getAbsolutePath());
//            System.err.flush();

        } catch (IOException e)
        {
            e.printStackTrace(System.err);
            System.err.flush();
        }
        return parms;
    }

    public static void splitFile(String path, String fileName, String prefix, String extension, int numberLines)
    {
        File mainFile = null;
        File directory = null;
        BufferedReader fin = null;
        String lineRead = null;
        int lineCounter = 0;
        PrintWriter fout = null;
        int fileNumber = 0;
        String outputFile = null;
        int maximumNumberFiles = 50;


        directory = new File(path);
        if(directory.exists() && directory.isDirectory() && directory.canWrite())
        {
            mainFile = new File( path, fileName );
            if(!mainFile.exists() || !mainFile.canRead())
            {
                System.err.println("The file" + path + "/" + fileName + " is not available or permissions are wrong!");
                System.err.flush();
                return;
            }
        }
        else
        {
            System.err.println("The directory " + path + " is not available or permissions are wrong!");
            System.err.flush();
            return;
        }


        try
        {
            fin = new BufferedReader( new FileReader(mainFile) );
            lineCounter = numberLines + 1;
            while( (lineRead = fin.readLine()) != null )
            {
                if(fileNumber > maximumNumberFiles)
                {
                    fout.println( lineRead );
                }
                else
                {
                    if(lineCounter < numberLines)
                    {
                        fout.println( lineRead );
                        lineCounter++;
                    }
                    else
                    {
                        if(fileNumber > 0)
                        {
                            fout.flush();
                            fout.close();
                        }
                        outputFile = prefix + "_"+ fileNumber + "." + extension;
                        fout = new PrintWriter( new FileWriter( new File(path, outputFile) ) );
                        fout.println( lineRead );
                        fileNumber++;
                        lineCounter = 1;
                    }
                }
            }
            fout.close();
            fin.close();

        } catch (FileNotFoundException e)
        {
            e.printStackTrace(System.err);
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
        }
    }
    public static String[] listAllFilesInDirectory( String dirName )
    {
        File directory = new File(dirName);
        File parent = new File(directory.getParent());
        return listAllFilesInDirectory(parent.getAbsolutePath(), directory.getName());
    }
    public static String[] listAllFilesInDirectory( String path, String dirName )
    {
        File directory = null;
        boolean directoryOK = false;
        ArrayList fileNames = null;
        String[] extraFiles = null;
        String fullPath = null;
        String[] temp = null;

        directory = new File(path, dirName);


        if(directory.exists() && directory.isDirectory())
        {
            directoryOK = true;
        }

        if(!directoryOK )
        {
            System.err.println("The directory " + path + "/" + dirName +  " is not available or permissions are wrong!");
            System.err.flush();
            return null;
        }


        File[] fList = directory.listFiles();
        if( fList == null )
        {
            return null;
        }
        fullPath = path + "/" + dirName;
        fileNames = new ArrayList();
        fileNames.add(fullPath);

        for( int i=0; i<fList.length; i++ )
        {
            File temporaryFilePtr = fList[i];
            try
            {
                if( temporaryFilePtr.isDirectory() )
                {
                    extraFiles = listAllFilesInDirectory( fullPath, temporaryFilePtr.getName() );
                    for(int n = 0; n < extraFiles.length; n++)
                        fileNames.add(extraFiles[n]);
                }
                else
                    fileNames.add( temporaryFilePtr.getAbsolutePath());
            } catch( Exception ex )
            {
                ex.printStackTrace(System.err);
                return null;
            }
        }
        temp = new String[fileNames.size()];
        fileNames.toArray(temp);
        return temp;
    }
    public static int fetchMaxDirectoryLevel(String fileName)
    {

        String fullPathName = null;
        int levels = 0;

        fullPathName = fileName;

        while(!fullPathName.equals("/"))
        {
            File currentFile = new File(fullPathName);
            File tempParent = new File(currentFile.getParent());
            fullPathName = tempParent.getAbsolutePath();
            levels++;
            if(levels > 100) break;
        }
        return levels;
    }

    public static boolean compressContentOfDirectory( String directoryNameWithFullPath)
    {
        File directory = null;
        boolean directoryOK = false;

        directory = new File(directoryNameWithFullPath);

        if(directory.exists() && directory.isDirectory() && directory.canWrite())
        {
            directoryOK = true;
        }

        if(!directoryOK )
        {
            System.err.println("The directory " + directoryNameWithFullPath + " is not available or permissions are wrong!");
            System.err.flush();
            return false;
        }


        FilenameFilter fileFilter = new FilenameFilter()
        {
            public boolean accept(File dir, String fname) {
                return !fname.endsWith(".gz") ;
            }
        };

        String[] fList = directory.list(fileFilter);
        if( fList == null )
        {
            return true;
        }

        for( int i=0; i<fList.length; i++ )
        {
            CommandsUtils.gZipFile(directoryNameWithFullPath + "/" +fList[i] );
        }
        return true;
    }
    public static void zipAllFiles(String archive, String[] files, int levels)
    {

        byte[] buf = new byte[1024];
        String usedName = null;
        String fullPathName = null;
        int maxPosibleLevels = 0;

        maxPosibleLevels = fetchMaxDirectoryLevel(files[0]);
        if(levels < 0) levels = 1;
        if(levels > maxPosibleLevels)
            levels = maxPosibleLevels + 1;

        if(archive == null)
        {
            System.err.println("Unable to zip the files archive name missing");
            System.err.flush();
            return;
        }

        if(files == null || files.length < 1)
        {
            System.err.println("Unable to zip there are no file names");
            System.err.flush();
            return;
        }

        File checkArchive = new File(archive);
        File archiveParent = new File(checkArchive.getParent());

        if(archiveParent.exists() && archiveParent.isDirectory() && !archiveParent.canWrite())
        {
            System.err.println("Unable to write archive in directory " + archiveParent.getAbsolutePath() + " not enough permissions");
            System.err.flush();
            return;
        }
        if(checkArchive == null)
        {
            System.err.println("Unable to zip problems with the archive name provided " + archive);
            System.err.flush();
            return;
        }

        if(checkArchive.exists() && checkArchive.isDirectory())
        {
            System.err.println("Unable to overwrite directory with same name as zip file " + archive);
            System.err.flush();
            return;
        }


        if(checkArchive.exists() && !checkArchive.canWrite())
        {
            System.err.println("Unable to overwrite existing file with archive not enough permissions");
            System.err.flush();
            return;
        }




        try {

            ZipOutputStream out = new ZipOutputStream(new FileOutputStream(archive));

            for (int i = 0; i < files.length; i++)
            {
                File tempFile = new File(files[i]);
                usedName = tempFile.getName();
                fullPathName = files[i];


                for(int y = 0; y < levels; y++)
                {
                    try{
                        File currentFile = new File(fullPathName);
                        File tempParent = new File(currentFile.getParent());
                        usedName = tempParent.getName() + "/" + usedName;
                        fullPathName = tempParent.getAbsolutePath();
                    }
                    catch(Exception e)
                    {
                        System.err.println("EXCEPTION: in zipAllFiles file " + fullPathName + " does not have a parent");
                        System.err.flush();
                    }
                }

                if(tempFile.isDirectory())
                    continue;
                FileInputStream in = new FileInputStream(files[i]);

                out.putNextEntry(new ZipEntry(usedName));

                int len;
                while((len = in.read(buf)) > 0)
                    out.write(buf, 0, len);

                out.closeEntry();
                in.close();
            }

            out.close();


        } catch (IOException e) {
            e.printStackTrace(System.err);
        }
    }
    public static boolean createNewDir(String path, String dirName)
    {
        File directory = null;
        File parentDir = null;

        parentDir = new File(path);
        directory = new File(path, dirName);

        if(directory.exists())
        {
            return true;
        }
        if(parentDir.exists() && parentDir.isDirectory() && parentDir.canWrite())
        {
            directory.mkdir();
            return true;
        }
        else
        {
            System.err.println("The directory " + path + " is not available or permissions are wrong!");
            System.err.flush();
            return false;
        }
    }
    public static void moveFileFromTo(String fileName, String currentDirectory, String targetDirectory)
    {
        File file = null;
        File currentDir = null;
        File targetDir = null;
        File newFile = null;
        boolean currentLocationOK = false;
        boolean targetLocationOK = false;
        boolean fileLocationOK = false;

        currentDir = new File(currentDirectory);
        targetDir = new File(targetDirectory);
        file = new File(currentDirectory, fileName);
        newFile = new File(targetDirectory, fileName);


        if(currentDir.exists() && currentDir.isDirectory() && currentDir.canWrite())
            currentLocationOK = true;

        if(targetDir.exists() && targetDir.isDirectory() && targetDir.canWrite())
            targetLocationOK = true;

        if(file.exists() && file.canWrite())
            fileLocationOK = true;


        if(currentLocationOK && targetLocationOK && fileLocationOK)
        {
            if(!file.renameTo(newFile))
            {
                System.err.println("Error detected file " + currentDirectory + "/" + fileName + "fail to move to " + targetDirectory);
                System.err.println("Permissions and files are OK but unable to move");
                System.err.flush();
                return;
            }
        }
        else
        {
            if(!currentLocationOK )
                System.err.println("The directory " + currentDirectory + " is not available or permissions are wrong!");

            if(!targetLocationOK)
                System.err.println("The directory " + targetDirectory + " is not available or permissions are wrong!");

            if(!fileLocationOK)
                System.err.println("The file " + currentDirectory + "/" + fileName + " is not available or permissions are wrong!");

            System.err.flush();
            return;
        }
    }
    public static boolean clearDirectory( String path, String dirName )
    {
        File directory = null;
        File parentDir = null;
        boolean directoryOK = false;
        boolean parentDirOK = false;


        parentDir = new File(path);
        directory = new File(path, dirName);


        if(directory.exists() && directory.isDirectory() && directory.canWrite())
        {
            directoryOK = true;
        }

        if(parentDir.exists() && parentDir.isDirectory() && parentDir.canWrite())
        {
            parentDirOK = true;
        }

        if(!directoryOK || !parentDirOK)
        {
            System.err.println("The directory " + path + " is not available or permissions are wrong!");
            System.err.flush();
            return false;
        }


        File[] fList = directory.listFiles();
        if( fList == null )
        {
            return true;
        }

        for( int i=0; i<fList.length; i++ )
        {
            File temporaryFilePtr = fList[i];
            try
            {
                if( temporaryFilePtr.isDirectory() ) clearDirectory( temporaryFilePtr.getParent(), temporaryFilePtr.getName() );
                temporaryFilePtr.delete();
            } catch( Exception ex )
            {
                ex.printStackTrace(System.err);
                return false;
            }
        }
        return true;
    }

    public static String stringToMd5(String key)
    {
      return Util.generateMD5(key) ;
    }

    public static String generateUniqueName()
    {
      return Util.generateUniqueString() ;
    }

    public static int getNumberLinesUsingWc(String myFile)
    {
        String command = myFile;
        String envp[] = new String[1];
        envp[0] = "";
        String fullCommand = "/usr/bin/wc -l " + command;
        String[] numb = null;
        HashMap outPut = null;
        String out = null;
        String err = null;
        Integer level = null;
        File localOriginalFile = null;
        File parentDir = null;
        int numberOfLines = -1;


        if(command == null || command.length() < 1) return -1;

        try
        {
            localOriginalFile = new File(command);
            parentDir = new File(localOriginalFile.getParent());
        }
        catch(NullPointerException ex)
        {
            System.err.println("Uploader#run(): Unable to localize the fileName, please use full path and verify permissions");
            System.err.flush();
            return -2;
        }


        fullCommand = "/usr/bin/wc -l " + command;
        numb = null;
        outPut = CommandsUtils.runCommandaCollectInfo(fullCommand, envp, parentDir.getAbsolutePath());

        out = (String)outPut.get("stdout");
        err = (String)outPut.get("stderr");
        level = (Integer)outPut.get("errorlevel");

        int intLevel = -1;
        try
        {
            intLevel = level.intValue();
        }
        catch(NullPointerException ex)
        {
            numberOfLines = -3;
        }


        if(out != null && out.length() > 0)
        {
            out = out.trim();
            numb =  out.split(" ");
            numberOfLines = Util.parseInt(numb[0], -5);
        }
        else
        {
            return -4;
        }

        return numberOfLines;
    }



    public static String returnFormatedGMTTime()
    {
        String gmtStartDate = null;

        Date startDate = new Date();
        SimpleDateFormat dfmt = new SimpleDateFormat( "EEE MMM d HH:mm:ss z yyyy" );
        dfmt.setTimeZone( TimeZone.getTimeZone("GMT") );
        gmtStartDate = dfmt.format( startDate );

        return gmtStartDate;
    }

    public static String createFinalDir(String path,  String refSeqId, String userId)
    {
        String tempDir = null;
        String name = null;
        String databaseName = null;
        String nextDir = null;
        boolean created = false;

        if (path == null )
        {
            System.err.println("Wrong parameters used in createFinalDir method fullpath");
            System.err.flush();
            return null;
        }
        if (refSeqId == null || userId == null)
        {
            System.err.println("Wrong parameters used in createFinalDir method refseqId or userid missing");
            System.err.flush();
            return null;
        }

        nextDir = path;
        File checkIfDirExist = new File(nextDir);
        if(!checkIfDirExist.exists() || !checkIfDirExist.isDirectory() || !checkIfDirExist.canWrite())
        {
            System.err.println("Wrong directory permissions or directory does not exist " + path);
            System.err.flush();
            return null;
        }


        databaseName = GenboreeUtils.fetchMainDatabaseName(refSeqId );
        if(databaseName == null)
        {
            System.err.println("Unable to find databaseName for refSeqId = " + refSeqId);
            System.err.flush();
            return null;
        }

        created = createNewDir(nextDir, databaseName);
        if(!created)
        {
            System.err.println("directory = " + nextDir + "/" + databaseName + " does not exist or wrong permissions");
            System.err.flush();
            return null;
        }

        nextDir = nextDir + "/" + databaseName;
        name = GenboreeUtils.fetchUserName(userId);
        if(name == null)
        {
            System.err.println("Unable to find userName for userId = " + userId);
            System.err.flush();
            return null;
        }
        created = createNewDir(nextDir, name);
        if(!created)
        {
            System.err.println("directory = " + nextDir + "/" + databaseName + " does not exist or wrong permissions");
            System.err.flush();
            return null;
        }

        nextDir = nextDir + "/" + name;
        tempDir = generateUniqueName();
        if(tempDir == null)
        {
            System.err.println("Unable to generate unique name");
            System.err.flush();
            return null;
        }
        created = createNewDir(nextDir, tempDir);
        if(!created)
        {
            System.err.println("directory = " + nextDir + "/" + tempDir + " does not exist or wrong permissions");
            System.err.flush();
            return null;
        }
        nextDir = nextDir + "/" + tempDir;

        System.err.println("the directory " + nextDir + " has been successfully created");
        System.err.flush();

        return nextDir;
    }

    public static boolean verifyIfFileWrittable(String myFile)
    {
        File filePtr = null;
        File parentDir = null;
        if(myFile == null)
        {
            System.err.println("fileName (" + myFile + ") is null");
            System.err.flush();
            return false;
        }


        filePtr = new File(myFile);
        parentDir = new File(filePtr.getParent());


        if(filePtr.exists() && filePtr.isDirectory())
        {
            System.err.println("fileName (" + myFile + ") is a directory");
            System.err.flush();
            return false;

        }
        if(filePtr.exists() && !filePtr.canWrite())
        {
            System.err.println("Unable to write to file (" + myFile + ") wrong permissions");
            System.err.flush();
            return false;
        }

        if(!parentDir.exists() || !parentDir.isDirectory())
        {
            System.err.println("Unable to write to file (" + myFile + ") wrong path parent directory does not exist");
            System.err.flush();
            return false;
        }


        if(parentDir.exists() && !parentDir.canWrite())
        {
            System.err.println("Unable to write to file (" + myFile + ") wrong permissions on parent directory");
            System.err.flush();
            return false;
        }

        return true;
    }


    public static boolean isDirectoryWrittable(String dirName)
    {
        File filePtr = null;

        if(dirName == null && dirName.length() < 1)
        {
            System.err.println("the name provided for the directory is null");
            System.err.flush();
            return false;
        }


        filePtr = new File(dirName);

        if(!filePtr.exists())
        {
            System.err.println("the directory (" + dirName + ") does not exist!!");
            System.err.flush();
            return false;
        }


        if(filePtr.exists() && !filePtr.isDirectory())
        {
            System.err.println("the directory (" + dirName + ") is not a directory");
            System.err.flush();
            return false;
        }

        if(filePtr.exists() && !filePtr.canWrite())
        {
            System.err.println("Unable to write to directory (" + dirName + ") wrong permissions");
            System.err.flush();
            return false;
        }


        return true;
    }





    public static boolean verifyIfFileReadable(String myFile)
    {
        File filePtr = null;
        File parentDir = null;
        if(myFile == null)
        {
            System.err.println("fileName (" + myFile + ") is null");
            System.err.flush();
            return false;
        }


        filePtr = new File(myFile);
        parentDir = new File(filePtr.getParent());


        if(filePtr.exists() && filePtr.isDirectory())
        {
            System.err.println("fileName (" + myFile + ") is a directory");
            System.err.flush();
            return false;

        }
        if(filePtr.exists() && !filePtr.canRead())
        {
            System.err.println("Unable to read file (" + myFile + ") wrong permissions");
            System.err.flush();
            return false;
        }

        if(!parentDir.exists() || !parentDir.isDirectory())
        {
            System.err.println("Unable to read file (" + myFile + ") wrong path parent directory does not exist");
            System.err.flush();
            return false;
        }


        if(parentDir.exists() && !parentDir.canRead())
        {
            System.err.println("Unable to read file (" + myFile + ") wrong permissions on parent directory");
            System.err.flush();
            return false;
        }

        return true;
    }



    public static HashMap transformFileWithValuePairsIntoHash(String fileName)
    {
        HashMap outPut = null;
        File mainFile = null;
        BufferedReader fin = null;
        String lineRead = null;


        if(!verifyIfFileReadable(fileName)) return null;

        outPut = new HashMap();

        mainFile = new File(fileName);

        try
        {
            fin = new BufferedReader( new FileReader(mainFile) );

            while( (lineRead = fin.readLine()) != null )
            {
                String[] keyValue = new String[2];
                String name = null;

                name = lineRead.trim();
                name = name.replaceAll("\\s+", "");
                name = name.toUpperCase();
                keyValue = name.split("=");

                outPut.put( keyValue[0], keyValue[1]);
            }

            fin.close();

        } catch (FileNotFoundException e)
        {
            e.printStackTrace(System.err);
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
        }

        return outPut;
    }


    public static HashMap loadFileWithNamesIntoHash(String fileName)
    {
        HashMap outPut = null;
        File mainFile = null;
        BufferedReader fin = null;
        String lineRead = null;
        String name = null;

        if(!verifyIfFileReadable(fileName)) return null;

        outPut = new HashMap();

        mainFile = new File(fileName);

        try
        {
            fin = new BufferedReader( new FileReader(mainFile) );

            while( (lineRead = fin.readLine()) != null )
            {
                name = lineRead.trim();
                name = name.replaceAll("\\s+", "");
                name = name.toUpperCase();
                outPut.put( name, name);
            }

            fin.close();

        } catch (FileNotFoundException e)
        {
            e.printStackTrace(System.err);
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
        }

        return outPut;
    }



    public static HashMap transformFileWithNamesIntoHash(String fileName)
    {
        HashMap outPut = null;
        File mainFile = null;
        BufferedReader fin = null;
        String lineRead = null;
        String name = null;

        if(!verifyIfFileReadable(fileName)) return null;

        outPut = new HashMap();

        mainFile = new File(fileName);

        try
        {
            fin = new BufferedReader( new FileReader(mainFile) );

            while( (lineRead = fin.readLine()) != null )
            {
                name = lineRead.trim();
                name = name.replaceAll("\\s+", "").replaceAll("\\.\\d+", "");
                name = name.toUpperCase();
                outPut.put( name, name);
            }

            fin.close();

        } catch (FileNotFoundException e)
        {
            e.printStackTrace(System.err);
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
        }

        return outPut;
    }

    public static void extractExactAnnotationFromLff(String fileWithNames, String lffFile, PrintWriter myPrinterOutStream)
    {
        File mainFile = null;
        BufferedReader fin = null;
        String lineRead = null;
        String line = null;
        HashMap namesToLook = null;
        String[] data = null;
        String lffName = null;
        String tempName = null;

        if(!verifyIfFileReadable(lffFile)) return;

        mainFile = new File(lffFile);

        namesToLook = loadFileWithNamesIntoHash(fileWithNames);

        if(namesToLook == null || namesToLook.size() < 1) return;


        try
        {
            fin = new BufferedReader( new FileReader(mainFile) );

            while( (lineRead = fin.readLine()) != null )
            {
                line = lineRead.trim() ;
                data = line.split("\t");
                if(data.length >= 10 && data.length <= 14)
                {
                    if(data[0].indexOf('#')>= 0 || data[0].indexOf('[')>= 0) continue;
                    lffName = data[1];
                    lffName =lffName.trim().replaceAll("\\s+", "");
                    lffName = lffName.toUpperCase();
                    if(namesToLook.containsKey(lffName))
                    {
                        myPrinterOutStream.println(lineRead);
                    }

                }

            }

            fin.close();

        } catch (FileNotFoundException e)
        {
            e.printStackTrace(System.err);
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
        }
        finally
        {
            return ;
        }
    }



    public static void extractFromLff(String fileWithNames, String lffFile, PrintWriter myPrinterOutStream)
    {
        File mainFile = null;
        BufferedReader fin = null;
        String lineRead = null;
        String line = null;
        HashMap namesToLook = null;
        String[] data = null;
        String lffName = null;
        String tempName = null;

        if(!verifyIfFileReadable(lffFile)) return;

        mainFile = new File(lffFile);

        namesToLook = transformFileWithNamesIntoHash(fileWithNames);

        if(namesToLook == null || namesToLook.size() < 1) return;


        try
        {
            fin = new BufferedReader( new FileReader(mainFile) );

            while( (lineRead = fin.readLine()) != null )
            {
                line = lineRead.trim() ;
                data = line.split("\t");
                if(data.length >= 10 && data.length <= 14)
                {
                    if(data[0].indexOf('#')>= 0 || data[0].indexOf('[')>= 0) continue;
                    lffName = data[1];
                    lffName =lffName.trim().replaceAll("\\s+", "").replaceAll("\\.\\d+", "");
                    lffName = lffName.toUpperCase();
                    if(namesToLook.containsKey(lffName))
                    {
                        myPrinterOutStream.println(lineRead);
                    }

                }

            }

            fin.close();

        } catch (FileNotFoundException e)
        {
            e.printStackTrace(System.err);
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
        }
        finally
        {
            return ;
        }




    }

    public static void extractFromLff(String fileWithNames, String lffFile, Writer writer)
    {
        PrintWriter myPrinterOutStream  = new PrintWriter(writer);
        extractFromLff(fileWithNames, lffFile, myPrinterOutStream);
    }


    /* next method to implement MLGG  Extracting a unique list of genes from a track (lff file) */
  // at results.lff |cut -d"       " -f2|sed -e ''s/\.[0-9][0-9]\*// " |sed -e "y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/"|sort -ud

    public static StringBuffer extractFromLff(String fileWithNames, String lffFile)
    {
        StringBuffer buffer = null;
        File mainFile = null;
        BufferedReader fin = null;
        String lineRead = null;
        String line = null;
        HashMap namesToLook = null;
        String[] data = null;
        String lffName = null;
        String tempName = null;

        if(!verifyIfFileReadable(lffFile)) return null;

        mainFile = new File(lffFile);

        namesToLook = transformFileWithNamesIntoHash(fileWithNames);

        if(namesToLook == null || namesToLook.size() < 1) return null;

        buffer = new StringBuffer();


        try
        {
            fin = new BufferedReader( new FileReader(mainFile) );

            while( (lineRead = fin.readLine()) != null )
            {
                line = lineRead.trim() ;
                data = line.split("\t");
                if(data.length >= 10 && data.length <= 14)
                {
                    if(data[0].indexOf('#')>= 0 || data[0].indexOf('[')>= 0) continue;
                    lffName = data[1];
                    lffName =lffName.trim().replaceAll("\\s+", "").replaceAll("\\.\\d+", "");
                    lffName = lffName.toUpperCase();
                    if(namesToLook.containsKey(lffName))
                    {
                        buffer.append(lineRead);
                    }

                }

            }

            fin.close();

        } catch (FileNotFoundException e)
        {
            e.printStackTrace(System.err);
        } catch (IOException e)
        {
            e.printStackTrace(System.err);
        }
        finally
        {
            return buffer;
        }


    }



    public static StringBuffer getSubsetGenes(String lffFile, String fileWithListAccessions, String outPutFile)
    {
        StringBuffer buffer = null;
        String tempName = null;
        PrintWriter fout = null;
        File outFile = null;


        if(!verifyIfFileReadable(fileWithListAccessions))
        {
            System.err.println("#getSubsetGenes unable to read fileWithAccession " + fileWithListAccessions + " wrong permission");
            return null;
        }


        HashMap elements = transformFileWithNamesIntoHash(fileWithListAccessions);

        if(elements == null || elements.size() < 1)
        {
            System.err.println("#getSubsetGenes fileWithAccession " + fileWithListAccessions + " is empty");
            return null;
        }



        if(!verifyIfFileReadable(lffFile))
        {
            System.err.println("#getSubsetGenes unable to read fileWithAccession " + fileWithListAccessions + " wrong permission");
            return null;
        }


        if(lffFile == null)
        {
            System.err.println("#getSubsetGenes the lff file " + lffFile + " is empty");
            return null;
        }


        if(outPutFile != null)
        {
            outFile = new File(outPutFile);

            if(!outFile.exists())
            {
                File parent = outFile.getParentFile();
                if(!parent.canWrite())
                {
                    System.err.println("#getSubsetGenes unable to create output file " + outPutFile + " wrong permission");
                    return null;
                }
            }
            else if(outFile.exists() && !verifyIfFileWrittable(lffFile))
            {
                System.err.println("#getSubsetGenes unable to create output file " + outPutFile + " wrong permission");
                return null;
            }

            try
            {
                fout = new PrintWriter( new FileWriter(outFile) );
            } catch (IOException e)
            {
                e.printStackTrace(System.err);
            }
            extractFromLff(fileWithListAccessions, lffFile, fout);
            fout.close();
        }
        else
            buffer = extractFromLff(fileWithListAccessions, lffFile);

        return buffer;
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



/*
int numberLines = getNumberLinesUsingWc(args[0]);
System.err.println("The number of lines in file " + args[0] + " = " + numberLines);
System.err.flush();
*/



        System.exit(0);
    }
}
