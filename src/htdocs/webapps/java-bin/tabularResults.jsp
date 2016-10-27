<%@ page import="
  java.util.HashMap,
  org.genboree.util.Util,
  org.genboree.util.MemoryUtil,
  org.genboree.dbaccess.DbFtype,
  org.genboree.dbaccess.IDFinder,
  org.genboree.dbaccess.IDUnfoundException,
  org.genboree.tabular.Row,
  org.genboree.tabular.Table,
  org.genboree.tabular.ColumnType"
%>

<%
  // First things first, we must check for a session timeout (or public login)
  // This must be done before we include userInfo.incl because that file makes
  // calls to response.sendRedirect() which potentially can respond to an AJAX
  // widget with very undesirable effect.  
  // NOTE: It may be smarter to create methods in GenboreeUtil that will check
  // if a redirect is about to occur, so that we have that common code in one
  // place - SGD
  if(session.getAttribute("username") == null
    || session.getAttribute("pass") == null
    || session.getAttribute("userid") == null)
  {
    out.write("{'error': 'Missing login information'}") ;
    return ;
  }
  
  // Now check for public access attempts to a non-published database
  String databaseId = SessionManager.getSessionDatabaseId(session) ;
  if (databaseId == null) databaseId = request.getParameter("refSeqId") ;
  if(session.getAttribute("username").toString().equalsIgnoreCase("Public") &&
    !Refseq.isPublished(DBAgent.getInstance(), databaseId))
  {
    out.write("{'error': 'Access Denied'}") ;
    return ;
  }
%>

<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>

