<%@ page import="java.util.*, java.io.*, javax.servlet.http.*,
	org.genboree.dbaccess.*, org.genboree.gdasaccess.*,
	org.genboree.upload.*, org.genboree.util.*, javax.servlet.*,
	java.sql.*, java.lang.*" %>

<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>

<HTML>
<HEAD>

<title>Genboree - Track Operations Help</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>

</HEAD>

<BODY bgcolor="#DDE0FF">



<%@ include file="include/header.incl" %>

<table cellpadding="0" cellspacing="0" border="0" width="100%">
<tr>
	<td valign="top" align="left">
		<br>
		<h3>Track Operations Help Page</h3>
		<dl compact>
		<a name="Combine"><dt>Combine</dt></a>
			<dd> Given a list of track names, it outputs a single track that is the
			combination of all the listed tracks. <br>
			<br> Track names follow this convention, as displayed in Genboree: <br>
			<br> &nbsp;&nbsp;&nbsp;&nbsp;Type:SubType <br>
			<br> That is to say, the track Type and its Subtype are separated by a colon, to
			form the track name. </dd><p>
		<a name="Intersect"><dt>Intersect</dt></a>
			<dd> Given two opeand tracks, it outputs annotations from the first
			operand that overlap with at least one annotation from the second operand
			track. <br>
			<br> Actually, it is a bit more general in that it support &quot;multple&quot;
			second operand tracks, so you can have it output annotations from the first
			operand track that overlap with an annotation from &quot;any/all&quot; of the
			other operand tracks.  It saves a bit of time and is more useful for certain
			use cases (eg, my ESTs that intersect with ESTs from any one of various cancer
			libraries).  This is OPTIONAL. <br>
			<br> You can even provide a radius--this is a fixed number of base pairs that
			will be added to the ends of your records in the first operand track when
			determining the intersection.  This allows smaller ('point mapping') to be
			treated as bigger than they are.  Good for treating PGI indices as BACs or
			something. <br>
			<br> Track names follow this convention, as displayed in Genboree: <br>
			<br> &nbsp;&nbsp;&nbsp;&nbsp;Type:SubType <br>
			<br> That is to say, the track Type and its Subtype are separated by a colon, to
			form the track name. </dd><p>
		<a name="Non-Intersect"><dt>Non-Intersect</dt></a>
			<dd> Given two opeand tracks, it outputs annotations from the first
			operand that do not overlap with annotations from the second operand
			track. <br>
			<br> Actually, it is a bit more general in that it support &quot;multple&quot;
			second operand tracks, so you can have it output annotations from the first
			operand track that do not overlap with an annotation from &quot;any/all&quot; of the
			other operand tracks.  It saves a bit of time and is more useful for certain
			use cases (eg, my ESTs that do not intersect with ESTs from any one of various cancer
			libraries).  This is OPTIONAL. <br>
			<br> You can even provide a radius--this is a fixed number of base pairs that
			will be added to the ends of your records in the first operand track when
			determining the intersection for rejection.  This allows smaller ('point mapping') to be
			treated as bigger than they are.  Good for treating PGI indices as BACs or
			something. <br>
			<br> Track names follow this convention, as displayed in Genboree: <br>
			<br> &nbsp;&nbsp;&nbsp;&nbsp;Type:SubType <br>
			<br> That is to say, the track Type and its Subtype are separated by a colon, to
			form the track name. </dd><p>
		</dl>
	</td>	
</tr>
</table>		

<%@ include file="include/footer.incl" %>

</BODY>

</HTML>
