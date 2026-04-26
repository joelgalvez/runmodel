class AddRemoteJobIdToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :remote_job_id, :integer
  end
end
