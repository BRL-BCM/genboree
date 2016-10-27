package org.genboree.editor;

import org.genboree.dbaccess.DBAgent;
import org.genboree.dbaccess.GenboreeUpload;
import org.genboree.dbaccess.Refseq;
import org.genboree.dbaccess.TrackPermission;
import org.genboree.tabular.LffUtility;
import org.genboree.util.GenboreeUtils;
import org.genboree.upload.AnnotationCounter;
import org.genboree.util.Util;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import javax.servlet.jsp.JspWriter;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Vector;
import java.util.regex.Pattern;


/**
 * /**
 * User: tong Date: Nov 11, 2005 Time: 2:14:41 PM Helper class for AnnotationEditor JSP page mostly the method used in
 * database access and form validation
 */
public class AnnotationEditorHelper
{
  public static int findClassAnnoNum(Connection con, int fid)
  {
    int totalNumAnno = 0;
    AnnotationDetail annotation = new AnnotationDetail(fid);
    try {
      annotation = AnnotationEditorHelper.findAnnotation(annotation,  DBAgent.getInstance(), con, "" + fid);
      String sql = "select count(*) from fdata2 where gname= ? and rid = ? and ftypeid = ? ";
      PreparedStatement stms = con.prepareStatement(sql);
      stms.setString(1, annotation.getGname());
      stms.setInt(3, annotation.getFtypeId());
      stms.setInt(2, annotation.getRid());
      ResultSet rs = stms.executeQuery();
      while (rs.next()) {
        totalNumAnno = rs.getInt(1);
      }
    }
    catch (Exception e)
    {
      e.printStackTrace( System.err );
      System.err.println("Error AnnotationEditorHelper findClassAnnoNum");
    }
    return totalNumAnno;
  }


  public static String findStyleColor(AnnotationDetail annotation, Connection con, String userId)
  {
    String color = null;
    String sql = "select value from color c, fdata2 f,  featuretocolor fc " +
            "where f.fid = ? and f.ftypeid = fc.ftypeid and fc.colorid = c.colorid  and userId = ? ";
    try
    {
      PreparedStatement stms = con.prepareStatement(sql);
      stms.setInt(1, annotation.getFid());
      stms.setString(2, userId);
      ResultSet rs = stms.executeQuery();
      if (rs.next())
      {
        color = rs.getString(1);
      }
      rs.close();
      stms.close();
    }
    catch (SQLException e)
    {
      e.printStackTrace( System.err );
      System.err.println("Error AnnotationEditorHelper findStyleColor");
      return "";
    }

    return color;
  }



  public static boolean validateAnnotation(int i, AnnotationDetail annotation, HashMap trackMap, HttpSession mys, HttpServletRequest request, HashMap errorField, Vector vLog, HashMap chromosomes, JspWriter out, String dbName, Connection con) {
    boolean success = false;

    int numErrors = 0;
    numErrors += validateGname(i, annotation.getGname(), request, errorField, vLog, out);
    numErrors += validateChromosome(i, annotation.getChromosome(), request, errorField, vLog, chromosomes);

    String refName = annotation.getChromosome();
    Chromosome chromosome = (Chromosome) chromosomes.get(refName);
    if (chromosome == null)
      return false;
    boolean startError = false;
    int startErr = 0;
    try
    {
      startErr += validateStart(i, annotation, annotation.getFstart(), request, chromosome.length, errorField, vLog, out);

      if (startErr > 0)
        startError = true;
      numErrors += startErr;
      numErrors += validateStop(startError, annotation, i, annotation.getFstart(), annotation.getFstop(), chromosome.length, request, errorField, vLog, out);

      String type = request.getParameter("type_" + i);
      String subtype = request.getParameter("subtype_" + i);

      numErrors += validateTracks(false, request.getParameter("track_" + i), type, subtype, dbName, mys, trackMap, annotation, request, errorField, vLog, out, con);
      numErrors += validateQueryStartStop(i, annotation, annotation.getTstart(), annotation.getTstop(), chromosome.length, request, errorField, vLog);
      numErrors += validateFscore(i, annotation, annotation.getFscore(), errorField, vLog);



      if (numErrors == 0)
        success = true;

    }
    catch (Exception e)
    {
      e.printStackTrace( System.err );
      System.err.println("Error AnnotationEditorHelper validateAnnotation");
      return false;
    }
    return success;
  }
  public static int updateTrack(String type, String subtype, String dbName, Connection con)
  {

    int id = -1;
    if (type != null && subtype != null && !type.equals("") && !subtype.equals(""))
    {
      try {
        if (con == null || con.isClosed())
          con =  DBAgent.getInstance().getConnection(dbName);
        String sqlInsert = "insert into ftype (fmethod,fsource) values (?, ?)";

        PreparedStatement stms = con.prepareStatement(sqlInsert);
        stms.setString(1, type);
        stms.setString(2, subtype);
        stms.executeUpdate();
        stms.close();
        String sqlQuery = "select ftypeid from ftype where fmethod =?  and fsource = ?";
        PreparedStatement stms1 = con.prepareStatement(sqlQuery);
        stms1.setString(1, type);
        stms1.setString(2, subtype);
        ResultSet rs = stms1.executeQuery();
        if (rs.next()) {
          id = rs.getInt(1);

        }
        rs.close();
        stms1.close();
      }
      catch (SQLException e)
      {
        e.printStackTrace( System.err );
        System.err.println("Error AnnotationEditorHelper updateTrack");
      }
    }
    return id;

  }
  public static int existTrack(String type, String subtype, String dbName, HashMap trackMap, Connection con)
  {
    int id = -1;
    String fid = null;
    if (type != null && subtype != null && !type.equals("") && !subtype.equals(""))
    {
      String trackName = type + ":" + subtype;
      if ((fid = (String) trackMap.get(trackName)) != null) {
        try {
          id = Integer.parseInt(fid);
        }
        catch (Exception e) {
          e.printStackTrace(System.err);
          System.err.println(" error in parsing for ftype id:  " + fid);
          id = -2;
        }
        return id;
      }

      try {
        if (con == null || con.isClosed())
          con =  DBAgent.getInstance().getConnection(dbName);
        String sqlQuery = "select ftypeid from ftype where fmethod =?  and fsource = ?";
        PreparedStatement stms1 = con.prepareStatement(sqlQuery);
        stms1.setString(1, type);
        stms1.setString(2, subtype);
        ResultSet rs = stms1.executeQuery();
        if (rs.next()) {
          id = rs.getInt(1);
        }
        rs.close();
        stms1.close();

      }
      catch (SQLException e)
      {
        e.printStackTrace(System.err);
        System.err.println("error in AnnotationEditorHelper exitTrack");
      }
    }
    else {
      id = -2;
    }

    return id;

  }


  public static int validateGname(int i, String gname, HttpServletRequest request, HashMap errorField, Vector vLog, JspWriter out) {
    int numErr = 0;
    if (gname != null) {
      gname = gname.trim();
      gname = gname.replaceAll("\t", " ");
      gname = gname.replaceAll("\r", " ");
      gname = gname.replaceAll("\n", " ");
      gname = gname.replaceAll("\f", " ");

// check length
      if (gname.length() > 200)
      {
        errorField.put("gname_" + i, gname);
        vLog.add("Annotation name is too long.");
        numErr++;
      }
// check db empty String
      if (gname == null || gname.length() == 0)
      {
        gname = "";
        errorField.put("gname_" + i, gname);
        vLog.add("Annotation name is empty. Please enter an annotation name and try again. ");
        numErr++;
      }
    }
    else
    {
      errorField.put("gname_" + i, gname);
      vLog.add("Annotation name is empty. Please enter an annotation name and try again. ");
      numErr++;
    }

    return numErr;
  }


  public static boolean validateGname(String gname, HttpServletRequest request, Vector vLog, JspWriter out) {
    int numErr = 0;
    if (gname != null) {
      gname = gname.trim();
      gname = gname.replaceAll("\t", " ");
      gname = gname.replaceAll("\r", " ");
      gname = gname.replaceAll("\n", " ");
      gname = gname.replaceAll("\f", " ");

// check length
      if (gname.length() > 200) {
        vLog.add("Annotation name is too long.");
        return false;
      }
// check db empty String
      if (gname == null || gname.length() == 0) {
        gname = "";

        vLog.add("Annotation name is empty. Please enter an annotation name and try again. ");
        return false;
      }
    }
    else {

      vLog.add("Annotation name is empty. Please enter an annotation name and try again. ");
      return false;
    }

    return true;
  }


  public static int validateChromosome(int i, String chromosome, HttpServletRequest request, HashMap errorField, Vector vLog, HashMap chromosomes) {
    int numErrs = 0;

    int rid = -1;

    if (chromosome != null) {
      chromosome = chromosome.trim();
      if (!chromosomes.keySet().contains(chromosome)) {
        errorField.put("chromosome_" + i, chromosome);
        vLog.add("\"" + chromosome + "\" is an invalid chromosome name.\n");
        numErrs++;
      }
    }
    else {

      errorField.put("chromosome_" + i, chromosome);
      vLog.add("Chromosome name can not be empty. ");
      numErrs++;
    }
    return numErrs;
  }

  static String DIGIT_RE = "^[+-]?\\d+(\\d+)?$";
  static protected final Pattern compiledDIGIT_RE = Pattern.compile(DIGIT_RE);

  public static int validateStart(int i, AnnotationDetail annotation, String fstart, HttpServletRequest request, long chromLength, HashMap errorField, Vector vLog, JspWriter out) throws NumberFormatException {
    int numErrs = 0;
    long lstart = 0;
    if (fstart != null) {
      try {
        fstart = fstart.trim();
        fstart = fstart.replaceAll(",", "");
        fstart = fstart.replaceAll(" ", "");
        lstart = Long.parseLong(fstart);
      }
      catch (NumberFormatException e) {
        vLog.add("Start must be an integer between 1 and " + chromLength);
        errorField.put("start_" + i, fstart);
        return 1;
      }
    }

    if (lstart > chromLength) {
      vLog.add("Start exceeded chromosome length (" + chromLength + ")");
      errorField.put("start_" + i, "start must be an integer greater or equals to 1.");
      return numErrs++;
    }


    if (lstart <= 0) {
      vLog.add("Start must be an integer greater or equals to 1.");
      errorField.put("start_" + i, "start must be an integer greater or equals to 1.");
      return numErrs++;
    }


    if (lstart > 2147483647) {
      vLog.add("Start is too large.");
      errorField.put("start_" + i, "start must be an integer greater or equals to 1.");
      return numErrs++;
    }

    if (numErrs == 0)
      annotation.setStart(lstart);
    return numErrs;


  }


  public static int validateStop(boolean startError, AnnotationDetail anno, int i, String fstart, String fstop, long chromosomeLength, HttpServletRequest request, HashMap errorField, Vector vLog, JspWriter out) {
    int numErrs = 0;

    long istart = 0;
    long istop = 0;

    if (fstop != null) {
      try {
        fstop = fstop.trim();
        fstop = fstop.replaceAll(",", "");
        fstop = fstop.replaceAll(" ", "");
        istop = Long.parseLong(fstop);
        anno.setStop(istop);

      }
      catch (Exception e) {
        vLog.add("Stop must be an integer between 1 and " + chromosomeLength);
        errorField.put("stop_" + i, fstop);
        return numErrs++;
      }
    }


    if (!startError)
      if (istart > istop) {
        vLog.add(" Chromosome start \"" + istart + "\" is greater than stop " + istop + ".");
        errorField.put("start_" + i, fstart);
        errorField.put("stop_" + i, fstop);
        return numErrs++;
      }

    if (istop <= 0) {
      vLog.add("Stop must be an integer greater or equals to 1.");
      errorField.put("stop_" + i, fstop);
      return numErrs++;
    }

    if (istop > chromosomeLength) {
      vLog.add("Stop exceeded chromosome length (" + chromosomeLength + ").");
      errorField.put("stop_" + i, fstop);
      return 1;
    }

    if (istop > 2147483647) {
      vLog.add("Stop is too large.");
      errorField.put("stop_" + i, "Start is too large.");
      return numErrs++;
    }


    return numErrs;
  }


  /**
   * retrieves information from jsp page and save the information into annotationDetail object Notice that chromosome
   * and track name could be changes that will change the id of these two fields
   *
   * @param annotation  AnnotationDetail object initiated with data from db
   * @param trackMap    HashMap of track name:id value pairs,
   * @param request     HttpRequest
   * @param errorField  HasMap for errors in the form
   * @param vLog        log for errors
   * @param chromosomes ArrayList of available chromosome names in database
   * @param dbName      String
   * @return success boolean  true if all right and false if wrong
   */
  public static boolean validateForm(AnnotationDetail annotation, HashMap trackMap, HttpSession mys, HttpServletRequest request, HashMap errorField, Vector vLog, HashMap chromosomes, JspWriter out, String dbName, Connection con) {
    boolean success = false;

    int numErrors = 0;
    numErrors += validateGname(annotation, request, errorField, vLog, out);
    numErrors += validateChromosome(annotation, request, errorField, vLog, chromosomes);

    String refName = annotation.getChromosome();
    Chromosome chromosome = (Chromosome) chromosomes.get(refName);
    if (chromosome == null)
      return false;

    numErrors += validateStartStop(annotation, chromosome.length, request, errorField, vLog, out);

    numErrors += validateStrand(annotation, request, errorField, vLog);
    String type = request.getParameter("new_type");
    String subtype = request.getParameter("new_subtype");
    numErrors += validateTracks(true, request.getParameter("tracks"), type, subtype, dbName, mys, trackMap, annotation, request, errorField, vLog, out, con);

    numErrors += validateQueryStartStop(annotation, request, errorField, vLog);

    numErrors += validateFscore(annotation, request, errorField, vLog);

    numErrors += validatePhase(annotation, request, errorField, vLog);

    numErrors += validateSequence(annotation, request, errorField, vLog);

    numErrors += validateComments(annotation, request, errorField, vLog);

    if (numErrors == 0)
      success = true;

    return success;
  }


  /**
   * convert blank phase ".", null tstart  or tend to "n/a" if choice = 0; convert "n/a", ".", and blank line of query
   * start and end to null if choice == 1
   *
   * @param anno
   * @param choice int  0 from db to jsp page ; 1 from jsp to db
   * @return
   */

