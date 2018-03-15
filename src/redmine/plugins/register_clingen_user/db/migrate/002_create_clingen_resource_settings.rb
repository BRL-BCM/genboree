class CreateClingenResourceSettings < ActiveRecord::Migration
  def change
    create_table :clingen_resource_settings do |t|
      t.string  :gb_host
      t.string  :acmg_guideline_rest
      t.string  :acmg_transformation_rest
      t.string  :acmg_allowed_tags_rest
      t.string  :gb_public_tool_user, :default => 'gbPublicToolUser'
      t.string  :gb_cache_user, :default => 'gbCacheUser'
      t.string  :registry_grp, :default => 'Registry'
      t.string  :configuration_group, :default => 'pcalc_resources'
      t.string  :configuration_kb, :default => 'pcalc_resources'
      t.string  :cache_group, :default => 'pcalc_cache'
      t.string  :cache_kb, :default => 'pcalc_cache'
      t.string  :privilaged_user
    end
  end
end
