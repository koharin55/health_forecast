class HealthRecord < ApplicationRecord
  MERGEABLE_ATTRIBUTES = %w[
    weight sleep_hours exercise_minutes mood notes steps
    heart_rate systolic_pressure diastolic_pressure body_temperature
  ].freeze

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
  validates :weather_humidity, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100,
    only_integer: true,
    allow_nil: true
  }
  validates :weather_pressure, numericality: {
    greater_than_or_equal_to: 870,
    less_than_or_equal_to: 1084,
    allow_nil: true
  }

  scope :recent, -> { order(recorded_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :with_weather, -> { where.not(weather_code: nil) }
  scope :with_mood, -> { where.not(mood: nil) }
  scope :with_weather_and_mood, -> { with_weather.with_mood.where.not(weather_pressure: nil) }

  # 天候データを取得して設定
  def fetch_and_set_weather!
    return false unless user.location_configured?

    service = WeatherService.new(
      latitude: user.latitude,
      longitude: user.longitude
    )

    weather = service.fetch_weather_for_date(recorded_at)
    return false unless weather

    self.weather_temperature = weather[:temperature]
    self.weather_humidity = weather[:humidity]
    self.weather_pressure = weather[:pressure]
    self.weather_code = weather[:weather_code]
    self.weather_description = weather[:weather_description]
    true
  rescue WeatherService::Error => e
    Rails.logger.error("HealthRecord#fetch_and_set_weather! error: #{e.message}")
    false
  end

  # 天候データが存在するか
  def has_weather_data?
    weather_code.present? || weather_description.present?
  end

  # 天気アイコンを取得
  def weather_icon
    return nil unless has_weather_data?
    return WeatherService.weather_icon(weather_code) if weather_code.present?

    code = WeatherService.code_from_description(weather_description)
    code ? WeatherService.weather_icon(code) : "🌡️"
  end

  # 天気の表示文字列を取得
  def weather_display
    return nil unless has_weather_data?
    "#{weather_icon} #{weather_description}"
  end

  # 気圧レベルを判定（低気圧警告用）
  def pressure_level
    return nil unless weather_pressure

    case weather_pressure
    when 0...1000
      :low
    when 1000...1013
      :slightly_low
    when 1013...1020
      :normal
    else
      :high
    end
  end

  def self.create_or_merge_for_date(user:, recorded_at:, attributes:)
    transaction do
      record = user.health_records.find_by(recorded_at: recorded_at)

      if record
        merge_attrs = {}
        attributes.each do |key, value|
          key_s = key.to_s
          next unless MERGEABLE_ATTRIBUTES.include?(key_s)
          next if value.nil?

          merge_attrs[key_s] = value if record[key_s].nil?
        end
        record.update!(merge_attrs) if merge_attrs.any?
        { record: record.reload, merged: true }
      else
        record = user.health_records.create!(
          attributes.slice(*MERGEABLE_ATTRIBUTES.map(&:to_sym)).merge(recorded_at: recorded_at)
        )
        { record: record, merged: false }
      end
    end
  end
end