  public static AnnotationDetail convertAnnotation(AnnotationDetail anno, int choice) {

    String tstart = anno.getTstart();
    String tstop = anno.getTstop();
// convert data obtained from database to jsp page display form
    if (choice == 0) {
      String phase = anno.getPhase();
      if (phase == null)
        anno.setPhase("0");
      else {
        phase = phase.trim();
        if (phase.length() == 0) {
          anno.setPhase("0");
        }
      }

      String fstart = anno.getFstart();
      long istart = 0;
      try {
        istart = Long.parseLong(fstart);
      }
      catch (Exception e) {
         e.printStackTrace(System.err);
        istart = 1;
      }

      if (anno.getFstart() == null || istart <= 0)
        anno.setFstart("1");


      if (anno.getFstop() == null)
        anno.setFstop("1");

      if (tstop == null) {
        anno.setTstop("n/a");
      }


      if (tstart == null)
        anno.setTstart("n/a");


      if (anno.getSequences() == null)
        anno.setSequences("");


      String comment = anno.getComments();
      if (anno.getComments() == null)
        anno.setComments("");


      if (anno.getFscore() == null) {
        anno.setFscore("");

      }

    }

// convert data from jsp to database form
    else if (choice == 1) {
      if (tstart != null) {
        if (tstart.compareToIgnoreCase("n/a") == 0 || tstart.compareToIgnoreCase(".") == 0 || tstart.compareToIgnoreCase("") == 0)
          anno.setTstart(null);
      }

      if (tstop != null) {
        if (tstop.compareToIgnoreCase("n/a") == 0 || tstop.compareToIgnoreCase(".") == 0 || tstop.compareToIgnoreCase("") == 0)
          anno.setTstop(null);
      }

      if (anno.getPhase() != null && anno.getPhase().compareTo(".") == 0)
        anno.setPhase("0");

      if (anno.getFscore() != null && anno.getFscore().compareTo(".") == 0) {
        anno.setFscore("0");
        anno.setScore(0.0);
      }

      String seq = anno.getSequences();
      if (seq != null)
        anno.setSequences(stripTabAndReturn(seq));

      String comments = anno.getComments();
      if (comments != null)
        anno.setComments(stripTabAndReturn(comments));
    }

    return anno;
  }


