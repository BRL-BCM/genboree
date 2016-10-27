package org.genboree.util ;

import org.jdom.Comment ;
import org.jdom.Document ;
import org.jdom.Element ;
import org.jdom.input.SAXBuilder ;
import org.jdom.output.XMLOutputter ;

import java.io.File ;
import java.io.FileWriter ;
import java.io.IOException ;
import java.net.JarURLConnection ;
import java.net.URI ;
import java.net.URISyntaxException ;
import java.net.URL ;
import java.util.List ;
import java.util.Iterator ;
import java.util.ArrayList ;

/**
 * <p>
 * Read/Write XML based configuration files easily with this class. Use either a absolute path string,
 * like "/tagname/childtagname", or a relative path string, like "childtagname/grandchild", to retrieve
 * a config element or a array of config elements. Then invoke the method getConfigValue() without
 * parameters to retrieve the tag text content, or with parameter to retrieve the tag attribute value.
 *
 * <p>
 * Sample usage:
 * <code>
 *    URL url = getClass().getClassLoader().getResource("com/packagename/default_config.xml") ;
 *   XmlConfig config = XmlConfig.loadConfiguration(url) ;
 *   String value = config.lookupConfigElement("/root/config1").getConfigValue("attribute1") ;
 * </code>
 * Note: the inital XmlConfig object returned by the loadConfiguration() method points to the root element.
 * Author: alanf
 * Date: Apr 15, 2003
 */
public class XmlConfig
{
  private File file = null ;
  private URL url = null ;
  private Element element = null ;

  /**
   * Return the first configuration element that matches the path string.
   * @param path
   * @return null if no element found with the given path.
   */
  public XmlConfig lookupConfigElement(String path)
  {
    if(path == null)
    {
      throw new NullPointerException("ERROR: XmlConfig#lookupConfigElement(S) (VGP) => Path to the configuration element is null!") ;
    }
    Element e = locateElement(path) ;
    return (e == null ? null : new XmlConfig(e, this)) ;
  }

  private Element locateRootElement()
  {
    if(element.isRootElement())
    {
      return element ;
    }
    Document doc = element.getDocument() ;
    if(doc != null)
    {
      return doc.getRootElement() ;
    }
    Element e = element ;
    while (e.getParent() != null)
    {
      e = e.getParent() ;
    }
    return e ;
  }

  private Element locateElement(String path)
  {
    //        assert path != null : "Path to the configuration element is null!" ;
    if(path.equals("/"))
    {
      return element.getDocument().getRootElement() ;
    }
    StringBuffer sb = new StringBuffer(path) ;
    Element walker = null ;
    //decide the starting navigation point.
    if(sb.charAt(0) == '/')
    {
      sb.deleteCharAt(0) ;
      //match the root element
      Element root = locateRootElement() ;
      int pos = sb.toString().indexOf('/') ;
      String tagName = pos < 0 ? sb.toString() : sb.substring(0, pos) ;
      if(pos < 0)
      {
        return root.getName().equals(tagName) ? root : null ;
      }
      sb.delete(0, pos + 1) ; //delete the root tagname and the '/' from the path
      walker = root ;
    }
    else
    {
      walker = element ;
    }

    for(int i = 0 ; i < sb.length() ; i++)
    {
      if(sb.charAt(i) == '/')
      {
        String childName = sb.substring(0, i) ;
        walker = walker.getChild(childName) ;
        if(walker == null)
        {
          return null ;
        }
        sb.delete(0, i) ; //this removes the child tag name
        sb.deleteCharAt(0) ; //this removes the '/' character
        i = 0 ;
      }
    }
    if(sb.length() > 0)
    {
      //the last tag name that is not ended with /
       walker = walker.getChild(sb.toString()) ;
    }
    return walker ;
  }

  /**
   * Return the configuration value of the specified config element. The string
   * returned is the text value of this xml config element.
   * @return
   */
  public String getConfigValue()
  {
    return element.getText() ;
  }

  /**
   * Return the configuration value of the specified config element as an integer. The string
   * returned is the text value of this xml config element.
   * @return
   */
  public int getConfigValueAsInt()
  {
    return Integer.parseInt(getConfigValue()) ;
  }

  /**
   * Return the configuration value of the specified config element as a boolean. The string
   * returned is the text value of this xml config element.
   * @return
   */
  public boolean getConfigValueAsBoolean()
  {
    return "true".equalsIgnoreCase(getConfigValue()) ;
  }

  /**
   * Return the configuration value of the specified attribute. The attribute name
   * can not be null.
   * @param attributeName
   * @return
   */
  public String getConfigValue(String attributeName)
  {
    if(attributeName == null)
    {
      throw new NullPointerException("ERROR: XmlConfig.getConfigValue(S) (VGP) => The attribute name is null!") ;
    }
    return element.getAttributeValue(attributeName) ;
  }

  /**
   * Return the configuration value of the specified attribute as an integer. The attribute name
   * can not be null.
   * @param attributeName
   * @return
   */
  public int getConfigValueAsInt(String attributeName)
  {
    return Integer.parseInt(getConfigValue(attributeName)) ;
  }

