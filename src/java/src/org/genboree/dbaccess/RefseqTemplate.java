package org.genboree.dbaccess;

import org.genboree.util.Util;

import java.io.*;
import java.util.*;
import java.sql.*;

public class RefseqTemplate
{
  // CONSTANTS
  public static final int NO_LIMIT = -1 ;
  
  protected String refseqTemplateId;
  public String getRefseqTemplateId() { return refseqTemplateId; }
  public void setRefseqTemplateId( String refseqTemplateId )
  {
      if( refseqTemplateId == null ) refseqTemplateId = "#";
      this.refseqTemplateId = refseqTemplateId;
  }
  protected String FK_genomeTemplate_id;
  public String getFK_genomeTemplate_id() { return FK_genomeTemplate_id; }
  public void setFK_genomeTemplate_id( String FK_genomeTemplate_id )
  {
      this.FK_genomeTemplate_id = FK_genomeTemplate_id;
  }
  protected String name;
  public String getName() { return name; }
  public void setName( String name ) { this.name = name; }
  protected String species;
  public String getSpecies() { return species; }
  public void setSpecies( String species ) { this.species = species; }
  protected String version;
  public String getVersion() { return version; }
  public void setVersion( String version ) { this.version = version; }
  protected String description;
  public String getDescription() { return description; }
  public void setDescription( String description ) { this.description = description; }

  public String getScreenName()
  {
      String rc = getName();
      if( rc == null ) rc = "-- anonimous --";
      String s = getSpecies();
      String v = getVersion();
      if( !Util.isEmpty(s) ) rc = rc + " (" + s + ")";
      if( !Util.isEmpty(v) ) rc = rc + " ver. " + v;
      return rc;
  }

    public void clear()
    {
        refseqTemplateId = "#";
        name = species = version = description = FK_genomeTemplate_id = null;
    }

  public RefseqTemplate()
  {
      clear();
  }


    public static final String createStatement =
// "CREATE TABLE `refseqTemplate` (\n"+
// "  `refseqTemplateId` int(10) unsigned NOT NULL auto_increment,\n"+
// "  `FK_genomeTemplate_id` int(11) default NULL,\n"+
// "  `name` varchar(255) default NULL,\n"+
// "  `species` varchar(255) default NULL,\n"+
// "  `version` varchar(255) default NULL,\n"+
// "  `description` varchar(255) default NULL,\n"+
// "  PRIMARY KEY  (`refseqTemplateId`)\n"+
// ") ENGINE=MyISAM";
"CREATE TABLE `genomeTemplate` (\n"+
"  `genomeTemplate_id` int(11) NOT NULL auto_increment,\n"+
"  `genomeTemplate_name` varchar(255) default NULL,\n"+
"  `genomeTemplate_species` varchar(255) default NULL,\n"+
"  `genomeTemplate_version` varchar(255) default NULL,\n"+
"  `genomeTemplate_description` varchar(255) default NULL,\n"+
"  `genomeTemplate_source` varchar(255) default NULL,\n"+
"  `genomeTemplate_release_date` date default NULL,\n"+
"  `genomeTemplate_type` enum('SVG','PNG') NOT NULL default 'SVG',\n"+
"  `genomeTemplate_scale` int(11) default NULL,\n"+
"  `genomeTemplate_vgp` enum('Y','N') NOT NULL default 'N',\n"+
"  PRIMARY KEY  (`genomeTemplate_id`)\n"+
") ENGINE=MyISAM";

    public static final String createEntrypointStatement =
"CREATE TABLE `entryPointTemplate` (\n"+
"  `entryPointTemplateId` int(10) unsigned NOT NULL auto_increment,\n"+
"  `refseqTemplateId` int(10) unsigned NOT NULL default 0,\n"+
"  `fref` varchar(100) default NULL,\n"+
"  `gclass` varchar(100) default NULL,\n"+
"  `length` int(10) unsigned default NULL,\n"+
"  PRIMARY KEY  (`entryPointTemplateId`),\n"+
"  UNIQUE KEY `refseqTemplateId` (`refseqTemplateId`,`fref`)\n"+
") ENGINE=MyISAM";

