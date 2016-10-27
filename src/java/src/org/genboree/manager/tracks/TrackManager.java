package org.genboree.manager.tracks;

import org.genboree.dbaccess.*;
import org.genboree.message.GenboreeMessage;
import org.genboree.util.* ;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.servlet.jsp.JspWriter;
import java.io.IOException;
import java.sql.*;
import java.util.*;
import java.io.* ;


/**
 * User: tong Date: Jun 28, 2005 Time: 6:10:09 PM
 */
public class TrackManager implements SqlQueries
{
  /**
   * seqarching current database for styles, using ftype ID to match the color and style information 1. using style
   * format from  database 2. if not exist, get style information from share databse 3. save changes to local
   * database
   *
   * @param rseq   Refseq  refseq objects contains database names
   * @param db   DbAgent  object used for making database connection
   * @param userId int
   *
   * @return Style [] with color and styles set
   */
  public static Style[] findStyles(Refseq rseq, DBAgent db, int userId){
    String[] dbNames = null;
    int defaultUserId = 0;
    DbResourceSet dbRes = null;
    ResultSet rs = null;
    ArrayList vlist = new ArrayList ();
    Style style = null;
    Style[] styles = null;
    String localDB = rseq.getDatabaseName();
    ArrayList list = new ArrayList();

    try{
      dbNames = rseq.fetchDatabaseNames(db);

      // search ftype table and find all ftypes
      styles = findFtypes(localDB, db, userId);

      // database names for this project
      // populate styles with information from local db
      for(int i = 0; i < styles.length; i++){
      // local database precedes share database
            style = populateStyle(db, localDB, userId, styles[i]);
            if((style.styleId.compareTo("0") == 0) && style.color == null)
            style = populateStyle(db, localDB, defaultUserId, style);
            boolean isempty =  style.styleId.compareTo("0") == 0 && style.color == null;
            if ( !isempty)  {
                vlist.add(styles[i].featureType);
                list.add(style);
            }
      }

      // populate styles with information from share database
      for(int j = 0; j < dbNames.length; j++)
      {
        // skip local db
        if(dbNames[j].compareToIgnoreCase(localDB) == 0)
        {
          continue;
        }
        Style[] shareStyles = findFtypes(dbNames[j], db, userId);
        for(int k = 0; k < shareStyles.length; k++)
        {
          style = shareStyles[k];
          if(vlist.contains(style.featureType))
          {
            continue;
          }
          style = populateStyle(db, dbNames[j], defaultUserId, style);
          vlist.add(style.featureType);
          list.add(style);
          // System.err.println(" shared   style " + j + "  track " +  style.featureType  + "ftypeid " + style.ftypeid + "style " +  style.name    ) ;
        }
      }
        // add styles that is not in shared db and is not set
         for(int i = 0; i < styles.length; i++){
            if (!vlist.contains(styles[i].featureType)) {
                vlist.add(styles[i].featureType);
                list.add(styles[i]);
            }
         }

      String defStyleId = "0";
      try {
          dbRes = db.executeQuery(localDB, "SELECT styleId FROM style WHERE name='simple_draw'");
          rs = dbRes.resultSet;
          if(rs != null && rs.next())
            defStyleId = rs.getString(1);
          dbRes.close();
      }
      catch(Exception e){
        e.printStackTrace();
      }

      for(int l = 0; l < list.size(); l++){
          style = (Style) list.get(l);
          style = setDefault(style, defStyleId);
      }

      styles = (Style[]) list.toArray(new Style[list.size()]);
    }
    catch(Exception e)
    {
      e.printStackTrace();
    }
    return styles;
  }

  /**
   * finds existing style format and return
   *
   * @param db
   * @param dbName
   *
   * @return style populated with color and style
   */
  public static Style populateStyle(DBAgent db, String dbName, int userId, Style style)
  {
    PreparedStatement stmscolor = null;
    PreparedStatement stmsstyle = null;

    String sqlcolor = "select c.colorId, c.value from color c, featuretocolor fc, ftype f " +
                      " where f.ftypeId = ? and fc.userId = ? and f.ftypeId = fc.ftypeId and c.colorId = fc.colorId ";

    String sqlstyle = "select s.styleId, s.name, s.description from style s, featuretostyle fs, ftype f " +
                      "where f.ftypeId = ? and fs.userId = ? and f.ftypeId = fs.ftypeId and fs.styleId = s.styleId ";

    try
    {
      Connection conn = db.getConnection(dbName);
      stmscolor = conn.prepareStatement(sqlcolor);
      stmsstyle = conn.prepareStatement(sqlstyle);

      stmscolor.setInt(1, style.ftypeid);
      stmsstyle.setInt(1, style.ftypeid);
      stmscolor.setInt(2, userId);
      stmsstyle.setInt(2, userId);

      ResultSet rscolor = stmscolor.executeQuery();
      ResultSet rsstyle = stmsstyle.executeQuery();

      while(rscolor.next())
      {
        style.colorid = rscolor.getInt(1);
        style.color = rscolor.getString(2);
      }

      rscolor.close();
      stmscolor.close();

      while(rsstyle.next())
      {
        style.styleId = rsstyle.getString(1);
        style.name = rsstyle.getString(2);
        style.description = rsstyle.getString(3);
      }
      rsstyle.close();
      stmsstyle.close();

    }
    catch(SQLException e)
    {
      e.printStackTrace();
    }
    return style;
  }


  /**
   * populate style [] with information from table ftypes
   *
   * @param dbName
   * @param db
   *
   * @return Style [] contains ftype id, dmethod, fsource, and datbaseName
   */
  public static Style[] findFtypes(String dbName, DBAgent db, int userId)
  {
    ArrayList list = new ArrayList();
    try
    {
      Connection con = db.getConnection(dbName);
      PreparedStatement stms = con.prepareStatement(sqlSelectFtype);
      ResultSet rs = stms.executeQuery();
      while(rs.next())
      {
        Style style = new Style();
        style.ftypeid = rs.getInt(1);
        String fmethod = rs.getString(2);
        style.fmethod = fmethod;
        String fsource = rs.getString(3);
        style.fsource = fsource;
        style.databaseName = dbName;
        style.featureType = style.fmethod + ":" + style.fsource;
        if( TrackPermission.isTrackAllowed( dbName, fmethod, fsource, userId  ))
          list.add(style);
      }
      rs.close();
      stms.close();
    }
    catch(SQLException e)
    {
      e.printStackTrace();
    }
    return (Style[]) list.toArray(new Style[list.size()]);
  }

  public static Style setDefault(Style style, String defStyleId)
  {
    String defColor = "#000000"; // "#2D7498";
    if(style.color == null && style.styleId.compareTo("0") != 0){
      style.color = defColor;
    }
    else if(style.color != null && style.styleId.compareTo("0") == 0)
    {
      style.styleId = defStyleId;
      style.name = "simple_draw";
      style.description = "Simple Rectangle";
    }
    else if(style.color == null && style.styleId.compareTo("0") == 0) // both null
    {
      style.styleId = defStyleId;
      style.name = "simple_draw";
      style.description = "Simple Rectangle";
      style.color = defColor;
    }
    return style;
  }

  /**
   * retrieve  style information  from local database, set default color and style
   *
   * @param db
   * @param dbName
   *
   * @return Vector contains local style objects with default setting
   */
  public static Vector setDefaultStyles(DBAgent db, String dbName, Vector featureNames)
  {
    Vector styles = new Vector();
    Connection conn = null;
    ResultSet rs = null;
    String defStyleId = "0";
    String defColor = "#000000"; // "#2D7498";
    PreparedStatement stmt = null;
    DbResourceSet dbRes = null;


    try
    {
      conn = db.getConnection(dbName);
      dbRes = db.executeQuery(dbName, sqlSelectStyleID);
	  rs = dbRes.resultSet;

      if(rs != null && rs.next())
        defStyleId = rs.getString(1);
      dbRes.close();

      stmt = conn.prepareStatement(sqlSelectFtype);
      rs = stmt.executeQuery();
      while(rs.next()) {
        Style s = new Style();
        s.ftypeid = rs.getInt(1);
        s.fmethod = rs.getString(2);
        s.fsource = rs.getString(3);
        if(s.fmethod.compareTo("Component") == 0 && s.fsource.compareTo("Chromosome") == 0)
          continue;
        if(s.fmethod.compareTo("Supercomponent") == 0 && s.fsource.compareTo("Sequence") == 0)
          continue;

        s.featureType = s.fmethod + ":" + s.fsource;
        featureNames.add(s.featureType);
        s.styleId = defStyleId;
        s.name = "simple_draw";
        s.description = "Simple Rectangle";
        s.color = defColor;
        s.databaseName = dbName;
        styles.add(s);
      }
      rs.close();
      stmt.close();
    } catch(SQLException e) {
      e.printStackTrace(System.err);
    }
    return styles;
  }

