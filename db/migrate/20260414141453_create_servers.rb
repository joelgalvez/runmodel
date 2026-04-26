class CreateServers < ActiveRecord::Migration[8.1]
  def change
    create_table :servers do |t|
      t.string :url
      t.string :login
      t.string :password

      t.timestamps
    end
  end
end
