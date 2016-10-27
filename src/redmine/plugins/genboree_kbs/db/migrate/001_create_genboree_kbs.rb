class CreateGenboreeKbs < ActiveRecord::Migration
  def change
    create_table :genboree_kbs do |t|
      t.integer :id
      t.integer :project_id
      t.string :name
      t.string :description
      t.string :gbGroup
      t.string :gbHost
    end
  end
end
