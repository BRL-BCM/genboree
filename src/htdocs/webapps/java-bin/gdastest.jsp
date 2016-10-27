<%@ page import="javax.servlet.http.*,
 java.io.*, java.sql.*, java.util.*,
 org.genboree.dbaccess.*, org.genboree.gdas.*,
 org.genboree.util.*, org.genboree.upload.*" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/common.incl" %>
<%!
	static final File tgtDir =
		new File( System.getProperty("catalina.home","/www/htdocs/"), "graphics" );
%>
<%
// genboree_r_3e71f3fa87b41a668f194fd7df513712
// genboree_r_2508cce3183b21c68621a84c72e50f76
// segment=chr3:1,199411731

	int i;

/*
	String dbNames[] = new String[1];
	dbNames[0] = "genboree_6f18eca7f5c805cf3cf4bc6223a6f476";
	String fref = "Hs1-b15";
	String from = "95101949";
	String to = "150101949";
*/

	String[] dbNames = new String[2];
	dbNames[0] = "genboree_r_3e71f3fa87b41a668f194fd7df513712";
	dbNames[1] = "genboree_r_2508cce3183b21c68621a84c72e50f76";
	String fref = "chr3";
	String from = "1";
	String to = "199411731";
	
	Properties parms = new Properties();
	parms.setProperty( "useUnicode", "false" );
//	parms.setProperty( "useCompression", "true" );
	
	for( i=0; i<dbNames.length; i++ )
	{
		Connection conn = db.getConnection( dbNames[i] );
		if( conn != null ) conn.close();
		conn = db.getConnection( dbNames[i], true, parms );
	}

	java.util.Date startDate0 = new java.util.Date();
	
	MultiFeatureFetcher ff = new MultiFeatureFetcher( dbNames, fref, from, to );
	ff.addFilter( "NOT (fg.gname like '%_GV')" );
	ff.addFilter( "NOT (fg.gname like '%_CV')" );
	ff.fetch();
	
	java.util.Date stopDate0 = new java.util.Date();
	long timeDiff0 = (stopDate0.getTime() - startDate0.getTime()) / 100;
%>

<HTML>
<head>
<title>Genboree - Gdastest</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">

<PRE>
<%
	long cnt = 0L;
	java.util.Date startDate = new java.util.Date();

/*
	FileOutputStream fos = new FileOutputStream( new File(tgtDir,"features.xml") );
	PrintStream fout = new PrintStream( fos );
*/

	Process pr = Runtime.getRuntime().exec( "/www/htdocs/counter" );
	OutputStream pr_os = pr.getOutputStream();
	PrintStream f_out = new PrintStream( pr_os );


	StringWriter fsw = new StringWriter();
	PrintWriter fout = new PrintWriter( fsw, true );

/*
    fout.println( "<?xml version=\"1.0\" standalone=\"yes\"?>" );
    fout.println( "<!DOCTYPE DASGFF SYSTEM \"http://www.genboree.org/dtd/dasgff.dtd\">" );
    fout.println( "<DASGFF>" );
    fout.println( "<GFF version=\"1.01\" href=\"http://www.genboree.org/\">" );
    fout.println( "<SEGMENT id=\""+fref+"\" start=\""+from+"\" stop=\""+to+"\" version=\"1.0\">" );
*/

	while( ff.next() )
	{
		cnt++;
		
// simple printing		

		fout.println( ff.gclass+"\t"+ff.gname+"\t"+ff.fid+"\t"+ff.fmethod+"\t"+ff.fsource+"\t"+
		ff.fstart+"\t"+ff.fstop+"\t"+ff.fscore+"\t"+ff.fstrand+"\t"+ff.fphase );
        if( ff.l_ftarget_start > 0 && ff.l_ftarget_stop > 0 )
        {
            fout.println( "~target\t"+ff.fref+"\t"+ff.ftarget_start+"\t"+ff.ftarget_stop );
        }
        for( i=0; i<ff.numLinks; i++ )
        {
            fout.println( "~link\t"+ff.linkUrls[i]+"\t"+ff.linkNames[i] );
        }
        if( ff.l_gid > 0 )
        {
            fout.println( "~groupId\t"+ff.groupId+"\t"+ff.gname );
        }
		
		

// XML printing
/*	
        fout.println( "<FEATURE id=\""+ff.gclass+":"+ff.gname+"/"+ff.fid+"\" label=\""+ff.gclass+"\">" );
        fout.println( "<TYPE id=\""+ff.fmethod+":"+ff.fsource+"\" category=\"miscellaneous\">"+ff.fmethod+":"+ff.fsource+"</TYPE>" );
        fout.println( "<METHOD id=\""+ff.fmethod+"\">  "+ff.fmethod+"</METHOD>" );
        fout.println( "<START>"+ff.fstart+"</START>" );
        fout.println( "<END>"+ff.fstop+"</END>" );
        fout.println( "<SCORE>"+ff.fscore+"</SCORE>" );
        fout.println( "<ORIENTATION>"+ff.fstrand+"</ORIENTATION>" );
        String sPhase = (ff.fphase.trim().length()>0) ? ff.fphase : "0";
        fout.println( "<PHASE>"+sPhase+"</PHASE>" );
        if( ff.l_ftarget_start > 0 && ff.l_ftarget_stop > 0 )
        {
            fout.println( "<TARGET id=\""+ff.fref+"\" start=\""+ff.ftarget_start+"\" stop=\""+ff.ftarget_stop+"\" />" );
        }
        for( i=0; i<ff.numLinks; i++ )
        {
            fout.println( "<LINK href=\""+ff.linkUrls[i]+"\">"+ff.linkNames[i]+"</LINK>" );
        }
        if( ff.l_gid > 0 )
        {
            fout.println( "<GROUP id=\""+ff.groupId+"\" type=\""+ff.gname+"\"></GROUP>" );
        }
        fout.println( "</FEATURE>" );
*/

		if( fsw.getBuffer().length() >= 0x10000 )
		{
			f_out.print( fsw.getBuffer().toString() );
			fsw = new StringWriter();
			fout = new PrintWriter( fsw, true );
		}
		
//		out.println( ff.fmethod+"\t"+ff.fsource+"\t"+ff.gid+"\t"+ff.fstart+"\t"+ff.groupId );
//		int lnkCnt = ff.numLinks;
//		for( i=0; i<lnkCnt; i++ )
//			out.println( "\tLink\t"+ff.linkNames[i]+"\t"+ff.linkUrls[i] );
	}

/*
    fout.println( "</SEGMENT>" );
    fout.println( "<UNKNOWNSEGMENT id=\""+ff.groupId+"\">" );
    fout.println( "</UNKNOWNSEGMENT>" );
    fout.println( "</GFF>" );
    fout.println( "</DASGFF>" );
*/
	
	fout.print( "\032" );
	
	f_out.print( fsw.getBuffer().toString() );
	

	java.util.Date stopDate = new java.util.Date();
	long timeDiff = (stopDate.getTime() - startDate.getTime()) / 100;
	out.println( "Query: "+(timeDiff0/10)+"."+(timeDiff0%10)+"s; "+
	cnt+" recs in "+(timeDiff/10)+"."+(timeDiff%10)+"s" );
%>
</PRE>

</BODY>
</HTML>
