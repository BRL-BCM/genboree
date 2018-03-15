Redmine::Plugin.register :genboree_profile_management do
  name 'Genboree Profile Management plugin'
  author 'BRL-BCM'
  description 'This is a plugin for Redmine for registering Genboree users and to provide them an interface for editing their profile info.'
  version '1.0.0'
  url 'http://genboree.org/'
  author_url 'http://genboree.org/members'
  
  settings  :default => {'empty' => true},
            :partial => 'settings/genboree_profile_management'
  
  
  # Everyone would have access to this.
  # However, depending on whether the user is logged in or not, the interface will show slightly different things
  # For non logged in users, would present a page for fresh registration. For logged in user, will present a page for editing certain profile info.
  project_module(:genboree_profile_management) {
    permission :genboree_profile_management_read_access, {
      :genboree_profile_management_ui_entry => [ :show, :validate_user_id, :validate_email_id, :create, :forgot_pwd, :reset_pwd ]
    }
    permission :genboree_profile_management_write_access, {
      :genboree_profile_management_ui_update => [ :show, :update, :show_update_pwd, :update_pwd ]
    }
  }

  # For projects with Genboree Profile Management module enabled, add a tab to the menu bar
  menu :project_menu,
    :genboree_profile_management,
    {
      :controller => "genboree_profile_management_ui_entry",
      :action => "show"
    }
    
    

  
  
end
