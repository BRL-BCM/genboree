# Load the rails application
require File.expand_path('../application', __FILE__)

# Make sure there's no plugin in vendor/plugin before starting
vendor_plugins_dir = File.join(Rails.root, "vendor", "plugins")
if Dir.glob(File.join(vendor_plugins_dir, "*")).any?
  $stderr.puts "Plugins in vendor/plugins (#{vendor_plugins_dir}) are no longer allowed. " +
    "Please, put your Redmine plugins in the `plugins` directory at the root of your " +
    "Redmine directory (#{File.join(Rails.root, "plugins")})"
  exit 1
end

#Redmine::Utils::relative_url_root = "/genboreeKB"
#RedmineApp::Application.routes.default_scope =  { :path => '/genboreeKB_dev' }

# #########################
# Running Redmine at a Sub-URI
# #########################

# 1. Configure the RedmineApp class to know it's running under a mount / sub-URI
# - Must do this before initializing the app (from this default class thing)
RedmineApp::Application.routes.default_scope =  { :path => '/redmine' }

# 2. Initialize the rails application.
# - Singleton, so can't muck with RedmineApp::Application now and get an effect
RedmineApp::Application.initialize!

# 3. Fix some stuff for assets (but see below!!!!)
ActionController::Base.relative_url_root = "/redmine"
Redmine::Utils::relative_url_root = "/redmine" 


# HOWEVER, while rails now works, even in async render mode, assets are not working.
# - Rails is finicky. Here is how to fix assets too, given prep work above:
#
# 4. DO NOT --prefix when starting thin for Redmine! Fix it now.
# 5. Create a softlink in public/ to "." that is named after your sub-URI mount
# - Yep, this trick works due to relative_url_root stuff above
# - i.e.
#     cd public/
#     ln -s . genboreeKB_dev