    public static final String createTemplate2UploadStatement =
"CREATE TABLE `template2upload` (\n"+
"  `template2uploadId` int(10) unsigned NOT NULL auto_increment,\n"+
"  `templateId` int(10) unsigned NOT NULL default '0',\n"+
"  `uploadId` int(10) unsigned NOT NULL default '0',\n"+
"  PRIMARY KEY  (`template2uploadId`)\n"+
") ENGINE=MyISAM";

    protected static final String migrateStatement1 =
"ALTER TABLE genomeTemplate ADD COLUMN\n"+
"  `genomeTemplate_description` varchar(255) default NULL";
    protected static final String migrateStatement2 =
"ALTER TABLE genomeTemplate ADD COLUMN\n"+
"  `genomeTemplate_vgp` enum('Y','N') NOT NULL default 'N'";

    public static void migrate( DBAgent db ) throws SQLException {
    Connection conn = db.getConnection(null, false);
    if( conn != null ) try
    {
        int i;

        Statement stmt = conn.createStatement();

        stmt.executeUpdate( migrateStatement1 );
        stmt.executeUpdate( migrateStatement2 );
        stmt.executeUpdate( createTemplate2UploadStatement );
        stmt.executeUpdate( "UPDATE genomeTemplate SET genomeTemplate_vgp='Y'" );

            RefseqTemplate[] rtTgt = fetchAll( db );
            Hashtable ht = new Hashtable();
            Hashtable htep = new Hashtable();
            for( i=0; i<rtTgt.length; i++ )
                ht.put( rtTgt[i].getRefseqTemplateId(), rtTgt[i] );

            String qs = "SELECT refseqTemplateId, FK_genomeTemplate_id, "+
                "name, species, version, description FROM refseqTemplate";
            ResultSet rs = stmt.executeQuery( qs );
            while( rs.next() )
            {
        RefseqTemplate p = new RefseqTemplate();
        p.setRefseqTemplateId( rs.getString(1) );
        String fkid = rs.getString(2);
        p.setFK_genomeTemplate_id( fkid );
        p.setName( rs.getString(3) );
        p.setSpecies( rs.getString(4) );
        p.setVersion( rs.getString(5) );
        p.setDescription( rs.getString(6) );

        EntryPoint[] eps = p.fetchEntryPoints( db );

        RefseqTemplate op = null;
        if( !Util.isEmpty(fkid) ) op = (RefseqTemplate) ht.get( fkid );
        if( op == null )
        {
            p.setRefseqTemplateId("#");
            p.insert( db );
            op = p;
            ht.put( op.getRefseqTemplateId(), op );
        }
        htep.put( op.getRefseqTemplateId(), eps );
            }

            stmt.executeUpdate( "DELETE FROM entryPointTemplate" );

            for( Enumeration en=ht.keys(); en.hasMoreElements(); )
            {
                String fkid = (String) en.nextElement();
                RefseqTemplate p = (RefseqTemplate) ht.get( fkid );
                EntryPoint[] eps = (EntryPoint []) htep.get( fkid );
                if( p!=null && eps!=null )
                {
                    p.updateEntryPoints( db, eps );
                }
            }

        stmt.close();
    } catch( Exception ex )
    {
      db.reportError( ex, "RefseqTemplate.migrate()" );
    }
    }


    protected static void createTables( DBAgent db ) throws SQLException {
        Connection conn = db.getConnection();
        if( conn != null ) try
        {
            Statement stmt = conn.createStatement();
            stmt.executeUpdate( createStatement );
            stmt.executeUpdate( createEntrypointStatement );
            stmt.executeUpdate( createTemplate2UploadStatement );
            stmt.close();
        } catch( Exception ex ) {}
    }

  public static RefseqTemplate[] fetchAll( DBAgent db ) throws SQLException {
    Vector v = new Vector();
    Connection conn = db.getConnection();
    if( conn != null ) try
    {

            String qs = "SELECT genomeTemplate_id, genomeTemplate_name, genomeTemplate_species, "+
            "genomeTemplate_version, genomeTemplate_description FROM genomeTemplate";
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( qs );
      while( rs.next() )
      {
        RefseqTemplate p = new RefseqTemplate();
        p.setRefseqTemplateId( rs.getString(1) );
        p.setName( rs.getString(2) );
        p.setSpecies( rs.getString(3) );
        p.setVersion( rs.getString(4) );
        p.setDescription( rs.getString(5) );
        v.addElement( p );
      }
      stmt.close();
    } catch( Exception ex )
    {
        if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
        {
            createTables( db );
        }
        else
        {
            db.reportError( ex, "RefseqTemplate.fetchAll()" );
        }
    }
    RefseqTemplate[] rc = new RefseqTemplate[ v.size() ];
    v.copyInto( rc );
    return rc;
  }

