package org.genboree.upload;

import org.genboree.dbaccess.DBAgent;
import org.genboree.util.DirectoryUtils;
import org.genboree.util.TimingUtil;
import org.genboree.util.Util;
import org.genboree.util.GenboreeUtils;

import java.sql.*;
import java.util.*;

public class GroupAssignerComplexUpdates
{

    protected DBAgent db = null;
    protected Connection conn = null;
    protected String databaseName = null;
    protected String refseqId = null;
    protected ArrayList fidGroupValueU = null;
    protected ArrayList fidGroupValueF = null;
    protected ArrayList fidGroupValueL = null;
    protected static int numberOfUpdatesToInsert = 100000;
    protected int counter = 0;
    protected static int sleepBetweenHowManySelects = 15000;
    protected static int sleepTimeBetweenSelects = 1000;
    protected static int sleepTimeBetweenUpdates = 1000;
    protected String selectMinMaxP1 = "select gname, min(fstart) minimum, max(fstop) maximums from fdata2 where rid = ";
    protected String selectMinMaxP2 =" and ftypeid= ";
    protected String selectMinMaxP3 = " group by gname limit ";
    protected String fidGroupSt = "UPDATE fdata2 SET groupContextCode = ";
    protected String getRidsQuery = "SELECT rid FROM fref";
    protected PreparedStatement getRidsPstmt;
    protected String getFtypesQuery = "SELECT ftypeid typeId from ftype";
    protected PreparedStatement getFtypesPstmt;
    protected TimingUtil timer = null;
    protected TimingUtil totalTimer = null;
    protected static int limit = 15000 ;
    protected int fidGroupValuesCounter = 0;


