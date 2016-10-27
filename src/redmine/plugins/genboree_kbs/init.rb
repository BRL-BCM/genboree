require 'yaml'
require_dependency 'genboree_kbs/hooks'

# Require our patches to built-in Redmine controllers

Redmine::Plugin.register :genboree_kbs do
  name 'Genboree Kbs plugin'
  author 'Sameer Paithankar, Andrew Jackson'
  author_url 'http://genboree.org'
  url 'http://genboree.org/genboreeKB'
  description 'This Redmine plugin adds an optional UI for GenboreeKBs.'
  version '0.0.1'
  project_module :genboree_kbs do
    #permission :view_genboree_kbs, :genboreeKb => :index
    #permission :create_genboree_kbs, :genboreeKb => :create
    #permission :update_genboree_kbs, :genboreeKb => :update
    permission :view_genboree_kbs, {:genboreeKbCollection => [:index] }
    permission :create_genboree_kbs, {:genboreeKb => [:create] }
    permission :update_genboree_kbs, {:genboreeKb => [:update] }
    #permission :edit_genboree_kbs, {:genboreeKb => [:create, :update, :savedoc] }, :require => :member
  end
  menu :project_menu, :genboree_kb_collection, { :controller => 'genboreeKbCollection', :action => 'index' }, :caption => 'GenboreeKB', :after => :activity, :param => :project_id
end

 

mongoYml = YAML.load(File.read(File.join(Redmine::Plugin.find(:genboree_kbs).directory, "conf/mongoDb.yml") ))
Redmine::Plugin.genboreeKbMongoDbYml = mongoYml
