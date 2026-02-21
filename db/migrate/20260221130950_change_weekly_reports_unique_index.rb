class ChangeWeeklyReportsUniqueIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index :weekly_reports, [:user_id, :week_start], unique: true
    add_index :weekly_reports, [:user_id, :week_start, :week_end], unique: true,
              name: "index_weekly_reports_on_user_id_and_period"
  end
end
