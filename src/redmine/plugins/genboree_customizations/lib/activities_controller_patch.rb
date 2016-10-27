require_dependency 'activities_controller'

module ActivitiesControllerPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :index, :activity_scope_fix
    end
  end
  
  module InstanceMethods
    # We are intercepting the ActivitiesController#index method.
    # - in this case, we will NOT call the original method (provided automatically in index_without_activity_scope_fix)
    # - we will provide our own version, with a minor change
  
    def index_with_activity_scope_fix(headers={}, &block)  
      $stderr.puts "\n\nactivities index shim starting!\n\n"
          @days = Setting.activity_days_default.to_i

      if params[:from]
        begin; @date_to = params[:from].to_date + 1; rescue; end
      end

      @date_to ||= Date.today + 1
      @date_from = @date_to - @days
      @with_subprojects = params[:with_subprojects].nil? ? Setting.display_subprojects_issues? : (params[:with_subprojects] == '1')
      @author = (params[:user_id].blank? ? nil : User.active.find(params[:user_id]))

      @activity = Redmine::Activity::Fetcher.new(User.current, :project => @project,
                                                             :with_subprojects => @with_subprojects,
                                                             :author => @author)
      @activity.scope_select {|t| !params["show_#{t}"].nil?}
      # BRL: to implement this change:
      #   "Activity" needs ALL types selected in right-hand side
      # This requires a change to how it gets @activity.scope (to have all checked by default)
      # OLD:
      #@activity.scope = (@author.nil? ? :default : :all) if @activity.scope.empty?
      # NEW:
      @activity.scope = :all if(@activity.scope.empty?)

      events = @activity.events(@date_from, @date_to)

      if events.empty? || stale?(:etag => [@activity.scope, @date_to, @date_from, @with_subprojects, @author, events.first, events.size, User.current, current_language])
        respond_to do |format|
          format.html {
            @events_by_day = events.group_by {|event| User.current.time_to_date(event.event_datetime)}
            render :layout => false if request.xhr?
          }
          format.atom {
            title = l(:label_activity)
            if @author
              title = @author.name
            elsif @activity.scope.size == 1
              title = l("label_#{@activity.scope.first.singularize}_plural")
            end
            render_feed(events, :title => "#{@project || Setting.app_title}: #{title}")
          }
        end
      end

    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end

# Now apply our patched method to the core Redmine ActivitiesController class via module include:
ActivitiesController.send(:include, ActivitiesControllerPatch)
