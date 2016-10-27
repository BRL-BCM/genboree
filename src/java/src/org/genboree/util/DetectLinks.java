package org.genboree.util;

import org.genboree.dbaccess.GenboreeUpload;

import java.util.*;

public class DetectLinks
{
    public static void printUsage()
    {
        System.out.print("usage: DetectLinks ");
        System.out.println("\n");
        return;
    }

    public static void main(String[] args)
    {
        HashMap  databasesUsingVP = null;
        HashMap  databasesNotUsingVP = null;
        HashMap currentDB = null;
        HashMap  tempValues = null;
        String tempKey = null;
        String databaseName = null;
        String ftypeId = null;
        String fmethod = null;
        String fsource = null;
        String linkId = null;
        String linkName = null;
        String linkDesc = null;
        Iterator  tracksLinksIterator = null;

        databasesUsingVP = GenboreeUpload.detectLinks(true);
        databasesNotUsingVP =  GenboreeUpload.detectLinks(false);
        currentDB = new HashMap();
        System.out.println("Printing results for databases that use Value pairs");
        tracksLinksIterator = databasesUsingVP.entrySet().iterator() ;
        while(tracksLinksIterator.hasNext())
        {
            Map.Entry tracksLinksMap = (Map.Entry)tracksLinksIterator.next() ;
            tempKey = (String)tracksLinksMap.getKey();
            tempValues = (HashMap)tracksLinksMap.getValue();

            if(tempKey == null || tempValues == null) continue;

            databaseName = (String)tempValues.get("databaseName");
            ftypeId = (String)tempValues.get("ftypeid");
            fmethod = (String)tempValues.get("fmethod");
            fsource = (String)tempValues.get("fsource");
            linkId = (String)tempValues.get("linkId");
            linkName = (String)tempValues.get("name");
            linkDesc = (String)tempValues.get("description");


/*            if(!currentDB.containsKey(databaseName))
            {
                System.out.println("DatabaseName = " + databaseName);
                currentDB.put(databaseName, databaseName);
            }
*/

            System.out.println("DatabaseName = " + databaseName);
            System.out.println("   " + fmethod + ":" + fsource + " contains link " + linkName + " with internal comments -> " + linkDesc);
            System.out.flush();
        }

        System.out.println("Printing results for databases that do not use Value pairs only comments");
        tracksLinksIterator = databasesNotUsingVP.entrySet().iterator() ;
        while(tracksLinksIterator.hasNext())
        {
            Map.Entry tracksLinksMap = (Map.Entry)tracksLinksIterator.next() ;
            tempKey = (String)tracksLinksMap.getKey();
            tempValues = (HashMap)tracksLinksMap.getValue();

            if(tempKey == null || tempValues == null) continue;

            databaseName = (String)tempValues.get("databaseName");
            ftypeId = (String)tempValues.get("ftypeid");
            fmethod = (String)tempValues.get("fmethod");
            fsource = (String)tempValues.get("fsource");
            linkId = (String)tempValues.get("linkId");
            linkName = (String)tempValues.get("name");
            linkDesc = (String)tempValues.get("description");

            if(!currentDB.containsKey(databaseName))
            {
                System.out.println("DatabaseName = " + databaseName);
                currentDB.put(databaseName, databaseName);
            }

            System.out.println("   " + fmethod + ":" + fsource + " contains link " + linkName + " with internal comments -> " + linkDesc);
            System.out.flush();
        }
    }
}