  /**
   * Return the configuration value of the specified attribute as a boolean. The attribute name
   * can not be null.
   * @param attributeName
   * @return
   */
  public boolean getConfigValueAsBoolean(String attributeName)
  {
    return "true".equalsIgnoreCase(getConfigValue(attributeName)) ;
  }

  /**
   * Return all configuration elements that matches the path string.
   * @param path
   * @return
   */
  public XmlConfig[] lookupAllConfigElements(String path)
  {
    if(path == null)
    {
      throw new NullPointerException("ERROR: XmlConfig.lookupAllConfigElements(S) (VGP) => Path to the configuration element is null!") ;
    }
    else if(path.equals("/"))
    {
      return new XmlConfig[]{new XmlConfig(locateRootElement(), this)} ;
    }
    else if(path.endsWith("/"))
    {
      path = path.substring(0, path.length() - 1) ;
    }
    Element e = null ;
    //locate the parent of the target config element
    int idx = path.lastIndexOf('/') ;
    if(idx > 0)
    {
      e = locateElement(path.substring(0, idx)) ;
      if(e == null)
      {
        return new XmlConfig[0] ;
      }
    }
    else
    {
      e = element ;
    }

    // now find all children
    String childName = idx > 0 ? path.substring(idx + 1) : path ;
    List list = e.getChildren(childName) ;
    XmlConfig[] configs = new XmlConfig[list.size()] ;
    for(int i = 0 ; i < list.size() ; i++)
    {
      Element child = (Element) list.get(i) ;
      configs[i] = new XmlConfig(child, this) ;
    }
    return configs ;
  }

  public XmlConfig[] getChildren()
  {
    Iterator iter = element.getChildren().iterator() ;
    ArrayList children = new ArrayList() ;
    while(iter.hasNext())
    {
      Element child = (Element) iter.next() ;
      XmlConfig xc = new XmlConfig(child, this) ;
      children.add(xc) ;
    }
    XmlConfig[] arr = new XmlConfig[children.size()] ;
    children.toArray(arr) ;
    return arr ;
  }

  /**
   * Add comments under the current config element.
   * @param comments
   */
  public void addConfigComments(String comments)
  {
    element.addContent(new Comment(comments)) ;
  }

  /**
   * Set the configuration value for the current configuration element. The value is saved
   * as the text value of the xml config element.
   * @param value
   */
  public void setConfigValue(String value)
  {
    element.setText(value) ;
  }

  /**
   * Set the configuration value. The configuration attribute name can not be null.
   * @param attributeName
   * @param value
   */
  public void setConfigValue(String attributeName, String value)
  {
    if(attributeName == null)
    {
      throw new NullPointerException("ERROR: XmlConfig.setConfig(S,S) (VGP) => The configuration attribute name is null!") ;
    }
    element.setAttribute(attributeName, value) ;
    return ;
  }

  /**
   * Adds a configuration element as the child of the current element
   * @param child
   */
  public void addChildConfig(XmlConfig child)
  {
    element.addContent(child.element) ;
  }

  /**
   * Remove the current cnfiguration element from the configuration tree.
   */
  public void removeCurrentConfig()
  {
    element.detach() ;
  }

  /**
   * Returns the parent configuration element.
   * @return
   */
  public XmlConfig getParent()
  {
    Element e = element.getParent() ;
    return e == null ? null : new XmlConfig(e, this) ;
  }

  /**
   * Returns the root configuration element.
   * @return
   */
  public XmlConfig getRoot()
  {
    Element e = locateRootElement() ;
    return e == null ? null : new XmlConfig(e, this) ;
  }

  /**
   * Set the name of the configuration element (the xml tagname).
   * @param name
   */
  public void setName(String name)
  {
    element.setName(name) ;
  }

  /**
   * Get the name of the configuration element (the xml tagname).
   * @return
   */
  public String getName()
  {
    return element.getName() ;
  }

  /**
   * Test if the current configuration element is the root of the configuration tree.
   * @return
   */
  public boolean isRoot()
  {
    Element e = locateRootElement() ;
    return e == element ;
  }

  /**
   * Return a new XmlConfig instance.
   * @param name
   * @return
   */
  public static XmlConfig newConfigElement(String name)
  {
    return new XmlConfig(name) ;
  }

  /**
   * Loads a configuration tree from a disk file.
   * @param fname
   * @return The inital XmlConfig object returned by the loadConfiguration() method which points to the root element.
   */
  public static XmlConfig loadConfiguration(String fname) throws Exception
  {
    if(fname == null)
    {
      throw new NullPointerException("ERROR: XmlConfig.loadConfiguration(S) (VGP) => Configuration filename is null!") ;
    }
    return loadConfiguration(new File(fname)) ;
  }

  /**
   * Loads a configuration tree from a disk file.
   * @param file
   * @return The inital XmlConfig object returned by the loadConfiguration() method which points to the root element.
   */
  public static XmlConfig loadConfiguration(File file) throws Exception
  {
    if(file == null)
    {
      throw new NullPointerException("ERROR: XmlConfig.loadConfiguration(F) (VGP) => Configuration file is null!") ;
    }
    Element root = new SAXBuilder().build(file).getRootElement() ;
    XmlConfig config = new XmlConfig() ;
    config.element = root ;
    config.file = file ;
    return config ;
  }

