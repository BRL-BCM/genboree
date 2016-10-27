<%@ page import="javax.servlet.http.*, java.util.*,java.sql.*, org.genboree.dbaccess.*, org.genboree.dbaccess.util.*, org.genboree.message.*, org.genboree.manager.tracks.Utility" %>
<%@ include file="include/fwdurl.incl" %>
<%@ include file="include/group.incl" %>
<%
    ArrayList errList = new ArrayList();
   // boolean isAdmin = false;
    boolean isAuthor = false;
    boolean userAdded = false;
    GenboreeUser[] usrs = null;
    String memberInfo = "";
    response.addDateHeader( "Expires", 0L );
    response.addHeader( "Cache-Control", "no-cache, no-store" );
    boolean   newuser_nameExist = false;
    boolean   newuser_emailExist = false;
    boolean  addConfirmation = false;
    boolean addExistConfirmation = false;
    HashMap id2user = new HashMap();
    if (mys.getAttribute("id2user")!= null)
    id2user = (HashMap)mys.getAttribute("id2user");
    String serverName = Constants.REDIRECTTO;
    String confirmedState = "0";
    if (mys.getAttribute("confirmState")!= null)
    confirmedState = (String)mys.getAttribute("confirmState");
    GenboreeUser usr = null;
    GenboreeUser[] users = null;
    int i;
    String firstName = "";
    String lastName = "";
    String loginName = "";
    String emailAddress = "";
    String institution = "";
    boolean confirmed = false;
    String tempGroupName = "Empty";
    String tempGroupDescription = "There are not groups, please create one";
    if( myself==null ){
        GenboreeUtils.sendRedirect(request,response,  "/java-bin/login.jsp" );
        return;
    }
    String pMode = request.getParameter("mode");

    Refseq[] rseqs2 = Refseq.fetchAll( db, grps );
    if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
    if( rseqs2 == null ) rseqs2 = new Refseq[0];