  public static Style[] setLocalDefaultStyles(DBAgent db, Refseq rseq, Style[] styles, int userId, javax.servlet.jsp.JspWriter out) {

    if(styles == null || styles.length < 1)
      return styles;

    String dbName = rseq.getDatabaseName();
    String[] dbNames = null;
    Connection conn = null;
    ResultSet rscolor = null;
    ResultSet rsstyle = null;
    Vector vNoLocalDefault = new Vector();
    String defStyleId = "0";
    String defColor = "#000000"; // "#2D7498";
    PreparedStatement stmscolor = null;
    PreparedStatement stmsstyle = null;

    String sqlcolor = "select c.colorId, c.value from color c, featuretocolor fc, ftype f "
        + " where f.ftypeId = ? and fc.userId = ? and f.ftypeId = fc.ftypeId and c.colorId = fc.colorId ";
    String sqlstyle = "select s.styleId, s.name, s.description from style s, featuretostyle fs, ftype f "
        + " where f.ftypeId = ? and fs.userId = ? and f.ftypeId = fs.ftypeId and fs.styleId = s.styleId ";
    try
    {
      conn = db.getConnection(dbName);
      Hashtable h = new Hashtable();
      dbNames = rseq.fetchDatabaseNames(db);
      for(int i = 0; i < styles.length; i++)
      {
        Style style = styles[i];

        stmscolor = conn.prepareStatement(sqlcolor);
        stmsstyle = conn.prepareStatement(sqlstyle);

        stmscolor.setInt(1, style.ftypeid);
        stmsstyle.setInt(1, style.ftypeid);

        stmscolor.setInt(2, 0);
        stmsstyle.setInt(2, 0);

        rscolor = stmscolor.executeQuery();
        rsstyle = stmsstyle.executeQuery();

        boolean noColor = false;

        if(rscolor.next()) {
          style.colorid = rscolor.getInt(1);
          style.color = rscolor.getString(2);
        } else
          noColor = true;

        // rscolor.close();
        //  stmscolor.close();

        boolean noStyle = false;

        if(rsstyle.next())
        {
          style.styleId = rsstyle.getString(1);
          style.name = rsstyle.getString(2);
          style.description = rsstyle.getString(3);
        }
        else
          noStyle = true;

        // rsstyle.close();
        // stmsstyle.close();

        if(noColor && noStyle)
        {
          vNoLocalDefault.add(style);
          h.put(style.featureType, "" + i);
        }
        else if(!noColor && noStyle)
        {
          style.styleId = "1";
          style.name = "simple_draw";
          style.description = "Simple Rectangle";
        }
        else if(noColor && !noStyle)
        {
          style.color = "#000000";
        }
      }

      // end of for
      String databaseName = null;
      String method = null;
      String source = null;
      ResultSet rs1color = null;
      ResultSet rs1style = null;
      PreparedStatement stmscolor1 = null;
      PreparedStatement stms_style = null;

      // get default from foreign db
      if(!vNoLocalDefault.isEmpty())
      {
        for(int i = 0; i < vNoLocalDefault.size(); i++)
        {
          // one style;
          Style s = (Style) vNoLocalDefault.get(i);
          boolean hasColor = false;
          boolean hasStyle = false;

          //loop through all db
          for(int j = 0; j < dbNames.length; j++) {
            databaseName = dbNames[j];
            if(databaseName.compareTo(dbName) == 0)
              continue;

            conn = db.getConnection(databaseName);

            method = s.fmethod;
            source = s.fsource;
            String sqlSelectColor = "select c.colorId,  c.value from color c, featuretocolor fc, ftype f "
                + "  where f.fmethod = '" + method + "' and f.fsource = '" + source + "'  and fc.userId = 0 and f.ftypeId = fc.ftypeId and c.colorId = fc.colorId ";
            String sqlSelectStyle = "select s.styleId, s.name, s.description from style s, featuretostyle fs, ftype f "
                + "where f.fmethod =  '" + method + "' and f.fsource = '" + source + "'  and fs.userId = 0 and f.ftypeId = fs.ftypeId and fs.styleId = s.styleId ";
            stmscolor1 = conn.prepareStatement(sqlSelectColor);
            stms_style = conn.prepareStatement(sqlSelectStyle);
             rs1color = stmscolor1.executeQuery();

            while(rs1color.next()) {
              s.color = rs1color.getString(2);
              s.colorid = rs1color.getInt(1);
              hasColor = true;

            }

            rs1style = stms_style.executeQuery();

            while(rs1style.next()) {
              s.styleId = rs1style.getString(1);
              s.name = rs1style.getString(2);
              s.description = rs1style.getString(3);
              hasStyle = true;
            }

            if(hasStyle || hasColor) {
              if(hasStyle && !hasColor) {
                s.color = defColor;
                //  s.colorid = 1;
              }
              if(!hasStyle && hasColor) {

                s.styleId = "1";
                s.name = "simple_draw";
                s.description = "Simple Rectangle";
              }

              int index = -1;
              String s1 = (String) h.get(s.featureType);
              if(s1 != null)
                index = Integer.parseInt(s1);


              if(index > 0)
                styles[index] = s;
              break;
            }
          }
          if(!hasStyle || !hasColor) {
            s.color = defColor;
            // s.colorid = 1;
            s.styleId = "1";
            s.name = "simple_draw";
            s.description = "Simple Rectangle";
          }
        }
      }
      styles = loadDefault(styles, db, userId, dbName, true, out);
      rscolor.close();
      rsstyle.close();
      stmscolor1.close();
      stms_style.close();
      stmscolor.close();
      stmsstyle.close();
    } catch(Exception e) {
      e.printStackTrace();
    }
    return styles;
  }

  /**
   * retrieve  style information  from local database, set default color and style
   *
   * @param db
   * @param dbName
   *
   * @return Vector contains local style objects with default setting
   */
  public static Vector setShareDefaultStyles(DBAgent db, String dbName, Vector featureNames, javax.servlet.jsp.JspWriter out)
  {
    Vector styles = new Vector();
    Connection conn = null;
    ResultSet rs = null;
    String defStyleId = "0";
    String defColor = "#000000"; // "#2D7498";
    PreparedStatement stmt = null;
    DbResourceSet dbRes = null;

    try
    {
      conn = db.getConnection(dbName);
      dbRes = db.executeQuery(dbName, sqlSelectStyleID);
      rs = dbRes.resultSet;

      if(rs != null && rs.next())
        defStyleId = rs.getString(1);

      dbRes.close();

      PreparedStatement stms1 = conn.prepareStatement("select s.styleId, s.name, s.description "
          + " from style s, featuretostyle fs " +
          " where s.styleId = fs.styleId  and fs.ftypeId = ? and fs.userId = 0 ");

      PreparedStatement stms2 = conn.prepareStatement("select c.colorId, c.value  "
          + " from color c, featuretocolor fc " +
          " where c.colorId = fc.colorId and fc.ftypeId = ?  and fc.userId = 0 ");


      stmt = conn.prepareStatement(sqlSelectFtype);
      rs = stmt.executeQuery();
      ResultSet rs2 = null;
      ResultSet rs3 = null;
      while(rs.next())
      {
        Style s = new Style();
        s.fmethod = rs.getString(2);
        s.fsource = rs.getString(3);
        s.featureType = s.fmethod + ":" + s.fsource;
        // if already present in loal database, skip
        if(featureNames.contains(s.featureType)) {
          continue;
        }

        s.ftypeid = rs.getInt(1);
        stms1.setInt(1, s.ftypeid);
        rs2 = stms1.executeQuery();
        if(rs2.next())
        {
          s.styleId = rs2.getString(1);
          s.name = rs2.getString(2);
          s.description = rs2.getString(3);
        } else {
          s.styleId = defStyleId;
          s.name = "simple_draw";
          s.description = "Simple Rectangle";
        }
        stms2.setInt(1, s.ftypeid);
        rs3 = stms2.executeQuery();
        if(rs3.next())
        {
          s.color = rs3.getString(2);
          s.colorid = rs3.getInt(1);
        } else {
          s.color = defColor;
        }
        rs3.close();
        rs2.close();
        s.databaseName = dbName;
        styles.add(s);
      }
      rs.close();
      stmt.close();
      stms1.close();
      stms2.close();
    } catch(SQLException e) {
      e.printStackTrace();
    } catch(Exception e2) {e2.printStackTrace();}
    return styles;
  }

