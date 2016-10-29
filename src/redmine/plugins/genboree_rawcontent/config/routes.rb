
# How do these routes affect sub-dirs? Not at all? What about "upload" ~sub-dir
# How do these routes affect .xml, .json API type representatons (they don't?)
RedmineApp::Application.routes.draw do
  delete '/projects/:id/rawcontent(/*request_path(.:format))', :to => "genboree_rawcontent#delete", :as => :rawcontent_delete
  put "/projects/:id/rawcontent(/*request_path(.:format))", :to => "genboree_rawcontent#create", :as => :rawcontent_upload
  # @todo Separate out show() from index() in controller and add/change routes appropriately
  #get '/projects/:id/rawcontent(/*request_path(.:format))', :to => "genboree_rawcontent#index", :as => :rawcontent_index
  get '/projects/:id/rawcontent(/*request_path(.:format))', :to => "genboree_rawcontent#index", :as => :rawcontent_index
  get '/projects/:id/rawcontent(/*request_path)', :to => "genboree_rawcontent#index", :as => :rawcontent_index
  get '/projects/:id/rawcontent/:path', :to => "genboree_rawcontent#show", :as => :rawcontent_link
end