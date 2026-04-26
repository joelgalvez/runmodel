class AddModelToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :model, :string
  end
end
