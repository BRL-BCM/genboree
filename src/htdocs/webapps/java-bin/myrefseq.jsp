<%@ page import="javax.servlet.http.*, java.util.*, java.sql.*, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.util.*, org.genboree.upload.*, org.genboree.message.GenboreeMessage" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%!
  //static String[] modeIds = { "Create", "Delete", "Update", "Upload", "EPs", "Publish", "Unlock" } ;
  //static String[] modeLabs = { "Create", "Delete", "Update&nbsp;Info", "Upload&nbsp;Data", "Upload&nbsp;Entry&nbsp;Points", "Publish", "Unlock" } ;
  static String[] modeIds = {} ;
	static String[] modeLabs = {} ;
	static final int MODE_DEFAULT = -1 ;
  static final int MODE_CREATE = 0 ;
  static final int MODE_DELETE = 1 ;
  static final int MODE_UPDATE = 2 ;
  static final int MODE_UPLOAD = 3 ;
  static final int MODE_UPLOADEPS = 4 ;
  static final int MODE_PUBLISH = 5 ;
  static final int MODE_UNLOCK = 6 ;
  static String[] sourceFileArr = new String[7] ;
%>
<%
  sourceFileArr[MODE_UNLOCK] = "/genboree/dbUnlockResource.rhtml" ;

  // ARJ: Create a TimingUtil object for easy timing of code
  TimingUtil timer = new TimingUtil(userInfo) ;
  response.addDateHeader( "Expires", 0L ) ;
  response.addHeader( "Cache-Control", "no-cache, no-store" ) ;
  GenboreeMessage.clearMessage(mys) ;
  String errMessage = "<b>The requested operation cannot be performed:</b>" ;
  String db_msg = null ;
  boolean edit_frefs = false ;
  boolean need_reload = false ;
  boolean db_public = false ;
  boolean need_create = false ;
  boolean need_update = false ;
  boolean createSuccess = false ;
  int totalFrefCount = -1 ; // How many frefs?
  int mode = MODE_DEFAULT ;
  int totalRstEPCount = -1 ;
  String publish = "Publish" ;
  String unPublish = "Retract" ;
  String pMode = request.getParameter("mode") ;
  String rseq_name = "" ;
  String rseq_descr = "" ;
  String rseq_species = "" ;
  String rseq_ver = "" ;
  String rsTemplId = null ;
  Vector v = null ;
	String serverName = Constants.REDIRECTTO;

  Refseq rseq = null ;
  boolean is_ro_group = false ;
  Hashtable htTrkErr = null ;
  Connection tConn = null ; // Get connection to annotation database once
  DbFref[] frefs = null ;
  RefseqTemplate[] rsTempls = null ;
  RefseqTemplate rst = null ;
  RefseqTemplate.EntryPoint[] rstEps = null ;

  // Only ADMINs and AUTHORs can create/update databases
  boolean userRoleCanEditRefseqInfo = (currGroupRoleCode.equals("o") || currGroupRoleCode.equals("w")) ;
  boolean userRoleIsGroupAdmin = currGroupRoleCode.equals("o") ;

  // First, determine if we have the 'accounts' feature turned on or not
  Connection conn = db.getConnection() ;
  String useAccountsStr = GenboreeConfig.getConfigParam("useAccounts") ;
  boolean useAccounts = false ;
  if(useAccountsStr != null && useAccountsStr.length() > 0)
  {
    if(useAccountsStr.toLowerCase().equals("true"))
    {
      useAccounts = true ;
    }
  }
  // If we're processing the submitted form or something, get the account code from the form if present
  String accountCode = request.getParameter("accountCode") ;
  String accountErrStr = null ; // Unfortunately, the horrible disorganization of this page requires work arounds for error-detection/handling
  if(accountCode == null)
  {
    accountCode = "" ;
  }
  else
  {
    accountCode = accountCode.trim() ;
  }

  if(pMode != null)
  {
    for(int i=0 ; i<modeIds.length ; i++ )
    {
      if(pMode.equals(modeIds[i]))
      {
        mode = i ;
        break ;
      }
    }
  }

  if( request.getParameter("btnCancel") != null || request.getParameter("btnCancel2") != null  )
  {
    GenboreeMessage.clearMessage(mys) ;
    GenboreeUtils.sendRedirect(request,response, (mode == MODE_DEFAULT) ? "/java-bin/index.jsp" : "/java-bin/myrefseq.jsp" ) ;
    return ;
  }

  if(userInfo[0].equals("admin"))
  {
    myGrpAccess = "ADMINISTRATOR" ;
    i_am_owner = true ;
    isAdmin = true ;
  }

  /* removing all this variables from session why?? */
  mys.removeAttribute( "uploadRefseq" ) ;
  mys.removeAttribute( "uploadRefseqId" ) ;

  if( rseq_id == null )
  {
    rseq_id = "#" ;
  }
  else
  {
    for(int i=0 ; i<rseqs.length ; i++ )
    {
      if( rseqs[i].getRefSeqId().equals(rseq_id) )
      {
          rseq = rseqs[i] ;
          break ;
      }
    }
  }

  htTrkErr = new Hashtable() ;
  HashMap accountInfo = new HashMap() ;
  boolean accountCodeOk = false ;
  int accountId = -1 ;
  // CHECK ACCOUNT CODE, STORE VALIDATION RESULT FOR LATER USE
  if(mode == MODE_CREATE)
  {
    // No current refseq/userDatabase
    rseq = null ;
    rseq_id = "#" ;
    // Check if using accounts feature, have we got an accountCode to process and if so, are we allowed to create?
    if(useAccounts)
    {
      if(accountCode.length() > 0)
      {
        // Retrieve account record using this code
        DbResourceSet accountRecordDbResSet = AccountsTable.getRecordByCode(accountCode, conn) ;
        if(accountRecordDbResSet != null && accountRecordDbResSet.resultSet != null)
        {
          accountRecordDbResSet.db = db ;
          while(accountRecordDbResSet.resultSet.next())
          {
            accountInfo.put("id", accountRecordDbResSet.resultSet.getInt("id")) ;
            accountInfo.put("name", accountRecordDbResSet.resultSet.getString("name")) ;
            accountInfo.put("code", accountRecordDbResSet.resultSet.getString("code")) ;
            accountInfo.put("primaryContactName", accountRecordDbResSet.resultSet.getString("primaryContactName")) ;
            accountInfo.put("primaryContactEmail", accountRecordDbResSet.resultSet.getString("primaryContactEmail")) ;
            accountCodeOk = true ;
            break ;
          }
          accountRecordDbResSet.close() ;
        }
        // Did we get an account using this code?
        if(!accountCodeOk)
        {
          accountErrStr  = "The account code entered does not correspond to a existing Genboree account." ;
          createSuccess = false ;
        }
        else // got valid account code
        {
          // check if num users for account not exceeded
          accountId = (Integer)accountInfo.get("id") ;
          accountCodeOk = !AccountsTable.isMaxNumDatabasesExceeded(accountId, conn) ;
          if(!accountCodeOk)
          {
            accountErrStr  = "No more databases are permitted in for this account. Please contact your account manager to arrange for more, if needed." ;
            createSuccess = false ;
          }
          else
          {
            createSuccess = true ;
          }
        }
      }
      else
      {
        accountErrStr = "Account code is empty ; please enter your code." ;
        createSuccess = false ;
        accountCodeOk = false ;
      }
    }
    else // not using accounts
    {
      accountCodeOk = true ;
      createSuccess = true ;
    }
  }
  // How many frefs?
  totalFrefCount = -1 ;
  if(rseq != null)
  {
    tConn = db.getConnection(rseq.getDatabaseName()) ;
    totalFrefCount = DbFref.countAll( tConn ) ;
  }

  if(mode==MODE_UPDATE)
  {
    GenboreeMessage.clearMessage(mys) ;
    if( rseq == null )
    {
      mode = MODE_DEFAULT ;
    }
    else
    {
      if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_EDIT)
      {
        frefs = DbFref.fetchAll( tConn ) ;
      }
      else // too many, get none
      {
        frefs = new DbFref[0] ;
      }

      if(request.getParameter("update_frefs") != null)
      {
        GenboreeMessage.clearMessage(mys) ;
        Hashtable htDup = new Hashtable() ;
        Hashtable htOld = new Hashtable() ;
        HashMap deleteFrefs = new HashMap() ;
        Vector vNew = new Vector() ;
        Vector vEml = new Vector() ;

        for(int i=0 ; i<frefs.length ; i++ )
        {
          DbFref fref = frefs[i] ;
          boolean deletefref = false ;
          String frefId = "" + fref.getRid() ;
          String refname = request.getParameter( "updfref_" + fref.getRid() ) ;
          String deleteRefname = request.getParameter("deletefref_" + fref.getRid()) ;
          if(deleteRefname != null)
          {
            deleteRefname.trim() ;
            if(deleteRefname.equalsIgnoreCase("y")) deletefref = true ;
          }
          if( refname == null )
          {
            refname = fref.getRefname() ;
          }
          if(deletefref)
          {
            deleteFrefs.put(frefId, frefId) ;
          }
          else
          {
            refname = refname.trim() ;
          }
          if(Util.isEmpty(refname))
          {
            ArrayList errlist = new  ArrayList() ;
            errlist.add("Please enter new entry point name" ) ;
            GenboreeMessage.setErrMsg(
              mys,
              "<b>Failed to rename entry point \"" + Util.htmlQuote(fref.getRefname()) + "\"</b>",
              errlist) ;

            htTrkErr.put(frefId, fref) ;
            htDup.put(fref.getRefname(), fref) ;
            continue ;
          }
          if(refname.equals(fref.getRefname()))
          {
            htDup.put( fref.getRefname(), fref ) ;
            continue ;
          }
          htOld.put( refname, fref.getRefname() ) ;
          fref.setRefname( refname ) ;
          vNew.addElement( fref ) ;
        }

        for(int i=0 ; i<vNew.size() ; i++ )
        {
          DbFref fref = (DbFref) vNew.elementAt(i) ;
          String frefId = "" + fref.getRid() ;
          String refname = fref.getRefname() ;
          String oldRefname = (String) htOld.get( refname ) ;
          if( htDup.get(refname) != null )
          {
            ArrayList errlist = new ArrayList() ;
            errlist.add( "Duplicate entry point name") ;
            GenboreeMessage.setErrMsg(
              mys,
              "<b>Failed to rename entry point \"" + Util.htmlQuote(oldRefname)+"\" to " + Util.htmlQuote(fref.getRefname()  ) + "</b>",
              errlist) ;
            htTrkErr.put( frefId, fref ) ;
            htDup.put( oldRefname, fref ) ;
            continue ;
          }

          if(!fref.update(tConn))
          {
            ArrayList errlist = new ArrayList() ;
            errlist.add( "Duplicate entry point name:") ;
            GenboreeMessage.setErrMsg(
              mys,
              "<b>Failed to rename entry point\"" + Util.htmlQuote(oldRefname)+"\" to " + Util.htmlQuote(fref.getRefname()) +"</b>",
              errlist) ;
              htTrkErr.put(frefId, fref) ;
              htDup.put( oldRefname, fref ) ;
              continue ;
          }

          GenboreeMessage.setSuccessMsg(
            mys,
            "Entry Point <b>" + Util.htmlQuote(oldRefname)+"</b> was successfully renamed to <b>" + Util.htmlQuote(fref.getRefname()) + "</b>" ) ;
          vEml.addElement("Entry Point " + Util.htmlQuote(oldRefname) + " renamed to " + Util.htmlQuote(fref.getRefname()) ) ;
          htDup.put( fref.getRefname(), fref ) ;
        }

        String deletedRids = null ;
        if(deleteFrefs.size() > 0)
        {
          deletedRids = Refseq.deleteRids( db, rseq.getDatabaseName(), deleteFrefs) ;
          if(deleteFrefs.size() == 1)
          {
            GenboreeMessage.setSuccessMsg(mys, "<B>The 1 selected entry point was deleted successfully.</b>") ;
          }
          else
          {
            GenboreeMessage.setSuccessMsg(mys, "<B>The " + deleteFrefs.size() + " selected entry points were deleted successfully. </b>") ;
          }

          if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_EDIT)
          {
            frefs = DbFref.fetchAll( tConn ) ;
          }
           else // too many, get none
          {
            frefs = new DbFref[0] ;
          }
        }

        if( vEml.size() > 0 )
        {
          // Send notification email
          String adrFrom = "\"Genboree Team\" <" +  GenboreeConfig.getConfigParam("gbFromAddress") + ">" ;
          SendMail m = new SendMail() ;
          m.setHost( Util.smtpHost ) ;
          m.setFrom( adrFrom ) ;
          m.setReplyTo( adrFrom ) ;
          m.addTo( adrFrom ) ;
          m.addTo( GenboreeConfig.getConfigParam("gbAdminEmail")) ;
          String serv = Constants.REDIRECTTO ;
          m.setSubj( "Change Alert from " + serv + " on refSeqId " + rseq.getRefSeqId() ) ;
          String body = "Changes have been made to database\n"+
                  "Server: " + serv + "\n"+
                  "ID: " + rseq.getRefSeqId() + "\n"+
                  "Database name: " + rseq.getDatabaseName() + "\n"+
                  "Name: " + rseq.getRefseqName() + "\n"+
                  "Description: " + rseq.getDescription() + "\n"+
                  "Species: " + rseq.getRefseq_species() + "\n"+
                  "Version: " + rseq.getRefseq_version() + "\n\n" ;
          for(int i=0 ; i<vEml.size() ; i++ )
          {
            body = body + ((String)vEml.elementAt(i)) + "\n" ;
          }
          if(deleteFrefs.size() > 0)
          {
            body += "The following chromosomes has been deleted " + deletedRids ;
          }
          m.setBody( body ) ;
          m.go() ;
        }

        CacheManager.clearCache( db, rseq ) ;
        mys.removeAttribute( Constants.SESSION_DATABASE_ID ) ;
        mys.removeAttribute( "editEP" ) ;
        mys.removeAttribute( "editStart" ) ;
        mys.removeAttribute( "editStop" ) ;
        mys.removeAttribute( "uploadGroupId" ) ;
        mys.removeAttribute( "lastBrowserView" ) ;
      }
    }
  }
  timer.addMsg("DONE - got fref info (if needed)") ;
  rsTempls = new RefseqTemplate[0] ;
  rsTemplId = "#" ;

  if(userRoleCanEditRefseqInfo)
  {
    rsTempls = RefseqTemplate.fetchAll( db ) ;
    db.clearLastError() ;
    rsTemplId = request.getParameter( "rsTemplId" ) ;
    if( rsTemplId == null )
    {
      rsTemplId = "#" ;
    }
  }

  if(rseq == null)
  {
    // Find our rst object in here (STUPID WAY TO DO THINGS)
    for(int i=0 ; i<rsTempls.length ; i++ )//
    {
      if( rsTempls[i].getRefseqTemplateId().equals(rsTemplId) )
      {
        rst = rsTempls[i] ;
        break ;
      }
    }

    if(rst != null)
    {
      rseq_descr = rst.getDescription() ;
      rseq_species = rst.getSpecies() ;
      rseq_ver = rst.getVersion() ;

      String refSeqId = GenboreeUtils.fetchRefseqIdForTemplateDatabase(rsTemplId) ;
      String databaseName = GenboreeUtils.fetchMainDatabaseName(refSeqId) ;
      Connection   nConn = db.getConnection(databaseName) ;
      totalFrefCount = DbFref.countAll(nConn) ;

      if(totalFrefCount <= Constants.GB_MAX_FREF_FOR_EDIT)
      {
        frefs = DbFref.fetchAll( nConn ) ;
      }
      else // too many, get some
      {
        frefs = DbFref.fetchAll( nConn, Constants.GB_MAX_FREF_FOR_LIST) ;
      }
    }
    timer.addMsg("DONE - got rst info and entrypoints via rst if needed (rst = " + ((rst == null) ? "null" : rst.toString()) + ", totalRstEPCount = " + totalRstEPCount + ")" ) ;
  }

  // HANDLE SUBMISSION - CREATE & UPDATE
  if((request.getParameter("btnCreate") != null || request.getParameter("btncreate1") != null || request.getParameter("btnUpdate") != null))
  {
    if(userRoleCanEditRefseqInfo)
    {
      GenboreeMessage.clearMessage(mys) ;
      rseq_name = request.getParameter("rseq_name") ;
      if( rseq_name == null )
      {
        rseq_name = "" ;
      }
      else
      {
        rseq_name = rseq_name.trim() ;
      }
      int refseqExist = RefSeqTable.hasRefSeqName(rseq_name) ;
      if(refseqExist > 0 && rseq != null && (!rseq.getRefseqName().equalsIgnoreCase(rseq_name)))
      {
        ArrayList errlist = new ArrayList() ;
        errlist.add(  "<B>Please select a different 'Name', there is already a <i>" + rseq_name + "</i> db in use.</B>") ;
        GenboreeMessage.setErrMsg(mys, errMessage, errlist) ;
        need_create = false ;
      }
      else
      {
        if(Util.isEmpty(rseq_name))
        {
          ArrayList errlist = new ArrayList() ;
          errlist.add( "database name is empty" ) ;
          GenboreeMessage.setErrMsg(mys, errMessage, errlist  ) ;
        }
        else if(request.getParameter("btnUpdate") != null)
        {
          need_update = true ;
        }
        rseq_descr = request.getParameter( "rseq_descr" ) ;
        rseq_species = request.getParameter( "rseq_species" ) ;
        rseq_ver = request.getParameter( "rseq_ver" ) ;
        need_create = true ;
      }
    }
    if(JSPErrorHandler.checkErrors(request,response, db,mys)) return ;
  }

  // Do actual DB CREATE, if handler above indicated it's needed
  if(need_create && rseq == null && userRoleCanEditRefseqInfo)
  {
    if(createSuccess && accountCodeOk)
    {
      String myTemplateId = null ;
      if(rsTemplId != null && !rsTemplId.equalsIgnoreCase("#"))
      {
        myTemplateId = rsTemplId ;
      }
      DatabaseCreator dbC = new DatabaseCreator(new DBAgent(), groupId, myself.getUserId(), null,
                            myTemplateId,rseq_name, rseq_descr, rseq_species, rseq_ver, true) ;
      rseqs = Refseq.fetchAll( db, grps ) ;
      String newRefSeqIdStr = dbC.getRefSeqId() ;
      // associate new database with account, if that feature is turned on
      if(useAccounts)
      {
        int newRefSeqId = -1 ;
        try
        {
          newRefSeqId = Integer.parseInt(newRefSeqIdStr) ;
          int numUpdated = Refseq2AccountTable.associateDatabaseWithAccount(newRefSeqId, accountId, conn) ;
          if(numUpdated != 1)
          {
            System.err.println("ERROR: myrefseq.jsp => refseqId not properly associated with 1 accountId when creating this database." +
                               "(refseqId: " + newRefSeqId + ", accountId: " + accountId + ", numUpdated: " + numUpdated + ")") ;
          }
        }
        catch(Exception ex)
        {
          System.err.println("ERROR: myrefseq.jsp => probably exception converting refseqId value to an integer. (refseqId: " + newRefSeqId + ", accountId: " + accountId + ")") ;
          ex.printStackTrace(System.err) ;
        }
      }
      SessionManager.setSessionDatabaseId(mys, dbC.getRefSeqId()) ;
      mys.removeAttribute("lastBrowserView") ;
      need_reload = true ;
      GenboreeMessage.setSuccessMsg(mys,  "<B>The  database \"" + rseq_name + "\" was created successfully.</B>" ) ;
      createSuccess = true ;
    }
    else
    {
      GenboreeMessage.setErrMsg(mys, accountErrStr) ;
    }
  }
  // Do actual DB UPDATE, if handler above indicated it's needed
  else if( rseq != null && need_update && userRoleCanEditRefseqInfo )
  {
    int refseqExist = RefSeqTable.hasRefSeqName(rseq_name) ;
    if(refseqExist > 1 && (!rseq.getRefseqName().equalsIgnoreCase(rseq_name)))
    {
      GenboreeMessage.setErrMsg( mys, "<B>Please select a different Name there is already a <i>" + rseq_name + "</i> db in use.</B>" ) ;
    }
    else
    {
      rseq.setRefseqName( rseq_name ) ;
      rseq.setDescription( rseq_descr ) ;
      rseq.setRefseq_species( rseq_species ) ;
      rseq.setRefseq_version( rseq_ver ) ;
      rseq.update( db ) ;
      GenboreeMessage.setSuccessMsg(mys, "<B>The selected database was updated successfully.</B>") ;
    }
    if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return ;
  }
  // Do actual DELETE of user database, if handler above indicated it's needed
  else if( request.getParameter("btnDropDatabase") != null && rseq != null && userRoleIsGroupAdmin )
  {
    GenboreeMessage.clearMessage(mys) ;
    boolean del_yes = (request.getParameter("askYes") != null) ;
    boolean del_no = (request.getParameter("askNo") != null) ;
    if( !del_yes && !del_no )
    {
      mys.setAttribute( "target", "myrefseq.jsp" ) ;

      String quest = "<br><font color=\"red\" size=\"+1\">" +
              "<strong>ATTENTION!</strong></font><br>\n" +
              "You are about to PERMANENTLY delete the database " +
              "&laquo;<strong>" +
              Util.htmlQuote(rseq.getRefseqName()) +
              "</strong>&raquo;<br>\n" +
              "All the data in the database will be lost FOREVER.<br><br>\n" +
              "Are you willing to proceed?<br><br>\n" ;

      mys.setAttribute( "question", quest ) ;
      mys.setAttribute(
        "form_text",
        "<input type=\"hidden\" name=\"btnDropDatabase\" id=\"btnDropDatabase\" " +
        "value=\"d\">\n" +
        "<input type=\"hidden\" name=\"group_id\" id=\"group_id\" value=\"" +
        grp.getGroupId()+"\">\n" +
        "<input type=\"hidden\" name=\"rseq_id\" id=\"rseq_id\" value=\"" +
        rseq.getRefSeqId()+"\">" ) ;
      GenboreeUtils.sendRedirect(request,response,  "/java-bin/ask.jsp" ) ;
      return ;
    }

    // Do the real delete of the database (user confirmed the delete)
    if( del_yes )
    {
      // If using accounts feature, remove the association of the user database with a particular account
      if(useAccounts)
      {
        // get refseq as the int it really is
        int refSeqId = -1 ;
        try
        {
          refSeqId = Integer.parseInt(rseq.getRefSeqId()) ;
          int numDeleted = Refseq2AccountTable.unassociateDatabaseWithAccount(refSeqId, conn) ;
          if(numDeleted != 1)
          {
            System.err.println("ERROR: myrefseq.jsp => refseqId not properly unassociated with account when deleting this database." +
                               "(refseqId: " + refSeqId + ", accountId: " + accountId + ", numUpdated: " + numDeleted + ")") ;
          }
        }
        catch(Exception ex)
        {
          System.err.println("ERROR: myrefseq.jsp => probably exception converting refSeqId string to the integer it is.") ;
        }
      }
      rseq.delete( db ) ;
      mys.removeAttribute( "lastBrowserView" ) ;
      SessionManager.setSessionDatabaseId(mys, null) ;
      SessionManager.setSessionDatabaseName(mys, null) ;
      GenboreeMessage.setSuccessMsg(mys, "<b>Database \""  +  rseq.getRefseqName() + "\" was deleted successfully. </b>") ;
      rseq = null ;
      rseq_id = "#" ;
      need_reload = true ;
      rseq_name = "" ;
      rseq_descr = "" ;
      rseq_species = "" ;
      rseq_ver = "" ;
      rstEps = null ;
      mode = MODE_DELETE ;
    }
    timer.addMsg("DONE - delete a database stuff (if needed)") ;
  }

  // Some actions above trigger a reload of the page.
  if( need_reload )
  {
    grp.fetchRefseqs( db ) ;
    if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return ;

    rseqs = Refseq.fetchAll( db, grps ) ;
    if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return ;
    if( rseqs == null )
    {
      rseqs = new Refseq[0] ;
    }
    v = new Vector() ;
    for(int i=0 ; i<rseqs.length ; i++ )
    {
      Refseq rs = rseqs[i] ;
      if( grp.belongsTo(rs.getRefSeqId()) )
      {
        v.addElement( rs ) ;
      }
    }
    rseqs = new Refseq[ v.size() ] ;
    v.copyInto( rseqs ) ;
    rseq_id = SessionManager.getSessionDatabaseId(mys) ;

    for(int i=0 ; i<rseqs.length ; i++ )
    {
      if( rseqs[i].getRefSeqId().equals(rseq_id) )
      {
        rseq = rseqs[i] ;
        break ;
      }
    }

    if(rseq == null)
    {
      if(rseqs.length > 0)
      {
        rseq = rseqs[0] ;
      }
    }
  }

  if(rseq != null && userRoleCanEditRefseqInfo)
  {
    v = new Vector() ;
    Hashtable ht = new Hashtable() ;
    ht.put( grp.getGroupId(), "y" ) ;

    for(int i=0 ; i<rwGrps.length ; i++ )
    {
      GenboreeGroup cgrp = rwGrps[i] ;
      if( ht.get(cgrp.getGroupId()) != null ) continue ;
      v.addElement( cgrp ) ;
      ht.put( cgrp.getGroupId(), "y" ) ;
      if(pubGrp != null && cgrp.getGroupId().equals(pubGrp.getGroupId()))
      {
        pubGrp = cgrp ;
        mys.setAttribute( "public_group", pubGrp ) ;
      }
    }
    if(pubGrp != null && ht.get(pubGrp.getGroupId()) == null)
    {
      v.addElement( pubGrp ) ;
    }
    timer.addMsg("DONE - group info stuff" ) ;
  }

  if(rseq != null && request.getParameter("btnDbToGroup") != null)
  {
    Hashtable ht = new Hashtable() ;
    String[] gids = request.getParameterValues( "rseq_group_id" ) ;

    if( gids != null )
    {
      for(int i=0 ; i<gids.length ; i++)
      {
        ht.put( gids[i], "y" ) ;
      }
    }

    for(int i=0 ; i<v.size() ; i++ )
    {
      GenboreeGroup g = (GenboreeGroup) v.elementAt(i) ;
      boolean need_add = (ht.get(g.getGroupId()) != null) ;
      boolean is_added = g.belongsTo(rseq.getRefSeqId()) ;

      if( need_add != is_added )
      {
        db.executeUpdate(
          null, need_add ?
          "INSERT INTO grouprefseq (groupId, refSeqId) " +
          "VALUES (" + g.getGroupId() + ", " + rseq.getRefSeqId() + ")" :
          "DELETE FROM grouprefseq " +
          "WHERE groupId=" + g.getGroupId() + " AND refSeqId="+rseq.getRefSeqId()) ;
        g.fetchRefseqs( db ) ;
        db.executeUpdate(
          null, need_add ?
          "UPDATE refseq SET public=1 " +
          "WHERE refSeqId = " + rseq.getRefSeqId() :
          "UPDATE refseq SET public=0 " +
          "WHERE refSeqId = " + rseq.getRefSeqId()) ;
        g.fetchRefseqs( db ) ;
      }
    }
    mode = MODE_DEFAULT ;
    timer.addMsg("DONE - insert values into grouprefseq table ") ;
  }

  if(rseq != null)  // Then get database details
  {
    rseq_id = rseq.getRefSeqId() ;
    rseq_name = rseq.getRefseqName() ;
    rseq_descr = rseq.getDescription() ;
    rseq_species = rseq.getRefseq_species() ;
    rseq_ver = rseq.getRefseq_version() ;
    String databaseName = GenboreeUtils.fetchMainDatabaseName(rseq_id) ;
    mys.setAttribute( "uploadRefseq", rseq ) ;
    mys.setAttribute( "uploadRefseqId", rseq_id ) ;
    mys.setAttribute( Constants.SESSION_DATABASE_ID, rseq_id ) ;
    mys.setAttribute( Constants.SESSION_GROUP_ID, groupId) ;

    if(frefs == null && databaseName != null) // then we need to fill in some frefs
    {
      // Make sure we have an annotation db connection
      tConn = db.getConnection(databaseName) ;
      if(tConn != null && totalFrefCount <= Constants.GB_MAX_FREF_FOR_EDIT)
      {
          frefs = DbFref.fetchAll( tConn ) ;
      }
      else if(tConn != null && totalFrefCount > Constants.GB_MAX_FREF_FOR_EDIT)// too many, get some
      {
          frefs = DbFref.fetchAll( tConn, Constants.GB_MAX_FREF_FOR_LIST) ;
      }
    }
  }

  if(rseq != null)
  {
    db_public = pubGrp.belongsTo(rseq.getRefSeqId()) ;
  }

  // User wants to upload annos. Redirect to upload annos page.
  if(request.getParameter("btnUploadTracks") != null && rseq != null)
  {
    if( rseq==null && rseqs.length>0 )
    {
      GenboreeMessage.setErrMsg(mys, "Please select a database" ) ;
    }
    else
    {
      mys.setAttribute( "uploadStudent", new Integer(2) ) ;
      GenboreeUtils.sendRedirect(request,response,  "/java-bin/upload.jsp" ) ;
      return ;
    }
  }

  mys.removeAttribute( "featuretypes" ) ;
  mys.setAttribute( "destback", "myrefseq.jsp" ) ;

  // BEGIN: Display appropriate page contents
  boolean need_db_list = (rseqs.length>0) ;
  boolean need_db_details = (rseq != null) ;
  boolean db_details_editable = false ;
  db_msg = need_db_list ? null : "No Databases available in this group" ;
  boolean need_button = need_db_details ;
  boolean need_upload_rs = true ;
  boolean need_noacs_msg = false ;
  boolean need_eps = false ;

  // INIT: state for each mode so appropriate things get done.
  switch( mode )
  {
    case MODE_CREATE:
      need_db_details = true ;
      need_upload_rs = false ;
      need_db_list = false ;
      db_details_editable = true ;
      need_button = true ;
      need_eps = true ;

      // Set the correct message...if accounts feature is turned on, then check for an account-related error first
      if(userRoleCanEditRefseqInfo || isAdmin)
      {
        if(useAccounts && accountErrStr != null)
        {
          db_msg = accountErrStr ;
        }
        else
        {
          db_msg = "-- Create New Database --" ;
        }
      }
      else
      {
        need_button = false ;
        need_db_details = false ;
        need_eps = false ;
        need_noacs_msg = true ;
        db_msg = "Sorry, your role in this group does not permit the creation of new databases." ;
        GenboreeMessage.setErrMsg(mys, db_msg) ;
      }
      break ;
    case MODE_UPDATE:
      need_upload_rs = false ;
      need_eps = true ;
      db_details_editable = true ;
      if(!isAdmin || !userRoleCanEditRefseqInfo)
      {
        need_upload_rs = false ;
        rstEps = null ;
        need_eps = false ;
        need_db_list = false ;
        need_noacs_msg = true ;
        need_button = false ;
        need_db_details = false ;
        db_msg = "Sorry, you have no rights to update databases in this group." ;
        GenboreeMessage.setErrMsg(mys, db_msg) ;
      }
      break ;
    case MODE_DELETE:
      need_db_list = true ;
      need_upload_rs = false ;
      need_eps = false ;
      // Set the correct message...if accounts feature is turned on, then check for an account-related error first
      if(useAccounts && accountErrStr != null)
      {
        db_msg = accountErrStr ;
      }
      else if(!isAdmin || !userRoleIsGroupAdmin)
      {
        rstEps = null ;
        frefs = null ;
        need_db_list = false ;
        need_button = false ;
        need_db_details = false ;
        need_noacs_msg = true ;
        db_msg = "Sorry, you do not have sufficient privileges to delete entirre databases. Please ask you group admin to remove the entire database." ;
        GenboreeMessage.setErrMsg(mys, db_msg) ;
      }
      break ;
    case MODE_DEFAULT:
      need_db_list = true ;
      need_eps = true ;
      need_upload_rs = false ;
      need_button = false ;
      edit_frefs = false ;
      break ;
    case MODE_UPLOAD:
      need_upload_rs = true ;
      need_eps = true ;
      need_db_list= true ;
      if(!isAdmin || !userRoleCanEditRefseqInfo)
      {
        rstEps = null ;
        need_eps = false ;
        need_db_details = false ;
        need_noacs_msg = true ;
        db_msg = "Sorry, you have no rights to upload to this database." ;
      }
      break ;
    case MODE_UPLOADEPS:
      need_upload_rs = true ;
      need_eps = true ;
      need_db_list = true ;
      if(!isAdmin && !userRoleCanEditRefseqInfo)
      {
        rstEps = null ;
        need_eps = false ;
        need_db_details = false ;
        need_noacs_msg = true ;
        db_msg = "Sorry, you have no rights to upload to this database." ;
      }
      break ;
    case MODE_PUBLISH:
      need_db_list = true ;
      need_eps = false ;
      if(userRoleIsGroupAdmin)
      {
        need_db_details = true ;
      }
      else
      {
        need_db_details = false ;
        need_noacs_msg = true ;
        db_msg = "Sorry, you do not have sufficient privileges to public this database to the world. Please ask your group admin to publish the database for public access." ;
      }
      rstEps = null ;
      need_upload_rs = false ;
      break ;
    case MODE_UNLOCK:
      need_db_list = true;
      need_eps = false;
      need_button = false;
      need_db_details = false;
      if(!i_am_owner)
      {
        need_noacs_msg = true;
        db_msg = "Sorry, you have no rights to publish this database.";
      }
      rstEps = null;
      need_upload_rs = false;
      break;
    default:
      need_upload_rs = false ;
      need_eps = true ;
      break ;
  }

  if( request.getParameter("cancel1") != null  || request.getParameter("btnCancel") != null )
  {
    mode= MODE_UPDATE ;
    need_eps = true ;
    edit_frefs = false ;
  }

