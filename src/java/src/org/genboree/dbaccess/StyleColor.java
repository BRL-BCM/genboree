package org.genboree.dbaccess;

import java.sql.*;
import java.util.Iterator;
import java.util.Map;

import org.genboree.dbaccess.*;
import org.genboree.gdasaccess.*;
/**
 * Created by IntelliJ IDEA.
 * User: manuelg
 * Date: Aug 18, 2003
 * Time: 11:07:15 AM
 * To change this template use Options | File Templates.
 */
public class StyleColor {

  protected DBAgent db;
  protected Connection conn = null;


    public StyleColor() throws SQLException {
        db = DBAgent.getInstance();
        conn = db.getConnection();
    }

    public StyleColor(DBAgent db) throws SQLException {
	     this.db = db;
             conn = db.getConnection();
    }

    public void updateStyleColorValues(String currentKey, String keyValue, int userId, parseStyleCmd[] rseps)
    {
        int i = 0;
        String tempColor = null;
        String tempStyle = null;


       for( i=0; i < rseps.length; i++ )
       {
        if(rseps[i].getFeatureType() == null || rseps[i].getFeatureType().length() < 1)
            continue;

        tempColor = rseps[i].getFeatureType().concat(":color");
        tempStyle = rseps[i].getFeatureType().concat(":style");
        if(currentKey.equalsIgnoreCase(tempColor) == true)
        {
            if(keyValue.equals(rseps[i].getColor()) == false || userId == 0)
                updateUserValue(rseps[i].getFeatureType(), keyValue, userId, "color");
        }
        else if(currentKey.equalsIgnoreCase(tempStyle) == true)
        {
            if(keyValue.equals(rseps[i].getName()) == false || userId == 0)
                updateUserValue(rseps[i].getFeatureType(), keyValue, userId, "style");
        }

       }

    }


    void updateUserValue(String featureType, String newValue, int userId, String type)
    {
        int featureTypeId;
        int newValueId;


        featureTypeId = getFeatureTypeIdFromName(featureType);
        newValueId = getNewValueId(newValue, type);

            System.err.println("the FeatureType is " + featureType + " with value" +
		 newValue + " and with type" + type + " and userId = " + userId);
	   System.err.flush();
        if(type.equalsIgnoreCase("color") == true)
            setNewColorId(userId, featureTypeId, newValueId);
        else if(type.equalsIgnoreCase("style") == true)
            setNewStyleId(userId, featureTypeId, newValueId);
        else
            System.err.println("unknown type in updateUserValue for feature " + featureType + " with value" + newValue + " and with type" + type);


    }

    int getFeatureTypeIdFromName(String featureType)
    {
        int featureTypeId = 0;
        try
         {

             PreparedStatement pstmt = conn.prepareStatement(
                     "Select featureTypeId from featuretype WHERE name = ?");

                 pstmt.setString( 1,featureType);
                 ResultSet rs1 = pstmt.executeQuery();
                 if( rs1.next() )
                     featureTypeId = rs1.getInt(1);
                 pstmt.close();
                 return featureTypeId;
         } catch( Exception ex ) {
             db.reportError( ex, "FeatureTypeId error" );
         }
         return 0;
    }

    int  getNewValueId(String newValue, String type)
    {
        int valueId = 0;
        PreparedStatement pstm = null;
        try
        {
            if(type.equalsIgnoreCase("color") == true)
                pstm = conn.prepareStatement("SELECT colorId FROM color WHERE value = ?");
            else if(type.equalsIgnoreCase("style") == true)
                pstm = conn.prepareStatement("SELECT styleId FROM style WHERE name = ?");
            else
            {
                 System.err.println("The type is unknown" + type);
                return 0;
            }

            pstm.setString( 1,newValue);
            ResultSet rs1 = pstm.executeQuery();
            if( rs1.next() )
               valueId = rs1.getInt(1);
            pstm.close();
            return valueId;
         } catch( Exception ex ) {
             db.reportError( ex, "newValueId error" );
         }
         return 0;
    }