  public static AnnotationDetail copy(AnnotationDetail from, AnnotationDetail to) {
    to.setRid(from.getRid());
    to.setFstart("" + from.getStart());
    to.setFstop("" + from.getStop());
    to.setStart(from.getStart());
    to.setStop(from.getStop());
    to.setFbin(from.getFbin());
    to.setFtypeId(from.getFtypeId());
    to.setFscore(from.getFscore());
    to.setScore(from.getScore());
    to.setStrand(from.getStrand());
    to.setPhase(from.getPhase());
    to.setTargetStart(from.getTargetStart());
    to.setTargetStop(from.getTargetStop());
    to.setChromosome(from.getChromosome());
    to.setTrackName(from.getTrackName());
    to.setTstart(from.getTstart());
    to.setTstop(from.getTstop());
    to.setGname(from.getGname());
    to.setComments(from.getComments());
    to.setSequences(from.getSequences());
    to.setLength(from.getLength());
    to.setFstart(from.getFstart());
    to.setFstop(from.getFstop());
    to.displayCode = from.displayCode;
    to.displayColor = from.displayColor;
    to.flag = from.flag;
    return to;
  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param fid    int  id of annotation
   * @param db     DBAgent for db connection
   * @param dbName String
   */
  public static void deleteAnnotation(int fid, DBAgent db, String dbName, JspWriter out, Connection con)
  {

    String ftypeIds = GenboreeUtils.getFtypeIdsFromFids( con,  "" + fid );
    String sqlupdate = "delete from fdata2 where fid = ? ";
    try {
      if (con == null || con.isClosed())
        con = db.getConnection(dbName);
      PreparedStatement stms = con.prepareStatement(sqlupdate);

      stms.setInt(1, fid);
      stms.executeUpdate();
      stms.close();
    }
    catch (SQLException e) {
      e.printStackTrace(System.err);
    }

    String sqldelfidtext = "delete from  fidText where fid = " + fid;
    db.executeUpdate(dbName, sqldelfidtext);

    AnnotationCounter.updateCountTableUsingTrackIds( con, ftypeIds );

  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *

   */
  public static void deleteAllAnnotation(int[] fids,  Connection con) {
    String fidsSt = null;
    String sqlupdate = null;
    String ftypeIds = null;

    if (fids != null)
    {
      fidsSt  = "";
      for (int i = 0; i < fids.length; i++) {
        fidsSt  = fidsSt  + fids[i] + ", ";
      }
      fidsSt  = fidsSt.substring(0, fidsSt .lastIndexOf(","));
      ftypeIds = GenboreeUtils.getFtypeIdsFromFids( con,  "" + fidsSt );
      sqlupdate = "delete from fdata2 where fid in (" + fidsSt  + ")";
    }
    else
      return;

    try
    {
      PreparedStatement stms = con.prepareStatement(sqlupdate);
      stms.executeUpdate();
      String sqldelfidtext = "delete from  fidText where fid  in (?)";
      stms = con.prepareStatement(sqldelfidtext);
      stms.setString(1, fidsSt );
      stms.executeUpdate();
    }
    catch (SQLException e)
    {
      e.printStackTrace(System.err);
    }
    AnnotationCounter.updateCountTableUsingTrackIds( con, ftypeIds );

  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param db     DBAgent for db connection
   * @param upload
   */
  public static boolean updateAnnotationsComments(String newComments, int[] fids, DBAgent db, GenboreeUpload upload, JspWriter out, Connection con) {
    int count = 0;
    boolean success = false;
    try {
      if (newComments == null || fids == null || fids.length == 0) {
        return false;
      }
      String sqlupdate = "update fidText " +
              " set text =? where fid = ? and textType ='t'";
      if (con == null || con.isClosed())
        con = db.getConnection(upload.getDatabaseName());
      PreparedStatement stms = null;
      if (con != null || !con.isClosed()) {
        stms = con.prepareStatement(sqlupdate);
        for (int i = 0; i < fids.length; i++) {
          try {
            stms.setString(1, newComments);
            stms.setInt(2, fids[i]);
            count += stms.executeUpdate();
          }
          catch (Exception e) {
            continue;
          }
        }
        stms.close();
      }
    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }

    success = true;
    return success;
  }

  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param db     DBAgent for db connection
   * @param upload
   */
  public static boolean updateAnnotationsComments(String newComments, AnnotationDetail[] annotations, DBAgent db, GenboreeUpload upload, JspWriter out, Connection con) {

    int count = 0;
    boolean success = false;
    try {
      if (newComments == null || annotations == null || annotations.length == 0) {
        return false;
      }

      String sqlupdate = "update fidText " +
              " set text =? where fid = ? and textType ='t'";
      String sqlInsert = "insert into fidText (fid, textType, text, ftypeid) " +
              " values(?, ?, ?, ? ); ";
      if (con == null || con.isClosed())
        con = db.getConnection(upload.getDatabaseName());
      PreparedStatement stms = null;
      PreparedStatement stmsIns = null;
      if (con != null || !con.isClosed()) {
        stms = con.prepareStatement(sqlupdate);
        stmsIns = con.prepareStatement(sqlInsert);

        for (int i = 0; i < annotations.length; i++) {
          try {
            int n = 0;
            String oldComments = annotations[i].getComments();
            stms.setString(1, oldComments);
            stms.setInt(2, annotations[i].getFid());
            n = stms.executeUpdate();
            if (n < 1) {
              stmsIns.setInt(1, annotations[i].getFid());
              stmsIns.setString(2, "t");
              stmsIns.setString(3, oldComments);
              stmsIns.setInt(4, annotations[i].getFtypeId());
              n = stmsIns.executeUpdate();
            }

            count += n;

          }
          catch (Exception e) {
            continue;
          }
        }
        stms.close();
        stmsIns.close();
      }
    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }

    if (count == annotations.length)
      success = true;
    return success;
  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param db     DBAgent for db connection
   * @param upload
   */
  public static boolean updateAnnotationSequence(String newSeq, AnnotationDetail annotation, DBAgent db, GenboreeUpload upload, JspWriter out, Connection con) {

    int n = 0;
    boolean success = false;
    try {
      if (newSeq == null || annotation == null) {
        return false;
      }

      String sqlupdate = "update fidText " +
              " set text =? where fid = ? and textType ='s'";
      String sqlInsert = "insert into fidText (fid, textType, text, ftypeid) " +
              " values(?, ?, ?, ? ); ";
      if (con == null || con.isClosed())
        con = db.getConnection(upload.getDatabaseName());
      PreparedStatement stms = null;
      PreparedStatement stmsIns = null;
      if (con != null || !con.isClosed()) {
        stms = con.prepareStatement(sqlupdate);
        stmsIns = con.prepareStatement(sqlInsert);

        String oldComments = annotation.getComments();
        stms.setString(1, oldComments);
        stms.setInt(2, annotation.getFid());
        n = stms.executeUpdate();
        if (n < 1) {
          stmsIns.setInt(1, annotation.getFid());
          stmsIns.setString(2, "s");
          stmsIns.setString(3, oldComments);
          stmsIns.setInt(4, annotation.getFtypeId());
          n = stmsIns.executeUpdate();
        }


      }
      stms.close();
      stmsIns.close();

    }
    catch (Exception e) {
      e.printStackTrace(System.err);
      return false;
    }

    if (n <= 0)
      success = false;
    else
      success = true;
    return success;
  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param db     DBAgent for db connection
   * @param upload
   */
  public static boolean updateAnnotationsName(String newName, int[] fids, DBAgent db, GenboreeUpload upload, JspWriter out, Connection con) {

    int count = 0;
    boolean success = false;
    try {
      if (newName == null || fids == null || fids.length == 0) {
        return false;
      }

      String sqlupdate = "update fdata2 " +
              " set gname=? where fid = ? ";
      if (con == null || con.isClosed())
        con = db.getConnection(upload.getDatabaseName());
      PreparedStatement stms = null;

      if (con != null || !con.isClosed()) {
        stms = con.prepareStatement(sqlupdate);
        for (int i = 0; i < fids.length; i++) {
          try {
            stms.setString(1, newName);
            stms.setInt(2, fids[i]);
            count += stms.executeUpdate();
          }
          catch (Exception e) {
            continue;
          }
        }
        stms.close();
      }
    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }

//if (count == fids.length )
    success = true;
    return success;
  }


  public static boolean updateAnnotationsColor(int newColor, int[] fids, DBAgent db, GenboreeUpload upload, JspWriter out, Connection con) {

    int count = 0;
    boolean success = false;
    try {

      String sqlupdate = "update fdata2 " +
              " set displayColor=? where fid = ? ";
      if (con == null || con.isClosed())
        con = db.getConnection(upload.getDatabaseName());
      PreparedStatement stms = null;

      if (con != null || !con.isClosed()) {
        stms = con.prepareStatement(sqlupdate);
        for (int i = 0; i < fids.length; i++) {
          try {
            stms.setInt(1, newColor);
            stms.setInt(2, fids[i]);
            count += stms.executeUpdate();
          }
          catch (Exception e) {
            continue;
          }
        }
        stms.close();
      }
    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }

//if (count == fids.length )
    success = true;
    return success;
  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText

   */

  /*
 MLGG
 Modified for the new table ftype2attributeName
  */
  public static void updateSelectedFtype( int newFtypeid, int[] fids,  Connection con, String databaseName, int genboreeUserId )
  {
    String ftypeIds = "";
    try {
      if (fids == null || fids.length == 0)
        return;
        String commaSepFids = GenboreeUtils.getCommaSeparatedIds( fids );
        ftypeIds = GenboreeUtils.getFtypeIdsFromFids(con, commaSepFids);
        ftypeIds += ", " + newFtypeid;
        boolean hasMyPermission = TrackPermission.isTrackAllowed( databaseName, newFtypeid, genboreeUserId );
        if(!hasMyPermission)
          return;

      String sqlupdate = "update fdata2 set ftypeid=? where fid = ? ";
      String updateFidTex = "update fidText set ftypeid= ? where fid = ? ";
      PreparedStatement stms = null;
      PreparedStatement stms1 = null;
      ArrayList dupidList = new ArrayList();
      stms = con.prepareStatement(sqlupdate);
      stms1 = con.prepareStatement(updateFidTex);

      for (int i = 0; i < fids.length; i++) {
        try {
          stms.setInt(1, newFtypeid);
          stms.setInt(2, fids[i]);
          stms.executeUpdate();

          stms1.setInt(1, newFtypeid);
          stms1.setInt(2, fids[i]);
          stms1.executeUpdate();
        }
        catch (Exception e) {
          e.printStackTrace(System.err);
          dupidList.add("" + fids[i]);
          System.err.println("annotation update error with fid " + fids[i]);
          continue;

        }
      }
      if (!dupidList.isEmpty()) {
        int[] dupIDs = new int[dupidList.size()];
        for (int i = 0; i < dupidList.size(); i++) {
          dupIDs[i] = Integer.parseInt((String) dupidList.get(i));

        }
        deleteAllAnnotation(dupIDs, con);
      }
      stms.close();
      stms1.close();
    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }
    finally
    {
      AnnotationCounter.updateCountTableUsingTrackIds( con, ftypeIds );
    }
  }



  public static void updateFeature2AVPName( int newFtypeid, int[] fids,  Connection con) {
    try {
      if (fids == null || fids.length == 0)
        return;

      String [] attNameIds =retriveAttNameIds  ( fids,   con);
      String sqlupdate = "insert ignore into  ftype2attributeName (ftypeid, attNameId)   values (?, ? ) ";
      PreparedStatement stms = null;
      stms = con.prepareStatement(sqlupdate);
      if (attNameIds != null && attNameIds.length > 0 ) {
        for (int i = 0; i < attNameIds.length; i++) {
          try {
            stms.setInt(1, newFtypeid);
            stms.setString(2, attNameIds[i]);
            stms.executeUpdate();
          }
          catch (Exception e) {
            e.printStackTrace(System.err);
          }
        }
      }
      stms.close();
    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }
  }

  public static String[]  retriveAttNameIds (  int[] fids,  Connection con) {
    String [] attNameIds = null;
    HashMap map = new HashMap();
    PreparedStatement stms = null;
    try {
      if (fids == null || fids.length == 0)
        return null;
      String [] fidArr = LffUtility.getFidStrings(fids, 1000);
      String sql = null;
      for (int i=0; i<fidArr.length; i++) {
        sql =  "select distinct attNameId from fid2attribute  where fid in ("  + fidArr[i] + ")" ;
        stms = con.prepareStatement(sql);
        ResultSet rs =stms.executeQuery();

        while (rs.next()) {
          map.put(rs.getString(1), "1");
        }
      }
      stms.close();
    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }

    if (!map.isEmpty()) {
      attNameIds = (String [])map.keySet().toArray(new String[map.size()]);

    }

    return attNameIds;
  }


  public static void updateFtypeid(int newftypeid, int fid,  Connection con)
  {
    String ftypeIds = "";
    String ftypeId = null;

    if(fid > 0)
    {
      ftypeId = GenboreeUtils.getFtypeIdsFromFids( con,  "" + fid );
      if(ftypeId != null && ftypeId.length() > 0)
        ftypeIds = ftypeId;
    }
    else
    {
      System.err.println("The AnnotationEditorHelp has problems the fid is null");
      System.err.println("In method AnnotationEditorHelp#updateFtypeid");
    }
    if(ftypeId != null && ftypeId.length() > 0 )
      ftypeIds += ", " + newftypeid;
    else
     ftypeIds += "" + newftypeid;

    String sqlupdate = "update fdata2  set ftypeid=? where fid = ? ";
    String updateFidTex = "update ignore fidText set ftypeid= ? where fid = ? ";
    try {
      PreparedStatement stms = con.prepareStatement(sqlupdate);
      stms.setInt(1, newftypeid);
      stms.setInt(2, fid);
      stms.executeUpdate();
      stms = con.prepareStatement(updateFidTex);
      stms.setInt(1, newftypeid);
      stms.setInt(2, fid);
      stms.executeUpdate();
      stms.close();
    }
    catch (Exception e)
    {
      System.err.println("Exception in AnnotationEditorHelper::updateFtypeid");
      e.printStackTrace(System.err);
    }
    finally{
    AnnotationCounter.updateCountTableUsingTrackIds( con, ftypeIds );
    }
  }

  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param fid int  id of annotation
   * @param db  DBAgent for db connection
   */
  public static boolean deleteAnnotationText(int fid, DBAgent db, Connection con, JspWriter out) {

    String sqlupdate = "delete from fidText where fid = ? ";
    int rc = 0;
    try {

      PreparedStatement stms = con.prepareStatement(sqlupdate);

      stms.setInt(1, fid);
      rc = stms.executeUpdate();
      stms.close();
    }
    catch (SQLException e) {

      e.printStackTrace(System.err);
    }

    if (rc <= 0)
      return false;
    else
      return true;


  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param db     DBAgent for db connection
   * @param upload
   */
  public static void updateAnnotationGroupName(String gname, int fid, DBAgent db, GenboreeUpload upload, JspWriter out, Connection con) throws SQLException {

    String sqlupdate = "update fdata2  set gname = ?  where fid = ? ";

    try {
      if (con == null || con.isClosed())
        con = db.getConnection(upload.getDatabaseName());
      if (con != null || !con.isClosed()) {
        PreparedStatement stms = con.prepareStatement(sqlupdate);
        stms.setString(1, gname);
        stms.setInt(2, fid);
        stms.executeUpdate();
        stms.close();

      }
    }
    catch (SQLException e) {
      e.printStackTrace(System.err);
      throw new SQLException(e.getMessage());
    }
  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param annotation object of annotation details
   * @param db         DBAgent for db connection
   * @param upload
   */
  public static void updateAnnotation(AnnotationDetail annotation, DBAgent db, GenboreeUpload upload, JspWriter out, Connection con) throws SQLException {
    String s = null;
    String ftypeIds = GenboreeUtils.getFtypeIdsFromFids( con,  "" + annotation.getFid());
    ftypeIds += ", " + annotation.getFtypeId();

    if ((s = annotation.getComments()) != null)
      annotation.setComments(s.replaceAll("'", "\'"));

    final int RID = 1;
    final int FSTART = 2;
    final int FSTOP = 3;
    final int FBIN = 4;
    final int FTYPEID = 5;
    final int FSCORE = 6;
    final int FSTRAND = 7;
    final int PHASE = 8;
    final int TARGET_START = 9;
    final int TARGET_STOP = 10;
    final int GNAME = 11;
    final int FID = 13;
    final int DISPLAY_COLOR = 12;

    boolean newTrack = false;
    boolean newChromosome = false;
    int newFtypeid = -1;
    int newChromosomeId = -1;

    String sqlupdate = "update fdata2 " +
            " set rid=?, fstart = ?, fstop = ?, fbin=?, ftypeid = ? " +
            ", fscore = ?, fstrand = ?, fphase = ?, ftarget_start = ? " +
            ", ftarget_stop = ?, gname = ?, displayColor = ?   where fid = ? ";

    try {
      if (con == null || con.isClosed())
        con = db.getConnection(upload.getDatabaseName());

      PreparedStatement stms = con.prepareStatement(sqlupdate);
      stms.setInt(RID, annotation.getRid());
      stms.setLong(FSTART, annotation.getStart());
      stms.setLong(FSTOP, annotation.getStop());
      stms.setString(FBIN, annotation.getFbin());
      stms.setInt(FTYPEID, annotation.getFtypeId());
      stms.setString(FSCORE, annotation.getFscore());
      stms.setString(FSTRAND, annotation.getStrand());
      stms.setString(PHASE, annotation.getPhase());
      stms.setString(TARGET_START, annotation.getTstart());
      stms.setString(TARGET_STOP, annotation.getTstop());
      stms.setString(GNAME, annotation.getGname());
      stms.setInt(FID, annotation.getFid());

      String hexS = annotation.getHexAnnoColor();

      if (hexS != null) {
        hexS = hexS.replaceAll("#", "");
      }

      if ((hexS != null) && hexS.length() == 6) {
        annotation.setDisplayColor(Integer.parseInt(hexS, 16));
      }

// annotation.setDisplayColor(GenboreeUtils.extractColorIntValueFormColorValuePair(hexS));
      if (hexS != null && hexS.length() == 6)
        stms.setString(DISPLAY_COLOR, "" + annotation.getDisplayColor());
      else
        stms.setString(DISPLAY_COLOR, null);
      int n = stms.executeUpdate();

      stms.close();

    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }

    AnnotationCounter.updateCountTableUsingTrackIds( con, ftypeIds );

    String comments = annotation.getComments();
    String sequences = annotation.getSequences();
    if (comments != null)
      comments = comments.trim();
    if (sequences != null)
      sequences = sequences.trim();

    boolean updatable = false;
    if (comments != null && comments.compareTo("") != 0)
      updatable = true;

    if (sequences != null && sequences.compareTo("") != 0)
      updatable = true;

    if (updatable) {
      try {

// 2. update fidText
        String sqldelfidtext = "delete from  fidText where fid = " + annotation.getFid()
                + " and textType = 's'";
        db.executeUpdate(upload.getDatabaseName(), sqldelfidtext);


        String sqlfidSeq = "insert ignore into  fidText (fid, textType, text, ftypeid)  " +
                "  values (?, ?, ?, ?) ";


        PreparedStatement stms1 = null;
        try {
          stms1 = con.prepareStatement(sqlfidSeq);
          stms1.setInt(1, annotation.getFid());
          stms1.setString(2, "s");
          stms1.setString(3, annotation.getSequences());
          stms1.setInt(4, annotation.getFtypeId());
          stms1.executeUpdate();

//stms1.close();
//db.executeInsert(upload.getDatabaseName(), sqlfidSeq);
        }
        catch (SQLException e) {
          e.printStackTrace(System.err);
        }


        sqldelfidtext = "delete from  fidText where fid = " + annotation.getFid() + " and textType = 't'";
        annotation.getFtypeId();
        db.executeUpdate(upload.getDatabaseName(), sqldelfidtext);

        try {
          PreparedStatement stms2 = con.prepareStatement(sqlfidSeq);
          stms2.setInt(1, annotation.getFid());
          stms2.setString(2, "t");
          stms2.setString(3, annotation.getComments());
          stms2.setInt(4, annotation.getFtypeId());
          stms2.executeUpdate();
          stms1.close();
          stms2.close();

//db.executeInsert(upload.getDatabaseName(), sqlfidtext);
        }
        catch (Exception e) {
          System.err.println("sql error from AnnotatonEditoHelper.updateAnnotation");
          e.printStackTrace(System.err);
        }

      }
      catch (Exception e) {
        e.printStackTrace(System.err);
      }
    }
  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param annotation object of annotation details
   * @param db         DBAgent for db connection
   * @param upload
   */
  public static void updateText(int fid, AnnotationDetail annotation, DBAgent db, GenboreeUpload upload, JspWriter out, Connection con) throws SQLException {
    String s = null;
    if ((s = annotation.getComments()) != null)
      annotation.setComments(s.replaceAll("'", "\'"));

    try {
      if (con == null)
        con = db.getConnection(upload.getDatabaseName());
      if (con != null || !con.isClosed()) {

// 2. update fidText
        String sqldelfidtext = "delete from  fidText where fid = " + annotation.getFid()
                + " and textType = 's'";
        db.executeUpdate(upload.getDatabaseName(), sqldelfidtext);


        String sqlfidSeq = "insert ignore into  fidText (fid, textType, text, ftypeid)  " +
                "  values (?, ?, ?, ?) ";


        PreparedStatement stms1 = null;
        try {
          stms1 = con.prepareStatement(sqlfidSeq);
          stms1.setInt(1, fid);
          stms1.setString(2, "s");
          stms1.setString(3, annotation.getSequences());
          stms1.setInt(4, annotation.getFtypeId());
          stms1.executeUpdate();

//stms1.close();
//db.executeInsert(upload.getDatabaseName(), sqlfidSeq);
        }
        catch (SQLException e) {
          e.printStackTrace(System.err);
        }


        sqldelfidtext = "delete from  fidText where fid = " + annotation.getFid() + " and textType = 't'";
        annotation.getFtypeId();
        db.executeUpdate(upload.getDatabaseName(), sqldelfidtext);


        try {
          PreparedStatement stms2 = con.prepareStatement(sqlfidSeq);
          stms2.setInt(1, fid);
          stms2.setString(2, "t");
          stms2.setString(3, annotation.getComments());
          stms2.setInt(4, annotation.getFtypeId());
          stms2.executeUpdate();
          stms1.close();
          stms2.close();

//db.executeInsert(upload.getDatabaseName(), sqlfidtext);
        }
        catch (Exception e) {
          System.err.println("sql error from AnnotatonEditoHelper.updateAnnotation");
          e.printStackTrace(System.err);
        }
      }
    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }

  }


  public static void reassignAnnotationText(Connection con, int newfid, int oldfid, AnnotationDetail annotation, DBAgent db, String dbName) {
// if there is cooments or seq, insert; otherwise, do nothing
    String comments = annotation.getComments();
    String sequence = annotation.getSequences();
    boolean updateable = false;
    if (comments != null)
      comments = comments.trim();

    if (sequence != null)
      sequence = sequence.trim();

    if (comments != null && comments.compareTo("") != 0)
      updateable = true;

    if (sequence != null && sequence.compareTo("") != 0)
      updateable = true;


    if (updateable) {

      String del = "delete  from fidText where fid= " + newfid;

      String sqlInsert = "insert ignore into  fidText (fid, textType, text, ftypeid)  " +
              "  values (?, ?, ?, ?) ";

      PreparedStatement stms1 = null;
      try {
        if (con == null)
          con = db.getConnection(dbName);

        if (con == null)
          throw new SQLException("connection failed at reassignFidText");
        stms1 = con.prepareStatement(del);
        stms1.executeUpdate();

        stms1 = con.prepareStatement(sqlInsert);
        stms1.setInt(1, newfid);
        stms1.setString(2, "s");
        stms1.setString(3, annotation.getSequences());
        stms1.setInt(4, annotation.getFtypeId());
        stms1.executeUpdate();

        stms1 = con.prepareStatement(sqlInsert);
        stms1.setInt(1, newfid);
        stms1.setString(2, "t");
        stms1.setString(3, annotation.getComments());
        stms1.setInt(4, annotation.getFtypeId());
        stms1.executeUpdate();

        del = "delete  from fidText where fid= " + oldfid;
        stms1 = con.prepareStatement(del);
        stms1.executeUpdate();


        stms1.close();
      }
      catch (SQLException e) {
        e.printStackTrace(System.err);
      }
    }
  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param annotation object of annotation details
   */


  public static boolean insertText(int newftypeid, AnnotationDetail annotation, DBAgent db, String dbName, Connection con, JspWriter out) throws SQLException {
    if (con == null || con.isClosed())
      con = db.getConnection(dbName);

    if (con == null || con.isClosed()) {
      throw new SQLException("connection failed at AnnotationEditorHelper.updateAnnotationText");

    }
    boolean success = false;
    int rc = 0;

    String comments = annotation.getComments();
    String sequence = annotation.getSequences();
    boolean updateable = false;
    if (comments != null)
      comments = comments.trim();

    if (sequence != null)
      sequence = sequence.trim();

    if (comments != null && comments.compareTo("") != 0)
      updateable = true;

    if (sequence != null && sequence.compareTo("") != 0)
      updateable = true;


    if (updateable) {

      String sqlInsert = "insert ignore into  fidText (fid, textType, text, ftypeid)  " +
              "  values (?, ?, ?, ?) ";

      PreparedStatement stms1 = null;
      try {

        stms1 = con.prepareStatement(sqlInsert);
        stms1.setInt(1, newftypeid);
        stms1.setString(2, "s");
        stms1.setString(3, annotation.getSequences());
        stms1.setInt(4, newftypeid);
        rc += stms1.executeUpdate();
        stms1 = con.prepareStatement(sqlInsert);
        stms1.setInt(1, newftypeid);
        stms1.setString(2, "t");
        stms1.setString(3, annotation.getComments());
        stms1.setInt(4, newftypeid);
        rc += stms1.executeUpdate();
        stms1.close();

      }
      catch (SQLException e) {
        e.printStackTrace(System.err);
      }
    }
    else
      return true;

    if (updateable && rc > 0)
      success = true;
    if (!updateable)
      success = true;
    return success;
  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param annotation object of annotation details
   */


  public static void updateAnnotationText(int newftypeid, AnnotationDetail annotation, DBAgent db, String dbName, Connection con, JspWriter out) throws SQLException {
    String s = null;
    int newfid = 0;

    if (con == null || con.isClosed())
      con = db.getConnection(dbName);

    if (con == null || con.isClosed()) {
      throw new SQLException("connection failed at AnnotationEditorHelper.updateAnnotationText");

    }

    try {
      AnnotationDetail temp = new AnnotationDetail(annotation.getFid());
      temp = copy(annotation, temp);
      temp.setFtypeId(newftypeid);

      if (con != null && !con.isClosed()) {
        newfid = isDupAnnotation(dbName, temp, con);
        temp.setFtypeId(annotation.getFtypeId());
        boolean isDup = isDupText(dbName, newfid, annotation, con);
        if (newfid > 0 && isDupText(dbName, newfid, annotation, con)) {
          String sqlfidSeq = "update ignore  fidText set text = ? , textType =? where fid = ? and ftypeid = ? ";
          PreparedStatement stms1 = null;
          try {
            stms1 = con.prepareStatement(sqlfidSeq);
            stms1.setString(1, annotation.getSequences());
            stms1.setString(2, "s");
            stms1.setInt(3, newfid);
            stms1.setInt(4, newftypeid);
            stms1.executeUpdate();
          }
          catch (SQLException e) {
            e.printStackTrace(System.err);
          }

          try {
            stms1.setString(1, annotation.getComments());
            stms1.setString(2, "t");
            stms1.setInt(3, newfid);
            stms1.setInt(4, newftypeid);
            stms1.executeUpdate();
            stms1.close();
          }
          catch (SQLException e) {
            e.printStackTrace(System.err);
          }


        }
        else { // comments and sequences not existng with new ftypeid and fid
// if there is cooments or seq, insert; otherwise, do nothing
          String comments = annotation.getComments();
          String sequence = annotation.getSequences();
          boolean updateable = false;
          if (comments != null)
            comments = comments.trim();

          if (sequence != null)
            sequence = sequence.trim();

          if (comments != null && comments.compareTo("") != 0)
            updateable = true;

          if (sequence != null && sequence.compareTo("") != 0)
            updateable = true;


          if (updateable) {

            String del = "delete from fidText where fid= " + newfid;

            String sqlInsert = "insert ignore into  fidText (fid, textType, text, ftypeid)  " +
                    "  values (?, ?, ?, ?) ";

            PreparedStatement stms1 = null;
            try {
              stms1 = con.prepareStatement(del);
              stms1.executeUpdate();

              stms1 = con.prepareStatement(sqlInsert);
              stms1.setInt(1, newfid);
              stms1.setString(2, "s");
              stms1.setString(3, annotation.getSequences());
              stms1.setInt(4, newftypeid);
              stms1.executeUpdate();
              stms1 = con.prepareStatement(sqlInsert);
              stms1.setInt(1, newfid);
              stms1.setString(2, "t");
              stms1.setString(3, annotation.getComments());
              stms1.setInt(4, newftypeid);
              stms1.executeUpdate();
              stms1.close();

            }
            catch (SQLException e) {
              e.printStackTrace(System.err);
            }
          }
        }
      }
    }
    catch (Exception e)
    {
      e.printStackTrace(System.err);
    }

  }


  public static boolean updateAnnotation(long newstart, long newstop, String fbin, int fid, DBAgent db, String dbName, JspWriter out, Connection con) {
    boolean success = false;

    String sqlupdate = "update fdata2 " +
            " set fstart = ?, fstop = ?, fbin=?  where fid = ? ";

    try {
      if (con == null || con.isClosed())
        con = db.getConnection(dbName);
      if (con != null || !con.isClosed()) {
        PreparedStatement stms = con.prepareStatement(sqlupdate);
        stms.setLong(1, newstart);
        stms.setLong(2, newstop);
        stms.setString(3, fbin);
        stms.setInt(4, fid);
        stms.executeUpdate();
        stms.close();

      }
    }
    catch (SQLException e) {
      e.printStackTrace(System.err);
      success = false;
      db.reportError(e, "AnnotationEditorHelper.updateAnnotation");
    }
    success = true;
    return success;

  }


  public static ArrayList shiftGroupAnnotations(long dist, int direction, DBAgent db, AnnotationDetail[] annotations, String dbName, JspWriter out, Connection con) {

    ArrayList list = new ArrayList();
    try {

      for (int i = 0; i < annotations.length; i++) {
        int fid = annotations[i].getFid();

        String fbin = "";
        long newStart = 0;
        long newStop = 0;
        boolean success = false;

        if (direction == 3) {
          newStart = dist + annotations[i].getStart();
          newStop = dist + annotations[i].getStop();
          fbin = (Refseq.computeBin(newStart, newStop, 1000));
          success = updateAnnotation(newStart, newStop, fbin, fid, db, dbName, out, con);
          list.add("" + fid);

        }
        else if (direction == 5) {
          newStart = -dist + annotations[i].getStart();
          newStop = -dist + annotations[i].getStop();
          fbin = (Refseq.computeBin(newStart, newStop, 1000));
          success = updateAnnotation(newStart, newStop, fbin, fid, db, dbName, out, con);
          list.add("" + fid);

        }
      }

    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }
    return list;
  }


  public static String[] duplicateAnnotations(int newftypeid, AnnotationDetail[] annotations, String dbName, Connection con) {
    int newfid = 0;
    ArrayList list = new ArrayList();
    for (int i = 0; i < annotations.length; i++) {
      int oldfid = annotations[i].getFid();
      AnnotationDetail newanno = new AnnotationDetail(oldfid);
      newanno = copy(annotations[i], newanno);
      newanno.setFtypeId(newftypeid);
      newfid = insertAnnotation(newanno, dbName, con);

      if (newfid > 0) {

        duplicateAVP (oldfid, newfid,  con);
        duplicateAnnoText(newfid, oldfid, dbName, con);
        list.add("" + newfid);
      }
      else {
        newfid = isDupAnnotation(dbName, newanno, con);

        duplicateAVP (oldfid, newfid,  con);
        duplicateAnnoText(newfid, oldfid, dbName, con);
        list.add("" + newfid);
      }
    }

    String[] sids = null;
    if (list.size() > 0)
      sids = (String[]) list.toArray(new String[list.size()]);
    if (sids == null)
      sids = new String[0];

    return sids;
  }


  public static HashMap duplicateSelectedAnnotations(String newGName, AnnotationDetail[] annotations, String dbName, Connection con) {
    int newfid = 0;
    HashMap fid2newfid = new HashMap();
    for (int i = 0; i < annotations.length; i++) {
      int oldfid = annotations[i].getFid();
      AnnotationDetail newanno = new AnnotationDetail(oldfid);
      newanno = copy(annotations[i], newanno);
      newanno.setGname(newGName);
      newfid = insertAnnotation(newanno, dbName, con);

      if (newfid > 0) {
        duplicateAnnoText(newfid, oldfid, dbName, con);
        duplicateAVP (oldfid, newfid,  con);
        fid2newfid.put("" + oldfid, "" + newfid);
      }
      else {
        newfid = isDupAnnotation(dbName, newanno, con);
        duplicateAVP (oldfid, newfid,  con);
        duplicateAnnoText(newfid, oldfid, dbName, con);
        fid2newfid.put("" + oldfid, "" + newfid);
      }
    }
    return fid2newfid;
  }

  public static boolean duplicateAVP(int oldfid, int newfid,  Connection con) {
    boolean success = true;
    try {

      String sqlDel = "delete from fid2attribute where fid = ? ";
      PreparedStatement stms = con.prepareStatement(sqlDel);
      stms.setInt(1, newfid);
      stms.executeUpdate();
      String sqlSelect = "select attNameId, attValueId from fid2attribute where fid=? ";

      stms = con.prepareStatement(sqlSelect);
      stms.setInt(1, oldfid);
      ResultSet rs = stms.executeQuery();
      ArrayList list = new ArrayList();
      while (rs.next()) {
        int[] avp = new int[2];
        avp[0] = rs.getInt(1);
        avp[1] = rs.getInt(2);
        list.add(avp);
      }

      if (list.size() > 0) {
        String sqlInsert = "insert into fid2attribute (fid, attNameId, attValueId) values (?, ?, ?)";
        stms = con.prepareStatement(sqlInsert);
        stms.setInt(1, newfid);
        for (int i = 0; i < list.size(); i++) {
          int[] avp = (int[]) list.get(i);
          stms.setInt(2, avp[0]);
          stms.setInt(3, avp[1]);
          stms.executeUpdate();
        }
      }
      rs.close();
      stms.close();
    }
    catch (SQLException e) {
      success = false;
      e.printStackTrace(System.err);;
    }

    return success;
  }



  public static String[] duplicateAnnotations(String newGName, AnnotationDetail[] annotations, String dbName, Connection con) {
    int newfid = 0;
    ArrayList list = new ArrayList();
    for (int i = 0; i < annotations.length; i++) {
      int oldfid = annotations[i].getFid();
      AnnotationDetail newanno = new AnnotationDetail(oldfid);
      newanno = copy(annotations[i], newanno);
      newanno.setGname(newGName);
      newfid = insertAnnotation(newanno, dbName, con);
      if (newfid > 0) {
        duplicateAnnoText(newfid, oldfid, dbName, con);
        duplicateAVP (oldfid, newfid,   con);
        list.add("" + newfid);
      }
      else {
        newfid = isDupAnnotation(dbName, newanno, con);
        duplicateAnnoText(newfid, oldfid, dbName, con);
        duplicateAVP (oldfid, newfid,    con);
        list.add("" + newfid);
      }
    }

    String[] sids = null;
    if (list.size() > 0)
      sids = (String[]) list.toArray(new String[list.size()]);
    if (sids == null)
      sids = new String[0];

    return sids;
  }


  public static int duplicateAnnotation(String newGName, AnnotationDetail annotation, String dbName, Connection con) {
    boolean success = false;
    int oldfid = annotation.getFid();
    AnnotationDetail newanno = new AnnotationDetail(oldfid);
    newanno = copy(annotation, newanno);
    newanno.setGname(newGName);
    int newfid = insertAnnotation(newanno, dbName, con);

    if (newfid > 0) {
      duplicateAnnoText(newfid, oldfid, dbName, con);
      duplicateAVP (oldfid, newfid,  con);
      success = true;
    }

    return newfid;
  }


  public static int duplicateAnnotation(boolean useAVP, int oldftypeid, int newftypeid,
                                        AnnotationDetail annotation, String dbName, Connection con)
  {
    String ftypeIds = "" + oldftypeid;
    ftypeIds += ", " + newftypeid;
    boolean success = false;
    int oldfid = annotation.getFid();

    AnnotationDetail newanno = new AnnotationDetail(oldfid);
    newanno = copy(annotation, newanno);
    newanno.setFtypeId(newftypeid);
    int newfid = insertAnnotation(newanno, dbName, con);
    if (newfid > 0) {
      duplicateAnnoText(newfid, oldfid, dbName, con);
      if (useAVP)
        duplicateAVP (oldfid, newfid, con);
      success = true;
    }
    AnnotationCounter.updateCountTableUsingTrackIds( con, ftypeIds );
    return newfid;
  }

  public static int duplicateAnnotation(int ftypeid, AnnotationDetail annotation, String dbName, Connection con)
  {
    String ftypeIds =   "" + ftypeid ;

    boolean success = false;
    int oldfid = annotation.getFid();

    ftypeIds += ", " + GenboreeUtils.getFtypeIdsFromFids( con,  "" + oldfid );
    AnnotationDetail newanno = new AnnotationDetail(oldfid);
    newanno = copy(annotation, newanno);
    newanno.setFtypeId(ftypeid);
    int newfid = insertAnnotation(newanno, dbName, con);
    if (newfid > 0) {
      duplicateAnnoText(newfid, oldfid, dbName, con);
      duplicateAVP (oldfid, newfid, con);
      success = true;
    }
    AnnotationCounter.updateCountTableUsingTrackIds( con, ftypeIds );
    return newfid;
  }


  public static boolean duplicateAnnoText(int newfid, int oldfid, String dbName, Connection con) {
    boolean success = false;

    PreparedStatement stms = null;
    DBAgent db =  DBAgent.getInstance();


    class DBText {

      String textType;
      String text;
      int ftypeid;
    }


    String sqlSelect = "select textType, text, ftypeid  from  fidText where fid = " + oldfid;
    String sqlInsert = "insert ignore into  fidText (fid, textType, text, ftypeid)  " +
            "  values (?, ?, ?, ?) ";
    String sqlDelete = "delete from fidText where fid = ? ";

    try {
      if (con == null || con.isClosed())
        con = db.getConnection(dbName);
      PreparedStatement stmsdel = con.prepareStatement(sqlDelete);
      stmsdel.setInt(1, newfid);

      stmsdel.executeUpdate();
      stmsdel.close();

      stms = con.prepareStatement(sqlSelect);

      ResultSet rs = stms.executeQuery();
      ArrayList list = new ArrayList();
      while (rs.next()) {
        DBText dbtext = new DBText();
        dbtext.textType = rs.getString(1);
        dbtext.text = rs.getString(2);
        dbtext.ftypeid = rs.getInt(3);
        list.add(dbtext);
      }

      if (!list.isEmpty()) {
        DBText[] texts = (DBText[]) list.toArray(new DBText[list.size()]);
        stms = con.prepareStatement(sqlInsert);
        for (int i = 0; i < texts.length; i++) {
          stms.setInt(1, newfid);
          stms.setString(2, texts[i].textType);
          stms.setString(3, texts[i].text);
          stms.setInt(4, texts[i].ftypeid);
          stms.executeUpdate();

        }
      }

      rs.close();
      stms.close();

      success = true;

    }
    catch (Exception e) {
      System.err.println("sql error from AnnotatonEditoHelper.duplicateAnnoText ");
      e.printStackTrace(System.err);
    }

    return success;
  }


  /**
   * update database with information from web page The following four tables maybe updated updated: 1. fdata2 2.
   * fidText
   *
   * @param annotation object of annotation details
   */


  public static int insertAnnotation(AnnotationDetail annotation, String dbName, Connection con)
  {
    String s = null;
    if ((s = annotation.getComments()) != null)
      annotation.setComments(s.replaceAll("'", "\'"));

    final int RID = 1;
    final int FSTART = 2;
    final int FSTOP = 3;
    final int FBIN = 4;
    final int FTYPEID = 5;
    final int FSCORE = 6;
    final int FSTRAND = 7;
    final int PHASE = 8;
    final int TARGET_START = 9;
    final int TARGET_STOP = 10;
    final int GNAME = 11;
    final int FID = 12;

    int newfid = 0;

    String sqlupdate = "insert ignore into fdata2 (rid, fstart, fstop, fbin, ftypeid, fscore, fstrand, fphase, " +
            " ftarget_start, ftarget_stop, gname, displayCode, displayColor ) " +
            " values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )";

    try {
      if (con == null || con.isClosed())
        con =  DBAgent.getInstance().getConnection(dbName);

      PreparedStatement stms = con.prepareStatement(sqlupdate);
      stms.setInt(RID, annotation.getRid());
      stms.setLong(FSTART, annotation.getStart());
      stms.setLong(FSTOP, annotation.getStop());
      stms.setString(FBIN, annotation.getFbin());
      stms.setInt(FTYPEID, annotation.getFtypeId());
      stms.setString(FSCORE, annotation.getFscore());
      stms.setString(FSTRAND, annotation.getStrand());
      stms.setString(PHASE, annotation.getPhase());
      stms.setString(TARGET_START, annotation.getTstart());
      stms.setString(TARGET_STOP, annotation.getTstop());
      stms.setString(GNAME, annotation.getGname());
      if (annotation.getDisplayCode() <= 0) {
        stms.setString(12, null);
      }
      else {
        stms.setInt(12, annotation.getDisplayCode());
      }


      if (annotation.getDisplayColor() <= 0) {
        stms.setString(13, null);
      }
      else {
        stms.setInt(13, annotation.getDisplayColor());
      }
// stms.setInt(14, annotation.getFlag());
      stms.executeUpdate();

      String selectId = "select last_insert_id()";
      stms = con.prepareStatement(selectId);
      ResultSet rs = stms.executeQuery();

      if (rs.next()) {
        newfid = rs.getInt(1);
      }
      rs.close();
      stms.close();

    }
    catch (SQLException e) {

      e.printStackTrace(System.err);

    }


    AnnotationCounter.updateCountTableUsingFids( con, "" + newfid );

    return newfid;

  }

  public static boolean compareAnnos(AnnotationDetail anno1, AnnotationDetail anno2) {

    if (anno1.getFtypeId() != anno2.getFtypeId()) {
      return false;
    }
    if (anno1.getRid() != anno2.getRid()) {
      return false;
    }

    if (anno1.getStart() != anno2.getStart()) {
      return false;
    }

    if (anno1.getStop() != anno2.getStop()) {
      return false;
    }

    String gname1 = anno1.getGname();
    String gname2 = anno2.getGname();

    if (gname1 != null && gname2 != null) {
      if (gname1.compareTo(gname2) != 0) {

        return false;
      }
    }

    String strand1 = anno1.getStrand();
    String strand2 = anno2.getStrand();
    if (strand1.compareTo(strand2) != 0) {

      return false;
    }

    String phase1 = anno1.getPhase();
    String phase2 = anno2.getPhase();

    if (phase1.compareTo(phase2) != 0) {

      return false;
    }

    if (anno1.getScore() != anno2.getScore()) {

      return false;
    }

    String fbin1 = anno1.getFbin();
    String fbin2 = anno2.getFbin();

    if (fbin1.compareTo(fbin2) != 0) {

      return false;
    }


    return true;

  }


  /**
   * duplication means:  a. identical in fdata2 b. identical in fidText w/o white space
   *
   * @param dbName
   * @param annotation : annotation from web  with comments and Sequence information
   * @return
   */

  public static boolean isDupAnno(String dbName, AnnotationDetail annotation, Connection con) {
    return isDupAnnotation(dbName, annotation, con) > 0 ? true : false;
  }


  /**
   * duplication means:  a. identical in fdata2 b. identical in fidText w/o white space
   *
   * @param dbName
   * @param annotation : annotation from web  with comments and Sequence information
   * @return
   */

  public static int isDupAnnotation(String dbName, AnnotationDetail annotation, Connection con)
  {
    return isDupAnnotationData(dbName, annotation, con);
  }


  /**
   * duplication means:  a. identical in fdata2 b. identical in fidText w/o white space
   *
   * @param dbName
   * @param annotation : annotation from web  with comments and Sequence information
   * @return
   */

  public static int isDupAnnotationData(String dbName, AnnotationDetail annotation, Connection con)
  {
    double delta = 1e-300 ;
    int fid = -1;
    String newPhase;
    String newFstrand;
    double localFscore = Util.parseDouble(annotation.getFscore() , 0.00 );
    double fscoreStart =  localFscore - delta;
    double fscoreEnd = localFscore + delta;
    String fphase = annotation.getPhase();
    String fstrand = annotation.getStrand();
    String sqlSel = "SELECT fid FROM fdata2" +
           " WHERE rid = ? AND fstart = ? AND fstop = ? AND fbin = ?" +
           " AND ftypeid = ? " +
           " AND fscore between ? AND ? AND fstrand = ?" +
           " AND ( fphase = ? OR fphase = ?) AND gname = ?";


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



String debug    = " SELECT  fid FROM fdata2" +
" WHERE rid=" + annotation.getRid() + "  AND  fstart = " + annotation.getStart() + " AND  fstop = " + annotation.getStop() +
" AND  fbin= '" + annotation.getFbin () + "' AND ftypeid =  " +  annotation.getFtypeId() +
" AND  fscore BETWEEN " + fscoreStart + " AND " +  fscoreEnd   + " AND  fstrand = '" + newFstrand +
"' AND ( fphase ='"  +newPhase +  "' OR fphase = '') " +
" AND  gname = '" + annotation.getGname() + "'";
//System.err.println( "the query to find the fid in db " + dbName + " is \n" + debug );

    try {
      if (con == null || con.isClosed())
        con =  DBAgent.getInstance().getConnection(dbName);

      PreparedStatement stms = con.prepareStatement(sqlSel);
      stms.setInt(1, annotation.getRid());
      stms.setLong(2, annotation.getStart());
      stms.setLong(3, annotation.getStop());
      stms.setString(4, annotation.getFbin());
      stms.setInt(5, annotation.getFtypeId());
      stms.setDouble( 6, fscoreStart);
      stms.setDouble( 7, fscoreEnd);
      stms.setString( 8, newFstrand);
      stms.setString( 9, newPhase);
      stms.setString( 10, " ");
      stms.setString(11, annotation.getGname());
      ResultSet rs = stms.executeQuery();
      if (rs.next()) {
        fid = rs.getInt(1);

      }

      rs.close();
      stms.close();


    }
    catch (SQLException e) {
      e.printStackTrace(System.err);
    }
    return fid;
  }


  /**
   * duplication means:  a. identical in fdata2 b. identical in fidText w/o white space
   *
   * @param dbName
   * @param annotation : annotation from web  with comments and Sequence information
   * @return
   */

  public static boolean isDupText(String dbName, int fid, AnnotationDetail annotation, Connection con) {
    boolean isDup = false;
    String sql = " select textType, text  from fidText " +
            " where fid = ? ";
    String comments = annotation.getComments();
    String seq = annotation.getSequences();
    if (comments != null)
      comments = comments.trim();
    if (seq != null)
      seq = seq.trim();

    try {
      if (con == null)
        con =  DBAgent.getInstance().getConnection(dbName);
      PreparedStatement stms = con.prepareStatement(sql);
      stms.setInt(1, fid);

      ResultSet rs = stms.executeQuery();
      boolean commentSame = false;
      boolean seqSame = false;

      while (rs.next()) {
        String type = rs.getString(1);
        String text = rs.getString(2);

        if (comments != null)
          if (type != null && type.compareTo("t") == 0 && text != null && text.compareTo(comments) == 0) {

            commentSame = true;

          }
        if (seq != null)
          if (type != null && type.compareTo("s") == 0 && text != null && text.compareTo(seq) == 0) {
            seqSame = true;
          }

      }


      if (commentSame && seqSame)
        isDup = true;
      rs.close();
      stms.close();


    }
    catch (SQLException e) {
      e.printStackTrace(System.err);
    }

    return isDup;
  }


  /**
   * retrives avaliable track name and id from database
   *
   * @param db DBAgent
   * @return trackMap  HashMap of track name:id pair from table ftype
   */

  public static HashMap findTracks( DBAgent db, Connection con, int genboreeUserId, String databaseName )
  {
    String fmethod = null;
    String fsource = null;
    String id = null;
    HashMap trackMap = null;
    String sql = " SELECT fmethod, fsource, ftypeid FROM ftype order by fmethod ";

    try
    {
      trackMap = new HashMap();
      if( con == null || con.isClosed() )
        throw new SQLException( "No connection made" );

      PreparedStatement stms = con.prepareStatement( sql );


      ResultSet rs = stms.executeQuery();

      while( rs.next() )
      {
        fmethod = rs.getString( 1 );
        fsource = rs.getString( 2 );
        id = rs.getString( 3 );
        if( fmethod != null )
          fmethod = fmethod.trim();

        if( fsource != null )
          fsource = fsource.trim();

        if( ( fmethod.compareToIgnoreCase( "Component" ) == 0 && fsource.compareToIgnoreCase( "Chromosome" ) == 0 ) ||
                ( fmethod.compareToIgnoreCase( "supercomponent" ) == 0 && fsource.compareToIgnoreCase( "sequence" ) == 0 ) )
          continue;

        if( TrackPermission.isTrackAllowed( databaseName, fmethod, fsource, genboreeUserId ) )
          trackMap.put( fmethod + ":" + fsource, id );
      }
      rs.close();
      stms.close();
    }
    catch( Exception e )
    {
      System.err.println("Exception on AnnotationEditorHelper#findTracks");
      e.printStackTrace( System.err );
    }
    finally
    {
      return trackMap;
    }
  }

  /**
   * @param annotation
   * @param db
   * @param con
   * @param fid
   * @return
   */
  public static AnnotationDetail findAnnotation(AnnotationDetail annotation, DBAgent db, Connection con, String fid)
  {
    String queryFdata2 = "SELECT fd.fstart, fd.fstop, fd.fscore, fd.fphase, " +
            " fd.fstrand, fd.gname, ft.fmethod, ft.fsource, " +
            " ft.ftypeid, fr.refname, " +
            " fd.ftarget_start, fd.ftarget_stop, fd.fbin, " +
            " fd.rid,   fd.displayCode, fd.displayColor, fd.groupContextCode  FROM " +
            " fdata2 fd, ftype ft, fref fr WHERE fd.ftypeid=ft.ftypeid AND " +
            " fd.rid = fr.rid AND fd.fid=  " + fid;

    try {
      if (con == null || con.isClosed())
      {
        System.err.println("Connection is close on AnnotationEditorHelper#findAnnotation why??");
        return null;
      }
      
      PreparedStatement stms = con.prepareStatement(queryFdata2);
      ResultSet rs = stms.executeQuery();
      if (rs != null && rs.next())
      {
        annotation.setStart(rs.getLong(1));
        annotation.setStop(rs.getLong(2));
        annotation.setFstart(rs.getString(1));
        annotation.setFstop(rs.getString(2));
        annotation.setScore(rs.getDouble(3));
        annotation.setFscore(rs.getString(3));

        annotation.setPhase(rs.getString(4));


        annotation.setStrand(rs.getString(5));
        if (rs.getString("gname") != null)
          annotation.setGname(rs.getString(6));
        if (rs.getString("fmethod") != null)
          annotation.setFmethod(rs.getString(7));
        if (rs.getString("fsource") != null)
          annotation.setFsource(rs.getString(8));


        annotation.setFtypeId(rs.getInt(9));
        annotation.setChromosome(rs.getString(10));
        if (rs.getString("ftarget_start") != null) {
          annotation.setTstart(rs.getString(11));
          annotation.setTargetStart(rs.getLong(11));
        }
        if (rs.getString("ftarget_stop") != null) {
          annotation.setTstop(rs.getString(12));
          annotation.setTargetStop(rs.getLong(12));
        }
        annotation.setFbin(rs.getString(13));
        annotation.setRid(rs.getInt(14));


        if (rs.getString(15) != null)
          annotation.setDisplayCode(rs.getInt(15));
        else
          annotation.setDisplayCode(-1);


        if (rs.getString(16) != null)
          annotation.setDisplayColor(rs.getInt(16));
        else
          annotation.setDisplayColor(-1);


        if (annotation.getDisplayColor() >= 0) {
          int temp = annotation.getDisplayColor();
          String hexS = Integer.toHexString(temp);
          annotation.setHexAnnoColor(hexS);
        }


        annotation.setGroupContextCode(rs.getString(17));


        if (rs.getString("fmethod") != null && rs.getString("fsource") != null)
          annotation.setTrackName(annotation.getFmethod() + ":" + annotation.getFsource());

      }

      byte[] b = new byte[70];
      String aSeq = "";
      String sql = "SELECT textType, text FROM fidText WHERE fid=" + fid;
      stms = con.prepareStatement(sql);
      rs = stms.executeQuery();

      while (rs != null && rs.next()) {
        String tt = rs.getString(1);
        if (tt != null && tt.compareToIgnoreCase("t") == 0) {
          annotation.setComments(rs.getString(2));
        }
        else {
          InputStream bIn = rs.getAsciiStream(2);
          int n = bIn.read(b);
          while (n > 0) {
            if (aSeq == null) aSeq = "";
            aSeq = aSeq + (new String(b, 0, n));
            n = bIn.read(b);
          }
          annotation.setSequences(aSeq);
        }
      }
// no comments or sequence in database
      if (annotation.getComments() == null)
        annotation.setComments("");
      if (annotation.getSequences() == null)
        annotation.setSequences("");

    }
    catch (Exception e) {
      e.printStackTrace(System.err);
      System.err.println("AnnotationEditorHelper.findAnnotations()");
    }
    return annotation;
  }


  public static long findChromosomeLength(Connection con, DBAgent db, String dbName, int rid) {
    long length = 0;
    try {
      String sql = "select  rlength from fref where rid = " + rid;
      if (con == null || con.isClosed())
        con = db.getConnection(dbName);
      PreparedStatement stms = con.prepareStatement(sql);
      ResultSet rs = stms.executeQuery();
      if (rs.next())
        length = rs.getLong(1);
      rs.close();
      stms.close();
    }
    catch (SQLException e) {
      e.printStackTrace(System.err);
    }

    return length;
  }


  /**
   * retrieves information from database and store obtained information in Chromosome objects
   *
   * @param db
   * @return chromosomes HashMap of refname:Chromosome pairs
   */

  public static HashMap findChromosomes(DBAgent db, Connection con) throws SQLException {
    String sql = "select distinct refname, rid, rlength from fref order by refname";
    HashMap chromosomes = new HashMap();
    int REFNAME = 1;
    int RID = 2;
    int RLENGTH = 3;
    try {
      if (con == null || con.isClosed())
        throw new SQLException("connection not made");

      PreparedStatement stms = con.prepareStatement(sql);
      ResultSet rs = stms.executeQuery();
      int count = 0;
      while (rs.next()) {
        count ++;
        if (count >org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST )
          break;
        String chr = rs.getString(REFNAME);
        if (chr == null)
          continue;

        Chromosome chromosome = new Chromosome(chr);
        chromosome.id = rs.getInt(RID);
        chromosome.length = rs.getLong(RLENGTH);
        chromosomes.put(chr, chromosome);
      }
      rs.close();
      stms.close();
    }
    catch (SQLException e) {
      e.printStackTrace(System.err);
      db.reportError(e, "AnnotationEditorHelper.findChromosomes()");
      throw e;
    }

    return chromosomes;
  }


  /**
   * validate annotation name -- length <= 200 chars -- no tab or new line characters -- does this allows blank name
   *
   * @param annotation annotation detail
   * @param request    httpservletrequest
   * @param errorField hashmap or error fields
   * @param vLog       vector of error messag
   * @return true if all right; false if 1. gname length>=200 2.gname contains tab or newline characters gname is null
   *         or length = 0
   */

  public static int validateGname(AnnotationDetail annotation, HttpServletRequest request, HashMap errorField, Vector vLog, JspWriter out) {
    String gname = null;
    int numErr = 0;
    if ((gname = request.getParameter("gname")) != null) {
      gname = gname.trim();
      gname = gname.replaceAll("\t", " ");
      gname = gname.replaceAll("\r", " ");
      gname = gname.replaceAll("\n", " ");
      gname = gname.replaceAll("\f", " ");


      annotation.setGname(gname);

// check length
      if (gname.length() > 200) {
        errorField.put("gname", gname);
        vLog.add("Annotation name exceeded maximum length of 200. ");
        numErr++;
      }

// check db empty String
      if (gname == null || gname.length() == 0) {
        gname = "";
        errorField.put("gname", gname);
        vLog.add("Annotation name is empty. Please enter an annotation name and try again. ");
        numErr++;
      }
    }
    else {
      annotation.setGname("");
      errorField.put("gname", gname);
      vLog.add("Annotation name is empty. Please enter an annotation name and try again. ");
      numErr++;
    }

    return numErr;
  }


  /**
   * Retrieves chromosome information from jsp page update annotation object for rid if chromosome are changed
   *
   * @param annotation
   * @param request
   * @param errorField
   * @param vLog
   * @param chromosomes
   * @return true if included, false if not in db
   */
  public static int validateChromosome(AnnotationDetail annotation, HttpServletRequest request, HashMap errorField, Vector vLog, HashMap chromosomes) {
    int numErrs = 0;
    String chromosome = null;
    int rid = -1;

    if ((chromosome = request.getParameter("chromosomes")) != null) {
      chromosome = chromosome.trim();

// first, check if chromosome is changed
      if (chromosome.compareToIgnoreCase(annotation.getChromosome()) != 0) {
// find new chromosome id and update annotation
        rid = ((Chromosome) chromosomes.get(chromosome)).id;
        annotation.setRid(rid);
      }

      annotation.setChromosome(chromosome);

      if (!chromosomes.keySet().contains(chromosome)) {
        annotation.setRid(-1);
        errorField.put("chromosome", chromosome);
        vLog.add("\"" + chromosome + "\" is an invalid chromosome name.");
        numErrs++;
      }

    }
    else {
      annotation.setChromosome("");
      errorField.put("chromosome", chromosome);
      vLog.add("Chromosome name can not be empty. ");
      numErrs++;
    }
    return numErrs;
  }


  /**
   * validates entry point start and end of the annotation entry points start and end should be number, non-negrative,
   * and the mlength should not exceed chromosome length start can not be greater than stop
   *
   * @param annotation AnnotationDetail object containing initial information from database
   * @param request    used for obtaining input information
   * @param errorField HashMap of fields and error messages
   * @param vLog       Vector of error messages to be displayed
   * @param out
   * @return true if succedds, false else
   */


  public static int validateStartStop(AnnotationDetail annotation, long chromosomeLength, HttpServletRequest request, HashMap errorField, Vector vLog, JspWriter out) {
    int numErrs = 0;
    String fstart = null;
    String fstop = null;
    long istart = 0;
    long istop = 0;
    long lastStart = annotation.getStart();
    long lastStop = annotation.getStop();
    boolean startErr = false;
    boolean stopErr = false;

    if ((fstart = request.getParameter("startValue")) != null) {
      annotation.setFstart(fstart);

      fstart = fstart.trim();
      fstart = fstart.replaceAll(",", "");
      fstart = fstart.replaceAll(" ", "");


      try {
        istart = Long.parseLong(fstart);
        annotation.setStart(istart);
        annotation.setFstart(fstart);

      }
      catch (Exception e) {
        startErr = true;
        vLog.add("Start must be an integer greater or equals to 1.");
        errorField.put("start", fstart);
        numErrs++;
      }
    }

    if ((fstop = request.getParameter("stopValue")) != null) {
      annotation.setFstop(fstop);
      try {

        fstop = fstop.trim();
        fstop = fstop.replaceAll(",", "");
        fstop = fstop.replaceAll(" ", "");
        istop = Long.parseLong(fstop);
        annotation.setFstop(fstop);


        annotation.setStop(istop);
      }
      catch (Exception e) {
        stopErr = true;
        vLog.add("Stop must be an integer greater or equals to 1.");
        errorField.put("stop", fstop);
        numErrs++;
      }
    }


    if (!startErr && !stopErr && (istart > istop)) {
      vLog.add("Start must be less than or equal to stop.");
      errorField.put("start", fstart);
      errorField.put("stop", fstop);
      numErrs++;
    }

    if (!startErr && istart <= 0) {
      vLog.add("Start must be an integer greater or equals to 1.");
      errorField.put("start", fstop);
      numErrs++;
    }

    if (!stopErr && istop <= 0) {
      vLog.add("Stop must be an integer greater or equals to 1.");
      errorField.put("stop", fstop);
      numErrs++;
    }

    if (!stopErr && (istop > chromosomeLength)) {
      vLog.add("Annotation stop " + istop + " exceededed chromosome length (" + chromosomeLength + ").");
// errorField.put("start", fstart);
      errorField.put("stop", fstop);
      numErrs++;
    }

    if (!startErr && (istart > chromosomeLength)) {
      vLog.add("Annotation start " + istart + " exceededed chromosome length (" + chromosomeLength + ").");
// errorField.put("start", fstart);
      errorField.put("start", fstart);
      numErrs++;
    }


    if (!startErr && !startErr && (istart != lastStart || istop != lastStop)) {
      String fbin = (Refseq.computeBin(istart, istop, 1000));
      annotation.setFbin(fbin);
    }

    return numErrs;
  }


  /**
   * validates entry point start and end of the annotation entry points start and end should be number, non-negrative,
   * and the mlength should not exceed chromosome length start can not be greater than stop
   *
   * @param errorField HashMap of fields and error messages
   * @param vLog       Vector of error messages to be displayed
   * @param out
   * @return true if succedds, false else
   */


  public static boolean validateStartStop(long istart, long istop, long chromosomeLength, HashMap errorField, Vector vLog, JspWriter out) {
    boolean success = false;
    int numErrs = 0;

    if (istart > istop) {
      vLog.add("Start must be less than or equal to stop.");
      errorField.put("start", "start must be less than or equal to stop.");
      errorField.put("stop", "start must be less than or equal to stop.");
      numErrs++;
    }

    if (istart <= 0) {
      vLog.add("Start must be an integer greater or equals to 1.");
      errorField.put("start", "start must be an integer greater or equals to 1.");

    }

    if (istop <= 0) {
      vLog.add("Stop must be an integer greater or equals to 1.");
      errorField.put("stop", "" + "stop must be an integer greater or equals to 1.");
      numErrs++;
    }

    if (istop > chromosomeLength) {
      vLog.add("Annotation stop " + istop + " exceededed chromosome length (" + chromosomeLength + ").");
// errorField.put("start", fstart);
      errorField.put("stop", "Annotation stop " + istop + " exceededed chromosome length (" + chromosomeLength + ").");
      numErrs++;
    }

    if (istart > chromosomeLength) {
      vLog.add("Annotation start " + istart + " exceededed chromosome length (" + chromosomeLength + ").");
// errorField.put("start", fstart);
      errorField.put("start", "" + "Annotation start " + istart + " exceededed chromosome length (" + chromosomeLength + ").");
      numErrs++;
    }

    if (numErrs == 0)
      success = true;

    return success;
  }


  /**
   * validates entry point start and end of the annotation entry points start and end should be number, non-negrative,
   * and the mlength should not exceed chromosome length start can not be greater than stop
   *
   * @param errorField HashMap of fields and error messages
   * @param vLog       Vector of error messages to be displayed
   * @param out
   * @return true if succedds, false else
   */


  public static boolean validateShiftAnnotations(String distance, String direction, AnnotationDetail[] annotations, long chromosomeLength, HashMap errorField, Vector vLog, JspWriter out) {
    boolean success = false;
    int numErrs = 0;
    long istart = 0;
    long istop = 0;
    long idistance = 0;

    if (direction == null || (direction.compareTo("3") != 0 && direction.compareTo("5") != 0)) {
      vLog.add("Please select a direction for this annotation.");
      errorField.put("direction", "Please select a direction for this annotation.");
      numErrs++;

    }


    if (distance != null) {
      distance = distance.trim();
      distance = distance.replaceAll(",", "");
      distance = distance.replaceAll(" ", "");
      if (distance.length() == 0 || distance.compareTo("") == 0) {
        vLog.add("Distance must be an integer greater than or equals to 1.");
        errorField.put("distance", distance);
        numErrs++;
      }
      else {

        try {
          idistance = Long.parseLong(distance);
        }
        catch (Exception e) {
          vLog.add("Distance must be an integer greater than or equals to 1.");
          errorField.put("distance", distance);
          numErrs++;
        }

        if (idistance < 1 && errorField.get("distance") == null) {
          vLog.add("Distance must be an integer greater than or equals to 1.");
          errorField.put("distance", distance);
          numErrs++;
        }
      }
    }
    else {
      vLog.add("Distance must be an integer greater than or equals to 1.");
      errorField.put("disatance", distance);
      numErrs++;
      success = false;
    }

    long maxStop = 0;
    long minStart = 2147483647;

    for (int i = 0; i < annotations.length; i++) {
      if (annotations[i].getStart() < minStart)
        minStart = annotations[i].getStart();

      if (annotations[i].getStop() > maxStop)
        maxStop = annotations[i].getStop();
    }


    if (numErrs == 0) {
      if (direction.compareTo("3") == 0) {
        if ((idistance + maxStop) > chromosomeLength) {
          vLog.add("Stop will exceed chromosome length after shift.");
          errorField.put("disatance", "Stop will exceed chromosome length after shift.");
          numErrs++;
        }

      }
      else if (direction.compareTo("5") == 0) {
        if ((-idistance + minStart) < 1) {
          vLog.add("Start will be 0 or negative after shift.");
          errorField.put("disatance", "Start will be 0 or negative after shift.");
          numErrs++;

        }
      }
    }
    if (numErrs == 0)
      success = true;

    return success;
  }


  /**
   * validates entry point start and end of the annotation entry points start and end should be number, non-negrative,
   * and the mlength should not exceed chromosome length start can not be greater than stop
   *
   * @param errorField HashMap of fields and error messages
   * @param vLog       Vector of error messages to be displayed
   * @param out
   * @return true if succedds, false else
   */


  public static boolean validateShift(String distance, String fstart, String fstop, long chromosomeLength, String direction, HashMap errorField, Vector vLog, JspWriter out) {
    boolean success = false;
    int numErrs = 0;
    long istart = 0;
    long istop = 0;
    long idistance = 0;

    if (direction == null || (direction.compareTo("3") != 0 && direction.compareTo("5") != 0)) {
      vLog.add("Please select a direction for this annotation.");
      errorField.put("direction", "Please select a direction for this annotation.");
      numErrs++;

    }


    if (distance != null) {
      distance = distance.trim();
      distance = distance.replaceAll(",", "");
      distance = distance.replaceAll(" ", "");
      if (distance.length() == 0 || distance.compareTo("") == 0) {
        vLog.add("Distance must be an integer greater than or equals to 1.");
        errorField.put("distance", distance);
        numErrs++;
      }
      else {

        try {
          idistance = Long.parseLong(distance);
        }
        catch (Exception e) {
          vLog.add("Distance must be an integer greater than or equals to 1.");
          errorField.put("distance", distance);
          numErrs++;
        }

        if (idistance < 1 && errorField.get("distance") == null) {
          vLog.add("Distance must be an integer greater than or equals to 1.");
          errorField.put("distance", distance);
          numErrs++;
        }
      }
    }
    else {
      vLog.add("Distance must be an integer greater than or equals to 1.");
      errorField.put("disatance", distance);
      numErrs++;
      success = false;
    }


    if (fstart != null) {
      fstart = fstart.trim();
      fstart = fstart.replaceAll(",", "");
      fstart = fstart.replaceAll(" ", "");

      try {
        istart = Long.parseLong(fstart);
      }
      catch (Exception e) {
        vLog.add("Start must be an integer greater than or equals to 1.");
        errorField.put("start", fstart);
        numErrs++;
      }
    }

    if (fstop != null) {
      try {
        fstop = fstop.trim();
        fstop = fstop.replaceAll(",", "");
        fstop = fstop.replaceAll(" ", "");
        istop = Long.parseLong(fstop);
      }
      catch (Exception e) {
        vLog.add("Stop must be an integer greater than or equals to 1.");
        errorField.put("stop", fstop);
        numErrs++;
      }
    }

    if (numErrs == 0) {
      if (direction.compareTo("3") == 0) {
        if ((idistance + istop) > chromosomeLength) {
          vLog.add("Stop will exceed chromosome length after shift.");
          errorField.put("disatance", distance);
          numErrs++;
        }

      }
      else if (direction.compareTo("5") == 0) {
        if ((-idistance + istart) < 1) {
          vLog.add("Start will be 0 or negative after shift.");
          errorField.put("disatance", distance);
          numErrs++;

        }
      }
    }

    if (numErrs == 0) {
      return validateStartStop(istart, istop, chromosomeLength, errorField, vLog, out);
    }


    return success;
  }


  public static int validateStrand(AnnotationDetail annotation, HttpServletRequest request, HashMap errorField, Vector vLog) {
    String strand = null;
    int numErrs = 0;
    if ((strand = request.getParameter("strand")) != null) {
      strand = strand.trim();
      annotation.setStrand(strand);
      if (strand.compareTo("+") != 0 && strand.compareTo("-") != 0) {
        errorField.put("strand", strand);
        vLog.add("\"" + strand + "\" is an invalid.\nPlease use \"+\" or \"-\" for strand selection.");
        numErrs++;
      }
    }
    else {
      annotation.setStrand("");
//errorField.put("strand", strand);
//vLog.add("strand can not be empty. Please select a valid strand. ");
//numErrs++;
    }

    return numErrs;
  }

  /**
   * @param annotation
   * @param request
   * @param errorField
   * @param vLog
   * @return
   */

  public static int validatePhase(AnnotationDetail annotation, HttpServletRequest request, HashMap errorField, Vector vLog) {
    String phase = null;
    int numErrs = 0;
    if ((phase = request.getParameter("phase")) != null) {
      phase = phase.trim();
      annotation.setPhase(phase);
      if (phase.compareTo(".") != 0 && phase.compareTo("0") != 0 && phase.compareTo("1") != 0 && phase.compareTo("2") != 0) {
        errorField.put("phase", phase);
        vLog.add("\"" + phase + "\" is an invalid choice. \nPlease use \".\" or \"0\" or \"1\" or \"2" +
                " for phase values.");
        numErrs++;
      }
    }
    else {
      annotation.setStrand("");
//errorField.put("phase", phase);
//vLog.add("strand can not be empty. Please select a valid phase and try again. ");
//numErrs++;
    }
    return numErrs;
  }

  /**
   * validate user input of track name against available track names from database. if tracks are changed by user,
   * update annotation object for ftypeid
   *
   * @param trackMap
   * @param annotation
   * @param request
   * @param errorField
   * @param vLog
   * @return
   */


  public static int validateTracks(boolean insertNew, String trackName, String type, String subtype, String dbName, HttpSession mys, HashMap trackMap, AnnotationDetail annotation, HttpServletRequest request, HashMap errorField, Vector vLog, JspWriter out, Connection con) {
    int numErrs = 0;
    int ftypeid = 0;
    String oldName = null;
    if (annotation != null)
      oldName = annotation.getTrackName();
    if (trackName != null)
      trackName = trackName.trim();
    try {

      if (trackName != null) {
        if (trackName.indexOf("New Track") >= 0) {
          String newTrackName = null;
          if (type != null)
            type = type.trim();

          if (subtype != null)
            subtype = subtype.trim();


          if ((type == null || type.compareTo("") == 0) && (subtype == null || subtype.compareTo("") == 0)) {
            errorField.put("newTrackRow", trackName);
            vLog.add("Type and subtype name can not be empty.");
            return 1;

          }

          if ((type != null && type.compareTo("") != 0) && (subtype == null || subtype.compareTo("") == 0)) {
            errorField.put("newTrackRow", trackName);
            vLog.add("Subtype name can not be empty.");
            return 1;
          }

          if ((type == null || type.compareTo("") == 0) && (subtype != null && subtype.compareTo("") != 0)) {

            errorField.put("newTrackRow", trackName);
            vLog.add("Type name can not be empty.");
            return 1;
          }


          if (type.indexOf(":") >= 0) {
            errorField.put("newTrackRow", trackName);
            vLog.add("Type name can not contains \":\" .");
            return 1;

          }

          if (subtype.indexOf(":") >= 0) {
            errorField.put("newTrackRow", trackName);
            vLog.add("Subtype name can not contains \":\" .");
            return 1;
          }


          newTrackName = type + ":" + subtype;
          newTrackName = newTrackName.trim();

          if (trackMap.get(newTrackName) == null) {
// insert new ftype
            if (insertNew) {
              int id = insertFtype(type, subtype, dbName, con);
// update Tracks
              int oldid = annotation.getFtypeId();
              updateClassMaping(id, oldid, dbName, out, con);
              setTrackColor(id, oldid, dbName, out, con);
              annotation.setFtypeId(id);
              annotation.setTrackName(type + ":" + subtype);
              trackMap.put(type + ":" + subtype, "" + id);
            }
            else {
              trackMap.put(type + ":" + subtype, "" + annotation.getFtypeId());
            }
            annotation.setType(type);
            annotation.setSubType(subtype);
            return 0;
          }
          else {
            errorField.put("newTrackRow", trackName);
            vLog.add("Track name " + type + ":" + subtype + " already exist in database.");
            mys.setAttribute("duptype", type);
            mys.setAttribute("dupsubtype", type);
            return 1;
          }
        }

        else {
          type = trackName.substring(0, trackName.indexOf(":"));
          subtype = trackName.substring(trackName.indexOf(":") + 1);
          if (type != null)
            type = type.trim();
          if (subtype != null)
            subtype = subtype.trim();

          if ((type == null || type == "") && (subtype == null || subtype == "")) {
            vLog.add("Type and subtype name can not be empty.");
            return 1;
          }
          if ((type != null && type != "") && (subtype == null || subtype == "")) {
            vLog.add("Subtype name can not be empty.");
            return 1;
          }
          if ((type == null || type == "") && (subtype != null && subtype != "")) {
            vLog.add("Type name can not be empty.");
            return 1;
          }
          annotation.setFmethod(type);
          annotation.setFsource(subtype);
          annotation.setTrackName(trackName);
          if (trackName.compareToIgnoreCase(oldName) != 0) {
            String id = (String) trackMap.get(trackName);

            if (id != null) {
              try {
                ftypeid = Integer.parseInt(id);
                annotation.setFtypeId(ftypeid);
              }
              catch (NumberFormatException e) {
                e.printStackTrace(System.err);
              }
            }
          }
        }
      }
      else {
        annotation.setTrackName("");
        errorField.put("trackName", trackName);
        vLog.add("Track name can not be empty. Please enter a valid track name. ");
        return numErrs++;
      }
    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }
    return numErrs;
  }


  public static int validateQueryStartStop(int i, AnnotationDetail annotation, String tstart, String tstop, long chromosomeLength, HttpServletRequest request, HashMap errorFields, Vector vLog) {

    long qstart = 0;
    long qstop = 0;
    int numErrs = 0;

    if (tstart != null) {

      tstart = tstart.trim();
      if (tstart.compareToIgnoreCase("n/a") == 0 || tstart.compareToIgnoreCase("") == 0 || tstart.compareToIgnoreCase(".") == 0) {

      }
      else {
        tstart = tstart.replaceAll(",", "");
        tstart = tstart.replaceAll(" ", "");
        try {
          qstart = Long.parseLong(tstart);
          annotation.setTstart(tstart);
          annotation.setTargetStart(qstart);

        }
        catch (Exception e) {
          vLog.add("Query start is invalid.");
          errorFields.put("tstart_" + i, tstart);
          numErrs++;
        }
      }
    }


    if (tstop != null) {
      tstop = tstop.trim();

      if (tstop.compareToIgnoreCase("n/a") == 0 || tstop.compareToIgnoreCase("") == 0 || tstop.compareToIgnoreCase(".") == 0) {

      }
      else {
        try {
          tstop = tstop.replaceAll(",", "");
          tstop = tstop.replaceAll(" ", "");
          qstop = Long.parseLong(tstop);
          annotation.setTstop(tstop);
          annotation.setTargetStop(qstop);

        }
        catch (Exception e) {

          vLog.add("Query stop is invalid.");
          errorFields.put("tstop_" + i, tstop);
          numErrs++;
        }
      }
    }


    if (numErrs == 0) {
      errorFields.remove("tstart_" + i);
      errorFields.remove("tstop_" + i);
    }
    return numErrs;
  }


  /**
   * validate query start and end fields 1. tstart amd tstop can be negative numbers 2. can be "N/A" or "n/a", ".", or
   * empty line
   *
   * @param annotation
   * @param request
   * @param errorFields
   * @param vLog
   * @return true if success, false if fails
   */

  public static int validateQueryStartStop(AnnotationDetail annotation, HttpServletRequest request, HashMap errorFields, Vector vLog) {
    String tstart = null;
    String tstop = null;
    long qstart = 0;
    long qstop = 0;
    int numErrs = 0;
    boolean startErr = false;
    boolean stopErr = false;
    if ((tstart = request.getParameter("qstart")) != null) {
      annotation.setTstart(tstart);
      tstart = tstart.trim();
      if (tstart.compareToIgnoreCase("n/a") == 0 || tstart.compareToIgnoreCase("") == 0 || tstart.compareToIgnoreCase(".") == 0) {
        annotation.setTstart(null);
        annotation.setTargetStart(0);
      }
      else {
        tstart = tstart.replaceAll(",", "");
        tstart = tstart.replaceAll(" ", "");
        try {
          qstart = Long.parseLong(tstart);
          annotation.setTstart(tstart);
          annotation.setTargetStart(qstart);
        }
        catch (Exception e) {
          vLog.add("Query start is invalid.");
          errorFields.put("tstart", tstart);
          numErrs++;
          startErr = true;
        }
      }
    }
    else {
      annotation.setTstart(null);
    }

    if (!startErr && qstart > 2147483647) {
      annotation.setTargetStart(2147483647);
      annotation.setTstart("2147483647");
      vLog.add("Query start is too large. Will be set to 2,147,483,647");
      errorFields.put("tstart", tstart);
      numErrs++;
    }
    else if (!startErr && qstart < -2147483648) {
      annotation.setTargetStart(-2147483648);
      annotation.setTstart("-2147483648");

      vLog.add("Query start is too small. Will be set to -2,147,483,648");
      errorFields.put("tstart", tstart);
      numErrs++;
    }

    if ((tstop = request.getParameter("qstop")) != null) {
      tstop = tstop.trim();
      if (tstop.compareToIgnoreCase("n/a") == 0 || tstop.compareToIgnoreCase("") == 0 || tstop.compareToIgnoreCase(".") == 0) {
        annotation.setTstop(null);
        annotation.setTargetStop(0);
      }
      else {
        try {
          tstop = tstop.replaceAll(",", "");
          tstop = tstop.replaceAll(" ", "");
          qstop = Long.parseLong(tstop);
          annotation.setTargetStop(qstop);
          annotation.setTstop(tstop);
        }
        catch (Exception e) {

          vLog.add("Query stop is invalid.");
          errorFields.put("tstop", tstop);
          numErrs++;
          stopErr = true;
        }
      }
    }
    else {
      annotation.setTstop(null);
    }

    if (!stopErr && qstop > 2147483647) {
      annotation.setTargetStop(2147483647);
      annotation.setTstop("2147483647");
      vLog.add("Query stop is too large.  Will be set to 2,147,483,647");
      errorFields.put("tstop", tstop);
      numErrs++;
    }
    else if (!stopErr && qstop < -2147483648) {
      annotation.setTargetStop(-2147483648);
      annotation.setTstop("-2147483648");
      vLog.add("Query stop is too small.  Will be set to -2,147,483,648");
      errorFields.put("tstop", tstop);
      numErrs++;
    }

    return numErrs;
  }

  public static int validateFscore(int i, AnnotationDetail annotation, String fscore, HashMap errorFields, Vector vLog) {
    double dScore = 0.0;
    String fscore1 = "";
    int numErrs = 0;
    boolean b = false;

    if (fscore != null && fscore.compareTo("") != 0) {
      fscore = fscore.trim();
      fscore = fscore.replaceAll(",", "");
      fscore = fscore.replaceAll(" ", "");


      fscore = fscore.trim();
      fscore = fscore.toLowerCase();

      int indexE = fscore.indexOf("e");
      if (indexE >= 0) {
        fscore1 = fscore;

        if (indexE == (fscore.length() - 1)) {
          vLog.add("Score must be a valid  number ");
          errorFields.put("score", fscore1);
          return numErrs++;
        }

        if (indexE == 0) {
          if (fscore.length() == 1) {
            vLog.add("Score must be a valid  number ");
            errorFields.put("score", fscore1);
            return numErrs++;
          }
          else if (fscore.length() > 1)
            fscore = "1" + fscore;
        }


        b = true;
      }


      try {
        dScore = Double.parseDouble(fscore);
        annotation.setScore(dScore);
        annotation.setFscore(fscore);
      }
      catch (Exception e) {
        e.printStackTrace(System.err);
        if (!b) {
          vLog.add("Score must be a valid number.");
          errorFields.put("score_" + i, fscore);
        }
        else {
          vLog.add("Score must be a valid number.");
          errorFields.put("score_" + i, fscore1);
          numErrs++;
        }
      }


    }
    else {
//vLog.add("\"" + fscore + "\" is an invalid score.");
//errorFields.put("score", fscore);
//numErrs++;
    }
    return numErrs;
  }


  public static int validateFscore(AnnotationDetail annotation, HttpServletRequest request, HashMap errorFields, Vector vLog) {
    String fscore = null;
    double dScore = 0.0;
    String fscore1 = "";
    int numErrs = 0;
    boolean b = false;
    if ((fscore = request.getParameter("score")) != null) {
      annotation.setFscore(fscore);
      fscore = fscore.trim();
      fscore = fscore.replaceAll(",", "");
      fscore = fscore.replaceAll(" ", "");
      fscore = fscore.toLowerCase();

      int indexE = fscore.indexOf("e");
      if (indexE >= 0) {
        fscore1 = fscore;

        if (indexE == (fscore.length() - 1)) {
          vLog.add("Score must be a valid  number ");
          errorFields.put("score", fscore1);
          return numErrs++;
        }

        if (indexE == 0) {
          if (fscore.length() == 1) {
            vLog.add("Score must be a valid  number ");
            errorFields.put("score", fscore1);
            return numErrs++;
          }
          else if (fscore.length() > 1)
            fscore = "1" + fscore;
        }
        b = true;
      }

      /*
      String reg =  "^[-+]?[0-9]*[.]?[0-9]*([eE][-+] ?[0-9]+)?$";
      Pattern p = Pattern.compile(reg);
      Matcher m = p.matcher(fscore) ;
      boolean boo = m.matches();
      if (!boo)
      {
      vLog.add("111score must be a valid  number ");
      errorFields.put("score", fscore1);
      return  numErrs++;

      }
      */
      //System.err.println (" to be parsed: " + fscore);
      try {
        dScore = Double.parseDouble(fscore);
      }
      catch (Exception e) {
        e.printStackTrace(System.err);
        if (!b) {
          vLog.add("Score must be a valid number.");
          errorFields.put("score", fscore);
          return numErrs++;
        }
        else {
          vLog.add("Score must be a valid number.");
          errorFields.put("score", fscore1);
          return numErrs++;
        }
      }
      if (numErrs == 0) {
        annotation.setFscore(fscore);
        annotation.setScore(dScore);
      }
    }
    return numErrs;
  }


  /**
   * validate comments -- no tabs, no new lines
   *
   * @param annotation
   * @param request
   * @param errorField
   * @param vLog
   * @return
   */
  public static int validateSequence(AnnotationDetail annotation, HttpServletRequest request, HashMap errorField, Vector vLog) {
    String aSeq = null;
    int numErrs = 0;
//  add comments and sequence to fidtext
    if ((aSeq = request.getParameter("sequence")) != null) {
      annotation.setSequences(aSeq);
    }
    else
      annotation.setSequences("");

    return numErrs;
  }


  static String addReturn(String s) {


    boolean hasReturn = false;
    String newString = "";
    String temp = "";
    if (s.length() > 80) {
      while (s.length() > 80) {
        if (newString.length() >= 79) {
          if (!hasReturn)
            newString = newString + "\n" + temp;
          else
            newString = newString + temp;

        }

        temp = s.substring(0, 80);
        int index = temp.indexOf(' ');
        if (index < 0)
          index = temp.indexOf(',');
        if (index < 0)
          index = temp.indexOf('.');
        if (index < 0)
          index = temp.indexOf(';');

        if (index > 0)
          hasReturn = true;
        else
          hasReturn = false;


        s = s.substring(80);
      }
      newString = newString + "\n" + s;
    }
    else
      return s;

    return newString;
  }


  public static String stripTabAndReturn(String s) {
    s = s.replaceAll("\t", " ");
    s = s.replaceAll("\r", " ");
    s = s.replaceAll("\n", " ");
    s = s.replaceAll("\f", " ");

    s = s.replaceAll("\\s+", " ");
    s = s.trim();
    return s;
  }

  /**
   * @param annotation
   * @param request
   * @param errorField
   * @param vLog
   * @return
   */

  public static int validateComments(AnnotationDetail annotation, HttpServletRequest request, HashMap errorField, Vector vLog) {
    String aText = null;
    int numErrs = 0;
    if ((aText = request.getParameter("comments")) != null) {
      annotation.setComments(aText);
    }
    else
      annotation.setComments("");
    return numErrs;
  }


  public static AnnotationDetail[] findGroupAnnotations(String dbName, int fid, HttpServletResponse response, HttpSession mys, JspWriter out, Connection con) {
    String gname = null;
    ArrayList list = new ArrayList();
    int ftypeid = 0;
    DBAgent db =  DBAgent.getInstance();
    AnnotationDetail[] annotations = null;
    String fmethod = null;
    String fsource = null;
    String trackName = null;
    int rid = 0;
    try {
      if (con == null || con.isClosed())
        con = db.getConnection(dbName);

      PreparedStatement stms = con.prepareStatement("select f.gname, f.ftypeid, t.fmethod, t.fsource, f.rid from fdata2 f, ftype t  where f.ftypeid = t.ftypeid and f.fid = " + fid);
      ResultSet rs = stms.executeQuery();
      if (rs.next()) {
        gname = rs.getString(1);
        ftypeid = rs.getInt(2);
        fmethod = rs.getString(3);
        fsource = rs.getString(4);
        rid = rs.getInt(5);
      }
      rs.close();
      stms.close();

//out.println ("  rid = " + rid);
    }
    catch (Exception e) {

      e.printStackTrace(System.err);
    }

    if (rid < 0 || ftypeid < 0 || gname == null)
      return new AnnotationDetail[0];

    annotations = findGroupAnnotations(dbName, gname, ftypeid, rid, response, mys, out, con);

    return annotations;
  }


  public static AnnotationDetail[] findGroupAnnotations(String dbName, String gname, int ftypeid, int rid, HttpServletResponse response, HttpSession mys, JspWriter out, Connection con) {

    ArrayList list = new ArrayList();
    DBAgent db =  DBAgent.getInstance();
    AnnotationDetail[] annotations = null;

    String sql = "SELECT fd.fstart, fd.fstop, fd.fscore, fd.fphase, " +
            " fd.fstrand, fd.gname, ft.fmethod, ft.fsource, " +
            " ft.ftypeid, fr.refname, " +
            " fd.ftarget_start, fd.ftarget_stop, fd.fbin, " +
            " fd.rid, fd.fid, fd.displayCode, fd.displayColor, fd.groupContextCode  FROM " +
            " fdata2 fd, ftype ft, fref fr WHERE fd.ftypeid=ft.ftypeid AND " +
            " fd.rid = fr.rid AND fd.ftypeid = ? and fd.gname = ? and fd.rid = ?  order by fd.fstart ";


    String sqlFidText = "select textType, text from fidText where fid = ?  ";

    try {
      if (con == null || con.isClosed())
        con = db.getConnection(dbName);
      if (gname != null) {
        PreparedStatement stms = con.prepareStatement(sql);
        PreparedStatement stms2 = con.prepareStatement(sqlFidText);
        stms.setInt(1, ftypeid);
        stms.setString(2, gname);
        stms.setInt(3, rid);
        ResultSet rs = stms.executeQuery();

        while (rs.next()) {
          AnnotationDetail anno = new AnnotationDetail(rs.getInt(15));
          anno.setGname(gname);
          anno.setFtypeId(ftypeid);
          anno.setRid(rid);
          anno.setFstart(rs.getString(1));
          anno.setFstop(rs.getString(2));
          anno.setStart(rs.getLong(1));
          anno.setStop(rs.getLong(2));

          anno.setFscore(rs.getString(3));
          anno.setScore(rs.getDouble(3));

          anno.setPhase(rs.getString(4));
          anno.setStrand(rs.getString(5));
          anno.setChromosome(rs.getString(10));
          anno.setTstart(rs.getString(11));
          anno.setTstop(rs.getString(12));
          anno.setTargetStart(rs.getLong(11));
          anno.setTargetStop(rs.getLong(12));
          anno.setFbin(rs.getString(13));

          anno.setFmethod(rs.getString(7));
          anno.setFsource(rs.getString(8));

          if (rs.getString(16) != null)
            anno.setDisplayCode(rs.getInt(16));
          else
            anno.setDisplayCode(-1);


          if (rs.getString(17) != null)
            anno.setDisplayColor(rs.getInt(17));
          else
            anno.setDisplayColor(-1);

          anno.setGroupContextCode(rs.getString(18));

          if (anno.getDisplayColor() > 0) {
            int temp = anno.getDisplayColor();
            String hexS = Integer.toHexString(temp);
            anno.setHexAnnoColor(hexS);
          }


          if (anno.getFmethod() != null && anno.getFsource() != null)
            anno.setTrackName(anno.getFmethod() + ":" + anno.getFsource());

          stms2.setInt(1, anno.getFid());
          ResultSet rs2 = stms2.executeQuery();
          while (rs2.next()) {
            String type = rs2.getString(1);
            String text = rs2.getString(2);

            if (type != null && type.compareToIgnoreCase("t") == 0)
              anno.setComments(text);
            else if (type != null && type.compareToIgnoreCase("s") == 0)
              anno.setSequences(text);
          }
          rs2.close();
          list.add(anno);
        }

        if (list.size() > 0)
          annotations = (AnnotationDetail[]) list.toArray(new AnnotationDetail[list.size()]);
        rs.close();

        stms.close();


        stms2.close();
      }
//out.println (" num annos " + gname + " ftypeid  " + ftypeid + "  rid " +  rid + annotations.length);
    }
    catch (Exception e) {

      e.printStackTrace(System.err);
    }

    return annotations;
  }


  public static AnnotationDetail[] getAnnotationsFromWeb(AnnotationDetail[] annosDB, HttpServletRequest request, JspWriter out, HashMap chromosomeMap, HashMap trackmap, String dbName,  Connection con) throws Exception {
    int length = annosDB.length;
    AnnotationDetail[] annosWeb = new AnnotationDetail[length];
    for (int i = 0; i < length; i++) {
      if (annosDB[i].isFlagged())
        continue;

      if (request.getParameter("track_" + i) == null)
        continue;


      annosWeb[i] = new AnnotationDetail(annosDB[i].getFid());
      annosWeb[i].setFlagged(annosDB[i].isFlagged());


      String gname = request.getParameter("gname_" + i);
      String fstart = request.getParameter("annostart_" + i);
      String fstop = request.getParameter("annostop_" + i);
      String qStart = request.getParameter("qStart_" + i);
      String qStop = request.getParameter("qStop_" + i);
      String phase = request.getParameter("phase_" + i);
      String strand = request.getParameter("strand_" + i);
      String track = request.getParameter("track_" + i);
      String chromosome = request.getParameter("chromosome_" + i);
      String score = request.getParameter("score_" + i);
      String comments = request.getParameter("comments_" + i);
      String sequences = request.getParameter("sequences_" + i);
      String annoColor = request.getParameter("hiddenInputId" + i);
      if (annoColor == null)
        annoColor = "";

      annosWeb[i].setGname(gname);

      annosWeb[i].setFstart(fstart);
      annosWeb[i].setFstop(fstop);

      annosWeb[i].setFscore(score);
      annosWeb[i].setTstart(qStart);
      annosWeb[i].setTstop(qStop);
      annosWeb[i].setPhase(phase);
      annosWeb[i].setStrand(strand);
      annosWeb[i].setTrackName(track);
      annosWeb[i].setChromosome(chromosome);
      annosWeb[i].setComments(comments);
      annosWeb[i].setSequences(sequences);
      annosWeb[i].setFbin(annosDB[i].getFbin());
      annosWeb[i].setHexAnnoColor(annoColor);

      int intColor = 0;
      if (annoColor != null)
        annoColor = annoColor.trim();
      if (annosDB[i].getHexAnnoColor() != null && annoColor.compareTo(annosDB[i].getHexAnnoColor()) == 0)
        annosWeb[i].displayColor = annosDB[i].displayColor;

      else {

        if (annoColor != null && annoColor.compareTo("#") != 0) {
          String temp = annoColor.replaceAll("#", "");

          if (temp.length() > 0 && temp != "")
            intColor = Integer.parseInt(temp, 16);
          annosWeb[i].setDisplayColor(intColor);
        }
      }
      if (chromosome != null && annosDB[i].getChromosome() != null && chromosome.compareTo(annosDB[i].getChromosome()) == 0)
        annosWeb[i].setRid(annosDB[i].getRid());
      else {
        Chromosome chrom = (Chromosome) chromosomeMap.get(chromosome);
        if (chrom != null)
          annosWeb[i].setRid(chrom.getId());
      }

// if  track name unchanged
      if (track != null && annosDB[i].getTrackName() != null && track.compareTo(annosDB[i].getTrackName()) == 0) {
        annosWeb[i].setFtypeId(annosDB[i].getFtypeId());
      }
      else {  // if track changed
        String trackid = (String) trackmap.get(track);
        if (trackid != null)   // if existing in db
          annosWeb[i].setFtypeId(Integer.parseInt(trackid));
        else if (track != null && track.indexOf("New Track") > 0) {
// if new track
          String type = request.getParameter("type_" + i);
          String subtype = request.getParameter("subtype_" + i);
          if (type != null && subtype != null && type != "" && subtype != "") {
            int id = -1;

            if ((id = existTrack(type, subtype, dbName, trackmap, con)) < 0) {
              id = updateTrack(type, subtype, dbName, con);

              updateClassMaping(id, annosDB[i].getFtypeId(), dbName, out, con);
              annosWeb[i].setFtypeId(id);
              annosWeb[i].setFmethod(type);
              annosWeb[i].setFsource(subtype);
              annosWeb[i].setTrackName(type + ":" + subtype);

            }
            else {
              annosWeb[i].setFtypeId(-1);
              if (type != null)
                annosWeb[i].setFmethod(type);
              else
                annosWeb[i].setFmethod("");
              trackmap.put(type + ":" + subtype, "" + id);
              if (subtype != null)
                annosWeb[i].setFsource(subtype);
              else
                annosWeb[i].setFsource("");

            }
          }
          else {
            annosWeb[i].setFtypeId(-1);
            annosWeb[i].setFmethod("");
            trackmap.put(track, "-1");
            annosWeb[i].setFsource("");
          }
        }
        else {
          System.err.println("<br> track name " + track + "  web " +  annosDB[i].getTrackName());


          // throw new Exception("track");
        }
      } // track changed
    }
    return annosWeb;
  }


  public static int StartNewTrack(int i, HashMap trackMap, HttpServletRequest request, HashMap errorField, Vector vLog, JspWriter out) {
    String trackName = request.getParameter("track_" + i);
    String type = request.getParameter("type_" + i);
    String subtype = request.getParameter("subtype_" + i);

    int numErrs = 0;
    if (trackName != null && trackName.indexOf("New Track") < 0)
      return 0;

    if (type == null || subtype == null) {
      numErrs++;
    }
    else {
      type = type.trim();
      subtype = subtype.trim();
      if (type.compareTo("") == 0 || subtype.compareTo("") == 0)
        numErrs++;
    }


    if (numErrs > 0) {
      errorField.put("newTrackRow", "y");
      vLog.add("Track name can not be empty. Please enter a valid track name. ");
      return numErrs++;
    }
    return numErrs;
  }

  public static int insertFtype(String type, String subtype, String dbName, Connection con) {
    int id = 0;
    try {
      if (con == null || con.isClosed())
        con =  DBAgent.getInstance().getConnection(dbName);
      String sql = "select ftypeid from ftype where fmethod = ? and fsource = ? ";
      String sqlIns = "insert ignore  into ftype (fmethod, fsource) values (?, ?) ";
      String sqlInsMap = "insert into ";


      PreparedStatement stms = con.prepareStatement(sql);
      ResultSet rs = null;
      PreparedStatement stms1 = con.prepareStatement(sqlIns);
      if (type != null && subtype != null) {
        stms1.setString(1, type);
        stms1.setString(2, subtype);
        stms1.executeUpdate();
        stms.setString(1, type);
        stms.setString(2, subtype);
        rs = stms.executeQuery();
        if (rs != null && rs.next())
          id = rs.getInt(1);
      }

      if (rs != null)
        rs.close();
      if (stms != null)
        stms.close();
      if (stms1 != null)
        stms1.close();
    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }
    return id;
  }

  /* 05/02/2008 removed some redundant methods that were copied to this class and transformed this method into a wrapper*/
  public static boolean verifyUploadIdAndFid(int userId, int uploadId, int fid, GenboreeUpload upload, Connection mainConnection, Connection localConn)
  {

    boolean b = false;


    String databaseName = upload.getDatabaseName();
    String realFid = null;
    long valueFid = -1;

    int refSeqId = upload.getRefSeqId();


    if (refSeqId <= 0) {
      System.err.println("#AnnotationEditorHelper:verifyUpladIdAndFid uploadId is not valid-- userId = " + userId + " uploadId = " + uploadId);
      return false;
    }


    if (!GenboreeUtils.verifyUserAccess(refSeqId, userId, mainConnection))
    {
      System.err.println("#AnnotationEditorHelper:verifyUpladIdAndFid user does not have permission to edit this upload -- userId = " + userId + " uploadId = " + uploadId);
      return false;
    }


    realFid = GenboreeUtils.verifyFid(databaseName, "" + fid, localConn);



    if (realFid == null)
    {
      System.err.println("#AnnotationEditorHelper:verifyUpladIdAndFid fId does not exist for this upload -- userId = " + userId + " uploadId = " + uploadId + " fid = " + fid);
      return false;
    }

    if(!TrackPermission.isTrackAllowed( fid, databaseName,  userId))
    {
      System.err.println("#AnnotationEditorHelper:verifyUpladIdAndFid user does not have permission to edit this track fid: " + fid + " -- userId = " + userId + " uploadId = " + uploadId);
      return false;
    }


    return true;
  }



  public static void updateClassMaping(int id, int oldid, String dbName, JspWriter out, Connection con) {
    try {
      if (con == null)
        con =  DBAgent.getInstance().getConnection(dbName);
      String sql = "select distinct gid from ftype2gclass  where ftypeid  =   " + oldid;
      String sqlIns = " insert ignore ftype2gclass (ftypeid, gid) values (?, ?) ";

      PreparedStatement stms1 = con.prepareStatement(sqlIns);

      PreparedStatement stms = con.prepareStatement(sql);
      ResultSet rs = null;
      rs = stms.executeQuery();
      while (rs != null && rs.next()) {
        stms1.setInt(1, id);
        stms1.setInt(2, rs.getInt(1));
        stms1.executeUpdate();
      }

      if (rs != null)
        rs.close();
      if (stms != null)
        stms.close();
      if (stms1 != null)
        stms1.close();

    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }
  }


  public static void setTrackColor(int id, int oldid, String dbName, JspWriter out, Connection con) {
    try {
      if (con == null)
        con =  DBAgent.getInstance().getConnection(dbName);
      int colorid = 136;
      String sql = "select colorId from featuretocolor where ftypeid = ?";
      PreparedStatement stms = con.prepareStatement(sql);
      stms.setInt(1, oldid);
      ResultSet rs = stms.executeQuery();
      if (rs.next())
        colorid = rs.getInt(1);
      rs.close();
      stms.close();

      String sqlIns = " insert ignore featuretocolor (ftypeid,  colorId) values (?, ?) ";

      PreparedStatement stms1 = con.prepareStatement(sqlIns);


      stms1.setInt(1, id);
      stms1.setInt(2, colorid);
      stms1.executeUpdate();


      if (stms1 != null)
        stms1.close();

    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }
  }


  public static void updateTrackColor(int id, int oldid, String dbName, JspWriter out, Connection con) {
    try {
      if (con == null)
        con =  DBAgent.getInstance().getConnection(dbName);
      int srcTrkColorid = -1;
      String sql = "select colorId from featuretocolor where ftypeid = ?";
      PreparedStatement stms = con.prepareStatement(sql);
      stms.setInt(1, oldid);
      ResultSet rs = stms.executeQuery();
      if (rs.next())
        srcTrkColorid = rs.getInt(1);


// nothing to copy from
      if (srcTrkColorid < 0) {
        rs.close();
        stms.close();

        return;

      }

      int newTrkColorId = -1;
// check new track
      stms.setInt(1, id);
      rs = stms.executeQuery();
      if (rs.next())
        newTrkColorId = rs.getInt(1);
      rs.close();
      stms.close();

      if (newTrkColorId > 0)
        return;

      String sqlIns = " insert ignore featuretocolor (ftypeid,  colorId) values (?, ?) ";

      PreparedStatement stms1 = con.prepareStatement(sqlIns);


      stms1.setInt(1, id);
      stms1.setInt(2, srcTrkColorid);
      stms1.executeUpdate();


      if (stms1 != null)
        stms1.close();

    }
    catch (Exception e) {
      e.printStackTrace(System.err);
    }
  }


}


