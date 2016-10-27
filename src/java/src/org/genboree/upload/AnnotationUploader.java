package org.genboree.upload;

import org.genboree.dbaccess.*;
import org.genboree.util.GenboreeUtils;
import org.genboree.util.TimingUtil;
import org.genboree.util.Util;
import org.genboree.util.DirectoryUtils;
import org.genboree.util.FileKiller;

import java.io.*;
import java.security.MessageDigest;
import java.sql.*;
import java.util.*;

public class AnnotationUploader extends LffFileProperties implements LffConstants
{

    public AnnotationUploader( String myRefseqId, String userId, String groupId, String databaseName, PrintStream fullLogFile)
    {
        this(DBAgent.getInstance(), myRefseqId , userId, groupId, databaseName, fullLogFile);
    }


    public AnnotationUploader( String myRefseqId, String userId, String groupId, String databaseName)
    {
        this(DBAgent.getInstance(), myRefseqId , userId, groupId, databaseName, System.err);
    }

    public AnnotationUploader(DBAgent myDb, String myRefseqId, String userId, String groupId, String databaseName)
    {
        this(myDb, myRefseqId , userId, groupId, databaseName, System.err);
    }


    public AnnotationUploader( DBAgent myDb, String myRefseqId , String userId, String groupId,
                               String databaseName, PrintStream fullLogFile)
    {
        // Prep a single timer instance to use for this uploader instance
        this.timer = new TimingUtil() ;

        setDb(myDb);
        setDatabaseName(databaseName);
        boolean useVP = GenboreeUtils.isDatabaseUsingNewFormat(databaseName, false);
        setUsingValuePairs(useVP);
        setFullLogFile(fullLogFile);
        setDatabaseConnection();
        CacheManager.clearCache( myDb, databaseName);
        setMaxNumberOfInserts(defaultNumberOfInserts);
        setMaxSizeOfBufferInBytes(defaultMaxSizeOfBufferInBytes);
        prepareQueries();
        setMaxMinBins();
        setRefseqId(myRefseqId);
        setUserId(userId);
        setGroupId(groupId);
        initializeVariables();
        setHFref();
        setHtFtype();
        setHtGclass();
        setGclass2ftypesHash();
        ftypeIdsInLffFile = new HashMap();
        currentUploaderTimer = new TimingUtil() ;
        currentUploaderTimer.addMsg("BEGIN ANNOTATION UPLOADER Initializing AnnotationUploader");

        debugInfo = new StringBuffer(100);
        insertManager = new BulkUploadManager( getDatabaseConnection(), getDatabaseName(),
                 getMaxNumberOfInserts(), getMaxSizeOfBufferInBytes(), fullLogFile);
    }


    public void setFileName()
    {
        java.util.Date rightNow = new java.util.Date();
        String myRightNow = null;
        String nameToUse = null;

        myRightNow = rightNow.toString();
        myRightNow = myRightNow.replaceAll("\\s+", "");
        myRightNow = myRightNow.replaceAll(":", "");
        nameToUse = "databaseId" + refseqId + "-" + myRightNow + ".lff" ;
        fileName = nameToUse;
    }
    public void setFeatureTypeToGclasses(DBAgent db, String myRefseqId )
    {
        String[] ftypes = null;
        String[] uploads = null;
        String[]fmethodfsource = null;
        String[] classNames = null;

        ftypes = GenboreeUpload.fetchAllTracksFromUploads(db, myRefseqId, getGenboreeUserId() );
        uploads = GenboreeUpload.returnDatabaseNames(db, myRefseqId );
        featureTypeToGclasses = new HashMap();

        for(int i = 0; i < ftypes.length; i++)
        {
            String ftype = ftypes[i];
            if(ftype == null) continue;
            fmethodfsource = ftype.split(":");
            if(fmethodfsource == null || fmethodfsource.length < 2)
                continue;
            String fmethod = fmethodfsource[0];
            String fsource = fmethodfsource[1];
            if(fmethod != null && fsource != null)
                classNames = GenboreeUpload.fetchClassesInFtypeId(db, uploads, fmethod, fsource);
            if(classNames != null)
                featureTypeToGclasses.put( ftypes[i], classNames );
        }

        return;
    }
    public String fetchMainDatabaseName( Connection conn )
    {
        String qs = null;
        String mainDatabase = null;
        Statement stmt = null;
        ResultSet rs = null;

        if( getRefseqId().equals("#") ) return null;

        qs = "SELECT  databaseName FROM refseq where refSeqId = " +getRefseqId();
        try
        {
            stmt = conn.createStatement();
            rs = stmt.executeQuery( qs );
            if( rs.next() )
                mainDatabase = rs.getString("databaseName");
        } catch( Exception ex )
        {
            System.err.println("Exception trying to find database for refseqId = " + getRefseqId());
            System.err.flush();
        }
        finally{
            return mainDatabase;
        }
    }
    public void setGclass2ftypesHash()
    {
        StringBuffer query = null;
        String qs = null;
        String previousSortingValue = null;
        query = new StringBuffer( 200 );

        gclass2ftypesHash = new Hashtable();

        query.append("SELECT gclass.gclass myClass,  ftype.fmethod myMethod, ftype.fsource mySource ");
        query.append(", CONCAT('(',ftype.ftypeid,', ', gclass.gid, ')') myvalues ");
        query.append("FROM ftype, gclass, ftype2gclass WHERE ");
        query.append("ftype.ftypeid = ftype2gclass.ftypeid AND gclass.gid = ftype2gclass.gid ");
        query.append("order by ftype.ftypeid,gclass.gid");
        qs = query.toString();

        try
        {
            Statement stmt = databaseConnection.createStatement();
            ResultSet rs = stmt.executeQuery(qs);

            while( rs.next() )
            {
                String myClass = rs.getString("myClass");
                String myMethod = rs.getString("myMethod");
                String mySource = rs.getString("mySource");
                if(myClass == null || myMethod == null || mySource == null)
                {
                    continue;
                }
                myClass = myClass.toUpperCase();
                myMethod = myMethod.toUpperCase();
                mySource = mySource.toUpperCase();
                String myKey = myClass + ":" + myMethod + ":" + mySource;
                previousSortingValue = (String)gclass2ftypesHash.get(myKey);
                if(previousSortingValue == null)
                    gclass2ftypesHash.put(myKey, rs.getString("myValues"));
            }
            stmt.close();


        } catch( Exception ex ) {
            System.err.println("Exception during quering the db AnnotationUploader#setGclass2ftypesHash()");
            System.err.println("Databasename = " + getDatabaseName());
            System.err.println("The query is ");
            System.err.println(query.toString());
            System.err.flush();
        }

        return;
    }