// GENERATE APPROPRIATE HTML
%>
<%@  include file="include/sessionGrp.incl" %>
<HTML>
<head>
<title>Genboree - User Database Management</title>
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html ; charset=iso-8859-1'>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/loading-genboree.css<%=jsVersion%>">
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/prototype.js?jsVer=<%=jsVersion%>" ></script>
  <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/ext-prototype-adapter.js?jsVer=<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/extjs/ext-all.js?jsVer=<%=jsVersion%>"></script>
  <!-- Set a local "blank" image file; default is a URL to extjs.com -->
  <script type='text/javascript'>
    Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
  </script>
  <script type="text/javascript" src="/javaScripts/myrefseq.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/progressUpload.js<%=jsVersion%>"></script>

</head>
<BODY>
<!-- Placeholders for upload message -->
<div id="genboree-loading-mask" name="genboree-loading-mask" style="visibility: hidden;"></div>
<div id="genboree-loading" name="genboree-loading" style="visibility: hidden;"></div>
<%@ include file="include/header.incl" %>
<form  name="test" id="test" action="myrefseq.jsp" >
<%@ include file="include/navbar.incl" %>
<table border="0" cellspacing="4" cellpadding="2">
<tr>
<%
  for(int i=0 ; i<modeIds.length ; i++ )
  {
    String cls = "nav" ;
    String a1 = "<a href=\"myrefseq.jsp?mode=" + modeIds[i] + "\">" ;
    String a2 = "</a>" ;
    if( i == mode )
    {
      cls = "nav_selected" ;
      a1 = a2 = "" ;
    }
%>
    <td class="<%=cls%>"><%=a1%><%=modeLabs[i]%><%=a2%></td>
<%
  }
