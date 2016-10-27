require_dependency 'wiki_controller'

module WikiControllerPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :show, :no_subscriber_404
    end
  end
  
  module InstanceMethods
    # We are intercepting the WikiController#show method.
    # - we will implement this ourselves (it's a copy, with a minor change)
    # - in this case, we will NOT call the original method (provided automatically in show_without_no_subscriber_404)
  
    def show_with_no_subscriber_404(headers={}, &block)  
      #$stderr.puts "\n\nwiki show shim starting!\n\n"
      
      if params[:version] && !User.current.allowed_to?(:view_wiki_edits, @project)
        deny_access
        return
      end
      @content = @page.content_for_version(params[:version])
      if @content.nil?
        if User.current.allowed_to?(:edit_wiki_pages, @project) && editable? && !api_request?
          edit
          render :action => 'edit'
        else
          render :action => 'noWikiYet'
        end
        return
      end
      if User.current.allowed_to?(:export_wiki_pages, @project)
        if params[:format] == 'pdf'
          send_data(wiki_page_to_pdf(@page, @project), :type => 'application/pdf', :filename => "#{@page.title}.pdf")
          return
        elsif params[:format] == 'html'
          export = render_to_string :action => 'export', :layout => false
          send_data(export, :type => 'text/html', :filename => "#{@page.title}.html")
          return
        elsif params[:format] == 'txt'
          send_data(@content.text, :type => 'text/plain', :filename => "#{@page.title}.txt")
          return
        end
      end
      @editable = editable?
      @sections_editable = @editable && User.current.allowed_to?(:edit_wiki_pages, @page.project) &&
        @content.current_version? &&
        Redmine::WikiFormatting.supports_section_edit?

      respond_to do |format|
        format.html
        format.api
      end
    end
  end
end

# Now apply our patched method to the core Redmine WikiController class via module include:
WikiController.send(:include, WikiControllerPatch)