    protected boolean defineFtype2Gclass( String className, String method, String source, int gid, int ftypeid )
    {
        String  methodUC = null;
        String sourceUC = null;
        String classNameUC = null;
        String ftype2gclassValue = null;
        String  myKey = null;
        boolean success = false;
        String tempFtype2gclassValue = null;


        if(className == null || method == null || source == null) return success;

        methodUC =  method.toUpperCase();
        sourceUC =  source.toUpperCase();
        classNameUC = className.toUpperCase();


        myKey = classNameUC + ":" + methodUC + ":" + sourceUC;
        ftype2gclassValue = (String)gclass2ftypesHash.get(myKey);

        if(ftype2gclassValue == null)
        {

            try {
                statementIndividualInsertsFtype2Gclass.setInt(1,ftypeid);
                statementIndividualInsertsFtype2Gclass.setInt(2,gid);
                statementIndividualInsertsFtype2Gclass.executeUpdate();
                ftype2gclassValue = "(" + ftypeid + ", " + gid + ")";
                gclass2ftypesHash.put(myKey, ftype2gclassValue);

                tempFtype2gclassValue = (String)gclass2ftypesHash.get(myKey);
                if(tempFtype2gclassValue != null) success = true;

            } catch (SQLException e) {
                e.printStackTrace(System.err);
            }
        }
        else
            success = true;


        return success;

    }
    protected boolean defineFtype2Gclass( String method, String source, String className )
    {
        String  methodUC = null;
        String sourceUC = null;
        String classNameUC = null;
        String ftKey = null;
        String ftype2gclassValue = null;
        String  myKey = null;
        DbFtype ft = null;
        DbGclass rc = null;
        boolean success = false;
        String tempFtype2gclassValue = null;


        if(className == null || method == null || source == null) return success;

        methodUC =  method.toUpperCase();
        sourceUC =  source.toUpperCase();
        classNameUC = className.toUpperCase();
        ftKey = methodUC+":"+sourceUC;

        ft = (DbFtype) htFtype.get( ftKey );
        rc = returnGclassCaseInsensitiveKey(className);

        if(ft == null || rc == null) return success;

        myKey = classNameUC + ":" + methodUC + ":" + sourceUC;
        ftype2gclassValue = (String)gclass2ftypesHash.get(myKey);

        if(ftype2gclassValue == null)
        {

            try {
                statementIndividualInsertsFtype2Gclass.setInt(1,ft.getFtypeid());
                statementIndividualInsertsFtype2Gclass.setInt(2,rc.getGid());
                statementIndividualInsertsFtype2Gclass.executeUpdate();
                ftype2gclassValue = "(" + ft.getFtypeid() + ", " + rc.getGid() + ")";
                gclass2ftypesHash.put(myKey, ftype2gclassValue);

                tempFtype2gclassValue = (String)gclass2ftypesHash.get(myKey);
                if(tempFtype2gclassValue != null) success = true;

            } catch (SQLException e) {
                e.printStackTrace(System.err);
            }
        }
        else
            success = true;


        return success;

    }
    public void setHtFtype()
    {
        htFtype = new Hashtable();
        DbFtype[] tps = DbFtype.fetchAll( databaseConnection, databaseName, getGenboreeUserId() );
        if( tps != null )
        {
            for(int i=0; i<tps.length; i++ )
            {
                DbFtype ft = tps[i];
                String methodUC = ft.getFmethod();
                methodUC = methodUC.toUpperCase();
                String sourceUC = ft.getFsource();
                sourceUC = sourceUC.toUpperCase();
                htFtype.put( methodUC+":"+sourceUC, ft );
            }
        }
    }
    public void setHFref()
    {
        htFref = new Hashtable();
        DbFref[] frs = DbFref.fetchAll( databaseConnection );
        for(int i=0; i<frs.length; i++ )
        {
            htFref.put( frs[i].getRefname(), frs[i] );
        }
    }
    public void initializeVariables()
    {
        currSect = "annotations";
        metaData = metaAnnotations;
        errs = new Vector();
        is_error = false;
        htGclass = new Hashtable();
        htFtype = new Hashtable();
        htFtypeGclass = new Hashtable();
        vFtype = new Vector();
        setMaxNumberOfErrors(50);
        setContinueAtLine(-1);
    }
    public void setHtGclass()
    {
        htGclass = new Hashtable();
        DbGclass[] gcs = DbGclass.fetchAll( databaseConnection );
        for(int i=0; i<gcs.length; i++ )
        {
            htGclass.put( ""+gcs[i].getGclass(), gcs[i] );
        }
    }
    public void setMaxMinBins()
    {
        try
        {
            minFbin = 1000L;
            maxFbin = 100000000L;
            PreparedStatement pstmt = databaseConnection.prepareStatement(
                    "SELECT fvalue FROM fmeta WHERE fname=?" );
            pstmt.setString( 1, "MIN_BIN" );
            ResultSet rs = pstmt.executeQuery();
            if( rs.next() ) minFbin = rs.getLong(1);
            pstmt.setString( 1, "MAX_BIN" );
            rs = pstmt.executeQuery();
            if( rs.next() ) maxFbin = rs.getLong(1);
            pstmt.close();
        } catch( Exception ex )
        {
            db.reportError( ex, "Refseq.initializeUpload()" );
        }

    }
    private void setDatabaseConnection()
    {
        DBAgent myDb = null;
        myDb = getDb();
        try
        {
            databaseConnection = myDb.getConnection( getDatabaseName(), false );

        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }
    }
    public void insertNewValuesGclass2FtypesHash()
    {
        StringBuffer query = null;
        String qs = null;
        query = new StringBuffer( 200 );
        Hashtable myGclass2ftypesHash = null;
        String deleteQuery = null;
        String[] processedList = null;
        Statement stmt = null;

        deleteQuery = "DELETE "+ getMysqlDeleteAttributes() + " FROM ftype2gclass";

        myGclass2ftypesHash = getGclass2ftypesHash();

        if(myGclass2ftypesHash != null && myGclass2ftypesHash.size() > 0)
        {

            query.append("INSERT ").append(getMysqlInsertAttributes()).append(" INTO ftype2gclass VALUES ");
            Vector inserts = new Vector();
            for( Enumeration en = myGclass2ftypesHash.keys(); en.hasMoreElements(); )
            {
                String myValue = (String)myGclass2ftypesHash.get( en.nextElement() );
                inserts.addElement(myValue);
            }

            processedList = new String[ inserts.size() ];
            inserts.copyInto( processedList );

            for( int j=0; j< processedList.length; j++ )
            {
                query.append(processedList[j]);
                if(j < (processedList.length -1))
                    query.append(", ");
            }


            qs = query.toString();

            try
            {
                stmt = databaseConnection.createStatement();
                stmt.executeUpdate( deleteQuery );
                stmt.executeUpdate(qs);
                stmt.close();
            } catch( Exception ex ) {
                System.err.println("Exception during closing the connection for ftype2gclass");
                System.err.println("Databasename = " + getDatabaseName());
                System.err.flush();
            }
        }

        return;
    }

    public void cleanUpAttTables()
    {
        Statement stmt = null;
        String deleteATTNAMESQuery = "DELETE FROM attNames WHERE attNames.attNameId NOT IN (SELECT fid2attribute.attNameId FROM fid2attribute)";
        String deleteATTVALUESSQuery = "DELETE FROM attValues WHERE attValues.attValueId NOT IN (SELECT fid2attribute.attValueId FROM fid2attribute)";

            try
            {
                stmt = databaseConnection.createStatement();
                stmt.executeUpdate( deleteATTNAMESQuery );
                stmt.executeUpdate( deleteATTVALUESSQuery );
                stmt.close();
            } catch( Exception ex ) {
                System.err.println("Exception during closing the connection for cleanUpAttTables()");
                System.err.println("Databasename = " + getDatabaseName());
                System.err.flush();
            }

        return;
    }

