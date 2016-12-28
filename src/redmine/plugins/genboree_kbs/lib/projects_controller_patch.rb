require_dependency 'projects_controller'

module ProjectsControllerPatch
  def self.included(base) # :nodoc:
    base.send(:include, ProjectsInstanceMethods)

    base.class_eval do
      alias_method_chain :settings, :kb_project_vars
    end
  end
  
  module ProjectsInstanceMethods
    # We are intercepting the ProjectsController#settings method.
    # - in this case, we will NOT call the original method (provided automatically in settings_without_kb_project_vars)
    # - we will provide our own version, with a minor change
  
    def settings_with_kb_project_vars()  
      # Call original ProjectsController#settings methods
      # - preserve original return value
      retVal = settings_without_kb_project_vars()
     
      # Add our kb-related instance variables to ProjectsController
      # Set up additional varaiables to support the GenboreeKb plugin:
      # To-do: replace find(:all) with find by project id
      @genboreeKbAll = GenboreeKb.find(:all)
      @project = Project.find(params['id'])
      @genboreeKb = nil
      @genboreeKbAll.each { |kb|
      #$stderr.puts "kb['project_id']:\n#{kb['project_id'].inspect}\n\n@project['id']:\n#{@project['id'].inspect}\n\nparams['id']:\n#{params['id'].inspect}"  
      if(kb['project_id'] == @project['id'])
        @genboreeKb = kb
        break
      end
      }
      return retVal
    end     
  end
end

# Now apply our patched method to the core Redmine ProjectsController class via module include:
ProjectsController.send(:include, ProjectsControllerPatch)
