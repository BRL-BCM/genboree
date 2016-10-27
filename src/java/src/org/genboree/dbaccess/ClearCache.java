package org.genboree.dbaccess;



public class ClearCache
{


    public static void printUsage()
    {
        System.out.print("usage: ClearCache");
/*
        System.out.println(
                "-r refseqid ( or -d databaseName )\n" +
                "Optional [\n" +
                "\t-d databaseName\n" +
                "]\n");
*/
        return;
    }
    public static void main(String[] args) throws Exception
    {


        DBAgent db = DBAgent.getInstance();

        Refseq[] rseqs = Refseq.fetchAll( db );


        for(int i = 0; i < rseqs.length; i++)
        {
            Refseq tempRefseq = rseqs[i];
            System.err.println("processing database = " + tempRefseq.getDatabaseName());
            CacheManager.clearCache( db, tempRefseq );
        }


        System.exit(0);

    }



}
