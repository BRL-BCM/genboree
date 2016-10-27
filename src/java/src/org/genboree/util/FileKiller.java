package org.genboree.util;

import java.io.*;
import java.util.*;

import javax.servlet.http.*;

public class FileKiller extends Hashtable
    implements HttpSessionBindingListener
{
    protected String pref, suff;

    public FileKiller( String pref, String suff )
    {
        this.pref = pref;
        this.suff = suff;
    }

    public String requestFile()
    {
        try
        {
            File f = File.createTempFile( pref, suff );
            f.deleteOnExit();
            String rc = f.getName();
            put( rc, f );
            return rc;
        } catch( Throwable t ) {
            t.printStackTrace(System.err);
        }
        return null;
    }

    public File getFile( String key )
    {
        return (File) get( key );
    }

    public void valueBound( HttpSessionBindingEvent event )
    {
    }

    public static void clearDirectory( File dir )
    {
        File[] fList = dir.listFiles();
        if( fList == null ) return;
        for( int i=0; i<fList.length; i++ )
        {
            File f = fList[i];
            try
            {
                if( f.isDirectory() ) clearDirectory( f );
                f.delete();
            } catch( Exception ex ) {
                ex.printStackTrace(System.err);
                System.err.println("An exception at FileKiller#clearDirectory trying to clean the directory  "
                        + dir.getAbsolutePath()  + " specifically in file " + f.getAbsolutePath());
                System.err.flush();
            }
        }
    }

    public void valueUnbound( HttpSessionBindingEvent event )
    {
	    for( Enumeration en=keys(); en.hasMoreElements(); )
	    {
	        File f = (File) get( en.nextElement() );
			try
			{
			    if( f.isDirectory() ) clearDirectory( f );
			    f.delete();
			} catch( Throwable t ) {
                t.printStackTrace(System.err);
            }
	    }
    }

}
