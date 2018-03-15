require 'uri'
require 'yaml'
require 'json'
require 'mysql2'
require 'em-http-request'
require 'brl/util/util'
require 'brl/db/dbrc'
require 'brl/rest/apiCaller'
require 'brl/cache/helpers/dnsCacheHelper'
require 'brl/cache/helpers/domainAliasCacheHelper'
require 'brl/genboree/kb/kbDoc'
require 'brl/genboree/kb/propSelector'
require 'brl/genboree/kb/producers/abstractTemplateProducer'

require_dependency 'register_clingen_user/hooks'

Redmine::Plugin.register :register_clingen_user do

  name 'Register Clingen User plugin'
  author 'Ronak Patel'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
  settings  :default => {'empty' => true},
            :partial => 'settings/register_clingen_user'
  project_module(:register_clingen_user) {
      permission :register_user, :cg_users => [ :new, :create, :resetp, :send_reset_request ]
      #, :public => true
      permission :edit_user, :cg_users => [ :show, :edit, :editpwd, :updatel, :updatep ]
  }
  menu :project_menu, :manage_account, { 
       :controller => 'cg_users', 
       :action => 'show' }, :caption => 'Manage Account'
end
