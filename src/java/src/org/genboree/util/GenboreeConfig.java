package org.genboree.util ;

import java.io.* ;
import java.util.* ;
import java.util.regex.* ;

public class GenboreeConfig
{
  // Get value of configuration parameter as a String
  public static String getConfigParam(String param)
  {
    String propValStr = null ;
    try
    {
      ReadConfigFile myConfig = new ReadConfigFile() ;
      if(myConfig.getGoodFile())
      {
        propValStr = myConfig.getProps().getProperty(param);
      }
    }
    catch(IOException e)
    {
      System.err.println("GenboreeConfig#getConfigParam: ERROR => Unable to read properties file " + Constants.GENBOREE_CONFIG_FILE);
      e.printStackTrace(System.err);
    }
    return propValStr ;
  }

  // Get value of configuration parameter as an int
  public static int getIntConfigParam(String param, int errorValue)
  {
    int retVal = errorValue ;
    String propValStr = GenboreeConfig.getConfigParam(param) ;
    try
    {
      retVal = Integer.parseInt(propValStr) ;
    }
    catch(NumberFormatException nfe)
    {
      if(propValStr == null)
      {
        System.err.println("GenboreeConfig#getIntConfigParam: ERROR => The for property '" + param + "' is MISSING in the config file! ") ;
      }
      else
      {
        System.err.println("GenboreeConfig#getIntConfigParam: ERROR => The value '" + propValStr + "' for property '" + param + "' can't be converted to an int.") ;
      }
      nfe.printStackTrace(System.err) ;
    }
    return retVal ;
  }

  // Get value of configuration parameter as a long
  public static long getLongConfigParam(String param, long errorValue)
  {
    long retVal = errorValue ;
    String propValStr = GenboreeConfig.getConfigParam(param) ;
    try
    {
      retVal = Long.parseLong(propValStr) ;
    }
    catch(NumberFormatException nfe)
    {
      if(propValStr == null)
      {
        System.err.println("GenboreeConfig#getLongConfigParam: ERROR => The for property '" + param + "' is MISSING in the config file! ") ;
      }
      else
      {
        System.err.println("GenboreeConfig#getLongConfigParam: ERROR => The value '" + propValStr + "' for property '" + param + "' can't be converted to a long.") ;
      }
      nfe.printStackTrace(System.err) ;
    }
    return retVal ;
  }

  // For config param whose value is a CSV list, get a HashMap with list elements as the keys (HashMap values all -true-)
  public static HashMap<String,Boolean> getHashFromListConfigParam(String param)
  {
    HashMap<String,Boolean> valueMap = new HashMap() ;
    String propValStr = GenboreeConfig.getConfigParam(param) ;
    try
    {
      String[] csvValues = propValStr.trim().split("\\s*,\\s*") ;
      for(int ii=0; ii<csvValues.length; ii++)
      {
        valueMap.put(csvValues[ii], true);
      }
    }
    catch(Exception ex)
    {
      if(propValStr == null)
      {
        System.err.println("GenboreeConfig#getHashFromListConfigParam: ERROR => The for property '" + param + "' is MISSING in the config file! ") ;
      }
      else
      {
        System.err.println("GenboreeConfig#getHashFromListConfigParam: ERROR => The value '" + propValStr + "' for property '" + param + "' caused a problem making a HashMap from the config value.") ;
      }
      ex.printStackTrace(System.err) ;
    }
    return valueMap ;
  }

  // Get value of a Time Period (HH:MM,length) as a range (array of 2 Calendar times: start and end).
  // - Get instance of Calendar (today)
  // - Set instance time to HH:MM
  // - Get new instance by adding length minutes to that time
  public static Calendar[] getTimePeriodParam(String param)
  {
    Calendar[] timePeriod = new Calendar[2] ;

    // Read the file to get param value as String
    String propValStr = GenboreeConfig.getConfigParam(param) ;
    // Process value
    try
    {
      Pattern timeRE = Pattern.compile("(\\d+)\\s*:\\s*(\\d+)\\s*,\\s*(\\d+)") ;
      Matcher timeREMatcher = timeRE.matcher(propValStr) ;
      boolean reFound = timeREMatcher.find() ;
      int hour = Integer.parseInt(timeREMatcher.group(1)) ;
      int minutes = Integer.parseInt(timeREMatcher.group(2)) ;
      int minutesLength = Integer.parseInt(timeREMatcher.group(3)) ;
      timePeriod[0] = Calendar.getInstance() ;
      timePeriod[0].set(Calendar.HOUR_OF_DAY, hour) ;
      timePeriod[0].set(Calendar.HOUR, (hour == 12 ? 12 : (hour % 12))) ;
      timePeriod[0].set(Calendar.AM_PM, (hour >= 12 ? Calendar.PM : Calendar.AM)) ;
      timePeriod[0].set(Calendar.MINUTE, minutes) ;
      timePeriod[1] = (Calendar)timePeriod[0].clone() ;
      timePeriod[1].add(Calendar.MINUTE, minutesLength) ;
    }
    catch(Exception ex)
    {
      System.err.println("GenboreeConfig#getTimePeriodParam: ERROR => The value '" + propValStr + "' for property '" + param + "' can't be converted to a time period due to an error.\nDetails: " +
                         ex.getMessage()) ;
      ex.printStackTrace(System.err) ;
    }
    return timePeriod ;
  }
}
