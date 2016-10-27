package org.genboree.dbaccess;

/**
 * Created by IntelliJ IDEA. User: tong Date: Jun 21, 2005 Time: 1:37:05 PM To change this template use File | Settings
 * | File Templates.
 */
public interface SqlQueries {

    // select deafult stype  id
   public static final String sqlSelectStyleID = "SELECT styleId FROM style WHERE name='simple_draw'";


    // select style objects using ftypeid and user id
    public static final String sqlSelectStyleByUserIDFtypeID = "SELECT s.styleId, s.name, s.description " +
            "FROM featuretostyle fs, style s " +
            "WHERE fs.styleId=s.styleId AND fs.userId=? AND fs.ftypeid=? ";

    // select color objects using ftypeid and user id
    public static final String sqlSelectColorByUserIDFtypeID = "SELECT c.colorId, c.value FROM featuretocolor fc, color c " +
            "WHERE fc.colorId=c.colorId AND fc.userId=? AND fc.ftypeid=? ";

    // select feature from ftype
    public static final String sqlSelectFtype = "SELECT ftypeid, fmethod, fsource FROM ftype";


    public static final String createLink =
            "CREATE TABLE link ( `linkId` varchar(32) NOT NULL, `name` varchar(255), `description` varchar(255), PRIMARY KEY (`linkId`));";

    public static final String createFeatureToLink =
            "CREATE TABLE `featuretolink1` ( " +
            "`ftypeid` int(10) unsigned NOT NULL default '0',  " +
            "`userId` int(10) unsigned NOT NULL default '0',  " +
            "`linkId` varchar(32)  NOT NULL, " +
            "PRIMARY KEY  (`userId`,`ftypeid`,`linkId`) ) ";
   public static final String selectGclass  = "SELECT gid, gclass FROM gclass order by gclass";

    public static final String selectLastId =   " SELECT LAST_INSERT_ID() ";


}
