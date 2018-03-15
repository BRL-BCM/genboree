require "erubis"
require "redcloth"
require "uri"
#12-29-14 kpr
require "json"


#require 'rack-google-analytics'
#use Rack::GoogleAnalytics, tracker: 'UA-24682900-2'

# Our required modules
$LOAD_PATH.unshift(File.dirname(__FILE__))
#require "includes/events.rb"
#require "includes/news.rb"
#require "includes/slider.rb"
require "includes/redmine.rb"
#require "includes/splash.rb"

##
# Important configuration options, to be modified for deployment:
CONFIG = {
  # +:root+
  #   The actual file root of the scripts.  Should be automatically determined
  #   correctly but could be modified manually if needed.
  :root => File.expand_path(File.dirname(__FILE__)),
  # +:templateDir+
  #   The location of the rhtml templates (relative to :root)
  :templateDir => "/views",
  # +:assetsPath+
  #   The location of the static assets (css/images/js/etc) (relative to :root)
  :assetsPath => "/public",
  # +:context+
  #   The context for URL requests.  All links must be generated starting with
  #   this context at the root of the server.  Leading slash required, no trailing
  #   slashes.
  #   (Ex] "" means no prefix, "/prefix" means all links will be "/prefix/link")
  :context => "/site",
  # +:registerUrl+
  #   The URL for POST requests to the Genboree register form (new user form)
  :registerUrl => "http://__GENBOREE_webserverFQDN__/projects/genboree_profile_management/genboree_profile_management/profile/new",
  # +:loginUrl+
  #   The URL for POST requests to the Genboree login form
  :loginUrl => "http://__GENBOREE_webserverFQDN__/java-bin/login.jsp",
  # +:lostPasswordUrl+
  #   The URL for POST requests to the Genboree lost password form
  :lostPasswordUrl => "http://__GENBOREE_webserverFQDN__/projects/genboree_profile_management/genboree_profile_management/profile/forgot_pwd",

  :redmineUrl => "http://localhost/redmine",
  :redmineProject => "genboree_website_content",
  :apiKey => "779665443f782f5f670a5e3ae69874a78607cdc0"
}

##
# Main process starts
class GenboreeWebSite
  attr_reader :context, :loginUrl, :registerUrl, :lostPasswordUrl,
    :redmineUrl, :redmineProject, :apiKey, :configPath

  ##
  # Constructor
  def initialize(opts)
    @root = opts[:root]
    @templateDir = @root + opts[:templateDir]
    @assetsPath = @root + opts[:assetsPath]
    @context = opts[:context]
    @registerUrl = opts[:registerUrl]
    @loginUrl = opts[:loginUrl]
    @lostPasswordUrl = opts[:lostPasswordUrl]
    @redmineUrl = opts[:redmineUrl]
    @redmineProject = opts[:redmineProject]
    @apiKey = opts[:apiKey]
    #12-29-14 kpr
    @configPath = opts[:configPath]
  end

  ##
  #12-29-14 kpr
  # Method to get JSON settings from config (actions, etc.)
  def get_actions()
    #config_file = "#{@configPath}/action_config.json"
    config_file = "action_config.json"
    config = JSON.parse(File.read(config_file))
    
    return config
  end

  ##
  # Convenience method for rendering templates within templates.
  def rendr(target, varMap={})
    #12-29-14 kpr
    if target == "splash"
      # log output for date / time so we get general idea to timestamp
      #  issues. Right now only for splash page. 
      $stderr.puts "-- #{Time.now.strftime("%m-%d-%y %k:%M:%S")} --"
    end
    rhtml = "#{@templateDir}/#{target}.rhtml"
    rhtmlObj = Erubis::FastEruby.new(File.read(rhtml))
    varMap[:context] = @context
    varMap[:server] = self
    #9-17-14 kpr
    #varMap[:redmineUrl] = @redmineUrl

    #10-9-14
    rUrlObj = URI.parse(@redmineUrl)
    varMap[:redmineUrl] = rUrlObj.path
    return rhtmlObj.evaluate(varMap)
  end

  ##
  # Method to handle requests.
  def call(env)
    # Extract the requested path from the request
    path = Rack::Utils.unescape(env['PATH_INFO'])
    # Remove any trailing slashes
    #path.chop! if(path =~ /.*\/$/)
    path.chomp!('/')

    # Remove @context from front of path, if in use
    if(@context and !@context.empty?)
      path.gsub!(/^#{@context}/, '')
    end

    # Send to an asset OR index.rhtml
    target = nil
    if (File.file?("#{@assetsPath}/#{path}"))
      target = "#{@assetsPath}/#{path}"
    else
      target = "#{@templateDir}/index.rhtml"
      #vars = {:action => path.slice(1, path.length), :context => @context, :server => self}
      #9-17-14 kpr
      #vars = {:action => path.slice(1, path.length), :context => @context, :server => self, :redmineUrl => @redmineUrl}

      #10-9-14
      rUrlObj = URI.parse(@redmineUrl)
      vars = {:action => path.slice(1, path.length), :context => @context, :server => self, :redmineUrl => rUrlObj.path}
    end

    # NOTE: If you cannot use the 'file' executable to determine MIME type, we
    #   could always modify this to make a guess based on extension.
    mime = `file --mime -b #{target}`
    mime.chomp!

    #$stderr.puts "path:\n\n#{path.inspect}\n\nPATH_INFO:\n\n#{env['PATH_INFO'].inspect}\n\ntarget:\n\n#{target.inspect}\nvars:\n\n#{vars.inspect}\n\n"
    # Send back the appropriate Content-Type header, and file contents
    if (target and target =~ /.*\.rhtml$/)
      # Render the file with Erubis
      rhtmlObj = Erubis::FastEruby.new(File.read(target))
      [200, {'Content-Type' => 'text/html'}, rhtmlObj.evaluate(vars)]
    elsif (target =~ /.*\.js$/)
      # Javascript files
      [200, {'Content-Type' => 'text/javascript'}, File.read(target)]
    elsif (target =~ /.*\.css$/)
      # CSS files
      [200, {'Content-Type' => 'text/css'}, File.read(target)]
    elsif (target)
      # Simply process the file (MIME type might be wrong)
      [200, {'Content-Type' => mime}, File.read(target)]
    else
      # Not found
      [404, {'Content-Type' => 'text/html'}, "#{path} Not Found"]
    end
  end # def call(env)
end # class GenboreeWebSite

##
# Create the app and run it (Rack stuff)
website = GenboreeWebSite.new(CONFIG)
run website
