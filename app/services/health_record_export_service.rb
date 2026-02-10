require 'csv'

class HealthRecordExportService
  class Error < StandardError; end

  BOM = "\xEF\xBB\xBF"

  HEADERS = %w[
    記録日 体調スコア 体重(kg) 睡眠時間(h) 運動時間(分) 歩数
    心拍数(bpm) 最高血圧(mmHg) 最低血圧(mmHg) 体温(℃) メモ
    天気 気温(℃) 湿度(%) 気圧(hPa)
  ].freeze

  COLUMNS = %i[
    recorded_at mood weight sleep_hours exercise_minutes steps
    heart_rate systolic_pressure diastolic_pressure body_temperature notes
    weather_description weather_temperature weather_humidity weather_pressure
  ].freeze

  def initialize(user)
    @user = user
  end

  def generate_csv
    csv_string = CSV.generate do |csv|
      csv << HEADERS
      records.each do |record|
        csv << COLUMNS.map { |col| format_value(record, col) }
      end
    end

    BOM.dup.force_encoding(Encoding::UTF_8) + csv_string
  end

  private

  def records
    @user.health_records.order(recorded_at: :desc)
  end

  def format_value(record, column)
    value = record.public_send(column)
    return nil if value.nil?

    case column
    when :recorded_at
      value.strftime('%Y-%m-%d')
    else
      value
    end
  end
end