  public boolean fetch( DBAgent db ) throws SQLException {
      String tid = getRefseqTemplateId();
    Connection conn = db.getConnection();
    if( conn != null && !tid.equals("#") ) try
    {
      String qs = "SELECT genomeTemplate_name, genomeTemplate_species, "+
      "genomeTemplate_version, genomeTemplate_description FROM genomeTemplate "+
      "WHERE genomeTemplate_id="+tid;
      PreparedStatement pstmt = conn.prepareStatement( qs );
      ResultSet rs = pstmt.executeQuery();
      boolean rc = false;
      if( rs.next() )
      {

        setName( rs.getString(1) );
        setSpecies( rs.getString(2) );
        setVersion( rs.getString(3) );
        setDescription( rs.getString(4) );
        rc = true;
      }
      pstmt.close();
      return rc;
    } catch( Exception ex )
    {
      db.reportError( ex, "RefseqTemplate.fetch()" );
    }
    return false;
  }

  public boolean insert( DBAgent db ) throws SQLException {
    Connection conn = db.getConnection(null, false);
    if( conn != null ) try
    {
        String qs = "INSERT INTO genomeTemplate (genomeTemplate_name, "+
        "genomeTemplate_species, genomeTemplate_version, genomeTemplate_description) "+
        "VALUES (?, ?, ?, ?)";

      PreparedStatement pstmt = conn.prepareStatement( qs );
      pstmt.setString( 1, getName() );
      pstmt.setString( 2, getSpecies() );
      pstmt.setString( 3, getVersion() );
      pstmt.setString( 4, getDescription() );
      boolean rc = (pstmt.executeUpdate() > 0);
      if( rc ) setRefseqTemplateId( ""+db.getLastInsertId(conn) );
      pstmt.close();
//      conn.close();
      return rc;
    } catch( Exception ex )
    {
      db.reportError( ex, "RefseqTemplate.insert()" );
    }
    return false;
  }

  public boolean update( DBAgent db ) throws SQLException {
      String tid = getRefseqTemplateId();
    Connection conn = db.getConnection();
    if( conn != null && !tid.equals("#") ) try
    {
        String qs = "UPDATE genomeTemplate SET genomeTemplate_name=?, "+
        "genomeTemplate_species=?, genomeTemplate_version=?, genomeTemplate_description=? "+
      "WHERE genomeTemplate_id="+tid;
      PreparedStatement pstmt = conn.prepareStatement( qs );
      pstmt.setString( 1, getName() );
      pstmt.setString( 2, getSpecies() );
      pstmt.setString( 3, getVersion() );
      pstmt.setString( 4, getDescription() );
      boolean rc = (pstmt.executeUpdate() > 0);
      pstmt.close();
      return rc;
    } catch( Exception ex )
    {
      db.reportError( ex, "RefseqTemplate.update()" );
    }
    return false;
  }

  public boolean delete( DBAgent db ) throws SQLException {
      String tid = getRefseqTemplateId();
    Connection conn = db.getConnection();
    if( conn != null && !tid.equals("#") ) try
    {
      String qs = "DELETE FROM genomeTemplate WHERE genomeTemplate_id="+tid;
      Statement stmt = conn.createStatement();
      boolean rc = (stmt.executeUpdate(qs) > 0);

      qs = "DELETE FROM entryPointTemplate WHERE refseqTemplateId="+tid;
      stmt.executeUpdate( qs );

            qs = "DELETE FROM chromosomeTemplate WHERE FK_genomeTemplate_id="+tid;
      stmt.executeUpdate( qs );

      qs = "DELETE FROM template2upload WHERE templateId="+tid;
      stmt.executeUpdate( qs );

      stmt.close();
      return rc;
    } catch( Exception ex )
    {
      db.reportError( ex, "RefseqTemplate.delete()" );
    }
    return false;
  }