  /**
   * update style information from local(main) database
   *
   * @return styles Vector of styles
   */
  public static Vector updateStyle(TrackManagerInfo info, Vector styles, DBAgent db) {
    PreparedStatement styleStmt = null;
    Style style = null;
    Vector v = new Vector();

    String dbName = info.getDbName();

    try
    {
      Connection conn = db.getConnection(dbName);
      styleStmt = conn.prepareStatement(sqlSelectStyleByUserIDFtypeID);
      for(int i = 0; i < styles.size(); i++)
      {
        style = (Style) styles.get(i);
        styleStmt.setInt(1, info.getUserId());
        styleStmt.setInt(2, style.ftypeid);

        ResultSet rs1 = styleStmt.executeQuery();
        if(!rs1.next())
        {
          styleStmt.setInt(1, 0);
          // styleStmt.setInt(2, style.ftypeid);
          rs1 = styleStmt.executeQuery();
          if(!rs1.next()) rs1 = null;
        }

        if(rs1 != null)
        {
          style.styleId = rs1.getString(1);
          style.name = rs1.getString(2);
          style.description = rs1.getString(3);
          rs1.close();
        }
        v.add(style);
      }
      styleStmt.close();
    } catch(SQLException e) {
      db.reportError(e, "FeatureStyleFinder");
    }
    return v;
  }


  /**
   * update color information from local (main ) database
   *
   * @param styles
   * @param userId
   * @param dbName
   * @param db
   *
   * @return styles Vector of styles
   */
  public static Vector updateStyleColor(Vector styles, int userId, String dbName, DBAgent db)
  {
    PreparedStatement colorStmt = null;
    Style style = null;
    Vector v = new Vector();
    ResultSet rs1 = null;
    Connection conn = null;

    try {
      conn = db.getConnection(dbName);
      colorStmt = conn.prepareStatement(sqlSelectColorByUserIDFtypeID);
      colorStmt.setInt(1, userId);

      for(int i = 0; i < styles.size(); i++) {
        style = (Style) styles.get(i);
        colorStmt.setInt(2, style.ftypeid);
        rs1 = colorStmt.executeQuery();
        if(!rs1.next()) {
          colorStmt.setInt(1, 0);
          rs1 = colorStmt.executeQuery();
          if(!rs1.next()) rs1 = null;
        }

        if(rs1 != null) {
          style.colorid = rs1.getInt(1);
          style.color = rs1.getString(2);
          rs1.close();
        }

        v.add(style);
      }
      colorStmt.close();

    } catch(SQLException e) {
      db.reportError(e, "FeatureStyleFinder");
    }
    return v;
  }


  static void updateLocalStyles(Vector vshare, DBAgent db, int userId, String dbName, boolean setDefault)
  {
    if(vshare == null || vshare.isEmpty())
      return;

    for(int i = 0; i < vshare.size(); i++) {
      // for(i=0; i<v.size(); i++) {
      Style s = (Style) vshare.get(i);
      // Style s = (Style)v.get(i);

      String sql2 = "insert into featuretocolor (ftypeId, colorId, userId)   values (?, ? , ?)";
      String sql3 = "insert into featuretostyle (ftypeId, styleId, userId )values (?, ? , ?)";
      String sql4 = "insert into ftype (fmethod, fsource)  values (? , ? )";
      String sql5 = "delete from featuretocolor where ftypeId = ? and userId = ?";
      String sql6 = "delete from featuretostyle where ftypeId = ? and userId = ? ";

      try
      {
        Connection conn = db.getConnection(dbName);
        PreparedStatement stms2 = conn.prepareStatement(sql2);
        PreparedStatement stms3 = conn.prepareStatement(sql3);
        PreparedStatement stms4 = conn.prepareStatement(sql4);
        PreparedStatement stms7 = conn.prepareStatement(sql5);
        PreparedStatement stms8 = conn.prepareStatement(sql6);

        stms4.setString(1, s.fmethod);
        stms4.setString(2, s.fsource);
        stms4.executeUpdate();

        Statement stms5 = conn.createStatement();
        ResultSet rs = stms5.executeQuery("select last_insert_id() ");
        int ftypeId = 0;
        while(rs.next())
        {
          ftypeId = rs.getInt(1);
        }

        rs.close();
        stms5.close();
        stms7.setInt(1, ftypeId);
        stms7.setInt(2, userId);
        stms8.setInt(1, ftypeId);
        stms8.setInt(2, userId);
        stms7.executeUpdate();
        stms8.executeUpdate();

        if(!setDefault)
        {
          stms2.setInt(1, ftypeId);
          stms2.setInt(2, s.colorid);
          stms2.setInt(3, userId);
          stms3.setInt(1, ftypeId);
          stms3.setInt(2, Integer.parseInt(s.styleId));
          stms3.setInt(3, userId);
          stms2.executeUpdate();
          stms3.executeUpdate();
        } else {
          stms7.setInt(1, ftypeId);
          stms7.setInt(2, 0);
          stms8.setInt(1, ftypeId);
          stms8.setInt(2, 0);
          stms7.executeUpdate();
          stms8.executeUpdate();
          stms2.setInt(1, ftypeId);
          stms2.setInt(2, s.colorid);
          stms2.setInt(3, userId);
          stms3.setInt(1, ftypeId);
          stms3.setInt(2, Integer.parseInt(s.styleId));
          stms3.setInt(3, userId);
          stms2.executeUpdate();
          stms3.executeUpdate();
        }
        stms2.close();
        stms3.close();
        stms4.close();
        stms7.close();
        stms8.close();
      } catch(SQLException e) {e.printStackTrace();}
    }
  }

  /**
   * load tables ftyle, featuretocolor, featuretostyle in local database
   *
   * @param styles
   * @param db     DbAgent
   * @param userId
   * @param dbName   local database name
   * @param setDefault
   * @param out
   *
   * @return Style [] with updated ftype id and database name if rom share db
   */
  public static Style[] loadDefault(Style[] styles, DBAgent db, int userId, String dbName, boolean setDefault, javax.servlet.jsp.JspWriter out)
  {
    PreparedStatement stms2 = null;
    PreparedStatement stms3 = null;
    PreparedStatement stms7 = null;
    PreparedStatement stms8 = null;
    String sql2 = "insert into featuretocolor (ftypeId, colorId, userId) values (?, ? , ?)";
    String sql3 = "insert into featuretostyle (ftypeId, styleId, userId) values (?, ? , ?)";
    String sql5 = "delete from featuretocolor where ftypeId = ? and userId = ?";
    String sql6 = "delete from featuretostyle where ftypeId = ? and userId = ?";
    String databaseName = null;

    try
    {
      Connection conn = db.getConnection(dbName);
      for(int i = 0; i < styles.length; i++)
      {
        Style s = styles[i];
        databaseName = styles[i].databaseName;

        if(databaseName.compareToIgnoreCase(dbName) != 0) {
          continue;
        }

        stms2 = conn.prepareStatement(sql2);
        stms3 = conn.prepareStatement(sql3);
        stms7 = conn.prepareStatement(sql5);
        stms8 = conn.prepareStatement(sql6);
        stms7.setInt(1, s.ftypeid);
        stms7.setInt(2, userId);
        stms8.setInt(1, s.ftypeid);
        stms8.setInt(2, userId);
        stms7.executeUpdate();
        stms8.executeUpdate();
        stms7.setInt(2, 0);
        stms8.setInt(2, 0);
        stms7.executeUpdate();
        stms8.executeUpdate();

        stms2.setInt(1, s.ftypeid);
        stms2.setInt(2, s.colorid);
        stms2.setInt(3, 0);

        stms3.setInt(1, s.ftypeid);
        stms3.setInt(2, Integer.parseInt(s.styleId));
        stms3.setInt(3, 0);
        stms2.executeUpdate();
        stms3.executeUpdate();

        stms2.setInt(1, s.ftypeid);
        stms2.setInt(2, s.colorid);
        stms2.setInt(3, userId);
        stms3.setInt(1, s.ftypeid);
        stms3.setInt(2, Integer.parseInt(s.styleId));
        stms3.setInt(3, userId);

        stms2.executeUpdate();
        stms3.executeUpdate();

        PreparedStatement stmsColor = conn.prepareStatement("select * from color where colorId = ? ");
        stmsColor.setInt(1, s.colorid);
        ResultSet rs = stmsColor.executeQuery();
        if(!rs.next())
        {
          Statement stmsins = conn.createStatement();
          String sql = " insert into color (colorId, value ) values ('" + s.colorid + "', '" + s.color + "') ";
          stmsins.executeUpdate(sql);
          stmsins.close();
        } else {
          rs.close();
          stmsColor.close();
        }
      }
      stms2.close();
      stms3.close();
      stms7.close();
      stms8.close();
    } catch(SQLException e) {e.printStackTrace();} catch(Exception e) {e.printStackTrace();}
    return styles;
  }


