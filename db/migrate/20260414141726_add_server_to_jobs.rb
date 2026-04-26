class AddServerToJobs < ActiveRecord::Migration[8.1]
  def change
    add_reference :jobs, :server, foreign_key: true
  end
end
