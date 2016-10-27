<%@ page import="
  java.util.Map,
  java.util.Iterator,
  java.net.URLEncoder,
  org.genboree.util.GenboreeUtils"
%>
<%
StringBuilder query = new StringBuilder() ;
query.append("?") ;

// REBUILD the request params we will redirect using GET
Map paramMap = request.getParameterMap() ; // "key"=>String[]

// Loop over request key-value pairs, append them to query string
Iterator paramIter = paramMap.entrySet().iterator() ;
while(paramIter.hasNext())
{
  Map.Entry paramPair = (Map.Entry) paramIter.next() ;
  String pName = URLEncoder.encode((String) paramPair.getKey(), "UTF-8") ;
  String[] pValues = (String[]) paramPair.getValue() ; // <-- Array!
  
  // Don't add a "&" after the "?"
  if(query.length() > 1) query.append("&") ;
  
  if(pValues != null)
  { // then there is 1+ actual values
    for(int ii = 0; ii < pValues.length; ii++)
    { // Add all of the values to the POST
      query.append(pName).append("=").append(URLEncoder.encode(pValues[ii], "UTF-8")) ;
    }
  }
  else // no value, just a key? ok...
  {
    query.append("&").append(pName).append("=") ;
  }
}

// Forward to new page (using GET)
GenboreeUtils.sendRedirect(request, response, "/java-bin/tabular.jsp" + query) ; 
%>
