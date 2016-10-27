<%@ page import="org.genboree.dbaccess.GenboreeGroup,
java.util.*,
java.io.*,
org.genboree.upload.*,
org.genboree.upload.HttpPostInputStream,
org.genboree.upload.AnnotationUploader,
org.genboree.upload.DatabaseCreator,
org.genboree.upload.FastaEntrypointUploader,
org.genboree.message.GenboreeMessage,
org.genboree.samples.*,
java.util.regex.Pattern,
java.util.regex.Matcher,
java.text.SimpleDateFormat,
org.json.JSONObject,
org.genboree.tabular.LffUtility,
java.text.DateFormat,
java.text.ParseException"
%>
<%@ page import="org.genboree.tabular.LayoutHelper" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%@ include file="include/sessionGrp.incl" %>


<%
    HashMap displayOrder = new HashMap ();
    String orderedSortNames []= null;
    String []  orderedDisplayNames =  null;
	String displayArrow = "&nbsp;";
	String jsparams =  request.getParameter("jsparams");
    boolean sortingColumns = false;
	String sortingColumnName = request.getParameter("sortingColumnName");
	if (sortingColumnName != null) {
		//sortingColumnName = sortingColumnName.trim();
		sortingColumnName = Util.urlDecode(sortingColumnName);
		sortingColumnName = sortingColumnName.trim();
	}

	boolean ascendingSort = true;
	String sortingColumnOrder = request.getParameter("sortingColumnOrder");
	String sortingArrow = "&nbsp;";
	if (sortingColumnOrder != null && sortingColumnOrder.length() > 0) {
		if (sortingColumnOrder.equals("up")) {
			sortingArrow = "&uarr;";
				 ascendingSort = true;
		}
		else if (sortingColumnOrder.equals("down")) {
			sortingArrow = "&darr;";
			ascendingSort = false;

		}
		mys.setAttribute("sortingColumnOrder", sortingColumnOrder);
	}

	if (sortingColumnOrder != null && sortingColumnOrder.length() > 0) {
		sortingColumns = true;
	}




	if (jsparams != null && jsparams.length() >0) {
        JSONObject json = new JSONObject( jsparams ) ;
        if (json != null) {
            orderedDisplayNames = LffUtility.parseJson(json, "rearrange_list_1")  ;
            if ( orderedDisplayNames != null &&  orderedDisplayNames.length >0)
            mys.setAttribute("displayNames", orderedDisplayNames);

            if (orderedDisplayNames != null)
            for (int j=0; j<orderedDisplayNames.length ; j++) {
				orderedDisplayNames[j] = Util.urlDecode(orderedDisplayNames[j]);
				displayOrder.put(orderedDisplayNames[j], "" + j);
			//	out.println("<br>in hash " + j + "  " + orderedDisplayNames[j]+ "  length " +orderedDisplayNames[j].length());
			}
			mys.setAttribute("displayNameOrder", displayOrder);
		}

        orderedSortNames = LffUtility.parseJson(json, "rearrange_list2");
        if (orderedSortNames != null) {
            int index = -1;
            for (int j=0; j<orderedSortNames.length; j++) {
            orderedSortNames [j] = Util.urlDecode(orderedSortNames[j]);
            index = orderedSortNames[j].indexOf("_sort");
            if (index >0)
            orderedSortNames[j] = orderedSortNames[j].substring(0, index);
             }
        }

        mys.setAttribute("orderedDisplayNames", orderedDisplayNames);
        mys.setAttribute("orderedSortNames", orderedSortNames);
     }
    else{
        orderedDisplayNames = (String[])mys.getAttribute("orderedDisplayNames");
        orderedSortNames = (String[])mys.getAttribute("orderedSortNames");
     }


    if (orderedDisplayNames == null || orderedDisplayNames.length ==0)
      GenboreeMessage.setErrMsg(mys, " There is no sample for display.");

     //   out.println("<br> num  display names  names " + orderedDisplayNames.length);
    if(userInfo[0].equals("admin")){
        myGrpAccess = "ADMINISTRATOR";
        i_am_owner = true;
        isAdmin = true;
    }

	int totalNumSamples = 0;
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    GenboreeMessage.clearMessage(mys);
    String numString = "0";

    int i=0;
    int mode = -1;
    Refseq rseq = null;

    Sample [] samples = null;
    String [] attributeNames  = null;
    Sample[] totalSamples = null;
    if ( request.getParameter("navigator") != null && request.getParameter("download") == null ) {
    mode = SampleConstants.VIEW;
    }

    if (request.getParameter("btnBack") != null)
       GenboreeUtils.sendRedirect(request, response, "java-bin/mySamples.jsp?mode=View/Download");

    if (rseqs== null || rseqs.length==0 && mode >=0)
    	GenboreeMessage.setErrMsg(mys, "Sorry, there is no database in this group. <br> -- Please create a database and try again.");
    %>
    <%@ include file="include/sampleInit.incl" %>
    <%
		if (rseqs != null && rseqs.length >0) {
		rseq = rseqs[0];
		if (rseq_id != null && !rseq_id.equals("")) {
		for ( i=0; i<rseqs.length; i++) {
		if (rseqs[i].getRefSeqId().equals(rseq_id))
		rseq = rseqs[i];
		}
    }
    else {
    	rseq = null;
    }

    if ( grpChangeState!= null && grpChangeState.compareTo("1") ==0 ) {
    rseq = null;
    }

    if ( sessionCleared) {
         GenboreeUtils.sendRedirect(request, response, "java-bin/mySamples.jsp?mode=View/Download");
    }

    String dbName = null;
    Connection con = null;

    if (rseq != null) {
    dbName =  rseq.getDatabaseName();


    con = db.getConnection(dbName);
    }

    String selectAtt = "";
    if( rseq != null) {
         // get all attribute names
        attributeNames = SampleRetriever.retrievesAllAttributeNames(con);
        totalNumSamples =    SampleRetriever.countAllSamples(con);
        numString = "" + totalNumSamples;
        numString = Util.putCommas(numString);
        if (attributeNames != null)
        Arrays.sort(attributeNames);
       if (attributeNames == null ||attributeNames.length ==0)
        GenboreeMessage.setErrMsg(mys, "There is no sample data to display." );


        if ( request.getParameter("currentPage")!= null) {
        currentPage = request.getParameter("currentPage");
        }


        if (jsparams != null )
        initPage = true;

			if ( initPage) {
            // now , dispaly names is what user selected
            if ( orderedDisplayNames == null) {
                GenboreeMessage.setErrMsg(mys, "There is no attribute selected for sample display. ");

            }
            else {
				mys.setAttribute("orderedDisplayNames", orderedDisplayNames);
				int order =0;
				HashMap displayOrder2Name = new HashMap ();
				String jsQuotedName = null;
				for (i=0; i<orderedDisplayNames.length; i++){
				order = i + 1;
				jsQuotedName  = Util.simpleJsQuote(orderedDisplayNames[i]);
				selectAtt +=  "'" +   jsQuotedName  + "', ";
				displayOrder2Name.put("" + order, orderedDisplayNames[i]);
				}
				selectAtt = selectAtt.substring(0, selectAtt.length() -2);
				totalSamples =  SampleRetriever.retrieveAllSamples (con, false, selectAtt,  displayOrder2Name);
			      }

            if (orderedSortNames != null && orderedSortNames.length >0) {
				int [] attributeIndexes = new int [orderedSortNames.length];
				int attributeIndex= -1;
				//find indexes of the selected attributes
				int count =0;
				for (int j=0; j< orderedSortNames.length; j++) {
					String attIndex  = (String)displayOrder.get((orderedSortNames[j]));
					if ( attIndex != null)
					attributeIndex = Integer.parseInt( attIndex );
					attributeIndexes[count] = attributeIndex;
					count++;
				}
				mys.setAttribute("attributeIndexArr", attributeIndexes);

				try {
					totalSamples =SampleSorter.sortAllSamples(out, orderedSortNames, attributeIndexes,  totalSamples, displayOrder, ascendingSort);
				 //  totalSamples =SampleSorter.sortAllSamples(orderedSortNames, attributeIndexes,  totalSamples, displayOrder);
				}
				catch (SampleException e) {
				//   out.println("<br>Error happened in sample sorting: " + e.getMessage());
				e.printStackTrace();
				db.reportError(e, "Error in sorting samples ");
				}
			}

				mys.setAttribute("totalSamples", totalSamples);

        }
        else {

			totalSamples = (Sample [] )mys.getAttribute("totalSamples");

			orderedDisplayNames = (String [])mys.getAttribute("orderedDisplayNames");
        }


			if (sortingColumns){
			displayOrder = (HashMap)mys.getAttribute("displayNameOrder");
			initPage = true;

			if (sortingColumnName != null && !sortingColumnName.equals("sampleName") ) {
					String attIndex  = (String)displayOrder.get(sortingColumnName);
				int index = -1;
				 if (attIndex != null)  {
					 try {
					 index = Integer.parseInt(attIndex);
					 }
					 catch (Exception e) {
						 GenboreeMessage.setErrMsg(mys, " att index  " + attIndex + " is not a number ." );
					 }
				 }
				 else
				   GenboreeMessage.setErrMsg(mys, " index for attribute " + sortingColumnName + " is null." );
					try {
				totalSamples =SampleSorter.sortAllSamplesByColumn(out, sortingColumnName,  index,  totalSamples, displayOrder, ascendingSort);
				}
				catch (Exception e) {
				   //  out.println("<br> error in ln   307 sorting name  "  + sortingColumnName + "  att index   " + index +" samples " +   totalSamples + "<br> hash order " +  displayOrder + "<br>" )	;
						 // System.err.println(" AN error  has happened in SampleSorter.sortAllSamples().  " ) ;
			    e.printStackTrace()  ;
			     return;
					}
			}
		else {
				try {
				totalSamples =SampleSorter.sortSamplesByName(totalSamples,ascendingSort );
				}
				catch (Exception e) {
				//	 out.println("<br> error in ln   317 " )	;
					System.err.println(" AN error  has happened in SampleSorter.sortAllSamples().  " ) ;
						}
			}
		}
	}

  String pressed = null;
%>
<%@ include file="include/sampleMP.incl" %>
<%
    }

		if (sortingColumnName== null)
		sortingColumnName = "";

	String headArrow = "&nbsp;";

	if (sortingColumnName != null && sortingColumnName.equals("sampleName"))
		headArrow = sortingArrow;
	else
	   headArrow = "&nbsp;";


		///String ensortingColumnName = sortingColumnName;
