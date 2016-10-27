require_dependency 'boards_controller'

module BoardsControllerPatch

  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :show, :subject_and_author_sort
    end
  end

  module InstanceMethods
    include Redmine::I18n
    include Redmine::Pagination
    include SortHelper
    # We are intercepting the BoardsController#show method.
    # - we will implement this ourselves (it's a copy, with a couple minor changes)
    # - in this case, we will NOT call the original method (provided automatically in show_without_subject_and_author_sort)

    def show_with_subject_and_author_sort(headers={}, &block)
      #$stderr.puts "\n\nboards show shim starting!\n\n"
      respond_to { |format|
        format.html {
          sort_init 'updated_on', 'desc'
          sort_update 'created_on' => "#{Message.table_name}.created_on",
                      'replies' => "#{Message.table_name}.replies_count",
                      'updated_on' => "COALESCE(last_replies_messages.created_on, #{Message.table_name}.created_on)",
                      # BRL: Allow sort by Subject & Author (actually Author *name* in the end, which requires hack approach)
                      'subject' => "#{Message.table_name}.subject",
                      'author' => "#{Message.table_name}.author_id"

          @topic_count = @board.topics.count
          @topic_pages = Paginator.new @topic_count, per_page_option, params['page']
          @topics =  @board.topics.
            reorder("#{Message.table_name}.sticky DESC").
            includes(:last_reply).
            limit(@topic_pages.per_page).
            offset(@topic_pages.offset).
            order(sort_clause).
            preload(:author, {:last_reply => :author}).
            all

          # BRL: Special hack for sorting by Author *name*, if needed (can't use SortHelper#sort_update approach b/c info is in a different table)
          if(@sort_criteria.is_a?(SortHelper::SortCriteria) and !@sort_criteria.empty?)
            sortKey, asc = @sort_criteria.first_key, @sort_criteria.first_asc?
            descCode = (asc ? 1 : -1)
            if(sortKey == 'author')
              # Then resort @topics as best we can by topic.author (which will be text display of user name; probably Last, First or whatever user display is set to)
              @topics.sort! { |aa, bb| retVal = (aa.author.name.downcase <=> bb.author.name.downcase) ; retVal = (aa.author.name <=> bb.author.name) if(retVal == 0) ; retVal * descCode }
            end
          end

          @message = Message.new(:board => @board)
          render :action => 'show', :layout => !request.xhr?
        }
        format.atom {
          @messages = @board.messages.
            reorder('created_on DESC').
            includes(:author, :board).
            limit(Setting.feeds_limit.to_i).
            all
          render_feed(@messages, :title => "#{@project}: #{@board}")
        }
      }
    end
  end
end

# Now apply our patched method to the core Redmine WikiController class via module include:
BoardsController.send(:include, BoardsControllerPatch)