  public static class EntryPoint
  {
      public String fref;
      public String gclass;
      public long len;
      public EntryPoint() {}
      public EntryPoint( String fref, String gclass, long len )
      {
          this.fref = fref;
          this.gclass = gclass;
          this.len = len;
      }
  }

  // ARJ: count eps
  public int countAllEPs( Connection conn )
  {
      int retVal = -1 ;
      String tid = getRefseqTemplateId();
      if( conn != null && !tid.equals("#") )
      {
          try
          {
              String qs = "SELECT count(*) FROM entryPointTemplate WHERE refseqTemplateId=" + tid ;
              Statement stmt = conn.createStatement() ;
              ResultSet rs = stmt.executeQuery(qs) ;
              if(rs.next())
              {
                  retVal = rs.getInt(1) ;
              }
              else
              {
                  retVal = 0 ;
              }
              stmt.close() ;
          }
          catch( Exception ex )
          {
              // ARJ: should log this error somewhere (even catalina.out is fine) but error reporting seems spotty?
              System.err.println("EXCEPTION: DbRef.countAll() failed to count the EPs. Error msg: " + ex.toString()) ;
          }
      }
      return retVal ;
  }
  
  // Get all EPs using Connection
  public EntryPoint[] fetchEntryPoints( Connection conn)
  {
    return fetchEntryPoints(conn, -1) ;
  }
  
  // Get limited number of EPs using Connection (-1 will get all of them)
  public EntryPoint[] fetchEntryPoints( Connection conn, int recordLimit)
  {
    ArrayList vv = new ArrayList();
    String tid = getRefseqTemplateId();
    String limitStr = (recordLimit >= 0) ? ( " LIMIT " + recordLimit ) : "" ;
    
    if( conn != null && !tid.equals("#") )
    {
      try
      {
        String qs = "SELECT fref, gclass, length " +
                    "FROM entryPointTemplate " +
                    "WHERE refseqTemplateId=" + tid + " " +
                    "ORDER BY fref" + limitStr ;
        Statement stmt = conn.createStatement();
        ResultSet rs = stmt.executeQuery( qs );
        while( rs.next() )
        {
          EntryPoint ep = new EntryPoint();
          ep.fref = rs.getString( 1 );
          ep.gclass = rs.getString( 2 );
          ep.len = rs.getLong( 3 );
          vv.add( ep );
        }
        stmt.close();
      } 
      catch( Exception ex )
      {
        System.err.println("EXCEPTION: RefseqTemplate.fetchEntryPoints(Connection, int) failed to get the EP records. Error msg: " + ex.toString()) ;
      }
    }
    EntryPoint[] rc = new EntryPoint[ vv.size() ];
    vv.toArray( rc );
    return rc;
  }
  
  public EntryPoint[] fetchEntryPoints( DBAgent db ) throws SQLException
  {
    Vector v = new Vector();
    String tid = getRefseqTemplateId();
    Connection conn = db.getConnection();
    
    if( conn != null && !tid.equals("#") ) try
    {
      String qs = "SELECT fref, gclass, length "+
          "FROM entryPointTemplate "+
          "WHERE refseqTemplateId="+tid+" "+
          "ORDER BY fref";
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( qs );
      while( rs.next() )
      {
          EntryPoint ep = new EntryPoint();
          ep.fref = rs.getString( 1 );
          ep.gclass = rs.getString( 2 );
          ep.len = rs.getLong( 3 );
          v.addElement( ep );
      }
      stmt.close();
    } catch( Exception ex )
    {
      db.reportError( ex, "RefseqTemplate.fetchEntryPoints()" );
    }
    EntryPoint[] rc = new EntryPoint[ v.size() ];
    v.copyInto( rc );
    return rc;
  }

  public boolean updateEntryPoints( DBAgent db, EntryPoint[] eps ) throws SQLException {
      String tid = getRefseqTemplateId();
    Connection conn = db.getConnection();
    if( conn != null && !tid.equals("#") ) try
    {
      Statement stmt = conn.createStatement();
      stmt.executeUpdate( "DELETE FROM entryPointTemplate WHERE refseqTemplateId="+tid );
      stmt.close();

      String qs = "INSERT INTO entryPointTemplate "+
          "(refseqTemplateId, fref, gclass, length) VALUES ("+tid+", "+
          "?, ?, ?)";
            PreparedStatement pstmt = conn.prepareStatement( qs );
            for( int i=0; i<eps.length; i++ )
            {
                EntryPoint ep = eps[i];
                pstmt.setString( 1, ep.fref );
                pstmt.setString( 2, ep.gclass );
                pstmt.setLong( 3, ep.len );
                try
                {
                    pstmt.executeUpdate();
                } catch( Exception ex01 ) {}
            }
      pstmt.close();
      return true;
    } catch( Exception ex )
    {
      db.reportError( ex, "RefseqTemplate.fetchEntryPoints()" );
    }
    return false;
  }

