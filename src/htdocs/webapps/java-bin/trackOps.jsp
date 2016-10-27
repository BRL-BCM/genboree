<%@ include file="include/trackOps.incl" %>
<HTML>
<head>
<title>Genboree - Track Operations</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<script type="text/javascript" src="/javaScripts/prototype.js?<%=jsVersion%>"></script>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY bgcolor="#DDE0FF">
<%@ include file="include/sessionGrp.incl" %>
<%@ include file="include/header.incl" %>
<%@ include file="include/navbar.incl" %>
<%@ include file="include/toolBar.incl" %>
<BR/>
<%
  if( verr.size() > 0 )
  {
%>
    <font color="red"><strong>Error:</strong></font>
    The requested operation cannot be performed due to the following problem(s):
    <ul>
    <%
      for(int ii=0; ii<verr.size(); ii++ )
      {
        out.println( "<li>" + ((String)verr.elementAt(ii)) + "</li>" ) ;
      }
    %>
    </ul>
<%
  }
%>

<form name="usrfsq" id="usrfsq" action="trackOps.jsp" method="post">

<%
  if( mode != MODE_DEFAULT )
  {
%>
    <input type="hidden" name="mode" id="mode" value="<%=modeIds[mode]%>"></input>
<%
  } // if( mode != MODE_DEFAULT )
%>

<table border="0" cellpadding="4" cellspacing="2" width="100%">
  <tr>
     <%@ include file="include/groupbar.incl" %>
  </tr>
  <tr>
    <td colspan="2" style="height:12"></td>
  </tr>
<%
  boolean need_db_list = ( rseqs.length > 0 ) ;
  String db_msg = need_db_list ? null : "No databases available in this group" ;
