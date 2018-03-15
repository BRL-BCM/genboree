class ClingenResourceSettingsController < ApplicationController
  before_filter  :find_project
  def update
    $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Inside settings update. The params are #{params.inspect}") 
    $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Inside settings update. The setting_params are #{setting_params.inspect}") 

    @clingen_resource_setting = ClingenResourceSetting.find_by_project_id(@project.id)
    kbMount = RedmineApp::Application.routes.default_scope[:path]
    if @clingen_resource_setting.nil?
      @clingen_resource_setting = ClingenResourceSetting.new(setting_params)
      if @clingen_resource_setting.save
         # Give a success notice
         redirect_to "#{kbMount}/projects/#{@project.identifier}/settings/clingen_resource_settings"
         flash[:success] = "Settings Saved."
      end
    else
      @clingen_resource_setting.update_attributes(setting_params)
      if @clingen_resource_setting.save
        redirect_to "#{kbMount}/projects/#{@project.identifier}/settings/clingen_resource_settings"
        flash[:success] = "Settings Updated."
      end
    end
  end
  def new
  end
  private 
  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  def setting_params
    return params[:clingen_resource_setting]
  end
end