//    mys.setAttribute( "RefSeqs", rseqs2 );
    int mode = GenboreeGroup.MODE_DEFAULT;
    if( pMode != null ){
        for( i=0; i<GenboreeGroup.modeIds.length; i++ ){
            if( pMode.equals(GenboreeGroup.modeIds[i]) ){
            mode = i;
            break;
            }
        }
    }

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

  // If we're processing the submitted registration form or something, get the account code from the form if present
  String accountCode = request.getParameter("accountCode") ;
  boolean accountCodeOk = true ;
  if(accountCode == null)
  {
    accountCode = "" ;
  }
  else
  {
    accountCode = accountCode.trim() ;
  }

    if( request.getParameter("btnCancel") != null )
    {
        GenboreeUtils.sendRedirect(request,response,  (mode == GenboreeGroup.MODE_DEFAULT) ? "/java-bin/index.jsp" : "/java-bin/mygroup.jsp" );
        return;
    }

    boolean is_new_group = true;

     //get Session group id ; should be the old one
    String oldGroupId = SessionManager.getSessionGroupId(mys);
    if( groupId != null )
    {
      if( oldGroupId!=null && oldGroupId.equals(groupId) )
      {
        is_new_group = false ;
      }
    }
    else
    {
      groupId = oldGroupId ;
    }


    // set default to first group
    if( groupId == null  && grp != null){
        groupId = grp.getGroupId();
    }
    else{
    // find corresponding group
        if(rwGrps != null)
        for( i=0; i<rwGrps.length; i++ )
        if( rwGrps[i].getGroupId().equals(groupId) )
            grp = rwGrps[i];
    }


  // check user access
  if(!subscribeOnlyGroupIds.contains(grp.getGroupId())  )
    isAuthor = true;

  usrs = new GenboreeUser[0];
  if( mode != GenboreeGroup.MODE_CREATE  && grp != null)
    usrs = grp.getUsers( db );

  // update group name
    String group_name = request.getParameter( "group_name" );
    if( group_name == null ) group_name = "";
    else group_name = group_name.trim();
    String group_descr = request.getParameter( "group_descr" );
    if( group_descr == null ) group_descr = "";

    boolean inGroup = false;
    if(rwGrps != null) {
        for (i=0; i< rwGrps.length ;  i++) {
            if (rwGrps[i].getGroupId().equals(groupId) ) {
                grp = rwGrps[i];
                if (grp.belongsTo((String)mys.getAttribute(Constants.SESSION_DATABASE_ID)))
                inGroup = true;
                break;
            }
        }
    }
    if (!inGroup ) {
        mys.removeAttribute(Constants.SESSION_DATABASE_ID);
    }

     if( request.getParameter("btnCreate") != null )
       isAuthor = true;

    if( mode == GenboreeGroup.MODE_CREATE ){
        grp = new GenboreeGroup();
        groupId = grp.getGroupId();
        grp.setGroupName( group_name );
        grp.setDescription( group_descr );

    }

             if( request.getParameter("btnCreate") != null ){
                if( Util.isEmpty(group_name) ){
                    errList.add( "Group Name must not be empty" );
                }
                else{
                GenboreeGroup ngrp = new GenboreeGroup();
                ngrp.setGroupName( group_name );
                if( ngrp.fetchByName(db) ){
                    errList.add( "A group with group name \"" + group_name + "\" already exists; ");
                }
                else{
                    grp.setGroupName( group_name );
                    grp.setDescription( group_descr );
                    grp.insert( db );
                    grp.grantAccess( db, myself.getUserId(), "o" );
                    grp.fetchUsers( db );
                    if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;

                    groupId = grp.getGroupId();
                    group_name = grp.getGroupName();
                    GenboreeGroup[] ngrps = new GenboreeGroup[ grps.length + 1];
                    System.arraycopy( grps, 0, ngrps, 1, grps.length );
                    ngrps[0] = grp;
                    grps = ngrps;
                    vRw.add( 0, grp );
                    rwGrps = new GenboreeGroup[ vRw.size() ];
                    vRw.copyInto( rwGrps );
                    SessionManager.setSessionGroupId(mys, groupId);
                    SessionManager.setSessionGroupName(mys, group_name);
                    SessionManager.setSessionDatabaseId(mys, null);
                    SessionManager.setSessionDatabaseName(mys, null);
                    myself.fetchGroups( db );
                    if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
                    GenboreeMessage.setSuccessMsg(mys,  "Group \"" + group_name + "\" was created successfully."  );
                    mode = GenboreeGroup.MODE_DEFAULT;
                }
                }
            }


   if ( isAdmin) {
        if( request.getParameter("btnUpdate") != null){
            if( Util.isEmpty(group_name) ){
                errList.add("Group Name must not be empty" );
            }
            else{
                GenboreeGroup ngrp = new GenboreeGroup();
                ngrp.setGroupName( group_name );
                String currentGrpName = null;
                if (grp != null)
                currentGrpName = grp.getGroupName();
                if( ngrp.fetchByName(db) && currentGrpName!= null &&group_name.compareTo( currentGrpName) != 0){
                errList.add( "A group with  name \"" + group_name +"\" already exists. ");
                }
                else {
                    if(grp != null) {
                        grp.setGroupName( group_name );
                        grp.setDescription( group_descr );
                        grp.update( db );
                        if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
                        mode = GenboreeGroup.MODE_DEFAULT;
                        GenboreeMessage.setSuccessMsg(mys, "The group information was updated successfully.");
                    }
                }
                }
          }

        else if( request.getParameter("btnDelete") != null ){
            if(rwGrps != null && rwGrps.length <= 1 ){
                errList.add( "You cannot delete your last group" );
            }
            else if(rwGrps == null || grps == null){
            }
            else{
            String tempName = grp.getGroupName();
            GenboreeMessage.clearMessage(mys);
            boolean del_yes = (request.getParameter("askYes") != null);
            boolean del_no = (request.getParameter("askNo") != null);
            if( !del_yes && !del_no ){
            mys.setAttribute( "target", "mygroup.jsp" );
            String quest = "<br><font color=\"red\" size=\"+1\">"+
            "<strong>ATTENTION!</strong></font><br>\n"+
            "You are about to PERMANENTLY delete the group "+
            "&laquo;<strong>"+
            Util.htmlQuote(tempName)+
            "</strong>&raquo;<br>\n"+
            "All the data in the database will be lost FOREVER.<br><br>\n"+
            "Are you willing to proceed?<br><br>\n";
            mys.setAttribute( "question", quest );
            mys.setAttribute( "form_text", "<input type=\"hidden\" name=\"btnDelete\" id=\"btnDelete\" "+
            "value=\"d\">\n"+
            "<input type=\"hidden\" name=\"group_id\" id=\"group_id\" value=\""+
            grp.getGroupId()+"\">\n");
            GenboreeUtils.sendRedirect(request,response,  "/java-bin/ask.jsp" );
            return;
            }
            if( del_yes ){
            vRw.removeElement( grp );
            Vector v = new Vector();
            for( i=0; i<grps.length; i++ )
                if( !grps[i].getGroupId().equals(grp.getGroupId()) )
                v.addElement( grps[i] );
                grp.delete( db );
                if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
                GenboreeMessage.setSuccessMsg(mys,  "Group \"" + tempName + "\" was deleted successfully."  );
                grps = new GenboreeGroup[ v.size() ];
                v.copyInto( grps );
 //               mys.setAttribute( "GenboreeGroups", grps );
                rwGrps = new GenboreeGroup[ vRw.size() ];
                vRw.copyInto( rwGrps );
                grp = grps[0];
                groupId = grp.getGroupId();
                mode = GenboreeGroup.MODE_DEFAULT;
            }
            }
        }

    // case 1   add existing user fine
    if( request.getParameter("addExistingUser") != null )
    {

        String acs = request.getParameter("member_access");
        memberInfo = request.getParameter("member_name");
        if( memberInfo != null )
           memberInfo = memberInfo.trim();
        else memberInfo = "";
        if( !Util.isEmpty(acs) && !Util.isEmpty(memberInfo) )
        {
            usr = new GenboreeUser();
            GenboreeUser [] existingUsers = null;
            if (memberInfo.indexOf("@") >0)  {
            // check both xxx@bcm.edu and bcm.tmc.edu
                 usr.setEmail(memberInfo);
                existingUsers = GenboreeGroup.findUserInfoByEmail(db,memberInfo, out);
                if ( existingUsers == null ||  existingUsers.length ==0 ) {
                    String tempStr = memberInfo.toLowerCase();
                    int index1 =  tempStr.indexOf("@bcm.edu");
                    int index2 =  tempStr.indexOf("@bcm.tmc.edu");
                    int index =    memberInfo.indexOf("@");
                    String userIdStr = memberInfo.substring(0, index);

                    if ( index1 >0)
                    {
                        tempStr = userIdStr + "@bcm.tmc.edu";
                        existingUsers = GenboreeGroup.findUserInfoByEmail(db,tempStr, out);
                    }
                    else if (index2 >0)
                    {
                        tempStr = userIdStr + "@bcm.edu";
                        existingUsers = GenboreeGroup.findUserInfoByEmail(db,tempStr, out);
                    }
                    // check if there are users now
                     if ( existingUsers != null &&  existingUsers.length >0 )
                     {
                             usr.setEmail(tempStr);
                             memberInfo = tempStr;
                     }
                }
            }
            else {
                usr.setName(memberInfo);
                existingUsers = GenboreeGroup.findUserInfoByLoginName(db,memberInfo, out);
            }

          if( existingUsers != null && existingUsers.length > 0 )
          {
            id2user = new HashMap();
            for( i = 0; i < existingUsers.length; i++ )
            {
              id2user.put( existingUsers[ i ].getUserId(), existingUsers[ i ] );
            }
            mys.removeAttribute( "id2user" );
            mys.setAttribute( "id2user", id2user );

            if( !id2user.isEmpty() )
            {
              users = new GenboreeUser[id2user.size()];
              users = ( GenboreeUser[] )id2user.values().toArray( new GenboreeUser[users.length] );
              ArrayList list = new ArrayList();
              HashMap name2User = new HashMap();
              for( i = 0; i < users.length; i++ )
              {
                String tempName = users[ i ].getFullName();
                if( tempName != null )
                  tempName = tempName.trim();
                else
                  tempName = "";
                tempName = tempName.toUpperCase();
                if( name2User.get( tempName ) == null )
                {
                  list.add( tempName );
                  name2User.put( tempName, users[ i ] );
                } else
                {
                  int n = 1;
                  tempName = tempName + n;
                  while( name2User.get( tempName ) != null )
                  {
                    n++;
                    tempName = tempName + n;
                  }
                  list.add( tempName );
                  name2User.put( tempName, users[ i ] );
                }
              }
              String[] userNames = ( String[] )list.toArray( new String[list.size()] );
              Arrays.sort( userNames );
              GenboreeUser[] newusers = new GenboreeUser[users.length];
              for( i = 0; i < userNames.length; i++ )
              {
                newusers[ i ] = ( GenboreeUser )name2User.get( userNames[ i ] );
              }
              existingUsers = newusers;
              users = newusers;
            }

            mys.setAttribute( "existingUsers", existingUsers );

            if( existingUsers.length > 1 )
            {
              addExistConfirmation = true;
            }
            else
            {  // has only one user ==1

              usr = existingUsers[ 0 ];
              boolean ingroup = false;
              ingroup = Utility.isInGroup( usr.getUserId(), grp.getGroupId(), db );
              // if already in group, don't add
              if( !ingroup )
              {
                if( grp != null )
                {
                  grp.grantAccess( db, usr.getUserId(), acs );
                  grp.fetchUsers( db );
                  addConfirmation = false;
                  if( JSPErrorHandler.checkErrors( request, response, db, mys ) ) return;
                  memberInfo = "";
                }
                GenboreeMessage.setSuccessMsg( mys, "Genboree user: \"" + usr.getName() + "\" was successfully added to genboree and group \"" + grp.getGroupName() + "\"" );

              } else
              {
                errList.add( "user " + usr.getName() + " is already in this group." );
              }
            }
          }
          else
                errList.add( "Unknown login name or email: "+memberInfo );
            }
        }

    //   add existing user fine
    if( request.getParameter("addSelectedUsers") != null )
    {
          String  acs =  (String ) mys.getAttribute("userAccess");
        if (acs==null)
            acs ="r";
        usr = new GenboreeUser();
        GenboreeUser [] selectedUsers = null;
        String [] selectedUseerIds = request.getParameterValues("selectedUsers");
        if (selectedUseerIds  != null  )
        {
            selectedUsers = new GenboreeUser [selectedUseerIds.length];
            for (i=0; i<selectedUseerIds.length; i++)
            {
                selectedUsers[i]  = (GenboreeUser)id2user.get(selectedUseerIds[i]);
            }
            memberInfo = (String)mys.getAttribute("memberInfo");
            ArrayList selectedList = new ArrayList ();
            for (i=0;  i < selectedUsers.length; i++)
            {
                usr = selectedUsers[i];
                boolean ingroup =  false;
                ingroup = Utility.isInGroup(usr.getUserId(), grp.getGroupId(), db );
                // if already in group, don't add
                if (!ingroup)
                {
                  if( grp != null )
                  {
                    grp.grantAccess( db, usr.getUserId(), acs );
                    grp.fetchUsers( db );

                    addConfirmation = false;
                    if( JSPErrorHandler.checkErrors( request, response, db, mys ) ) return;
                    memberInfo = "";
                  }
                }
                else
                {
                    errList.add( "user " +  selectedUsers[i].getName() +  " is already in this group."  );
                }
                selectedList.add(usr.getFullName());
            }
            mys.removeAttribute("memberInfo");
            mys.removeAttribute("existingUsers");
           String  be = "user was ";
            if (selectedList.size() == 0 || selectedList.size() > 1 )
               be = "users were ";
            if (errList.isEmpty() )
                GenboreeMessage.setSuccessMsg(mys, "The following selected " + be + " successfully added to genboree and group \"" + grp.getGroupName() +"\"", selectedList);
        }
        else{
            users = (GenboreeUser[])mys.getAttribute("existingUsers");
            addExistConfirmation = true;
            errList.add("Please select a user " );
        }
    }

    //   add existing user fine
    if( request.getParameter("addSelected") != null )
    {
         confirmed = true;
        newuser_nameExist = true;
        addConfirmation = false;
        mys.setAttribute("confirmState", "0");
        String selectedUserId = request.getParameter("selectedUser");
        GenboreeUser user2 = (GenboreeUser)id2user.get(selectedUserId);
        boolean addingExistingUser = true;
        if (user2 != null)
        {
            // adding exsiting user
            mys.removeAttribute("existing_newuser");
            mys.removeAttribute("confirmState");
            mys.setAttribute("existing_newuser", user2);
            usr = user2;
            if (mys.getAttribute("add_new_user") != null && grps != null)
            {    // user exist
                boolean ingroup =  false;
                ingroup = Utility.isInGroup(user2.getUserId(), grp.getGroupId(), db );
                if (!ingroup)
                {
                    String  acs =  (String ) mys.getAttribute("userAccess");
                    if (acs == null)
                    acs = "r";
                    if (  GenboreeGroup.adduser(mys,grp, usr, fullName,serverName,  db,acs) )
                    {
                          newuser_nameExist= false;
                          newuser_emailExist = false;
                          mys.setAttribute("existing_newuser", null);
                          mys.setAttribute("add_new_user", null);
                          mys.setAttribute("last_username", null);
                          mys.setAttribute("id2user", null);
                          mys.setAttribute("confirmState", "0");
                          addConfirmation = false;
                          GenboreeMessage.setSuccessMsg(mys, "Genboree user: \"" + user2.getName() + "\" was successfully added");
                    }
                }
                else
                {
                    errList.add( "user " + user2.getName() + " is already in group."  );
                    addConfirmation = false;
                    confirmed = false;
                    mys.setAttribute("existing_newuser", null);
                    mys.setAttribute("add_new_user", null);
                    mys.setAttribute("last_username", null);
                    mys.setAttribute("id2user", null);
                    mys.setAttribute("confirmState", "0");
                    newuser_nameExist  = false;
                    newuser_emailExist  = false;
                }
              }
        }
    }

    if( request.getParameter("continueAdd") != null )
    {
        mys.setAttribute("existing_newuser", mys.getAttribute("userinput_newuser"));
        addConfirmation = false;
        try
        {
          GenboreeUser newuser =    (GenboreeUser)mys.getAttribute("userinput_newuser");
          String acs =  (String ) mys.getAttribute("userAccess");
          if(acs == null)
             acs = "r";

          String fName = newuser.getFirstName() + newuser.getLastName();
          emailAddress = newuser.getEmail();

          GenboreeGroup.adduser(mys, grp, newuser, fullName,serverName, db,acs);

          GenboreeGroup ngrp = new GenboreeGroup();
          String groupName = newuser.getName() + "_group";
          ngrp.setGroupName( groupName );
          ngrp.insert( db );
          ngrp.grantAccess( db, newuser.getUserId(), "o" );
          ngrp.fetchUsers( db );
          GenboreeGroup[] ngrps = new GenboreeGroup[ grps.length + 1];
          System.arraycopy( grps, 0, ngrps, 1, grps.length );
          ngrps[0] = ngrp;
          grps = ngrps;
          vRw.add( 0, ngrp );
          vRw.add( 0, grp );
          rwGrps = new GenboreeGroup[ vRw.size() ];
          vRw.copyInto( rwGrps );
          newuser.fetchGroups( db );
          newuser_nameExist= false;
          newuser_emailExist = false;
          mys.setAttribute("existing_newuser", null);
          mys.setAttribute("add_new_user", null);
          mys.setAttribute("last_username", null);
          mys.setAttribute("id2user", null);
          mys.setAttribute("confirmState", "0");
          // mys.removeAttribute("userAccess");
          addConfirmation = false;
          GenboreeMessage.setSuccessMsg(mys, "Genboree user: \"" + newuser.getName()  + "\" was successfully added to genboree and group \"" + groupName + "\"");
        }
        catch(Exception ex)
        {
          System.err.println("FATAL ERROR adding user:") ;
          ex.printStackTrace(System.err) ;
          errList.add("A FATAL error occurred adding the user.") ;
          errList.add("Please contact " + GenboreeConfig.getConfigParam("gbAdminEmail") + " concerning this error and a fix.") ;
          mys.setAttribute("createError", "true") ;
        }
    }

     GenboreeUser newuser = null;

       String lastError = null;
       if( mode == GenboreeGroup.MODE_CREATE &&  mys.getAttribute("createError") != null )
         lastError =  (String)mys.getAttribute("createError") ;
       else  {
            mys.removeAttribute("createError");
            mys.removeAttribute("lastcreateuser" );
       }


  //*** case : adding new user  */
  if( request.getParameter("addNewUser") != null   || lastError != null && lastError.equals("true"))
  {
    // ACCOUNTS: If accounts feature is turned on, check the account code is valid and such
    HashMap accountInfo = new HashMap() ;
    int accountId = -1 ;
    accountCodeOk = true ;
    if(useAccounts)
    {
      // Retreive account record using this code
      DbResourceSet accountRecordDbResSet = AccountsTable.getRecordByCode(accountCode, conn) ;
      accountCodeOk = false ;
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
        errList.add("The account code entered does not correspond to a existing Genboree account.") ;
      }
      else // got valid account code
      {
        // check if num users for account not exceeded
        accountId = (Integer)accountInfo.get("id") ;
        accountCodeOk = !AccountsTable.isMaxNumUsersExceeded(accountId, conn) ;
        if(!accountCodeOk)
        {
          errList.add("The account has the maximum number of allowed users. Cannot register a new user on this account.") ;
        }
      }
    }
    boolean addingNewUser = false ;
    boolean addingExistingUser = false ;
    if(errList.size() <= 0)
    {
      if(confirmedState.compareTo("1")==0 )
      {
        confirmed = true ;
        addingNewUser = true ;
      }

      if(confirmedState.compareTo("2")==0 )
      {
        confirmed = true ;
        addingExistingUser = true ;
      }

      newuser = new GenboreeUser() ;
      String  acs = request.getParameter("newmember_access") ;
      if(acs == null)
      {
        acs = "r" ;
      }
      mys.setAttribute("userAccess", acs) ;

      firstName = request.getParameter("new_userfname") ;
      lastName = request.getParameter("new_userlname" );
      if(firstName != null )
      {
        firstName = firstName.trim();
      }

      if(lastName != null )
      {
        lastName = lastName.trim();
      }

      mys.setAttribute("last_username", firstName + ":" + lastName) ;
      emailAddress  = request.getParameter("email") ;
      if( emailAddress != null )
      {
        emailAddress = emailAddress.trim() ;
      }
      institution = request.getParameter("institution") ;
      if(  institution  != null )
      {
        institution  =  institution.trim() ;
      }
      newuser.setFirstName(firstName) ;
      newuser.setLastName(lastName) ;
      newuser.setEmail(emailAddress);
      newuser.setName(firstName + lastName) ;
      newuser.setInstitution(institution) ;
      mys.setAttribute("userinput_newuser", newuser) ;

      // find genboree user
      usr = GenboreeGroup.findUserInfo(db,firstName, lastName, emailAddress, out);
      String fName = firstName + lastName;

      if(!confirmed)
      {
        GenboreeUser[] usersByEmail = GenboreeGroup.findUserInfoByEmail(db,emailAddress, out) ;
        GenboreeUser [] usersByName = GenboreeGroup.findUserInfoByName(db,firstName, lastName, out);
        id2user = new HashMap () ;
        if (usersByEmail != null )
        {
          for (i=0; i<usersByEmail.length; i++)
          {
            id2user.put(usersByEmail[i].getUserId(), usersByEmail[i]);
          }
        }

        if(usersByName != null )
        {
          for(i=0; i<usersByName.length; i++)
          {
            if (id2user.get(usersByName[i].getUserId())== null)
            {
              id2user.put(usersByName[i].getUserId(), usersByName[i]);
            }
          }
        }

        mys.removeAttribute("id2user") ;
        mys.setAttribute("id2user", id2user) ;

        if(!id2user.isEmpty())
        {
          users = new GenboreeUser[id2user.size()] ;
          users = (GenboreeUser[])id2user.values().toArray(new GenboreeUser[users.length]) ;
          ArrayList list = new ArrayList() ;
          HashMap name2User = new HashMap () ;
          for(i=0 ; i<users.length ; i++)
          {
            String tempName =  users[i].getFullName() ;
            if(tempName != null)
            {
              tempName = tempName.trim() ;
            }
            else
            {
              tempName = "" ;
            }
            tempName = tempName.toUpperCase() ;
            if(name2User.get(tempName)== null)
            {
              list.add(tempName) ;
              name2User.put(tempName, users[i]) ;
            }
            else
            {
              int n =1 ;
              tempName =  tempName + n ;
              while(name2User.get(tempName)!= null)
              {
                n++ ;
                tempName =  tempName+ n ;
              }
              list.add(tempName) ;
              name2User.put(tempName, users[i]) ;
            }
          }
          String [] userNames = (String [])list.toArray(new String [list.size()]) ;
          Arrays.sort(userNames) ;
          GenboreeUser [] newusers = new GenboreeUser[users.length] ;
          for(i=0 ; i<userNames.length ; i++)
          {
            newusers[i] = (GenboreeUser)name2User.get(userNames[i]) ;
          }
          users = newusers ;
        }
      }

      if(usr != null)
      {
        mys.removeAttribute("existing_newuser");
        mys.setAttribute("existing_newuser", usr);
        // 1. check if user name is used
        String dbUserName = usr.getFirstName() + usr.getLastName();
        if(fName != null && dbUserName.compareToIgnoreCase(fName) ==0){
            newuser_nameExist = true;
        }

        if (emailAddress != null && usr.getEmail().compareToIgnoreCase(emailAddress)==0)  {
            newuser_emailExist = true;
        }

        if ((newuser_nameExist || newuser_emailExist ) && !confirmed) {
            addConfirmation = true;
        }
      }
      else
      { //user not exist
        try
        {
          if(grp != null)
          {
            //   String  hostName = newUser.email.substring(email.indexOf("@") +1);
            if(GenboreeGroup.adduser(mys,  grp, newuser, fullName, serverName, db, acs))
            {
              GenboreeGroup ngrp = new GenboreeGroup();
              String groupName = newuser.getName() + "_group";
              ngrp.setGroupName( groupName );
              ngrp.insert( db );
              ngrp.grantAccess( db, newuser.getUserId(), "o" );
              ngrp.fetchUsers( db );
              userAdded = true;
              GenboreeGroup[] ngrps = new GenboreeGroup[ grps.length + 1];
              System.arraycopy( grps, 0, ngrps, 1, grps.length );
              ngrps[0] = ngrp;
              grps = ngrps;
              vRw.add( 0, ngrp );
              vRw.add( 0, grp );
              rwGrps = new GenboreeGroup[ vRw.size() ];
              vRw.copyInto( rwGrps );
              newuser.fetchGroups( db );
              newuser_nameExist= false;
              newuser_emailExist = false;
              mys.setAttribute("existing_newuser", null);
              mys.setAttribute("add_new_user", null);
              mys.setAttribute("id2user", null);
              mys.setAttribute("last_username", null);
              GenboreeMessage.setSuccessMsg(mys," New user \"" + newuser.getName()
                      + "\" was successfully added to Genboree and group \"" + grp.getGroupName()
                      + " \".<br> Registration information was sent to \""  + newuser.getEmail() + "\"");
              mys.removeAttribute("createError");
              mys.removeAttribute("lastcreateuser" );
            }
            else
            {
              mys.setAttribute("createError", "true");
              mys.setAttribute("lastcreateuser", newuser );
            }
          }
        }
        catch(Exception ex)
        {
          System.err.println("FATAL ERROR adding user:") ;
          ex.printStackTrace(System.err) ;
          errList.add("A FATAL error occurred adding the user.") ;
          errList.add("Please contact " + GenboreeConfig.getConfigParam("gbAdminEmail") + " concerning this error and a fix.") ;
          mys.setAttribute("createError", "true") ;
        }
      }
    }
  }
   // end of adding new user
    if ( request.getParameter("initPage") != null && request.getParameter("initPage").compareToIgnoreCase("no") ==0) {
        newuser_nameExist= false;
        newuser_emailExist = false;
        mys.setAttribute("existing_newuser", null);
        mys.setAttribute("add_new_user", null);
        mys.setAttribute("last_username", null);
    }

    if( request.getParameter("btnSetRoles") != null  && grp != null){
       if (usrs != null && usrs.length > 0)
        for( i=0; i<usrs.length; i++ ){
            usr = usrs[i];
            if( usr.getUserId().equals(myself.getUserId()) ) continue;
            String  acs = request.getParameter("userGroupAccess"+usr.getUserId());
            if( acs == null ) continue;
            grp.grantAccess( db, usr.getUserId(), acs );
            if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
        }
        grp.fetchUsers( db );
        if( JSPErrorHandler.checkErrors(request,response, db,mys) ) return;
        usrs = grp.getUsers( db );
    }


    mys.setAttribute( "uploadGroupId", groupId );
    if (usrs != null && usrs.length > 1) {
        String []  usrnames = new String [usrs.length];
        HashMap name2user = new HashMap ();
        for (i=0; i<usrs.length; i++) {
        String fullName1 = usrs[i].getFullName();
        if (fullName1 != null)
        fullName1 = fullName1.trim();
        else
        fullName1 = "";
        fullName1 = fullName1.toUpperCase();
        usrnames[i] = fullName1;
        if (name2user.get(usrnames[i])== null) {
         name2user.put (fullName1, usrs[i]);
        }
        else {
        int n =1;
        fullName1 = fullName1+ n ;
        while (name2user.get(fullName1)!= null) {
        n++;
        fullName1 = fullName1+ n ;
        }
        usrnames[i] = fullName1;
        name2user.put (fullName1, usrs[i]);
        }
        }
        Arrays.sort(usrnames);
        GenboreeUser [] tempusers = new GenboreeUser [usrs.length] ;
        for (i=0; i<usrnames.length; i++) {
            tempusers[i] = (GenboreeUser)name2user.get(usrnames[i]);
        }
        usrs = tempusers;
    }
   }
    boolean need_button = false;
    boolean hideCancelButton = false;
    String edit_opt = " disabled";
    String message = "";

    boolean hasError = false;
    System.err.println("DEBUG: isAdmin = " + isAdmin ) ;

     switch( mode ){
        case GenboreeGroup.MODE_CREATE:
        need_button = true;
        edit_opt = "";

        break;

        case GenboreeGroup.MODE_DELETE:
        if( grps.length > 1 ) need_button = true;
            if (!isAdmin) {     hasError = true;
        message =  "Sorry, you do not have enough privileges to delete in this group.";

            need_button = false;
        }
        break;
        case GenboreeGroup.MODE_UPDATE:

            need_button = true;
            edit_opt = "";
            if (!isAdmin) {     hasError = true;
            message =  "Sorry, you do not have enough privileges to update in this group.";

            need_button = false;
        }
        break;

        case GenboreeGroup.MODE_ADDUSER:
        if (!isAdmin) {     hasError = true;
        message =  "Sorry, you do not have enough privileges to add user in this group.";

        need_button = false;
        }
        break;

        case GenboreeGroup.MODE_SETROLES:
        if(!isAdmin) {     hasError = true;
        message =  "Sorry, you do not have enough privileges to update roles in this group.";
        need_button = false;

        }
        else  need_button = true;
        break;

        case GenboreeGroup.MODE_COPYUSERS:
        if (!isAdmin) {     hasError = true;
        message =  "Sorry, you do not have enough privileges to update roles in this group.";
        need_button = false;

        }
        else  need_button = true;
        break;

        case GenboreeGroup.MODE_DEFAULT:
        break;

        default:
        need_button = true;
        hideCancelButton = false;
        break;
    }


   if (!isAdmin  && hasError)
     GenboreeMessage.setErrMsg(mys,message);
   GenboreeGroup selectedGroup = null;
