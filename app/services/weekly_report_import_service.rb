class WeeklyReportImportService
  class Error < StandardError; end

  REQUIRED_FIELDS = %w[week_start week_end content].freeze
  MAX_FILE_SIZE = 5.megabytes

  BuildResult = Struct.new(:attributes, :created_at)

  def initialize(user, file_content, duplicate_strategy: 'skip')
    @user = user
    @file_content = file_content
    @duplicate_strategy = duplicate_strategy
  end

  def import
    result = { imported: 0, skipped: 0, errors: [] }

    data = parse_json(result)
    return result if data.nil?

    reports = data['reports']
    unless reports.is_a?(Array)
      result[:errors] << 'JSONの形式が正しくありません（reports配列が見つかりません）'
      return result
    end

    cache_existing_reports(reports)

    reports.each.with_index(1) do |report_data, index|
      process_entry(report_data, index, result)
    end

    result
  end

  private

  def parse_json(result)
    data = JSON.parse(@file_content)
    unless data.is_a?(Hash) && data.key?('reports')
      result[:errors] << 'JSONの形式が正しくありません'
      return nil
    end
    data
  rescue JSON::ParserError
    result[:errors] << 'JSONファイルの解析に失敗しました'
    nil
  end

  def cache_existing_reports(reports)
    pairs = reports.filter_map do |r|
      next unless r.is_a?(Hash) && r['week_start'] && r['week_end']

      [Date.parse(r['week_start']), Date.parse(r['week_end'])]
    rescue ArgumentError
      nil
    end

    starts = pairs.map(&:first)
    ends   = pairs.map(&:last)

    @existing_reports = @user.weekly_reports
                             .where(week_start: starts, week_end: ends)
                             .index_by { |r| [r.week_start, r.week_end] }
  end

  def process_entry(report_data, index, result)
    unless report_data.is_a?(Hash)
      result[:errors] << "#{index}件目: 不正なデータ形式です（オブジェクトを期待しています）"
      return
    end

    missing = REQUIRED_FIELDS.select { |f| report_data[f].blank? }
    if missing.any?
      result[:errors] << "#{index}件目: 必須項目(#{missing.join(', ')})が不足しています"
      return
    end

    build_result = build_attributes(report_data)
    if build_result.nil?
      result[:errors] << "#{index}件目: 日付の形式が正しくありません"
      return
    end

    key = [build_result.attributes[:week_start], build_result.attributes[:week_end]]
    existing = @existing_reports[key]

    if existing
      handle_duplicate(existing, build_result, index, result)
    else
      create_report(build_result, index, result)
    end
  end

  def build_attributes(report_data)
    week_start = Date.parse(report_data['week_start'])
    week_end   = Date.parse(report_data['week_end'])
    created_at = report_data['created_at'] ? Time.zone.parse(report_data['created_at']) : nil

    attributes = {
      week_start: week_start,
      week_end: week_end,
      content: report_data['content'],
      summary_data: report_data['summary_data'],
      predictions: report_data['predictions'],
      tokens_used: report_data['tokens_used']&.to_i
    }

    BuildResult.new(attributes, created_at)
  rescue ArgumentError
    nil
  end

  def handle_duplicate(existing, build_result, index, result)
    if @duplicate_strategy == 'overwrite'
      if existing.update(build_result.attributes)
        # created_at はモデル経由で更新できないため update_columns を使用
        # rubocop:disable Rails/SkipsModelValidations
        existing.update_columns(created_at: build_result.created_at) if build_result.created_at
        # rubocop:enable Rails/SkipsModelValidations
        result[:imported] += 1
      else
        result[:errors] << "#{index}件目: #{existing.errors.full_messages.join(', ')}"
      end
    else
      result[:skipped] += 1
    end
  end

  def create_report(build_result, index, result)
    report = @user.weekly_reports.build(build_result.attributes)
    if report.save
      # created_at はモデル経由で更新できないため update_columns を使用
      # rubocop:disable Rails/SkipsModelValidations
      report.update_columns(created_at: build_result.created_at) if build_result.created_at
      # rubocop:enable Rails/SkipsModelValidations
      result[:imported] += 1
    else
      result[:errors] << "#{index}件目: #{report.errors.full_messages.join(', ')}"
    end
  end
end
