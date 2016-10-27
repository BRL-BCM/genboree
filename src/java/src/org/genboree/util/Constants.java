
// ============================================================================
// GENBOREE CONSTANTS FILE
// ============================================================================
// ARJ 8/22/2005 4:35PM:
// ============================================================================
// This file is a collection of constants used in Genboree Java code and JSPs.
//
// The idea is to:
// (1) Use constants rather than hard-coding primitive values.
// (2) Use somewhat descriptive names.
// (3) Put constant *together* in one place so you don't have to go searching
//     around 12 files to find all the relevant constants
// (4) *Categorize* the constants, so we can find what we need via search/scan
// (5) Comment the constants, so others know what they are for and use them.
//
// Standard:
// (1) All constants are UPPER_CASE
// (2) Constants are public static final
// (3) Genboree constants start with "GB_". No collisions will occur.
// (4) Constant Arrays are done by the unmutatble method as described at:
//     http://www.javapractices.com/Topic2.cjp

package org.genboree.util ;

import java.util.regex.Pattern ;

/**
* Colleciton of Genboree constants used in Java and JSP files.
*
* used  By any Genboree JSP or Java file.
* @author Andrew R Jackson
*/
public final class Constants
{
  // --------------------------------------------------------------------------
  //    STATIC URL
  // - Controls redirecting from a old machine name to real url.
  // -------------------------------------------------------------------------
  // First thing must be: Config file...better constant name to go with better file name. Old one kept around for backward compatibility.
  public static final String GENBOREE_CONFIG_FILE = GenboreeUtils.getConfigFileName() ; 
  public static final String DBACCESS_PROPERTIES = GENBOREE_CONFIG_FILE ;
  public static final String badPattern  = GenboreeUtils.getBadPattern() ;
  public static final Pattern compiledBadPattern= Pattern.compile(badPattern , Pattern.MULTILINE | Pattern.DOTALL) ;
  public static final String REDIRECTTO = GenboreeUtils.getNameLocalMachine() ;
  public static final String GROUP_X_HEADER = "X-GENBOREE-GROUP" ;
  public static final String DATABASE_X_HEADER = "X-GENBOREE-DATABASE" ;
  public static final String USER_X_HEADER = "X-GENBOREE-USER" ;
  public static final String SESSION_GROUP_NAME = "currGroupName" ;
  public static final String SESSION_DATABASE_NAME = "currDatabaseName" ;
  public static final String SESSION_GROUP_ID = "currGroupID" ;
  public static final String SESSION_DATABASE_ID = "currDatabaseID" ;
  public static final String SESSION_PROJECT_NAME = "currProjectName" ;
  public static final String SESSION_PROJECT_ID = "currProjectID" ;
  // --------------------------------------------------------------------------
  // EMAIL SETTINGS
  // --------------------------------------------------------------------------
  // Generally DON'T USE THIS: if in the config file, alwasy read dynamically from the config file.
  // This avoids having to recompile if something is changed. Making them constants is harder to maintain and requires restarts!!
  // We do it here to avoid breaking existing uses...but are tryign to remove these constants from the code.
  public static final String GB_SMTP_HOST      = GenboreeConfig.getConfigParam("gbSmtpHost") ;
  public static final String GB_FROM_ADDRESS   = GenboreeConfig.getConfigParam("gbFromAddress") ;
  public static final String GB_BCC_ADDRESS    = GenboreeConfig.getConfigParam("gbBccAdress") ;

  // --------------------------------------------------------------------------
  // GBROWER RELATED
  // - Especially having to do with the browser interface.
  // --------------------------------------------------------------------------
  public static final int GB_MAX_FREF_FOR_DROPLIST = 100 ;                        // Max number of EntryPoints before abandoning the droplist for an input box.

  // --------------------------------------------------------------------------
  // MY DATABASES RELATED
  // --------------------------------------------------------------------------
  public static final int GB_MAX_FREF_FOR_EDIT = 100 ;                           //  Max number of EntryPoints user can edit via Genboree (otherwise no editing)
  public static final int GB_MAX_FREF_FOR_LIST = 100 ;                           // Max number of EntryPoints to list on a page (eg My Databases page)
  public static final String GB_FASTA_EP_FILE = "Fasta" ;                           // Value for fasta-formatted entrypoint file
  public static final String GB_LFF_EP_FILE = "3colLff" ;                               // Value for lff-formatted entrypoint file
  public static final String GB_WIG_EP_FILE = "WIG" ;                               // Value for wig-formatted entrypoint file
  protected static String[] genboreeTables = { "fdata2", "fref", "ftype", "ftype2gclass", "gclass","color", "fdata2_cv", "fdata2_gv", "featuredisplay", "featuresort", "featuretocolor", "featuretolink", "featuretostyle", "featureurl", "fidText", "fmeta", "image_cache", "link", "rid2ridSeqId", "ridSequence", "style", "ftypeCount"};