    public String[] returnVectorWithColumNames(ResultSet rs)
    {
        ResultSetMetaData rm = null;
        Vector columnNames = null;
        int numCols = 0;
        String[] columns = null;

        columnNames = new Vector();

        try {
            rm = rs.getMetaData();
            numCols = rm.getColumnCount();
            for(int i=0; i<numCols; i++ )
            {
                String lab = rm.getColumnLabel(i+1);
                columnNames.addElement( lab );
            }
            columns = new String[ columnNames.size() ];
            columnNames.copyInto( columns );
        }
        catch (SQLException e) {
            e.printStackTrace(System.err);
        }
        finally{
            return columns;
        }
    }
    public String[] retrieveClassesName(DBAgent db, String fmethod, String fsource)
    {
        String ftypeKey = null;
        HashMap myFtoCHash = null;
        String[] gclasses = null;

        if(fmethod == null|| fsource == null) return null;

        myFtoCHash = getFeatureTypeToGclasses();
        if(myFtoCHash == null) return null;

        ftypeKey = fmethod + ":" + fsource;
        gclasses = (String[])myFtoCHash.get(ftypeKey);

        return gclasses;
    }
    public String retrieveClassName(DBAgent db, String fmethod, String fsource)
    {
        String gclass = null;
        String[] gclasses = null;

        if(fmethod == null|| fsource == null) return null;

        gclasses = retrieveClassesName(db, fmethod, fsource);

        if(gclasses == null || gclasses.length == 0) return null;
        gclass = gclasses[0];

        return gclass;
    }
    public String retrieveExtraClassName(DBAgent db, String fmethod, String fsource)
    {
        String[] gclasses = null;
        int sizeOfClasses = 0;
        StringBuffer gclassBuffer = null;

        if(fmethod == null|| fsource == null) return null;

        gclasses = retrieveClassesName(db, fmethod, fsource);

        if(gclasses == null)
            return null;

        sizeOfClasses = gclasses.length;

        if(sizeOfClasses < 2) return null;

        gclassBuffer = new StringBuffer( 200 );
        gclassBuffer.append(" aHClasses=");
        for(int i = 1; i < sizeOfClasses; i++)
        {
            gclassBuffer.append(gclasses[i]);
            if(i < (sizeOfClasses -1))
                gclassBuffer.append(",");
        }
        gclassBuffer.append(";");
        return gclassBuffer.toString();
    }
    protected void reportError( String msg )
    {
        String prefx = is_error ? "\t" : "Error in line "+ getCurrentLffLineNumber()+": ";
        errs.addElement( prefx+msg );
        is_error = true;
    }
    public static String computeBin( long start, long stop, long min )
    {
        long tier = min;
        long bin_start, bin_end;
        while( true )
        {
            bin_start = start / tier;
            bin_end = stop / tier;
            if( bin_start == bin_end ) break;
            tier *= 10;
        }
        String fract = "" + bin_start;
        while( fract.length() < 6 ) fract = "0" + fract;
        return ""+tier+"."+fract;
    }
    protected void doConsumeReferencePoints( String[] rpt )
    {
        long entryPointLength = -1;
        String entryPointName = null;
        String className = null;
        DbFref entryPointObject = null;
        boolean updateEP= false;

        is_error = false;
        if( rpt[0]==null || rpt[1]==null || rpt[2]==null )
        {
            reportError( "Invalid format of entry point record" );
            return;
        }

        entryPointName = rpt[0].trim();
        entryPointLength = Util.parseLong( rpt[2], -1L );
        if( entryPointLength < 1L )
        {
            reportError( "Invalid length parameter" );
            return;
        }
        className = rpt[1].trim();


        if(!htFref.isEmpty())
            entryPointObject = (DbFref)htFref.get(entryPointName);

        if( entryPointObject != null )
        {
            long tempLength = entryPointObject.getLength();
            String tempClass = entryPointObject.getGname();

            if(tempLength != entryPointLength)
                updateEP = true;

            if(!tempClass.equalsIgnoreCase(className))
            {
                //TODO also need to update but Andrew did not request this feature for now
                // updateEP = true;
            }
            if(!updateEP)
                return;
            else
            {
                htFref.remove(entryPointName);
            }
        }
        else
        {
            entryPointObject =   new DbFref();
        }




        entryPointObject.setRefname( entryPointName );
        entryPointObject.setRlength( "" + entryPointLength );
        entryPointObject.setLength( entryPointLength );
        entryPointObject.setGname( className );
        String sFbin = computeBin( 1L, entryPointLength, minFbin );
        entryPointObject.setRbin( sFbin );
        try
        {
            DbGclass gclass = defineGclass( "Sequence" );
            entryPointObject.setGid( gclass.getGid() );

            DbFtype ft = defineFtype( "Component", "Chromosome" );
            entryPointObject.setFtypeid( ft.getFtypeid() );

            if(!updateEP)
                entryPointObject.insert( databaseConnection );
            else
                entryPointObject.update( databaseConnection );

            entryPointObject = DbFref.fetchByName( databaseConnection, entryPointName);

            htFref.put( entryPointName, entryPointObject );

        } catch( Exception ex )
        {
            String action = ( updateEP ) ? " insert" : " update ";
            System.err.println("Exception caught in AnnotationUploader on method doConsumeReferencePoints tying to " + action +
                    "entry point in database "  + getDatabaseName() );
            System.err.println("The refName is " +  entryPointName + " the size of the EP is " + entryPointLength );
            System.err.flush();
        }
    }
    public DbGclass returnGclassCaseInsensitiveKey(String gclass)
    {
        DbGclass tempRc = null;
        if( gclass == null ) return null;
        for( Enumeration en=htGclass.keys(); en.hasMoreElements(); )
        {
            String tempKey = (String) en.nextElement();
            if(gclass.equalsIgnoreCase(tempKey))
            {
                tempRc = (DbGclass) htGclass.get( tempKey );
                return tempRc;
            }
        }
        return null;
    }
    protected DbFtype defineFtype( String _method, String _source )
    {
        String methodUC =  _method.toUpperCase();
        String sourceUC =  _source.toUpperCase();
        String ftKey = methodUC+":"+sourceUC;
        DbFtype ft = (DbFtype) htFtype.get( ftKey );
        if( ft == null )
        {
            ft = new DbFtype();
            ft.setFmethod( _method );
            ft.setFsource( _source );
            ft.setDatabaseName(getDatabaseName());
            ft.insert( getDatabaseConnection());
            htFtype.put( ftKey, ft );
            vFtype.addElement( ftKey );
        }
        return ft;
    }
    protected DbGclass defineGclass( String gclass )
    {
        if(gclass == null) return null;
        DbGclass rc = returnGclassCaseInsensitiveKey(gclass);
        if( rc == null )
        {
            rc = new DbGclass();
            rc.setGclass( gclass );
            rc.insert( databaseConnection );
            htGclass.put( gclass, rc );
        }
        return rc;
    }
    protected int metaIndexOf( String s )
    {
        for( int i=0; i<metaData.length; i++ ) if( s.equals(metaData[i]) ) return i;
        return -1;
    }
    protected String getMeta( String[] d, String key )
    {
        int idx = metaIndexOf( key );
        if( idx >= 0 && idx < d.length ) return d[idx];
        return null;
    }
    protected void consumeReferencePoints( String[] d )
    {
        String[] rpt = new String[3];
        rpt[0] = getMeta( d, "id" );
        rpt[1] = getMeta( d, "class" );
        rpt[2] = getMeta( d, "length" );
        doConsumeReferencePoints( rpt );
    }
    protected void consumeAssembly( String[] d )
    {
        String[] rpt = new String[3];
        rpt[0] = getMeta( d, "id" );
        rpt[1] = getMeta( d, "class" );
        rpt[2] = getMeta( d, "end" );
        doConsumeReferencePoints( rpt );
    }
    public String getErrorAt( int i )
    {
        return (String) errs.elementAt(i);
    }
    public String extractExtraClasses(String originalComments)
    {
        String[] tokens = null;


        if(originalComments == null) return null;
        if(originalComments.indexOf(';') > -1)
            tokens = originalComments.split(";");
        else
        {
            tokens = new String[1];
            tokens[0] = originalComments;
        }

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();
            if(comment.startsWith("aHClasses="))
            {
                comment = comment.replaceFirst("aHClasses=", "");
                return comment;
            }
        }

