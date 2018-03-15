require 'redmine'

# Apply shims to certain methods of Redmine's ApplicationController
# - Needed to support async stuff of this plugin without access to
#   User.current global (which cannot be used with async because it's a global
#   and will change with any requests that get handled before our async blocks)
require 'genboree_generic_application_controller_patch'

Redmine::Plugin.register :genboree_generic do
  name 'Genboree Generic plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
end
