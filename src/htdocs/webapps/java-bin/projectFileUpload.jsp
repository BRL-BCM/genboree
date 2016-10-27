<%@ page import="org.apache.commons.fileupload.*, org.apache.commons.fileupload.disk.DiskFileItemFactory,
                 org.apache.commons.fileupload.servlet.ServletFileUpload, java.util.*,
                 java.io.*, java.lang.*, org.json.JSONObject, java.net.URLEncoder"%><%

// NO NEWLINES BETWEEN % >< % in this FILE !!! IMPORTANT.

String respStatus = "";
String respMessage = "";

String tmpFilePath = null;
String prjFileName = null;
String prjFilePath = null;
String projectName = "";
Map<String,String> fileItemMap = new HashMap<String,String>() ;

// Get the project name from GET params, ensure it's escaped
projectName = request.getParameter("projectName");
if(projectName != null && !projectName.equals("")) {

  String escProjectName = URLEncoder.encode(projectName, "UTF-8");
  escProjectName = escProjectName.replaceAll("\\+", "%20") ;

  // Check that we have a file upload request
  boolean isMultipartForm = ServletFileUpload.isMultipartContent(request);
  if(isMultipartForm) {
    // Create a factory for disk-based file items
    FileItemFactory factory = new DiskFileItemFactory();
    // Create a new file upload handler
    ServletFileUpload upload = new ServletFileUpload(factory);
    // Parse the request
    List items = upload.parseRequest(request);
    // Process the uploaded items
    Iterator itemIter = items.iterator();
    while (itemIter.hasNext()) {
        FileItem item = (FileItem) itemIter.next();
        String name = item.getFieldName();      
        if (item.isFormField()) {
          String value = item.getString() ;
          fileItemMap.put(name, value);
        } else {
          // Shouldn't be a file because we're using the Nginx upload module
          // which should have modified the request body replacing the file data with form fields
          System.err.println("Received a non-formfield item.  Probably a File item.");
        }
    }    
    tmpFilePath = fileItemMap.get("projectFiles_upload.path") ;
    prjFileName = fileItemMap.get("projectFiles_upload.name") ;
    
    String escPrjFileName = URLEncoder.encode(prjFileName, "UTF-8");
    escPrjFileName = escPrjFileName.replaceAll("\\+", "%20") ;
    
    // Unencode '/' in the project name which designates a sub project
    escProjectName = escProjectName.replaceAll("%2F", "/") ;
    
    prjFilePath = "/usr/local/brl/data/genboree/projects/" + escProjectName + "/genb^^additionalFiles/";
    
    
    // Move using a system call, because File.renameTo is unreliable
    // Ensure everything is properly escaped
    String cmdLine="mv -f " + tmpFilePath + " " + prjFilePath + escPrjFileName;

    //System.err.println("DEBUG: tmpFilePath => " + tmpFilePath) ;
    //System.err.println("DEBUG: prjFileName => " + escPrjFileName) ;
    //System.err.println("DEBUG: prjFilePath => " + prjFilePath) ;
    //System.err.println("DEBUG: cmdLine => " + cmdLine) ;

    try {
      Process p = Runtime.getRuntime().exec(cmdLine);
    } catch(IOException ioe) {
      System.out.println(ioe);
      respStatus = "ERROR";
      respMessage = "Error writing file..." + ioe.toString();      
      // output that there was a problem
    }
    // Need to check what cmdLine has returned to get an idea whether it was successful    
    // If successful notify.
    respStatus = "OK";
    respMessage = "File has been uploaded";
  } else {
    // projectName is null
    respStatus = "ERROR";
    respMessage = "Not a multipart content request.";
  }
      
} else {
    // projectName is null
    respStatus = "ERROR";
    respMessage = "projectName is missing";
}

JSONObject json = new JSONObject();
json.put("msg", respMessage);
json.put("statusCode", respStatus);

JSONObject respJson = new JSONObject();
respJson.put("status", json);
String output = respJson.toString();

%><%= output %><%@ include file="include/common.incl" %>