  // --------------------------------------------------------------------------
  // MAX NUMBER OF ANNOTATIONS CAN BE EDITED IN THE FIRST VERSION OF ANNOTATION EDITOR

  // --------------------------------------------------------------------------
  public static final int GB_MAX_ANNO_FOR_DISPLAY = 10000;                        // Max number of EntryPoints before abandoning the droplist for an input box.
  public static final int GB_MIN_ANNO_FOR_DISPLAY_WARN = 1000;                        // Max number of EntryPoints before abandoning the droplist for an input box.


  // ------------------------------------------------------------------------------
  // DIRECTORY LOCATION
  // ------------------------------------------------------------------------------

  public static final String GENBOREE_ROOT =  "/usr/local/brl/local/apache";
  public static final String GENBOREE_HTDOCS = GENBOREE_ROOT  + "/htdocs/";
  public static final String UPLOADDIRNAME = GENBOREE_HTDOCS + "/genboreeUploads";


  public static final String LOCKFILEDIR = "/usr/local/brl/data/genboree/lockFiles/";
  public static final String SEQUENCESDIR = "/usr/local/brl/data/genboree/ridSequences/";
  public static final String GB_RID_SEQUENCE_DIR_BASE = "/usr/local/brl/data/genboree/ridSequences" ;
  public static final String GB_PROJECTS_DIR = "/usr/local/brl/data/genboree/projects" ;

  // --------------------------------------------------------------------------
  // PROPERTIES LOCATIONS
  // --------------------------------------------------------------------------
  public static final String LFFMERGER_MULTILEVEL = GENBOREE_ROOT + "/ruby/conf/lffMerger_multiLevel.VGP.properties";
  public static final String LFFMERGER_NOMERGE = GENBOREE_ROOT + "/ruby/conf/lffMerger.VGP.noMerge.properties";
  public static final String LFFMERGER_2REFSEQ_DENSE = GENBOREE_ROOT + "/ruby/conf/lffMerger_multiLevel.VGP.2RefSeq.Dense.properties";
  public static final String LFFMERGER_2REFSEQ_SPARSE = GENBOREE_ROOT + "/ruby/conf/lffMerger_multiLevel.VGP.2RefSeq.Sparse.properties";
  public static final String LFFMERGER_1REFSEQ_DENSE = GENBOREE_ROOT + "/ruby/conf/lffMerger_multiLevel.VGP.1RefSeq.Dense.properties";
  public static final String LFFMERGER_1REFSEQ_SPARSE = GENBOREE_ROOT + "/ruby/conf/lffMerger_multiLevel.VGP.1RefSeq.Sparse.properties";
  public static final String LFFMERGER_ALREADYMERGED = GENBOREE_ROOT + "/ruby/conf/lffMerger.VGP.noMerge.AlreadyMerged.properties";
  public static final String MAGICFILE = GENBOREE_ROOT + "/magic.genboree";