%>
<HTML>
<head>
  <title>Genboree - User Group Management</title>
  <link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/message.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/styles/mygroup.css<%=jsVersion%>" type="text/css">
  <meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
  <script src="/javaScripts/prototype.js<%=jsVersion%>" type="text/javascript"></script>
  <script src="/javaScripts/util.js<%=jsVersion%>" type="text/javascript"></script>
  <script src="/javaScripts/group.js<%=jsVersion%>" type="text/javascript"></script>
  <script src="/javaScripts/commonFunctions.js<%=jsVersion%>" type="text/javascript"></script>
  <script src="/javaScripts/sorttable.js<%=jsVersion%>" type="text/javascript"></script>

<%
if( mode == GenboreeGroup.MODE_COPYUSERS )
{
%>
  <script type="text/javascript" src="/javaScripts/ext-2.2/adapter/prototype/prototype.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/ext-2.2/adapter/prototype/scriptaculous.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/ext-2.2/adapter/prototype/ext-prototype-adapter.js<%=jsVersion%>"></script>
  <script type="text/javascript" src="/javaScripts/ext-2.2/ext-all.js<%=jsVersion%>"></script>
  <!-- Set a local "blank" image file; default is a URL to extjs.com -->
  <script type='text/javascript'>
    Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
  </script>

  <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/window.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/dialog.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/panel.css<%=jsVersion%>" type="text/css">
  <link rel="stylesheet" href="/javaScripts/ext-2.2/resources/css/core.css<%=jsVersion%>" type="text/css">

  <script type="text/javascript" src="/javaScripts/copyUsers.js<%=jsVersion%>"></script>
<%
}
%>