  /**
   * Loads a configuration tree from a URL.
   * @param url
   * @return The inital XmlConfig object returned by the loadConfiguration() method which points to the root element.
   */
  public static XmlConfig loadConfiguration(URL url) throws Exception
  {
    if(url == null)
    {
      throw new NullPointerException("ERROR: XmlConfig.loadConfiguration(U) (VGP) => Configuration url is null!") ;
    }
    Element root = new SAXBuilder().build(url).getRootElement() ;
    XmlConfig config = new XmlConfig() ;
    config.element = root ;
    config.url = url ;
    return config ;
  }

  /**
   * Saves the current configuration tree to its original location, overwrites the file if
   * it already exists.
   */
  public void saveConfiguration() throws Exception
  {
    if(file == null && url == null)
    {
      throw new NullPointerException("ERROR: XmlConfig.saveConfiguration() (VGP) => Can not save configuration: no location was specified!") ;
    }

    File f = file ;
    if(f == null)
    {
      f = getFileFromURL(url) ;
    }

    if(f == null)
    {
      throw new IllegalArgumentException("ERROR: XmlConfig.saveConfiguration() (VGP) => Failed to open the output file!") ;
    }

    Document doc = element.getDocument() ;
    if(doc == null)
    {
      Element e = null ;
      while((e = element.getParent()) != null)
      {
        element = e ;
      }
      doc = new Document(element) ;
    }
    XMLOutputter outputter = new XMLOutputter("    ", true) ;
    FileWriter writer = new FileWriter(f) ;
    outputter.output(doc, writer) ;
    writer.close() ;
    return ;
  }

  /**
   * Saves the current configuration tree to the specified file, overwrites the file if
   * it already exists.
   */
  public void saveConfiguration(String fname) throws Exception
  {
    file = new File(fname) ;
    saveConfiguration() ;
  }

  private XmlConfig()
  {
  }

  private XmlConfig(String name)
  {
    element = new Element(name) ;
  }

  private XmlConfig(Element e, XmlConfig caller)
  {
    this.element = e ;
    //make sure the file or the url is passed on
    this.file = caller.file ;
    this.url = caller.url ;
  }

  private static File getFileFromURL(URL url)
  {
    if("jar".equals(url.getProtocol()))
    {
      try
      {
        JarURLConnection jarCon = (JarURLConnection) url.openConnection() ;
        url = jarCon.getJarFileURL() ;
      }
      catch (IOException e)
      {
        e.printStackTrace() ;
      }
    }
    URI uri = null ;
    try
    {
      uri = new URI(url.toExternalForm()) ;
    }
    catch(URISyntaxException se)
    {
      se.printStackTrace() ;
      throw new IllegalArgumentException("ERROR: XmlConfig.getFileFromURL(U) (VGP) => Invalid syntax when parsing the resource string to the URI class.") ;
    }
    return new File(uri.getPath()) ;
  }

  public static void main(String[] args) throws Exception
  {
    URL url = ClassLoader.getSystemClassLoader().getResource("com/test.xml") ;
    XmlConfig src = XmlConfig.loadConfiguration(url) ;
    XmlConfig dest = XmlConfig.newConfigElement(src.getName()) ;
    dest.setConfigValue("attr1", src.getConfigValue("attr1")) ;
    dest.setConfigValue("attr2", src.getConfigValue("attr2")) ;

    XmlConfig[] configs = src.lookupAllConfigElements("/root/A/") ;
    for(int i = 0 ; i < configs.length ; i++)
    {
      XmlConfig ele = configs[i] ;
      XmlConfig xc = XmlConfig.newConfigElement(ele.getName()) ;
      xc.setConfigValue("name", ele.getConfigValue("name")) ;
      if(ele.getConfigValue("other") != null)
      {
        xc.setConfigValue("other", ele.getConfigValue("other")) ;
      }
      xc.setConfigValue(ele.getConfigValue().trim()) ;
      ele = ele.lookupConfigElement("layout") ;
      XmlConfig xc2 = XmlConfig.newConfigElement(ele.getName()) ;
      if(ele.getConfigValue("newAtt") != null)
      {
        xc2.setConfigValue("newAtt", ele.getConfigValue("newAtt")) ;
      }
      xc2.setConfigValue(ele.getConfigValue().trim()) ;
      xc.addConfigComments("Comments before") ;
      xc.addChildConfig(xc2) ;
      xc.addConfigComments("Comments after") ;
      dest.addChildConfig(xc) ;
    }

    XmlConfig xc = XmlConfig.newConfigElement("comments") ;
    xc.addConfigComments("Some comments 1st") ;
    xc.setConfigValue("<!-- This is a comments for the sub elements of the element comments -->") ;
    xc.addConfigComments("Some comments") ;
    dest.addChildConfig(xc) ;
    dest.saveConfiguration("c:\\temp\\sample1a.xml") ;
    System.out.println("done!") ;
  }
}
