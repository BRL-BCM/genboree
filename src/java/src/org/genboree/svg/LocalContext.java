package org.genboree.svg ;

import org.genboree.svg.imagemap.SVGLinkTree ;
import java.io.IOException ;
import java.util.ArrayList ;
import java.util.HashMap ;

/**
 * This class contains the necessary context information and objects for generating the
 * SVG image for a specific specie, such as a link to the database. It is also used to
 * store the generated SVG content. It is created by the SVGServlet when a client request
 * for the SVG image is received, and passed along to the SVGData objects.
 * After finishing all the process, the cleanUp() method should be called to release any
 * system resources, such as the db connection.
 */
public class LocalContext implements Constants
{
  public static final String LF = System.getProperty("line.separator") ;
  private GlobalContext gContext = null ;
  private StringBuffer svgContent = null ;
  private HashMap colorCodeMap = null ;
  private HashMap colorValueMap = null ;
  private HashMap colorCategory = null ;
  private ArrayList leftDataBlocks = null ;
  private ArrayList rightDataBlocks = null ;
  private boolean debug = false ;
  private boolean useCache = true ;
  private int imageType = -1 ;
  private String chromosome = null ;
  private HashMap userOptions = null ;
  private boolean rasterizeGif = false ;
  private SVGLinkTree svgLinkTree = null ;

  /**
   * Default constructor. It initializes necessary resources to be prepared
   * for the image generation.
   */
  public LocalContext()
{
    gContext = GlobalContext.getInstance() ;
    svgContent = new StringBuffer(2048) ;
    colorCodeMap = new HashMap(24) ;
    colorValueMap = new HashMap(24) ;
    colorCategory = new HashMap(24) ;
  }

  public void cleanup()
{
    return ;
  }
  /**
   * Append the string SVG content to the buffer. The local context maintains an
   * internal buffer to hold all the generated SVG contents.
   * @param content
   */
  public void append(String content)
{
    svgContent.append(content) ;
    return ;
  }

  /**
   * Append a new line to the buffer.
   */
  public void appendLineFeed()
{
    svgContent.append(LF) ;
    return ;
  }

  /**
   * Utility method that appends a SVG tag attribute to the content buffer.
   * @param name
   * @param value
   */
  public void appendTagAttribute(String name, String value)
{
    svgContent.append(' ') ;
    svgContent.append(name) ;
    svgContent.append("=\"") ;
    svgContent.append(value) ;
    svgContent.append('"') ;
    return ;
  }

  public void printContent()
{
    System.err.println("LocalContext#printContent() (VGP) => svg content\n" + this.svgContent) ;
    return ;
  }

  /**
   * Utility method that appends a SVG tag attribute to the content buffer.
   * @param name
   * @param value
   */
  public void appendTagAttribute(String name, int value)
{
    svgContent.append(' ') ;
    svgContent.append(name) ;
    svgContent.append("=\"") ;
    svgContent.append(value) ;
    svgContent.append('"') ;
    return ;
  }

  /**
   * Utitlity method that appends the commonly used x, y, width, height attributes to the content
   * buffer.
   * @param x
   * @param y
   * @param width
   * @param height
   */
  public void appendTagLocationSizeAttributes(int x, int y, int width, int height)
{
    appendTagAttribute("x", x) ;
    appendTagAttribute("y", y) ;
    appendTagAttribute("width", width) ;
    appendTagAttribute("height", height) ;
    return ;
  }

  /**
   * Utility method that appends the string "<"+tagName to the content buffer.
   * The current indentation will be auto incremented.
   * @param tagName
   */
  public void appendTagStart(String tagName)
{
    appendIndentation(INDENT_PLUS) ;
    svgContent.append('<') ;
    svgContent.append(tagName) ;
    return ;
  }

  /**
   * Utility method that appends the string "</"+tagName+">\n" to the content buffer.
   * The current indentation will be auto decremented.
   * @param tagName
   */
  public void appendTagClose(String tagName)
{
    appendIndentation(INDENT_MINUS) ;
    svgContent.append("</") ;
    svgContent.append(tagName) ;
    svgContent.append('>') ;
    svgContent.append(LF) ;
    return ;
  }

