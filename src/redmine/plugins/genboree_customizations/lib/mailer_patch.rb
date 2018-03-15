require_dependency 'mailer'

module MailerPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :mail, :add_subject_prefix
    end
  end

  module InstanceMethods
    EMAIL_SPECIAL_X_HEADERS = [ :x_no_auto_subject_prefix, :x_no_auto_reply_to ]

    # We are intercepting the Mailer#mail method.
    # - we will mess with the header :subject a bit
    # - then we will call the original method (provided automatically in mail_without_add_subject_prefix

    def mail_with_add_subject_prefix(headers={}, &block)
      #$stderr.puts "\n\nmail shim starting!\n\n"

      # Add subject prefix to :subject
      headers = headers.dup
      # Make sure there is SOME subject and nudge dev to rethink lazy code.
      headers[:subject] ||= '[Bug: no informative subject]'
      # Add global Subject prefix if not there and not suppressed.
      unless( headers[:x_no_auto_subject_prefix] or headers[:subject] =~ /^#{Setting.emails_subject_prefix}/ )
        headers[:subject] = "#{Setting.emails_subject_prefix} #{headers[:subject]}"
      end
      # Make sure there is a sensible Reply-To email header (if available). Might be different than :from header
      globalReplyTo = Setting.emails_reply_to rescue nil
      if( globalReplyTo )
        unless( headers[:x_no_auto_reply_to] or !headers[:reply_to].blank? )
          headers[:reply_to] = Setting.emails_reply_to
        end
      end

      # Clean up the special X- headers
      EMAIL_SPECIAL_X_HEADERS.each { |hdr|
        headers.delete(hdr)
      }

      #$stderr.puts "\n\nheaders now: #{headers.inspect}\n\n"

      # Call original method we intercepted
      return mail_without_add_subject_prefix(headers, &block)
    end
  end
end

# Now apply our patched method to the core Redmine Mailer class via module include:
Mailer.send(:include, MailerPatch)
