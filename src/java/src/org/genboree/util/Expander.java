package org.genboree.util;


import java.io.*;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
import java.util.ArrayList;
import java.util.HashMap;


public class Expander implements Runnable {

    protected static String fileUtil = Constants.FILEUTIL ;
    protected static String unzipUtil = Constants.UNZIPUTIL;
    protected static String bunzipUtil = Constants.BUNZIPUTIL;
    protected static String gunzipUtil = Constants.GUNZIPUTIL;
    protected static String verifyZip = Constants.VERIFYZIP + " -T";
    protected static String verifyGzip = Constants.VERIFYGZIP + " -t";
    protected static String verifyBzip = Constants.VERIFYBZIP + " -t";
    protected static String[] fileOutput = {"text", "gzip", "bzip2", "Zip", "tar", "executable", "directory"};
    protected String fileName;
    protected String stderr;
    protected String stdout;
    protected int errorLevel;
    protected String uncompressedFileName;
    protected boolean success = false;
    protected boolean debug = false;


    public Expander(String fileName) {
        setStderr("");
        setStdout("");
        setErrorLevel(-1);
        setFileName(fileName);
    }


    public boolean isDebug() {
        return debug;
    }

    public void setDebug(boolean debug) {
        this.debug = debug;
    }

    public String getUncompressedFileName() {
        return uncompressedFileName;
    }

