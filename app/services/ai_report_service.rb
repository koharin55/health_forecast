# frozen_string_literal: true

# AI週次レポート生成サービス
# Gemini APIを使用して健康データから週次レポートを生成
class AiReportService
  class Error < StandardError; end
  class ApiError < Error; end
  class InsufficientDataError < Error; end
  class ConfigurationError < Error; end

  GEMINI_MODEL = "gemini-2.5-flash"
  MINIMUM_PERIOD_RECORDS = 3
  DEFAULT_PERIOD_DAYS = 7
  MAX_PERIOD_DAYS = 31

  def initialize(user)
    @user = user
    validate_configuration!
  end

  # 週次レポートを生成
  # デフォルト: 直近7日間（昨日まで）を対象
  def generate_weekly_report(week_start: nil, week_end: nil)
    week_start ||= Date.current - DEFAULT_PERIOD_DAYS
    week_end ||= Date.current - 1

    result = check_sufficient_data(week_start, week_end)
    unless result[:sufficient]
      raise InsufficientDataError,
            "対象期間の記録が#{result[:count]}件しかありません。#{MINIMUM_PERIOD_RECORDS}件以上必要です"
    end

    prompt = build_prompt(week_start, week_end)
    response = call_gemini_api(prompt)
    content = parse_response(response)

    create_report(week_start, week_end, content, response)
  end

  # 対象期間のバリデーション（エラーメッセージ or nil）
  def validate_period(week_start, week_end)
    if week_start > Date.current || week_end > Date.current
      "未来の日付は指定できません"
    elsif week_end < week_start
      "終了日は開始日より後の日付を指定してください"
    elsif (week_end - week_start).to_i + 1 > MAX_PERIOD_DAYS
      "対象期間は最大#{MAX_PERIOD_DAYS}日間までです"
    end
  end

  # 対象期間内のデータ件数と十分性を返す（1回のクエリで完結）
  def check_sufficient_data(week_start = nil, week_end = nil)
    week_start ||= Date.current - DEFAULT_PERIOD_DAYS
    week_end ||= Date.current - 1
    count = period_record_count(week_start, week_end)
    {
      sufficient: count >= MINIMUM_PERIOD_RECORDS,
      count: count,
      required: MINIMUM_PERIOD_RECORDS
    }
  end

  private

  def period_record_count(week_start, week_end)
    @user.health_records.where(recorded_at: week_start..week_end).count
  end

  def validate_configuration!
    return if api_key.present?

    raise ConfigurationError, "GEMINI_API_KEYが設定されていません"
  end

  def api_key
    @api_key ||= Rails.application.credentials.dig(:gemini_api_key) || ENV["GEMINI_API_KEY"]
  end

  def client
    @client ||= Gemini.new(
      credentials: {
        service: "generative-language-api",
        api_key: api_key
      },
      options: { model: GEMINI_MODEL, server_sent_events: true }
    )
  end

  def call_gemini_api(prompt)
    result = client.stream_generate_content({
      contents: { role: "user", parts: { text: prompt } }
    })
    result
  rescue StandardError => e
    Rails.logger.error("AiReportService API error: #{e.message}")
    raise ApiError, "AIレポートの生成に失敗しました: #{e.message}"
  end

  def parse_response(response)
    return "" if response.blank?

    # stream_generate_contentは配列で返ってくる
    text_parts = response.map do |chunk|
      chunk.dig("candidates", 0, "content", "parts", 0, "text")
    end.compact

    text_parts.join("")
  end

  def build_prompt(week_start, week_end)
    health_records = fetch_weekly_records(week_start, week_end)
    historical_data = fetch_historical_summary
    forecast_data = fetch_forecast_data
    analysis_data = fetch_analysis_data

    <<~PROMPT
      あなたは健康管理アドバイザーです。
      以下のデータを分析し、週次ヘルスレポートを生成してください。

      ## 対象期間
      #{week_start.strftime('%Y年%m月%d日')}〜#{week_end.strftime('%m月%d日')}

      ## 今週の健康記録データ
      #{format_health_records(health_records)}

      ## 過去30日間の傾向サマリー
      #{format_historical_summary(historical_data)}

      ## 気象感度分析
      #{format_analysis_data(analysis_data)}

      ## 翌週の天気予報
      #{format_forecast_data(forecast_data)}

      ## レポート作成ガイドライン
      以下の形式でMarkdownレポートを生成してください：

      ## 📊 今週の振り返り
      （体調・睡眠・運動などの傾向を100字程度でまとめる）

      ## 🔍 傾向分析
      （過去データからのパターン発見を箇条書き3-5点）

      ## 🌤️ 来週の注意日
      （天気予報から体調に影響しそうな日をピックアップ）

      ## 💡 具体的なアドバイス
      （生活習慣の改善提案を3点）

      ## 🩹 体調不良時の対処法
      （メモの内容や傾向から推測される回復方法）

      注意事項：
      - データがない項目は「記録なし」と明記
      - 具体的な数値を引用して説得力を持たせる
      - 前向きで実行可能なアドバイスを心がける
      - 日付表示は「2/5(水)」のような形式で
    PROMPT
  end

  def fetch_weekly_records(week_start, week_end)
    @user.health_records
         .where(recorded_at: week_start..week_end)
         .order(recorded_at: :asc)
  end

  def fetch_historical_summary
    records = @user.health_records
                   .where(recorded_at: 30.days.ago..Date.current)
                   .order(recorded_at: :asc)

    return {} if records.empty?

    {
      count: records.count,
      avg_mood: records.where.not(mood: nil).average(:mood)&.round(2),
      avg_sleep: records.where.not(sleep_minutes: nil).average(:sleep_minutes)&.round(0),
      avg_exercise: records.where.not(exercise_minutes: nil).average(:exercise_minutes)&.round(0),
      notes: records.where.not(notes: [nil, ""]).pluck(:notes).last(5)
    }
  end

  def fetch_forecast_data
    return [] unless @user.location_configured?

    service = WeatherService.new(
      latitude: @user.latitude,
      longitude: @user.longitude
    )
    service.fetch_forecast_days(days: 7)
  rescue WeatherService::Error => e
    Rails.logger.warn("AiReportService forecast fetch failed: #{e.message}")
    []
  end

  def fetch_analysis_data
    service = HealthAnalysisService.new(@user)
    return {} unless service.sufficient_data?

    service.analyze_weather_sensitivity
  rescue HealthAnalysisService::Error => e
    Rails.logger.warn("AiReportService analysis failed: #{e.message}")
    {}
  end

  def format_health_records(records)
    return "記録なし" if records.empty?

    records.map do |r|
      parts = ["- #{r.recorded_at.strftime('%m/%d')}:"]
      parts << "体調#{r.mood}/5" if r.mood.present?
      parts << "睡眠#{r.sleep_duration_text}" if r.sleep_minutes.present?
      parts << "運動#{r.exercise_minutes}分" if r.exercise_minutes.present?
      parts << "体重#{r.weight}kg" if r.weight.present?
      parts << "血圧#{r.systolic_pressure}/#{r.diastolic_pressure}" if r.systolic_pressure.present?
      parts << "体温#{r.body_temperature}℃" if r.body_temperature.present?
      parts << "気圧#{r.weather_pressure}hPa" if r.weather_pressure.present?
      parts << "メモ「#{r.notes.truncate(50)}」" if r.notes.present?
      parts.join(" ")
    end.join("\n")
  end

  def format_historical_summary(data)
    return "データ不足" if data.empty?

    parts = []
    parts << "- 記録数: #{data[:count]}件"
    parts << "- 平均体調スコア: #{data[:avg_mood]}/5" if data[:avg_mood]
    parts << "- 平均睡眠時間: #{HealthRecord.format_minutes_to_duration(data[:avg_sleep])}" if data[:avg_sleep]
    parts << "- 平均運動時間: #{data[:avg_exercise]}分" if data[:avg_exercise]
    if data[:notes]&.any?
      parts << "- 最近のメモ:"
      data[:notes].each { |note| parts << "  - 「#{note.truncate(30)}」" }
    end
    parts.join("\n")
  end

  def format_analysis_data(data)
    return "分析データなし（記録を増やすと分析可能になります）" if data.empty?

    parts = []
    parts << "- 気象感度スコア: #{data[:sensitivity_score]}/100"
    parts << "- 気圧と体調の相関係数: #{data[:pressure_correlation]}" if data[:pressure_correlation]

    if data[:mood_by_pressure].present?
      parts << "- 気圧別平均体調:"
      data[:mood_by_pressure].each do |group, info|
        label = { low: "低気圧", slightly_low: "やや低い", normal: "通常", high: "高気圧" }[group]
        parts << "  - #{label}: #{info[:average]}/5 (#{info[:count]}件)"
      end
    end

    parts.join("\n")
  end

  def format_forecast_data(data)
    return "天気予報なし（地域設定を行うと表示されます）" if data.empty?

    data.map do |day|
      wday = %w[日 月 火 水 木 金 土][day[:date].wday]
      "- #{day[:date].strftime('%m/%d')}(#{wday}): #{day[:weather_description]} 気圧#{day[:pressure]&.round}hPa"
    end.join("\n")
  end

  def create_report(week_start, week_end, content, response)
    tokens_used = extract_tokens_used(response)
    summary_data = build_summary_data(week_start, week_end)
    predictions = build_predictions_data

    @user.weekly_reports.create!(
      week_start: week_start,
      week_end: week_end,
      content: content,
      summary_data: summary_data,
      predictions: predictions,
      tokens_used: tokens_used
    )
  end

  def extract_tokens_used(response)
    return nil if response.blank?

    # 最後のチャンクにトークン情報が含まれる
    last_chunk = response.last
    last_chunk&.dig("usageMetadata", "totalTokenCount")
  end

  def build_summary_data(week_start, week_end)
    records = fetch_weekly_records(week_start, week_end)
    return {} if records.empty?

    {
      record_count: records.count,
      avg_mood: records.where.not(mood: nil).average(:mood)&.round(2),
      avg_sleep: records.where.not(sleep_minutes: nil).average(:sleep_minutes)&.round(0),
      total_exercise: records.where.not(exercise_minutes: nil).sum(:exercise_minutes)
    }
  end

  def build_predictions_data
    forecast = fetch_forecast_data
    return {} if forecast.empty?

    # 低気圧（1005hPa以下）の日を警戒日として抽出
    warning_dates = forecast.select { |day| day[:pressure].to_f < 1005 }
                            .map { |day| day[:date].to_s }

    {
      warning_dates: warning_dates,
      forecast_days: forecast.size
    }
  end
end
