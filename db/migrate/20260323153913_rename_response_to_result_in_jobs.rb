class RenameResponseToResultInJobs < ActiveRecord::Migration[8.1]
  def change
    rename_column :jobs, :response, :result
  end
end
