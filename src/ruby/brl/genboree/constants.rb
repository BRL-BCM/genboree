
module BRL ; module Genboree

module Constants

  #--------------------------------------------------------------------------
  # GLOBALS
  #--------------------------------------------------------------------------
  CATALINA_HOME = ENV['CATALINA_HOME']
  CATALINA_WEBAPPS = "#{CATALINA_HOME}/webapps"
  FATAL, OK, OK_WITH_ERRORS, FAILED, USAGE_ERR = 1,0,10,20,16

  #--------------------------------------------------------------------------
  # 'STATE' CONSTANTS
  # - generally for the 'state' column in DB tables. See Constants.java also.
  #--------------------------------------------------------------------------
  FAIL_STATE = 1 ;
  PENDING_STATE = 2 ;
  RUNNING_STATE = 4 ;
  PUBLIC_STATE = 256 ;
  IS_TEMPLATE_STATE = 65536 ;
  IS_COMPLETED_STATE = 131072 ;

  #--------------------------------------------------------------------------
  # Display Constants
  # - should eventually be moved to a config file
  #--------------------------------------------------------------------------
  TRACK_DISPLAY_TYPES = ['Expand', 'Compact', 'Hidden', 'Multicolor', 'Expand with Names', 'Expand with Comments']

  #--------------------------------------------------------------------------
  # LOCATIONS
  #--------------------------------------------------------------------------
  GB_PROJECTS_DIR = "/usr/local/brl/data/genboree/projects"
  GENBOREE_ROOT =  "/usr/local/brl/local/apache"
  GENBOREE_HTDOCS = GENBOREE_ROOT  + "/htdocs";
  UPLOADDIRNAME = GENBOREE_HTDOCS + "/genboreeUploads";

  #----------------------------------------------------------------------------
  # PROJECT-SPECIFIC CONSTANTS
  #----------------------------------------------------------------------------
  # Ion Channel
  IONCHANNEL_DOMAIN = "test2.proline.brl.bcm.tmc.edu"
  IONCHANNEL_DATA_DIR = "/usr/local/brl/home/genbadmin/www/lighttpd/docroots/#{IONCHANNEL_DOMAIN}"

  #----------------------------------------------------------------------------
  # Command Utils
  #----------------------------------------------------------------------------
  FILEUTIL = "/usr/local/brl/local/bin/file"
  MAGICFILE = GENBOREE_ROOT + "/magic.genboree"
  UNZIPUTIL = "unzip"
  BUNZIPUTIL = "bunzip2"
  GUNZIPUTIL = "gunzip"
  UNXZUTIL = "unxz"
  UN7ZUTIL = "7za"
  WIG_UPLOAD_CMD = "importWiggleInGenboree.rb";
  JAVAEXEC = "/usr/local/brl/local/jdk/bin/java"
  UPLOADERCLASSPATH = " -classpath /usr/local/brl/local/apache/htdocs/common/lib/servlet-api.jar:/usr/local/brl/local/apache/htdocs/common/lib/mysql-connector-java.jar:/usr/local/brl/local/apache/htdocs/common/lib/activation.jar:/usr/local/brl/local/apache/htdocs/common/lib/mail.jar:/usr/local/brl/local/apache/java-bin/WEB-INF/lib/GDASServlet.jar "
  UPLOADERCLASS = " -Xmx1800M org.genboree.upload.AutoUploader "
  ZOOMLEVELSFORLFF = "createZoomLevelsForLFF.rb"
  ZOOMLEVELSANDUPLOADLFF = "createZoomLevelsAndUploadLFF.rb"

  GB_LFF_EP_FILE = "3colLff"
  GB_FASTA_EP_FILE = "Fasta"
  FASTAFILEUPLOADERCLASS = " -Xmx1800M org.genboree.upload.FastaEntrypointUploader "
  
  CLUSTER_ADMIN_EMAIL = "raghuram@bcm.edu";

end

end ; end
