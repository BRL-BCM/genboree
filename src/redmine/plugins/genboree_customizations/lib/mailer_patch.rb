require_dependency 'mailer'

module MailerPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :mail, :add_subject_prefix
    end
  end

  module InstanceMethods
    # We are intercepting the Mailer#mail method.
    # - we will mess with the header :subject a bit
    # - then we will call the original method (provided automatically in mail_without_add_subject_prefix

    def mail_with_add_subject_prefix(headers={}, &block)
      $stderr.puts "\n\nmail shim starting!\n\n"

      # Add subject prefix to :subject
      headers = headers.dup
      if(headers[:subject])
        headers[:subject] = "#{Setting.emails_subject_prefix} #{headers[:subject]}"
      end

      (headers[:reply_to] = Setting.emails_reply_to) rescue nil

      $stderr.puts "\n\nheaders now: #{headers.inspect}\n\n"

      # Call original method we intercepted
      return mail_without_add_subject_prefix(headers, &block)
    end
  end
end

# Now apply our patched method to the core Redmine Mailer class via module include:
Mailer.send(:include, MailerPatch)