  /**
   * find ftype id using fmethod and fsouce
   *
   * @param s
   * @param db
   * @param dbName
   *
   * @return int ftype id , if none, return -1;
   */
  public static int findFtypeId(Style s, DBAgent db, String dbName)
  {
    int id = -1;

    String sql4 = "select ftypeId from ftype  where fmethod = ? and  fsource = ? ";
    try
    {
      Connection conn = db.getConnection(dbName);
      PreparedStatement stms4 = conn.prepareStatement(sql4);
      stms4.setString(1, s.fmethod);
      stms4.setString(2, s.fsource);
      ResultSet rs = stms4.executeQuery();
      if(rs.next())
        id = rs.getInt(1);
      rs.close();
      stms4.close();
    } catch(SQLException e) {e.printStackTrace();}
    return id;
  }

  public static void updateFtype(Style s, DBAgent db, String dbName)
  {

          String sqlSel = "select ftypeid from ftype where fmethod = ? and fsource = ? ";
         String sqlInsert = "insert into ftype (fmethod, fsource)  values (? , ? )";

      Connection con = null;
      try {
          con = db.getConnection(dbName);
      }
      catch (SQLException e) {e.printStackTrace();}


    if(!checkFeature(s, db, dbName)){
      int id = -1;
      try
      {
        PreparedStatement stmsIns = con.prepareStatement(sqlInsert);
        stmsIns.setString(1, s.fmethod);
        stmsIns.setString(2, s.fsource);
        stmsIns.executeUpdate();
        stmsIns.close();
      } catch(SQLException e) {e.printStackTrace();}
    }  // if already in database, update  style.trackid
     else {

      try
      {
        PreparedStatement stmsSel = con.prepareStatement(sqlSel);
        stmsSel.setString(1, s.fmethod);
        stmsSel.setString(2, s.fsource);
         ResultSet rs = stmsSel.executeQuery();
          if (rs.next()) {
             s.ftypeid = rs.getInt(1) ;
          }
        rs.close();

        stmsSel.close();
      } catch(SQLException e) {e.printStackTrace();}

    }


  }

  public static boolean checkFeature(Style s, DBAgent db, String dbName)
  {
    boolean b = false;
    String sql4 = "select * from ftype  where fmethod = ? and  fsource = ? ";
    try
    {
      Connection conn = db.getConnection(dbName);
      PreparedStatement stms4 = conn.prepareStatement(sql4);
      stms4.setString(1, s.fmethod);
      stms4.setString(2, s.fsource);
      ResultSet rs = stms4.executeQuery();
      if(rs.next())
        b = true;
      rs.close();
      stms4.close();
    } catch(SQLException e) {e.printStackTrace();}
    return b;
  }

  public static boolean checkStyleFeature(DBAgent db, String dbName, String tableName, int ftypeId)
  {
    boolean b = false;
    String sql4 = "select * from " + tableName + "   where ftypeId = " + ftypeId;
    try
    {
      Connection conn = db.getConnection(dbName);
      PreparedStatement stms4 = conn.prepareStatement(sql4);

      ResultSet rs = stms4.executeQuery();
      if(rs.next())
        b = true;
      rs.close();
      stms4.close();
    } catch(SQLException e) {e.printStackTrace();}
    return b;
  }

  public static boolean applyRenameTrackToAnnotationDataDir(DBAgent db, String oldTrkName, String newTrkName, Refseq refseqObj)
  {
    boolean retVal = false ;
    // Get dir for this track (will only be 1 File for the 1 dir here)
    String oldTrkDir = makeAnnotationDataDirName(db, refseqObj, oldTrkName) ;
    String newTrkDir = makeAnnotationDataDirName(db, refseqObj, newTrkName) ;

    // Do rename:
    File oldDir = new File(oldTrkDir) ;
    File newDir = new File(newTrkDir) ;
    if(oldDir.exists())
    {
      retVal = oldDir.renameTo(newDir) ;
      if(!retVal)
      {
        System.err.println("ERROR: renaming " + oldTrkDir + " to " + newTrkDir + " failed!") ;
      }
    }
    return retVal ;
  }