%>
  <td class="nav"><a href="trackmgr.jsp">Manage&nbsp;Tracks</a></td>
  <td class="nav"><a href="linkmgr.jsp">Link&nbsp;Setup</a></td>
</tr>
</table>
</form>
<%
  if( rseq != null )
  {
%>
    <form name="dnld" action="download.jsp" method="post">
      <input type="hidden" name="refSeqId" id="refSeqId" value="<%=rseq.getRefSeqId()%>">
      <input type="hidden" name="ckEntire" id="ckEntire" value="y">
    </form>
<%
  }
%>
<div id="gbmsg" style="display:block" >
  <%@ include file="include/message.incl"%>
</div>

<div id="db0" style="display:block">
  <form name="usrfsq" id="usrfsq" action="" method="post" onsubmit="init(<%=mode%>) ;">
<%
  if(mode != MODE_DEFAULT )
  {
%>
    <input type="hidden" name="mode" id="mode" value="<%=modeIds[mode]%>">
<%
  } // if( mode != MODE_DEFAULT )
%>
  <table border="0" cellpadding="4" cellspacing="2" width="100%">
<%
  // Add segment for entering account code which is necessary for creating databases
  if(useAccounts)
  {
    // If creating and have permission to create, we need this...otherwise not
    if( mode==MODE_CREATE && userRoleCanEditRefseqInfo )
    {
%>
      <tr>
        <td class="form_header">
          Genboree Account Code
        </td>
        <td class="form_header">
          <input class="txt" type="text" name="accountCode" id="accountCode" size="68" maxlength="255" value="<%=Util.htmlQuote(accountCode)%>">
        </td>
      </tr>
<%
    }
  }
