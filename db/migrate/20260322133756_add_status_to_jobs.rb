class AddStatusToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :status, :string
  end
end