  public static DbFtype[] renameTracks(TrackManagerInfo info, HttpSession mys, HttpServletRequest request, DBAgent db, JspWriter out)
  {
    CacheManager.clearCache(db, info.getDbName(), info.getRseq());

    Hashtable htDup = new Hashtable();
    Hashtable htOld = new Hashtable();
    Vector vNew = new Vector();
    ArrayList errlist = new ArrayList();
    DbFtype[] localTracks = info.getLocalTracks() ;
    DbFtype[] shareTracks = info.getShareTracks() ;
    DbFtype tracks[] = info.getTracks() ;

    // Here, we want to display them in *alphabetical* sort order:
    Comparator alphaComparer = new Comparator() {
                                public int compare(Object aa, Object bb)
                                {
                                  return aa.toString().toLowerCase().compareTo( bb.toString().toLowerCase() ) ;
                                }
                              };

    if(localTracks != null && (localTracks.length > 0))
      Arrays.sort(localTracks, alphaComparer) ;
    else
      localTracks = new DbFtype[0];

    if(shareTracks != null && (shareTracks.length > 0))
      Arrays.sort(shareTracks, alphaComparer) ;
    else
      shareTracks = new DbFtype[0] ;

    /* START: ARJ_DEBUG: */
//        System.err.println("\n\n--------------------------------\nTrackManager#renameTracks()\n--------------------------\nExisting Local Track list:\n") ;
//        for(int i = 0; i < localTracks.length; i++)
//        {
//          DbFtype ft = localTracks[i];
//          String key = ft.toString();
//          System.err.println("- " + key) ;
//        }
//        System.err.println("\n\n--------------------------------\nTrackManager#renameTracks()\n--------------------------\nExisting Shared Track list:\n") ;
//        for(int i = 0; i < shareTracks.length; i++)
//        {
//          DbFtype ft = shareTracks[i];
//          String key = ft.toString();
//          System.err.println("- " + key) ;
//        }
    /* END: ARJ_DEBUG */

    Connection con = null;
    try
    {
      con = db.getConnection(info.getDbName());
    }
    catch(SQLException e)
    {
      db.reportError(e, "TrackManager.renameTracks()");
      return tracks;
    }

    // Populate a duplicate list of local tracks
    for(int i = 0; i < localTracks.length; i++)
    {
      DbFtype ft = localTracks[i];
      htDup.put(ft.toString(), ft);
    }

    // Look at each track and get the new name, by trkId
    // NOTE: trkId doesn't span DBs (eg to the shared DBs)...this was a bug in the previous version
    for(int i = 0; i < localTracks.length; i++)
    {
      DbFtype ft = localTracks[i];
      String trkId = "" + ft.getFtypeid();
      // Note, the shared tracks are named with meth_ and src_, but often use OVERLAPPING trkIds (valid in the *shared* database)
      // This is why it was broken after the 2006/3/28
      String fmethod = request.getParameter("lclType_" + trkId);
      String fsource = request.getParameter("lclSubtype_" + trkId);

      if(fmethod == null || fsource == null)
        continue;

      // If the name is the same for this trkId, skip it
      String tn = fmethod + ":" + fsource;
      if(tn.equals(ft.toString()))
        continue;

      if(Util.isEmpty(fmethod) || Util.isEmpty(fsource))
      {
        errlist.add("The new track names must be in the form <b><i>Type:Subtype</i></b>");
        GenboreeMessage.setErrMsg(mys, "The rename operation failed.", errlist);
        info.htTrkErr.put(trkId, ft);
        continue;
      }

      htDup.remove(ft.toString());
      htOld.put(trkId, ft.toString());

      // If this is a shared database, we need to spread its renaming to sub-ordinate DBs
      if(info.isHasSubordinateDB())
      {
        SubOrdinateDBManager.updateFtype(ft, fmethod, fsource, info.getSubdbNames(), db);
      }

      // Set the new name for this record
      ft.setFmethod(fmethod);
      ft.setFsource(fsource);

      // Add it to the list of ones that need to change.
      vNew.addElement(ft);
    }

    /* START: ARJ_DEBUG: */
//      System.err.println("\n\n--------------------------------\nTrackManager#renameTracks().2\n--------------------------\nNew Track Names list:\n") ;
//      for(int i = 0; i < vNew.size(); i++)
//      {
//        DbFtype ft = (DbFtype) vNew.elementAt(i) ;
//        String trkName = ft.toString() ;
//        System.err.println(" - " + trkName) ;
//      }
    /* END: ARJ_DEBUG: */

    ArrayList successList = new ArrayList();

    // Apply new names:
    int count = 0;
    for(int i = 0; i < vNew.size(); i++)
    {
      DbFtype ft = (DbFtype) vNew.elementAt(i);
      String trkId = "" + ft.getFtypeid();
      String oldName = (String) htOld.get(trkId);
      if(oldName == null)
        continue;
      if(htDup.get(ft.toString()) != null)
      {
        errlist.add("  Duplicate track name '" + ft.toString() +  "'");
        info.getHtTrkErr().put(trkId, ft);
        htDup.put(oldName, ft);
        continue;
      }

      String fmethod = ft.getFmethod();
      String fsource = ft.getFsource();
      if(fmethod.indexOf("\\") >= 0 || fsource.indexOf("\\") >= 0)
      {
        ft.setFmethod(fmethod);
        ft.setFsource(fsource);
        errlist.add("Track type and subtype can not contain '\\'");
        info.getHtTrkErr().put(trkId, ft);
        continue;
      }

      if(fmethod.indexOf(":") >= 0 || fsource.indexOf(":") >= 0)
      {
        errlist.add("Track type and subtype can not contain ':'");
        ft.setFmethod(fmethod);
        ft.setFsource(fsource);
        info.getHtTrkErr().put(trkId, ft);
        continue;
      }

     if(!ft.update(con))
     {
        errlist.add("  Duplicate track name '" + ft.toString() + "'");
        info.getHtTrkErr().put(trkId, ft);
        htDup.put(oldName, ft);
        continue;
      }
      else
      {
        count++;
      }

      GenboreeMessage.setSuccessMsg(mys, "Track '" + Util.htmlQuote(oldName) + "' was renamed to '" + Util.htmlQuote(ft.toString()) + "'");
      htDup.put(ft.toString(), ft);
      // Update the annotation data file dir for this track, if one exists (where live bigWig or bigBed files for example)
      applyRenameTrackToAnnotationDataDir(db, oldName, ft.toString(), info.getRseq()) ;
    }
    String be = (count>1 || count==0) ? "  tracks were renamed" : "  track was renamed";

    successList.add("" +count + be );
    int failedNum =  vNew.size() - count;
    String be2 =  (failedNum > 1) ? "  tracks failed (highlighted) because:" : "  track (highlighted) failed because";
    if(errlist.isEmpty())
      GenboreeMessage.setSuccessMsg(mys, "The rename operation was successful.", successList);
    else
    {
      if(count==0)
        GenboreeMessage.setErrMsg(mys, "The rename operation failed due to the following errors:", errlist);
      else if(count>0)
      {
        String m =  "<font color=\"green\" > " + count + be + " successfully, and </font><br> "+
           "<font color=\"red\" > "   + failedNum + be2 + "</font>" ;
        GenboreeMessage.setErrMsg(mys,m, errlist);
      }
    }

    tracks = TrackSortManager.topShareTracks(tracks, info.getDbName(), info.getDbNames(), db, out);
    info.setTracks(tracks);
    return tracks;
  }

  public static void updateURL(TrackManagerInfo info, HttpServletRequest request, JspWriter out, DBAgent db) {
    if(info.urltracks != null) {
      Connection con = null;
      try {
        con = db.getConnection(info.getDbName());
      } catch(SQLException e) {
        db.reportError(e, "TrackManager.updateURl()");
        return;
      }


      info.editTrackId = request.getParameter("ftypeid");
      info.iEditTrackId = Util.parseInt(info.editTrackId, -1);
      DbFtype.fetchUrls(con, info.urltracks);

      DbFtype ft = null;
      for(int i = 0; i < info.urltracks.length; i++) {
        ft = info.urltracks[i];
        //   for( i=0; i<tracks.length; i++ ){
        //DbFtype ft = tracks[i];
        if(ft.getFtypeid() == info.iEditTrackId) {
          info.editTrack = ft;
          break;
        }
      }

      if(info.editTrack == null && info.urltracks.length > 0) {
        info.editTrack = info.urltracks[0];
        info.iEditTrackId = info.editTrack.getFtypeid();
        info.editTrackId = "" + info.iEditTrackId;
      }


      if(info.editTrack == null) {
        info.iEditTrackId = -1;
        info.editTrackId = "#";
        info.editTrack = new DbFtype();
      } else {
        info.vBtn.addElement(TrackMgrConstants.btnApply);
        if(request.getParameter(TrackMgrConstants.btnApply[1]) != null) {

          String trackUrl = request.getParameter("track_url");
          String urlLabel = request.getParameter("url_label");
          String urlDescr = request.getParameter("url_description");
          if(trackUrl == null) trackUrl = "''";
          if(urlLabel == null) urlLabel = "''";
          if(urlDescr == null) urlDescr = "''";

          info.editTrack.setUrl(trackUrl);
          info.editTrack.setUrlLabel(urlLabel);
          info.editTrack.setUrlDescription(urlDescr);
          info.editTrack.updateUrl(con);


          info.setEditTrack(info.editTrack);
        // out.println ("passed params url "  + trackUrl + "  label " + urlLabel + "  desc " + urlDescr);
          //SubOrdinateDBManager.updateURL(info.getSubdbNames(), info.editTrack.getFmethod(), info.editTrack.getFsource(), trackUrl, urlDescr, urlLabel);

          //   }
          //}
          //  catch(IOException e) {

          //}

          // GenboreeUtils.sendRedirect(request,response,  "trackmgr.jsp" );
//          GenboreeUtils.sendRedirect(request,response,  "gbrowser.jsp" );
        }
      }

    }

  }


