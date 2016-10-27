require 'redmine'

require 'mailer_patch'
require 'wiki_controller_patch'
require 'activities_controller_patch'
require 'boards_controller_patch'
require 'user_model_patch'

# Attempt override of RedCloth3::ALLOWED_TAGS constant
class RedCloth3
  ALLOWED_TAGS = %w(redpre pre code notextile object script param a img embed)
end

Redmine::Plugin.register :genboree_customizations do
  name 'Genboree Customizations plugin'
  author 'Andrew R Jackson'
  description 'This Redmine plugin applies various tweaks/customization particular to Genboree installations'
  version '0.0.1'
  #url 'http://example.com/path/to/plugin'
  author_url 'http://genboree.org'

  menu :top_menu, :gb_home, "/site/", :before => :projects, :caption => :label_gb_home, :html => { :target => '_blank' }

  settings :default => { 'empty' => true }, :partial => 'settings/genboree_customizations_settings'
end

gbCustomPlugin = Redmine::Plugin.find(:genboree_customizations)

gbCustomPlugin.delete_menu_item(:top_menu, :my_page)
