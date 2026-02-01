class HealthRecord < ApplicationRecord
  belongs_to :user

  validates :recorded_at, presence: true
  validates :mood, inclusion: { in: 1..5, allow_nil: true }
  validates :weight, numericality: { greater_than: 0, allow_nil: true }
  validates :sleep_hours, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :exercise_minutes, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :steps, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :heart_rate, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :systolic_pressure, numericality: {
    greater_than_or_equal_to: 60,
    less_than_or_equal_to: 250,
    only_integer: true,
    allow_nil: true
  }
  validates :diastolic_pressure, numericality: {
    greater_than_or_equal_to: 40,
    less_than_or_equal_to: 150,
    only_integer: true,
    allow_nil: true
  }
  validates :body_temperature, numericality: {
    greater_than_or_equal_to: 34.0,
    less_than_or_equal_to: 42.0,
    allow_nil: true
  }

  scope :recent, -> { order(recorded_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
end