  public static Style[] updateStyles(TrackManagerInfo info, HttpServletRequest request, HttpServletResponse response, HttpSession mys, JspWriter out, DBAgent db) {

    String[] trackNames = info.trackNames;
    Style[] styleMap = info.getStyleMap();
    Hashtable trackLookup = info.getTrackLookup();

    Style[] styleList = info.getStyleList();
    int userId = info.getUserId();
    Refseq rseq = info.getRseq();

    if(info.isOld_db()) trackNames = (String[]) mys.getAttribute("featuretypes");

    if(trackNames != null && trackNames.length > 0) {
      trackLookup = new Hashtable();
      for(int i = 0; i < trackNames.length; i++) {
        trackLookup.put(trackNames[i], "y");
      }
    }


    int cmd = 2;
    if(request.getParameter(TrackMgrConstants.btnApply[1]) != null)
      cmd = 1;
    else if(request.getParameter(TrackMgrConstants.btnLoadDefault[1]) != null)
      cmd = 2;
    else if(request.getParameter(TrackMgrConstants.btnSetDefault[1]) != null)
      cmd = 3;


    if(cmd == 1 || cmd == 3) {

      styleMap = TrackManager.findStyles(rseq, db, userId);

      Arrays.sort(styleMap);
      // create a hashtable of style name:  stle object
      Hashtable htStyle = new Hashtable();
      for(int i = 0; i < styleList.length; i++)
        htStyle.put(styleList[i].name, styleList[i]);

      Vector vd = new Vector();
      Vector vu = new Vector();


      for(int i = 0; i < styleMap.length; i++) {
        Style st = styleMap[i];
        String trackName = st.fmethod + ":" + st.fsource;


        if(trackLookup != null && trackLookup.get(trackName) == null)
          continue;

        if(trackName.compareToIgnoreCase("Component:Chromosome") == 0 ||
            trackName.compareToIgnoreCase("Supercomponent:Sequence") == 0)
          continue;


        String stName = request.getParameter(trackName + ":style");
        Style cst = (stName != null) ? (Style) htStyle.get(stName) : (Style) null;

        // current color
        String curColor = request.getParameter(trackName + ":color");

        if(cst == null && curColor == null) {
          // out.println ("style " + i + " skipped" + "<br>" );
          continue;
        }

        boolean changed = false;

        // set style object  to current
        if((cst != null) && (cst.name.compareToIgnoreCase(st.name) != 0)) {

          changed = true;
        }

        // update style.color
        if((curColor != null) && (curColor.compareToIgnoreCase(st.color) != 0)) {
          changed = true;
        }

        boolean doUpdate = false;
        if(st.databaseName.compareTo(rseq.getDatabaseName()) == 0) {
          if(!TrackManager.checkStyleFeature(db, rseq.getDatabaseName(), "featuretocolor", st.ftypeid))
            doUpdate = true;

          if(!TrackManager.checkStyleFeature(db, rseq.getDatabaseName(), "featuretostyle", st.ftypeid))
            doUpdate = true;
          if(cst != null) {
            st.name = cst.name;
            st.description = cst.description;
          }

          if(curColor != null) st.color = curColor;

        } else if(st.databaseName.compareTo(rseq.getDatabaseName()) != 0 && changed) {
          TrackManager.updateFtype(st, db, rseq.getDatabaseName());
          st.ftypeid = TrackManager.findFtypeId(st, db, rseq.getDatabaseName());
          st.databaseName = rseq.getDatabaseName();
          doUpdate = true;
          if(cst != null) {
            st.name = cst.name;
            st.description = cst.description;
          }

          if(curColor != null) st.color = curColor;


        } else if(st.databaseName.compareTo(rseq.getDatabaseName()) != 0 && !changed) {
          continue;
        }


        if(doUpdate) {
          vd.addElement(st);

          // adding to upate list
          vu.addElement(st);
        }
      }

      Style[] delst = new Style[vd.size()];
      vd.copyInto(delst);
      rseq.deleteStyleMap(db, delst, userId);
      try {
        if(JSPErrorHandler.checkErrors(request,response,  db, mys))
          return null;
      } catch(IOException e) {
        return null;
      }
      Style[] updst = new Style[vu.size()];
      vu.copyInto(updst);
      try {
        rseq.setStyleMap(db, updst, (cmd == 3) ? 0 : userId);

        if(info.isAuto_goback()) {
          GenboreeUtils.sendRedirect(request,response, info.getDestback());
          return null;
        }
      } catch(Exception e) {
          System.err.println("\n\n: Error in Refseq.setStyleMap (); ");
          e.printStackTrace();

      }

    }
    // load default
    else if(cmd == 2) {

      styleMap = TrackManager.setLocalDefaultStyles(db, rseq, styleMap, userId, out);
      // Arrays.sort(styleMap);
    }
    try {
      if(JSPErrorHandler.checkErrors(request,response,  db, mys)) return null;
    } catch(Exception e) {
      return null;
    }

    return styleMap;

  }


  public static void deleteTracks(TrackManagerInfo info, DBAgent db, HttpSession mys, HttpServletResponse response, HttpServletRequest request, JspWriter out) {

    Refseq rseq = info.getRseq();
    info.vBtn.addElement(TrackMgrConstants.btnDelete);
    try {
      if(request.getParameter(TrackMgrConstants.btnDelete[1]) != null) {
        CacheManager.clearCache(db, info.getDbName(), info.getRseq());

        String[] trkIds = request.getParameterValues("delTrkId");
        if(trkIds != null && trkIds.length > 0) {
          int nDel = rseq.deleteTracks(db, trkIds);
          if(info.isHasSubordinateDB())
            SubOrdinateDBManager.deleteSubordinateTracks(db, trkIds, info.getSubdbNames(), info.getDbName());
          if(JSPErrorHandler.checkErrors(request,response,  db, mys)) return;
          if(nDel > 0) {
            GenboreeMessage.setSuccessMsg(mys, "" + nDel + " records were deleted from " +
                Util.htmlQuote(rseq.getRefseqName()));
          }

          info.setTracks(rseq.fetchTracksSorted(db, info.fetchUserId));


          if(JSPErrorHandler.checkErrors(request,response,  db, mys)) return;
        }

      } // btnDelete
    } catch(Exception e) {}
    info.setTracks(TrackSortManager.topShareTracks(info.getTracks(), rseq.getDatabaseName(), info.getDbNames(), db, out));
  }


  public   static int deleteURL(Connection con, String fmethod, String fsource, JspWriter out) {
        int rc = 0;
        int ftypeid = 0;
        try {
            PreparedStatement stms = con.prepareStatement("select ftypeid from ftype where fmethod = ? and fsource = ? ");
            stms.setString(1, fmethod);
            stms.setString(2, fsource);
            ResultSet rs = stms.executeQuery();
            if (rs.next())
                ftypeid = rs.getInt(1);
            rs.close();
            stms.close();
            String sql = "delete from featureurl where ftypeid = ?";
            stms = con.prepareStatement(sql);
            stms.setInt(1, ftypeid);
            rc = stms.executeUpdate();
            stms.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
        return rc;
    }


   public static  String[] getDbftype(DBAgent db, String dbname, String fmethod, String fsource, JspWriter out) {
        String[] arr = new String[3];
        String sql = "select fu.url, fu.label, fu.description from featureurl fu, ftype f " +
                " where f.ftypeid = fu.ftypeid and f.fmethod = ? and fsource = ?";

        try {
            if (db == null)
                db = DBAgent.getInstance();

            Connection con = db.getConnection(dbname);
            if (con == null && con.isClosed())
                return arr;

            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, fmethod);
            stms.setString(2, fsource);
            ResultSet rs = stms.executeQuery();
            if (rs.next()) {
                arr[0] = rs.getString(1);
                arr[1] = rs.getString(2);
                arr[2] = rs.getString(3);
            }
            rs.close();
            stms.close();

        } catch (Exception e) {
            e.printStackTrace();
        }
        return arr;
    }

   public  static boolean localEmpty(Connection con, String fmethod, String fsource) {
        boolean b = true;
        String sql = "select fu.url, fu.label, fu.description from featureurl fu, ftype f " +
                " where f.ftypeid = fu.ftypeid and f.fmethod = ? and fsource = ? ";

        try {
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, fmethod);
            stms.setString(2, fsource);
            ResultSet rs = stms.executeQuery();
            if (rs.next())
                b = false;
            rs.close();
            stms.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
        return b;
    }