  /**
   * Utility method that append the string ">\n" to the content buffer. The current
   * indentation is not affected.
   */
  public void appendTagStartEnd()
{
    svgContent.append('>') ;
    svgContent.append(LF) ;
    return ;
  }

  /**
   * Append the configuration value identified by the path to the SVG content.
   * @param path
   */
  public void appendConfigValue(String path)
{
    svgContent.append(gContext.getConfigValue(path)) ;
  }

  /**
   * Retrieve the generated SVG content from the buffer. No more content should be appended to the buffer
   * after this method is called to improve the performance.
   * @return
   */
  public String getSVGContent()
{
    return svgContent.toString() ;
  }

  /**
   * Retrieves the config value indentified by the path from the config file
   * @return
   */
  public String getConfigValue(String path)
{
    return gContext.getConfigValue(path) ;
  }

  /**
   * Retrieve the content of the requested resource file. The requested resource file must be in the
   * current classpath since it is accessed through the ClassLoader.
   * @param resource
   * @return
   * @throws java.io.IOException
   */
  public String getFileContentAsString(String resource) throws IOException
  {
    return gContext.getFileContentAsString(resource) ;
  }

  /**
   * Put the color_id/color_code into the cache. The color_id corresponds to the fname.fname_id in the database,
   * while the color_code corresponds to the fname.fname_color in the database.
   * @param id
   * @param color
   */
  public void putColorCode(String id, String color)
  {
    colorCodeMap.put(id, color) ;
  }

  /**
   * Retrieve previously saved color code by its id.
   * @param id
   * @return
   */
  public String getColorCode(String id)
  {
    return (String) colorCodeMap.get(id) ;
  }

  /**
   * Put the color_id/color_value into the cache. The color_id corresponds to the fname.fname_id in the database,
   * while the color_value corresponds to the fname.fname_value in the database.
   * @param id
   * @param value
   */
  public void putColorValue(String id, String value)
  {
    colorValueMap.put(id, value) ;
  }

  /**
   * Retrieve previously saved color value by its id.
   * @param id
   * @return
   */
  public String getColorValue(String id)
  {
    return (String) colorValueMap.get(id) ;
  }

  public void putColorCategory(String id, String value)
  {
    this.colorCategory.put(id, value) ;
  }

  /**
   * Retrieve previously saved color value by its id.
   * @param id
   * @return
   */
  public String getColorCategory(String id)
  {
    return (String) colorCategory.get(id) ;
  }

  /**
   * Set the annotation data blocks at the left side of the chromosome drawing.
   * @param leftDataBlocks
   */
  public void setLeftDataBlocks(ArrayList leftDataBlocks)
  {
    this.leftDataBlocks = leftDataBlocks ;
  }

  /**
   * Retrieve back the annotation data blocks at the left side of the chromosome drawing.
   * @return
   */
  public ArrayList getLeftDataBlocks()
  {
    return this.leftDataBlocks ;
  }

  /**
   * Set the annotation data blocks at the right side of the chromosome drawing.
   * @param rightDataBlocks
   */
  public void setRightDataBlocks(ArrayList rightDataBlocks)
  {
    this.rightDataBlocks = rightDataBlocks ;
  }

  /**
   * Retrieve back the annotation data blocks at the right side of the chromosome drawing.
   * @return
   */
  public ArrayList getRightDataBlocks()
  {
    return this.rightDataBlocks ;
  }

  /**
   * Returns the option if a cache should be used when possible.
   * @return
   */
  public boolean isUseCache()
  {
    return useCache ;
  }

  /**
   * Get the single chromosome that should be displayed.
   * @return null if all chromosomes should be drawn.
   */
  public String getChromosome()
  {
    return chromosome ;
  }

  /**
   * Set the single chromosome that should be displayed.
   * @param chromosome
   */
  public void setChromosome(String chromosome)
  {
    this.chromosome = chromosome ;
  }

