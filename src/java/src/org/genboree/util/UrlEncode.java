package org.genboree.util;

import org.genboree.util.Util;


public class UrlEncode {


    public static void printUsage()
    {
        System.out.print("usage: UrlEncode");
        System.out.println(
                "-s string to use \n" + 
                "-e url encode \n" + 
                "-d url decode \n"
		);
    }


    public static void main(String[] args)
    {
        String stringToUse = null;
        boolean toEncode = false;
        boolean toDecode = false;
        
        if (args.length < 2)
        {
            printUsage();
            System.exit(-1);
        }

        if (args.length >= 1)
        {

            for (int i = 0; i < args.length; i++)
            {
                if (args[i].compareToIgnoreCase("-s") == 0)
                {
                    i++;
                    if (args[i] != null)
                    {
        		        stringToUse = args[i];
                    }
                }
                else if(args[i].compareToIgnoreCase("-e") == 0)
                {
                     toEncode = true;
                     toDecode = false;
                }
                else if(args[i].compareToIgnoreCase("-d") == 0)
                {
                    toEncode = false;
                    toDecode = true;
                }
            }

        }
        else
        {
            printUsage();
            System.exit(-1);
        }


        if(stringToUse == null || stringToUse.length() < 1)
            return;

        if(toEncode)
            System.out.println(Util.urlEncode(stringToUse));
        else if(toDecode)
            System.out.println(Util.urlDecode(stringToUse));
        else
            System.out.println(stringToUse);

    }

}


