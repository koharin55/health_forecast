class AddWeatherToHealthRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :health_records, :weather_temperature, :decimal, precision: 4, scale: 1
    add_column :health_records, :weather_humidity, :integer
    add_column :health_records, :weather_pressure, :decimal, precision: 6, scale: 1
    add_column :health_records, :weather_code, :integer
    add_column :health_records, :weather_description, :string
  end
end
