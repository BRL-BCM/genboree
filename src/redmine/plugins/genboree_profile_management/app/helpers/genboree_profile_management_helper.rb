
module GenboreeProfileManagementHelper
  
  include GenericHelpers::BeforeFiltersHelper
  include PluginHelpers::BeforeFiltersHelper
  extend  PluginHelpers::BeforeFiltersHelper  # so also available as "class" method when doing settings
  include ProjectHelpers::BeforeFiltersHelper
  include PluginHelpers::PluginSettingsHelper
  extend  PluginHelpers::PluginSettingsHelper  # so also available as "class" method when doing settings
  
  
  def self.included(includingClass)
    includingClass.send(:include, GenericHelpers::PermHelper)
  end

  def self.extended(extendingObj)
    extendingObj.send(:extend, GenericHelpers::PermHelper)
  end
  
  def init_user_info
    @user_info = {
      "user_id" => "",
      "email_id" => "",
      "first_name" => "",
      "last_name" => "",
      "affiliation" => "",
      "phone" => ""
    }
  end
  
end