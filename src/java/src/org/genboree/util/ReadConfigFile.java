package org.genboree.util ;

import java.io.* ;
import java.util.Properties ;
import org.genboree.util.* ;

public class ReadConfigFile
{
  protected String fileName = null ;
  protected Properties props = null ;
  protected boolean goodFile = false ;

  // Read the default config file specified in org.genboree.util.Constants
  public ReadConfigFile() throws IOException
  {
    this(GenboreeUtils.getConfigFileName()) ;
    
  }

  // Read the config file provided
  public ReadConfigFile(String propertyFile) throws IOException
  {
    this.fileName = propertyFile ;
    this.loadConfig() ;
  }

  public Properties getProps()
  {
    return props ;
  }

  public boolean getGoodFile()
  {
    return goodFile ;
  }

  public String getFileName()
  {
    return this.fileName ;
  }

  public boolean loadConfig() throws java.io.FileNotFoundException, java.io.IOException
  {
    boolean retVal = false ;
    // If we have a config file name to load
    if(this.fileName != null)
    {
      File configFile = new File(this.fileName) ;
      this.goodFile = configFile.exists() ;
      // If the file exists
      if(this.goodFile)
      {
        this.props = new Properties() ;
        FileInputStream fis = new FileInputStream(configFile) ;
        this.props.load(fis) ;
        retVal = true ;
        fis.close() ;
      }
    }
    return retVal ;
  }
}