    public void setUncompressedFileName(String uncompressedFileName) {
        this.uncompressedFileName = uncompressedFileName;
    }

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }

    public String getStderr() {
        return stderr;
    }

    public void setStderr(String stderr) {
        this.stderr = stderr;
    }

    public String getStdout() {
        return stdout;
    }

    public void setStdout(String stdout) {
        this.stdout = stdout;
    }

    public int getErrorLevel() {
        return errorLevel;
    }

    public void setErrorLevel(int errorLevel) {
        this.errorLevel = errorLevel;
    }

    public String getFileName() {
        return fileName;
    }

    public void setFileName(String fileName) {
        this.fileName = fileName;
    }


    private ArrayList listContentFromArchive(String inputText) {
        String SOMERE = "^\\s*inflating:\\s*(.*)\\s*$";
        Pattern compiledSOMERE = Pattern.compile(SOMERE, 8); // 40 is 8 (Multiline) + 32(DOTALL)
        Matcher matchSOMERE = compiledSOMERE.matcher(inputText);
        boolean result = false;
        int numberGroups = -1;
        int indexOfString = 0;
        int counter = 0;
        String groupStr = null;
        int maxNumberOfFilesToList = 20;
        ArrayList allFilesInArchive = null;

        if (inputText == null) return null;

        allFilesInArchive = new ArrayList();

        while (indexOfString < inputText.length() && counter < maxNumberOfFilesToList) {
            groupStr = null;
            result = matchSOMERE.find(indexOfString);
            if (!result) {
                System.err.println("The regular expression " + SOMERE + " failed!");
                System.err.flush();
                return null;
            }

            numberGroups = matchSOMERE.groupCount();

            if (numberGroups < 1)
                break;

            for (int i = 1; i <= matchSOMERE.groupCount(); i++)
                groupStr = matchSOMERE.group(i);

            if (groupStr != null)
                allFilesInArchive.add(groupStr);

            indexOfString = matchSOMERE.end();
            counter++;
        }
        if (allFilesInArchive.isEmpty() || allFilesInArchive.size() < 1) return null;

        return allFilesInArchive;
    }


    public int checkFileType(String fullPathFileName) {
        String cmd = null;
        HashMap returnValues = null;
        Integer tempErrorLevel = null;
        File parentDir = null;
        File inputFile = null;
        int fileUtilResult = -1;
        String tempName = null;

        inputFile = new File(fullPathFileName);
        parentDir = new File(inputFile.getParent());
        cmd = fileUtil + " " + inputFile.getAbsolutePath();

        if (inputFile.exists() && inputFile.length() > 20) {
            returnValues = CommandsUtils.runCommandaCollectInfo(cmd, null, parentDir.getAbsolutePath());
            tempErrorLevel = (Integer) returnValues.get("errorLevel");
            setErrorLevel(tempErrorLevel.intValue());
            setStderr((String) returnValues.get("stderr"));
            setStdout((String) returnValues.get("stdout"));
        }
        else
        {
            setErrorLevel(30);
            setStderr("File: " + fullPathFileName.replaceFirst("/.*/", "") + " appears to be empty, please re-upload a file with data");
            setStdout("");
            return -1;
        }

        if (errorLevel != 0) {
            System.out.println("FATAL ERROR = " + errorLevel + "\n" + stdout + "\n");
            System.out.println(stderr);
            return -1;
        }

        tempName = inputFile.getName() + ":";
        stdout = stdout.replaceFirst(tempName, "");
        for (int i = 0; i < fileOutput.length; i++) {
            if (stdout.indexOf(fileOutput[i]) >= 0) {
                fileUtilResult = i;
                break;
            }
        }

        if (debug) {
            System.err.println("Expander#checkFile: errorLevel=" + getErrorLevel() + "\n   stderr = '" + getStderr() + "'\n   stdout = '" + getStdout() + "'\n\n");
            if (fileUtilResult >= 0) {
                System.err.println("The result of Expander checkFileType = " + fileUtilResult + " matching text = " + fileOutput[fileUtilResult]);
                System.err.flush();
            } else {
                System.err.println("Expander#checkFile: the filetype was not found?? " + fileUtilResult);
                System.err.flush();

            }
        }
        return fileUtilResult;
    }


    public void run() {
        File originalFile = null;
        File inputFile = null;
        File parentDir = null;
        File newFileName = null;
        int fileUtilResult = -1;
        String decompressUtil = null;
        String decompressCommand = null;
        boolean processedSuccessfully = false;
        String zipKeyWord = "inflating:";
        String uncompName = null;
        HashMap returnValues = null;
        Integer tempErrorLevel = null;


        originalFile = new File(getFileName());
        parentDir = new File(originalFile.getParent());
        inputFile = new File(parentDir, originalFile.getName());

        fileUtilResult = checkFileType(getFileName());

        if (debug) {
            System.err.println("Expander run:");
            System.err.println("    After testingTheFileType");
            System.err.println("    the fileUtilResult = " + fileUtilResult);
            System.err.println("    the errorLevel = " + errorLevel);
            System.err.println("    the stderr = " + stderr);
            System.err.println("    the stdout = " + stdout);
            System.err.flush();
        }


        switch (fileUtilResult) {
            case 0:
                processedSuccessfully = true;
                uncompName = inputFile.getAbsolutePath();
                setErrorLevel(0);
                setStderr("");
                setStdout("Text file");
                if (debug)
                    System.err.println("Found text file in Expander.run");
                break;
            case 1:
                if (debug)
                    System.err.println("Inside the case 1 gzip file");
                if (!inputFile.getName().endsWith(".gz")) {
                    uncompName = inputFile.getAbsolutePath();
                    newFileName = new File(inputFile.getAbsolutePath() + ".gz");
                    inputFile.renameTo(newFileName);
                } else {
                    newFileName = inputFile;
                    uncompName = inputFile.getAbsolutePath().replaceFirst("\\.gz$", "");
                }
                decompressUtil = gunzipUtil;
                decompressCommand = decompressUtil + " " + newFileName.getName();
                if (debug)
                    System.err.println("the decompressCommand = " + decompressCommand);
                returnValues = CommandsUtils.runCommandaCollectInfo(decompressCommand, null, parentDir.getAbsolutePath());

                tempErrorLevel = (Integer) returnValues.get("errorLevel");
                setErrorLevel(tempErrorLevel.intValue());
                setStderr((String) returnValues.get("stderr"));
                setStdout((String) returnValues.get("stdout"));
                if (getErrorLevel() == 2) {
                    if (getStderr().indexOf("trailing garbage ignored") >= 0) {
                        tempErrorLevel = new Integer(0);
                        setErrorLevel(0);
                    }
                }
                if (debug) {
                    System.err.println("the stderr = " + getStderr());
                    System.err.println("the stdout = " + getStdout());
                    System.err.println("the errorLevel = " + getErrorLevel());
                }
                if (errorLevel == 0)
                    processedSuccessfully = true;
                break;
            case 2:
                if (!inputFile.getName().endsWith(".bz2")) {
                    uncompName = inputFile.getAbsolutePath();
                    newFileName = new File(inputFile.getAbsolutePath() + ".bz2");
                    inputFile.renameTo(newFileName);
                } else {
                    newFileName = inputFile;
                    uncompName = inputFile.getAbsolutePath().replaceFirst("\\.bz2$", "");
                }
                decompressUtil = bunzipUtil;
                decompressCommand = decompressUtil + " " + newFileName.getName();
                returnValues = CommandsUtils.runCommandaCollectInfo(decompressCommand, null, parentDir.getAbsolutePath());
                tempErrorLevel = (Integer) returnValues.get("errorLevel");
                setErrorLevel(tempErrorLevel.intValue());
                setStderr((String) returnValues.get("stderr"));
                setStdout((String) returnValues.get("stdout"));
                if (errorLevel == 0)
                    processedSuccessfully = true;
                break;
            case 3:
                if (!inputFile.getName().endsWith(".zip")) {
                    newFileName = new File(inputFile.getAbsolutePath() + ".zip");
                    inputFile.renameTo(newFileName);
                } else
                    newFileName = inputFile;

                decompressUtil = unzipUtil;
                decompressCommand = decompressUtil + " " + newFileName.getName();
                returnValues = CommandsUtils.runCommandaCollectInfo(decompressCommand, null, parentDir.getAbsolutePath());
                tempErrorLevel = (Integer) returnValues.get("errorLevel");
                setErrorLevel(tempErrorLevel.intValue());
                setStderr((String) returnValues.get("stderr"));
                setStdout((String) returnValues.get("stdout"));
                int first = stdout.indexOf(zipKeyWord);
                int last = stdout.lastIndexOf(zipKeyWord);
                if (first == last) {
                    String testString = stdout.substring(first + zipKeyWord.length());
                    testString = testString.trim();
                    uncompName = parentDir.getAbsolutePath() + "/" + testString;
                } else {
                    if (isDebug()) {
                        // This section deals with archives with multilple files but we don't support this feature yet.
                        ArrayList listOfFiles = listContentFromArchive(stdout); // regular expression function to extract all files and file names from archive
                        for (int i = 0; i < listOfFiles.size(); i++) {
                            System.err.println("file[" + i + "] = " + parentDir.getAbsolutePath() + "/" + (String) listOfFiles.get(i));
                        }
                        System.err.flush();
                    }
                }

                break;
            default:
                setErrorLevel(30);
                String theExFile = (getUncompressedFileName() == null) ? getFileName() : getUncompressedFileName();
                if(getStderr() == null)
                    setStderr("ERROR: Unable to recognize file: " + theExFile + " WRONG FORMAT OR ARCHIVE");
//                System.err.println("ERROR: Unable to recognize file: " + theExFile + " WRONG FORMAT OR ARCHIVE");
                setStdout("");
                break;
        }


        if (debug) {
            System.err.println("After the switch");
            System.err.println("the fileUtilResult = " + fileUtilResult);
            System.err.println("the errorLevel = " + errorLevel);
            System.err.println("the stderr = " + stderr);
            System.err.println("the stdout = " + stdout);
            System.err.flush();
        }

        if (errorLevel == 0)
            fileUtilResult = checkFileType(uncompName);

        if (debug) {
            System.err.println("After rechecking the file = " + uncompName);
            System.err.println("the fileUtilResult = " + fileUtilResult);
            System.err.println("the errorLevel = " + errorLevel);
            System.err.println("the stderr = " + stderr);
            System.err.println("the stdout = " + stdout);
            System.err.flush();
        }

        if (errorLevel == 0) {
            if (fileUtilResult != 0) {
                setErrorLevel(30);
                String theExFile = (getUncompressedFileName() == null) ? getFileName() : getUncompressedFileName();
                setStderr("ERROR: Unable to recognize file: " + theExFile + " WRONG FORMAT OR ARCHIVE");
                System.err.println("Last process ERROR: Unable to recognize file: " + theExFile + " WRONG FORMAT OR ARCHIVE");
                setStdout("");
                processedSuccessfully = false;
            } else
                processedSuccessfully = true;
        } else {
            setSuccess(false);
            return;
        }


        setUncompressedFileName(uncompName);
        setSuccess(processedSuccessfully);

    }

    public static void printUsage() {
        System.out.print("usage: Expander ");
        System.out.println("-f fileName ");
        return;
    }

    public static void main(String[] args) throws Exception {
        String name = null;
        boolean expandSuccess = false;

        if (args.length == 0) {
            printUsage();
            System.exit(-1);
        }


        if (args.length >= 1) {

            for (int i = 0; i < args.length; i++) {
                if (args[i].compareToIgnoreCase("-f") == 0) {
                    i++;
                    if (args[i] != null) {
                        name = args[i];
                    }
                }
            }

        } else {
            printUsage();
            System.exit(-1);
        }

        Expander expandFile = new Expander(name);
        expandFile.setDebug(false);
        expandFile.run();
        expandSuccess = expandFile.isSuccess();
        String result = (expandSuccess) ? "generating a regular text file " : "but the resulting file is not plain text file";
        String theExFile = (expandFile.getUncompressedFileName() == null) ? " " : " and the uncompressedFile is " + expandFile.getUncompressedFileName();
        System.err.println("file " + name + " has been processed " + result + theExFile);

        System.exit(0);
    }
}
