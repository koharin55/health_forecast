class AddBodyTemperatureToHealthRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :health_records, :body_temperature, :decimal
  end
end