%>
  <!-- Group selection -->
  <tr>
<%
    if(rwGrps.length == 1)
    {
%>
      <td class="form_header">
        <strong>Group</strong>
        <input type="hidden" name="group_id" id="group_id" value="<%=groupId%>">
      </td>
      <td class="form_header">
        <%=Util.htmlQuote(grp.getGroupName())%>
        &nbsp;&nbsp;<font color="#CCCCFF">Role:</font>&nbsp;&nbsp;<%=myGrpAccess%>
      </td>
<%
    }
    else
    {
%>
      <%@ include file="include/groupbar.incl"%>
<%  }   %>
    </tr>
    <tr>
      <td colspan="2" style="height:12"></td>
    </tr>
<%
    if (rseqs == null || rseqs.length ==0 )
    {
      SessionManager.clearSessionDatabase(mys) ;
    }

    String tf_disabled = db_details_editable ? "" : "disabled" ;
%>
    <script>
      var dbNames = new Array() ;
<%
      for(int i=0 ; i<rseqs.length ; i++ )
      {
%>
        dbNames[<%=i%>] =  "<%=rseqs[i].getRefseqName()%>" ;
<%    }   %>
    </script>
<%
    if( need_db_list )
    {
%>
      <tr>
        <%@ include file="include/databaseBar.incl"%>
      </tr>
<%
    }

    if (need_noacs_msg )
    {
%>
      <tr>
        <td  colspan="2">
          <input type="hidden" name="rseq_id" id="rseq_id" value="#">
        </td>
      </tr>
<%
    }
