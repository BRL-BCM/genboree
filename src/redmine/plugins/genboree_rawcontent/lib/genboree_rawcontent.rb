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

# Extend Redmine::MimeType definition.
# @todo Redmine::MimeType is using extension-convention and a map to determine mime-type. YUCK.
#   Perhaps replace with more comprehensive version based on "file -b --mime-type {path}"??
#   Although some of interface is nice (like to check for text/html vs non-html etc)
module Redmine
  module MimeType
    DEFAULT_MIME_TYPE = "application/octet-stream"
    def self.sub_mimetype_of(name)
      mimetype = of(name)
      mimetype.split('/').second if(mimetype)
    end
  end
end

# Plugin
module Redmine
  module Plugins
    module GenboreeRawcontent
      class << self

        # Is a given file extension allowed/valid (by default ALL are, including none, but Settings can override this)
        def valid_extension?(path)
          extensions = Setting.plugin_genboree_rawcontent['extensions'].to_s
          extsRE = Regexp.new(extensions, Regexp::IGNORECASE)
          pathExt = File.extname(path)
          retVal = (pathExt =~ extRE ? true : false)
        end

      end
    end
  end
end

class << RedmineApp::Application ; self ; end.class_eval {
  define_method :clear!, lambda {}
}
