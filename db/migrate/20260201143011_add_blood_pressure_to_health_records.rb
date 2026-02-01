class AddBloodPressureToHealthRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :health_records, :systolic_pressure, :integer
    add_column :health_records, :diastolic_pressure, :integer
  end
end