<%
  if(request.getParameter("action").equals("list"))
  {
    // Get the cached results
    Table tabular = null ;
    if(session.getAttribute("tabularTable") != null)
      tabular = (Table) session.getAttribute("tabularTable") ;

    // Check for problems
    if(tabular == null)
    {
      out.write("{'error': 'Cannot find the table data in memory'}") ;
      System.err.println("tabularResults.jsp: Could not find Table object in session!") ;
    }
    else
    {
      // Perform a new sort if requested
      if(request.getParameter("sort") != null)
      {
        // NOTE: This sort is requested EVERY time a page is listed, after the
        // user has used the GridPanel headers to sort a single time.  However,
        // the Table.sort() method is very efficient and will not perform a
        // sort unless it will result in a reordering of data.  Therefore, the
        // extra requests will not hurt our performance.
        try
        {
          // Following line assumes sort request of form: "columnX" where X is the
          // column number to be sorted
          int col = Integer.parseInt(request.getParameter("sort").substring(6)) ;
          boolean reverse = request.getParameter("dir").equals("DESC") ;
          tabular.sort(col, reverse) ;
        }
        catch(NumberFormatException e)
        {
          System.err.println("tabularResults.jsp: Invalid sort - " + request.getParameter("sort")) ;
        }
      }

      // Build the JSON object
      int start, limit;
      try
      {
        start = Integer.parseInt(request.getParameter("start")) ;
        limit = Integer.parseInt(request.getParameter("limit")) ;
      }
      catch(NumberFormatException e)
      {
        System.err.println("tabularResults.jsp: Invalid start/limit parameters (" + 
          request.getParameter("start") + "," + request.getParameter("limit") + ")") ;
        start = 0 ;
        limit = 25 ;
      }

      // Fill the Table Row
      if(tabular.getRowCount() == 0)
        start = 0; 
      else if(start >= tabular.getRowCount())
        start = tabular.getRowCount() - 1 ;
      if(start + limit > tabular.getRowCount() || limit <= 0)
         limit = tabular.getRowCount() - start ;
      tabular.fill(db, start, (start + limit - 1)) ;

      // Get our Row data and build a JSON string
      HashMap<String, String> userAccessMap = new HashMap<String, String>() ;
      StringBuilder results = new StringBuilder() ;
      results.append("[") ;
      for(int row = start; row < start + limit && row < tabular.getRowCount(); row++)
      {
        results.append((row == start ? "" : ",") + "{") ;
        Row targetRow = tabular.getRow(row) ;
        for (int col = 1; col <= tabular.getVisibleColumnCount(); col++)
        {
          results.append((col == 1 ? "" : ",") + "'") ;
          results.append("column") ;
          results.append(col) ;
          results.append("':") ;
          results.append("'") ;
          if(tabular.getHeader(col).getType().getId() == ColumnType.UNDEFINED_ID)
          {
            // Handle the Edit Buttons
            if(userAccessMap.get(tabular.getDb(targetRow)) == null)
            {
              String access = Refseq.fetchUserAccess(db, tabular.getDb(targetRow), myself.getUserId()) ;
              if(access != null && (access.equals("o") || access.equals("w")))
              {
                Refseq r = new Refseq() ;
                r.fetch(db, tabular.getDb(targetRow)) ;
                int uploadId = -2 ;
                try
                {
                  uploadId = IDFinder.findUploadID(db.getConnection(), r.getRefSeqId(), 
                    tabular.getDb(targetRow)) ;
                }
                catch(IDUnfoundException e)
                {
                  System.err.println("tabularResults.jsp: Cannot find upload id for refseq " + 
                    r.getRefSeqId()) ;
                }
                userAccessMap.put(tabular.getDb(targetRow), "" + uploadId) ;
              }
              else
              {
                userAccessMap.put(tabular.getDb(targetRow), "-1");
              }
            }
            
            results.append(userAccessMap.get(tabular.getDb(targetRow)) + ":" + targetRow.getId()) ;
          }
          else if(tabular.getHeader(col).getType().getId() == ColumnType.NAME_ID)
          {
            // Handle the 'name', add link to gbrowser
            long startPos = -1, stopPos = -1 ;
            String chromosome = "" ;
            try
            {
              // First determine start/stop/chr
              for(int head = 1; head <= tabular.getColumnCount(); head++)
              {
                if(tabular.getHeader(head).getType().getId() == ColumnType.START_ID)
                  startPos = Long.parseLong(targetRow.get(head)) ;
                if(tabular.getHeader(head).getType().getId() == ColumnType.STOP_ID)
                  stopPos = Long.parseLong(targetRow.get(head)) ;
                if(tabular.getHeader(head).getType().getId() == ColumnType.ENTRY_POINT_ID)
                  chromosome = targetRow.get(head) ;
              }

              // Now build the gbrowser parameters
              long length = stopPos - startPos ;
              if(startPos <= 0) startPos = 1 ;
              if(startPos - (length / 5) > 0)
                startPos = startPos - (length / 5) ;
              stopPos = stopPos + (length / 5) ;
              if((stopPos - startPos) < 100) stopPos = startPos + 100 ;
              
              // Now produce the link
              results.append("<a href=\"/java-bin/gbrowser.jsp?refSeqId=" + 
                request.getParameter("refSeqId") + 
                "&entryPointId=" + chromosome + "&from=" + startPos + "&to=" + stopPos + "\">" +
                targetRow.get(col).replaceAll("'", "\\\\'") + "</a>") ;
            }
            catch(NumberFormatException e)
            {
              System.err.println("tabularResults.jsp: Problem getting start / stop coordinates for link to " +
              "gbrowser.jsp from fid: " + targetRow.getId() + " db: " + tabular.getDb(targetRow)) ;
              results.append(targetRow.get(col).replaceAll("'", "\\\\'")) ;
            }
          }
          else if(targetRow.get(col) != null)
          {
            // Typical data value
            results.append(targetRow.get(col).replaceAll("'", "\\\\'")) ;
          }
          else
          {
            // Empty value??
            results.append("null") ;
          }
          results.append("'") ;
        }
        results.append("}") ;
      }
      results.append("]") ;

      // Respond
      out.write("{'total': '" + tabular.getRowCount() + "', 'results': " + results + "}") ;
    }
  }
  else
  {
    // Misunderstood request
    out.write("{failure:true}") ;
    System.err.println("tabularResults.jsp: Misunderstood request (" + 
      request.getParameter("action") + ")") ;
  }
%>
