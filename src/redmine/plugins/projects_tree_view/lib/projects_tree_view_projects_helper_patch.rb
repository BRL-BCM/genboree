module ProjectsTreeView
  module ProjectsHelperPatch
    extend ActiveSupport::Concern

    module ClassMethods
    end

    def render_project_progress(project)
      s = ''
      cond = project.project_condition(false)

      open_issues = Issue.visible.count(:include => [:project, :status, :tracker], :conditions => ["(#{cond}) AND #{IssueStatus.table_name}.is_closed=?", false])

      if open_issues > 0
        issues_closed_pourcent = (1 - open_issues.to_f/project.issues.count) * 100
        s << "<div>Issues: " +
          link_to("#{open_issues} open", :controller => 'issues', :action => 'index', :project_id => project, :set_filter => 1) +
          "<small> / #{project.issues.count} total</small></div>" +
          progress_bar(issues_closed_pourcent, :width => '30em', :legend => '%0.0f%' % issues_closed_pourcent)
      end
      project_versions = project_open(project)

      unless project_versions.empty?
        s << "<div>"
        project_versions.reverse_each do |version|
          unless version.completed?
            s << "<div style=\"clear:both; display: block\">" + link_to_version(version) + ": " +
            link_to_if(version.open_issues_count > 0, l(:label_x_open_issues_abbr, :count => version.open_issues_count), :controller => 'issues', :action => 'index', :project_id => version.project, :status_id => 'o', :fixed_version_id => version, :set_filter => 1) +
            "<small> / " + link_to_if(version.closed_issues_count > 0, l(:label_x_closed_issues_abbr, :count => version.closed_issues_count), :controller => 'issues', :action => 'index', :project_id => version.project, :status_id => 'c', :fixed_version_id => version, :set_filter => 1) + "</small>. "
            s << due_date_distance_in_words(version.effective_date) if version.effective_date
            s << "</div><br />" +
            progress_bar([version.closed_pourcent, version.completed_pourcent], :width => '30em', :legend => ('%0.0f%' % version.completed_pourcent))
          end
        end
        s << "</div>"
      end
      s.html_safe
    end

    def favorite_project_modules_links(project)
      links = []
      menu_items_for(:project_menu, project) do |node|
         links << link_to(extract_node_details(node, project)[0], extract_node_details(node, project)[1]) unless node.name == :overview
      end
      links.join(", ").html_safe
    end

    def project_open(project)
      trackers = project.trackers.find(:all, :order => 'position')
      #retrieve_selected_tracker_ids(trackers, trackers.select {|t| t.is_in_roadmap?})
      with_subprojects =  Setting.display_subprojects_issues?
      project_ids = with_subprojects ? project.self_and_descendants.collect(&:id) : [project.id]

      versions = project.shared_versions || []
      versions += project.rolled_up_versions.visible if with_subprojects
      versions = versions.uniq.sort
      completed_versions = versions.select {|version| version.closed? || version.completed? }
      versions -= completed_versions

      issues_by_version = {}
      versions.reject! {|version| !project_ids.include?(version.project_id) && issues_by_version[version].blank?}
      versions
    end
  end
end