  public static String getRefseqScreenName( Refseq rs )
  {
      String rc = rs.getRefseqName();
      if( rc == null ) rc = "-- anonimous --";
      String s = rs.getRefseq_species();
      String v = rs.getRefseq_version();
      if( !Util.isEmpty(s) ) rc = rc + " (" + s + ")";
      if( !Util.isEmpty(v) ) rc = rc + " ver. " + v;
      return rc;
  }

  public static EntryPoint[] getRefseqEntryPoints( Refseq rs, DBAgent db ) throws SQLException {
      Vector v = new Vector();
      Connection conn = db.getConnection( rs.getDatabaseName() );
      if( conn != null ) try
      {
          String[][] oeps = rs.fetchEntryPoints( conn );
          for( int i=0; i<oeps.length; i++ )
          {
              String[] oep = oeps[i];
              EntryPoint ep = new EntryPoint();
              ep.fref = oep[0];
              ep.gclass = oep[1];
              ep.len = Long.parseLong( oep[2] );
              v.addElement( ep );
          }
      } catch( Exception ex )
      {
      db.reportError( ex, "RefseqTemplate.getRefseqEntryPoints()" );
      }
    EntryPoint[] rc = new EntryPoint[ v.size() ];
    v.copyInto( rc );
    return rc;
  }

  protected void processException( DBAgent db, Exception ex, String meth )
  {
      if( ex instanceof SQLException && ((SQLException)ex).getErrorCode()==1146 )
      {
            try
            {
              Connection conn = db.getConnection();
                Statement stmt = conn.createStatement();
                stmt.executeUpdate( createTemplate2UploadStatement );
                stmt.close();
            } catch( Exception ex1 ) {}
      }
      else
      {
        db.reportError( ex, meth );
      }
  }

  public String[] getTemplateUploadIds( DBAgent db ) throws SQLException {
      String tid = getRefseqTemplateId();
      Vector v = new Vector();
      Connection conn = db.getConnection();
      if( conn != null && !tid.equals("#") ) try
      {
          String qs = "SELECT uploadId FROM template2upload WHERE templateId="+tid;
          Statement stmt = conn.createStatement();
          ResultSet rs = stmt.executeQuery( qs );
          while( rs.next() )
          {
              v.addElement( rs.getString(1) );
          }
          stmt.close();
      } catch( Exception ex )
      {
          processException( db, ex, "RefseqTemplate.getTemplateUploadIds()" );
      }
    String[] rc = new String[ v.size() ];
    v.copyInto( rc );
    return rc;
  }

  public boolean setTemplateUploadIds( DBAgent db, String[] uids ) throws SQLException {
      String tid = getRefseqTemplateId();
      Connection conn = db.getConnection();
      if( conn != null && !tid.equals("#") ) try
      {
          Statement stmt = conn.createStatement();
          stmt.executeUpdate( "DELETE FROM template2upload WHERE templateId="+tid );
          stmt.close();
          if( uids != null && uids.length > 0 )
          {
              String qs = "INSERT INTO template2upload (uploadId, templateId) "+
              "VALUES(?, "+tid+")";
              PreparedStatement pstmt = conn.prepareStatement( qs );
              for( int i=0; i<uids.length; i++ )
              {
                  pstmt.setString( 1, uids[i] );
                  pstmt.executeUpdate();
              }
              pstmt.close();
          }
          return true;
      } catch( Exception ex )
      {
          processException( db, ex, "RefseqTemplate.setTemplateUploadIds()" );
      }
      return false;
  }

  protected String baseDir = null;
  protected String sequenceDir = null;
  public File getSequenceDirFile()
  {
      if( Util.isEmpty(baseDir) || Util.isEmpty(sequenceDir) ) return null;
      File rc = new File( baseDir, sequenceDir );
      return rc;
  }