  // --------------------------------------------------------------------------
  // PROGRAM LOCATIONS
  // --------------------------------------------------------------------------
  // This is NOT SMART. Program locations hard-coded; such things can change, especially as the
  // architecture of the file system is cleaned up and made more sensible. Rather, make sure the
  // PATH environment is set appropriately and can find these programs...then remove the directory
  // locations.
  public static final String GBROWSER = "/usr/local/brl/local/apache/htdocs/webapps/java-bin/WEB-INF/myTest.exe";
  public static final String RUBY = "/usr/local/brl/local/bin/ruby";
  public static final String RUBYLIB = "/usr/local/brl/local/lib/ruby/site_ruby/1.8";
  public static final String LFFMERGEWRAPPER = GENBOREE_ROOT + "/ruby/brl/genboree/lffMergeWrapper.rb";
  public static final String LFFCOMBINECMDPATH = "lffCombine.rb" ;
  public static final String LFFINTERSECTCMDPATH = "lffIntersect.rb" ;
  public static final String LFFNONINTERSECTCMDPATH = "lffNonIntersect.rb" ;
  public static final String LFFVALIDATOR = GENBOREE_ROOT + "/ruby/brl/fileFormats/LFFValidator.rb";
  public static final String BLAT2LFF = RUBY + " " + GENBOREE_ROOT + "/ruby/brl/formatMapper/blat2lff.rb -b ";
  public static final String BLAST2LFF = RUBY + " " + GENBOREE_ROOT + "/ruby/brl/formatMapper/blast2lff.rb ";
  public static final String GFF2LFF = RUBY + " " + GENBOREE_ROOT + "/ruby/brl/formatMapper/gff2lff.rb ";
  public static final String AGILENT2LFF = RUBY + " /usr/local/brl/local/bin/agilent2lff.rb ";
  public static final String PASHTWO2LFF = "pashTwo2lff.rb";
  public static final String WIGUPLOAD = "importWiggleInGenboree.rb";
  public static final String GB_RUBY = RUBY ;
  public static final String GB_FASTA_UPLOADER = GENBOREE_ROOT + "/ruby/brl/genboree/seqImporter.rb" ;
  public static final String GB_GZIP  = "/bin/gzip" ;
  public static final String UNZIPUTIL = "/usr/bin/unzip";
  public static final String BUNZIPUTIL = "/usr/bin/bunzip2";
  public static final String GUNZIPUTIL = "/usr/bin/gunzip";
  public static final String VERIFYZIP = "/usr/bin/zip";
  public static final String VERIFYGZIP = "/usr/bin/gzip";
  public static final String VERIFYBZIP = "/usr/bin/bzip2";
  public static final String FILEUTIL = GenboreeConfig.getConfigParam("fileCmd");
  public static final String JAVAEXEC = "/usr/local/brl/local/jdk/bin/java";
  public static final String GENBTASKWRAPPERPATH = "/usr/local/brl/local/lib/ruby/site_ruby/1.8/brl/genboree/tasks/genbTaskWrapper.rb";                                                                                                                                                                               
  public static final String UPLOADERCLASSPATH = " -classpath /usr/local/brl/local/apache/htdocs/common/lib/servlet-api.jar:/usr/local/brl/local/apache/htdocs/common/lib/mysql-connector-java.jar:/usr/local/brl/local/apache/htdocs/common/lib/activation.jar:/usr/local/brl/local/apache/htdocs/common/lib/mail.jar:/usr/local/brl/local/apache/htdocs/webapps/java-bin/WEB-INF/lib/GDASServlet.jar ";
  public static final String UPLOADERCLASS = " -Xmx1800M org.genboree.upload.AutoUploader ";
  public static final String TRACKDELETERCLASS = " -Xmx1800M org.genboree.util.TrackDeleter ";
  public static final String FASTAFILEUPLOADERCLASS = " -Xmx1800M org.genboree.upload.FastaEntrypointUploader ";
  public static final long PENDING_STATE = 2 ;
  public static final long RUNNING_STATE = 4 ;
  public static final long FAIL_STATE = 1 ;
  public static final long PUBLIC_STATE = 256 ;
  public static final int TRACK_PERMISSION = 2 ;

  // --------------------------------------------------------------------------
  // OTHER LOCATIONS
  // --------------------------------------------------------------------------

  // --------------------------------------------------------------------------
  // REST-API RELATED
  // --------------------------------------------------------------------------
  public static final String GB_BAD_REQUEST_MSG = "A request for data from the Genboree server was not correctly constructed." ;
  public static final String GB_BAD_REQUEST_DMSG = "Bad Request format. API URL doesn't match any known service or is missing required parameters. Check construction." ;
  public static final String GB_FORBIDDEN_MSG = "A request for data from the Genboree server was denied access. You may not have permission to access/change the resource." ;
  public static final String GB_FORBIDDEN_DMSG = "Forbidden because user info either not provided or user doesn't have access to the resource. Used from within Genboree: did the session timeout?" ;

  // ------------------------------------------------------------------
  // DISPLAY CONFIGURATION FLAGS (BIT MASKS)
  // ------------------------------------------------------------------
  public static final int DISPLAY_FTYPEATTRNAME_AND_VALUE = 1 ;
  

}
