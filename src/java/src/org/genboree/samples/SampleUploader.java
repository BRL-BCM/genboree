package org.genboree.samples;

import javax.servlet.http.HttpSession;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;

import org.genboree.dbaccess.DBAgent;
import org.genboree.manager.tracks.Utility;
import org.genboree.message.GenboreeMessage;
import org.genboree.util.DirectoryUtils;
import org.genboree.util.* ;

/**
 * action class for file uploading
 * User: tong
 * Date: Oct 27, 2006
 * Time: 2:57:27 PM
 */
public class SampleUploader implements Runnable   {

    private File file;
    HttpSession httpSession ;
    Connection con;
    String userId;


    public Connection getCon() {
        return con;
    }

    public void setCon(Connection con) {
        this.con = con;
    }

    String dbName;
    DBAgent db ;

    public SampleUploader() {}
    public SampleUploader (HttpSession session, String dbName, DBAgent db,  File uploadFile, String uid)  {
        this.httpSession = session;
        this.file = uploadFile;
        this.dbName = dbName;
        this.db = db ;
        this.userId = uid;
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

    /**
      * faster version of directory creation
      * create a directory file  in the following order: path String -> databaseName-> userName ->randomTime
      *@param mys HttpSession for error reporting
     *@param  path default directory
     *  @return created directory path if success , null otherwise
      */


        public static String createDir(HttpSession mys,  String path,  String databaseName, String userName ){
            String tempDir = null;

            boolean success = false;
            ArrayList errList = new ArrayList ();

            if (path == null )
                errList.add ("passed file path is empty. ");

            if(databaseName == null)
             errList.add ("passed databaseName is empty. ");

             if(userName == null)
                errList.add ("passed userName is empty. ");

            File file = new File(path);
            if(!file.exists() || !file.isDirectory() || !file.canWrite()){
                  errList.add("File " + path + " does not exist, or does not allow write " );
            }

            if(!errList.isEmpty()) {
                GenboreeMessage.setErrMsg(mys, "Sorry, An error happened in file uploading ", errList);
                return null;
            }
             success = DirectoryUtils.createNewDir(path, databaseName);
            if(!success)
            {
                GenboreeMessage.setErrMsg(mys, "Sorry, An error happened in file uploading: failure in create directory   ");
                return null;
            }

            tempDir = path + "/" + databaseName;


            success = createNewDir(tempDir, userName);
            if(!success)
            {
                System.err.println("directory = " + path + "/" + databaseName + " does not exist or wrong permissions");
                System.err.flush();
                return null;
            }

           tempDir = tempDir + "/" + userName;

        String randomTime = DirectoryUtils.generateUniqueName();
               if(randomTime == null)
               {
                   System.err.println("Unable to generate unique name");
                   System.err.flush();
                   return null;
               }

             success = createNewDir(tempDir, randomTime);
            if(!success)
            {
                System.err.println("directory = " + tempDir + "/" + randomTime + " does not exist or wrong permissions");
                System.err.flush();
                return null;
            }

            tempDir = tempDir + "/" + randomTime;

            System.err.println("the directory " + tempDir + " has been successfully created");
            System.err.flush();

            return tempDir;
        }

/**
 *
  * @param con
 * @param mys
 * @param file
 * @param fileName
 * @return

 */
    public  SampleError   uploadFile (Connection con, HttpSession mys, File file, String  fileName) {
        java.util.GregorianCalendar cal = new java.util.GregorianCalendar();
         String startTime = cal.getTime().toString();

        SampleError err =   SampleFileValidator.validateFile(file, fileName);
        if (err.errStatus >0 ) {
            java.util.GregorianCalendar cal1 = new java.util.GregorianCalendar();
            String finishTime = cal1.getTime().toString();
            err.setStartTime(startTime);
            err.setFinishTime(finishTime);
            return err;
        }

        int [] attributeIds = findAttributeIds(con, mys, file, fileName) ;

        if (attributeIds == null || attributeIds.length <1)
        {
            err.errStatus = 300;
            System.err.println ();
            java.util.GregorianCalendar cal1 = new java.util.GregorianCalendar();
            String finishTime = cal1.getTime().toString();
            err.setStartTime(startTime);
            err.setFinishTime(finishTime);
            return err;
        }


        HashMap id2values = uploadFileData(mys, file, fileName, attributeIds) ;

       if ( id2values == null ||  id2values.isEmpty())
        {
            err.errStatus = 300;
            java.util.GregorianCalendar cal1 = new java.util.GregorianCalendar();
            String finishTime = cal1.getTime().toString();
            err.setStartTime(startTime);
            err.setFinishTime(finishTime);
            System.err.println ();
            return err;
        }

        err = insertValues ( this.dbName, db, id2values, attributeIds, err);
        err.numSamples = id2values.size();

        java.util.GregorianCalendar cal1 = new java.util.GregorianCalendar();
        String finishTime = cal1.getTime().toString();
        err.setStartTime(startTime);
        err.setFinishTime(finishTime);

      return  err;
    }

    public  int [] findAttributeIds  (Connection con, HttpSession mys, File file, String  fileName) {
        String line = null;
        boolean isHeaderLine = true;
        int [] attributeIds = null;
        String headerLine = "";
        String test = "";
        String [] attributes = null;
        int firstHeaderTokenIndex = -1;
          try {
             BufferedReader br = new BufferedReader(new FileReader (file));
             while ((line = br.readLine()) != null ) {
                 test = line.trim();
                 if (test =="" || test.length() ==0 )
                     continue;

                 attributes = line.split("\t");
                 String firstToken = null;
                 if (isHeaderLine) {
                        headerLine = line;
                        if (attributes != null && attributes.length > 0)  {
                            firstToken = attributes[0];
                          }

                        if (firstToken != null )
                            firstHeaderTokenIndex = line.indexOf(firstToken);
                        isHeaderLine = false;
                 }
                 else {
                    String sampleId = null;
                    if (attributes != null && attributes.length > 0)
                       sampleId = attributes[0];

                      // get sampleId
                      if (sampleId != null ) {
                          int  firstValueTokenIndex = line.indexOf(sampleId);
                          // in this case, there is a value in the cell cross header and sampleId

                           if (firstValueTokenIndex == firstHeaderTokenIndex )
                               attributeIds = processHeaderLine(con, headerLine, true);
                           // in this case, the cell cross header and sampleId is blank
                            else if (firstValueTokenIndex < firstHeaderTokenIndex)
                             attributeIds = processHeaderLine(con, headerLine, false);
                  }

                    break;
                 }
              }
              br.close();
         }
          catch (IOException e1) {
              e1.printStackTrace();
              GenboreeMessage.setErrMsg(mys, " erorr happened in uploading. ");
          }
        return attributeIds ;
      }



    public  HashMap   uploadFileData ( HttpSession mys, File file, String  fileName, int [] attributeIds) {
        String line = null;
        boolean startProcess = false;
        HashMap id2values = null;
        String [] values = null;
        String [] attributes = null;
        String sampleId = null;
        String test = "";
        int numAttributes = 0;
        if (attributeIds != null && attributeIds.length > 0)
           numAttributes = attributeIds.length;
        else  {
            System.err.println ("no attribute id found" );
            System.err.flush();
            return null;
        }

           try {
               id2values = new HashMap ();
              BufferedReader br = new BufferedReader(new FileReader (file));
              while ((line = br.readLine()) != null ) {
                  test = line.trim();
                // skip empty line
                  if (test =="" || test.length() ==0 )
                      continue;
                  if (!startProcess) {
                   startProcess = true;
                  }
                  else {
                        attributes = line.split("\t");
                        sampleId = null;
                        if (attributes != null && attributes.length > 0)  {
                            sampleId = attributes[0];

                            if (sampleId != null)
                               sampleId = sampleId.trim();
                            // this case should be caught at validator
                            if (sampleId == null || sampleId.length() ==0)
                              continue;

                            values = new String [numAttributes ] ;
                            // attribute matches headerline  or less
                            if (attributes.length-1 <= numAttributes) {
                                for  (int i=0; i<attributes.length-1; i++)
                                values [i] = attributes[i+1];
                            }
                            // this case should be caught at validator
                            else if (attributes.length-1 > numAttributes) {
                                for  (int i=0; i<numAttributes-1; i++)
                                values [i] = attributes[i+1];
                            }

                            if (sampleId != null)
                            id2values.put (sampleId, values);
                        }
                  }
               }
               br.close();
          }
           catch (IOException e1) {
               e1.printStackTrace();
               GenboreeMessage.setErrMsg(mys, " erorr happened in uploading. ");
           }
        return id2values;
       }


    public  int []  processHeaderLine (Connection con, String line, boolean skipFirstToken) {
        int [] ids = null;
        String sql = "insert ignore into samplesAttNames (saName) values (?) ";
        String sql1 =   "SELECT LAST_INSERT_ID()";
        String sql2 =   "SELECT saAttNameId from samplesAttNames where saName = ? ";
        try {

            String[] allattributes = line.split("\t");
            int numAttributes = allattributes.length;
            if (skipFirstToken)
               numAttributes --;
               String[] attributes = new String [numAttributes];
             String value = null;
            if (skipFirstToken) {
                for (int i=0; i<numAttributes; i++) {
                    value = allattributes[i+1];
                    if (value!= null)
                        value = value.trim();
                    attributes [i] = value;
                }
              }
              else {
                 for (int i=0; i<numAttributes; i++) {
                    value = allattributes[i];
                    if (value!= null)
                        value = value.trim();
                    attributes [i] = value;
                }
              }
        PreparedStatement stms = con.prepareStatement(sql);
        PreparedStatement stms1 = con.prepareStatement(sql1);
        PreparedStatement stms2 = con.prepareStatement(sql2);
        ids = new int [attributes.length];
        ResultSet rs = null;
          for (int i=0; i<attributes.length; i++) {
            int insertedCount = 0;
            stms.setString(1, attributes[i]);
            insertedCount = stms.executeUpdate();
            if  (insertedCount >0) {
                rs = stms1.executeQuery();
                if (rs.next())
                ids[i] = rs.getInt(1);
            }
            else {
               stms2.setString(1, attributes[i]);
               rs = stms2.executeQuery();
               if (rs.next())
                ids[i] = rs.getInt(1);
            }
           }
          stms.close();
        }
        catch (Exception e) {
            e.printStackTrace();
        }
     return ids;
    }


  /**
   * insert one line of value which corersponding to one sample
   * @param attributeIds

   */
    public  SampleError insertValues (String dbName, DBAgent db, HashMap sampleId2Values, int [] attributeIds, SampleError err) {
            String sqlInsSamples = "insert ignore into samples (saName) values (?) ";
            String sqlInsValues = "insert ignore into samplesAttValues(saValue, saSha1) values (?, ?) ";
            String sqlInsMapping = "insert ignore into samples2attributes (saId, saAttNameId, saAttValueId) values (?, ?, ?)";
            String sqlLastId =   "SELECT LAST_INSERT_ID()";
            PreparedStatement stmsSamples = null;
            PreparedStatement stmsLastId =   null;
             try {
                this.con = db.getConnection(this.dbName);
                PreparedStatement stmsValues = con.prepareStatement(sqlInsValues);
                PreparedStatement stmsValueId = con.prepareStatement("select saAttValueId from samplesAttValues  where saValue = ? ");
                PreparedStatement  stmsSaId = con.prepareStatement("select saId from samples where saName = ? ");
                ResultSet rs = null;
                String id = null;
                String values [] = null;
                int sampleId = 0;
                int index = 0;
                 int numSamples = sampleId2Values.size();
                int sampleIds[] = new int [sampleId2Values.size()];
                HashMap sampleName2id = new HashMap ();
                // insert samples table
                String [] sampleNames   = (String [])sampleId2Values.keySet().toArray(new String [numSamples]);
                  if (con == null || con.isClosed())
                  return null;
                    stmsSamples = con.prepareStatement(sqlInsSamples);
                    stmsLastId =  con.prepareStatement(sqlLastId);
                 for  (int i=0; i< sampleNames.length; i++) {
                    id = sampleNames[i];
                    if (id == null || id.equals("") )
                    continue;
                    stmsSaId.setString(1, id);
                    rs = stmsSaId.executeQuery();
                    if (rs.next()) {
                    sampleName2id.put(id, rs.getString(1));
                    }
                 }
                 err.numUpdated = sampleName2id.size();
                 int totalNumInserted =0;
                 int insertedSampleCount =0;
                  for  (int i=0; i< sampleNames.length; i++) {
                    id = sampleNames[i];
                    if (id == null || id.equals("") )
                    continue;
                    if ( sampleName2id.get(id)== null) {
                    stmsSamples.setString(1, sampleNames[i]);
                    insertedSampleCount =0;
                    insertedSampleCount =  stmsSamples.executeUpdate();
                    if (insertedSampleCount >0) {
                    totalNumInserted ++;
                    rs = stmsLastId.executeQuery();
                    if (rs.next())
                    sampleName2id.put(id, rs.getString(1));
                    }
                    }
                 }
                 stmsSamples.close();

                 err.numInserted = totalNumInserted;
                 if (this.con == null || this.con.isClosed()) {
                     try {
                       this.con = db.getConnection(this.dbName);
                     }
                     catch (SQLException e) {
                         e.printStackTrace();
                         return null;
                     }
                 }

                  int [] valueIds = null;
                 HashMap sampleId2ValueIds = new HashMap ();
                  Iterator iterator1 = sampleId2Values.keySet().iterator();
                   while (iterator1.hasNext()) {
                        String sampleID = (String)iterator1.next();
                        // insert value table
                        String md5 = null;
                        values = (String [])sampleId2Values.get (sampleID );
                        valueIds = new int [values.length];
                        for(int i=0; i<values.length; i++){
                             // if values is null, oesn't insert, cz default is null
                            if (values[i]==null)
                                continue;

                            stmsValues.setString(1, values[i]);
                            md5 = Utility.generateMD5( values[i]);
                            stmsValues.setString(2, md5);

                          int vcount = stmsValues.executeUpdate();
                            if (vcount>0) {
                                rs = stmsLastId.executeQuery();
                                if (rs.next())
                                valueIds[i]  = rs.getInt(1);
                            }
                            else {
                                stmsValueId.setString(1, values[i]);
                                rs = stmsValueId.executeQuery();
                                if (rs.next())
                                valueIds[i]  = rs.getInt(1);
                            }
                        }
                       sampleId2ValueIds.put(sampleID, valueIds);
                   }


                     stmsValues.close();

                    if (this.con == null || this.con.isClosed()) {
                     try {
                       this.con = db.getConnection(this.dbName);
                     }
                     catch (SQLException e) {
                         e.printStackTrace();
                         return null;
                     }
                 }

                 PreparedStatement stmsDel = con.prepareStatement("delete from samples2attributes where saId = ? and saAttNameId = ? and saAttValueId = ?");
                 PreparedStatement stmsMapping = con.prepareStatement(sqlInsMapping);


                  Iterator iterator2 =  sampleId2ValueIds.keySet().iterator();
                 String tempId = null;

                 int numArr = (numSamples * attributeIds.length) /100;
                 int remain =(numSamples * attributeIds.length)  % 100;
                 if (remain >0)
                   numArr +=1;
                 AttributeMapping [][] mappings  = new AttributeMapping [numArr][100];

                 int sid = -1;
                 int counter = 0;
                 int currentIndex = 0;
                while (iterator2.hasNext()){
                    String sampleName = (String)iterator2.next();
                    tempId = (String)sampleName2id.get(sampleName);
                    try {
                        sid = Integer.parseInt( tempId );
                    }
                    catch  (Exception e ) {
                        System.err.println(" \nsample " + sampleName + "  id " + tempId);
                        System.err.flush();
                       // continue;
                    }

                    valueIds = (int [])sampleId2ValueIds.get(sampleName);
                    for (int i=0; i<attributeIds.length; i++) {

                      mappings[currentIndex][counter] = new AttributeMapping();
                        mappings[currentIndex][counter].setSampleId(sid);
                        mappings[currentIndex][counter].setAttributeId(attributeIds[i]);
                        mappings[currentIndex][counter].setValueId(valueIds[i]);

                        if (counter==99) {
                            currentIndex = currentIndex + 1;
                            counter = 0;
                        }
                        else
                              counter ++;
                    }
                }

               for (int i=0; i<numArr; i++) {
                     for (int j=0; j<100; j++) {
                       if (mappings[i][j] == null) {
                              continue;
                       }
                        if (mappings[i][j].getValueId()<=0)
                        {
                              continue;
                        }
                        stmsDel.setInt(1, mappings[i][j].getSampleId());
                        stmsDel.setInt(2, mappings[i][j].getAttributeId());
                        stmsDel.setInt(3, mappings[i][j].getValueId());
                        stmsDel.addBatch();
                        stmsMapping.setInt(1, mappings[i][j].getSampleId());
                        stmsMapping.setInt(2, mappings[i][j].getAttributeId());
                        stmsMapping.setInt(3, mappings[i][j].getValueId());
                        stmsMapping.addBatch();
                   }

                    if (i%10 == 0 && i>0) {
                    stmsDel.executeBatch();
                    stmsMapping.executeBatch();
                   // Thread.currentThread().sleep(1000);

                        if (this.con == null || this.con.isClosed()) {
                            try {
                              this.con = db.getConnection(this.dbName);
                            }
                            catch (SQLException e) {
                                e.printStackTrace();
                                return null;
                            }
                        }

                    }

                    if (numArr < 10 ) {
                         remain = numArr;
                    }
                }

                 if (remain >0) {
                        stmsDel.executeBatch();
                        stmsMapping.executeBatch();
                 }
                 rs.close();
                stmsDel.close();
                stmsMapping.close();
             }
               catch (SQLException e) {
                     e.printStackTrace();
                     return null;
                 }
             catch (Exception e) {
                 e.printStackTrace();
             }
        return err;
    }



    /**
     * before start populate data into database, we should check if the file is locked, and if the process if used.
     * as well as should sleep some time if too much data need updated
     *
     *
     *

     */
    public void run ()
    {
      // the following code does several things,
      /* 1. check if the file is locked
         2. if locked, sleep some time
         3. after each sleep , increase sleep time by certain amount

        question is : could it be that the file sleep forever?
        need to be tested with alrge files
      */

      try
      {
        this.con = this.db.getConnection(this.dbName);
      }
      catch(Exception e)
      {
        e.printStackTrace();
      }
      SampleError err  =  uploadFile(this.con, this.httpSession, this.file, this.file.getName());
      String [] userInfo  = getUserEmail (db, userId );
      String userName = userInfo[1] +" " +  userInfo[2];
      String userEmail = userInfo[0];

      String emailHeader = "";
      String emailBody = "";
      String groupName = SessionManager.getSessionGroupName(this.httpSession);
      String refseqId = SessionManager.getSessionDatabaseId(httpSession);

      if(err.errStatus == SampleError.NO_ERROR)
      {
        emailHeader =  "Your sample upload was complete (no errors.)";
        String beIns = err.numInserted ==1? " was":" were";
        String beUpdate = err.numUpdated ==1? " was":" were";

        emailBody = "Congratulations, " + userName + "!\n" +
                    "\n" +
                    "The process of validating and uploading your sample data was successful.\n" +
                    "\n" +
                    "Job details:\n" +
                    "Group: " + groupName + " \n" +
                    "Database ID: " + refseqId + "\n" +
                    "File Name: " +  this.file.getName()  +    "\n" +
                    "   - contained " + err.numSamples +" samples\n" +
                    "   - of these, "+  err.numInserted  + beIns +  " inserted and " + err.numUpdated  + beUpdate + " updated\n" +
                    "Started At: " + err.startTime + "\n" +
                    "Finished At: " + err.finishTime + "\n" +
                    "\n" +
                    "You can now log into Genboree and view your data.\n" +
                    "\n" +
                    "Thank you for using Genboree,\n" +
                    "The Genboree Team\n" +
                    "(" + GenboreeConfig.getConfigParam("gbAdminEmail") + ")" ;
      }
      else
      {
        emailHeader =  "Your sample upload failed.";
        emailBody = "" +
                    "" +
                    "Dear " + userName + ",\n" +
                    "\n" +
                    "The Sample Upload process failed due to errors.\n" +
                    "Please check your file format and try again.\n" +
                    "\n" +
                    "Job details:\n" +
                    "Group: " + groupName + " \n" +
                    "Database ID: " + refseqId + "\n" +
                    "File Name: " +  this.file.getName()  +  "\n" +
                    "Started At: " + err.startTime + "\n" +
                    "Finished At: " + err.finishTime + "\n" +
                    "\n" +
                    "ERROR: the file has a formatting error:\n" +
                    "---------------------------------------\n\n" ;

        String errBottom =  "\n" +
                            "\n" +
                            "We apologize for any inconvenience,\n" +
                            "The Genboree Team\n" +
                            "(" + GenboreeConfig.getConfigParam("gbAdminEmail") + ")" ;

        String details  = "";
        HashMap errMap = err.error2Line;
        int count = 0;
        Iterator iterator = errMap.keySet().iterator();
        while(iterator.hasNext()  && count<30)
        {
          String key = (String)iterator.next();
          String data = (String)errMap.get(key);
          if(data != null)
          {
            details = details  + data + "\n";
          }
          count ++;
        }
        emailBody = emailBody + details +  errBottom;
      }
      if(userEmail != null)
      {
        sendEmail (userEmail, emailHeader , emailBody  );
      }
      else
      {
        System.err.println("user don't have email address");
      }
      return ;
    }

    void  sendEmail (String  userEmail, String header, String body)  {
         SendMail mail = new SendMail();
         mail.setHost( Util.smtpHost );
         String bccAddress = GenboreeConfig.getConfigParam("gbBccAddress") ;
         String fromAddress = "\"Genboree Team\" <" + GenboreeConfig.getConfigParam("gbFromAddress") + ">";
         //  mail.init();
         mail.setFrom( fromAddress );
         mail.setReplyTo(fromAddress );
         mail.addBcc(bccAddress);
         mail.addTo(userEmail);
         mail.setSubj(header);
         mail.setBody(body);
         mail.go();
     }


    public  String[]   getUserEmail(DBAgent db,  String userId) {
        String [] info = new String[3];
        String sql = "SELECT email, firstName, lastName FROM genboreeuser WHERE userId = ?";
        try {
            Connection connection = db.getConnection();
            PreparedStatement stms = connection.prepareStatement(sql);
            stms.setString(1, userId);
            ResultSet rs = stms.executeQuery();
            if  (rs.next()) {
                info[0] = rs.getString(1);
                info[1] = rs.getString(2);
                info[2] = rs.getString(3);
            }
            rs.close();
            stms.close();
        }
        catch (Exception e) {
            e.printStackTrace();
        }

        return info;
    }




}
