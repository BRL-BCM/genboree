<%@ page import="javax.servlet.http.*,
 java.io.*, java.util.*, java.net.*,
 org.genboree.dbaccess.*, org.genboree.util.*, 
 org.genboree.upload.*, org.genboree.gdasaccess.*, 
 java.lang.*, java.sql.ResultSet,
                 java.text.SimpleDateFormat" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%



    String refSeqId = (String)mys.getAttribute( "refSeqId" );
    String msgUrl = null;
    String entryPoint = null;
    String EPend = null;
    Refseq rseq = null;
    boolean showGB = true;
    boolean refSeqAreTheSame = false;
   	String mylastBrowser = null;

    mylastBrowser = (String) mys.getAttribute( "lastBrowserView" );
	if( mylastBrowser == null ) mylastBrowser = "defaultGbrowser.jsp";


    String oldRefSeqId = (String)mys.getAttribute( "editRefSeqId" );
    if(refSeqId != null)
        System.err.println("The refSeqId is " + refSeqId);
    else
        System.err.println("The refSeqId is null");

    if(oldRefSeqId != null)
        System.err.println("The oldRefSeqId is " + oldRefSeqId);
    else
        System.err.println("The oldRefSeqId is null");

    System.err.flush();

    if(oldRefSeqId != null && refSeqId != null)
    {
        if(oldRefSeqId.equalsIgnoreCase(refSeqId))
            refSeqAreTheSame = true;
    }



    if(refSeqAreTheSame){
        msgUrl = (String)mys.getAttribute( "msg_url");
            System.err.println("The refSEqsAreEqual and the msgUrl is " + msgUrl);

    }

    System.err.flush();

    if(refSeqId != null)
    {
        rseq = new Refseq();
	    rseq.setRefSeqId( refSeqId );
	    rseq.fetch( db );
    }


    if( rseq != null && !refSeqAreTheSame)
    {
        RefseqTemplate.EntryPoint[] eps = RefseqTemplate.getRefseqEntryPoints( rseq, db );
        entryPoint = eps[0].fref;
        EPend = "" + (eps[0].len/4);
    }




    if(entryPoint == null && rseq != null && msgUrl == null)
    {
        String databaseName = rseq.getDatabaseName();
        String query = "SELECT refname, rlength FROM fref order by rid";
        DbResourceSet dbRes =  db.executeQuery(databaseName, query);
        ResultSet rs = dbRes.resultSet;

        if( rs != null && rs.next() )
        {
            entryPoint =  rs.getString(1);
            int chrSize = rs.getInt(2);
            if(chrSize > 4)
                EPend = "" + (chrSize/4);
        }
        dbRes.close();
    }

    if(rseq == null)
        showGB = false;



    File workFile = (File) mys.getAttribute( "workFile" );
    File outputFile = (File) mys.getAttribute( "outputFile" );
    String workLFFFileName = workFile.getName();
    String outputLFFFileName = outputFile.getName();
%>

<HTML>
<head>
<title>Genboree - LFF Operation Complete</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>

<p><strong><%=myself.getFullName()%></strong>,</p>
<p>your data has been submitted for the LFF operation.</p>

<p>Since the <i><%=(String)mys.getAttribute( "currentMode" )%> track operation</i> may take a while (depending on the size
of your data file), we will send you a confirmation e-mail when it is complete.</p>

<p>If you do not receive such an e-mail within 48 hours, please feel free to
contact our administrator.</p>

<p>When contacting us, please be sure to include the following
information about your data transaction:</p>

<p>
<i>Login Name:</i>&nbsp;<%=Util.htmlQuote(myself.getName())%><br>
<i>Temporary work *.lff File: </i>&nbsp;<%=workLFFFileName%><br>
<i>Output *.lff File: </i>&nbsp;<%=outputLFFFileName%><br>
<i>Date:</i>&nbsp;<%=Util.htmlQuote((new Date()).toString())%><br>
</p>

<br>
<p align="center">
<a href="<%=mylastBrowser%>"><img src="/images/goBackToBrowser.gif" width="134" height="24"></a>&nbsp&nbsp
<a href="trackOps.jsp"><img src="/images/createMoreTracks.gif" width="125" height="24"></a></p>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
