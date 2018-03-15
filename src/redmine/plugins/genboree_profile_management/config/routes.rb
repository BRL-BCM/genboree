# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
RedmineApp::Application.routes.draw do
  # Profile releated routes for CRUD functions
  get '/projects/:id/genboree_profile_management',  :to => "genboree_profile_management_ui_entry#show",  :as => "genboree_profile_management_ui_entry_show"
  get '/projects/:id/genboree_profile_management/profile',  :to => "genboree_profile_management_ui_entry#profile",  :as => "genboree_profile_management_ui_entry_profile"
  get '/projects/:id/genboree_profile_management/profile/new',  :to => "genboree_profile_management_ui_entry#show",  :as => "genboree_profile_management_ui_entry_show"
  post '/projects/:id/genboree_profile_management/profile/create',  :to => "genboree_profile_management_ui_entry#create",  :as => "genboree_profile_management_ui_entry_create"
  get '/projects/:id/genboree_profile_management/profile/update',  :to => "genboree_profile_management_ui_update#show",  :as => "genboree_profile_management_ui_update_show"
  post '/projects/:id/genboree_profile_management/profile/update',  :to => "genboree_profile_management_ui_update#update",  :as => "genboree_profile_management_ui_update_update"
  get '/projects/:id/genboree_profile_management/profile/update/pwd',  :to => "genboree_profile_management_ui_update#show_update_pwd",  :as => "genboree_profile_management_ui_update_show_update_pwd"
  
  post '/projects/:id/genboree_profile_management/profile/update/pwd',  :to => "genboree_profile_management_ui_update#update_pwd",  :as => "genboree_profile_management_ui_update_update_pwd"
  get '/projects/:id/genboree_profile_management/profile/forgot_pwd',  :to => "genboree_profile_management_ui_entry#forgot_pwd",  :as => "genboree_profile_management_ui_entry_forgot_pwd"
  post '/projects/:id/genboree_profile_management/profile/reset_pwd',  :to => "genboree_profile_management_ui_entry#reset_pwd",  :as => "genboree_profile_management_ui_entry_reset_pwd"
  
  
  # Routes for live UI validation
  get '/projects/:id/genboree_profile_management/validate/user_id',  :to => "genboree_profile_management_ui_entry#validate_user_id",  :as => "genboree_profile_management_ui_entry_validate_user_id"
  get '/projects/:id/genboree_profile_management/validate/email_id',  :to => "genboree_profile_management_ui_entry#validate_email_id",  :as => "genboree_profile_management_ui_entry_validate_email_id"
  
end
