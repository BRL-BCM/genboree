require_dependency 'projects_controller'

module ProjectsControllerPatch
  def self.included(base) # :nodoc:
    base.send(:include, ProjectsInstanceMethods)

    base.class_eval do
      alias_method_chain :settings, :project_var
    end
  end
  
  module ProjectsInstanceMethods
    # We are intercepting the ProjectsController#settings method.
    # - in this case, we will NOT call the original method (provided automatically in settings_without_kb_project_vars)
    # - we will provide our own version, with a minor change
  
    def settings_with_project_var()  
      # Call original ProjectsController#settings methods
      # - preserve original return value
      retVal = settings_without_project_var()
     
      # Set up any plugin related models that you want for the setting tabs
      @project = Project.find(params['id'])
#      @genboreeKb = GenboreeKb.find_by_project_id(@project)
#      @genboreeAc = GenboreeAc.find_by_project_id(@project)
      return retVal
    end     
  end
end

# Now apply our patched method to the core Redmine ProjectsController class via module include:
ProjectsController.send(:include, ProjectsControllerPatch)
