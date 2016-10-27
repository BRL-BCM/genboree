package org.genboree.upload;

import org.genboree.dbaccess.DBAgent;
import org.genboree.dbaccess.DbFref;
import org.genboree.util.DirectoryUtils;
import org.genboree.util.GenboreeUtils;
import org.genboree.util.TimingUtil;
import org.genboree.util.Util;

import java.sql.*;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public class GroupAssigner
{

    protected DBAgent db = null;
    protected Connection conn = null;
    protected String databaseName = null;
    protected String refseqId = null;
    protected ArrayList fidGroupValueU = null;
    protected ArrayList fidGroupValueF = null;
    protected ArrayList fidGroupValueL = null;
    protected ArrayList fidGroupValueM = null;
    protected static int numberOfUpdatesToInsert = 100000;
    protected static int maxNumberRids = 50;
    protected int counter = 0;
    protected static int sleepBetweenHowManySelects = 15000;
    protected static int sleepTimeBetweenSelects = 1000;
    protected static int sleepTimeBetweenUpdates = 1000;
    protected String getRidsQuery = "SELECT rid FROM fref";
    protected PreparedStatement getRidsPstmt;
    protected String getCountRidsQuery = "SELECT count(rid) totalRids FROM fref";
    protected PreparedStatement getCountRidsPstmt;
    protected String getFtypesQuery = "SELECT ftypeid typeId from ftype";
    protected PreparedStatement getFtypesPstmt;
    protected String  getGnamesQuery = "SELECT distinct(gname) gname FROM fdata2 where " +
            "groupContextCode is null and rid = ? AND ftypeId = ?";
    protected PreparedStatement getGnamesPstmt;
    protected String getFidQuery = "SELECT fid, gname, fstart, fstop, groupContextCode FROM fdata2 " +
            "WHERE rid = ? AND ftypeId = ? AND gname = ? order by gname, fstart, fstop";
    protected PreparedStatement getFidPstmt;
    protected int numberGroupsToProcess =50;
    protected int numberGroupsToProcessNotUsingRids = 50;
    protected int numberOfRidsSelected = 1200;


    protected TimingUtil timer = null;
    protected String timmingInfo = null;


    public GroupAssigner(String refSeqId, String databasename)
    {

        if(databasename == null && refSeqId == null)
        {
            System.err.println("missing databaseName");
            return ;
        }
        else if(refSeqId != null && databasename == null)
        {
            this.refseqId = refSeqId;
            databaseName = GenboreeUtils.fetchMainDatabaseName(refseqId );
        }
        else if(refSeqId == null && databasename != null)
            this.databaseName = databasename;
        else
        {
            this.refseqId = refSeqId;
            this.databaseName = databasename;
        }

        if(databaseName == null)
        {
            System.err.println("wrong databaseName " + databaseName);
            return;
        }



        fidGroupValueU = new ArrayList();
        fidGroupValueF = new ArrayList();
        fidGroupValueL = new ArrayList();
        fidGroupValueM = new ArrayList();
        timer = new TimingUtil() ;

        try
        {
            boolean isGenboreeDatabase = false;
            db = DBAgent.getInstance();
            conn = db.getConnection(databaseName);
            if(conn == null)
            {
                System.err.println("Unable to create connection to Database " + databaseName );
                System.err.flush();
                System.exit(10);
            }

            isGenboreeDatabase = GenboreeUtils.verifyIfDabaseLookLikeGenboree_r_Type(conn, databaseName);

            if(!isGenboreeDatabase)
            {
                System.err.println("Database " + databaseName + " does not look like a genboree database");
                System.err.flush();
                System.exit(10);
            }

            getRidsPstmt = conn.prepareStatement( getRidsQuery);
            getCountRidsPstmt = conn.prepareStatement( getCountRidsQuery);
            getFtypesPstmt = conn.prepareStatement( getFtypesQuery);
            getGnamesPstmt = conn.prepareStatement( getGnamesQuery);
            getFidPstmt = conn.prepareStatement( getFidQuery);
        }
        catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find empty groups for databaseName = " + databaseName);
            System.err.flush();
        }
        finally
        {
            return ;
        }
    }

    public static int getSleepTimeBetweenSelects()
    {
        return sleepTimeBetweenSelects;
    }

    public static void setSleepTimeBetweenSelects(int sleepTimeBetweenSelects)
    {
        GroupAssigner.sleepTimeBetweenSelects = sleepTimeBetweenSelects;
    }

    public String getTimmingInfo()
    {
        return timmingInfo;
    }

    public int getNumberGroupsToProcess()
    {
        return numberGroupsToProcess;
    }

    public void setNumberGroupsToProcess(int numberGroupsToProcess)
    {
        this.numberGroupsToProcess = numberGroupsToProcess;
    }

    public static int getSleepTimeBetweenUpdates()
    {
        return sleepTimeBetweenUpdates;
    }

    public static void setSleepTimeBetweenUpdates(int sleepTimeBetweenUpdates)
    {
        GroupAssigner.sleepTimeBetweenUpdates = sleepTimeBetweenUpdates;
    }

    public static int getNumberOfUpdatesToInsert()
    {
        return numberOfUpdatesToInsert;
    }

    public static void setNumberOfUpdatesToInsert(int numberOfUpdatesToInsert)
    {
        GroupAssigner.numberOfUpdatesToInsert = numberOfUpdatesToInsert;
    }

    public static int getSleepBetweenHowManySelects()
    {
        return sleepBetweenHowManySelects;
    }

    public static void setSleepBetweenHowManySelects(int sleepBetweenHowManySelects)
    {
        GroupAssigner.sleepBetweenHowManySelects = sleepBetweenHowManySelects;
    }

    public HashMap transformGroupNamesAL2GroupRidDataArray(ArrayList groupNames, String ftypeId)
    {
        Statement stmt = null;
        String theInStatement = null;
        String getGroupOfFidQuery = null;
        ResultSet rs = null;
        String fid = null;
        String gname = null;
        String rid = null;
        String tempGroupNameRemoveRid = null;
        long fstart = 0;
        long fstop = 0;
        String groupContextCode = null;
        HashMap myGroup = new HashMap();
        ArrayList groupsArray = null;
        int localGroupCounter = 0;
        ArrayList groupNamesAL = null;
        String groupName_rid = null;

        if(groupNames == null || groupNames.size() < 1) return null;

        groupNamesAL = new ArrayList();

        for(int i = 0; i < groupNames.size(); i++)
        {
            String currentGroupName = null;
            tempGroupNameRemoveRid = (String)groupNames.get(i);
            int location = tempGroupNameRemoveRid.lastIndexOf("_");
            tempGroupNameRemoveRid = tempGroupNameRemoveRid.substring(0, location);
            currentGroupName = "'" + GenboreeUtils.mysqlEscapeSpecialChars(tempGroupNameRemoveRid) + "'";
            groupNamesAL.add(currentGroupName);
        }

        String orderPart = " ORDER BY gname, rid, fstart, fstop";


        getGroupOfFidQuery = "SELECT fid, gname, fstart, fstop, groupContextCode, rid FROM fdata2 " +
                "WHERE ftypeId = "+ ftypeId +" AND gname in ( ";


        theInStatement = DirectoryUtils.join(groupNamesAL, ",");
        getGroupOfFidQuery += theInStatement + ") " + orderPart;
        try
        {
            stmt = conn.createStatement();
            rs = stmt.executeQuery( getGroupOfFidQuery );
            localGroupCounter = 0;
            while( rs.next() )
            {
                localGroupCounter++;
                fid = rs.getString("fid");
                gname = rs.getString("gname");
                fstart = rs.getLong("fstart");
                fstop = rs.getLong("fstop");
                groupContextCode = rs.getString("groupContextCode");
                rid = rs.getString("rid");
                groupName_rid = gname + "_" + rid;

                GroupData  groupData = new GroupData( fid, fstart, fstop, gname, groupContextCode, ftypeId, rid, localGroupCounter);
                if(myGroup.containsKey(groupName_rid))
                {
                    groupsArray = (ArrayList)myGroup.get(groupName_rid);
                    groupsArray.add(groupData);
                }
                else
                {
                    groupsArray = new ArrayList();
                    groupsArray.add(groupData);
                    myGroup.put(groupName_rid, groupsArray);
                }
            }
            stmt.close();
//            timer.addMsg("  After the update groupContext: GroupAssigner#updateElementsOfGroup") ;
        }
        catch (SQLException ex)
        {
            ex.printStackTrace(System.err);
            myGroup = null;
        }
        finally
        {
            return myGroup;
        }
    }



    public HashMap transformGroupNamesAL2GroupDataArray(ArrayList groupNames, String rid, String ftypeId)
    {
        Statement stmt = null;
        String theInStatement = null;
        String getGroupOfFidQuery = null;
        ResultSet rs = null;
        String fid = null;
        String gname = null;
        long fstart = 0;
        long fstop = 0;
        String groupContextCode = null;
        HashMap myGroup = new HashMap();
        ArrayList groupsArray = null;
        int localGroupCounter = 0;
        ArrayList groupNamesAL = null;

        if(groupNames == null || groupNames.size() < 1) return null;

        groupNamesAL = new ArrayList();

        for(int i = 0; i < groupNames.size(); i++)
        {
            String currentGroupName = null;
            currentGroupName = "'" + GenboreeUtils.mysqlEscapeSpecialChars((String)groupNames.get(i)) + "'";
            groupNamesAL.add(currentGroupName);
        }

        String orderPart = " ORDER BY gname, fstart, fstop";


        getGroupOfFidQuery = "SELECT fid, gname, fstart, fstop, groupContextCode FROM fdata2 " +
                "WHERE rid = " + rid + " AND ftypeId = "+ ftypeId +" AND gname in ( ";


        theInStatement = DirectoryUtils.join(groupNamesAL, ",");
        getGroupOfFidQuery += theInStatement + ") " + orderPart;
        try
        {
            stmt = conn.createStatement();
            rs = stmt.executeQuery( getGroupOfFidQuery);
            localGroupCounter = 0;
            while( rs.next() )
            {
                localGroupCounter++;
                fid = rs.getString("fid");
                gname = rs.getString("gname");
                fstart = rs.getLong("fstart");
                fstop = rs.getLong("fstop");
                groupContextCode = rs.getString("groupContextCode");
                GroupData  groupData = new GroupData( fid, fstart, fstop, gname, groupContextCode, ftypeId, rid, localGroupCounter);
                if(myGroup.containsKey(gname))
                {
                    groupsArray = (ArrayList)myGroup.get(gname);
                    groupsArray.add(groupData);
                }
                else
                {
                    groupsArray = new ArrayList();
                    groupsArray.add(groupData);
                    myGroup.put(gname, groupsArray);
                }
            }
            stmt.close();
//            timer.addMsg("  After the update groupContext: GroupAssigner#updateElementsOfGroup") ;
        }
        catch (SQLException ex)
        {
            ex.printStackTrace(System.err);
            myGroup = null;
        }
        finally
        {
            return myGroup;
        }
    }

    public long  fetchMinStart(ArrayList groupArray)
    {
        long minStart = -1;
        GroupData  groupData = null;
        long fstart = 0;

        for(int groupIndex = 0; groupIndex < groupArray.size(); groupIndex++)
        {
            groupData = (GroupData)groupArray.get(groupIndex);
            fstart = groupData.getStart();
            if(groupIndex == 0)
            {
                minStart = fstart;
            }
            else
            {
                if(fstart < minStart)
                    minStart = fstart;
            }
        }

        return minStart;
    }
    public long  fetchMaxStop(ArrayList groupArray)
    {
        long maxStop = -1;
        GroupData  groupData = null;
        long fstop = 0;

        for(int groupIndex = 0; groupIndex < groupArray.size(); groupIndex++)
        {
            groupData = (GroupData)groupArray.get(groupIndex);
            fstop = groupData.getStop();

            if(fstop > maxStop)
                maxStop = fstop;
        }

        return maxStop;
    }

    public void processListGnames(ArrayList groupNamesAL, HashMap groupsData)
    {

        String fid = null;
        long fstart = 0;
        long fstop = 0;
        String groupContextCode = null;
        GroupData  groupData = null;
        ArrayList groupArray = null;
        String groupName = null;
        long minStart = -1;
        long maxStop = -1;



        if(groupsData == null || groupsData.size() < 1) return;
        if(groupNamesAL == null || groupNamesAL.size() < 1) return;




        for(int groupsIndex = 0; groupsIndex < groupNamesAL.size(); groupsIndex++)
        {
            groupName = (String)groupNamesAL.get(groupsIndex);
            groupArray = (ArrayList)groupsData.get(groupName);
            if(groupArray == null) continue;

            if(groupArray.size() == 1)
            {
                groupData = (GroupData)groupArray.get(0);
                fid = groupData.getFid();
                groupContextCode = groupData.getGroupContextCode();

                if(groupContextCode == null || !groupContextCode.equalsIgnoreCase("U"))
                    fidGroupValueU.add(fid);  // update fid groupContextCode = 'U';
            }
            else
            {
                minStart = fetchMinStart(groupArray);
                maxStop = fetchMaxStop(groupArray);

                for(int groupIndex = 0; groupIndex < groupArray.size(); groupIndex++)
                {
                    groupData = (GroupData)groupArray.get(groupIndex);
                    fid = groupData.getFid();
                    fstart = groupData.getStart();
                    fstop = groupData.getStop();
                    groupContextCode = groupData.getGroupContextCode();

                    if(fstart == minStart && fstop == maxStop)
                    {
                        if(groupContextCode == null || !groupContextCode.equalsIgnoreCase("U"))
                            fidGroupValueU.add(fid);  // update fid groupContextCode = 'U';
                    }
                    else if(fstart == minStart)
                    {
                        if(groupContextCode == null || !groupContextCode.equalsIgnoreCase("F"))
                            fidGroupValueF.add(fid); //Update minfid groupContext = 'F'
                    }
                    else if(fstop == maxStop)
                    {
                        if(groupContextCode == null || !groupContextCode.equalsIgnoreCase("L"))
                            fidGroupValueL.add(fid);  //Update maxfid groupContext = 'L'
                    }
                    else
                    {
                        if(groupContextCode == null || !groupContextCode.equalsIgnoreCase("M"))
                            fidGroupValueM.add(fid);   //update fid groupContext = 'M'
                    }
                }
            }
        }
    }


    /**
     * add a boolean doSleep to allow turn the sleep function call on and off after each database update
     * @param groupName String group name
     * @param typeid  int ftype id
     * @param rid    int chromosome id
     * @param doSleep  boolean,   used to turn sleep function call on and off
     */

    public void assignContextForSingleGroup(String groupName, String typeid, String rid, boolean doSleep)
    {
        ArrayList groupNamesAL = null;
        HashMap groupsData = null;
        groupNamesAL = new ArrayList();
        boolean groupNameEmpty = false;
        boolean typeidEmpty = false;
        boolean ridEmpty = false;


        if(groupName == null || groupName.length() < 1) groupNameEmpty = true;
        if(typeid == null || typeid.length() < 1) typeidEmpty = true;
        if(rid == null || rid.length() < 1) ridEmpty = true;

        if(groupNameEmpty || typeidEmpty || ridEmpty )
        {
            System.err.println("Unable to run assignContextForSingleGroup insuficient information");
            System.err.println("groupName = " + groupName + " typeid = " + typeid + " rid = " + rid);
            System.err.flush();
            return;
        }

        groupNamesAL.add(groupName);
        try
        {
            groupsData = transformGroupNamesAL2GroupDataArray(groupNamesAL, rid, typeid);
            if(groupsData != null && groupsData.size() > 0) {
                processListGnames(groupNamesAL, groupsData);
                groupsData.clear();
                groupsData = null;
            }

            if(groupNamesAL != null)//&& groupNamesAL.size() > 0)
            {
                groupNamesAL.clear();
            }

            // final update
            updateElementsOfGroup(fidGroupValueU, "U", true, doSleep);
            updateElementsOfGroup(fidGroupValueF, "F", true, doSleep);
            updateElementsOfGroup(fidGroupValueL, "L", true, doSleep);
            updateElementsOfGroup(fidGroupValueM, "M", true, doSleep);


        } catch (Exception ex) {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to run assignContextForSingleGroup for = databaseName = " + databaseName);
            System.err.flush();
        } finally {
            return;
        }
    }

    public void assignContextForSingleGroup(String groupName, String typeid, String rid)
    {
        assignContextForSingleGroup(groupName, typeid,  rid, true);
    }


    public void callMethodsForEmptyGroups() {
        int numberOfRids = fetchNumberOfRids();

        if (numberOfRids > maxNumberRids)
            callMethodsForEmptyGroupsNotUsingRids();
        else
            callMethodsForEmptyGroupsUsingRids();

    }

    private void callMethodsForEmptyGroupsNotUsingRids()
    {
        ArrayList typeids = null;
        String currentTypeId = null;
        int countGroupsForQuery = 0;
        HashMap groupRids = null;
        int numberOfGroupsInHash = 0;
        int groupCounter = 0;
        String[] groupOfRids = null;
        String currentGroupRids = null;

        ArrayList groupNamesAL = null;
        HashMap groupsData = null;

        timer.addMsg("BEGIN: GroupAssigner#callMethodsForEmptyGroups") ;

        groupNamesAL = new ArrayList();

        try
        {
            groupOfRids = GenboreeUtils.retrieveGroupsOfRids(databaseName, numberOfRidsSelected );

            for(int i = 0; i <  groupOfRids.length; i++)
            {
                currentGroupRids= groupOfRids[i];

                typeids = fetchListOfTrackIds();
                for(int typeIdIndex = 0; typeIdIndex < typeids.size(); typeIdIndex++)
                {
                    currentTypeId = (String)typeids.get(typeIdIndex);
                    groupRids = createHashGnamesRids(currentTypeId, currentGroupRids);
                    numberOfGroupsInHash = groupRids.size();
                    Iterator gnameRidIterator = groupRids.entrySet().iterator() ;
                    groupCounter = 0;
                    while(gnameRidIterator.hasNext())
                    {
                        Map.Entry gnameRidMap = (Map.Entry) gnameRidIterator.next() ;
                        String gname_rid = (String)gnameRidMap.getKey();
                        String[] gnameRid = (String[])gnameRidMap.getValue();
//                        currentGroupName = gnameRid[0];
//                        currentRid = gnameRid[1];


                        counter++;
                        if ((counter > 0) && ((counter % sleepBetweenHowManySelects) == 0))
                        {
                            try
                            {
                                Util.sleep(sleepTimeBetweenSelects);
                            } catch (InterruptedException e)
                            {
                                e.printStackTrace(System.err);
                            }
                        }



                        if(countGroupsForQuery > numberGroupsToProcessNotUsingRids)
                        {
                            groupsData = transformGroupNamesAL2GroupRidDataArray(groupNamesAL, currentTypeId);

                            if(groupsData != null && groupsData.size() > 0)
                            {
                                processListGnames(groupNamesAL, groupsData);
                                groupsData.clear();
                                groupsData = null;
                            }
                            if(groupNamesAL != null )//&& groupNamesAL.size() > 0)
                            {
                                groupNamesAL.clear();
                                groupNamesAL.add(gname_rid);
                                countGroupsForQuery = 1;
                            }
                        }
                        else
                        {
                            groupNamesAL.add(gname_rid);
                            countGroupsForQuery++;
                        }


                        if((groupCounter + 1) == numberOfGroupsInHash)
                        {
                            groupsData = transformGroupNamesAL2GroupRidDataArray(groupNamesAL, currentTypeId);
                            if(groupsData != null && groupsData.size() > 0)
                            {
                                processListGnames(groupNamesAL, groupsData);
                                groupsData.clear();
                                groupsData = null;
                            }

                            if(groupNamesAL != null )//&& groupNamesAL.size() > 0)
                            {
                                groupNamesAL.clear();
                            }

                        }
                        // test if Array list too long between groups if too long update and empty them
                        updateElementsOfGroup(fidGroupValueU, "U", false);
                        updateElementsOfGroup(fidGroupValueF, "F", false);
                        updateElementsOfGroup(fidGroupValueL, "L", false);
                        updateElementsOfGroup(fidGroupValueM, "M", false);

                        groupCounter++;
                    }
                }
            }


            // final update
            updateElementsOfGroup(fidGroupValueU, "U", true);
            updateElementsOfGroup(fidGroupValueF, "F", true);
            updateElementsOfGroup(fidGroupValueL, "L", true);
            updateElementsOfGroup(fidGroupValueM, "M", true);


        }catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find empty groups for = databaseName = " + databaseName);
            System.err.flush();
        }
        finally{
            timer.addMsg("DONE: GroupAssigner#callMethodsForEmptyGroups") ;
            timmingInfo = timer.generateStringWithReport();

//            System.out.println(timer.generateStringWithReport());
//            System.out.flush();

            return ;
        }
    }



    private void callMethodsForEmptyGroupsUsingRids()
    {
        ArrayList rids = null;
        ArrayList typeids = null;
        ArrayList groupNames = null;
        String currentRid = null;
        String currentTypeId = null;
        String currentGroupName = null;
        int countGroupsForQuery = 0;

        ArrayList groupNamesAL = null;
        HashMap groupsData = null;

        timer.addMsg("BEGIN: GroupAssigner#callMethodsForEmptyGroups") ;
        groupNamesAL = new ArrayList();

        try
        {
            rids = fetchListOfRids( );

            for(int ridIndex = 0; ridIndex < rids.size(); ridIndex++)
            {
                currentRid = (String)rids.get(ridIndex);
                typeids = fetchListOfTrackIds();
                for(int typeIdIndex = 0; typeIdIndex < typeids.size(); typeIdIndex++)
                {
                    currentTypeId = (String)typeids.get(typeIdIndex);
                    groupNames =  fetchListOfEmptyGroups(currentRid, currentTypeId);
                    for(int groupNameIndex = 0; groupNameIndex < groupNames.size(); groupNameIndex++)
                    {
                        counter++;
                        if ((counter > 0) && ((counter % sleepBetweenHowManySelects) == 0))
                        {
                            try
                            {
                                Util.sleep(sleepTimeBetweenSelects);
                            } catch (InterruptedException e)
                            {
                                e.printStackTrace(System.err);
                            }
                        }


                        currentGroupName = (String)groupNames.get(groupNameIndex);
                        if(countGroupsForQuery > numberGroupsToProcess)
                        {
                            groupsData = transformGroupNamesAL2GroupDataArray(groupNamesAL, currentRid, currentTypeId);

                            if(groupsData != null && groupsData.size() > 0)
                            {
                                processListGnames(groupNamesAL, groupsData);
                                groupsData.clear();
                                groupsData = null;
                            }
                            if(groupNamesAL != null )//&& groupNamesAL.size() > 0)
                            {
                                groupNamesAL.clear();
                                groupNamesAL.add(currentGroupName);
                                countGroupsForQuery = 1;
                            }
                        }
                        else
                        {
                            groupNamesAL.add(currentGroupName);
                            countGroupsForQuery++;
                        }



                        if((groupNameIndex + 1) == groupNames.size())
                        {
                            groupsData = transformGroupNamesAL2GroupDataArray(groupNamesAL, currentRid, currentTypeId);
                            if(groupsData != null && groupsData.size() > 0)
                            {
                                processListGnames(groupNamesAL, groupsData);
                                groupsData.clear();
                                groupsData = null;
                            }

                            if(groupNamesAL != null )//&& groupNamesAL.size() > 0)
                            {
                                groupNamesAL.clear();
                            }

                        }
                        // test if Array list too long between groups if too long update and empty them
                        updateElementsOfGroup(fidGroupValueU, "U", false);
                        updateElementsOfGroup(fidGroupValueF, "F", false);
                        updateElementsOfGroup(fidGroupValueL, "L", false);
                        updateElementsOfGroup(fidGroupValueM, "M", false);
                    }
                }


            }
            // final update
            updateElementsOfGroup(fidGroupValueU, "U", true);
            updateElementsOfGroup(fidGroupValueF, "F", true);
            updateElementsOfGroup(fidGroupValueL, "L", true);
            updateElementsOfGroup(fidGroupValueM, "M", true);


        }catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find empty groups for = databaseName = " + databaseName);
            System.err.flush();
        }
        finally{
            timer.addMsg("DONE: GroupAssigner#callMethodsForEmptyGroups") ;
            timmingInfo = timer.generateStringWithReport();
//            System.out.println(timer.generateStringWithReport());
//            System.out.flush();
            return ;
        }
    }



    /**
     * add boolean doSleep to allow turn the sleep function call on and off after database update
     * @param fidGroupValue ArrayList
     * @param groupContext String  group context
     * @param finalUpdate  boolean
     * @param doSleep  boolean,  used to turn sleep function call on and off
     */

    public void updateElementsOfGroup(ArrayList fidGroupValue, String groupContext, boolean finalUpdate, boolean doSleep)
    {
        Statement stmt = null;
        String theInStatement = null;
        String updateStatement = "UPDATE fdata2 SET groupContextCode = '" + groupContext + "' WHERE fid in( ";

        if(fidGroupValue.size() >= numberOfUpdatesToInsert || finalUpdate)
        {
            if(finalUpdate && fidGroupValue.size() < 1) return;
            timer.addMsg("  Inserting groupContext: GroupAssigner#updateElementsOfGroup  groupContext = " + groupContext +
                    " where the size of the insetion group is " + fidGroupValue.size());

            theInStatement = DirectoryUtils.join(fidGroupValue, ",");
            updateStatement += theInStatement + ")";

            if(groupContext.equalsIgnoreCase("U"))
            {
                fidGroupValueU.clear();
            }
            else if(groupContext.equalsIgnoreCase("F"))
            {
                fidGroupValueF.clear();
            }
            else if(groupContext.equalsIgnoreCase("L"))
            {
                fidGroupValueL.clear();
            }
            else if(groupContext.equalsIgnoreCase("M"))
            {
                fidGroupValueM.clear();
            }
            else
            {
                System.err.println("Wrong type of groupContext on GroupAssigner#updateElementsOfGroup = " + groupContext);
                System.err.flush();
            }

            try
            {
                stmt = conn.createStatement();
                stmt.executeUpdate(updateStatement);
                stmt.close();

                timer.addMsg("  After the update groupContext: GroupAssigner#updateElementsOfGroup");
                try
                {
                    if(doSleep)
                        Util.sleep(sleepTimeBetweenUpdates);
                } catch(InterruptedException e){
                    e.printStackTrace(System.err);
                }
            }
            catch(SQLException ex) {
                ex.printStackTrace(System.err);
            }

        }
        return;
    }

    public void updateElementsOfGroup(ArrayList fidGroupValue, String groupContext, boolean finalUpdate)
    {
        updateElementsOfGroup(fidGroupValue, groupContext,  finalUpdate, true);
    }


    public ArrayList fetchListOfRids( )
    {
        String rid = null;
        ResultSet rs = null;
        ArrayList entryPointIds = null;
        entryPointIds = new ArrayList();

        try
        {
            rs = getRidsPstmt.executeQuery();

            while( rs.next() )
            {
                rid = rs.getString("rid");
                entryPointIds.add(rid);
            }


        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("query = " + getRidsQuery);
            System.err.flush();
        }
        finally{
            return entryPointIds;
        }
    }

    public int fetchNumberOfRids( )
    {
        int numberRids = -1;
        ResultSet rs = null;

        try
        {
            rs = getCountRidsPstmt.executeQuery();

            if( rs.next() )
            {
                numberRids = rs.getInt("totalRids");
            }

        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("query = " + getCountRidsQuery);
            System.err.flush();
        }
        finally{
            return numberRids;
        }
    }



    public ArrayList fetchListOfTrackIds( )
    {
        String typeId = null;
        ResultSet rs = null;
        ArrayList ftypes = null;

        ftypes = new ArrayList();

        try
        {
            rs = getFtypesPstmt.executeQuery();

            while( rs.next() )
            {
                typeId = rs.getString("typeId");
                ftypes.add(typeId);
            }

        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("query = " + getFtypesPstmt);
            System.err.flush();
        }
        finally{
            return ftypes;
        }
    }

    public HashMap createHashGnamesRids(String typeId, String inRid)
    {
        String gname = null;
        String rid = null;
        String gname_rid_key = null;
        ResultSet rs = null;
        HashMap gname_rid = null;
        Statement stmt = null;
        String gnameQuery = null;

        if(typeId == null || inRid == null ) return null;

// Changed 041206       gnameQuery = "SELECT concat(gname, '_', rid) gname_rid, gname," +
        gnameQuery = "SELECT gname, rid from fdata2 where groupContextCode" +
                " is null and ftypeId = " + typeId + " AND rid in " + inRid;




        if(typeId == null) return null;

        gname_rid = new HashMap();

        try
        {
            stmt = conn.createStatement();
            rs = stmt.executeQuery( gnameQuery );

            while( rs.next() )
            {
                String[] values =  new String[2];
                gname_rid_key = rs.getString("gname") + "_" + rs.getString("rid");
                gname = rs.getString("gname");
                rid = rs.getString("rid");
                values[0] = gname;
                values[1] = rid;
                if(!gname_rid.containsKey(gname_rid_key))
                    gname_rid.put(gname_rid_key, values);
            }

        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("rid = " + rid + " ftypeId = " +  typeId );
            System.err.println("query = " + gnameQuery);
            System.err.flush();
        }
        finally{
            return gname_rid;
        }
    }


    public ArrayList fetchListOfEmptyGroups(String rid, String typeId)
    {
        String gname = null;
        ResultSet rs = null;
        ArrayList gnames = null;


        if(rid == null || typeId == null) return null;

        gnames = new ArrayList();

        try
        {

            getGnamesPstmt.setString( 1, rid);
            getGnamesPstmt.setString( 2, typeId);
            rs = getGnamesPstmt.executeQuery();

            while( rs.next() )
            {
                gname = rs.getString("gname");
                gnames.add(gname);
            }

        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("rid = " + rid + " ftypeId = " +  typeId );
            System.err.println("query = " + getGnamesQuery);
            System.err.flush();
        }
        finally{
            return gnames;
        }
    }

    public ArrayList fetchListOfFidsWithEmptyGroups( String rid, String typeId, String gname)
    {
        String fid = null;
        ResultSet rs = null;
        ArrayList fids = null;

        if( rid == null || typeId == null || gname == null) return null;

        fids = new ArrayList();

        try
        {
            getFidPstmt.setString( 1, rid);
            getFidPstmt.setString( 2, typeId);
            getFidPstmt.setString( 3, gname);
            rs = getFidPstmt.executeQuery();

            while( rs.next() )
            {
                fid = rs.getString("fid");
                fids.add(fid);
            }

        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.flush();
        }
        finally{
            return fids;
        }
    }


    public static void printUsage()
    {
        System.out.print("usage: Empty Groups ");
        System.out.println(
                "-r refseqid ( or -d databaseName )\n" +
                "Optional [\n" +
                "\t-d databaseName\n" +
                "\t-n numberOfRecordsPerUpdate (default size = " + GroupAssigner.numberOfUpdatesToInsert + ")\n" +
                "\t-u sleepTimeBetweeenUpdates (default time = " + GroupAssigner.sleepTimeBetweenUpdates + ")\n" +
                "\t-s sleepTimeBetweenSelects (default time = " + GroupAssigner.sleepTimeBetweenSelects + ")\n" +
                "\t-i sleepBetweenHowManySelects (default numberSelects = " + GroupAssigner.sleepBetweenHowManySelects + ")\n" +
                "]\n");
        return;
    }
    public static void main(String[] args) throws Exception
    {
        String refseqId = null;
        GroupAssigner groupAssigner;
        int numberOfSelects = -1;
        int sleepTimeBetweenSelects = -1;
        int sleepTimeBetweenUpdates = -1;
        int numberUpdates = -1;
        String bufferString = null;
        String databaseName = null;
        boolean modifySleepTimeBetweenSelects = false;
        boolean modifySleepTimeBetweenUpdates = false;
        boolean modifyNumberUpdates = false;
        boolean modifyNumberOfSelects = false;

        if(args.length == 0 )
        {
            printUsage();
            System.exit(-1);
        }


        if(args.length >= 1)
        {

            for(int i = 0; i < args.length; i++ )
            {
                if(args[i].compareToIgnoreCase("-r") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        refseqId = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-d") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        databaseName = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-u") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        sleepTimeBetweenUpdates = Util.parseInt(bufferString , -1);
                        if(sleepTimeBetweenUpdates > -1)
                            modifySleepTimeBetweenUpdates = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-s") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        sleepTimeBetweenSelects = Util.parseInt(bufferString , -1);
                        if(sleepTimeBetweenSelects > -1)
                            modifySleepTimeBetweenSelects = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-n") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        numberUpdates = Util.parseInt(bufferString , -1);
                        if(numberUpdates > -1)
                            modifyNumberUpdates = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-i") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        numberOfSelects = Util.parseInt(bufferString , -1);
                        if( numberOfSelects > -1)
                            modifyNumberOfSelects = true;
                    }
                }
            }

        }
        else
        {
            printUsage();
            System.exit(-1);
        }



       /*
        DBAgent db = null;
        Connection tConn = null;

        try
        {
            db = DBAgent.getInstance();
            tConn = db.getConnection(databaseName) ;

        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }
        String[] statements = GenboreeUtils.retrieveGroupsOfRids(tConn, numberUpdates);

        for(int i = 0; i <  statements.length; i++)
            System.out.println(statements[i]);

        System.out.println("The End....");

        */




        groupAssigner = new GroupAssigner( refseqId, databaseName );

        if(modifySleepTimeBetweenUpdates) GroupAssigner.setSleepTimeBetweenUpdates(sleepTimeBetweenUpdates);
        if(modifySleepTimeBetweenSelects) GroupAssigner.setSleepTimeBetweenSelects(sleepTimeBetweenSelects);
        if(modifyNumberOfSelects) GroupAssigner.setSleepBetweenHowManySelects(numberOfSelects);
        if(modifyNumberUpdates) GroupAssigner.setNumberOfUpdatesToInsert(numberUpdates);

        groupAssigner.callMethodsForEmptyGroups();
        System.exit(0);

    }



}
