Redmine::Plugin.register :sencha_helper do
  name 'Sencha Helper plugin'
  author 'Sameer Paithankar'
  description 'This plugin is used for setting up the base/root directory of the sencha-deploy area.'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
  settings  :partial => 'settings/sencha_helper',
            :default =>
            {
              'path' => '/usr/local/brl/local/rails/redmine/sencha-deploy'
            }
  project_module(:sencha_helper) {
    permission :sencha_helper_index, { :sencha_helper => [ :index] }
  }
end
