# 体調予測サービス
# 天気予報とユーザーの気象感度からリスクスコアを算出
class HealthPredictionService
  class Error < StandardError; end

  RISK_LEVELS = {
    low: 0..25,
    moderate: 26..50,
    high: 51..75,
    critical: 76..100
  }.freeze

  RISK_LEVEL_LABELS = {
    low: "良好",
    moderate: "注意",
    high: "警戒",
    critical: "危険"
  }.freeze

  RISK_LEVEL_ICONS = {
    low: "check-circle",
    moderate: "info-circle",
    high: "exclamation-triangle",
    critical: "exclamation-circle"
  }.freeze

  DEFAULT_SENSITIVITY = 50

  def initialize(user)
    @user = user
    @analysis_service = HealthAnalysisService.new(user)
  end

  # 指定日の体調予測
  def predict_for_date(date)
    forecast = fetch_forecast_for_date(date)
    return nil unless forecast

    current_weather = fetch_current_weather
    sensitivity_score = user_sensitivity_score

    risk_score = calculate_risk_score(forecast, current_weather, sensitivity_score)
    risk_level = determine_risk_level(risk_score)
    factors = identify_risk_factors(forecast, current_weather)
    advice = generate_advice(risk_level, factors)

    {
      date: date,
      risk_score: risk_score,
      risk_level: risk_level,
      risk_level_label: RISK_LEVEL_LABELS[risk_level],
      risk_level_icon: RISK_LEVEL_ICONS[risk_level],
      factors: factors,
      advice: advice,
      forecast: forecast
    }
  end

  # 複数日の予測を取得
  def predict_next_days(days: 3)
    return [] unless @user.location_configured?

    forecasts = fetch_forecasts(days)
    return [] if forecasts.empty?

    current_weather = fetch_current_weather
    sensitivity_score = user_sensitivity_score

    forecasts.map do |forecast|
      risk_score = calculate_risk_score(forecast, current_weather, sensitivity_score)
      risk_level = determine_risk_level(risk_score)
      factors = identify_risk_factors(forecast, current_weather)

      {
        date: forecast[:date],
        risk_score: risk_score,
        risk_level: risk_level,
        risk_level_label: RISK_LEVEL_LABELS[risk_level],
        risk_level_icon: RISK_LEVEL_ICONS[risk_level],
        factors: factors,
        advice: generate_advice(risk_level, factors),
        forecast: forecast
      }
    end
  end

  # 分析データが十分かどうか
  def sufficient_analysis_data?
    @analysis_service.sufficient_data?
  end

  # データ収集の進捗
  def data_progress
    @analysis_service.data_progress
  end

  # 必要なデータ数
  def required_data_count
    HealthAnalysisService::MINIMUM_RECORDS
  end

  # 現在のデータ数
  def current_data_count
    @analysis_service.data_count
  end

  private

  def weather_service
    @weather_service ||= WeatherService.new(
      latitude: @user.latitude,
      longitude: @user.longitude
    )
  end

  def user_sensitivity_score
    return DEFAULT_SENSITIVITY unless @analysis_service.sufficient_data?

    analysis = @analysis_service.analyze_weather_sensitivity
    analysis[:sensitivity_score]
  rescue HealthAnalysisService::Error
    DEFAULT_SENSITIVITY
  end

  def fetch_forecast_for_date(date)
    return nil unless @user.location_configured?

    weather_service.fetch_weather_for_date(date)
  rescue WeatherService::Error
    nil
  end

  def fetch_forecasts(days)
    return [] unless @user.location_configured?

    weather_service.fetch_forecast_days(days: days)
  rescue WeatherService::Error
    []
  end

  def fetch_current_weather
    return nil unless @user.location_configured?

    weather_service.fetch_current_weather
  rescue WeatherService::Error
    nil
  end

  # リスクスコア計算（0-100）
  def calculate_risk_score(forecast, current_weather, sensitivity_score)
    return 20 unless forecast[:pressure]

    # 基本リスク
    base_risk = 20

    # 気圧要因（低気圧ほどリスク高）
    pressure = forecast[:pressure]
    pressure_factor = case pressure
                      when 0...1000 then 40      # 低気圧
                      when 1000...1010 then 20   # やや低い
                      when 1010...1015 then 10   # 少し低い
                      when 1015...1020 then 0    # 通常
                      else -10                    # 高気圧
                      end

    # 気圧変化要因（現在との差が大きいほどリスク高）
    change_factor = 0
    if current_weather && current_weather[:pressure]
      pressure_change = (current_weather[:pressure] - pressure).abs
      change_factor = [pressure_change * 2, 30].min
    end

    # 個人感度要因（感度50を基準に±20程度の影響）
    sensitivity_factor = ((sensitivity_score - 50) / 50.0) * 20

    # 天気要因（悪天候でリスク上昇）
    weather_factor = case forecast[:weather_code]
                     when 61, 63, 65, 80, 81, 82 then 10  # 雨
                     when 95, 96, 99 then 15              # 雷雨
                     when 71, 73, 75, 85, 86 then 5       # 雪
                     else 0
                     end

    risk_score = base_risk + pressure_factor + change_factor + sensitivity_factor + weather_factor
    [[risk_score.round, 0].max, 100].min
  end

  # リスクレベルの判定
  def determine_risk_level(risk_score)
    RISK_LEVELS.find { |_level, range| range.cover?(risk_score) }&.first || :moderate
  end

  # リスク要因の特定
  def identify_risk_factors(forecast, current_weather)
    factors = []

    if forecast[:pressure]
      if forecast[:pressure] < 1005
        factors << { type: :low_pressure, message: "低気圧（#{forecast[:pressure].round}hPa）" }
      elsif forecast[:pressure] < 1010
        factors << { type: :slightly_low_pressure, message: "やや低い気圧（#{forecast[:pressure].round}hPa）" }
      end
    end

    if current_weather && current_weather[:pressure] && forecast[:pressure]
      change = (current_weather[:pressure] - forecast[:pressure]).round
      if change.abs >= 10
        direction = change > 0 ? "低下" : "上昇"
        factors << { type: :pressure_change, message: "気圧が#{change.abs}hPa#{direction}予報" }
      end
    end

    case forecast[:weather_code]
    when 61, 63, 65, 80, 81, 82
      factors << { type: :rain, message: "雨の予報" }
    when 95, 96, 99
      factors << { type: :thunderstorm, message: "雷雨の予報" }
    end

    factors
  end

  # アドバイスの生成
  def generate_advice(risk_level, factors)
    case risk_level
    when :critical
      "体調変化に十分注意してください。頭痛薬などを準備し、無理のない予定を心がけましょう。"
    when :high
      if factors.any? { |f| f[:type] == :low_pressure || f[:type] == :pressure_change }
        "気圧変化による体調不良に注意。頭痛薬の準備をおすすめします。"
      else
        "体調管理に気を付けましょう。十分な休息を取ってください。"
      end
    when :moderate
      "通常通りお過ごしいただけますが、体調の変化には注意してください。"
    else
      "良好な天気が予想されます。快適にお過ごしいただけそうです。"
    end
  end
end