%>

<% if(mode == MODE_UNLOCK) { %>
  <tr>
    <td colspan="2">
<%
           // Key variables:
            String urlStr = null ;
            boolean doHtmlStripping = true ;
            String contentUrl = null ; // String to store the entire content of an URL using getContentOfUrl(urlStr )
            String refSeqId = null ; // Not needed here, but staticContent.incl expects the variable
            String currPageURI = request.getRequestURI() ;
            String groupAllowed = null ;
            // REBUILD the request params we will pass to RHTML side (via a POST)
            Map paramMap = request.getParameterMap() ; // "key"=>String[]
            StringBuffer postContentBuff = new StringBuffer() ;
            // 1.a Send the userId, whether on form or not
            postContentBuff.append("userId=").append(Util.urlEncode(userInfo[2])) ;
            // Need to send the group_id when it's not post'd
            postContentBuff.append("&group_id=").append(Util.urlEncode(groupId)) ;
            postContentBuff.append("&refseq_id=").append(Util.urlEncode(rseq_id)) ;
            postContentBuff.append("&grpChangeState=").append(Util.urlEncode(grpChangeState)) ;

            // 1.b Loop over request key-value pairs, append them to rhtml request:
            Iterator paramIter = paramMap.entrySet().iterator() ;
            while(paramIter.hasNext())
            {
              Map.Entry paramPair = (Map.Entry) paramIter.next() ;
              String pName = Util.urlEncode((String) paramPair.getKey()) ;
              String[] pValues = (String[]) paramPair.getValue() ; // <-- Array!
              if(pValues != null)
              { // then there is 1+ actual values
                for(int ii = 0; ii < pValues.length; ii++)
                { // Add all of the values to the POST
                  postContentBuff.append("&").append(pName).append("=").append(URLEncoder.encode(pValues[ii], "UTF-8")) ;
                }
              }
              else // no value, just a key? ok...
              {
                postContentBuff.append("&").append(pName).append("=") ;
              }
            }
            // 1.c Get the string we will post IF that's what we will be doing
            String postContentStr = postContentBuff.toString() ;

            String uriPath = request.getRequestURI().replaceAll("/[^/]+\\.jsp.*$", "") ;
            urlStr = myBase + sourceFileArr[mode] ;
            HashMap hdrsMap = new HashMap() ;
            // Do as a POST
            contentUrl = GenboreeUtils.postToURL(urlStr, postContentStr, doHtmlStripping, hdrsMap, mys ) ;
            // Update group/database if correct X-HEADERS are found:
            GenboreeUtils.updateSessionFromXHeaders(hdrsMap, mys) ;
            // Write out content of other page
            out.write(contentUrl) ;
%>

    </td>
  </tr>
<% } %>