%>
<!--!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN""http://www.w3.org/TR/REC-html40/loose.dtd"-->
<HTML>
<head>
<title><%=" My Samples "%></title>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css" >
<link rel="stylesheet" href="/genboree/toolPlugins/nameSelector/nameSelector.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/sortableLists.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/samples.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
	<script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/prototype.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
<script src="/javaScripts/scriptaculous.js<%=jsVersion%>" type="text/javascript"></script>
<script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script> <!-- Stuff here used in rest of files... -->
<script type="text/javascript" src="/javaScripts/extjs/package/genboree/ext-msgbox-only-pkg.js<%=jsVersion%>"></script>
  <!-- Set a local "blank" image file; default is a URL to extjs.com -->
  <script type='text/javascript'>
    Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
  </script>
<SCRIPT type="text/javascript" src="/javaScripts/toolPlugins/toolPluginsWrapper.js<%=jsVersion%>"></SCRIPT>
<link rel="stylesheet" href="/styles/sortableLists.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/genboree/toolPlugins/nameSelector/nameSelector

.css<%=jsVersion%>" type="text/css">
<SCRIPT type="text/javascript" src="/javaScripts/toolPlugins/toolPluginsWrapper.js<%=jsVersion%>"></SCRIPT>
<script type="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/util.js<%=jsVersion%>"></script>
<script type="text/javascript" src="/javaScripts/json.js<%=jsVersion%>"></script>
<SCRIPT type="text/javascript" src="/javaScripts/commonFunctions.js<%=jsVersion%>"></SCRIPT>
<script type="text/javascript" SRC="/javaScripts/editorCommon.js<%=jsVersion%>"></script>
<script type="text/javascript" SRC="/javaScripts/columnSorting.js<%=jsVersion%>"></script>
	<SCRIPT type="text/javascript" src="/javaScripts/sample.js<%=jsVersion%>"></SCRIPT>
