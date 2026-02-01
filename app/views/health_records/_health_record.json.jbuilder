json.extract! health_record, :id, :recorded_at, :weight, :sleep_hours, :exercise_minutes, :mood, :notes, :steps, :heart_rate, :created_at, :updated_at
json.url health_record_url(health_record, format: :json)
