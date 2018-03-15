class AddColumnToClingenResourceSettings < ActiveRecord::Migration
  def change
    add_column :clingen_resource_settings, :project_id, :integer
  end
end
