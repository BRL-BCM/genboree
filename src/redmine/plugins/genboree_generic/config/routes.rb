# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
RedmineApp::Application.routes.draw {
  # "show" type action: show user profile info
  #get 'projects/:id/gb_generic/test/gb_user/show_test1', :to => 'genboree_generic_ui_tests#show_test1', :as => :genboree_generic_ui_tests_show_test1

  # "show" type action: that deliberate raises a nasty exception
  #get 'projects/:id/gb_generic/test/gb_user/show_fail1', :to => 'genboree_generic_ui_tests#show_fail1', :as => :genboree_generic_ui_tests_show_fail1
  # "update" type action
  # - Since need to handling LOADING FORM and SHOWING FORM, we'll need two routes
  #   (one for GET which loads the form for use to see, and one for POST that handled submission)
  #get 'projects/:id/gb_generic/test/gb_user/update_inst1', :to => 'genboree_generic_ui_tests#update_inst1', :as => :genboree_generic_ui_tests_update_inst1
  #post 'projects/:id/gb_generic/test/gb_user/update_inst1', :to => 'genboree_generic_ui_tests#update_inst1', :as => :genboree_generic_ui_tests_update_inst1

  # "emailing" example
  # - We have a controller-action to trigger a multipart-mime (html + text fallback) email to the user
  #   in order to see how the pieces fit together (controller-action => call custom mailer class' custom
  #   mail action => send ---> body formated via Views)
}
