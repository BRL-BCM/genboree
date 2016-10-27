<%@ page import="org.genboree.util.Util,
org.genboree.util.Constants,
org.genboree.dbaccess.GenboreeGroup,
java.util.ArrayList,
java.util.Arrays,
java.util.HashMap"%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/userinfo.incl" %>
<%!

// NUM ATTRIBUTES (from database)
// - to be retrived from database
// - add static LFF fields as well
public static final int numAttributes = 30;

%>
<%  
    String selectedAttribute = "";
    String selectedDatatypes = "";
    String selectedOperation ="";
    String [] attributes = new String [numAttributes];
    ArrayList attributelist = new ArrayList (); 
    
    // ATTRIBUTES (from database)
    // - to be retrived from database
    // - add static LFF fields as well
    for(int i=0; i<numAttributes; i++)
    {
      attributes[i] = "attribute" + i;
      attributelist.add(attributes[i]); 
    }
    String myCurrentIndex = "-1";
%>
<html>
<head><title>query tool</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
<link rel="stylesheet" href="/styles/querytool.css<%=jsVersion%>" type="text/css">
<script src="/javaScripts/prototype.js<%=jsVersion%>" type="text/javascript"></script>
<script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
<script src="/javaScripts/json.js<%=jsVersion%>" type="text/javascript"></script>
<script src="/javaScripts/querytool.js<%=jsVersion%>" type="text/javascript"></script>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<body onload="resetQueryUI()" >
<%@ include file="include/header.incl" %>

<!-- LIST OF ATTRIBUTES IN JAVASCRIPT, available globally on page -->
<script type="text/javascript">
  attributeList = new Array() ;
  attributeServerList = new Array() ;
<%
    Arrays.sort(attributes) ;
    for(int ii=numAttributes-1; ii>=0; ii--)
    {
%>  
      attributeList.push("<%=attributes[ii]%>") ;
      attributeServerList.push("<%=ii%>_<%=attributes[ii]%>") ;
<%  } %>
    // Last entry *must* be "**User Entered**
    attributeList.push("**User Entered**") ;
    attributeServerList.push("**User Entered**") ;
    numAttributes = attributeList.length;
</script>

<!-- This is the GUI FORM, most of which will not submitted to the server (only first few hiddens) -->
<form name="queryForm" id="queryForm" method="post" action="/genboree/formParams.rhtml">
  <input type="hidden" name="myCurrentIndex" id="myCurrentIndex" value="<%=myCurrentIndex%>" >
  <!-- These 2 fields are what is actually submitted to the server -->
  <input type="hidden" name="allAny" id="allAny" value="all">
  <input type="hidden" name="rulesJson" id="rulesJson" value="">
  <table width="100%">
  <tr>
    <td width="100%" style="background-color:#d3cfe6;">
      <BR>
      <div width="100%" style="text-align: center; min-width: 100% ; background-color:#d3cfe6;">
        <div style="float:left; width: 12% ;">
          <input type="button" name="btnApply" id="btnApply" value="Apply" class="btn"  style="width:70" onClick="submitAVP('queryForm', 'rulesJson');">
          <!--input type="button" name="btnReset" id="btnReset"" value="Reset" class="btn"  style="width:70" onClick="resetQueryUI('queryForm');"-->
        </div>
        <div style="float:left; margin-left: auto; margin-right: auto; width: 75% ; ">
          Match
          <select name="selectAllAny" id="selectAllAny" class="txt" style="" onClick="setAllAny('outForm', 'selectAllAny');">
            <option value="all">All</option>
            <option value="any">Any</option>
          </select>
         of the conditions.
        </div>
        <div style="float:right; width: 12%; ">
          <input type="button" name="btnaddAttribute" id="btnaddAttribute" value="+" class="btn" style="width:35" onClick="addRule();">
          <input type="button" name="btnremoveAttribute" id="btnremoveAttribute" value="-" class="btn" style="width:35" onClick="removeOneRule();">
        </div>
        <BR> <BR>
      </div>
      <div width="100%" class="rowheader">
        <!-- div style="width:60px ; " class="cellheaderdiv">&nbsp;</div -->
        <div style="width:120px ; " class="cellheaderdiv">Attribute</div>
        <div style="width:90px ; "  class="cellheaderdiv">Data type</div>
        <div style="width:130px ; " class="cellheaderdiv">Operation</div>
        <div style="width:110px ; " class="cellheaderdiv">Values</div>
        <BR>
      </div>
      <div id="qtooldiv" width="100%" class="scrollable">
      </div>
      <div width="100%" >
        <div width="100%" style="text-align: center; min-width: 100% ; background-color:#d3cfe6;">
        <div style="float:left; width: 12% ;">
          <input type="button" name="btnApply2" id="btnApply2" value="Apply" class="btn" style="width:70" onClick="submitAVP('queryForm', 'rulesJson');">
          <!--input type="button" name="btnReset2" id="btnReset2" value="Reset" class="btn"  style="width:70" onClick="resetQueryUI('queryForm');"-->
        </div>
        <div style="float:right; width: 12%; ">
          <input type="button" name="btnaddAttribute2" id="btnaddAttribute2" value="+" class="btn" style="width:35px" onClick="addRule();">
          <input type="button" name="btnremoveAttribute2" id="btnremoveAttribute2" value="-" class="btn" style="width:35px" onClick="removeOneRule();">
        </div>
        <BR> <BR>
      </div>
    </td>
  </tr>
  </table>
</form>
<%@ include file="include/footer.incl" %>
</body>
</html>
