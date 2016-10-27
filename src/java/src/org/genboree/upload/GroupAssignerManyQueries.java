package org.genboree.upload;

import org.genboree.dbaccess.DBAgent;
import org.genboree.util.DirectoryUtils;
import org.genboree.util.TimingUtil;
import org.genboree.util.Util;
import org.genboree.util.GenboreeUtils;

import java.sql.*;
import java.util.*;

public class GroupAssignerManyQueries
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
    protected int counter = 0;
    protected static int sleepBetweenHowManySelects = 10000;
    protected static int sleepTimeBetweenSelects = 3000;
    protected static int sleepTimeBetweenUpdates = 3000;
    protected  String updateGroupContextQuery = "UPDATE fdata2 SET groupContextCode = ? WHERE fid= ?";
    protected PreparedStatement updateGroupContextPstmt;
    protected String getRidsQuery = "SELECT rid FROM fref";
    protected PreparedStatement getRidsPstmt;
    protected String getFtypesQuery = "SELECT ftypeid typeId from ftype";
    protected PreparedStatement getFtypesPstmt;
    protected String  getGnamesQuery = "SELECT distinct(gname) gname FROM fdata2 where " +
            "groupContextCode is null and rid = ? AND ftypeId = ?";
    protected PreparedStatement getGnamesPstmt;
    protected String getFidQuery = "SELECT fid FROM fdata2 where rid = ? AND ftypeId = ? AND gname = ?";
    protected PreparedStatement getFidPstmt;
    protected String getMinFidQuery = "SELECT min(fstart) fstart FROM fdata2 WHERE " +
            "rid = ?  AND ftypeId = ? AND gname = ?";
    protected PreparedStatement getMinFidPstmt;
    protected String getFidUsingFstartQuery = "SELECT fid FROM fdata2 where rid = ? AND ftypeId = ? " +
            "AND gname = ? AND fstart = ?";
    protected PreparedStatement getFidUsingFstartPstmt;
    protected String getMaxFidQuery = "SELECT max(fstop) fstop FROM fdata2 where rid = ? " +
            "AND ftypeId = ? AND gname = ?";
    protected PreparedStatement getMaxFidPstmt;
    protected String getFidUsingFstopQuery = "SELECT fid FROM fdata2 where rid = ? AND ftypeId = ? " +
            "AND gname = ? AND fstop = ?";
    protected PreparedStatement getFidUsingFstopPstmt;
    protected TimingUtil timer = null;
    protected TimingUtil totalTimer = null;


    public GroupAssignerManyQueries(String refSeqId)
    {
        if(refSeqId == null)
        {
            System.err.println("missing refseqId");
            return ;
        }
        else
            this.refseqId = refSeqId;

        databaseName = GenboreeUtils.fetchMainDatabaseName(refseqId );
        if(databaseName == null)
        {
            System.err.println("wrong refseqId no database associated");
            return;
        }
        fidGroupValueU = new ArrayList();
        fidGroupValueF = new ArrayList();
        fidGroupValueL = new ArrayList();
        fidGroupValueM = new ArrayList();
        timer = new TimingUtil() ;
        totalTimer = new TimingUtil() ;
        try
        {
            db = DBAgent.getInstance();
            conn = db.getConnection(databaseName);

            updateGroupContextPstmt = conn.prepareStatement( updateGroupContextQuery);
            getRidsPstmt = conn.prepareStatement( getRidsQuery);
            getFtypesPstmt = conn.prepareStatement( getFtypesQuery);
            getGnamesPstmt = conn.prepareStatement( getGnamesQuery);
            getFidPstmt = conn.prepareStatement( getFidQuery);
            getMinFidPstmt = conn.prepareStatement( getMinFidQuery);
            getFidUsingFstartPstmt = conn.prepareStatement( getFidUsingFstartQuery);
            getMaxFidPstmt = conn.prepareStatement( getMaxFidQuery);
            getFidUsingFstopPstmt = conn.prepareStatement( getFidUsingFstopQuery);


        }
        catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find empty groups for = " + refseqId);
            System.err.println("databaseName = " + databaseName);
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
        GroupAssignerManyQueries.sleepTimeBetweenSelects = sleepTimeBetweenSelects;
    }

    public static int getSleepTimeBetweenUpdates()
    {
        return sleepTimeBetweenUpdates;
    }

    public static void setSleepTimeBetweenUpdates(int sleepTimeBetweenUpdates)
    {
        GroupAssignerManyQueries.sleepTimeBetweenUpdates = sleepTimeBetweenUpdates;
    }

    public static int getNumberOfUpdatesToInsert()
    {
        return numberOfUpdatesToInsert;
    }

    public static void setNumberOfUpdatesToInsert(int numberOfUpdatesToInsert)
    {
        GroupAssignerManyQueries.numberOfUpdatesToInsert = numberOfUpdatesToInsert;
    }

    public static int getSleepBetweenHowManySelects()
    {
        return sleepBetweenHowManySelects;
    }

    public static void setSleepBetweenHowManySelects(int sleepBetweenHowManySelects)
    {
        GroupAssignerManyQueries.sleepBetweenHowManySelects = sleepBetweenHowManySelects;
    }


    public void callMethodsForEmptyGroups()
    {
        ArrayList rids = null;
        ArrayList typeids = null;
        ArrayList groupNames = null;
        ArrayList fids = null;
        ArrayList maxFids = null;
        ArrayList minFids = null;
        String currentRid = null;
        String currentTypeId = null;
        String currentGroupName = null;
        String currentFid = null;

        timer.addMsg("BEGIN: GroupAssignerManyQueries#callMethodsForEmptyGroups") ;
        totalTimer.addMsg("TotalTime begins");
        try
        {
            rids = fetchListOfRids( );

            for(int ridIndex = 0; ridIndex < rids.size(); ridIndex++)
            {
                currentRid = (String)rids.get(ridIndex);
                typeids = fetchListOfTrackIds(currentRid);
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


                        fids = fetchListOfFidsWithEmptyGroups(currentRid, currentTypeId, currentGroupName);
                        if(fids.size() < 1)
                        {
                            break;
                        }
                        else if(fids.size() == 1)
                        {
                            currentFid = (String)fids.get(0);
                            fidGroupValueU.add(currentFid);  // update fid groupContextCode = 'U';
                        }
                        else
                        {
                            minFids = fetchFirstFidsWithEmptyGroups(currentRid, currentTypeId, currentGroupName);
                            maxFids = fetchLastFidsWithEmptyGroups(currentRid, currentTypeId, currentGroupName);
                            int combineSize = minFids.size() + maxFids.size();
                            if(minFids.size() == 1 && maxFids.size() == 1 && fids.size() > combineSize)
                            {
                                String maxFid = (String)maxFids.get(0);
                                String minFid = (String)minFids.get(0);
                                fidGroupValueF.add(minFid); //Update minfid groupContext = 'F'
                                fidGroupValueL.add(maxFid);  //Update maxfid groupContext = 'L'


                                for(int fidIndex = 0; fidIndex < fids.size(); fidIndex++)
                                {
                                    currentFid = (String)fids.get(fidIndex);
                                    if(!currentFid.equalsIgnoreCase(minFid) && !currentFid.equalsIgnoreCase(maxFid))
                                    {
                                        fidGroupValueM.add(currentFid);   //update fid groupContext = 'M'

                                    }
                                }
                            }
                            else if(minFids == null || minFids.size() < 1)
                            {
                                System.err.print("Error unable to find minFid for currentRid = " +
                                        currentRid + ", currentTypeId = " + currentTypeId +
                                        ", currentGroupName" + currentGroupName + " and fid(s) = ");
                                for(int fidIndex = 0; fidIndex < fids.size(); fidIndex++)
                                {
                                    currentFid = (String)fids.get(fidIndex);
                                    System.err.print(" " + currentFid + " ");
                                }
                                System.err.println();
                                System.err.flush();
                            }
                            else if(maxFids == null || maxFids.size() < 1)
                            {
                                System.err.print("Error unable to find maxFid for currentRid = " +
                                        currentRid + ", currentTypeId = " + currentTypeId +
                                        ", currentGroupName" + currentGroupName + " and fid(s) = ");
                                for(int fidIndex = 0; fidIndex < fids.size(); fidIndex++)
                                {
                                    currentFid = (String)fids.get(fidIndex);
                                    System.err.print(" " + currentFid + " ");
                                }
                                System.err.println();
                                System.err.flush();
                            }
                            else        // if((minFids.size() > 1 || maxFids.size() > 1) && fids.size() > combineSize)
                            {
                                ArrayList listOfMins = new ArrayList();
                                ArrayList listOfMaxs = new ArrayList();
                                for(int min = 0; min < minFids.size(); min++)
                                {
                                    String minFid = (String)minFids.get(min);
                                    fidGroupValueF.add(minFid); //Update minfid groupContext = 'F'
                                    listOfMins.add(minFid); // Local list of min
                                }
                                for(int max = 0; max < maxFids.size(); max++)
                                {
                                    String maxFid = (String)maxFids.get(max);
                                    fidGroupValueL.add(maxFid);  //Update maxfid groupContext = 'L'
                                    listOfMaxs.add(maxFid); // Local list of maxs
                                }

                                for(int fidIndex = 0; fidIndex < fids.size(); fidIndex++)
                                {
                                    currentFid = (String)fids.get(fidIndex);
                                    boolean found = false;

                                    for(int i = 0; i < listOfMins.size(); i++)
                                    {
                                        if(!found)
                                        {
                                            String tempMin = (String)listOfMins.get(i);
                                            found = currentFid.equalsIgnoreCase(tempMin);
                                        }
                                    }

                                    if(!found)
                                    {
                                        for(int i = 0; i < listOfMaxs.size(); i++)
                                        {
                                            if(!found)
                                            {
                                                String tempMax = (String)listOfMaxs.get(i);
                                                found = currentFid.equalsIgnoreCase(tempMax);
                                            }
                                        }
                                    }

                                    if(!found)
                                    {
                                        fidGroupValueM.add(currentFid);   //update fid groupContext = 'M'
                                    }
                                }
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


        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find empty groups for = " + refseqId);
            System.err.println("databaseName = " + databaseName);
            System.err.flush();
        }
        finally{
            timer.addMsg("DONE: GroupAssignerManyQueries#callMethodsForEmptyGroups") ;
            System.out.println(timer.generateStringWithReport());
            System.out.flush();
            totalTimer.addMsg("TotalTime Ends");
            System.out.println(totalTimer.generateStringWithReport());
            System.out.flush();
            return ;
        }
    }


    public void updateElementsOfGroup(ArrayList fidGroupValue, String groupContext, boolean finalUpdate)
    {
        Statement stmt = null;
        String theInStatement = null;
        String updateStatement = "UPDATE fdata2 SET groupContextCode = '" + groupContext + "' WHERE fid in( ";

        if(fidGroupValue.size() >= numberOfUpdatesToInsert || finalUpdate)
        {
            if(finalUpdate && fidGroupValue.size() < 1) return;
            timer.addMsg("  Inserting groupContext: GroupAssignerManyQueries#updateElementsOfGroup  groupContext = " + groupContext +
                    " where the size of the insetion group is " + fidGroupValue.size()) ;

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
                System.err.println("Wrong type of groupContext on GroupAssignerManyQueries#updateElementsOfGroup = " + groupContext);
                System.err.flush();
            }

            try
            {
                stmt = conn.createStatement();
                stmt.executeUpdate( updateStatement );
                stmt.close();
                timer.addMsg("  After the update groupContext: GroupAssigner#updateElementsOfGroup") ;
                try
                {
                    Util.sleep(sleepTimeBetweenUpdates);
                } catch (InterruptedException e)
                {
                    e.printStackTrace(System.err);
                }
            }
            catch (SQLException ex)
            {
                ex.printStackTrace(System.err);
            }

        }
        return;
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

    public ArrayList fetchListOfTrackIds( String rid )
    {
        String typeId = null;
        ResultSet rs = null;
        ArrayList ftypes = null;

        if(rid == null) return null;

        ftypes = new ArrayList();

        try
        {
//            getFtypesPstmt.setString( 1, rid);
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

    public ArrayList fetchFirstFidsWithEmptyGroups(String rid, String typeId, String gname)
    {
        String fid = null;
        String fstart = null;
        ResultSet rs = null;
        ArrayList fids = null;


        if( rid == null || typeId == null || gname == null ) return null;


        try
        {
            getMinFidPstmt.setString( 1, rid);
            getMinFidPstmt.setString( 2, typeId);
            getMinFidPstmt.setString( 3, gname);
            rs = getMinFidPstmt.executeQuery();

            if( rs.next() )
                fstart = rs.getString("fstart");

            if(fstart == null )return null;
            fids = new ArrayList();

            rs.close();
            rs = null;

            getFidUsingFstartPstmt.setString( 1, rid);
            getFidUsingFstartPstmt.setString( 2, typeId);
            getFidUsingFstartPstmt.setString( 3, gname);
            getFidUsingFstartPstmt.setString( 4, fstart);
            rs = getFidUsingFstartPstmt.executeQuery();

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

    public ArrayList fetchLastFidsWithEmptyGroups(String rid, String typeId, String gname)
    {
        String fid = null;
        String fstop = null;
        ResultSet rs = null;
        ArrayList fids = null;


        if( rid == null || typeId == null || gname == null ) return null;


        try
        {
            getMaxFidPstmt.setString( 1, rid);
            getMaxFidPstmt.setString( 2, typeId);
            getMaxFidPstmt.setString( 3, gname);
            rs = getMaxFidPstmt.executeQuery();

            if( rs.next() )
                fstop = rs.getString("fstop");

            if(fstop == null )return null;
            fids = new ArrayList();

            rs.close();
            rs = null;

            getFidUsingFstopPstmt.setString( 1, rid);
            getFidUsingFstopPstmt.setString( 2, typeId);
            getFidUsingFstopPstmt.setString( 3, gname);
            getFidUsingFstopPstmt.setString( 4, fstop);
            rs = getFidUsingFstopPstmt.executeQuery();

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
                "-r refseqid \n" +
                "Optional [\n" +
                "\t-n numberOfRecordsPerUpdate (default size = " + GroupAssignerManyQueries.numberOfUpdatesToInsert + ")\n" +
                "\t-u sleepTimeBetweeenUpdates (default time = " + GroupAssignerManyQueries.sleepTimeBetweenUpdates + ")\n" +
                "\t-s sleepTimeBetweenSelects (default time = " + GroupAssignerManyQueries.sleepTimeBetweenSelects + ")\n" +
                "\t-i sleepBetweenHowManySelects (default numberSelects = " + GroupAssignerManyQueries.sleepBetweenHowManySelects + ")\n" +
                "]\n");
        return;
    }
    public static void main(String[] args) throws Exception
    {
        String refseqId = null;
        GroupAssignerManyQueries groupAssigner;
        int numberOfSelects = -1;
        int sleepTimeBetweenSelects = -1;
        int sleepTimeBetweenUpdates = -1;
        int numberUpdates = -1;
        String bufferString = null;
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


        groupAssigner = new GroupAssignerManyQueries( refseqId );

        if(modifySleepTimeBetweenUpdates) GroupAssignerManyQueries.setSleepTimeBetweenUpdates(sleepTimeBetweenUpdates);
        if(modifySleepTimeBetweenSelects) GroupAssignerManyQueries.setSleepTimeBetweenSelects(sleepTimeBetweenSelects);
        if(modifyNumberOfSelects) GroupAssignerManyQueries.setSleepBetweenHowManySelects(numberOfSelects);
        if(modifyNumberUpdates) GroupAssignerManyQueries.setNumberOfUpdatesToInsert(numberUpdates);

        groupAssigner.callMethodsForEmptyGroups();
        System.exit(0);
    }



}


