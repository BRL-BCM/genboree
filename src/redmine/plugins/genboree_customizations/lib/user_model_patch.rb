require_dependency 'user'

module GenboreeCustomizations
  module Patches
    module UserPatch
      def self.included(base)
        base.class_eval {
          validates_uniqueness_of :mail, :if => Proc.new { |user| $stderr.puts "Have user.errors? #{user.errors.inspect rescue 'NO'}" ; user.errors.delete(:mail) if(user.errors and Setting.plugin_genboree_customizations and Setting.plugin_genboree_customizations['allow_non_uniq_emails'] == 'true') ;  $stderr.puts "Have user.errors AFTER?\n\n#{user.errors.inspect rescue 'NO'}\n\n" }
          $stderr.puts "DEBUG: possible re-do of validation uniq"
        }
      end
    end
  end
end

ActionDispatch::Callbacks.to_prepare {
  User.send(:include, GenboreeCustomizations::Patches::UserPatch)
}
