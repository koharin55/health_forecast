class CreateHealthRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :health_records do |t|
      t.references :user, null: false, foreign_key: true
      t.date :recorded_at
      t.decimal :weight
      t.decimal :sleep_hours
      t.integer :exercise_minutes
      t.integer :mood
      t.text :notes
      t.integer :steps
      t.integer :heart_rate

      t.timestamps
    end
  end
end