<%
    if( mode==MODE_CREATE && userRoleCanEditRefseqInfo )
    {
%>
      <!-- RefSeq template -->
      <tr>
        <td class="form_body">
          <strong>Reference&nbsp;Sequence</strong>
        </td>
        <td class="form_body">
          <select name="rsTemplId" id="rsTemplId" onchange='this.form.submit()'  class="txt" style="width:300">
            <option value="#"> ** User Will Upload ** </option>
<%
              if(rsTempls != null)
              {
                Arrays.sort(rsTempls, new Comparator()
                {
                  public int compare(Object aa, Object bb)
                  {
                    return (((RefseqTemplate)aa).getName()).compareToIgnoreCase(((RefseqTemplate)bb).getName()) ;
                  }
                }) ;
              }
              for(int i=0 ; i<rsTempls.length ; i++ )
              {
                String myId = rsTempls[i].getRefseqTemplateId() ;
                String sel = myId.equals(rsTemplId) ? " selected" : "" ;
%>
                <option value="<%=myId%>" <%=sel%>><%=rsTempls[i].getName()%></option>
<%            }   %>
          </select><br>
        </td>
      </tr>
<%
    }

    // Show details of the database if needed
    if( need_db_details )
    {
      if(Util.isEmpty(rseq_name))
      {
        rseq_name = request.getParameter( "rseq_name" ) ;
      }
      else if( rseq_name == null )
      {
        rseq_name = "" ;
      }
      else
      {
        rseq_name = rseq_name.trim() ;
      }
%>
      <tr>
        <td class="form_body">
          <strong>Database&nbsp;Name&nbsp;(*)</strong>
        </td>
        <td class="form_body">
          <input type="text" readonly style="background-color: #dcdcdc ;" name="rseq_name00" id="rseq_name00" size="68" maxlength="255" class="txt" <%=tf_disabled%> value="<%=Util.htmlQuote(rseq_name)%>">
        </td>
      </tr>
      <tr>
        <td class="form_body">
          <strong>Description</strong>
        </td>
        <td class="form_body">
          <input type="text"  readonly style="background-color: #dcdcdc ;"  name="rseq_descr00" id="rseq_descr00" size="68" maxlength="255" class="txt" <%=tf_disabled%> value="<%=Util.htmlQuote(rseq_descr)%>"  >
        </td>
      </tr>
      <tr>
        <td class="form_body">
          <strong>Species</strong>
        </td>
        <td class="form_body">
          <input type="text" readonly  style="background-color: #dcdcdc ;" name="rseq_species00" id="rseq_species00" size="68" maxlength="255" class="txt" <%=tf_disabled%> value="<%=Util.htmlQuote(rseq_species)%>">
        </td>
      </tr>
      <tr>
        <td class="form_body">
          <strong>Version</strong>
        </td>
        <td class="form_body">
          <input readonly  style="background-color: #dcdcdc ;" type="text" name="rseq_ver00" id="rseq_ver00" size="68" maxlength="255" class="txt" <%=tf_disabled%> value="<%=Util.htmlQuote(rseq_ver)%>">
        </td>
      </tr>
<%  } // if( need_db_details ) %>

    <!-- buttons -->
    <tr>
      <td colspan="2">
<%
        boolean db_ready = ( rseq != null && ((frefs != null && frefs.length>0) || (rstEps!=null && rstEps.length>0)) ) ;
        String btnId = "btnCreate" ;
        String btnLab = "Create" ;
        String btnOnClick = "" ;
        String btnType = "submit" ;

        if(need_button)
        {
          if(mode == MODE_UPDATE)
          {
            btnId = "btnUpdate" ;
            btnLab = "Edit Database Info" ;
          }
          else if( mode == MODE_DELETE )
          {
            btnId = "btnDropDatabase" ;
            btnLab = "Delete" ;
          }
          else if(mode == MODE_PUBLISH)
          {
            if(userRoleIsGroupAdmin && rseq != null)
            {
              btnId = "btnDbToGroup" ;
              btnLab = db_public ? unPublish : publish ;
%>
                <input type="hidden" name="rseq_group_id" id="rseq_group_id" <%= db_public ? "" : "value=\"" + pubGrp.getGroupId() + "\"" %>>
<%
            }
            else
            {
              need_button = false ;
            }
          }
          else if(mode == MODE_UPLOAD)
          {
            if(db_ready && isAdmin)
            {
              btnId = "btnUploadTracks" ;
              btnLab = "Upload Data Tracks" ;
            }
            else
            {
              need_button = false ;
            }
          }
          else if(mode == MODE_UPLOADEPS)
          {
            need_button = false ;
          }
        }
%>
        <div id="button_set1" style="float: left ; width: 95% ;" >
<%
          if(need_button && mode == MODE_UPDATE)
          {
%>
            <input type="submit" name="btnUpdate" id="btnUpdate" class="btn" value="Edit Database Info" onClick=" return displaydb() ;">&nbsp;
<%        }
          else if(need_button &&  mode != MODE_UPDATE )
          {
%>
            <input type="<%=btnType%>" name="<%=btnId%>" id="<%=btnId%>" class="btn" value="&nbsp;<%=btnLab%>&nbsp;"<%=btnOnClick%>>&nbsp;
<%        }
          else if(mode == MODE_DEFAULT &&  totalFrefCount > 0)
          {
%>
            <input type="button" class="btn" onClick="javascript:document.dnld.submit()" value="Download">
<%        }

          if( mode == MODE_UPDATE && userRoleCanEditRefseqInfo )
          {
            if(totalFrefCount > 0 && totalFrefCount < Constants.GB_MAX_FREF_FOR_EDIT)
            {
%>
              <input type="button"  class="btn" value="Rename Entry Points" onClick=" return displayEP() ;">
              <input type="button"  class="btn" value="Delete Entry Points" onClick=" return deleteEP() ;">
<%
            }
          }
%>
          <input type="submit" name="btnCancel" id="btnCancel" class="btn" value="&nbsp;Cancel&nbsp;">
        </div>

<%
        // Add help icon for the topic, if available/appropriate
        if(mode == MODE_UPLOAD )
        {
%>
          <DIV style="float: right ; width: 5% ; text-align: right ;">
            <A HREF="showHelp.jsp?topic=uploadAnnoHowto" target="_helpWin">
            <IMG class="" style="vertical-align: top ;" SRC="/images/gHelp1.png" BORDER="0" WIDTH="16" HEIGHT="16"></A>
          </DIV><BR CLEAR="all">
<%      }   %>
      </td>
    </tr>
    </table>
  </form>
</div>
<style>
.instruction {
background-color:#EFEFEF;
border:1px dashed #CCCCCC;
color:#4C3D99;
font-size:110%;
font-style:normal;
font-weight:normal;
margin-bottom:0;
margin-top:0;
padding:3px;
}
.instruction p {
  line-height:130%;
}
</style>
<div class="instruction">
	<p style="padding-top:10px;">
		<b><font color="red">Some of the Database related features have been relocated to the Genboree Workbench page.</font></b>
	</p>
	<p>
		To go to the Genboree workbench, just click on the <a href="workbench.jsp">Workbench link</a> in the menubar above.
	</p>
	<p>
		Below are a few images which show how to access the Database functionality on the Workbench page.
	</p>
	<ul>
		<li><a href="#createDb">CREATE</a></li>
		<li><a href="#editDb">EDIT, UNLOCK AND PUBLISH</a></li>
		<li><a href="#deleteDb">DELETE</a></li>
		<li><a href="#uploadAnnos">UPLOAD ANNOTATIONS</a></li>
		<li><a href="#eps">CHROMOSOME/ENTRYPOINT: upload, delete and edit</a></li>
	</ul>
	<div align="center" style="padding-top:10px;">
		<p>
			<a name="createDb"><b>CREATE:</b></a>
		</p>
		<img  style="padding-top:5px;" src="http://<%=serverName%>/java-bin/screenshots/createDbScaled.png" />
	</div>
	<div align="center" style="padding-top:10px;">
			 <p>
				<a name="editDb"><b>EDIT, UNLOCK and PUBLISH:</b></a>
			</p>
			<img style="padding-top:5px;" src="http://<%=serverName%>/java-bin/screenshots/publishRetractDbScaled.png" />
	</div>
	<div align="center" style="padding-top:10px;">
		 <p>
			<a name="deleteDb"><b>DELETE:</b></a>
		</p>
		<img style="padding-top:5px;" src="http://<%=serverName%>/java-bin/screenshots/deleteDbScaled.png" />
	</div>
	<div align="center" style="padding-top:10px;">
		 <p>
			<a name="uploadAnnos"><b>UPLOAD ANNOTATIONS:</b></a>
		</p>
		<img style="padding-top:5px;" src="http://<%=serverName%>/java-bin/screenshots/uploadAnnosScaled.png" />
	</div>
	<div align="center" style="padding-top:10px;">
		 <p>
			<a name="eps"><b>CHROMOSOME/ENTRYPOINT: upload, delete and edit:</b></a>
		</p>
		<img style="padding-top:5px;" src="http://<%=serverName%>/java-bin/screenshots/epScaled.png" />
	</div>
