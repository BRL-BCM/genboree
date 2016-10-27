require 'fileutils'
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

# Helper class to support saving new Raw HTML Content related files.
class RawContentFile < ActiveRecord::Base
  # Save the uploaded file to tgtDir, optionally uncompressing [ currently not supported, could take long time!! Genboree job?]
  # @param [String] tgtDir The target dir where to save file (project's rawcontent dir)
  # @param [Hash] uploadFile Hash (from Redmine) whose 'datafile' key points to IO object
  #   (probably File) which can be read (via IO#read) to get the uploaded content.
  # @param [Boolean] unpack [Optional; NOT IMPLEMENTED] Should the uploaded file be completely unpacked in the target dir?
  #   Currently noop because uncompression may take a long time and needs proper arrangement.
  def self.save(tgtDirName, uploadFile, unpack=false)
    path = File.join(tgtDirName, uploadFile)
    File.open(path, "wb") { |ff| ff.write(upload['datafile'].read) }
  end
end

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
class GenboreeRawcontentController < ApplicationController
  class GenboreeRawcontentControllerError < StandardError; end

  unloadable
  layout 'base' # Kept although we will almost certainly NOT USE Redmine's layout at all for the content.
  before_filter :find_project, :authorize
  before_filter :require_admin, :only => [ :create ]

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
    if(params[:request_path] !~ /\/\.\./)
      preAction()
      if(File.directory?(@diskPath))
        # Are we coming into this dir WITHOUT a terminal /? Must check REQUEST_URI env variable because Rails molests fullpath etc.
        if( @rawRequestUri[-1].chr != '/' )
          # Building redirect is slightly different for top-level (.../rawcontent) than for deeper dir, at least to make browser address bar look nice
          redirectPath = ( (@reqRsrc.nil? or @reqRsrc.empty?) ? '' : "#{get_rsrc_path(@diskPath)}/" )
          redirect_to rawcontent_link_path( :id => @project, :path => redirectPath)
        else
          # Is there an index file already? If so, just go there.
          indexFile = get_index_file(@diskPath)
          # Forces redirect to the index file when the requested path is a directory
          # so that relative links in embedded html pages work
          if((@railsFmt =='html' or @respFormat == 'html' or (@railsFmt.nil? and @respFormat.nil?)) and indexFile and File.readable?(indexFile))
            # An index file exists, need to show it
            showContent(indexFile, @origReqRsrc)
          else # build index info
            # Need to build index html partial from dirs/files found in path.
            dd = Dir["#{@diskPath}/*"] # won't include ., .., or any .{file}
            @tocFiles = []
            dd.each { |item|
              size  = sizeOnDisk(item)
              if(size) # then can successfully read etc
                kind = (File.file?(item) ? :file : (File.directory?(item) ? :dir : :other))
                rsrcPath = get_rsrc_path(item)
                rsrcPath << "/" if(kind == :dir)
                mtime = File.mtime(item)
                rec = { :rsrcPath => rsrcPath, :mtime => mtime, :size => size, :kind => kind }
                @tocFiles << rec
              end
            }
            # Parent directory entry
            if(@contentDirRsrcPath != "/")
              parentDir = File.dirname(@reqRsrc).strip
              parentDir = '' if(parentDir == '.' or parentDir == '/')
              parentDir << '/' unless(parentDir.empty? or parentDir[-1].chr == '/')
              rec = { :rsrcPath => get_rsrc_path(parentDir), :mtime => '', :size => '', :kind => :'/' }
              @tocFiles.unshift( rec )
            end
            render :index
          end
        end
      else # not a directory
        showContent(@diskPath, @origReqRsrc)
      end
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
  rescue GenboreeRawcontentControllerError => e
    $stderr.puts "ERROR - #{__method__}() => Exception! #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}\n\n"
    render_error e.message
  end
  
  # Remove a rawcontent file or directory (including all its contents)
  # DELETE /projects/:id/rawcontent/:request_path
  # @todo Was broken. Didn't follow approach of index(), so unsurprising.
  def delete()
    $stderr.puts "#{Time.now.to_s} - delete controller params #{params.inspect}"
    if(params[:request_path] !~ /\/\.\./)
      preAction()
      begin
        if(File.directory?(@diskPath))
          $stderr.debugPuts(__FILE__, __method__, "RAW CONTENT", "STATUS - DELETE: about to do FileUtils.rm_rf on: #{@diskPath.inspect}")
          FileUtils.rm_rf(@diskPath, { :secure => true })
        else
          $stderr.debugPuts(__FILE__, __method__, "RAW CONTENT", "STATUS - DELETE: about to do File.delete on #{@diskPath.inspect}")
          File.delete(@diskPath)
        end
        # @todo : ensure this is right. Maybe use @parentDir ?
        # display parent of deleted item ?? Huh ??
        $stderr.debugPuts(__FILE__, __method__, "RAW CONTENT", "STATUS - DELETE: wants to go to parent of deleted item. @parentDir: #{@parentDir.inspect}")
        redirect_to :back
      rescue GenboreeRawcontentControllerError => err
        # rescue this controller errors which enforces that file is in rawcontent area and exists
        $stderr.debugPuts(__FILE__, __method__, "RAW CONTENT", "ERROR - DELETE: Error class: #{err.class} ; Error message: #{err.message} ; Error trace:\n#{err.backtrace.join("\n")}")
        render_error err.message
      rescue Errno.constants.map { |cnst| Errno.const_get(cnst) } => err
        # rescue OS errors
        $stderr.debugPuts(__FILE__, __method__, "RAW CONTENT", "ERROR - DELETE: Error class: #{err.class} ; Error message: #{err.message} ; Error trace:\n#{err.backtrace.join("\n")}")
        render_error err.message
      rescue => err # anything else
        $stderr.debugPuts(__FILE__, __method__, "RAW CONTENT", "ERROR - DELETE: Error class: #{err.class} ; Error message: #{err.message} ; Error trace:\n#{err.backtrace.join("\n")}")
      end
    end
  end

  # Only supports JSON API-based attachment->upload flow by a Redmine admin.
  # * Phase 1: use Redmine's existing /uploads.json to upload a new attachment as you would for a new Issue [that has attachment]
  # * Phase 2: Call PUT on the directory path where you want to place the already-uploaded attachment, providing JSON with info about attachement
  # @todo Need to convert this method to throw async and do the move in a non blocking method using EM approaches. (Like the file upload in the kb plugin)
  def create()
    $stderr.puts "DEBUG - #{__method__}() => entered ; check for attachment info in params:\n\n#{params.inspect}"
    @result = { }
    @haveError = false
    @reqRsrc = (params[:request_path] or '/')
    @railsFmt = params[:format]
    @nvPairs = get_orig_query()
    @respFormat = @nvPairs['format']
    @respFormat = ( (@respFormat.nil? or @respFormat.empty?) ? @railsFmt : @respFormat.first )
    @origReqRsrc = get_orig_path(@reqRsrc, @railsFmt, @respFormat)
    valid = validateCreate()
    if(valid)
      # Use the rsrcPath to determine target dir info
      @result[:targetDir] = safeRsrc = sanitizePath(@origReqRsrc)
      projDir = get_project_directory()
      safeRsrcDisk = File.expand_path( File.join(projDir, safeRsrc) )
      safeRsrcDisk = ( safeRsrcDisk.chomp('/') << '/' ) # Safely ensure has terminal '/'

      # Make sure the target dir exists and doesn't conflict with a file in that location
      mkdir_p = FileUtils.mkdir_p(safeRsrcDisk) rescue :failed

      if(mkdir_p != :failed)
        # Find the list of uploads if any. If none, it's ok, being used to create dirs.
        uploadFail = []
        uploads = ( params["rawcontent"]["uploads"] or [] )
        # @todo FIX: don't assume uploads is an array! maybe user has wrong thing! or fix at validation

        uploads.each_index { |idx|
          upload = uploads[idx]
          begin
            # Must have token and filename
            token = upload["token"] rescue nil
            filename = upload["filename"] rescue nil
            if(token and filename)
              if(filename !~ /^\./ and filename !~ /(?:\/\.\.$)|(?:\/\.\.\/)/)
                safeFilename = sanitizePath(filename)
                $stderr.puts "DEBUG - #{__method__}() => attachment token: #{token.inspect} ;;; desired filename: #{filename.inspect} ;;; safe filename: #{safeFilename.inspect}"
                # Maybe filename has a path...need to create its relative dir.
                safeFileDir = File.dirname(safeFilename)
                mkdir_p = FileUtils.mkdir_p("#{safeRsrcDisk}#{safeFileDir}")
                finalTarget = "#{safeRsrcDisk}#{safeFilename}"
                # Get attachment referred to by token
                attachment = Attachment.find_by_token(token)
                if(attachment)
                  mv = FileUtils.mv(attachment.diskfile(), finalTarget)
                  destr = attachment.destroy
                else
                  uploadFail << { :idx => idx, :failure => "Token (#{token.inspect}) is invalid. No matching uploaded file. Perhaps old token that has already been processed?" }
                end
              else
                uploadFail << { :idx => idx, :failure => "The filename field either starts with '.' and/or has a '..' parent link in it. These are not allowed."}
              end
            else
              uploadFail << { :idx => idx, :failure => "Required 'token' and/or 'filename' fields are missing." }
            end
          rescue => ene
            $stderr.puts "EXCEPTION - #{self.class}##{__method__}() - Message: #{ene.message} ; Trace:\n#{ene.backtrace.join("\n")}\n\n"
            uploadFail << { :idx => idx, :failure => "An existing FILE is present that conflicts with a directory you put in the path (probably on of the dirs mentioned in your 'filename' field)." }
          rescue => ena
            $stderr.puts "EXCEPTION - #{self.class}##{__method__}() - Message: #{ena.message} ; Trace:\n#{ena.backtrace.join("\n")}\n\n"
            uploadFail << { :idx => idx, :failure => "SERVER ERROR: could not write to target directory due to permission/ownership problem. Contact your Redmine admin so this can be resolved." }
          rescue => err
            # Many errors are due to user indicating paths that conflict with existing files.
            # We will log the details, but this exception is handled because we expsect it even
            # for just some of the uploads mentioned, but perhaps not all.
            $stderr.puts "EXCEPTION - #{self.class}##{__method__}() - Message: #{err.message} ; Trace:\n#{err.backtrace.join("\n")}\n\n"
            uploadFail << { :idx => idx, :failure => "SERVER ERROR: unexpected error, unlikely your fault. Contact your Redmine admin so this can be resolved. (Details: #{err.class.inspect} => #{err.message.inspect} )" }
          end
        }
        @result = { :targetDir => safeRsrc, :numUploads => uploads.size, :numOK => (uploads.size - uploadFail.size), :numFail => uploadFail.size }
        if(uploadFail.size <= 0)
          @result[:message] = "All OK"
        else
          @result[:message] = "Not all your uploads were successful; #{uploadFail.size} failed. See the details in 'failures'."
          uploadFail.sort { |aa,bb| aa[idx] <=> bb[idx] }
          @result[:failures] = uploadFail
        end
      else
        @haveError = true
        @result[:message] = "ERROR: Could not create target directory named #{@origReqRsrc.inspect} (disk-safe name: #{safeRsrc.inspect}). Most likely that dir path conflicts with an existing FILE for one of the dirs in the path (i.e. one of those dirs already exists as a FILE)."
      end
    else
      @haveError = true
      @result[:message] = "ERROR: You didn't specify format=json or your JSON payload does not have a valid structure for creating/updating a rawcontent file/dir."
    end

    # This action does direct json rendering ONLY. Doesn't go through view.
    # Direct rendering works around the ext-is-format-for-view issue and errors
    # that come up with dirs named with .txt ending etc.
    if(@haveError)
      render :json => { :rawcontent => @result }, :status => 400
    else
      render :json => { :rawcontent => @result }
    end
  end

  # ------------------------------------------------------------------
  # PRIVATE HELPERS
  # ------------------------------------------------------------------

  private

  def preAction()
    @reqRsrc = params[:request_path]
    @contentDirRsrcPath = ("#{@reqRsrc}/" or "/")
    @tocFiles = []
    @railsFmt = params[:format]
    @nvPairs = get_orig_query()
    @respFormat = @nvPairs['format']
    @respFormat = ( (@respFormat.nil? or @respFormat.empty?) ? @railsFmt : @respFormat.first )
    @origReqRsrc = get_orig_path(@reqRsrc, @railsFmt, @respFormat)
    @rawRequestUri = request.env['REQUEST_URI'].to_s.strip # Before Rails gets at it and strips off / or even strips off /// (Rails hates terminal /...they don't indicate "actions")
    @diskPath = get_real_path(@origReqRsrc)
    return
  end
  
  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Return the path to the rawconent root directory for the current project.
  # @note As a side effect, this will ensure the project's rawcontent dir actually exists!
  def get_project_directory
    @project_directory ||= Setting.plugin_genboree_rawcontent['path'].to_s.gsub('{PROJECT}', @project.identifier)
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
    #$stderr.puts "DEBUG - #{__method__}() => dir: #{dir.inspect} ;;; real: #{real.inspect}"
    raise GenboreeRawcontentControllerError, "ERROR: tried to access a content file or directory (#{origReqRsrc.inspect}) that doesn't actually exist on disk." unless(real.starts_with?(dir) && File.exist?(real))
    return real
  end

  # @param [String] path Full disk path for a rawcontent file/dir.
  # @return [String] The resource path of rawcontent file/dir, given the full disk path for a rawcontent file/dir.
  def get_rsrc_path(diskPath)
    projDir = get_project_directory()
    projDir.chomp!('/')
    projDir = "#{projDir}/"
    return diskPath.gsub(/#{Regexp.escape(projDir)}/, '')
  end

  # Returns the index file in the given directory, if present.
  # @param [String] dir The directory in which to look for index file.
  # @return [String,nil] The path to the file or nil if no index file found.
  def get_index_file(dir)
    # What are the known/acceptable index files on this installation?
    indexes = Setting.plugin_genboree_rawcontent['index'].to_s.split
    # Find first known index file that is present.
    file = indexes.find {|ff| File.exist?(File.join(dir, ff)) }
    file = File.join(dir, file) if(file)
    return file
  end

  # Get the size of the file or dir item.
  # @param [String] fileOrDir Path to file or dir want size for.
  # @return [Fixnum,nil] If no such file, not a file or a dir, or not readable, or other error, then will return nil. Else size in bytes.
  def sizeOnDisk(fileOrDir)
    retVal = nil
    if(File.exist?(fileOrDir))
      if(File.file?(fileOrDir))
        retVal = File.size(fileOrDir) rescue nil
      elsif(File.directory?(fileOrDir))
        duOut = `du -b -s #{Shellwords.escape(fileOrDir)}`
        if($?.success? and duOut and !duOut.empty? and duOut =~ /^(\d+)\s/)
          retVal = $1.to_i
        end
      else
        retVal = nil
      end
    end
    return retVal
  end

  def showContent(diskPath=@diskPath, origReqRsrc=@origReqRsrc)
    @content = @title = nil

    # @todo unforce this and make a feature (or new plugin)
    # Should we wrap in Redmine layout or not? Future: new plugin or integrate here for this.
    useRedmineLayout = false

    if(useRedmineLayout) # Not "RAW" content, WRAPPED. Not yet supported ; see comments above.
      # @todo Redmine::MimeType is using extension-convention and a map to determine mime-type. YUCK.
      #   Perhaps replace with more comprehensive version based on "file -b --mime-type {path}"??
      #   Although some of interface is nice (like to check for text/html vs non-html etc)

      # If looks like html we will wrap in Redmine layout. Else send raw file.
      if(Redmine::MimeType.is_type?('text') and Redmine::MimeType.sub_mimetype_of(path) =~ /html/i)
        # Then looks like html.
        @content = prepEmbeddedFile(diskPath, origReqRsrc)
        render :action => 'show'
      else
        # Then non-html. Like image or something. Send content as-is with best mime-type.
        send_file(diskPath, :disposition => 'inline', :type => (Redmine::MimeType.of(diskPath) or Redmine::MimeType::DEFAULT_MIME_TYPE) )
      end
    else # RAW Content!
      # Send as-is.
      send_file(diskPath, :disposition => 'inline', :type => (Redmine::MimeType.of(diskPath) or Redmine::MimeType::DEFAULT_MIME_TYPE) )
      # @toto Invesigate if .erb files can be rendered sensibly or not.
      # * This also seems to work fine for html. But maybe .erb files get properly processed?? Dunno...but consider:
      #     render(@diskPath, :layout => false)
    end

  rescue Errno::ENOENT => noe
    render_error "ERROR: No such file on disk for #{origReqRsrc.inspect}. Error message: #{noe.message}"
  rescue Errno::EACCES => noa
    # Can not read the file
    render_error "ERROR: Unable to read the file #{origReqRsrc.inspect}. Error message: #{noe.message}"
  rescue GenboreeRawcontentControllerError => grcce
    render_error grcce.message
  end

  # Preps HTML file content for rendering within Redmine layout.
  #   Will strip it down to just <body> content. More correctly removes <html> tag,
  #   <body> tag, and whole <head> section. That allows html partials to be embedded in Redmine page body.
  # @param [String,Array] path The path to the html file.
  # @param [String] reqFile The file requested (not real path to disk file, just URL path)
  # @raise GenboreeRawcontentControllerError If file is too big.
  def prepEmbeddedFile(path, reqFile)
    # Max size for embedded html?
    maxSize = Setting.plugin_genboree_rawcontent['maxEmbedFileSize'].to_i
    fileSize = File.size(path)
    if(fileSize <= maxSize)
      @content = File.read(path)

      # Extract html title from embedded page
      if(@content =~ %r{<title>([^<]*)</title>}mi)
        @title = $1.strip
      end

      # Remove <html> and </html> tags
      @content.gsub!(%r{<html[^>]*>}i, '')
      @content.gsub!(%r{</ *html *>}i, '')
      # Remove whole <head> section
      @content.gsub!(%r{<head[^>]*>.*</ *head *>}i, '')
      # Remove <body> and </body> tags
      @content.gsub!(%r{<body[^>]*>}i, '')
      @content.gsub!(%r{</ *body *>}i, '')

      # What remains we will use as an html-partial. Works for actual partials (which may not have <body> tags or <html> or <head>)

    else
      raise GenboreeRawcontentControllerError, "ERROR: the file #{reqFile.inspect} is too big to be rendered within the page."
    end
    return @content
  end

  def validateCreate()
    retVal = false
    if(@respFormat == 'json')
      if(params.is_a?(Hash))
        rawcontent = params["rawcontent"]
        if(rawcontent.is_a?(Hash) and rawcontent["uploads"].is_a?(Array))
          retVal = true
        end
      end
    end
    return retVal
  rescue => ee
    return false
  end

  # Used in create() to make safe file name. Adapted from Redmine's Attachment.sanitize_filename model (where method is private).
  def sanitizePath(path)
    elems = path.split(/\//)
    newElems = []
    elems.each { |elem|
      newElems << elem.gsub(/[^\w _\^\.\-]/,'_')
    }
    return File.join(newElems)
  end
end