    public GroupAssignerComplexUpdates(String refSeqId, String databasename)
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
        timer = new TimingUtil() ;
        totalTimer = new TimingUtil() ;
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
            getFtypesPstmt = conn.prepareStatement( getFtypesQuery);


        }
        catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find empty groups for = " + databaseName);
            System.err.flush();
        }
        finally
        {
            return ;
        }
    }

    public static int getLimit()
    {
        return limit;
    }

    public static void setLimit(int limit)
    {
        GroupAssignerComplexUpdates.limit = limit;
    }

    public static int getSleepTimeBetweenSelects()
    {
        return sleepTimeBetweenSelects;
    }

    public static void setSleepTimeBetweenSelects(int sleepTimeBetweenSelects)
    {
        GroupAssignerComplexUpdates.sleepTimeBetweenSelects = sleepTimeBetweenSelects;
    }

    public static int getSleepTimeBetweenUpdates()
    {
        return sleepTimeBetweenUpdates;
    }

    public static void setSleepTimeBetweenUpdates(int sleepTimeBetweenUpdates)
    {
        GroupAssignerComplexUpdates.sleepTimeBetweenUpdates = sleepTimeBetweenUpdates;
    }

    public static int getNumberOfUpdatesToInsert()
    {
        return numberOfUpdatesToInsert;
    }

    public static void setNumberOfUpdatesToInsert(int numberOfUpdatesToInsert)
    {
        GroupAssignerComplexUpdates.numberOfUpdatesToInsert = numberOfUpdatesToInsert;
    }

    public static int getSleepBetweenHowManySelects()
    {
        return sleepBetweenHowManySelects;
    }

    public static void setSleepBetweenHowManySelects(int sleepBetweenHowManySelects)
    {
        GroupAssignerComplexUpdates.sleepBetweenHowManySelects = sleepBetweenHowManySelects;
    }


    public void callMethodsForEmptyGroups()
    {
        ArrayList rids = null;
        ArrayList typeids = null;
        int groupNamesCount = -1;
        String currentRid = null;
        String currentTypeId = null;

        timer.addMsg("BEGIN: GroupAssignerComplexUpdates#callMethodsForEmptyGroups") ;
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
                    updateElementsOfTrack( currentRid, currentTypeId, "M");
                    int groupCounter = 0;
                    int numberOfLoops = 0;
                    do {
                            groupNamesCount =  fetchListOfEmptyGroups(currentRid, currentTypeId,groupCounter);
                            numberOfLoops ++;
                            if(groupNamesCount >= limit)
                                groupCounter = limit * numberOfLoops;
                            else
                                groupCounter = 0;
                            updateElementsOfGroup(currentRid, currentTypeId, false);
                        }
                        while(groupCounter > 0 );

                        updateElementsOfGroup(currentRid, currentTypeId, true);
                    }
                }
        } catch( Exception ex )
        {
            ex.printStackTrace(System.err);
            System.err.println("Exception trying to find empty groups for = " + refseqId);
            System.err.println("databaseName = " + databaseName);
            System.err.flush();
        }
        finally{
            timer.addMsg("DONE: GroupAssignerComplexUpdates#callMethodsForEmptyGroups") ;
            System.out.println(timer.generateStringWithReport());
            System.out.flush();
            totalTimer.addMsg("TotalTime Ends");
            System.out.println(totalTimer.generateStringWithReport());
            System.out.flush();
            return ;
        }
    }

    public void updateElementsOfTrack( String rid, String typeId, String groupContext )
    {
        Statement stmt = null;
        String updateStatement = "UPDATE fdata2 SET groupContextCode = '" + groupContext +
                "' WHERE rid = " + rid + " AND ftypeid = " + typeId;

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


        return;
    }


    public void updateElementsOfGroup(String rid, String typeId, boolean finalUpdate)
    {
        Statement stmt = null;
        String theInStatementF = null;
        String theInStatementL = null;
        String theInStatementU = null;
        String updateStatementF = "UPDATE fdata2 SET groupContextCode = 'F' WHERE rid = " + rid + " AND ftypeid = " + typeId + " AND ";
        String updateStatementL = "UPDATE fdata2 SET groupContextCode = 'L' WHERE rid = " + rid + " AND ftypeid = " + typeId + " AND ";
        String updateStatementU = "UPDATE fdata2 SET groupContextCode = 'U' WHERE rid = " + rid + " AND ftypeid = " + typeId + " AND ";

        if(fidGroupValuesCounter >= numberOfUpdatesToInsert || finalUpdate)
        {
            if(fidGroupValueF.size() < 1) return;


            theInStatementF = DirectoryUtils.join(fidGroupValueF, " OR ");
            theInStatementL = DirectoryUtils.join(fidGroupValueL, " OR ");
            theInStatementU = DirectoryUtils.join(fidGroupValueU, " OR ");
            updateStatementF += theInStatementF;
            updateStatementL += theInStatementL;
            updateStatementU += theInStatementU;

            fidGroupValueF.clear();
            fidGroupValueL.clear();
            fidGroupValueU.clear();
            fidGroupValuesCounter = 0;

            try
            {
                stmt = conn.createStatement();

                stmt.executeUpdate( updateStatementF );
                stmt.executeUpdate( updateStatementL );
                stmt.executeUpdate( updateStatementU );
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



    public int fetchListOfEmptyGroups(String rid, String typeId, int groupCounter)
    {
        ResultSet rs = null;
        String queryForGroups = null;
        Statement stmt = null;
        String gname = null;
        String minFstart = null;
        String maxFstop = null;
        int localCounter = 0;


        if(rid == null || typeId == null) return -1;

        queryForGroups = selectMinMaxP1 + rid + selectMinMaxP2 + typeId + selectMinMaxP3 + groupCounter + "," + limit;

        try
        {
            stmt = conn.createStatement();
            rs = stmt.executeQuery( queryForGroups );

            while( rs.next() )
            {
                gname = rs.getString("gname");
                minFstart = rs.getString("minimum");
                maxFstop = rs.getString("maximums");
                String currentGroupName = "'" + GenboreeUtils.mysqlEscapeSpecialChars(gname) + "'";
                fidGroupValueF.add("( gname = " + currentGroupName + " AND fstart = " + minFstart + ") ");
                fidGroupValueL.add("( gname = " + currentGroupName + " AND fstop = " + maxFstop + ") ");
                fidGroupValueU.add("( gname = " + currentGroupName + " AND fstart = " + minFstart + " AND fstop = " + maxFstop + " ) ");
                fidGroupValuesCounter++;
                localCounter++;

            }


            stmt.close();
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
        return localCounter;

    }

    public static void printUsage()
    {
        System.out.print("usage: Empty Groups ");
        System.out.println(
                "-r refseqid ( or -d databaseName )\n" +
                "Optional [\n" +
                "\t-d databaseName\n" +
                "-r refseqid \n" +
                "Optional [\n" +
                "\t-n limit queries (default value = " + GroupAssignerComplexUpdates.limit + ")\n" +
                "\t-n numberOfRecordsPerUpdate (default size = " + GroupAssignerComplexUpdates.numberOfUpdatesToInsert + ")\n" +
                "\t-u sleepTimeBetweeenUpdates (default time = " + GroupAssignerComplexUpdates.sleepTimeBetweenUpdates + ")\n" +
                "\t-s sleepTimeBetweenSelects (default time = " + GroupAssignerComplexUpdates.sleepTimeBetweenSelects + ")\n" +
                "\t-i sleepBetweenHowManySelects (default numberSelects = " + GroupAssignerComplexUpdates.sleepBetweenHowManySelects + ")\n" +
                "]\n");
        return;
    }
    public static void main(String[] args) throws Exception
    {
        String refseqId = null;
        GroupAssignerComplexUpdates groupAssigner;
        int numberOfSelects = -1;
        int sleepTimeBetweenSelects = -1;
        int sleepTimeBetweenUpdates = -1;
        int numberUpdates = -1;
        int limits = -1;
        boolean modifyLimits = false;
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
                else if(args[i].compareToIgnoreCase("-l") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        limits = Util.parseInt(bufferString , -1);
                        if(limits > -1)
                            modifyLimits = true;
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


        groupAssigner = new GroupAssignerComplexUpdates( refseqId, databaseName );

        if(modifyLimits) GroupAssignerComplexUpdates.setLimit(limits);
        if(modifySleepTimeBetweenUpdates) GroupAssignerComplexUpdates.setSleepTimeBetweenUpdates(sleepTimeBetweenUpdates);
        if(modifySleepTimeBetweenSelects) GroupAssignerComplexUpdates.setSleepTimeBetweenSelects(sleepTimeBetweenSelects);
        if(modifyNumberOfSelects) GroupAssignerComplexUpdates.setSleepBetweenHowManySelects(numberOfSelects);
        if(modifyNumberUpdates) GroupAssignerComplexUpdates.setNumberOfUpdatesToInsert(numberUpdates);

        groupAssigner.callMethodsForEmptyGroups();
        System.exit(0);
    }



}