%>
<%
  if(need_db_list)
  {
%>
  <tr>
    <%@ include file="include/databaseBar.incl" %>
  </tr>
  <tr>
    <td class="form_body"><strong>Operation</strong></td>
    <td class="form_body">
      <select name="operationSelect" class="txt" id="operationSelect" style="width:300" onChange="window.location=this.options[this.selectedIndex].value">
       <option value="trackOps.jsp" selected>SELECT AN OPERATION</option>
<%
        for(int i=0; i<modeIds.length; i++ )
        {
          String sel = (mode == i) ? " selected" : "";
%>
          <option value="<%=modeLinks[i]%>"<%=sel%>><%=modeIds[i]%></option>
<%
        }
%>
      </select>
      &nbsp;
<%
      String openpopupStr = null ;
      switch(mode)
      {
        case MODE_COMBINE:
          openpopupStr = "javascript:openpopup('trackOpsHelp.jsp#Combine')" ;
          break ;
        case MODE_INTERSECT:
          openpopupStr = "javascript:openpopup('trackOpsHelp.jsp#Intersect')" ;
          break ;
        case MODE_NONINTERSECT:
          openpopupStr = "javascript:openpopup('trackOpsHelp.jsp#Non-Intersect')" ;
          break ;
        default:
         openpopupStr = "javascript:openpopup('trackOpsHelp.jsp')" ;
         break ;
      } ;
%>
      <a href="<%=openpopupStr%>">Help</a>
    </td>
  </tr>
<%
  // display interface of respective operation
  String [] checkedList = null ;
  String selected = null ;
  String checked = null ;
  if(hasTracks)
  {
    switch(mode)
    {
      case MODE_COMBINE:
%>
        <tr>
          <td class="form_body"><strong>Select from list of tracks</strong></td>
          <td align="left" class="form_body">
<%
            checkedList = (String []) mys.getAttribute( "combineTrack" ) ;
            for( int i = 0; i < trackNames.length; i++)
            {
              String chk = "" ;
              if(checkedList != null)
              {
                for(int j = 0; j < checkedList.length; j++)
                {
                  if(trackNames[i].equals(checkedList[j]))
                  {
                    chk = "checked" ;
                    break ;
                  }
                }
              }
%>
              <input type='checkbox' id='trkId' name='trkId' value="<%=Util.htmlQuote(trackNames[i])%>" <%=chk%>>
              <%=Util.htmlQuote( trackNames[i] ) %></input><br>
<%
            }

            if(checkedList != null)
            {
              mys.removeAttribute( "combineTrack" ) ;
            }
%>
          </td>
        </tr>
<%
        break;
      case MODE_INTERSECT:
%>
        <tr>
          <td class="form_body"><strong>First Track</strong></td>
          <td align="left" class="form_body">
            <select name="firstTrackSelect" class="txt" id="firstTrackSelect" style="width:300">
<%
              selected = (String) mys.getAttribute( "firstTrack" );
              for(int i = 0; i < trackNames.length; i++)
              {
                String sel = "";
                 if(selected != null && trackNames[i].equals( selected ))
                {
                  sel = "selected" ;
                }
%>
                <option value="<%=Util.htmlQuote(trackNames[i])%>" <%=sel%>>
                <%=Util.htmlQuote( trackNames[i] )%></option>
<%
              }

              if(selected != null)
              {
                mys.removeAttribute( "firstTrack" ) ;
              }
%>
            </select>
            <br>
            using an additional
            <input type="text" class="txt" name="radiusField" id="radiusField" size="4" value="<%=radius%>"></input>
            bp radius around the annotations
          </td>
        </tr>
        <tr>
          <td class="form_body"><strong>Condition</strong></td>
          <td align="left" class="form_body">
            <strong>intersecting</strong>  annotations from
<%
            checked = (String) mys.getAttribute( "condition" );
            for(int i = 0; i < condIds.length; i++)
            {
              String chk = "" ;
              if(checked != null)
              {
                if(condIds[i].equals(checked))
                {
                  cond = i ;
                  chk = "checked" ;
                }
              }
              else
              {
                if(i == 0)
                {
                  chk = "checked" ;
                }
              }
%>
              <input type="radio" name="conditionButton" value="<%=condIds[i]%>" onchange="updateReqOverlapText() ;" <%=chk%>><strong><%=condIds[i]%></strong></input>
<%
            }

            if(checked != null)
            {
              mys.removeAttribute( "condition" ) ;
            }
%>
            of the tracks below.
            <br>
            and requiring overlap with at least
            <input type="text" class="txt" name="reqOverlap" id="reqOverlap" size="2" value="1"></input>
            annotations <span id="reqOverlapText">from any selected track below</span>.
          </td>
        </tr>
        <tr>
          <td height="99" class="form_body"><strong>Second Track(s)</strong></td>
          <td align="left" class="form_body">
<%
            checkedList = (String [])mys.getAttribute("secondTrack");
            for(int i = 0; i < trackNames.length; i++)
            {
              String chk = "" ;
              if(checkedList != null)
              {
                for(int j = 0; j < checkedList.length; j++)
                {
                  if(trackNames[i].equals(checkedList[j]))
                  {
                    chk = "checked" ;
                    break ;
                  }
                }
              }
%>
              <input type='checkbox' name='trkId' value="<%=Util.htmlQuote(trackNames[i])%>" <%=chk%>>
              <%=Util.htmlQuote( trackNames[i] )%></input><br>
<%
            }

            if(checkedList != null )
            {
              mys.removeAttribute( "secondTrack" ) ;
            }
%>
          </td>
        </tr>
<%
        break;
      case MODE_NONINTERSECT:
%>
        <tr>
           <td class="form_body"><strong>First Track</strong></td>
          <td align="left" class="form_body">
            <select name="firstTrackSelect" class="txt" id="firstTrackSelect" style="width:300">
<%
              selected = (String) mys.getAttribute( "firstTrack" ) ;
              if(trackNames != null && trackNames.length > 0)
              {
                for(int i = 0; i < trackNames.length; i++)
                {
                  String sel = "";
                  if(selected != null)
                  {
                    if(trackNames[i].equals(selected))
                    {
                      sel = "selected" ;
                    }
                  }
%>
                  <option value="<%=Util.htmlQuote(trackNames[i])%>" <%=sel%>>
                  <%=Util.htmlQuote(trackNames[i]) %></option>
<%
                }

                if(selected != null)
                {
                  mys.removeAttribute( "firstTrack" ) ;
                }
              }
              else
              {
%>
                <option value=" No tracks avaliable for operation " >
<%
              }
%>
            </select>
            <br>
            using an additional
            <input type="text" class="txt" name="radiusField" id="radiusField" size="2" value="0"></input>
            bp radius around the annotations
          </td>
        </tr>
        <tr>
           <td class="form_body"><strong>Condition</strong></td>
           <td align="left" class="form_body">
            <strong>not intersecting</strong>  annotations from
<%
            checked = (String) mys.getAttribute( "condition" ) ;
            for(int i = 0; i < condIds.length; i++)
            {
              String chk = "" ;
              if(checked != null)
              {
                if(condIds[i].equals(checked))
                {
                  cond = i ;
                  chk = "checked" ;
                }
              }
              else
              {
                if(i == 0)
                {
                  chk = "checked" ;
                }
              }
%>
              <input type="radio" name="conditionButton" value="<%=condIds[i]%>" onchange="updateReqOverlapText() ;" <%=chk%>><strong><%=condIds[i]%></strong></input>
<%
            }

            if(checked != null)
            {
              mys.removeAttribute( "condition" ) ;
            }
%>
            of the tracks below.
            <br>
            and requiring intersection to involve overlap with at least
            <input type="text" class="txt" name="reqOverlap" id="reqOverlap" size="4" value="1"></input>
            annotations
            <br>
            <span id="reqOverlapText">from any selected track below</span> (anything fewer will count as 'non-intersecting').
          </td>
        </tr>
        <tr>
           <td height="99" class="form_body"><strong>Second Track(s)</strong></td>
           <td align="left" class="form_body">
<%
            checkedList = (String [])mys.getAttribute("secondTrack") ;
            for(int i = 0; i < trackNames.length; i++)
            {
              String chk = "" ;
              if(checkedList != null)
              {
                for(int j = 0; j < checkedList.length; j++)
                {
                  if(trackNames[i].equals( checkedList[j]))
                  {
                    chk = "checked" ;
                    break ;
                  }
                }
              }
%>
              <input type='checkbox' name='trkId' value="<%=Util.htmlQuote(trackNames[i])%>" <%=chk%>>
              <%=Util.htmlQuote(trackNames[i]) %></input><br>
<%
            }

            if(checkedList != null)
            {
              mys.removeAttribute( "secondTrack" );
            }
%>
          </td>
        </tr>
<%
        break ;
      default:
        break ;
    } ;

  // show table row containing new track information input if mode exists
  if(mode != MODE_DEFAULT)
  {
%>
    <tr>
      <td colspan="2" class="form_header"><strong>New Track</strong></td>
    </tr>
    <tr>
        <td class="form_body"><strong>Class</strong></td>
        <td class="form_body">
          <input type="text" class="txt" name="classField" id="classField" size="68" maxLength="255" value="<%=newTrackClassName%>"></input>
        </td>
    </tr>
    <tr>
        <td class="form_body"><strong>Type</strong></td>
        <td class="form_body">
          <input type="text" class="txt" name="typeField" id="textField" size="68" maxLength="255" value="<%=newTrackTypeName%>"></input>
        </td>
    </tr>
    <tr>
        <td class="form_body"><strong>Sub-Type</strong></td>
        <td class="form_body">
          <input type="text" class="txt" name="subTypeField" id="subTypeField" size="68" maxLength="255" value="<%=newTrackSubTypeName%>"></input>
        </td>
    </tr>
<%
  }
%>
<%
  }
  }
  else
  {
%>
    <tr>
      <td class="form_header" colspan="2">
        <input type="hidden" name="rseq_id" id="rseq_id" value="#">
        <strong><%=db_msg%></strong>
      </td>
    </tr>
<%
  } // end if(need_db_list )
