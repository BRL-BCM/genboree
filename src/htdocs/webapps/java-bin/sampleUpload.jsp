<%@ page import="java.io.File,
              
                 org.genboree.upload.*,
                 org.genboree.upload.AnnotationUploader,
                 org.genboree.upload.DatabaseCreator,
                 org.genboree.upload.FastaEntrypointUploader,
                 org.genboree.message.GenboreeMessage,
                 org.genboree.samples.SampleUploader"%>
                 
<%@ page import="org.genboree.dbaccess.GenboreeGroup,
                 org.genboree.upload.HttpPostInputStream,
                 java.util.*,
                 java.io.*"%>
 
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%!
    public static final String UPLOAD_FILE_NAME = "sampleFileName";
    public static final String UPLOAD_EMAIL_SUBJECT = "Your Genboree upload ";
    
 
public static Hashtable saveFileReturnParams(JspWriter out, String fileName, HttpPostInputStream hpIn,
String fieldWithFile) {
/* Get file to save data to */
File fileToSaveData = null;
File temporaryFile = null;
String temporaryString = null;
Hashtable parms = null;

int part = 0;
boolean debug = true;           
int typeOfCompression = -1;
boolean foundFileWithData = false;
boolean pasteDataFieldHasData = false;
boolean hasData = false;
long currByteCount = 0 ;
long fileByteCount = 0 ;

String nameAttribute = null;
String fileNameAttribute = null;
String contentTypeAttribute = null;
String nameOriginalFile = null;
String fileContentType = null;     
parms = new Hashtable();
fileToSaveData = new File( fileName );        
/* Read in multi-part mime data in post */
try{
while( hpIn.nextPart() ){
currByteCount = 0 ;
nameAttribute = hpIn.getPartAttrib( "name" );
fileNameAttribute = hpIn.getPartAttrib( "filename" );
// out.println("<br>file name" + fileNameAttribute);
contentTypeAttribute = hpIn.getPartAttrib( "Content-Type" );
if(nameAttribute.equalsIgnoreCase(fieldWithFile) && fileNameAttribute != null)
{
nameOriginalFile = fileNameAttribute.replaceAll("[ ]*", "");
int lastLocation = nameOriginalFile.lastIndexOf("\\");
if(lastLocation > -1)
nameOriginalFile = nameOriginalFile.substring(lastLocation + 1);
System.err.println("Name OF ORIGINAL FILE = " + nameOriginalFile);
System.err.flush();
// the following  typeOfCompression code is never used any where 
typeOfCompression = DirectoryUtils.returnTypeOfCompression(contentTypeAttribute);                     
// this is where data is saved 
currByteCount = writeToFile(fileToSaveData.getAbsolutePath(), hpIn, typeOfCompression, nameOriginalFile, out);
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
else //Reads all the other form fields except the paste_data and the upload_field
{
BufferedReader br = new BufferedReader( new InputStreamReader(hpIn) ) ;
temporaryString = br.readLine() ;
if(temporaryString != null)
{
temporaryString = temporaryString.trim();
if(!Util.isEmpty(temporaryString) )
{
parms.put( nameAttribute, temporaryString );
}
}
}
part++;                  
}

if(foundFileWithData)
{
//              temporaryFile.delete();
hasData = foundFileWithData;
currByteCount = fileByteCount;
}               
else
{
//                fileToSaveData.delete();
//                temporaryFile.delete();
currByteCount = -1;
}
parms.put("hasData", "" + hasData);
parms.put("byteCount", "" + currByteCount);

if(fileContentType != null)
parms.put("ContentType", fileContentType);
if(nameOriginalFile != null)
parms.put("fileName", nameOriginalFile);
parms.put("fileToSaveData", fileToSaveData);

} catch (IOException e)
{
e.printStackTrace(System.err);
System.err.flush();
}
return parms;
}


public static long writeToFile(String nameOffileToSaveData, HttpPostInputStream hpIn, int type, String originalName, JspWriter out )
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
} 
catch (Exception e){
e.printStackTrace(System.err);           
return 0;
}

try
{
while ((len = hpIn.read(buf1)) != -1)
{
fos.write(buf1, 0, len);
currByteCount += len;
if ((currByteCount > 0) && ((currByteCount % (1024 * 1024)) == 0))
{
Util.sleep(1);
}
}
fos.close();


originalFile = new File(parentDir, originalName);
fileToSaveData.renameTo(originalFile);
fileToSaveData = originalFile;
//  the following code uncompress files 
 outPutFromProgram =  CommandsUtils.extractUnknownCompressedFile(fileToSaveData.getAbsolutePath());
  nameOfExtractedFile = (String)outPutFromProgram.get("uncompressedFile");           

 if(nameOfExtractedFile != null) { //handle zip archives
    if(!nameOfExtractedFile.equalsIgnoreCase(fileToSaveData.getAbsolutePath())){
        tempFile = new File(nameOfExtractedFile);
        tempFile.renameTo(fileToSaveData);
    }
}
}
catch (Exception e)  {
e.printStackTrace();           
} 
if(nameOfExtractedFile != null) 
return currByteCount;
else
return currByteCount * -1;
}

    
    static String fromAddress = "\"Genboree Team\" " + GenboreeConfig.getConfigParam("gbFromAddress") ;
    static String bccAddress = GenboreeConfig.getConfigParam("gbBccAddress") ;
 %>       
<%
    String refseqId = SessionManager.getSessionDatabaseId(mys);
    if (refseqId == null) {
    // send back to mySample page
    GenboreeMessage.setErrMsg(mys, "Please select a database for uploading. ");   
    GenboreeUtils.sendRedirect(request, response, "/java-bin/mySamples.jsp?mode=Upload");
    return;         
    }
    String dbName = SessionManager.getSessionDatabaseName(mys); 
    if (dbName == null) {
    // send back to mySample page
    GenboreeMessage.setErrMsg(mys, "Please select a database for uploading. ");   
    GenboreeUtils.sendRedirect(request, response, "/java-bin/mySamples.jsp?mode=Upload");
    return;         
    }
    
    String dir = SampleUploader.createDir(mys, DirectoryUtils.uploadDirName , dbName, myself.getName() );    
    if (dir == null ) {
    // 
    out.println( " should report error here " ); 
    
    return; 
    } 
    File dirFile =  new File( dir );
    File fileToSaveData = File.createTempFile( "sample_", ".txt", dirFile);   
    
    long totalBytes = request.getContentLength();
    mys.setAttribute( "totalBytes", new Long(totalBytes * 4) );        
    HttpPostInputStream hpIn = new HttpPostInputStream( request.getInputStream(), mys );
    mys.setAttribute("file2beUploaded", hpIn );
    mys.setAttribute("file2SaveData", fileToSaveData);
    
    // transfer file from client to server 
    Hashtable parms = saveFileReturnParams(out, fileToSaveData.getAbsolutePath(), hpIn, UPLOAD_FILE_NAME); 
    String origFileName = (String)parms.get("fileName");     
    
    boolean has_data = false;  
    
    String fileName =   dir + "/" + origFileName;
    String fileDate =  new Date().toString();
    mys.setAttribute("fileName", fileName);
    mys.setAttribute("fileDate", fileDate);
    GenboreeUtils.sendRedirect(request, response, "/java-bin/uploadDatabase.jsp");
    %>   