</div>
<div id="db1" style="display:none;">
  <form name="usrfsq" id="usrfsq" action="myrefseq.jsp" method="post" onSubmit="return checkState() ; " >
<%
    if(mode != MODE_DEFAULT )
    {
%>
     <input type="hidden" name="mode" id="mode" value="<%=modeIds[mode]%>">
<%
    } // if( mode != MODE_DEFAULT )
%>

    <table border="0" cellpadding="4" cellspacing="2" width="100%">
<%
    // Add segment for entering account code which is necessary for creating databases
    if(useAccounts && mode == MODE_CREATE && userRoleCanEditRefseqInfo)
    {
%>
      <tr>
        <td class="form_header">
          Genboree Account Code
        </td>
        <td class="form_header">
          <input class="txt" type="text" name="accountCode" id="accountCode" size="68" maxlength="255" value="<%=Util.htmlQuote(accountCode)%>">
        </td>
      </tr>
<%
    }
%>
    <!-- Group selection -->
    <tr>
<%
      if(rwGrps.length == 1)
      {
%>
        <td class="form_header">
          <strong>Group</strong>
          <input type="hidden" name="group_id" id="group_id" value="<%=groupId%>">
        </td>
         <td class="form_header">
            <%=Util.htmlQuote(grp.getGroupName())%>
            &nbsp;&nbsp;<font color="#CCCCFF">Role:</font>&nbsp;&nbsp;<%=myGrpAccess%>
         </td>
<%
      }
      else
      {
%>
        <%@ include file="include/groupbar.incl"%>
<%    }   %>
    </tr>
    <tr>
      <td colspan="2" style="height:12"></td>
    </tr>
    <!-- DB selection -->
    <tr>
<%
      if(need_db_list)
      {
%>
        <%@ include  file="include/databaseBar.incl" %>
<%
      }  // need_db_list

      if(need_noacs_msg)
      {
%>
        </tr>
        <tr>
        <td  colspan="2">
          <input type="hidden" name="rseq_id" id="rseq_id" value="#">
        </td>
<%    }   %>
    </tr>
<%
      if(mode==MODE_CREATE && userRoleCanEditRefseqInfo)
      {
%>
        <!-- RefSeq template -->
        <tr>
          <td class="form_body">
            <strong>Reference&nbsp;Sequence</strong>
          </td>
          <td class="form_body">
            <select name="rsTemplId" id="rsTemplId" onchange='this.form.submit()'  class="txt" style="width:300">
              <option value="#"> ** User Will Upload ** </option>
<%
              for(int i=0; i<rsTempls.length; i++ )
              {
                String myId = rsTempls[i].getRefseqTemplateId();
                String sel = myId.equals(rsTemplId) ? " selected" : "";
%>
                <option value="<%=myId%>"<%=sel%>><%=rsTempls[i].getName()%></option>
<%            }   %>
            </select><br>
          </td>
        </tr>
<%    }

      // DB details
      if(need_db_details)
      {
%>
        <tr>
          <td class="form_body">
            <strong>Database&nbsp;Name&nbsp;(*)</strong>
          </td>
          <td class="form_body">
            <input type="text" name="rseq_name" id="rseq_name" size="68" maxlength="255" class="txt"  value="<%=Util.htmlQuote(rseq_name)%>"   onkeypress="processEvent(event);">
          </td>
        </tr>

        <tr>
          <td class="form_body">
            <strong>Description</strong>
          </td>
          <td class="form_body">
            <input type="text" name="rseq_descr" id="rseq_descr" size="68" maxlength="255" class="txt"  value="<%=Util.htmlQuote(rseq_descr)%>"   onkeypress="processEvent(event);" >
          </td>
        </tr>

        <tr>
          <td class="form_body">
            <strong>Species</strong>
          </td>
          <td class="form_body">
            <input type="text" name="rseq_species" id="rseq_species" size="68" maxlength="255" class="txt"  value="<%=Util.htmlQuote(rseq_species)%>"   onkeypress="processEvent(event);">
          </td>
        </tr>

        <tr>
          <td class="form_body">
            <strong>Version</strong>
          </td>
          <td class="form_body">
            <input type="text" name="rseq_ver" id="rseq_ver" size="68" maxlength="255" class="txt"  value="<%=Util.htmlQuote(rseq_ver)%>"  onkeypress="processEvent(event);">
          </td>
        </tr>
<%    }   // if( need_db_details ) %>
      <!-- buttons -->
      <tr>
        <td colspan="2">
          <div id="updateDBinfo" style="display:none">
<%
            if(mode==MODE_UPDATE)
            {
%>
              <input type="hidden" name="validDBName" id="validDBName" value="0">
              <input type="submit" name="btnUpdate" id="btnUpdate" class="btn" value="Apply"  onClick="checkDBName2(this.form, 'rseq_name', '<%=rseq_name%>')">&nbsp;
              <input type="button" name="btnDBCancel" id="btnDBCancel1" class="btn" value="&nbsp;Cancel&nbsp;" onCLick="cancelDBEdit(this.form, 'rseq_name');">
<%          }   %>
          </div>
          <div id="btnset2" style="display:none"  >
<%
            if(need_button && !is_ro_group && mode==MODE_UPDATE)
            {
%>
              <input type="Submit" name="btnUpdate" id="btnUpdate" class="btn" value="Edit Database Info"  >&nbsp;
  <%        } // if (need_button )
            else if(need_button && !is_ro_group && mode==MODE_CREATE)
            {
%>
              <input type="Submit" name="btncreate1" id="btncreate1" class="btn" value="Create"  onClick="return submitDB('rseq_name');" >&nbsp;
<%          } // if (need_button )
            else if(need_button && !is_ro_group && mode!=MODE_UPDATE  && mode!=MODE_CREATE)
            {
%>
              <input type="<%=btnType%>" name="<%=btnId%>" id="<%=btnId%>" class="btn" value="&nbsp;<%=btnLab%>&nbsp;"<%=btnOnClick%>>&nbsp;
<%
            } // if (need_button )
            else if(mode == MODE_DEFAULT &&  totalFrefCount > 0)
            {
%>
              <input type="button" class="btn" onClick="javascript:document.dnld.submit()" value="Download">
<%          }   %>

<%
            if(mode==MODE_UPDATE)
            {
              if(userRoleCanEditRefseqInfo)
              {
                if(totalFrefCount > 0 && totalFrefCount < Constants.GB_MAX_FREF_FOR_EDIT)
                {
%>
                  <input type="button"  class="btn" value="Rename Entry Points" onClick=" return displayEP();">
                  <input type="button"  class="btn" value="Delete Entry Points" onClick=" return deleteEP();">
<%              }
              }
%>
              <input type="button" name="btnCancel1" id="btnCancel1" class="btn" value="&nbsp;Cancel&nbsp;" onClick="displaytop();">
<%
            }
            else if(mode==MODE_CREATE)
            {
%>
              <input type="submit" name="btnCancel2" id="btnCancel2" class="btn" value="&nbsp;Cancel&nbsp;"   >
<%          }   %>
          </div>
        </td>
      </tr>
  </table>
</div>
<%
    if( mode == MODE_CREATE)
    {
%>
      <script>
        displayCreate() ;
      </script>
<%  }   %>
  </form>
</div>