%>
  <tr>
    <td colspan="2">
<%
      if( mode != MODE_DEFAULT && rseqs != null && rseqs.length >0  && trackNames != null && trackNames.length > 0 )
      {
%>
        <INPUT type="submit" name="btnExecute" id="btnExecute" class="btn" style="width:80" value="Execute" onClick="return validateForm() ;"></input>
<%
      }
%>
      <INPUT type="submit" name="btnCancel" id="btnCancel" class="btn" value="&nbsp;Cancel&nbsp;"></input>
    </td>
  </tr>
</table>
</form>

<script language="javascript">
  function validateForm()
  {
<%
    if(mode == MODE_INTERSECT || mode == MODE_NONINTERSECT)
    {
%>
      var radiusFieldElem = $('radiusField') ;
      var retVal = checkRadiusField(radiusFieldElem) ;
      if(retVal)
      {
        retVal = checkReqOverlap() ;
      }
<%
    }
%>
    return retVal ;
  }

  function checkRadiusField()
  {
<%
    if(mode == MODE_INTERSECT || mode == MODE_NONINTERSECT)
    {
%>
      var radiusFieldVal = $F('radiusField') ;
      radiusFieldVal = radiusFieldVal.strip() ;
      var re = /^-{0,1}\d*$/ ;
      if(!re.test( radiusFieldVal ) || radiusFieldVal == "")
      {
        alert("Radius value must be an integer!") ;
        $('radiusField').value = "0" ;
        return false ;
      }
<%
    }
%>
    return true ;
  }

  function checkReqOverlap()
  {
<%
    if(mode == MODE_INTERSECT || mode == MODE_NONINTERSECT)
    {
%>
      var reqOverlapVal = $F('reqOverlap') ;
      reqOverlapVal = reqOverlapVal.strip() ;
      var re = /^\d+$/ ;
      if(!re.test(reqOverlapVal) || reqOverlapVal == "0")
      {
        alert("Radius value must be a positive, non-zero integer!") ;
        return false ;
      }
<%
    }
%>
    return true ;
  }

  function updateReqOverlapText()
  {
<%
    if(mode == MODE_INTERSECT || mode == MODE_NONINTERSECT)
    {
%>
      var conditionRadios = document.getElementsByName('conditionButton') ;
      var checkedRadio = conditionRadios[0] ;
      for(var ii=0; ii<conditionRadios.length; ii++)
      {
        if(conditionRadios[ii].checked)
        {
          checkedRadio = conditionRadios[ii] ;
          break ;
        }
      }
      var conditionVal = checkedRadio.value ;
      var reqOverlapText = "from any selected track below"
      if(conditionVal == "All")
      {
        reqOverlapText = "in each of the selected tracks below"
      }
      var reqOverlapTextSpan = $('reqOverlapText') ;
      reqOverlapTextSpan.update(reqOverlapText) ;
<%
    }
%>
    return true ;
  }

  var winpops ;
  function openpopup(theUrl)
  {
    var popurl = theUrl ;
    winpops = window.open( popurl, "trackOpsHelp", "width=775,height=338,scrollbars,resizable") ;
    winpops.focus() ;
  }
</script>

<%@ include file="include/footer.incl" %>
</BODY>
</HTML>
