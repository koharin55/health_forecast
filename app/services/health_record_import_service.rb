require 'csv'

class HealthRecordImportService
  class Error < StandardError; end

  HEADER_MAP = {
    "記録日" => :recorded_at,
    "体調スコア" => :mood,
    "体重(kg)" => :weight,
    "睡眠時間(h)" => :sleep_hours,
    "運動時間(分)" => :exercise_minutes,
    "歩数" => :steps,
    "心拍数(bpm)" => :heart_rate,
    "最高血圧(mmHg)" => :systolic_pressure,
    "最低血圧(mmHg)" => :diastolic_pressure,
    "体温(℃)" => :body_temperature,
    "メモ" => :notes
  }.freeze

  def initialize(user, file_content, duplicate_strategy: 'skip')
    @user = user
    @file_content = file_content
    @duplicate_strategy = duplicate_strategy
  end

  def import
    result = { imported: 0, skipped: 0, errors: [] }

    content = strip_bom(@file_content)

    if content.blank?
      result[:errors] << 'CSVデータが空です'
      return result
    end

    rows = CSV.parse(content, headers: true)

    unless rows.headers.include?('記録日')
      result[:errors] << '必須列「記録日」がCSVに含まれていません'
      return result
    end

    cache_existing_records(rows)

    rows.each.with_index(2) do |row, line_number|
      process_row(row, line_number, result)
    end

    result
  end

  private

  def strip_bom(content)
    content = content.dup.force_encoding(Encoding::UTF_8)
    content.sub(/\A\xEF\xBB\xBF/, '')
  end

  def cache_existing_records(rows)
    dates = rows.map { |r| r['記録日'] }.compact.filter_map do |d|
      Date.parse(d)
    rescue Date::Error
      nil
    end

    @existing_records = @user.health_records
      .where(recorded_at: dates)
      .index_by(&:recorded_at)
  end

  def process_row(row, line_number, result)
    attributes = build_attributes(row)

    if attributes[:recorded_at].blank?
      result[:errors] << "#{line_number}行目: 記録日が空です"
      return
    end

    existing = @existing_records[attributes[:recorded_at]]

    if existing
      if @duplicate_strategy == 'overwrite'
        if existing.update(attributes)
          result[:imported] += 1
        else
          result[:errors] << "#{line_number}行目: #{existing.errors.full_messages.join(', ')}"
        end
      else
        result[:skipped] += 1
      end
    else
      record = @user.health_records.build(attributes)
      if record.save
        result[:imported] += 1
      else
        result[:errors] << "#{line_number}行目: #{record.errors.full_messages.join(', ')}"
      end
    end
  end

  def build_attributes(row)
    attributes = {}
    HEADER_MAP.each do |header, column|
      value = row[header]
      next if value.blank?

      attributes[column] = cast_value(column, value.strip)
    end
    attributes
  end

  def cast_value(column, value)
    case column
    when :recorded_at
      Date.parse(value)
    when :mood, :exercise_minutes, :steps, :heart_rate,
         :systolic_pressure, :diastolic_pressure
      value.to_i
    when :weight, :sleep_hours, :body_temperature
      value.to_f
    when :notes
      value
    end
  rescue Date::Error
    nil
  end
end
