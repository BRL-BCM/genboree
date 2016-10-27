<%@ page import="org.genboree.samples.SampleUploader,
                 java.io.File,
                 org.genboree.util.*,
                 org.genboree.message.GenboreeMessage"%>                 
<%@ include file="include/fwdurl.incl" %>  
<%@ include file="include/userinfo.incl" %>
<%
  
    String dbName = SessionManager.getSessionDatabaseName(mys); 
    String fileName =  null; 
    if (mys.getAttribute("fileName") != null) {
        fileName =(String)mys.getAttribute("fileName");
      
    }
    String fileDate = null; 
    if (mys.getAttribute("fileDate") != null) {
        fileDate = (String) mys.getAttribute("fileDate"); 
      
    }
 
    if (dbName == null || fileName == null) {
       GenboreeMessage.setErrMsg(mys, "error in database name or file name"); 
        
    }
          
    String userId = myself.getUserId();
     
    if (mys.getAttribute("uploading") == null) { 
        File file = new File(fileName);
        SampleUploader uploader = new SampleUploader(mys, dbName, db, file, userId);          
        mys.setAttribute("uploading", "y");        
        Thread t = new Thread(uploader); 
     //  t.setDaemon(true);
        t.start();        
          //uploader.startUpload(myself.getName(), userId, file.getName(), db );    
    }  
    else {  
        mys.removeAttribute("uploading");
      response.sendRedirect("/java-bin/uploadMsg.jsp"); 
    }
%><HTML>
<head>
<title>Genboree - Sample Upload</title>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<meta HTTP-EQUIV='refresh' CONTENT='0.5'>
</head>
<BODY>
</BODY>
</HTML>