  /**
   * Test if all chromosomes of this specie should be drawn, or only
   * a single chromosome should be drawn.
   * @return
   */
  public boolean singleChromosomeOnly()
  {
    return chromosome != null ;
  }

  /**
   * Get the user settings
   * @return
   */
  public HashMap getUserOptions()
  {
    return userOptions ;
  }

  /**
   * Set the user settings
   * @param userOptions
   */
  public void setUserOptions(HashMap userOptions)
  {
    this.userOptions = userOptions ;
  }

  /**
   * Sets the option if a cache should be used when possible. Each time when a SVG image is generated,
   * it is saved in the database as cache so it does not need to be generated again if the data is not changed.
   * @param useCache
   */
  public void setUseCache(boolean useCache)
  {
    this.useCache = useCache ;
  }

  public boolean willRasterizeGif()
  {
    return rasterizeGif ;
  }

  public void setRasterizeGif(boolean rasterizeGif)
  {
    this.rasterizeGif = rasterizeGif ;
  }

  public SVGLinkTree getSvgLinkTree()
  {
    return svgLinkTree ;
  }

  public void setSvgLinkTree(SVGLinkTree svgLinkTree)
  {
    this.svgLinkTree = svgLinkTree ;
  }

  // Provide utility methods for proper indentation of the SVG doc
  /**
   * Indentation size the same as the current indentation level.
   */
  public final int INDENT_SAME = 0 ;
  /**
   * Increase the current indentation level.
   */
  public final int INDENT_PLUS = 1 ;
  /**
   * Decrease the current indentation level.
   */
  public final int INDENT_MINUS = 2 ;
  private final String INDENTATION = "   " ;
  private int indentLevel = 0 ;

  /**
   * Append the indentation according to the current indentaion level.
   */
  public void appendIndentation()
  {
    appendIndentation(INDENT_SAME) ;
  }

  /**
   * Append the indentation. If the type is INDENT_SAME, the indentation will be the same as
   * the current indentation level. If the type is INDENT_PLUS, the current indentation level
   * is increased by one level and the result indentation will be appended. If the type is
   * INDENT_MINUS, the current indentation is appended first and then the current indentaion
   * level is decreased by one level.
   * @param type
   */
  public void appendIndentation(int type)
  {
    switch(type)
    {
      case INDENT_PLUS:
        indentLevel++ ;
        applyIndentation() ;
        break ;
      case INDENT_MINUS:
        applyIndentation() ;
        indentLevel = indentLevel > 0 ? indentLevel - 1 : 0 ;
        break ;
      default:
        applyIndentation() ;
        break ;
    }
    return ;
  }

  private void applyIndentation()
  {
    for(int i = 0 ; i < indentLevel ; i++)
    {
      append(INDENTATION) ;
    }
    return ;
  }

  /**
   * Change the current indentation level. No indentation is appended to the svg buffer.
   * @param type
   */
  public void changeIndentation(int type)
  {
    switch (type)
    {
      case INDENT_PLUS:
        indentLevel++ ;
        break ;
      case INDENT_MINUS:
        indentLevel-- ;
        break ;
      default:
        break ;
    }
    return ;
  }

  /**
   * Test if the debug mode is enabled.
   * @return
   */
  public boolean isDebug()
  {
    return debug ;
  }

  /**
   * Set the debug mode.
   * @param debug
   */
  public void setDebug(boolean debug)
  {
    this.debug = debug ;
    if(gContext != null)
    {
      gContext.setDebug(true) ;
    }
    return ;
  }

  /**
   * Set the type of the image that will be drawn.
   * @param imageType
   */
  public void setImageType(int imageType)
  {
    this.imageType = imageType ;
  }

  /**
   * Get the type of the image that will be drawn.
   * @return
   */
  public int getImageType()
  {
    return imageType ;
  }

  /**
   * Get the ImageRequirements object for the svg image currently been drawn.
   * @return
   */
  public ImageRequirements getImageRequirements()
  {
    return ImageDrawingFactory.getImageRequirements(imageType, userOptions) ;
  }
}
