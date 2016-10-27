<%@ page import="javax.servlet.http.*" %>
<%@ include file="include/fwdurl.incl" %>

<%!
	// static properties defined here

	// mode IDs
	static String[] modeIds =
	{
		"Combine", "Intersect", "Non-Intersect"
	};

	static final int MODE_DEFAULT = -1;
	static final int MODE_COMBINE = 0;
	static final int MODE_INTERSECT = 1;
	static final int MODE_NONINTERSECT = 2;

	// condition IDs
	static String[] condIds =
	{
		"Any", "All"
	};

	static final int COND_ANY = 0;
	static final int COND_ALL = 1;
%>
<%
	String errorMsg = "FATAL";

	HttpSession mys = request.getSession();

	String database = (String) mys.getAttribute( "database" );
	String pMode = (String) mys.getAttribute( "mode" );
	String pCond = null;
	String [] combineTrack = null;
	String firstTrack = null;
	String [] secondTrack = null;
 
	int mode = MODE_DEFAULT;
	int cond = COND_ANY;

	// determine mode
	for ( int i = 0; i < modeIds.length; i++ )
	{
		if ( modeIds[i].equals( pMode ) )
		{
			mode = i;
			break;
		}
	}

	// fetch appropriate track information
	switch( mode )
	{
		case MODE_COMBINE:
			combineTrack = (String []) mys.getAttribute( "combineTrack" );
			break;
		case MODE_INTERSECT:
		case MODE_NONINTERSECT:
			firstTrack = (String) mys.getAttribute( "firstTrack" );
			secondTrack = (String []) mys.getAttribute( "secondTrack" );
			pCond = (String) mys.getAttribute( "condition" );

			// determine condition
			for ( int i = 0; i < condIds.length; i++ )
			{
				if ( condIds[i].equals( pCond ) )
				{
					cond = i;
					break;
				}		
			}
			break;
	};    
%>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>Genboree - Error!!!</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<body bgcolor="#DDE0FF">

<%@ include file="include/header.incl" %>

<font color=red>
An internal exception <%=errorMsg%> has occured. Please report the following problems
  to the <a href="mailto:<%=GenboreeConfig.getConfigParam("gbAdminEmail")%>">system administrator</a>.<br>


</font>

<br>The error details are as follows:<br><br>
<!--<font face="Courier New" size=1>  -->
	&nbsp;&nbsp;&nbsp;<i>Page:</i> trackOps.jsp<br>
	&nbsp;&nbsp;&nbsp;<i>Database:</i> <%=database%><br>
	&nbsp;&nbsp;&nbsp;<i>Operation:</i> <%=modeIds[mode]%><br>
<%
	switch ( mode ) {
		case MODE_COMBINE:
%>
			&nbsp;&nbsp;&nbsp;<i>Select Tracks:</i><br>
<%
			for ( int i = 0; i < combineTrack.length; i++ ) {
%>
				&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<%=combineTrack[i]%><br>
<%
			}
			break;
		case MODE_INTERSECT:
		case MODE_NONINTERSECT:
%>
			&nbsp;&nbsp;&nbsp;<i>Condition:</i> <%=condIds[cond]%><br>
			&nbsp;&nbsp;&nbsp;<i>First Track:</i> <%=firstTrack%><br>
			&nbsp;&nbsp;&nbsp;<i>Second Track(s):</i><br>
<%
			for ( int i = 0; i < secondTrack.length; i++ ) {
%>
				&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<%=secondTrack[i]%><br>
<%
			}
			break;
	};
%>
<br>We apologize for any inconvenience this may cause to you.<br>

<!--</font>-->


<form action="trackOps.jsp" method="post">
    <input type="submit" name="Retry" value="Back" class="btn" style="width:100">
</form>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
