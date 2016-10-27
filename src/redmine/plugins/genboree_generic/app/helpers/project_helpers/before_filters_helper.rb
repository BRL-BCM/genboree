require 'brl/util/util'

module ProjectHelpers
  module BeforeFiltersHelper

    # Find the project id in the route (RESTful compliant) or query string param (not good, but as a back up)
    #   and use it to set @@project@ to the @Project@ object. Having @@project@ is a key step for many
    #   Redmine controllers and even other filter methods. For example: must have @project set before calling
    #   Redmine's authorize before_filter ; must have @project set before certain other plugin filters.
    #   Typical way to handle this is to register this before_filter first, before other before_filters.
    # @note This method will also set @@projectId@ to the project id extracted from the route or, as a back up,
    #   from the query string parameter 'project_id' (bad).
    # @param [Hash{Symbol,Object}] opts Optional. The options {Hash}, used to change default behavior. Setting
    #   @:no404@ to @false@ will prevent this method from calling Redmine's @render_404@ functionality. Instead
    #   @nil@ will be returned.
    # @return [Project] The matching project object.
    def find_project(opts={ :no404 => false})
      @projectId = params[:id]
      $stderr.debugPuts(__FILE__, __method__, 'CONFIRM', "*Generic* find_project - found proj info from #{@projectId.inspect} in path")
      @project = Project.find(@projectId)
    rescue ActiveRecord::RecordNotFound
      # If missing, try 'project_id' in params (for things like settings that may not have :id in path?)
      begin
        @projectId = params[:project_id]
        $stderr.debugPuts(__FILE__, __method__, 'CONFIRM', "*Generic* find_project - found proj info from #{@projectId.inspect} in query string (BAD)")
        @project = Project.find(@projectId)
      rescue ActiveRecord::RecordNotFound
        $stderr.debugPuts(__FILE__, __method__, 'CONFIRM', "*Generic* find_project - NO PROJECT ID FOUND???")
        if(opts[:no404])
          nil
        else
          render_404
        end
      end
    end
  end
end
