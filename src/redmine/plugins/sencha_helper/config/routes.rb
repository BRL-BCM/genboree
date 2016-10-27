# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
RedmineApp::Application.routes.draw do
  get '/projects/:id/:pluginId/sencha(/*request_path(.:format))', :to => "sencha_helper#index", :as => :sencha_helper_index
  get '/projects/:id/:pluginId/sencha(/*request_path)', :to => "sencha_helper#index", :as => :sencha_helper_index
  get '/projects/:id/:pluginId/sencha-apps(/*request_path(.:format))', :to => "sencha_helper#index", :as => :sencha_helper_index
end