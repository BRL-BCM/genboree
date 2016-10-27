# Redmine - project management software
# Copyright (C) 2008  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


# The initial version renders Raw web Content as-is, WITHOUT the base
#   Redmine layout. However, we keep around some aspects related to Redmine's
#   layout because we may want to add the ability, in the future, of inlining
#   raw content onto a Redmine-wrapped page.
# * How to indicate this is desired "view" of Raw Content may be tricky.
# ** Possibly protected extension/:format like ".wrap" or ".inline".
# ** But then how to deal best with all the href/src/etc to related raw content (e.g. inline images)?
# ** Perhaps just make sister-plugin called "wrappedContent" and separate /projects/{:id}/rawcontent/
#      from /projects/{:id}/wrapContent/ completely. Then don't have to worry about relative links
#      and inline-page assets (shouldn't be issue though, just relative links) having correct path/params.
# *** Or perhaps just have this support rawcontent and wrappedContent and use that as a switch for layout=>true/false
# ** Regardless, mixing these two approaches to Content is a no-go since in both approaches, page-editing
#     is required to get links to the *other* Content mode.
class SenchaHelperController < ApplicationController
  class SenchaHelperControllerError < StandardError; end

  unloadable
  layout 'base' # Kept although we will almost certainly NOT USE Redmine's layout at all for the content.
  before_filter :find_project

  # ------------------------------------------------------------------
  # Possibly helps with API support and certainly API-KEY type authentication.
  # ------------------------------------------------------------------
  skip_before_filter :check_if_login_required
  skip_before_filter :verify_authenticity_token

  accept_api_auth :index, :create, :delete

  helper :attachments
  include AttachmentsHelper

  # Can this show a ToC (in Redmine layout) for files in dir if there is no index.html?
  def index()
    #$stderr.puts "DEBUG - #{__method__}() => admin? #{User.current.admin?().inspect} ;;; User:\n\n#{User.current.inspect}"
    @tocFiles = []
    @reqRsrc = params[:request_path]
    @reqRsrc = "sencha-apps/#{@reqRsrc}" unless(@reqRsrc =~ /^sencha-apps\//)
    @reqRsrc = "#{params['pluginId']}/#{@reqRsrc}"
    @contentDirRsrcPath = ("#{@reqRsrc}/" or "/")
    @tocFiles = []
    if(@reqRsrc !~ /\/\.\./)
      @railsFmt = params[:format]
      @nvPairs = get_orig_query()
      @respFormat = @nvPairs['format']
      @respFormat = ( (@respFormat.nil? or @respFormat.empty?) ? @railsFmt : @respFormat.first )
      @origReqRsrc = get_orig_path(@reqRsrc, @railsFmt, @respFormat)
      @diskPath = get_real_path(@origReqRsrc)
      showContent(@diskPath, @origReqRsrc)
    else
      render :status => 400
    end
    return
  rescue Errno::ENOENT => e
    $stderr.puts "ERROR - #{__method__}() => Exception! #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}\n\n"
    render_error "ERROR: tried to access a content file or directory (#{@reqRsrc.inspect}) that doesn't actually exist on disk."
  rescue Errno::EACCES => e
    # Can not read the file
    $stderr.puts "ERROR - #{__method__}() => Exception! #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}\n\n"
    render_error "Unable to read the file: #{e.message}"
  rescue SenchaHelperControllerError => e
    $stderr.puts "ERROR - #{__method__}() => Exception! #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}\n\n"
    render_error e.message
  end

  

 

  # ------------------------------------------------------------------
  # PRIVATE HELPERS
  # ------------------------------------------------------------------

  private

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Return the path to the rawconent root directory for the current project.
  # @note As a side effect, this will ensure the sencha dir actually exists under redmine!
  def get_project_directory
    @project_directory ||= Setting.plugin_sencha_helper['path'].to_s
    FileUtils.mkdir_p(@project_directory)
  end

  def get_orig_query()
    uri = URI.parse(request.fullpath)
    queryStr = (uri.query or "")
    retVal = CGI.parse(queryStr)
  end

  def get_orig_path(reqRsrc, format, respFormat)
    if(format)
      if(respFormat and (format == respFormat)) # format coming from nvPairs not extension, so don't restore
        origPath = reqRsrc
      else # format coming from extension, restore
        origPath = "#{reqRsrc}.#{format}"
      end
    else # No format via extension or nvp so nothing to restore
      origPath = reqRsrc
    end
    return origPath
  end

  # Returns the absolute path of the original requested file.
  # @param [String] origReqRsrc The resource path requested, including any orig format extension rails removed.
  def get_real_path(origReqRsrc)
    projDir = get_project_directory()
    real = ( (origReqRsrc.nil? || origReqRsrc.empty?) ? projDir : File.join(projDir, origReqRsrc) )
    dir = File.expand_path(projDir)
    real = File.expand_path(real)
    $stderr.puts "DEBUG - #{__method__}() => dir: #{dir.inspect} ;;; real: #{real.inspect}"
    raise SenchaHelperControllerError, "ERROR: tried to access a content file or directory (#{origReqRsrc.inspect}) that doesn't actually exist on disk." unless(real.starts_with?(dir) && File.exist?(real))
    return real
  end



  def showContent(diskPath=@diskPath, origReqRsrc=@origReqRsrc)
    @content = @title = nil
    send_file(diskPath, :disposition => 'inline', :type => (Redmine::MimeType.of(diskPath) or Redmine::MimeType::DEFAULT_MIME_TYPE) )
  rescue Errno::ENOENT => noe
    render_error "ERROR: No such file on disk for #{origReqRsrc.inspect}. Error message: #{noe.message}"
  rescue Errno::EACCES => noa
    # Can not read the file
    render_error "ERROR: Unable to read the file #{origReqRsrc.inspect}. Error message: #{noe.message}"
  rescue SenchaHelperControllerError => grcce
    render_error grcce.message
  end



end
