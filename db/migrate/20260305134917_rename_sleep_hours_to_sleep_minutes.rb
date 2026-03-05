class RenameSleepHoursToSleepMinutes < ActiveRecord::Migration[7.1]
  def up
    add_column :health_records, :sleep_minutes, :integer
    execute <<~SQL
      UPDATE health_records
      SET sleep_minutes = ROUND(sleep_hours * 60)
      WHERE sleep_hours IS NOT NULL
    SQL
    remove_column :health_records, :sleep_hours
  end

  def down
    add_column :health_records, :sleep_hours, :decimal
    execute <<~SQL
      UPDATE health_records
      SET sleep_hours = ROUND(sleep_minutes / 60.0, 1)
      WHERE sleep_minutes IS NOT NULL
    SQL
    remove_column :health_records, :sleep_minutes
  end
end
