package org.genboree.util ;

import java.io.* ;

import java.util.Random ;


public class TempSyncFile
{
    public static File tempFile = null;


    public synchronized static File createTempFile(String prefix, String suffix, File directory) {

        Long ct = System.currentTimeMillis();
        String ctStr = ct.toString();

        Double randomDNumber = Math.random();
        String randomNumber = randomDNumber.toString();

        String newPrefix = prefix + "_" + ctStr + "_" + randomNumber + "_";
        try {
            tempFile = File.createTempFile(newPrefix, suffix, directory);
        } catch (IOException ex) {
            System.err.println("Unable to create temporary file TempSyncFile::createTempFile");
            ex.printStackTrace(System.err);
            System.err.flush();
        } finally {

            return tempFile;
        }
    }


}
