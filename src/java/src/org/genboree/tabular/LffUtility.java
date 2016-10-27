package org.genboree.tabular;
import org.apache.commons.validator.routines.DateValidator;
import org.apache.commons.validator.routines.DoubleValidator;
import org.apache.commons.validator.routines.LongValidator;
import org.genboree.util.Constants;
import org.genboree.util.Util;
import org.genboree.util.GenboreeConfig ;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import javax.servlet.http.HttpSession;
import javax.servlet.jsp.JspWriter;
import java.io.File;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
/**
* User: tong
* Date: Jan 30, 2007
* Time: 3:17:03 PM
*/
    public class LffUtility {
    public static boolean validateTrackNames ( String [] trackNames, HashMap trackMap ) {
           boolean success =  true;
           for (int i=0; i<trackNames.length; i++) {
              if (trackMap.get(trackNames[i]) == null) {
                  success = false;
                  break;
              }
           }

            return success;
        }


            public static String []  findInvalidTracks ( String [] trackNames, HashMap trackMap ) {
                ArrayList  list = new ArrayList ();
               for (int i=0; i<trackNames.length; i++) {
                  if (trackMap.get(trackNames[i]) == null) {
                     list.add(trackNames[i]);
                  }
               }
                String [] arr = null;
                if (!list.isEmpty())
               arr = (String [])list.toArray (new String [list.size()]);
                return arr ;
            }

    public static String [] parseJsonArray  (JSONObject json, String key) throws JSONException  {
          if (json == null  )
           throw new JSONException( "Error: passed json object is null");

              if ( key == null )
                         throw new JSONException( "Error: passed json key is null");


          String [] selectedNames = null;
          if (json.has(key)) {
              JSONArray displayArray  = json.getJSONArray(key);
              String status = null;
              String trackName = null;
              ArrayList list = new ArrayList ();
              if (displayArray != null) {
                  for (int i=0; i< displayArray.length(); i++) {
                      JSONArray arr = displayArray.getJSONArray(i);
                          trackName = (String)arr.get(1);

                          if (trackName.indexOf("_display")>=0)
                             trackName = trackName.substring(0, trackName.length() -8);

                         if (trackName.indexOf("_sort")>=0 && trackName.indexOf("_sort") == (trackName.length()-5))
                             trackName = trackName.substring(0, trackName.length() -5);



                          if (trackName != null)
                          list.add(Util.urlDecode(trackName));
                   }
               }

              if (!list.isEmpty())
                 selectedNames  = (String[])list.toArray(new String[list.size()]);
          }
            else
                throw new JSONException( "Error: json key  " + key + "  is not found in json object " + json.toString());

          return selectedNames;
      }

       public static int countAVPAssociation (Connection con, int [] ftypeids, int limit, int numAnnos, JspWriter out) {
           int count =0;

           if (numAnnos <=0)
             return 0;

           int i=0; int j=0;

            int [] fids = AttributeRetriever.retrieveFidByFtypeids(con, ftypeids, numAnnos);
                 if (fids == null || fids.length ==0)
                   return 0;
            try {
                Date d1 = new Date();
          int [][] arr = LffUtility.getFidArrays (fids, 1000);
                  Date d2 = new Date();
                   PreparedStatement stms = null;
              ResultSet rs = null;

                String  sql =   "select count(*) from fid2attribute where fid in (" + LffConstants.Q1000 + ") ";
                   stms = con.prepareStatement(sql);
                 for ( i=0; i<arr.length; i++) {
                  for ( j=0; j<1000; j++)
                      stms.setInt(j+1,  arr[i][j] );
                   rs = stms.executeQuery();
                   if (rs.next())
                     count += rs.getInt(1);
                   if (count > limit)
                       break;

               }

                   rs.close();
                stms.close();

           }
           catch (Exception e) {
            e.printStackTrace();

           }

           return count;
       }


        public static int countText (Connection con, int [] ftypeids) {
               int count =0;
               String sql =   "select count(*) from fidText where ftypeid = ? ";
                try {
                  PreparedStatement stms =  con.prepareStatement(sql);
                  ResultSet rs = null;

                   for (int i=0; i<ftypeids.length; i++) {
                       stms.setInt(1, ftypeids[i] );
                       rs = stms.executeQuery();
                       if (rs.next())
                           count += rs.getInt(1);

                   }

               }
               catch (Exception e) {
                e.printStackTrace();

               }

               return count;
           }


	public static int ppw(Connection con, int [] ftypeids, int rid, long start, long stop) {
				int count =0;
				String sql =   "select count(*) from fdata2  d ,  fidText t where  d.rid = ? and d.fstart >= ? and d.fstop <= ? and d.ftypeid = ?   and d.fid = t.fid    ";
				 try {
				   PreparedStatement stms =  con.prepareStatement(sql);
				   ResultSet rs = null;

					for (int i=0; i<ftypeids.length; i++) {
						stms.setInt(1, rid);
						stms.setLong(2, start);
						stms.setLong(3, stop);
						stms.setInt(4, ftypeids[i] );
						rs = stms.executeQuery();
						if (rs.next())
							count += rs.getInt(1);

					}

				}
				catch (Exception e) {
				 e.printStackTrace();

				}

				return count;
			}








	 public static int [][] getFidArrays (int fids [], int size ) {
         if (fids == null || fids.length==0)
         return null;
         if (size <= 0)
         size = 100;
         int num = fids.length;
         int length = num/size;
         if (num % size >0)
         length ++;
         int  [][] fidsArrays  = new int  [length][size];

        for (int i=0; i<length-1; i++) {
            for (int j=0; j<size; j++)
                fidsArrays [i][j] = fids[i*size + j ];
        }

             int lastRow = length -1;
         if (num% size>0) {
            int remain = num%size;
            for (int j=0; j<remain; j++)
             fidsArrays [lastRow][j] = fids[lastRow*size + j ];

             if (remain < size)
             for (int j=remain; j>size; j++)
                        fidsArrays [lastRow][j] = -1;
           }
         return fidsArrays ;
  }


	public static String  [][] getFidArrays (String  fids [], int size ) {
			if (fids == null || fids.length==0)
			return null;
			if (size <= 0)
			size = 100;
			int num = fids.length;
			int length = num/size;
			if (num % size >0)
			length ++;
			String  [][] fidsArrays  = new String   [length][size];

		   for (int i=0; i<length-1; i++) {
			   for (int j=0; j<size; j++)
				   fidsArrays [i][j] = fids[i*size + j ];
		   }

				int lastRow = length -1;
			if (num% size>0) {
			   int remain = num%size;
			   for (int j=0; j<remain; j++)
				fidsArrays [lastRow][j] = fids[lastRow*size + j ];

				if (remain < size)
				for (int j=remain; j>size; j++)
						   fidsArrays [lastRow][j] = "-1";
			  }
			return fidsArrays ;
	 }


  public static File createJsonConfigFile(String groupId, String refseqId, String fileName) throws Exception
  {
    String rootDir = GenboreeConfig.getConfigParam("annoTableViewsRootDir") ;
    File parentDir = new File(rootDir) ;
    if(!parentDir.exists())
    {
      throw new Exception (" failed in creating file for storing tabular view parameters: check root directory. ") ;
    }

    File tabularView = new File(parentDir, "annoTableViews") ;
    if(!tabularView.exists())
    {
      tabularView.mkdir() ;
    }

    if(!tabularView.exists())
    {
      throw new Exception (" failed in creating file for storing tabular view parameters: check directory of annoTableViews") ;
    }

    File groupDir = new File(tabularView,  groupId) ;
    if(!groupDir.exists())
    {
      groupDir.mkdir() ;
    }

    if(!groupDir.exists())
    {
      throw new Exception (" failed in creating file for storing tabular view parameters: check passed group id ");
    }

    File dbDir = new File(groupDir, refseqId) ;
    if(!dbDir.exists())
    {
      dbDir.mkdir() ;
    }

    if(!dbDir.exists())
    {
      throw new Exception (" failed in creating file for storing tabular view parameters: check passed refseqId ") ;
    }

    File annoFile = new File (dbDir, fileName) ;

    if(!annoFile.exists())
    {
      annoFile.createNewFile() ;
    }

    if(!annoFile.exists())
    {
      throw new Exception (" failed in creating file for storing tabular view parameters: check passed fileName ") ;
    }

    return annoFile ;
  }

    public static String [] parseJson  (JSONObject json, String key) throws JSONException  {
    if (json == null  )
     throw new JSONException( "Error: passed json object is null");

        if ( key == null )
                   throw new JSONException( "Error: passed json key is null");


    String [] selectedNames = null;
    if (json.has(key)) {
        JSONArray displayArray  = json.getJSONArray(key);
        String status = null;
        String trackName = null;
        ArrayList list = new ArrayList ();
        if (displayArray != null) {
            for (int i=0; i< displayArray.length(); i++) {
                JSONArray arr = displayArray.getJSONArray(i);
                if (arr != null && arr.length () == 3)
                    status = (String)arr.get(2);
                if (status != null && status .equals("1")) {
                    trackName = (String)arr.get(1);

                    if (trackName.indexOf("_display")>=0)
                       trackName = trackName.substring(0, trackName.length() -8);
                    if (trackName != null)
                    list.add(Util.urlDecode(trackName));


                }
				arr = null;
			}
         }

        if (!list.isEmpty())
           selectedNames  = (String[])list.toArray(new String[list.size()]);

		list = null;
		displayArray = null;
	}
      else
          throw new JSONException( "Error: json key  " + key + "  is not found in json object " + json.toString());

    return selectedNames;
}



    public static int  parseTrackName4ftypeid (String s, Connection con) {
        int id = -1;
        if (s == null) {
        return id;
        }
        if (s.indexOf(":") <1) {
        return id;
        }
        String type = s.substring(0, s.indexOf(":"));
        String subtype = s.substring(s.indexOf(":")+1);
        if (type != null  && subtype != null) {
        String sql = "select ftypeid from ftype where fmethod  = ?  and fsource = ?";
        try {
            PreparedStatement stms = con.prepareStatement(sql);
            stms.setString(1, type);
            stms.setString(2, subtype);
            ResultSet rs = stms.executeQuery();
            if (rs.next())
            id = rs.getInt(1);
			if (rs != null)
			rs.close();
            stms.close();
        }
        catch (Exception e) {
        e.printStackTrace();
        }
        }
        return id;
    }


public static int [] parse4ftypeids (String s) {
if (s == null)
return null;
ArrayList list = new ArrayList ();
int index = 0;
int  lastIndex = -1;
while  ((index = s.indexOf(",", lastIndex+1))>0 ) {
list.add(s.substring(lastIndex+1, index));
lastIndex = index;
}
if (!list.contains(s.substring(lastIndex+1)))
list.add(s.substring(lastIndex+1));
int [] ids = null;
if (!list.isEmpty()) {
ids = new int[list.size()];
for (int i=0; i<list.size(); i++) {
try {
ids[i] = Integer.parseInt((String)list.get(i));
}
catch (Exception e) {
e.printStackTrace();
return null;
}
}
}
return ids;
}

public static void clearCache (HttpSession mys) {
if ( mys.getAttribute("totalAnnotations") != null)
mys.removeAttribute("totalAnnotations");
if ( mys.getAttribute("page2Annotation") != null)
mys.removeAttribute("page2Annotation");
if (mys.getAttribute("fid2Attributes") != null )
mys.removeAttribute("fid2Attributes");
}

	public static String [] getFidStrings (String fids [], int size ) {
		if (fids == null || fids.length==0)
			return new String [] {"-1"};

		if (size <= 0)
		size = 100;

		int num = fids.length;
		int length = num/size;
		if (num % size >0)
			length ++;

		String [] fidstrings = new String [length];
		String s = "";
		StringBuffer sb = new StringBuffer ();
		int count = 0;
		int index = 0;
		String quote = "'";
		String comma = ",";
		for (int i=0; i<num; i++) {
			if (i%size ==0 && i != 0) {


				fidstrings[count] = sb.toString();
				count ++;
				index = 0;
				s = "";
				sb = new StringBuffer ();
					sb.append(quote);
				 sb.append(fids[i]);
				 sb.append("'");
				 index++;
			}
			else {
				if (index < size && i<num-1) {
					sb.append (quote);
					sb.append(fids[i]);
					sb.append(quote) ;
					if (index < size-1)
					sb.append(comma);
					index++;
				}
			}
		}
		if (num% size>0) {
		sb.append(quote);
			sb.append(fids[length-1]);
			sb.append(quote);
		fidstrings[length-1] = sb.toString();
		}

		sb = null;
		return fidstrings;
	}



	public static String [] getFidStrings (int fids [], int size ) {
        if (fids == null || fids.length==0)
        return new String [] {"-1"};

		String blank = "";
		String quote = "'";
		String comma = ",";
		if (size <= 0)
        size = 100;
        int num = fids.length;
        int length = num/size;
        if (num % size >0)
        length ++;
        String [] fidstrings = new String [length];
        StringBuffer s = new StringBuffer("");
        int count = 0;
        int index = 0;
        for (int i=0; i<num; i++) {

            if (i%size ==0 && i != 0) {


                fidstrings[count] = s.toString();
			//	if  (count < 2)
				//   System.err.println("" + count + "  s " + s.toString());


				count ++;
                index = 0;
                s = new StringBuffer("");
					s.append( quote);
				s.append(fids[i]);
				s.append( quote);
				index++;

			}
            else {
				if (index < size && i<num-1) {
					s.append(quote);
					s.append(fids[i]);
					s.append(quote);
					if (index <size-1)
					s.append(comma);
				//	if (count <2)
					// System.err.println("" + index + s.toString());
					index++;
				}
            }
        }

          if (num ==size ) {
                s.append(quote);
			    s.append(fids[length-1]);
			    s.append(quote);
                fidstrings[0] = s.toString();
            }


        if (num% size>0) {
            s.append( quote);
			s.append(fids[length-1]);
			s.append(quote);
            fidstrings[length-1] = s.toString();
        }

		s = null;

		return fidstrings;
        }







	public static int  findLffIndex (String sortName) {
	if (sortName == null)
	return -1;
	int  index2 = -1;
	for (int i=0; i<LffConstants.LFF_COLUMNS.length; i++) {
	if (sortName.equals(LffConstants.LFF_COLUMNS[i])){
	index2 = i;
	break;
	}
	}
	return index2;
}

	public static int findDataType (String name) {
		int type = LffConstants.String_TYPE;
		Long ii = LongValidator.getInstance().validate(name);
		if (ii != null) return LffConstants.Long_TYPE;
		else  {
			Double d = DoubleValidator.getInstance().validate(name);
			if (d!=null)
			return LffConstants.Double_TYPE;
			else {
			Date  date = DateValidator.getInstance().validate(name);
			if (date != null)
			return LffConstants.Date_TYPE;
			}
		}
		return type;
	}


public static  String findFdataSortName (int index ) {
String sortName = null;
switch (index) {
case (0) : sortName = "gname";
break;
case (1) : sortName = null;
break;
case (2) : sortName = null;
break;
case (3) : sortName =  null;
break;
case (4) : sortName = null;
break;
case (5) : sortName = "fstart";
break;
case (6) : sortName = "fstop";
break;
case (7) : sortName = "fstrand";
break;
case (8) : sortName = "fphase";
break;
case (9) : sortName = "fscore";
break;
case (10) : sortName = "ftarget_start";
break;
case (11) : sortName = "ftarget_stop";
break;
case (12) : sortName = null;
break;
case (13) : sortName = null;
break;
}
return sortName;
}

public static  String findNonFdataSortName (int index ) {
String sortName = null;
switch (index) {
case (1) : sortName = "ftypeid";
break;
case (2) : sortName = "ftypeid";
break;
case (3) : sortName =  "ftypeid";
break;
case (4) : sortName = "rid";
break;
}
return sortName;
}

public static String [] covertNames (String [] names) {
if (names == null || names.length ==0)
return names;
ArrayList list = new ArrayList ();
String dataName = null;
for (int i=0; i<names.length; i++) {
int index =LffUtility.findLffIndex(names [i]);
if (index >=0){
dataName = LffUtility.findFdataSortName(index);
if (dataName == null)
break;
else
list.add(dataName);
}
else
break;
}
return (String [])list.toArray(new String [list.size()]);
}
}