  public File fetchSequenceDir( DBAgent db ) throws SQLException {
      String tid = getRefseqTemplateId();
      Connection conn = db.getConnection();
      if( conn != null && !tid.equals("#") ) try
      {
          baseDir = sequenceDir = null;
      String qs = "SELECT genomeTemplate_baseDir, genomeTemplate_sequenceDir "+
      "FROM genomeTemplate "+
      "WHERE genomeTemplate_id="+tid;
      Statement stmt = conn.createStatement();
      ResultSet rs = stmt.executeQuery( qs );
      if( rs.next() )
      {
          baseDir = rs.getString(1);
          if( baseDir != null ) baseDir = baseDir.trim();
          sequenceDir = rs.getString(2);
          if( sequenceDir != null ) sequenceDir = sequenceDir.trim();
      }
      stmt.close();
      return getSequenceDirFile();
      } catch( Exception ex )
      {
      db.reportError( ex, "RefseqTemplate.fetchSequenceDir()" );
      }
      return null;
  }

    public boolean copySequenceFiles( DBAgent db, Refseq rseq ) throws SQLException
    {
        DBAgent myDb = null;
        Connection conn = null;
        Connection templateConn = null;
        Connection genboreeCon = null;
        PreparedStatement psInsertRid2ridSequence = null;
        PreparedStatement psInsertRidSequence = null;
        Statement templateQuery = null;
        Statement stSelectRid2ridSequence = null;
        Statement stSelectRidSequence = null;
        String insertRidSequence = null;
        String insertRid2RidSequence = null;
        String templateDatabase = null;
        int tempId = -1;
        ResultSet rs = null;
        String templateIdDatabaseName = null;
        String  selectRid2ridSequence = null;
        String selectRidSequence = null;
        File srcDir = null;
        File tgtDir = null;

        srcDir =fetchSequenceDir( db );
        if( srcDir == null )  return false;

        tgtDir = rseq.fetchSequenceDir( db );
        if( tgtDir == null ) return false;

        try
        {
            int i;
            File[] lst = srcDir.listFiles();
            if( lst == null ) return false;
            for( i=0; i<lst.length; i++ )
            {
                File sf = lst[i];
                if( sf.isDirectory() ) continue;
                File tf = new File( tgtDir, sf.getName() );
                String cmdLine = "ln -s "+sf.getAbsolutePath()+" "+tf.getAbsolutePath();
                Process p = Runtime.getRuntime().exec( cmdLine );
                p.waitFor();
            }

        } catch( Exception ex )
        {
            db.reportError( ex, "RefseqTemplate.copySequenceFiles()" );
        }





        tempId = Util.parseInt(getRefseqTemplateId(), -1);
        if(tempId > 0)
            templateIdDatabaseName = "SELECT u.databaseName FROM template2upload as t, upload as u where u.uploadId = t.uploadId AND t.templateId = " + tempId;
        else
            return false;

        selectRid2ridSequence = "SELECT rid,ridSeqId,offset,length FROM rid2ridSeqId";
        insertRid2RidSequence = "INSERT INTO rid2ridSeqId (rid, ridSeqId, offset, length) VALUES (?, ?, ?, ?)";
        selectRidSequence = "SELECT ridSeqId,seqFileName,deflineFileName FROM ridSequence";
        insertRidSequence = "INSERT INTO ridSequence (ridSeqId, seqFileName, deflineFileName) VALUES (?, ?, ?)";

        myDb = db;

        try {
            genboreeCon = myDb.getConnection();
            templateQuery = genboreeCon.createStatement();
            rs = templateQuery.executeQuery(templateIdDatabaseName);
            if( rs.next() )
            {
                templateDatabase = rs.getString(1);
            }

            if(templateDatabase != null)
            {
                templateConn = myDb.getConnection( templateDatabase );
                stSelectRid2ridSequence = templateConn.createStatement();
                stSelectRidSequence = templateConn.createStatement();
                conn = myDb.getConnection( rseq.getDatabaseName() );
                psInsertRid2ridSequence = conn.prepareStatement(insertRidSequence);
                psInsertRidSequence = conn.prepareStatement(insertRid2RidSequence);
            }
            else
                return false;

            rs = stSelectRid2ridSequence.executeQuery(selectRid2ridSequence);
            while( rs.next() )
            {
                psInsertRidSequence.setInt(1, rs.getInt(1));
                psInsertRidSequence.setInt(2, rs.getInt(2));
                psInsertRidSequence.setInt(3, rs.getInt(3));
                psInsertRidSequence.setInt(4, rs.getInt(4));
                psInsertRidSequence.executeUpdate();
            }
            rs = stSelectRidSequence.executeQuery(selectRidSequence);
            while( rs.next() )
            {
                psInsertRid2ridSequence.setInt(1, rs.getInt(1));
                psInsertRid2ridSequence.setString(2, rs.getString(2));
                psInsertRid2ridSequence.setString(3, rs.getString(3));
                psInsertRid2ridSequence.executeUpdate();
            }

            psInsertRid2ridSequence.close();
            psInsertRidSequence.close();
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return true;
    }


  public boolean oldCopySequenceFiles( DBAgent db, Refseq rseq ) throws SQLException {
// System.err.println( "Entering RefseqTemplate.copySequenceFiles(refSeqId="+rseq.getRefSeqId()+")" );
      File srcDir = fetchSequenceDir( db );
      if( srcDir == null )
      {
// System.err.println( "No source directory found/fetched" );
// System.err.flush();
          return false;
      }
// System.err.println( "Source directory: "+srcDir.getAbsolutePath() );
      File tgtDir = rseq.fetchSequenceDir( db );
      if( tgtDir == null )
      {
// System.err.println( "No target directory found/fetched" );
// System.err.flush();
          return false;
      }
      try
      {
          int i;
          File[] lst = srcDir.listFiles();
          if( lst == null )
          {
// System.err.println( "No files in source directory found" );
// System.err.flush();
              return false;
          }
          for( i=0; i<lst.length; i++ )
          {
              File sf = lst[i];
              if( sf.isDirectory() ) continue;
              File tf = new File( tgtDir, sf.getName() );
              String cmdLine = "ln -s "+sf.getAbsolutePath()+" "+tf.getAbsolutePath();
// System.err.println( "Create Soft Link: "+cmdLine );
              Process p = Runtime.getRuntime().exec( cmdLine );
/*
              InputStream p_err = p.getErrorStream();
              StringBuffer sb = new StringBuffer();
              int c;
              while( (c = p_err.read()) != -1 ) sb.append( (char)c );
              String stderr = sb.toString();
              if( stderr.length() > 0 )
              {
                    System.err.println( stderr );
              }
*/
              p.waitFor();
          }

          Connection conn = db.getConnection( rseq.getDatabaseName() );
          DbFref[] refs = DbFref.fetchAll( conn );

          PreparedStatement psRef = conn.prepareStatement(
              "INSERT INTO ridSequence (seqFileName, deflineFileName) VALUES (?, ?)" );
          PreparedStatement psRid = conn.prepareStatement(
              "INSERT INTO rid2ridSeqId (rid, ridSeqId) VALUES (?, ?)" );
          for( i=0; i<refs.length; i++ )
          {
              DbFref fr = refs[i];
              String refname = fr.getRefname();
              String sn = refname+".fa";
              String dn = refname+".def";
              File sf = new File( tgtDir, sn );
              File df = new File( tgtDir, dn );
              if( !sf.exists() || !df.exists() ) continue;

                psRef.setString( 1, sn );
                psRef.setString( 2, dn );
                psRef.executeUpdate();
                int ridSeqId = db.getLastInsertId( conn );
                psRid.setInt( 1, fr.getRid() );
                psRid.setInt( 2, ridSeqId );
                psRid.executeUpdate();
          }
          psRef.close();
          psRid.close();

// System.err.println( "Exiting, OK" );
// System.err.flush();
          return true;
      } catch( Exception ex )
      {
// ex.printStackTrace( System.err );
      db.reportError( ex, "RefseqTemplate.copySequenceFiles()" );
      }
// System.err.println( "Exiting, Error" );
// System.err.flush();
      return false;
  }

  public RefseqTemplate( Refseq rs )
  {
      clear();
      setName( rs.getRefseqName() );
      setSpecies( rs.getRefseq_species() );
      setVersion( rs.getRefseq_version() );
      setDescription( rs.getDescription() );
  }

}
