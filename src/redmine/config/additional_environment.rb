# Copy this file to additional_environment.rb and add any statements
# that need to be passed to the Rails::Initializer.  `config` is
# available in this context.
#
# Example:
#
#   config.log_level = :debug
#   ...
#

# Coordinate routes path with session cookie path.
# - i.e. with the setting you used in config/environment.rb for
#   RedmineApp::Application.routes.default_scope[:path]
# - this solves the cookie collisions between multiple redmines running on the same host
#   which cause sign-out issues when you access the different redmine services in
#   the same browser (i.e. in different windows/tabs)
# - NOTE:
#   . RedmineApp::Application.routes.default_scope is NOT available when this gets
#     evaluated. So can't just assign RedmineApp::Application.routes.default_scope[:path]
#     to coodinate them.
#   . Have to hard-code unfortunately. But to same value as you put in config/environment.rb
#   . (Conversely, putting the code below in config/environment.rb doesn't work as it
#     gets wiped when the actual config is created with the help of this file)
# Predefined:
#   config = RedmineApp::Application.config
#config.session_options[:path] = '/genboreeKB_dev'
#config.session_options[:key]  = '_redmine_session_genboreeKB_dev'
config.session_store(:cookie_store, config.session_options.merge(
{
  :key  => "_redmine_session_genboree_",
  :path => "/redmine"
}))

