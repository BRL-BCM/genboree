<%@ page import="org.genboree.dbaccess.CacheManager,
                 org.genboree.dbaccess.GenboreeGroup,
                 org.genboree.dbaccess.JSPErrorHandler,
                 org.genboree.dbaccess.util.TasksTable,
                 org.genboree.dbaccess.util.RefSeqTable,
                 org.genboree.util.DirectoryUtils,
                 org.genboree.util.CommandsUtils,
                 org.genboree.util.helpers.RESTapiUtil,
                 org.genboree.message.GenboreeMessage,
                 org.genboree.upload.*,
                 java.io.File,
                 java.util.Date,
                 java.util.*,
                 java.io.*,
                 java.lang.*,
                 org.apache.commons.fileupload.*,
                 org.apache.commons.fileupload.disk.DiskFileItemFactory,
                 org.apache.commons.fileupload.servlet.ServletFileUpload,
                 org.json.JSONObject"
                 %><%@ include file="include/fwdurl.incl" %><%@ include file="include/userinfo.incl" %><%
                 
/**-----------------------------
 *  Initialization of vars
 *
 *-----------------------------*/
                 
    boolean has_data = true;
    boolean isDaemon = false;
    boolean debug = true;
    boolean need_delete_all = false;
    boolean validRefseqId = false;
    boolean rc = false;
    long totalBytes = 0;
    String refseqId = null;
    String groupId = null;
    String fileFormat = null;
    String origFileName = null;
    String theLastView = null;
    String directoryToUse = null;
    String databaseNameInUse = null;
    String inputFormat = null;
    String upload_fastaFileLocation = null;
    File dirToUse = null;
    File fileToSaveData = null;
    HttpPostInputStream hpIn = null;
    Hashtable parms = new Hashtable();
    String tmpFilePath = null;
    String gain_loss_Threshold = null;
    String histogram = null;
    HashMap extraOptions = new HashMap();
    GenboreeGroup grp = null;
    FastaEntrypointUploader uploader = null;
    AnnotationUploader currentUpload = null;
    String fromAddress = "\"Genboree Team\" <" + GenboreeConfig.getConfigParam("gbFromAddress") + ">" ;
    String bccAddress = GenboreeConfig.getConfigParam("gbBccAddress") ;
    String inputFile = null;
    int maxNumberProcess = Util.parseInt(DirectoryUtils.getValueFromPropertyFile("maxWebUploads"), 1);
    String userId = myself.getUserId();
    String redirectTo = null;

    Map env = System.getenv() ;

    String useClusterForGBUpload = "";
    String clusterOutputDir = "";
    String clusterOutputFile = "";

        
    StringBuffer taskWrapper = new StringBuffer();
    StringBuffer genbTaskWrapper = new StringBuffer();
    String appendToEndOfTaskWrapper = "";
    taskWrapper.append(Constants.JAVAEXEC).append(" ").append(Constants.UPLOADERCLASSPATH);
    taskWrapper.append("-Xmx1800M org.genboree.util.TaskWrapper");
    taskWrapper.append(" -a -c ");
    genbTaskWrapper.append("genbTaskWrapper.rb").append(" -v -c ");

    
    StringBuffer uploaderCmdLine = new StringBuffer();
    uploaderCmdLine.append(Constants.JAVAEXEC).append(" ").append(Constants.UPLOADERCLASSPATH);
    
    // Only used for wig
    StringBuffer uploaderCmdLineForImportTool = new StringBuffer();
    uploaderCmdLineForImportTool.append(Constants.WIGUPLOAD);
    // --------------------------------------------------------------------------
    // Arguments for supported formats
    // - put each *possible* argument to the format converter here
    // - the web UI is assumed to use the same names for its form fields
    // - the arguments provided here will be:
    //   . looked for in the GET/POST parameters
    //   . if present, it will be added to the argument list for the converter
    //     like this: --argument
    //   . if a value is present also, that value will be provided like this:
    //     --argument=value
    // --------------------------------------------------------------------------
    String[] converterArgs = {
            // common
            "class",
            "type",
            "subtype",
            // agilent-specific
            "histogram",
            "gainloss",
            "segmentThresh",
            "segmentStddev",
            "minProbes",
            // wig-specific
            "trackName",
            "recordType"
    };

    //GenboreeMessage.clearMessage(mys);

    //System.err.println("The classpath env = " + System.getProperty("CLASSPATH"));
    //System.err.flush();

    // This page handles redirect if btnClose is set
    if (request.getParameter("btnClose") != null) {
        GenboreeUtils.sendRedirect(request, response, "/java-bin/myrefseq.jsp");
        return;
    }

    //theLastView = (String) mys.getAttribute("lastBrowserView");
    //if (theLastView == null) {
    //    theLastView = "myrefseq.jsp";
    //}

    //if (myself == null) {
    //    has_data = false;
    //    GenboreeUtils.sendRedirect(request, response, "/java-bin/login.jsp");
    //    return;
    //}
    
    
    
    
    
    /**-------------------------------------------------------------
     * Parse the POSTed multipart/form-data request body
     * We are using the Nginx upload module, which strips out the File parts
     * and adds fields with values of the tmp file path, name, size and content type
     * See the nginx.genboree.conf for more info
     *
     * Add the fields and values to HashMap parms
     *-------------------------------------------------------------------*/
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
          // Add the fields to parms
          parms.put(name, value);
        } else {
          // Shouldn't be a file because we're using the Nginx upload module
          // which should have modified the request body replacing the file data with form fields
          System.err.println("Received a non-formfield item.  Probably a File item.");
        }
      }    
    }

    // Set vars from post
    refseqId = (String) parms.get("refseq");
    groupId = (String) parms.get("groups");
    String idStr = (String) parms.get("idStr");
    tmpFilePath = (String) parms.get("upload_file.path") ;
    origFileName = (String) parms.get("upload_file.name");
    inputFormat = (String) parms.get("ifmt");
    // This comes from the EP upload form
    fileFormat = (String) parms.get("fileFormatSelect");

    // Set default values
    if (Util.isEmpty(origFileName)) {
        origFileName = "text pasted directly no file provided";
    }
    if (Util.isEmpty(inputFormat)) {
        inputFormat = "lff";
    }
    if (groupId == null) {
        has_data = false;
        GenboreeMessage.setErrMsg(mys, "  The selected group is empty.");
    }
    if (refseqId == null) {
        has_data = false;
        GenboreeMessage.setErrMsg(mys, "The selected database is empty.  ");
    }
    if (idStr == null) {
        idStr = "";
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    /**--------------------------------------------------
     *  Create directories necessary to store the files
     *---------------------------------------------------*/
    directoryToUse = DirectoryUtils.createFinalDir(DirectoryUtils.uploadDirName, refseqId, myself.getUserId());
    dirToUse = new File(directoryToUse);
    fileToSaveData = File.createTempFile("genb", ".lff", dirToUse);
    databaseNameInUse = GenboreeUtils.fetchMainDatabaseName(refseqId);
    grp = new GenboreeGroup();
    grp.setGroupId(groupId);
    grp.fetch(db);







    /**
     * NOTE: This file previously used DirectoryUtils.saveFileReturnParams which adds other stuff to parms,
     * see below for reference if something is broken
     */
    //parms = DirectoryUtils.saveFileReturnParams(fileToSaveData.getAbsolutePath(), hpIn, "upload_file", "paste_data");
    // 
    // Stuff that gets added by DirectoryUtils.saveFileReturnParams
    //    parms.put("hasData", "" + hasData);
    //    parms.put("byteCount", "" + currByteCount);
    //    if(fileContentType != null)
    //    parms.put("ContentType", fileContentType);
    //    if(nameOriginalFile != null)
    //    parms.put("fileName", nameOriginalFile);
    //    parms.put("fileToSaveData", fileToSaveData);

    /**------------------------------------------------
     * Now move the temp file using a system call,
     * because File.renameTo is unreliable for a temp file
     * Ensure everything is properly escaped
     *-------------------------------------------------*/
    String cmdLine="mv -f " + tmpFilePath + " " + fileToSaveData.getAbsolutePath();    

    if(debug) {
      System.err.println("DEBUG: tmpFilePath => " + tmpFilePath) ;
      System.err.println("DEBUG: cmdLine => " + cmdLine) ;
    }

    try {
      Process p = Runtime.getRuntime().exec(cmdLine);
      // Need to change permissions,because the tmpfile is 600, and should be 660
      p = Runtime.getRuntime().exec("chmod 660 " + fileToSaveData.getAbsolutePath());
      // Should probably try using HashMap runCommandaCollectInfo(String command, String dir)
    } catch(IOException ioe) {
      System.out.println(ioe);
      // output that there was a problem
    }
    // Need to check what cmdLine has returned to get an idea whether it was successful










    /**----------------------------------------------------
     * If annotations were pasted in, handle them here
     *---------------------------------------------------*/
    
    String pasteData =(String) parms.get("paste_data");
    // If we have pasted data { if(!pastData.trim.empty?)
    if(pasteData != null && pasteData.trim().length() != 0) {
      // Data from the paste field is written to a file genb3840748715331423261.lff_FromPasteDataField.txt
      File pasteDataFile = new File( fileToSaveData.getAbsolutePath() + "_FromPasteDataField.txt");
      // put the value from paste_data into the file
      // lff/wig/etc uploaders should pick up this file
      FileWriter fWriter = new FileWriter(pasteDataFile);
      fWriter.write(pasteData);
      fWriter.close();
      // Need to get the importers to notice the paste file, fileToSaveData is set to the paste file name
      fileToSaveData = pasteDataFile;
    } else {
      /**
       * Not pasted, we have a file which might be compressed
       * so uncompress it if necessary
       *  CommandsUtils.extractUnknownCompressedFile determines if the file needs uncompression and does nothing if it's not compressed
       */
      HashMap outPutFromProgram = CommandsUtils.extractUnknownCompressedFile(fileToSaveData.getAbsolutePath(), debug);
      String nameOfExtractedFile = (String)outPutFromProgram.get("uncompressedFile");
      // If the file was uncompressed, overwrite the compressed file with the uncompressed file
      if(nameOfExtractedFile != null) {
        if(!nameOfExtractedFile.equalsIgnoreCase(fileToSaveData.getAbsolutePath())) {
          File tempFile = new File(nameOfExtractedFile);
          tempFile.renameTo(fileToSaveData);
        }
      }
    }









        
    // --------------------------------------------------------------------------
    // Gather converter args into extraOptions HashMap
    // --------------------------------------------------------------------------
    for (int ii = 0; ii < converterArgs.length; ii++) {
        String argToLookFor = converterArgs[ii];
        String argValue = null;
        // Is the arg in the form parameters?
        if (parms.containsKey(argToLookFor)) {
            // arg was passed from the form, try to get a value
            argValue = (String) parms.get(argToLookFor);
            // Fix any "checkboxes" that have special values
            if (argValue.equalsIgnoreCase("genbCheckboxOn")) {
                argValue = null; // Present but no args
            }
            // Store the arg and the value (which could be null for boolean flags
            extraOptions.put(argToLookFor, argValue);
        }
    }
    // --------------------------------------------------------------------------

    need_delete_all = (String) parms.get("delAllTracks") != null;
    if (JSPErrorHandler.checkErrors(request, response, db, mys)) return;














    /* ---------------------------------------------------------------------------
    * (1) Unless we have been given a Fasta file for EP upload, we will do
    *     everything normally, as it was done before Fasta files. This should
    *     ensure full backwards compatibility (no code breakage).
    *
    * Therefore, this section is the ORIGINAL code.
    * ------------------------------------------------------------------------ */
    if (fileFormat != null && fileFormat.equals( Constants.GB_FASTA_EP_FILE )) // Could be an "else" obviously, but leaving it open for more options
    {
      
  
      /**----------------------------------
       * Start FASTA import
       * --------------------------------- */
      System.err.println("Start anootations FASTA import");      
      
      
        // Find out some useful information
        upload_fastaFileLocation = fileToSaveData.getCanonicalPath();
        uploaderCmdLine.append( Constants.FASTAFILEUPLOADERCLASS  );
        uploaderCmdLine.append( " -u " ).append( myself.getUserId() ).append( " -r " ).append( refseqId );
        uploaderCmdLine.append( " -f " ).append( upload_fastaFileLocation );

        redirectTo = "/java-bin/entryPointsUpload.jsp?fileName=" + fileToSaveData.getName();
        System.err.println( "55#$->The uploader command is \n" +  uploaderCmdLine.toString() );



        if( DirectoryUtils.isDirectoryWrittable( dirToUse.getAbsolutePath() )  )
        {
            appendToEndOfTaskWrapper = " > " + dirToUse.getAbsolutePath() + "/errors.out 2>&1 &" ;
            appendToEndOfTaskWrapper = Util.urlEncode(appendToEndOfTaskWrapper);
            
        }

        if (useClusterForGBUpload.equals("true") || useClusterForGBUpload.equals("yes"))
        {
          String clusterAdminEmail = "raghuram@bcm.edu";
          StringBuffer clusterSchedulerString = new StringBuffer("clusterJobScheduler.rb");
          String hostname = request.getServerName();
          clusterSchedulerString.append(" -o ").append(hostname).append(":").append(clusterOutputDir);
          clusterSchedulerString.append(" -e ").append(clusterAdminEmail);
          clusterSchedulerString.append(" -c ").append(Util.urlEncode(uploaderCmdLine.toString()));
          clusterSchedulerString.append(" -i ").append(hostname).append(":").append(inputFile);
          clusterSchedulerString.append(" -r gbUpload=1 -k ");
          RunExternalProcess rn = new RunExternalProcess(clusterSchedulerString.toString());
        }
        else
        {
          System.err.println(uploaderCmdLine.toString());
          taskWrapper.append(Util.urlEncode(uploaderCmdLine.toString() )  ).append(" -e ").append(appendToEndOfTaskWrapper );
          RunExternalProcess rn = new RunExternalProcess(taskWrapper.toString());
        }

        theLastView = (String) mys.getAttribute("lastBrowserView");
        if (theLastView == null) {
            theLastView = "defaultGbrowser.jsp";
        }

    /**----------------------------------
     * Done FASTA import
     * --------------------------------- */



//      GenboreeUtils.sendRedirect(request, response, redirectTo);

    }
    else if (fileFormat != null && fileFormat.equals(Constants.GB_LFF_EP_FILE))
    {


    /**----------------------------------
     * Start LFF EP import
     * --------------------------------- */
    System.err.println("Start anootations 3col LFF import");



        /* New code  to upload entry points */
        validRefseqId = DatabaseCreator.checkIfRefSeqExist(db, refseqId, databaseNameInUse);
        if (validRefseqId)
        {
           uploaderCmdLine.append(Constants.UPLOADERCLASS);
           uploaderCmdLine.append(" -u ").append(userId).append(" -r ").append(refseqId);
           uploaderCmdLine.append(" -f ").append( fileToSaveData.getAbsolutePath() );


        }
//      redirectTo = "/java-bin/myrefseq.jsp?mode=Upload";

      redirectTo = "/java-bin/entryPointsUpload.jsp?fileName=" + fileToSaveData.getAbsolutePath();
      System.err.println( "55#$->The uploader command is \n" +  uploaderCmdLine.toString() );



        if( DirectoryUtils.isDirectoryWrittable( dirToUse.getAbsolutePath() )  )
        {
            appendToEndOfTaskWrapper = " > " + dirToUse.getAbsolutePath() + "/errors.out 2>&1 &" ;
            appendToEndOfTaskWrapper = Util.urlEncode(appendToEndOfTaskWrapper);
            
        }

        if (useClusterForGBUpload.equals("true") || useClusterForGBUpload.equals("yes"))
        {
          String clusterAdminEmail = "raghuram@bcm.edu";
          StringBuffer clusterSchedulerString = new StringBuffer("clusterJobScheduler.rb");
          String hostname = request.getServerName();
          clusterSchedulerString.append(" -o ").append(hostname).append(":").append(clusterOutputDir);
          clusterSchedulerString.append(" -e ").append(clusterAdminEmail);
          clusterSchedulerString.append(" -c ").append(Util.urlEncode(uploaderCmdLine.toString()));
          clusterSchedulerString.append(" -i ").append(hostname).append(":").append(inputFile);
          clusterSchedulerString.append(" -r gbUpload=1 -k ");
          RunExternalProcess rn = new RunExternalProcess(clusterSchedulerString.toString());
        }
        else
        {
          System.err.println(uploaderCmdLine.toString());
          taskWrapper.append(Util.urlEncode(uploaderCmdLine.toString() )  ).append(" -e ").append(appendToEndOfTaskWrapper );
          RunExternalProcess rn = new RunExternalProcess(taskWrapper.toString());
        }

        theLastView = (String) mys.getAttribute("lastBrowserView");
        if (theLastView == null) {
            theLastView = "defaultGbrowser.jsp";
        }


    /**----------------------------------
     * DONE LFF EP import
     * --------------------------------- */




//      GenboreeUtils.sendRedirect(request, response, redirectTo);
    }
    else
    {
      
      

    /**----------------------------------
     * Start anootations LFF,Agilent,Blat,Blast,Pash,WIG import
     * --------------------------------- */
    System.err.println("Start anootations LFF,Agilent,Blat,Blast,Pash, WIG import");
      
      
      
      if (need_delete_all)
      {
          validRefseqId = DatabaseCreator.checkIfRefSeqExist(db, refseqId, databaseNameInUse);
          if (validRefseqId)
          {
            currentUpload = new AnnotationUploader(db, refseqId, myself.getUserId(), groupId, databaseNameInUse);
            currentUpload.truncateTables();
          }
      }
      CacheManager.clearCache(db, databaseNameInUse);
      inputFile = fileToSaveData.getAbsolutePath();
      if (Util.isEmpty(inputFormat))
      {
        inputFormat = "lff";
      }
      // This part is for the non-wig uploads which include lff, blat, blast, pash and agilent(for now)
      // Since all of the non-wig formats use the java task wrapper, they have been put together
      if(!inputFormat.equals("wig"))
      {
        
          
      /**----------------------------------
       * Start anootations LFF,Agilent,Blat,Blast,Pash import
       * --------------------------------- */
      System.err.println("Start anootations LFF,Agilent,Blat,Blast,Pash import");
        
                  
        
        
        if (JSPErrorHandler.checkErrors(request, response, db, mys)) {
          return;
        }
                                    
        if (myself == null || grp == null || refseqId == null || fileToSaveData == null)
        {
          GenboreeUtils.sendRedirect(request, response, "/java-bin/login.jsp");
          return;
        }
                   
        uploaderCmdLine.append(Constants.UPLOADERCLASS);
        uploaderCmdLine.append(" -u ").append(userId).append(" -r ").append(refseqId).append(" -f ");
        useClusterForGBUpload = GenboreeConfig.getConfigParam("useClusterForGBUpload");
        // Are we supposed to use the cluster for uploads?
        if (useClusterForGBUpload.equals("true") || useClusterForGBUpload.equals("yes"))
        {
        // InputFile will be local during cluster execution. Need containing dir. to use as output dir. after cluster run
          clusterOutputFile = inputFile.replaceFirst(".*/","");
          clusterOutputFile = "./"+clusterOutputFile;
          clusterOutputDir = inputFile.replaceFirst("[^/]*$","");          
          uploaderCmdLine.append(clusterOutputFile).append(" -t ").append(inputFormat);
        }
        else
        {
          uploaderCmdLine.append(inputFile).append(" -t ").append(inputFormat);
        }
                   
        for (Object key : extraOptions.keySet())
        {
          String value = (String) extraOptions.get((String) key);
          uploaderCmdLine.append(" --").append(key);
          if (value != null && value.length() > 0)
            uploaderCmdLine.append("=").append(value).append(" ");
        }
        redirectTo = "/java-bin/merger.jsp?fileName=" + fileToSaveData.getName();
        System.err.println( "55#$->The uploader command is \n" +  uploaderCmdLine.toString() );
        if( DirectoryUtils.isDirectoryWrittable( dirToUse.getAbsolutePath() )  )
        {
          appendToEndOfTaskWrapper = " > " + dirToUse.getAbsolutePath() + "/errors.out 2>&1 &" ;
          appendToEndOfTaskWrapper = Util.urlEncode(appendToEndOfTaskWrapper);
        }
        // Check if cluster is available. Launch the process there if it is
        if (useClusterForGBUpload.equals("true") || useClusterForGBUpload.equals("yes"))
        {
          String clusterAdminEmail = "raghuram@bcm.edu";
          StringBuffer clusterSchedulerString = new StringBuffer("clusterJobScheduler.rb");
          String hostname = request.getServerName();
          // hostname:clusterOutputDir is the output directory for the cluster job to move files to from the temporary working directoryon the node after it is done executing
          clusterSchedulerString.append(" -o ").append(hostname).append(":").append(clusterOutputDir);
          // Who gets notified about cluster job status changes?
          clusterSchedulerString.append(" -e ").append(clusterAdminEmail);
          // Suitably modified 'main' command for the cluster job to execute on the node
          clusterSchedulerString.append(" -c ").append(Util.urlEncode(uploaderCmdLine.toString()));
          clusterSchedulerString.append(" -i ").append(hostname).append(":").append(inputFile);
          // Which resources will this job utilize on the node/ what type of node does it need?
          clusterSchedulerString.append(" -r "+GenboreeConfig.getConfigParam("clusterLFFUploadResourceFlag")+"=1");
          // Should the temporary working directory of the cluster job be retained on the node?
          if (GenboreeConfig.getConfigParam("retainClusterGBUploadDir").equals("true") || GenboreeConfig.getConfigParam("retainClusterGBUploadDir").equals("yes"))
          {
            clusterSchedulerString.append(" -k ");
          }
          // Create a resource identifier string for this job which can be used to track resource usage
          // Format is /REST/v1/grp/{grp}/db/{db}/annos
          String resourcePathString = "/REST/v1/grp/{grp}/db/{db}/annos";        
          HashMap<String, String> hashMap = new HashMap<String, String>();
          hashMap.put( "grp", grp.getGroupName() ); 
          hashMap.put( "db", RefSeqTable.getRefSeqNameByRefSeqId(refseqId, db) );
          clusterSchedulerString.append(" -p "+Util.urlEncode(RESTapiUtil.fillURIPattern(resourcePathString, hashMap)));
          RunExternalProcess rn = new RunExternalProcess(clusterSchedulerString.toString());
        }
        // else launch the process on the server machine
        else
        {
          System.err.println(uploaderCmdLine.toString());
          taskWrapper.append(Util.urlEncode(uploaderCmdLine.toString() )  ).append(" -e ").append(appendToEndOfTaskWrapper );
          RunExternalProcess rn = new RunExternalProcess(taskWrapper.toString());
        }
        theLastView = (String) mys.getAttribute("lastBrowserView");
        if (theLastView == null) {
          theLastView = "defaultGbrowser.jsp";
        }
//        GenboreeUtils.sendRedirect(request, response, redirectTo);


          
      /**----------------------------------
       * Done anootations LFF,Agilent,Blat,Blast,Pash import
       * --------------------------------- */
        


        
      }
      // For wig uploads, a ruby task wrapper is launched
      // Important: cluster code for this part is NOT tested
      // Most of the code is the similar as the java uploads, with the java task wrapper
      // replaced by the ruby taskwrapper (genbTaskWrapper.rb)
      else
      {
          


      /**----------------------------------
       * Start anootations WIG import
       * --------------------------------- */
      System.err.println("Start anootations WIG import");          
        
       
        uploaderCmdLineForImportTool.append(" -u ").append(userId).append(" -d ").append(refseqId);
        uploaderCmdLineForImportTool.append(" -g ").append(groupId).append(" --email ").append(GenboreeUtils.fetchUserEmail(userId, false)).append(" -i ");
        useClusterForGBUpload = GenboreeConfig.getConfigParam("useClusterForGBUpload");
        if (useClusterForGBUpload.equals("true") || useClusterForGBUpload.equals("yes"))
        {
          // InputFile will be local during cluster execution. Need containing dir. to use as output dir. after cluster run
          clusterOutputFile = inputFile.replaceFirst(".*/","");
          clusterOutputFile = "./"+clusterOutputFile;
          clusterOutputDir = inputFile.replaceFirst("[^/]*$","");          
          uploaderCmdLineForImportTool.append(clusterOutputFile);
          uploaderCmdLineForImportTool.append(" -j . ");
          uploaderCmdLineForImportTool.append(" -t ");
          String trackName = (String)extraOptions.get("type") + ":" + (String)extraOptions.get("subtype");
          uploaderCmdLineForImportTool.append(Util.urlEncode(trackName));
          redirectTo = "/java-bin/merger.jsp?fileName=" + fileToSaveData.getName();
          System.err.println( "55#$->The uploader command is \n" +  uploaderCmdLineForImportTool.toString() );
          uploaderCmdLineForImportTool.append(" 1>").append("./importWiggle.out ");
          uploaderCmdLineForImportTool.append("2>").append("./importWiggle.err");
        }
        else
        {
          uploaderCmdLineForImportTool.append(inputFile);
          uploaderCmdLineForImportTool.append(" -t ");
          String trackName = (String)extraOptions.get("type") + ":" + (String)extraOptions.get("subtype");
          uploaderCmdLineForImportTool.append(Util.urlEncode(trackName));
          redirectTo = "/java-bin/merger.jsp?fileName=" + fileToSaveData.getName();
          System.err.println( "55#$->The uploader command is \n" +  uploaderCmdLineForImportTool.toString() );
          uploaderCmdLineForImportTool.append(" 1>").append(dirToUse.getAbsolutePath()).append("/importWiggle.out ");
          uploaderCmdLineForImportTool.append("2>").append(dirToUse.getAbsolutePath()).append("/importWiggle.err");
        }
        if( DirectoryUtils.isDirectoryWrittable( dirToUse.getAbsolutePath() )  )
        {
          appendToEndOfTaskWrapper = " -e " + dirToUse.getAbsolutePath() + "/genbTaskWrapper.err" + " -o " + dirToUse.getAbsolutePath() + "/genbTaskWrapper.out";                                    
        }
        if (useClusterForGBUpload.equals("true") || useClusterForGBUpload.equals("yes"))
        {
          String clusterAdminEmail = "raghuram@bcm.edu";
          StringBuffer clusterSchedulerString = new StringBuffer("clusterJobScheduler.rb");
          String hostname = request.getServerName();
          clusterSchedulerString.append(" -o ").append(hostname).append(":").append(clusterOutputDir);
          clusterSchedulerString.append(" -e ").append(clusterAdminEmail);
          clusterSchedulerString.append(" -c ").append(Util.urlEncode(uploaderCmdLineForImportTool.toString()));
          clusterSchedulerString.append(" -i ").append(hostname).append(":").append(inputFile);
          //clusterSchedulerString.append(" -r gbUpload=1 -k ");
          clusterSchedulerString.append(" -r "+GenboreeConfig.getConfigParam("clusterLFFUploadResourceFlag")+"=1");
          if (GenboreeConfig.getConfigParam("retainClusterGBUploadDir").equals("true") || GenboreeConfig.getConfigParam("retainClusterGBUploadDir").equals("yes"))
          {
            clusterSchedulerString.append(" -k ");
          }
          // Create a resource identifier string for this job which can be used to track resource usage
          // Format is /REST/v1/grp/{grp}/db/{db}/annos
          String resourcePathString = "/REST/v1/grp/{grp}/db/{db}/annos";
          HashMap<String, String> hashMap = new HashMap<String, String>();
          hashMap.put( "grp", grp.getGroupName() ); 
          hashMap.put( "db", RefSeqTable.getRefSeqNameByRefSeqId(refseqId, db) );
          clusterSchedulerString.append(" -p "+Util.urlEncode(RESTapiUtil.fillURIPattern(resourcePathString, hashMap)));
          // Output files requiring special handling that need to be moved to a different place; the 'rest' of the output files go to the default output dir. The default output dir is specified
          // during creation of the cluster job object
          // All files that end in .bin should
          String srcrexp = "\\.bin$";
          //.be renamed to (nothing in this case)
          String destrexp = "";
          // and moved to a different output dir
          String destOutputDir = hostname + ":"+"/usr/local/brl/data/genboree/ridSequences/"+ refseqId+"/";
          //Create a comma separated utl escaped list as command line argument
          clusterSchedulerString.append(" -l "+ Util.urlEncode(srcrexp)+","+Util.urlEncode(destrexp)+","+Util.urlEncode(destOutputDir));
          
          RunExternalProcess rn = new RunExternalProcess(clusterSchedulerString.toString());
        }
        else
        {
          System.err.println(uploaderCmdLineForImportTool.toString());
          genbTaskWrapper.append(Util.urlEncode(uploaderCmdLineForImportTool.toString() )  );
          genbTaskWrapper.append(appendToEndOfTaskWrapper.toString());
          HashMap runCmdOut = CommandsUtils.runCommandaCollectInfo(genbTaskWrapper.toString(), dirToUse.getAbsolutePath().toString());
          System.err.println("run Command Output: " + runCmdOut);
        }
        theLastView = (String) mys.getAttribute("lastBrowserView");
        if (theLastView == null) {
          theLastView = "defaultGbrowser.jsp";
        }
        
        // GenboreeUtils.sendRedirect(request, response, redirectTo);
      }
    }

    String respStatus = "";
    String respMessage = "";
    
    // Respond to the request with some informative JSON.
    // This script originally redirected to merger.jsp.  This is now handled by the client.
    // What to use to determine the requests was successful?
    if(redirectTo != null) {  
     respStatus = "OK";
     respMessage = "File has been uploaded";
    } else {
     // projectName is null
     respStatus = "ERROR";
     respMessage = "An error has occured";  
    }    
        
    JSONObject json = new JSONObject();
    json.put("msg", respMessage);
    json.put("statusCode", respStatus);
    json.put("redirectTo", redirectTo);
    
    JSONObject respJson = new JSONObject();
    respJson.put("status", json);
    String output = respJson.toString();
%><%= output %>