   public  static DbFtype updateURL2(Connection con, DbFtype ft, String url, String label, String desc, int userId, JspWriter out) {
        int ftypeid = 0;
        try {

            if (con.isClosed() || con == null) {

                return null;
            }


            PreparedStatement stms = con.prepareStatement("select ftypeid  from ftype where fmethod = ? and fsource = ? ");
            stms.setString(1, ft.getFmethod());
            stms.setString(2, ft.getFsource());
            ResultSet rs = stms.executeQuery();
            if (rs.next())
                ftypeid = rs.getInt(1);
            rs.close();
            stms.close();

            if (ftypeid == 0) {
                stms = con.prepareStatement("insert into ftype (fmethod, fsource) values (?, ?) ");
                stms.setString(1, ft.getFmethod());
                stms.setString(2, ft.getFsource());
                stms.executeUpdate();

                stms = con.prepareStatement("SELECT LAST_INSERT_ID()");
                rs = stms.executeQuery();
                if (rs.next())
                    ftypeid = rs.getInt(1);
                rs.close();
                stms.close();
            }

            stms = con.prepareStatement(" delete from featureurl where ftypeid = ? ");
            stms.setInt(1, ftypeid);
            stms.executeUpdate();
            stms.close();

            stms = con.prepareStatement("insert ignore into featureurl (ftypeid, url, label, description) values (?, ?, ?, ?) ");
            stms.setInt(1, ftypeid);
            stms.setString(2, url);
            stms.setString(3, label);
            stms.setString(4, desc);
            stms.executeUpdate();
            stms.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
        return ft;
    }
/*
MLGG
Modified for the new schema
This should be a todo for the next week MLGG-TODO
*/
  // Delete track from cheap tables user database
  // ** Track delettion is meant to be done in two steps: (a) a fast delete step that
  //    happens immediately and (b) a slower delete on big tables that happens when
  //    conditions allow.
  // ** This method works with expensiveDeleteTracks(...)
  // - this MUST be followed by a call to delete the expensive tables
  // - tracks are deleted by quickly removing them from ftype and the various feature* tables immediately
  //   and then in a thread cleaning up the fdata2 and fid2attribute tables when locks/constraints allow.
  // - After this method is called, the user can be told that the track is "deleted" (even though thorough
  //   cleaning is not done yet)
  // - returns number of TRACKS deleted
  public static int cheapDeleteTracks(Connection conn, String[] trkIds)
  {
    int rowCount = 0 ;
    Statement stmt = null ;
    if(conn != null)
    {
      try
      {
        StringBuffer tracksBuff = new StringBuffer() ;
        if(trkIds != null && trkIds.length > 0)
        {
          for(int ii = 0; ii < trkIds.length; ii++)
          {
            tracksBuff.append(trkIds[ii]) ;
            if(ii < (trkIds.length -1) ) // then not the last one, add a ','
            {
              tracksBuff.append(",") ;
            }
          }
          String tracksStr = tracksBuff.toString() ;


          stmt = conn.createStatement() ;
          rowCount = stmt.executeUpdate("DELETE FROM ftype WHERE ftypeid IN (" + tracksStr + ")") ;
          stmt.executeUpdate("DELETE FROM featuredisplay WHERE ftypeid IN (" + tracksStr + ")") ;
          stmt.executeUpdate("DELETE FROM featuretocolor WHERE ftypeid IN (" + tracksStr + ")") ;
          stmt.executeUpdate("DELETE FROM featuretostyle WHERE ftypeid IN (" + tracksStr + ")") ;
          stmt.executeUpdate("DELETE FROM featuretolink WHERE ftypeid IN (" + tracksStr + ")") ;
          stmt.executeUpdate("DELETE FROM ftype2gclass WHERE ftypeid IN (" + tracksStr + ")") ;
          stmt.executeUpdate("DELETE FROM featureurl WHERE ftypeid IN (" + tracksStr + ")") ;
          stmt.executeUpdate("DELETE FROM featuresort WHERE  ftypeid IN (" + tracksStr + ")") ;
          stmt.executeUpdate("DELETE FROM ftype2attributeName WHERE ftypeid IN (" + tracksStr + ")") ;
          stmt.executeUpdate("DELETE FROM ftypeCount WHERE ftypeid IN (" + tracksStr + ")") ;
          //stmt.executeUpdate("DELETE FROM ftype2attributes WHERE ftype_id IN (" + tracksStr + ")") ;
          stmt.close() ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: TrackManager#cheapDeleteTracks(C,S[],J) => error deleting tracks.") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        try
        {
          if(stmt != null)
          {
            stmt.close() ;
          }
        }
        catch(Exception ex) {}
      }
    }
    return rowCount ;
  }


  public static File[] fetchHdhvBinFiles(Connection conn, String trkId)
  {
    File[] rc = null ;
    try
    {
      Statement stmt = conn.createStatement() ;
      // Get the ridSequence dir from fmeta
      ResultSet rs = stmt.executeQuery("SELECT fvalue FROM fmeta WHERE fname = 'RID_SEQUENCE_DIR'") ;
      if(rs != null && rs.next()) {
        String ridBaseDir = rs.getString(1) ;
        // Get the fileNames
        if( conn == null ) return null ;
        String qs = "SELECT DISTINCT fileName FROM blockLevelDataInfo WHERE ftypeid = ?" ;
        PreparedStatement pstmt = conn.prepareStatement(qs) ;
        pstmt.setString( 1, trkId ) ;
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
      System.err.println("\n\n: Error in Refseq.fetchHdhvBinFiles(); ");
      ex.printStackTrace();
    }
    return rc;
  }

  public static String makeAnnotationDataDirName( DBAgent db, Refseq refseqObj, String trackName)
  {
    String retVal = null ;
    // Get dir path from config file
    String dirPathName = GenboreeConfig.getConfigParam("gbAnnoDataFilesDir") ;
    try
    {
      String refseqNameEsc = Util.urlEncode(refseqObj.getRefseqName()) ;
      String trackNameEsc = Util.urlEncode(trackName) ;
      // Get the groups that the refseq is linked to
      Connection conn = db.getConnection() ;
      if( conn == null ) return null ;
      String qs = "SELECT gr.groupId, gg.groupName FROM grouprefseq gr, genboreegroup gg WHERE gr.groupId=gg.groupId AND gr.refSeqId=?" ;
      PreparedStatement pstmt = conn.prepareStatement(qs) ;
      pstmt.setString( 1, refseqObj.getRefSeqId() ) ;
      ResultSet rs = pstmt.executeQuery() ;
      Vector v = new Vector() ;
      while( rs.next() )
      {
        String grpName = rs.getString(2) ;
        String grpNameEsc = Util.urlEncode(grpName) ; // Escape this
        String grpDirPathName = dirPathName + "grp/" + grpNameEsc + "/db/" + refseqNameEsc + "/trk/" + trackNameEsc ;
        retVal = grpDirPathName ;
      }
      pstmt.close();
    }
    catch(Exception ex)
    {
      db.reportError(ex, "Refseq.fetchAnnotationDataFilesDirs()") ;
    }
    return retVal ;
  }

  public static File[] fetchAnnotationDataFilesDirs( DBAgent db, String trkId, Refseq refseqObj, String trackName )
  {
    File[] rc = null ;
    // Get dir path from config file
    String dirPathName = GenboreeConfig.getConfigParam("gbAnnoDataFilesDir") ;
    try
    {
      String refseqNameEsc = Util.urlEncode(refseqObj.getRefseqName()) ;
      String trackNameEsc = Util.urlEncode(trackName) ;
      // Get the groups that the refseq is linked to
      Connection conn = db.getConnection() ;
      if( conn == null ) return null ;
      String qs = "SELECT gr.groupId, gg.groupName FROM grouprefseq gr, genboreegroup gg WHERE gr.groupId=gg.groupId AND gr.refSeqId=?" ;
      PreparedStatement pstmt = conn.prepareStatement(qs) ;
      pstmt.setString( 1, refseqObj.getRefSeqId() ) ;
      ResultSet rs = pstmt.executeQuery() ;
      Vector v = new Vector() ;
      while( rs.next() )
      {
        String grpName = rs.getString(2) ;
        String grpNameEsc = Util.urlEncode(grpName) ; // Escape this
        String grpDirPathName = dirPathName + "grp/" + grpNameEsc + "/db/" + refseqNameEsc + "/trk/" + trackNameEsc ;
        File grpDirPathFile = new File( grpDirPathName ) ;
        v.addElement( grpDirPathFile ) ;
      }
      pstmt.close();
      rc = new File[ v.size() ];
      v.copyInto( rc );
    } catch( Exception ex ) {
      db.reportError( ex, "Refseq.fetchAnnotationDataFilesDirs()" );
    }
    return rc;
  }

  // This method gets the filenames from blockLevelDataInfo so when deleting a track
  // be sure to call this method before deleting db records
  public static int deleteTrackHdhvFiles(Connection conn, String[] trkIds)
  {
    int rowCount = 0 ;
    try
    {
      if(trkIds != null && trkIds.length > 0)
      {
        for(int ii = 0; ii < trkIds.length; ii++)
        {
          File[] binFiles = fetchHdhvBinFiles(conn, trkIds[ii]) ;
          // Delete the files
          if(binFiles != null && binFiles.length > 0)
          {
            for( int i=0; i<binFiles.length; i++ )
            {
              FileKiller.clearDirectory(binFiles[i]) ;
              binFiles[i].delete() ;
            }
          }
        }
      }
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: TrackManager#deleteTrackHdhvFiles") ;
      ex.printStackTrace(System.err) ;
    }
    return rowCount ;
  }

  public static int deleteTrackAnnotationDataFiles(DBAgent db, Connection conn, String[] trkIds, Refseq refseqObj)
  {
    System.err.println("START DELETE THE DIR") ;
    int rowCount = 0 ;
    try
    {
      if(trkIds != null && trkIds.length > 0)
      {
        for(int ii = 0; ii < trkIds.length; ii++)
        {
          String qs = "SELECT fmethod, fsource FROM ftype WHERE ftypeid = ?" ;
          PreparedStatement pstmt = conn.prepareStatement(qs) ;
          pstmt.setString( 1, trkIds[ii] ) ;
          ResultSet rs = pstmt.executeQuery() ;
          if(rs != null && rs.next()) {
            String trackName = rs.getString(1) + ":" + rs.getString(2) ;
            File[] annoDirs = fetchAnnotationDataFilesDirs( db, trkIds[ii], refseqObj, trackName) ;
            // Delete the files
            if(annoDirs != null && annoDirs.length > 0)
            {
              for( int i=0; i<annoDirs.length; i++ )
              {
                System.err.println("DELETE THE DIR") ;
                System.err.println(annoDirs[i]) ;
                FileKiller.clearDirectory(annoDirs[i]) ;
                annoDirs[i].delete() ;
              }
            }
          }
        }
      }
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: TrackManager#deleteTrackAnnotationDataFiles") ;
      ex.printStackTrace(System.err) ;
    }
    return rowCount ;

  }

  public static int deleteTracksFromMainDb(DBAgent db, String[] trkIds)
  {
    int rowCount = 0 ;
    Connection mainDbConnection = null;
    Statement mstmt = null;

    try
    {
      StringBuffer tracksBuff = new StringBuffer() ;
      if(trkIds != null && trkIds.length > 0)
      {
        for(int ii = 0; ii < trkIds.length; ii++)
        {
          tracksBuff.append(trkIds[ii]) ;
          if(ii < (trkIds.length -1) ) // then not the last one, add a ','
          {
            tracksBuff.append(",") ;
          }
        }
        String tracksStr = tracksBuff.toString() ;

        // Delete gbKeys
        mainDbConnection = db.getConnection();
        mstmt = mainDbConnection.createStatement();
        mstmt.executeUpdate( "DELETE ugr, ugrp " +
                              "FROM unlockedGroupResources ugr, unlockedGroupResourceParents ugrp " +
                              "WHERE ugr.id = ugrp.unlockedGroupResource_id " +
                              "AND ugr.resourceType='track' AND ugr.resource_id IN ("+tracksStr+")" ) ;
        mstmt.close();

      }
    }
    catch(Exception ex)
    {
      System.err.println("ERROR: TrackManager#cheapDeleteTracks(C,S[],J) => error deleting tracks.") ;
      ex.printStackTrace(System.err) ;
    }
    finally
    {
      try
      {
        if(mstmt != null)
        {
          mstmt.close() ;
        }
      }
      catch(Exception ex) {}
    }
    return rowCount ;
  }

  // Delete tracks from expensive tables in user database (currently the fdata2 tables and fid2attribute tables)
  // - needs connection to the user database
  // - should be called from a Thread which first gets permission to delete from BigDBOpsLockFile before
  //   calling this function.
  // - returns number of ANNOTATIONS deleted.
  public static long expensiveDeleteTracks(Connection conn, String[] trkIds)
  {
    long rowCount = 0 ;
    int delLimit = 6000 ;
    int delPause = 2000 ;
    if(conn != null)
    {
      try
      {
        StringBuffer tracksBuff = new StringBuffer() ;
        if(trkIds != null && trkIds.length > 0)
        {
          for(int ii = 0; ii < trkIds.length; ii++)
          {
            tracksBuff.append(trkIds[ii]) ;
            if(ii < (trkIds.length -1) ) // then not the last one, add a ','
            {
              tracksBuff.append(",") ;
            }
          }
          String tracksStr = tracksBuff.toString() ;
          // ARJ: Do this before fdata2.
          String sql = "DELETE LOW_PRIORITY FROM fid2attribute WHERE fid2attribute.fid IN (SELECT fdata2.fid FROM fdata2 WHERE fdata2.ftypeid IN (" + tracksStr + ") ) LIMIT " + delLimit ;
          rowCount = TrackManager.doLimitedSQLDelete(sql, delLimit, delPause, conn) ;
          //System.err.println("DELETE DEBUG: total num records deleted from table: " + rowCount) ;
          sql = "DELETE LOW_PRIORITY FROM fdata2_cv WHERE ftypeid IN (" + tracksStr + ") LIMIT " + delLimit ;
          rowCount = TrackManager.doLimitedSQLDelete(sql, delLimit, delPause, conn) ;
          //System.err.println("DELETE DEBUG: total num records deleted from table: " + rowCount) ;
          sql = "DELETE LOW_PRIORITY FROM fdata2_gv WHERE ftypeid IN (" + tracksStr + ") LIMIT " + delLimit ;
          rowCount = TrackManager.doLimitedSQLDelete(sql, delLimit, delPause, conn) ;
          //System.err.println("DELETE DEBUG: total num records deleted from table: " + rowCount) ;
          sql = "DELETE LOW_PRIORITY FROM fidText WHERE ftypeid IN (" + tracksStr + ") LIMIT " + delLimit ;
          rowCount = TrackManager.doLimitedSQLDelete(sql, delLimit, delPause, conn) ;
          //System.err.println("DELETE DEBUG: total num records deleted from table: " + rowCount) ;
          sql = "DELETE LOW_PRIORITY FROM fdata2 WHERE ftypeid IN (" + tracksStr + ") LIMIT " + delLimit ;
          rowCount = TrackManager.doLimitedSQLDelete(sql, delLimit, delPause, conn) ;
					sql = "DELETE LOW_PRIORITY FROM ftype2attributes WHERE ftype_id IN (" + tracksStr + ") LIMIT" + delLimit ;
					rowCount = TrackManager.doLimitedSQLDelete(sql, delLimit, delPause, conn) ;
          //System.err.println("DELETE DEBUG: total num records deleted from table: " + rowCount) ;
        }
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: TrackManager#expensiveDeleteTracks(C,S[],J) => error deleting tracks.") ;
        ex.printStackTrace(System.err) ;
      }
    }
    return rowCount ;
  }

  // Executes the SQL in deleteSql argument which already has the limit clause
  // using conn until the number of records deleted is less than the limit argument.
  // - pauses for pauseMillisec in between deletes.
  public static long doLimitedSQLDelete(String deleteSql, long limit, int pauseMillis, Connection conn)
  {
    long totalRowCount = 0 ;
    long numRowsDeleted = 0 ;
    Statement stmt = null ;
    if(conn != null)
    {
      try
      {
        // Create statement
        stmt = conn.createStatement() ;
        // Execute delete statement until all done, pausing between each.
        // System.err.println("DEBUG DELETE: doing this delete sql:\n    " + deleteSql + "\n\n") ;
        do
        {
          numRowsDeleted = stmt.executeUpdate(deleteSql) ;
          // System.err.println("DEBUG DELETE: numRowsDeleted = " + numRowsDeleted) ;
          totalRowCount += numRowsDeleted ;
          Util.sleep(pauseMillis) ;
        } while(numRowsDeleted >= limit) ;
      }
      catch(Exception ex)
      {
        System.err.println("ERROR: TrackManager#doLimitedSQLDelete(S,l,i,C) => error doing limited delete.") ;
        ex.printStackTrace(System.err) ;
      }
      finally
      {
        try
        {
          if(stmt != null)
          {
            stmt.close() ;
          }
        }
        catch(Exception ex) {}
      }
    }
    return totalRowCount ;
  }

  public static void main(String[] s) {
    DBAgent db = DBAgent.getInstance();
    boolean b = checkStyleFeature(db, "genboree_r_0f017cf20579fc9d442bfb7227ef3a4c", "ftype", 5);
    System.out.println("" + b);
  }
}
