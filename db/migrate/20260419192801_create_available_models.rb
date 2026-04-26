class CreateAvailableModels < ActiveRecord::Migration[8.1]
  def change
    create_table :available_models do |t|
      t.string :name

      t.timestamps
    end
  end
end