</head>
<BODY>
  <%@ include file="include/sessionGrp.incl"%>
  <%@ include file="include/header.incl" %>
  <%@ include file="include/navbar.incl" %>
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
    <p>
    <b><font color="red">This feature has been relocated to the Genboree Workbench page.</font></b>
    </p>
    <p>
    To go to the Genboree workbench, just click on the <a href="workbench.jsp">Workbench link</a> in the menubar above.
    </p>
    <p>
    Below are a few images which show how to access the Groups functionality on the Workbench page.
    </p>
    <ul>
      <li><a href="#createGrp">CREATE</a></li>
      <li><a href="#editGrp">EDIT</a></li>
      <li><a href="#deleteGrp">DELETE</a></li>
      <li><a href="#userMgmt">USER MANAGEMENT</a></li>
      <li><a href="#copyUser">COPY user</a></li>
    </ul>
    <div align="center" style="padding-top:8px;">
      <p>
        <a name="createGrp"><b>CREATE:</b></a>
      </p>
      <img  style="padding-top:5px;" src="http://<%=serverName%>/java-bin/screenshots/createGroupScaled.png" />
    </div>
    <div align="center" style="padding-top:10px;">
       <p>
        <a name="editGrp"><b>EDIT:</b></a>
      </p>
      <img style="padding-top:5px;" src="http://<%=serverName%>/java-bin/screenshots/editGroupScaled.png" />
    </div>
    <div align="center" style="padding-top:10px;">
       <p>
        <a name="deleteGrp"><b>DELETE:</b></a>
      </p>
      <img style="padding-top:5px;" src="http://<%=serverName%>/java-bin/screenshots/deleteGroupScaled.png" />
    </div>
    <div align="center" style="padding-top:10px;">
       <p>
        <a name="userMgmt"><b>USER MANAGEMENT:</b></a>
      </p>
      <img style="padding-top:5px;" src="http://<%=serverName%>/java-bin/screenshots/userMgmtScaled.png" />
    </div>
    <div align="center" style="padding-top:10px;">
       <p>
        <a name="copyUser"><b>COPY user:</b></a>
      </p>
      <img style="padding-top:5px;" src="http://<%=serverName%>/java-bin/screenshots/copyUsersScaled.png" />
    </div>
  </div>
  <%@ include file="include/footer.incl" %>
</BODY>
</HTML>
