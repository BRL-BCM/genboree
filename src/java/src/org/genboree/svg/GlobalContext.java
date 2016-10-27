package org.genboree.svg ;

import org.genboree.util.* ;

import java.io.BufferedReader ;
import java.io.IOException ;
import java.io.InputStream ;
import java.io.InputStreamReader ;
import java.io.File ;
import java.net.URL ;
import java.util.HashMap ;

public class GlobalContext implements Constants
{
  private static final String DEFAULT_CONFIG = "org/genboree/svg/default.xml" ;
  private static XmlConfig config ;
  private static GlobalContext gcontext = null ;
  private HashMap resources = null ;
  private boolean debug = false ;

  private GlobalContext()
  {
    init() ;
  }

  private void init()
  {
    loadUserConfiguration() ;
    if(config == null)
    {
      loadDefaultConfiguration() ; // needs CATALINA_HOME/default.xml
    }
    resources = new HashMap(10) ;
    return ;
  }

  /**
   * Lookup the config element with the given path. Pass in a "/" will return the root config element.
   * @return The configuration element corresponding to the given path.
   */
  public XmlConfig lookupConfigElement(String path)
  {
    return config.lookupConfigElement(path) ;
  }

  /**
   * Get the configuration values from the default config file.
   * @param path The path to the configuration element.
   * @param name The configuration attribute, must not be null.
   * @return The configuration value.
   */
  public String getConfigValue(String path, String name)
  {
    return config.lookupConfigElement(path).getConfigValue(name) ;
  }

  /**
   * Get the configuration values from the default config file.
   * @param path The path to the configuration element.
   * @return The configuration value of the config element.
   */
  public String getConfigValue(String path)
  {
    return config.lookupConfigElement(path).getConfigValue() ;
  }

  /**
   * Load the default configuration file.
   */
  private void loadDefaultConfiguration()
  {
    try
    {
      URL url = getClass().getClassLoader().getResource(DEFAULT_CONFIG) ;
      config = XmlConfig.loadConfiguration(url) ;
    }
    catch(Exception e)
    {
      e.printStackTrace() ;
    }
    return ;
  }

  /**
   * Load the user configuration file.
   */
  private void loadUserConfiguration()
  {
    try
    {
      String preHome = org.genboree.util.Constants.GENBOREE_ROOT + "/htdocs" ;
      String userDir = preHome + "/default.xml" ;
      URL url = (new File(userDir)).toURL() ;
      System.err.println("GlobalContext#loadUserConfiguration() (VGP) => The url is " + url.toString()) ;
      if(url != null)
      {
        config = XmlConfig.loadConfiguration(url) ;
      }
    }
    catch(Exception e)
    {
      e.printStackTrace() ;
    }
    return ;
  }

  /**
   * Return a reference to the global context object.
   * @return
   */
  public static GlobalContext getInstance()
  {
    if(gcontext == null)
    {
      gcontext = new GlobalContext() ;
    }
    return gcontext ;
  }

  /**
   * Retrieve the content of the requested resource file. The requested resource file must be in the
   * current classpath since it is accessed through the ClassLoader.
   * @param resource
   * @return
   * @throws IOException
   */
  public String getFileContentAsString(String resource) throws IOException
  {
    String contents = null ;
    if(debug)
    {
      contents = readFileConentAsString(resource) ;
      resources.put(resource, contents) ;
    }
    else
    {
      if(contents == null)
      {
        contents = readFileConentAsString(resource) ;
        resources.put(resource, contents) ;
      }
    }
    return contents ;
  }

  private String readFileConentAsString(String resource) throws IOException
  {
    InputStream is = this.getClass().getResourceAsStream(resource) ;
    if(is == null)
    {
      throw new IOException("ERROR: GlobalContext#readFileConentAsString(S) (VGP) => Resource not found: " + resource) ;
    }
    BufferedReader br = new BufferedReader(new InputStreamReader(is)) ;
    char buffer[] = new char[1024] ;
    int count = 0 ;
    StringBuffer sb = new StringBuffer() ;
    while((count = br.read(buffer)) != -1)
    {
      sb.append(buffer, 0, count) ;
    }
    is.close() ;
    br.close() ;
    return sb.toString() ;
  }

  public boolean isDebug()
  {
    return debug ;
  }

  public void setDebug(boolean debug)
  {
    this.debug = debug ;
  }

  public static void main(String[] args) throws Exception
  {
    GlobalContext test = new GlobalContext() ;
    String result = test.getConfigValue("/configs/connection_pools/connection_pool/dbname") ;
    XmlConfig ele = test.lookupConfigElement("/configs/connection_pools/connection_pool/dbname") ;
    System.err.println("GlobalContext.main(S[]) (VGP) => The value is " + result) ;
    System.err.println("GlobalContext.main(S[]) (VGP) => From the ele " + ele.getConfigValue()) ;
    return ;
  }
}