<script type="text/javascript" src="/genboree/toolPlugins/nameSelector/nameSelector.js<%=jsVersion%>"></script>
<script>
var sortingArrow ='<%=sortingColumnOrder%>';
var displayNames = new Array();


var ii=0;
var numAtt = <%=orderedDisplayNames.length %>;


<%	for (int ii =0; ii<orderedDisplayNames.length;  ii++)  {
       String tempName = Util.urlEncode(orderedDisplayNames[ii]);
    %>
	   displayNames [<%=ii%>] = '<%=tempName%>';
	  <%}%>
</script>
</head>
<BODY  onload=""  >
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>
</td>
<td width="10"></td>
<td class="shadow"></td></TR>
<TR><td></td><td>
<%@ include file="include/message.incl" %>
<form name="viewForm" id="viewForm" action="viewSamples.jsp" method="post" >
    <input type="hidden" name="currentMode"  id="currentMode" value="<%=mode%>">
	<input type="hidden" name="sortingColumnName"  id="sortingColumnName" value="<%=sortingColumnName%>">
	<input type="hidden" name="sortingColumnOrder"  id="sortingColumnOrder">
		<table border="0" cellpadding="4" cellspacing="2" width="100%">
            <%  if( rwGrps.length == 1 ) { %>
            <TR> <td width="20%"></td><td></td></TR>
            <TR>
            <td class="form_header"><strong>Group</strong></td>
            <input type="hidden" name="group_id" id="group_id" value="<%=groupId%>">
            <td class="form_header">
            <%=Util.htmlQuote(grp.getGroupName())%>
            &nbsp;&nbsp;<font color="#CCCCFF">Role:</font>&nbsp;&nbsp;<%=myGrpAccess%></td></TR>
            <%}
            else { %>
            <TR><%@ include file="include/groupbar.incl"%></TR>
                <% }%>
            <TR><%@ include  file="include/databaseBar.incl" %></TR>
        </table>
            <table width="100%"   style="margin-bottom:5px;" border="1" cellpadding="2" cellspacing="1">
            <%@ include file="include/mpSample_pageIndex.incl"%>
            </table>
