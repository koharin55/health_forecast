class CreateWeeklyReports < ActiveRecord::Migration[7.1]
  def change
    create_table :weekly_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.date :week_start, null: false
      t.date :week_end, null: false
      t.text :content, null: false
      t.json :summary_data
      t.json :predictions
      t.integer :tokens_used

      t.timestamps
    end

    add_index :weekly_reports, [:user_id, :week_start], unique: true
  end
end