        return null;
    }
    public String removeExtraClasses(String originalComments)
    {
        String[] tokens = null;
        StringBuffer stringBuffer = null;

        if(originalComments == null) return null;

        stringBuffer = new StringBuffer( 200 );
        if(originalComments.indexOf(';') > -1)
            tokens = originalComments.split(";");
        else
        {
            tokens = new String[1];
            tokens[0] = originalComments;
        }

        for( int i = 0; i < tokens.length; i++)
        {
            String comment = tokens[i].trim();
            if(comment.startsWith("aHClasses=")) { }
            else if(comment.startsWith("annotationColor=")) { }
            else if(comment.startsWith("annotationCode=")) { }
            else
            {
                stringBuffer.append(comment);
                stringBuffer.append(";");
                if(i < (tokens.length - 1))
                {
                    stringBuffer.append(" ");
                }
            }
        }
        if(stringBuffer.length() > 0)
            return stringBuffer.toString();
        else
            return null;
    }
    public void addToGclass2ftypesHash(String gname, String fmethod, String fsource, int gid, int ftypeid)
    {
        String myKey = null;
        String myValue = null;
        String previousSortingValue = null;
        String methodUC = null;
        String sourceUC = null;


        if(gname == null || fmethod == null || fsource == null) return;
        methodUC = fmethod.toUpperCase();
        sourceUC = fsource.toUpperCase();

        myKey = gname + ":" + methodUC + ":" + sourceUC;
        myValue = "(" + ftypeid + ", " + gid + ")";

        previousSortingValue = (String)gclass2ftypesHash.get(myKey);
        if(previousSortingValue == null)
            gclass2ftypesHash.put(myKey, myValue);
    }
    private void prepareQueries()
    {
        try
        {
            fdata2QueryToGetFid = databaseConnection.prepareStatement(selectFidFromFdata2);
            statementIndividualInsertsFtype2Gclass = databaseConnection.prepareStatement(getIndividualInsertsFtype2Gclass());

        } catch (SQLException e)
        {
            e.printStackTrace(System.err);  //To change body of catch statement use File | Settings | File Templates.
        }

    }
    protected long fetchFidFromFdata(LffData lffData)
    {
        String fbin = lffData.getsFbin();
        int rid = lffData.getRid();
        int ftypeId = lffData.getFtypeId();
        long fstart = lffData.getStart();
        long fstop = lffData.getStop();
        double fscore = lffData.getScore();
        String fstrand = lffData.getStrand();
        String fphase = lffData.getPhase();
        long ftargetStart = lffData.getTargetStart();
        long ftargetStop = lffData.getTargetStop();
        String gname = lffData.getGroupName();
        long fid = fetchFidFromFdata(fbin, rid, ftypeId, fstart, fstop, fscore, fstrand, fphase,
                ftargetStart, ftargetStop, gname);
        return fid;

    }
    protected long fetchFidFromFdata(String fbin, int rid, int ftypeId, long fstart, long fstop, double fscore, String fstrand, String fphase,
                                     long ftargetStart, long ftargetStop, String gname)
    {
        // double delta = 0.0000001;
        double delta = 1e-300 ;
        String newPhase;
        PreparedStatement askForFid = null;
        ResultSet fidRs = null;
        long fid = 0;
        String newFstrand;
        double fscoreStart;
        double fscoreEnd;


        if(fphase == null)
            newPhase = "0";
        else if(Util.parseInt(fphase, -1) > -1 && Util.parseInt(fphase, -1) < 3)
            newPhase = fphase;
        else
            newPhase = "0";

        if(fstrand == null)
            newFstrand = "+";
        else if(fstrand.equalsIgnoreCase("+") || fstrand.equalsIgnoreCase("-"))
            newFstrand = fstrand ;
        else
            newFstrand = "+";


        fscoreStart = fscore - delta;
        fscoreEnd = fscore + delta;

        try
        {

            askForFid  = fdata2QueryToGetFid;

            askForFid.setString( 1,  fbin);
            askForFid.setInt( 2,  rid);
            askForFid.setLong( 3, fstart );
            askForFid.setLong( 4, fstop );
            askForFid.setInt( 5, ftypeId);
            askForFid.setString( 6, gname );
            askForFid.setDouble( 7, fscoreStart);
            askForFid.setDouble( 8, fscoreEnd);
            askForFid.setString( 9, newFstrand);
            askForFid.setString( 10, newPhase);
            askForFid.setString( 11, " ");

            fidRs = askForFid.executeQuery();
            if( fidRs.next() ) fid = fidRs.getLong(1);

        } catch (SQLException e)
        {
            e.printStackTrace(System.err);
        }
        finally
        {
            return fid;
        }
    }
    protected String generateErrorReport(String [] d)
    {
        int fileLineNumber =  getCurrentLffLineNumber();
        StringBuffer commonError = null;

        commonError = new StringBuffer(50);

        commonError.append("An Error has been detected in the following Lff line:\n");
        for(int i = 0; i < d.length; i++)
        {
            commonError.append(d[i]);
            commonError.append("\t");
        }
        commonError.append("In LffLine number");
        commonError.append(fileLineNumber).append("\n").append("Error type: ");

        return commonError.toString();
    }



    private String manageClasses(LffData lffData)
    {
        DbGclass gclass = null;
        String newComments = null;
        String[] tokens = null;

        tokens = lffData.getExtraClasses();

        gclass = defineGclass( lffData.getClassName() );

        defineFtype2Gclass(lffData.getClassName(), lffData.getType(), lffData.getSubType(), gclass.getGid() , lffData.getFtypeId());

        if(tokens != null)
        {
            for(int i = 0; i < tokens.length; i++)
            {
                DbGclass newgclass = defineGclass( tokens[i] );
                defineFtype2Gclass(tokens[i], lffData.getType(), lffData.getSubType(), newgclass.getGid() , lffData.getFtypeId());
            }
        }

        return newComments;
    }

    public String listOfCommaSeparatedKeys( HashMap hashWithKeys )
    {
      StringBuffer ftypeIdsBuffer = null;
      int counterT = 0;

      if(hashWithKeys == null || hashWithKeys.size() < 1)
        return null;

      ftypeIdsBuffer = new StringBuffer( 200 );
      for( Object key : hashWithKeys.keySet() )
      {
        ftypeIdsBuffer.append( key );
        counterT += 1;
        if( counterT < hashWithKeys.size() )
          ftypeIdsBuffer.append( "," );
      }
      return ftypeIdsBuffer.toString();
    }




    public boolean loadLffFile()
    {
        boolean result = false;
        result = loadLffFile(false);
        return result;
    }


    public boolean loadLffFile(boolean debbuging)
    {
        FileReader frd = null;
        BufferedReader in = null;
        boolean success = false;
        int linesInLffFile = -1;

        currentLffLineNumber = 0;

        linesInLffFile = DirectoryUtils.getNumberLinesUsingWc(lffFile );

        insertManager.setNumberOfLinesInLffFile(linesInLffFile);
        currentUploaderTimer.addMsg("Start of loadLffFile");

        if(debbuging)
        {
            System.err.println("Inside the loadLffFile() before cleaning the hash");
            printHashTables();
        }
        setHFref();
        setHtFtype();
        setHtGclass();
        setGclass2ftypesHash();

        if(debbuging)
        {
            System.err.println("Inside the loadLffFile() after cleaning the hash");
            printHashTables();
        }

        try {
            frd = new FileReader( lffFile );
            in = new BufferedReader( frd );

            consume( "[annotations]" );
            String s;


            currentUploaderTimer.addMsg("Before the loop to load lff file");
            while( (s = in.readLine()) != null )
            {
                currentLffLineNumber++;
                if(isLimitInLffSize() && currentLffLineNumber > getLimitNumberOfLffLinesTo())
                    break;
                if(currentLffLineNumber > getContinueAtLine())
                {
                    consume( s );
                }
                if( getNumErrors() > getMaxNumberOfErrors() )
                {
                    break;
                }
            }
            currentUploaderTimer.addMsg("After the loop to load lff file");

            insertManager.finalFlushRecord();
            currentUploaderTimer.addMsg("After finalFlushRecord");
            insertManager.deleteReservedIds();
            currentUploaderTimer.addMsg("After deleteReservedIds");
            insertManager.terminateAttribute();
            currentUploaderTimer.addMsg("After terminateAtribute");
            GenboreeUtils.recalculateFbin(databaseConnection, maxFbin);
            newFtypes = new String[ vFtype.size() ];
            vFtype.copyInto( newFtypes );

            currentUploaderTimer.addMsg("After recalculateFbin");
            success = true;
            frd.close();
            if(deleteExtraRecords)
                cleanUpAttTables(); //TODO activate or not
            groupAssigner = new GroupAssigner( refseqId, null );
            groupAssigner.callMethodsForEmptyGroups();
            groupAssignerTimmerInfo = groupAssigner.getTimmingInfo();
            currentUploaderTimer.addMsg("After fillingEmptyGroupcontext");
            AnnotationCounter annotationCounter = new AnnotationCounter( refseqId, null, listOfCommaSeparatedKeys( ftypeIdsInLffFile ) );
            currentUploaderTimer.addMsg("After annotationCounter");
            CacheManager.clearCache( getDb(), databaseName );
            currentUploaderTimer.addMsg("After cachemanager clearCache");

        } catch (FileNotFoundException e) {
            e.printStackTrace(System.err);  //To change body of catch statement use File | Settings | File Templates.
            success = false;
        } catch (IOException e) {
            e.printStackTrace(System.err);  //To change body of catch statement use File | Settings | File Templates.
            success = false;
        }
        finally
        {

            currentUploaderTimer.addMsg("END lffLoading method in AnnotationUploader");
            timmingInfo = currentUploaderTimer.generateStringWithReport();
//            System.out.println(currentUploaderTimer.generateStringWithReport());
//            System.out.flush();
            return success;
        }
    }

    public boolean loadLffArray(String[] lffLines)
    {
        boolean success = false;

        int lineNumber = 0;


            String s;
            for(int i = 0; i < lffLines.length; i++)
            {
                s = lffLines[i];
                lineNumber++;
                consume( s );
            }

            insertManager.finalFlushRecord();
            insertManager.deleteReservedIds();
            insertManager.terminateAttribute();
            GenboreeUtils.recalculateFbin(databaseConnection, maxFbin);
            newFtypes = new String[ vFtype.size() ];
            vFtype.copyInto( newFtypes );

            success = true;
            GenboreeUtils.fillAllEmptyGroupContext(getRefseqId());
            CacheManager.clearCache( getDb(), databaseName );

            return success;
    }




    public void consume( String s )
    {
        // Let's not make this any longer (in code or time) than needed,
        // it is called millions of times for large files.
        s = s.trim() ;
        String[] data = s.split("\t") ; // 99% of the time we need to do this anyway
        if(data.length > 8)
        {
          if((s.indexOf('}') > -1) || (s.indexOf('{') > -1) )
            {
              s = s.replaceAll(  "[{]" , "[" );
              s = s.replaceAll(  "[}]" , "]" );
              data = s.split("\t") ; // 99% of the time we need to do this anyway
            }
        }
        String md5LineValue = GenboreeUtils.generateUniqueKey(s);

        if( (s.length() == 0) || (s.charAt(0) == '#') )
        {
            return ;
        }
        else if(data.length == 1) // then maybe a header line (or who knows what?)
        {
            if( s.regionMatches(true, 0, "[annotations]", 0, 13) )
            {
                currSect = "annotations";
                metaData = metaAnnotations;
                return ;
            }
            else if( s.regionMatches(true, 0, "[assembly]", 0 ,10) )
            {
                currSect = "assembly";
                metaData = metaAssembly;
                return ;
            }
            else if( s.regionMatches(true, 0, "[reference_points]", 0, 18) ||
                     s.regionMatches(true, 0, "[references]", 0, 12) ||
                     s.regionMatches(true, 0, "[entrypoints]", 0, 13) ||
                     s.regionMatches(true, 0, "[entry points]", 0, 14) )
            {
                currSect = "reference_points";
                metaData = metaReferencePoints;
                return ;
            }
            else
            {
              // dunno what this is...it has 1 word, but not a header.
              // code previously ignored this case, keeping the same section; we will do this also
              return ;
            }
        }
        else // figure it out by its length ?
        {
            if(data.length == 3)
            {
                currSect = "reference_points";
                metaData = metaReferencePoints;
                if( !ignore_refseq )
                {
                    consumeReferencePoints( data );
                }
            }
            else if(data.length == 7)
            {
                currSect = "assembly";
                metaData = metaAssembly;
                if( !ignore_assembly )
                {
                    consumeAssembly( data );
                }
            }
            else if(data.length >= 10 && data.length <= maxNumberOfColumnsInLff)
            {
                currSect = "annotations";
                metaData = metaAnnotations;
                if( !ignore_annotations )
                {
                    consumeAnnotations( data, md5LineValue );
                }
            }
            else
            {
                return;
            }
        }
        return ;
    }

    protected LffData verifyLffData(LffData lffDataToProcess)
    {
        LffData lffData = lffDataToProcess;

        if(lffData.isParseError() || htFref == null || htFref.isEmpty())
            return null;
        DbFref fref = (DbFref) htFref.get( lffData.getEntryPoint() );
        if( fref == null )
        {
            lffData.reportError("Undefined entry point");
            return null;
        }
        long epLen = Util.parseLong( fref.getRlength(), -1L );
        if( lffData.getStart() > epLen ) lffData.setStart(epLen);
        if( lffData.getStop() > epLen ) lffData.setStop(epLen);

        if(lffData.getStart() > lffData.getStop())
        {
            long tempValue  = lffData.getStart();
            lffData.setStart( lffData.getStop());
            lffData.setStop( tempValue);
        }

        lffData.setRid(fref.getRid());

        if(getByPassClassName() && getNameNewClass() != null)
            lffData.setClassName(getNameNewClass().trim());

        DbFtype ft = defineFtype( lffData.getType(), lffData.getSubType() );
        if(ft.getFtypeid() < 1)
        {
            lffData.reportError("unable to insert ftypeid using " + lffData.getType() + ":" + lffData.getSubType());
            return null;
        }
        else
            lffData.setFtypeId(ft.getFtypeid());

        manageClasses(lffData);

       if(!lffData.isParseError() && lffData.isAnnotationsSuccessfullyParsed())
       {
           return lffData;
       }
        else
       {
           return null;
       }
    }




    protected void consumeAnnotations( String[] d , String lineMd5Value)
    {
        long fid = 0;
        char typeOfNote = ' ';
        LffData lffData = null;
        boolean updateFids = false;

        lffData = new LffData( d, getCurrentLffLineNumber(), lineMd5Value, isUsingValuePairs() );

        lffData = lffData.parseAnnotationData();


        if(lffData == null)
        {
/*
            System.err.println("Did not passed the line " + getCurrentLffLineNumber() + " with the line = ");
            for(int i = 0; i < d.length; i++)
                System.err.print(d[i] + "   ");
            System.err.println();
            System.err.flush();
*/
            return;
        }
        else
        {
//            lffData.printLffLine();
        }

        lffData = verifyLffData(lffData);
        if( lffData != null )
        {
            ftypeIdsInLffFile.put(lffData.getFtypeIdString(), lffData.getType() + ":" + lffData.getSubType() );
            annotationsSuccessfullyParsed++;
        }
        else
        {
            /*
           System.err.println("Did not passed the verification the line " + getCurrentLffLineNumber() + " with the line = ");
            for(int i = 0; i < d.length; i++)
                System.err.print(d[i] + "   ");
            System.err.println();
            System.err.flush();
            */
            return;
        }

        fid = fetchFidFromFdata(lffData);

        if(fid > 0) // In here the lffData already exist in the database check if neet to be updated
        {
            annotationsForUpdate++;
            lffData.setFid(fid);

            if(lffData.getAnnotationAction() == DELETEANNOTATION)
            {
                insertManager.addToDeleteFdata2(fid);
                insertManager.addValuePairIdsToDelete(fid);
                insertManager.commentsDeleter.addId("" + fid);
                insertManager.commentsDeleterCounter++;
                insertManager.sequenceDeleter.addId("" + fid);
                insertManager.sequenceDeleterCounter++;
            }
            else
            {

                insertManager.updateFdata(lffData);
                insertManager.updateFidText(lffData);

                if(lffData.getAttributeAction() != APPENDATTRIBUTE)
                    insertManager.addValuePairIdsToDelete(fid);

                if(lffData.getAttributeAction() != DELETEATTRIBUTE)
                    insertManager.addValuePairRecord(fid, lffData.getFtypeId(), lffData.getValuePairs());
            }
        }
        else
        {
            annotationsForInsertion++;
            boolean newInsert = insertManager.addValuesFdata(lffData);
            if(!newInsert) return;

            if(!lffData.isCommentsEmpty() && !isIgnoreComments())
            {
                typeOfNote = 't';
                insertManager.addValuesFidText(lffData, String.valueOf(typeOfNote));
            }

            if( !lffData.isSequencesEmpty() && !isIgnoreComments())
            {
                typeOfNote = 's';
                insertManager.addValuesFidText(lffData, String.valueOf(typeOfNote));
            }

            if(lffData.getAttributeAction() != DELETEATTRIBUTE)
                insertManager.addValuePairRecord(lffData.getFid(), lffData.getFtypeId(), lffData.getValuePairs());

        }
        lffData = null ;
    }


    public void addEntryPoints (String s )
    {
        String ss = s.trim().toLowerCase();
        if( ss.startsWith("[reference_points]") || ss.startsWith("[references]") )
        {
            currSect = "reference_points";
            metaData = metaReferencePoints;
            return;
        }

        String[] data = Util.parseString( s, '\t' );
        if( currSect.equals("reference_points") )
        {
            if( !ignore_refseq )
                consumeReferencePoints( data );
        }


    }
    public int getMaxNumberOfErrors()
    {
        return maxNumberOfErrors;
    }
    public int getNumErrors()
    {
        return errs.size();
    }
    public int getCurrentLffLineNumber()
    {
        return currentLffLineNumber;
    }

    public void printHashTables()
    {

        System.err.println("The ftypes in the hash After loading the lff file are:");
        for( Enumeration en=htFtype.keys(); en.hasMoreElements(); )
        {
            String tempKey = (String) en.nextElement();
            DbFtype ft = (DbFtype)htFtype.get(tempKey);
            System.err.println("key = " + tempKey + "ftypeid = " + ft.getFtypeid() + " and method:source = " +  ft.getFmethod() + ":" + ft.getFsource());
        }
        System.err.flush();


        System.err.println("The gclasses in the hash are:");
        for( Enumeration en=htGclass.keys(); en.hasMoreElements(); )
        {
            String tempKey = (String) en.nextElement();
            DbGclass gc = (DbGclass)htGclass.get(tempKey);
            System.err.println("key = " + tempKey + "gid = " + gc.getGid() + " and className  = " +  gc.getGclass());
        }
        System.err.flush();


        System.err.println("The chromosomes in the hash are:");
        for( Enumeration en=htFref.keys(); en.hasMoreElements(); )
        {
            String tempKey = (String) en.nextElement();
            DbFref chr = (DbFref)htFref.get(tempKey);
            System.err.println("key = " + tempKey + "rid = " + chr.getRid() + " and chromosome name   = " +  chr.getRefname());
        }
        System.err.flush();
    }





    public void deleteRefseqs()
    {
        String truncateSt = "TRUNCATE TABLE ";
        String[] truncateTables = {"fref", "rid2ridSeqId", "ridSequence"};

        try
        {

            Statement stmt = databaseConnection.createStatement();
            for(int i = 0; i < truncateTables.length; i++)
            {
                stmt.executeUpdate( truncateSt + truncateTables[i]);
            }

            stmt.close();

        } catch( Exception ex ) {
            System.err.println("Exception during truncating tables");
            System.err.println("Databasename = " + getDatabaseName());
            System.err.flush();
        }
    }

    public void cleanOldTables()
    {
        String truncateSt = "TRUNCATE TABLE ";
        String[] truncateTables = {"fdata2","attNames",
                                   "attValues","fidText",
                                   "fid2attribute"};
        try
        {

            Statement stmt = databaseConnection.createStatement();
            for(int i = 0; i < truncateTables.length; i++)
            {
                stmt.executeUpdate( truncateSt + truncateTables[i]);
            }
            stmt.close();

        } catch( Exception ex ) {
            System.err.println("Exception during truncation of tables");
            System.err.println("Databasename = " + getDatabaseName());
            System.err.flush();
        }
    }




    public void truncateAllTables()
    {
        String truncateSt = "TRUNCATE TABLE ";
        String[] truncateTables = {"fdata2","fdata2_cv",
                                   "fdata2_gv","featuredisplay",
                                   "featuresort","featuretocolor",
                                   "featuretolink","featuretostyle",
                                   "featureurl","fidText","ftype2gclass","link", "ftype", "gclass"};

        String insertFtype = "INSERT " + getMysqlInsertAttributes() + " INTO ftype VALUES (1,'Component','Chromosome'),(2,'Supercomponent','Sequence')";
        String insertGclass = "INSERT " + getMysqlInsertAttributes() + " INTO gclass VALUES (1,'Sequence'),(2,'Chromosome')";
        try
        {

            Statement stmt = databaseConnection.createStatement();
            for(int i = 0; i < truncateTables.length; i++)
            {
                stmt.executeUpdate( truncateSt + truncateTables[i]);
            }

            stmt.executeUpdate(insertFtype);
            stmt.executeUpdate(insertGclass);
            stmt.close();

        } catch( Exception ex ) {
            System.err.println("Exception during truncation of tables");
            System.err.println("Databasename = " + getDatabaseName());
            System.err.flush();
        }
    }
    public void truncateTables()
    {
        System.err.println("TRUNCATING tables!!!!!!!!!!!!!!") ;
        String truncateSt = "TRUNCATE TABLE ";
        String[] truncateTables = {"fdata2","fdata2_cv",
                                   "fdata2_gv",
                                   "fidText",
                                   "blockLevelDataInfo"};

        String insertFtype = "INSERT " + getMysqlInsertAttributes() + " INTO ftype VALUES (1,'Component','Chromosome'),(2,'Supercomponent','Sequence')";
        String insertGclass = "INSERT " + getMysqlInsertAttributes() + " INTO gclass VALUES (1,'Sequence'),(2,'Chromosome')";
        String updateFtypeCount = "UPDATE ftypeCount SET numberOfAnnotations=0";
        try
        {

            // Reset  ftypecount tables.
            
            

            // Remove bin files
            File[] binFiles = fetchHdhvBinFiles();
            // Delete the files
            if(binFiles != null && binFiles.length > 0)
            {
              for( int i=0; i<binFiles.length; i++ )
              {
                FileKiller.clearDirectory(binFiles[i]) ;
                binFiles[i].delete() ;
              }
            }
            
            // Remove annotationFileData, delete the database level dir
            /* Disabled for now so we don't delete anything unexpectedly
            Refseq rseq = new Refseq() ;
            rseq.setRefSeqId(getRefseqId()) ;
            File[] annoDirFileArr = rseq.fetchAnnotationDataFilesDirs(getDb()) ;
            if(annoDirFileArr != null && annoDirFileArr.length > 0)
            {
              for( int i=0; i<annoDirFileArr.length; i++ )
              {
                System.err.println("DELETING ANNO FILE!!!!!!!!!!!!!!") ;
                System.err.println(annoDirFileArr[i]) ;
                FileKiller.clearDirectory(annoDirFileArr[i]) ;
                annoDirFileArr[i].delete() ;
              }
            }            
            */

            Statement stmt = databaseConnection.createStatement();
            for(int i = 0; i < truncateTables.length; i++)
            {
                stmt.executeUpdate( truncateSt + truncateTables[i]);
            }

            stmt.executeUpdate(insertFtype);
            stmt.executeUpdate(insertGclass);
            stmt.executeUpdate(updateFtypeCount);
            stmt.close();

        } catch( Exception ex ) {
            System.err.println("Exception during truncation of tables");
            System.err.println("Databasename = " + getDatabaseName());
            ex.printStackTrace();
            System.err.flush();
        }
    }
    
    public File[] fetchHdhvBinFiles()
    {
      File[] rc = null ;
      try
      {
        Statement stmt = databaseConnection.createStatement() ;
        // Get the ridSequence dir from fmeta
        ResultSet rs = stmt.executeQuery("SELECT fvalue FROM fmeta WHERE fname = 'RID_SEQUENCE_DIR'") ;
        if(rs != null && rs.next()) {
          String ridBaseDir = rs.getString(1) ;
          // Get the fileNames
          if( databaseConnection == null ) return null ;
          String qs = "SELECT DISTINCT fileName FROM blockLevelDataInfo" ;
          PreparedStatement pstmt = databaseConnection.prepareStatement(qs) ;
          rs = pstmt.executeQuery() ;
          Vector v = new Vector() ;
          while( rs.next() )
          {
            String fileName = rs.getString(1) ;
            String binFileName = ridBaseDir + '/' + fileName;
            File grpDirPathFile = new File( binFileName ) ;
            v.addElement( grpDirPathFile ) ;
          }
          pstmt.close();
          rc = new File[ v.size() ];
          v.copyInto( rc );
        }
      } catch( Exception ex ) {
        System.err.println("\n\n: Error in AnnotationUploader.fetchHdhvBinFiles(); ");
        ex.printStackTrace();
      }
      return rc;    
   }
     
    
    public static void printUsage()
    {
        System.out.print("usage: AnnotationUploader ");
        System.out.println("" +
                "-u userId -r refSeqId  -l lffFile \n" +
                "Optional [\n" +
                "\t-a bufferSizeInKB (default size = " + defaultMaxSizeOfBufferInBytes + " Mb this value has to\n" +
                "\t-b numberOfInserts (default Number of Inserts = " + defaultNumberOfInserts + ")\n" +
                "\t\tbe less that the variable set in the mysqlserver max_allowed_packet values allowed are between 8 and 512 Kb)\n" +
                "\t-c { create a new Database With the following options }\n" +
                "\t-d { delete Annotations }\n"+
                "\t-e { upload ONLY entry Points ignore annotation section } \n" +
                "\t-f fileName \n"+
                "\t-g groupId\n" +
                "\t-h fullDatabaseName\n" +
                "\t-i {do not insert data just process}\n" +
                "\t-j attributesForInsert (Default = IGNORE)\n" +
                "\t-k {continue at line }\n" +

                "\t-m { is Merged }\n" +
                "\t-nn refseqName\n" +
                "\t-nd description\n" +
                "\t-ns species\n" +
                "\t-nv version\n" +
                "\t-o { delete data tables and ftype tables } \n"+
                "\t-p { print Queries default STDOUT unless a file name is specified with the -f option } \n"+

                "\t-s sleep time between inserts \n" +
                "\t-t templateId\n" +

                "\t-v attributesForDelete (For example IGNORE)\n" +
                "\t-w numberOfLinesToProcess\n" +
                "\t-x { delete Entry Points}\n"+
                "\t-y {ignore comments}\n" +
                "\t-z { ignore entryPoints}\n" +
                "]\n");
        return;
    }
    public static void main(String[] args) throws Exception
    {
        String myRefSeqId = null;
        DBAgent myDb = null;
        AnnotationUploader currentUpload = null;
        boolean deleteAnnotations = false;
        boolean deleteAnnotationsAndFtypes = false;
        String userId = null;
        String groupId = null;
        String fullDatabaseName = null;
        String templateId = null;
        boolean isMerged = false;
        boolean createANewDB = false;
        boolean fileLoaded = false;
        DatabaseCreator dbC = null;
        boolean validRefseqId = false;
        String refseqName = null;
        String description = null;
        String species = null;
        String version = null;
        String bufferString = null;
        String bufferInBytesString = null;
        int bufferSize = 0;
        int bufferSizeInBytes = 0;
        boolean dbInfo = false;
        boolean ignoreTheAnnotations = false;
        boolean ignoreTheEntryPoints = false;
        boolean deleteEntryPoints = false;
        boolean printQueries = false;
        boolean setBufferSize = false;
        boolean setBufferSizeInBytes = false;
        boolean ignoreInserts = false;
        boolean ignoreTheComments = false;
        boolean limitTheLffFile = false;
        int numberOfLinesToLimitLff = 0;
        int sleepTime = LffConstants.uploaderSleepTime;
        boolean modifySleepTime = false;
        int startAtLine = -1;
        ArrayList lffFiles;
        String myFile = null;
        PrintWriter fout = null;
        String deleteAttributes = null;
        String insertAttributes = null;

        if(args.length == 0 )
        {
            printUsage();
            System.exit(-1);
        }

        lffFiles = new ArrayList();

        if(args.length >= 1)
        {

            for(int i = 0; i < args.length; i++ )
            {
                if(args[i].compareToIgnoreCase("-x") == 0)
                {
                    deleteEntryPoints = true;
                    deleteAnnotationsAndFtypes = true;
                }
                else if(args[i].compareToIgnoreCase("-d") == 0)
                {
                    deleteAnnotations = true;
                }
                else if(args[i].compareToIgnoreCase("-o") == 0)
                {
                    deleteAnnotationsAndFtypes = true;
                }
                else if(args[i].compareToIgnoreCase("-e") == 0)
                {
                    ignoreTheAnnotations = true;
                }
                else if(args[i].compareToIgnoreCase("-p") == 0)
                {
                    printQueries = true;
                }
                else if(args[i].compareToIgnoreCase("-f") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        myFile = args[i];
                    }
                }

                else if(args[i].compareToIgnoreCase("-z") == 0)
                {
                    ignoreTheEntryPoints = true;
                }
                else if(args[i].compareToIgnoreCase("-i") == 0)
                {
                    ignoreInserts = true;
                }
                else if(args[i].compareToIgnoreCase("-y") == 0)
                {
                    ignoreTheComments = true;
                }
                else if(args[i].compareToIgnoreCase("-c") == 0)
                {
                    createANewDB = true;
                }
                else if(args[i].compareToIgnoreCase("-m") == 0)
                {
                    isMerged = true;
                }
                else if(args[i].compareToIgnoreCase("-u") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        userId = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-s") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferInBytesString = args[i];
                        sleepTime = Util.parseInt(bufferInBytesString , -1);
                        if(sleepTime > -1)
                            modifySleepTime = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-w") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferInBytesString = args[i];
                        numberOfLinesToLimitLff = Util.parseInt(bufferInBytesString , -1);
                        if(numberOfLinesToLimitLff > 0)
                            limitTheLffFile = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-k") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferInBytesString = args[i];
                        startAtLine = Util.parseInt(bufferInBytesString , -1);
                    }
                }
                else if(args[i].compareToIgnoreCase("-j") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        insertAttributes = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-v") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        deleteAttributes = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-b") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferString = args[i];
                        bufferSize = Util.parseInt(bufferString , -1);
                        if(bufferSize > 0) setBufferSize = true;
                    }
                }
                else if(args[i].compareToIgnoreCase("-a") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        bufferInBytesString = args[i];
                        bufferSizeInBytes = Util.parseInt(bufferInBytesString , -1);
                        if(bufferSizeInBytes > -1 && bufferSizeInBytes < 1025)
                            setBufferSizeInBytes = true;
                        else
                        {
                            System.err.println("Wrong argument the -a option should be a integer between 1 and 1024");
                            System.err.flush();
                            System.exit(-1);
                        }
                    }
                }
                else if(args[i].compareToIgnoreCase("-g") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        groupId = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-t") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        templateId = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-l") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        lffFiles.add(args[i]);
                    }
                }
                else if(args[i].compareToIgnoreCase("-h") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        fullDatabaseName = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-r") == 0)
                {
                    i++;
                    if(args[i] != null)
                    {
                        myRefSeqId =args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-nn") == 0){
                    if(args[i+ 1] != null){
                        refseqName = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-nd") == 0){
                    if(args[i+ 1] != null){
                        description =args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-ns") == 0){
                    if(args[i+ 1] != null){
                        species = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-nv") == 0){
                    if(args[i+ 1] != null){
                        version = args[i + 1];
                    }
                }
            }

        }
        else
        {
            printUsage();
            System.exit(-1);
        }

        if(myRefSeqId != null || fullDatabaseName != null)
            dbInfo = true;

        if( !dbInfo && !createANewDB)
        {
            printUsage();
            System.exit(-1);
        }

        if(userId == null)
        {
            printUsage();
            System.exit(-1);
        }


        myDb = DBAgent.getInstance();

        validRefseqId = DatabaseCreator.checkIfRefSeqExist(myDb, myRefSeqId, fullDatabaseName);

        if(validRefseqId)
        {
            dbC = new DatabaseCreator(myDb, fullDatabaseName, myRefSeqId);
        }
        else if(!validRefseqId && createANewDB && userId != null)
        {
            dbC = new DatabaseCreator(myDb, groupId, userId, myRefSeqId,
                    templateId,refseqName, description, species, version, isMerged);
        }
        else
            return;


        if(dbC != null && dbC.getRefSeqIdInt() > 0 && !validRefseqId)
            System.err.println("a new genboree database (" + dbC.getDatabaseName() + ") with refseqId = " + dbC.getRefSeqIdInt() + " has been created");



        if(fullDatabaseName == null)
            fullDatabaseName = dbC.getDatabaseName();

        if(groupId == null)
            groupId = dbC.getGroupId();

        if(userId == null)
            userId = dbC.getUserId();

        if(myRefSeqId == null)
            myRefSeqId = dbC.getRefSeqId();


        currentUpload = new AnnotationUploader(myDb, myRefSeqId, userId, groupId, fullDatabaseName);

        if(currentUpload != null)
        {
            currentUpload.setPrintQueries(printQueries);
            currentUpload.setIgnoreComments(ignoreTheComments);
            if(startAtLine > 1)
                currentUpload.setContinueAtLine(startAtLine);
        }

        if(currentUpload != null && limitTheLffFile)
        {
            currentUpload.setLimitInLffSize(limitTheLffFile);
            if(startAtLine > 1)
                numberOfLinesToLimitLff += startAtLine;
            currentUpload.setLimitNumberOfLffLinesTo(numberOfLinesToLimitLff);
        }

        if(currentUpload != null)
            currentUpload.setInsertData(!ignoreInserts);

        if(currentUpload != null && setBufferSize)
            currentUpload.setMaxNumberOfInserts(bufferSize);

        if(currentUpload != null && insertAttributes != null)
            currentUpload.setMysqlInsertAttributes(insertAttributes);

        if(currentUpload != null && deleteAttributes != null)
            currentUpload.setMysqlDeleteAttributes(deleteAttributes);

        if(currentUpload != null && setBufferSizeInBytes)
            currentUpload.setMaxSizeOfBufferInBytes(bufferSizeInBytes * 1024 * 1024);

        if(currentUpload != null && modifySleepTime)
            currentUpload.setSleepTime(sleepTime);

        if(deleteAnnotations && currentUpload != null)
            currentUpload.truncateTables();

        if(deleteAnnotationsAndFtypes && currentUpload != null)
            currentUpload.truncateAllTables();

        if(deleteEntryPoints && currentUpload != null)
            currentUpload.deleteRefseqs();

        if(ignoreTheAnnotations && currentUpload != null)
            currentUpload.setIgnore_annotations(true);

        if(ignoreTheEntryPoints  && currentUpload != null)
        {
            currentUpload.setIgnore_refseq(true);
            currentUpload.setIgnore_assembly(true);
        }

        if(myFile != null)
            fout = new PrintWriter( new FileWriter(myFile) );
        else
            fout = new PrintWriter(System.out);

        currentUpload.setPrinterOutStream(fout);

        if(lffFiles != null && lffFiles.size() > 0)
        {
            for(int i = 0; i < lffFiles.size(); i++)
            {
                String lffFile = (String)lffFiles.get(i);
//                System.err.println("The lff file["+ i + "] is " + lffFile);
                currentUpload.setLffFile(lffFile);
                fileLoaded = currentUpload.loadLffFile();
            }
        }



        if(fileLoaded)
        {
            System.err.println("Lff files have been uploaded successfully");
            System.err.flush();
        }
        else if(!fileLoaded && !deleteEntryPoints && !deleteAnnotations && !deleteAnnotationsAndFtypes)
        {
            System.err.println("You need to provide a lff file with full path using -l fullPath/lffFile");
            System.err.flush();
        }


        int nerr = currentUpload.getNumErrors();
        for(int  i=0; i<nerr; i++ )
        {
            System.err.println( currentUpload.getErrorAt(i) );
        }

        fout.close();

        System.exit(0);
    }

}
