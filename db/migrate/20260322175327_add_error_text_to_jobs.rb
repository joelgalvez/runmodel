class AddErrorTextToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :error_text, :text
  end
end
