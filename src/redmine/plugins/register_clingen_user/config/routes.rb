# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
RedmineApp::Application.routes.draw do
  post   '/projects/:id/register_clingen_user/cg_users'               ,  :to =>    "cg_users#create"
  get    '/projects/:id/register_clingen_user/cg_users/new'           ,  :to =>    "cg_users#new"     ,  :as => "new_cg_user"
  get    '/projects/:id/register_clingen_user/cg_users/show'          ,  :to =>    "cg_users#show"    ,  :as => "cg_users"
  get    '/projects/:id/register_clingen_user/cg_users/edit'          ,  :to =>    "cg_users#edit"    , :as => "edit_cg_users"
  post   '/projects/:id/register_clingen_user/cg_users/updatel'       ,  :to =>    "cg_users#updatel"
  get    '/projects/:id/register_clingen_user/cg_users/editpwd'          ,  :to =>    "cg_users#editpwd"    , :as => "editpwd_cg_users"
  post   '/projects/:id/register_clingen_user/cg_users/updatep'       ,  :to =>    "cg_users#updatep"

  get    '/projects/:id/register_clingen_user/cg_users/resetp'       ,  :to =>    "cg_users#resetp"    , :as => "reset_password_cg_users"
  post   '/projects/:id/register_clingen_user/cg_users/resetp'       ,  :to =>    "cg_users#send_reset_request"

  # Route to update setting
  post '/projects/:id/register_clingen_user/clingen_resource_settings/update', :to => "clingen_resource_settings#update", :as => :update_clingen_resource_settings
  put '/projects/:id/register_clingen_user/clingen_resource_settings/update', :to => "clingen_resource_settings#update"
end