    void setNewColorId(int userId, int featureTypeId, int newValueId)
    {
        String checkColorId = new String("SELECT userColorId from userColor where featureTypeId = ? and userId = ?");
        String updateColorId = new String("UPDATE userColor set colorId = ? where featureTypeId = ? and userId = ?");
        String insertColorId = new String("Insert into userColor (colorId, featureTypeId, userId) VALUES (?, ?, ?)");
        String checkDefaultColorId = new String("SELECT defaultColorId from defaultColor where featureTypeId = ?");
        String updateDefaultColorId = new String("UPDATE defaultColor set colorId = ? where featureTypeId = ?");
        String insertDefaultColorId = new String("Insert into defaultColor (colorId, featureTypeId) VALUES (?, ?)");
        PreparedStatement pstm = null;
        int userColorId = 0;
        int defaultColorId = 0;

         if(userId > 0)
         {
            try
            {
                pstm = conn.prepareStatement(checkColorId);
                pstm.setInt(1,featureTypeId);
                pstm.setInt(2,userId);
                ResultSet rs1 = pstm.executeQuery();
                if( rs1.next() )
                    userColorId = rs1.getInt(1);

		System.err.println("The userColorId is  " + userColorId );
                pstm.clearParameters();
                if(userColorId > 0)
                    pstm = conn.prepareStatement(updateColorId);
                else
                    pstm = conn.prepareStatement(insertColorId);

                pstm.setInt(1,newValueId);
                pstm.setInt(2,featureTypeId);
                pstm.setInt(3,userId);
                pstm.executeUpdate();

            } catch( Exception ex ) {
		System.err.println("The parameters are: query " + insertColorId + " " + newValueId + " " + featureTypeId + " " + userId );
		if(db == null)
			System.err.println("The db is error");
                db.reportError( ex, "newValueId error" );
            }
         }
        else
         {
            try
            {
                pstm = conn.prepareStatement(checkDefaultColorId);
                pstm.setInt(1,featureTypeId);
                ResultSet rs1 = pstm.executeQuery();
                if( rs1.next() )
                    defaultColorId = rs1.getInt(1);

                pstm.clearParameters();
                if(defaultColorId > 0)
                    pstm = conn.prepareStatement(updateDefaultColorId);
                else
                    pstm = conn.prepareStatement(insertDefaultColorId);

                pstm.setInt(1,newValueId);
                pstm.setInt(2,featureTypeId);
                pstm.executeUpdate();

            } catch( Exception ex ) {
                db.reportError( ex, "newDefaultValueId error" );
            }
         }
    }

    void setNewStyleId(int userId, int featureTypeId, int newValueId)
    {
        String checkStyleId = new String("SELECT userFeatureTypeStyleId from userfeaturetypestyle where featureTypeId = ? and userId = ?");
        String updateStyleId = new String("UPDATE userfeaturetypestyle set styleId = ? where featureTypeId = ? and userId = ?");
        String insertStyleId = new String("Insert into userfeaturetypestyle (styleId, featureTypeId, userId) VALUES (?, ?, ?)");
        String checkDefaultStyleId = new String("SELECT defaultUserFeatureTypeStyleId from defaultuserfeaturetypestyle where featureTypeId = ?");
        String updateDefaultStyleId = new String("UPDATE defaultuserfeaturetypestyle set styleId = ? where featureTypeId = ?");
        String insertDefaultStyleId = new String("Insert into defaultuserfeaturetypestyle (styleId, featureTypeId) VALUES (?, ?)");
        PreparedStatement pstm = null;
        int userStyleId = 0;
        int defaultStyleId = 0;

         if(userId > 0)
         {
            try
            {
                pstm = conn.prepareStatement(checkStyleId);
                pstm.setInt(1,featureTypeId);
                pstm.setInt(2,userId);
                ResultSet rs1 = pstm.executeQuery();
                if( rs1.next() )
                    userStyleId = rs1.getInt(1);

                pstm.clearParameters();
                if(userStyleId > 0)
                    pstm = conn.prepareStatement(updateStyleId);
                else
                    pstm = conn.prepareStatement(insertStyleId);

                pstm.setInt(1,newValueId);
                pstm.setInt(2,featureTypeId);
                pstm.setInt(3,userId);
                pstm.executeUpdate();

            } catch( Exception ex ) {
                 db.reportError( ex, "newStyleValueId error" );
            }
         }
         else
         {
            try
            {
                pstm = conn.prepareStatement(checkDefaultStyleId);
                pstm.setInt(1,featureTypeId);
                ResultSet rs1 = pstm.executeQuery();
                if( rs1.next() )
                    defaultStyleId = rs1.getInt(1);

                pstm.clearParameters();
                if(defaultStyleId > 0)
                    pstm = conn.prepareStatement(updateDefaultStyleId);
                else
                    pstm = conn.prepareStatement(insertDefaultStyleId);

                pstm.setInt(1,newValueId);
                pstm.setInt(2,featureTypeId);
                pstm.executeUpdate();

            } catch( Exception ex ) {
                 db.reportError( ex, "newDefaultStyleValueId error" );
            }
         }



    }

    public static void main(String args[]) throws SQLException {
        parseStyleCmd[] rseps = parseStyleCmd.fetchStyles("http://localhost/java-bin/das/genboree_5mmm2kend8daf46fa5abcd1819cffech/styles?userId=7");
        StyleColor theStyle = new StyleColor();
        theStyle.updateStyleColorValues("Pash:Mm11-b2:color", "#000000", 7, rseps);
        theStyle.updateStyleColorValues("Pash:Mm11-b2:style", "cdna_draw", 7, rseps);
    }
}