</td>
<td width=10></td>
<td class="shadow"></td>
</tr>

<tr>
<td width=10 class="bkgd"></td>
<td height=10 class="shadow"></td>
<td width=10 class="shadow"></td>
<td width=10 class="shadow"></td>
</tr>
</table>
<table width="700" border="1" cellpadding="1" cellspacing="1" page-break-after="avoid" style="margin-bottom:0px; margin-top:10px;" >
<TR align="center" >
<TD class="form_header"> <b>(Total of <%=numString%>&nbsp;samples)</B> </td>
</TR>
</table>
<%if (rseq != null&& orderedDisplayNames != null) {%>
    <input type="hidden" name="currentPage" id="currentPage" value="<%=currentPage%>">
    <input type="hidden" name="navigator" id="navigator" value="">
    <table width="100%"  id="sampleView" page-break-before="avoid" style="margin-top:0px; margin-bottom:10px;"  class="sortable" border="1" cellpadding="1" cellspacing="1">
        <!--table  id="sampleView"   border="1" cellpadding="1" cellspacing="1" width="100%"-->
        <TR>
		   <td class="form_header"  name="sampleName" id="sampleName"  align="center"  onclick="sortingSampleName(<%=orderedDisplayNames.length%>); ">
			<nobr>
		   <a href="#" class="sortheader">
			  <font color="white">&nbsp;Sample&nbsp;</font></a>
			<span id="span_sampleName" class="sortarrow"><%=headArrow%> </span>
			</nobr>
	    </td>
		<%
			String displayName = null;
			for (i=0; i<orderedDisplayNames.length; i++) {
        		displayName =  orderedDisplayNames[i];
				if (displayName != null){
					if (sortingColumnName != null && displayName.equals(sortingColumnName) ) {
					  displayArrow = sortingArrow;

					}
					else {
						  displayArrow = "&nbsp;";

					}
					//displayName = displayName.trim();
					//displayName = displayName.replaceAll(" ", "&nbsp;" );
				}
				//String encodedString =  Util.urlEncode(displayName);
		%>
		<td class="form_header"  name="name_<%=i%>" id="id_<%=i%>"  align="center"  value="<%=displayName%>" onclick="sortingByColumn(<%=i%>, <%=orderedDisplayNames.length%>, '<%=displayName%>'); ">
			<nobr>
		   <a href="#" class="sortheader">
			<font color="white"><%=displayName%></font></a>
			<span id="span_<%=i%>" class="sortarrow"><%=displayArrow%> </span>
			</nobr>
			</td>
		<%}%>
        </TR>
        <% if (samples != null)  {
        for ( i=0; i<samples.length; i++) {
        Sample sample = samples [i];
        if (sample == null){
        continue;
        }
        String sampleName = sample.getSampleName();
        if (sampleName != null)
        sampleName = sampleName.trim();
            String tdClass = "form_body3";
               if (sampleName.length() >= 50  )
                tdClass = "form_body2";
        %>
        <TR>
		<% if (sampleName != null) {
		sampleName = sampleName.trim(); %>
		<TD class="<%=tdClass%>"><%="&nbsp;" + sampleName%></TD>
		<%}
		else { %>
		<TD  class="form_body2">&nbsp</TD>
		<%
		}
			Attribute[] attributes = sample.getAttributes();
			if (attributes!= null) {
			for (int j=0; j<attributes.length; j++)  {
			Attribute attribute = attributes[j];
			tdClass = "form_body3";
			if (attribute != null && attribute.getAttributeValue() != null) {
			String attributeName = attribute.getAttributeValue().trim();
			if (attributeName.length() >= 50)
			tdClass = "form_body2";
				%>
		<TD align="center" class="<%=tdClass%>">
		<%="&nbsp;"+ attributeName%></td>
		<%	}
		else { %>
		<TD align="center" class="form_body2">
		<%="&nbsp;"%>
		<%}%>
		</TD>
        <%}}%>
        </TR>
        <% }} %>
    </table>
       <% }%>
     <table cellpadding="0" cellspacing="0" border="0" bgcolor="white" width="700" class='TOP'>
        <tr>
            <td width="10"></td>
            <td height="10"></td>
            <td width="10"></td>
            <td width="10" class="bkgd"></td>
        </TR>
        <TR>
        <td width="10"></td>
        <td height="10">
        <table>
            <TR>
                <TD>
                <div id="viewbk"  align="left" style="display:block; margin-left: 30px;">
                <input type="submit" name="btnBack" value="Back"  class="btn" style="WIDTH:100">&nbsp;&nbsp
                </div>
                <BR>
                </TD>
            </TR>
        </table>
        <%
            if (rseq != null && orderedDisplayNames != null) {%>
            <table width="100%"  border="1" cellpadding="0" cellspacing="1">
            <tr><td>
            <%@ include file="include/mpSample_pageIndexBottom.incl"%>
            </td></tr></table>
            <%}%>
        </form>
            <%@ include file="include/footer.incl" %>
</BODY>
</HTML>