<%
  // UPLOAD EPS
  if( mode == MODE_UPLOADEPS  && need_upload_rs && rseq != null && userRoleCanEditRefseqInfo )
  {
%>
    <form name="upldrs"  id="upldrs" action="/genbUpload/genboree/upload.rhtml" onsubmit="return uploadFormSubmitIt(this);" method="post" ENCTYPE="multipart/form-data">
      <input type="hidden" name="rm" value="upload">
      <input type="hidden" name="refseq" value="<%=rseq.getRefSeqId()%>">
      <input type="hidden" name="groups" value="<%=grp.getGroupId()%>">
      <input type="hidden" name="userId" value="<%=userInfo[2]%>">
      <input type="hidden" name="flags" id="flags" value="mydata">
      <input type="hidden" name="idStr" id="idStr" value="<%=System.currentTimeMillis()%>">
      <table border="0" cellpadding="4" cellspacing="2" width="100%">
      <tr>
          <td colspan="3" class="form_header">
            <%= ((rstEps==null || rstEps.length==0) && (frefs == null || frefs.length==0)) ? "Upload Your Entry Points" : "Add More Entry Points" %>
            <A HREF="showHelp.jsp?topic=uploadEPhowto" target="_helpWin">
            <SPAN class="subtopicHeader">
                <IMG class="helpNavImg" SRC="/images/gHelp2.png" BORDER="0" WIDTH="16" HEIGHT="16">
            </SPAN>
            </A>
          </td>
      </tr>
      <tr>
        <td class="form_body">
          <b>&nbsp;File: &nbsp;</b>
          <input type="file" name="upload_file" size="40" class="txt">
        </td>
        <td class="form_body">
          <b>Format:</b>
          <select class="txt" id="fileFormatSelect" name="fileFormatSelect">
            <option value="<%=Constants.GB_FASTA_EP_FILE%>">Fasta</option>
            <option value="<%=Constants.GB_LFF_EP_FILE%>">3-Column LFF</option>
          </select>
        </td>
        <td class="form_body">
          <input type="submit" name="btnUploadRefseq" id="btnUploadRefseq" class="btn" value="Upload">
        </td>
      </tr>
      </table>
    </form>
<%
  }  // end of upload  EPs

  // ------------------------------------------------------------------
  // ARJ: Special section for only CERTAIN users. Ones in the Workshop group
  //      indicated in the edaccMetadataLinkGroup config setting get to see this.
  // Get config setting.
  String edaccMetadataLinkGroupStr = GenboreeConfig.getConfigParam("edaccMetadataLinkGroup") ;
  if(groupId != null && !groupId.equals("3") && rseq != null && edaccMetadataLinkGroupStr != null && edaccMetadataLinkGroupStr.length() > 0)
  {
    // Check if user is in that group.
    if(userInfo[2] != null && userInfo[2].length() > 0)
    {
      boolean userInGroup = UsergroupTable.isUserInGroup(userInfo[2], edaccMetadataLinkGroupStr, db) ;
      if(userInGroup)
      {
        // Show special link and info for workbench.
%>
        <center>
          <table style="margin-top: 0px; margin-bottom: 10px; border: 1px solid red;">
          <tr>
            <td>
              Link to <a href="/java-bin/EDACC/edaccFormTypesIndex.jsp">Epigenomics Metadata Submissions page</a>.
            </td>
          </tr>
          </table>
        </center>
<%
      }
    }
  }



  if( mode==MODE_UPDATE && userRoleCanEditRefseqInfo)
  {
%>
    <form name="updfrefs" id="updfrefs" method="post" action="myrefseq.jsp" onsubmit="return showWarning() ;">
      <input type="hidden" name="update_frefs" id="update_frefs" value="y">
      <input type="hidden" name="rseq_id" id="rseq_id" value="<%=rseq_id%>">
      <input type="hidden" name="mode" id="mode" value="<%=modeIds[mode]%>">
      <input type="hidden" name="group_id" id="group_id" value="<%=groupId%>">

      <div id="ep_edit"  style="display:none" >
        <table border="0" cellspacing="0" cellpadding="2" width="100%"><tbody>
        <tr>
          <td colspan="5">
        	  <input type="button" name="btnUpdateFrefs" id="btnUpdateFrefs" class="btn" value="Apply" onClick="checkEntryPoint('updfrefs')">
           <input type="button" name="cancel1" id="cancel1" class="btn" value="Cancel"  onClick=" cancelEdit(this.form) ;">
          </td>
        </tr>
        <tr>
          <td class="form_header" style="width:2"></td>
          <td class="form_header" width="1%">Entry&nbsp;Point&nbsp;Name</td>
          <td class="form_header" style="width:8"></td>
          <td class="form_header">Class</td>
          <td class="form_header">Length</td>
          <td class="form_header">&nbsp;</td>
        </tr>
<%
        if(totalFrefCount > 0 && totalFrefCount < Constants.GB_MAX_FREF_FOR_EDIT)
        {
          for( int i=0 ; i<frefs.length ; i++ )
          {
            DbFref fref = frefs[i] ;
            String frefId = "updfref_"+fref.getRid() ;
            String deleteFrefId = "deletefref_" + fref.getRid() ;
            String altStyle = ((i%2) == 0) ? "form_body" : "bkgd" ;

            if( htTrkErr.get(""+fref.getRid()) != null )
            {
              altStyle="form_fixed" ;
            }
%>
            <tr>
              <td class="<%=altStyle%>" style="width:2"></td>
              <td class="<%=altStyle%>">
                <input type="text" name="<%=frefId%>" id="<%=frefId%>" class="txt" style="width:350" value="<%=Util.htmlQuote(fref.getRefname())%>">
              </td>
              <td class="<%=altStyle%>" style="width:8"></td>
              <td class="<%=altStyle%>"><%=Util.htmlQuote(fref.getGname())%></td>
              <td class="<%=altStyle%>"><%=fref.getRlength()%></td>
              <td class="<%=altStyle%>"> </td>
            </tr>
<%        }    %>
            <tr>
              <td colspan="5">
                <input type="button" name="btnUpdateFrefs" id="btnUpdateFrefs" class="btn" value="Apply"onClick="checkEntryPoint('updfrefs')">
                <input type="button" name="cancel1" id="cancel1" class="btn" value="Cancel"  onClick=" cancelEdit(this.form) ;">
              </td>
            </tr>
<%
        }
        else if(totalFrefCount == 0)
        {
%>
          <tr>
            <td colspan="5" class="form_body">
              <strong>You must upload some Entry Points before using the database.</strong>
            </td>
          </tr>
<%
        }
        else
        {
%>
          <tr>
            <td class="form_body" colspan="5">Sorry, you have way too many entrypoints (<%=totalFrefCount%>) to edit by hand!</td>
          </tr>
<%      }   %>
        </table>
      </div>
      <div id="ep_delete"  style="display:none" >
        <table border="0" cellspacing="0" cellpadding="2" width="100%">
        <tr>
          <td colspan="5">
            <input type="submit" name="btnUpdateFrefs" id="btnUpdateFrefs" class="btn" value="Apply">
            <input type="button" name="cancel1" id="cancel1" class="btn" value="Cancel"  onClick="displaytop() ;">
          </td>
        </tr>
        <tr>
          <td class="form_header" style="width:2"></td>
          <td class="form_header" width="1%">Entry&nbsp;Point&nbsp;Name</td>
          <td class="form_header" style="width:8"></td>
          <td class="form_header">Class</td>
          <td class="form_header">Length</td>
          <td class="form_header">Delete</td>
        </tr>
<%
        if(totalFrefCount > 0 && totalFrefCount < Constants.GB_MAX_FREF_FOR_EDIT)
        {
          for( int i=0 ; i<frefs.length ; i++ )
          {
            DbFref fref = frefs[i] ;
            String frefId = "updfref_"+fref.getRid() ;
            String deleteFrefId = "deletefref_" + fref.getRid() ;
            String altStyle = ((i%2) == 0) ? "form_body" : "bkgd" ;
            if( htTrkErr.get("" + fref.getRid()) != null )
            {
              altStyle="form_fixed" ;
            }
%>
            <tr>
              <td class="<%=altStyle%>" style="width:2"></td>
              <td class="<%=altStyle%>"	name="<%=frefId%>" id="<%=frefId%>" value="<%=Util.htmlQuote(fref.getRefname())%>">
                <%=Util.htmlQuote(fref.getRefname())%>
              </td>
              <td class="<%=altStyle%>" style="width:8"></td>
              <td readonly   class="<%=altStyle%>"><%=Util.htmlQuote(fref.getGname())%></td>
              <td readonly   class="<%=altStyle%>"><%=fref.getRlength()%></td>
              <td class="<%=altStyle%>"> <input type="checkbox" name="<%=deleteFrefId%>" id="<%=deleteFrefId%>" value="y" ></td>
            </tr>
<%
          }
%>
          <tr>
            <td colspan="5">
              <input type="submit" name="btnUpdateFrefs" id="btnUpdateFrefs" class="btn" value="Apply">
              <input type="button" name="cancel1" id="cancel1" class="btn" value="Cancel"  onClick="displaytop() ;">
            </td>
          </tr>
<%
        }
        else if(totalFrefCount == 0)
        {
%>
          <tr>
            <td colspan="5" class="form_body">
              <strong>You must upload some Entry Points before using the database.</strong>
            </td>
          </tr>
<%
        }
        else
        {
%>
          <tr>
            <td class="form_body" colspan="5">Sorry, you have way too many entrypoints (<%=totalFrefCount%>) to edit by hand!</td>
          </tr>
<%
        }
%>
        </table>
      </div>
    </form>
<%
  }
%>





<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
