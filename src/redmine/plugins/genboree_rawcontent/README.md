
Genboree Raw Content
====================

Projects can have "raw pages" or "raw html" associated with them, like the deprecated Genboree Project "additional pages" and "additional files".

A key benefit is that in this case Redmine is enforcing ACL whereas the old Project additional pages did not; they were available to all.

This plugin is a severe adaptation, gutting, and replacement of the redmine_embedded plugin (found on GitHub) which in turn is a slight edit of Jean-Philippe's own embedded plugin.
* We are after more generic functionality, not documentation embedding.
* We want to be able to show the pages WITHOUT the Redmine layout.
* We will tightly integrate with Genboree (not presumed to work w/o Genboree, but it might).
* We don't need several features of embedded as a result.


Original note from redmine_embedded plugin:

Redmine  Embedded
================

Plugin for Redmine to embed Doxygen/Javadoc files based on the original by Jean-Philippe Lang but updated for Redmine 2 and Rails 3

To use, create a directory for the HTML documentation and set the owner to the same user as the webserver user running your Redmine installation. Default setting is "/var/doc".

Documentation should be a zip of the root html directory, prefereably compiled without search (CSS needs some work).
