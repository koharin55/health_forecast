# 天候・体調相関分析サービス
# ユーザーの過去データから気象感度スコアを算出
class HealthAnalysisService
  class Error < StandardError; end
  class InsufficientDataError < Error; end

  MINIMUM_RECORDS = 10

  # 気圧グループの定義（hPa）
  PRESSURE_GROUPS = {
    low: 0...1000,           # 低気圧
    slightly_low: 1000...1013, # やや低い
    normal: 1013...1020,     # 通常
    high: 1020..1100         # 高気圧
  }.freeze

  def initialize(user)
    @user = user
  end

  # 天候と体調の相関を分析
  def analyze_weather_sensitivity
    raise InsufficientDataError, "分析には#{MINIMUM_RECORDS}件以上のデータが必要です" unless sufficient_data?

    mood_by_pressure = calculate_mood_by_pressure_group
    sensitivity_score = calculate_sensitivity_score(mood_by_pressure)
    pressure_correlation = calculate_pressure_correlation

    {
      sensitivity_score: sensitivity_score,
      pressure_correlation: pressure_correlation,
      mood_by_pressure: mood_by_pressure,
      data_count: analysis_records.count
    }
  end

  # 気圧グループ別の平均体調スコアを計算
  def calculate_mood_by_pressure_group
    results = {}

    PRESSURE_GROUPS.each do |group_name, range|
      records = analysis_records.select { |r| range.cover?(r.weather_pressure) }
      next if records.empty?

      moods = records.map(&:mood)
      results[group_name] = {
        average: (moods.sum.to_f / moods.size).round(2),
        count: moods.size
      }
    end

    results
  end

  # 分析に十分なデータがあるか
  def sufficient_data?
    analysis_records.count >= MINIMUM_RECORDS
  end

  # 分析対象レコード数
  def data_count
    analysis_records.count
  end

  # データ収集の進捗率（0-100）
  def data_progress
    count = analysis_records.count
    [(count.to_f / MINIMUM_RECORDS * 100).round, 100].min
  end

  private

  # 分析対象のレコード（天候データと体調スコアの両方が存在するもの）
  def analysis_records
    @analysis_records ||= @user.health_records.with_weather_and_mood.to_a
  end

  # 気象感度スコアを計算（0-100）
  # 低気圧時と高気圧時の体調差が大きいほど感度が高い
  def calculate_sensitivity_score(mood_by_pressure)
    return 50 if mood_by_pressure.empty?

    # 低気圧グループと高気圧グループの平均を取得
    low_pressure_moods = []
    high_pressure_moods = []

    mood_by_pressure.each do |group, data|
      case group
      when :low, :slightly_low
        low_pressure_moods << data[:average]
      when :normal, :high
        high_pressure_moods << data[:average]
      end
    end

    return 50 if low_pressure_moods.empty? || high_pressure_moods.empty?

    low_avg = low_pressure_moods.sum / low_pressure_moods.size
    high_avg = high_pressure_moods.sum / high_pressure_moods.size

    # 差分（高気圧時 - 低気圧時）を感度スコアに変換
    # 差が大きい（低気圧で体調悪い）ほど感度が高い
    diff = high_avg - low_avg

    # 差分を0-100のスコアに変換（差分1.0で約25ポイント増加）
    base_score = 50
    sensitivity = base_score + (diff * 25)
    [[sensitivity, 0].max, 100].min.round
  end

  # 気圧と体調の相関係数を計算
  def calculate_pressure_correlation
    return nil if analysis_records.count < 3

    pressures = analysis_records.map(&:weather_pressure)
    moods = analysis_records.map(&:mood)

    pearson_correlation(pressures, moods)
  end

  # ピアソン相関係数の計算
  def pearson_correlation(x_values, y_values)
    n = x_values.size
    return nil if n == 0

    sum_x = x_values.sum
    sum_y = y_values.sum
    sum_xy = x_values.zip(y_values).map { |x, y| x * y }.sum
    sum_x2 = x_values.map { |x| x * x }.sum
    sum_y2 = y_values.map { |y| y * y }.sum

    numerator = n * sum_xy - sum_x * sum_y
    denominator = Math.sqrt((n * sum_x2 - sum_x**2) * (n * sum_y2 - sum_y**2))

    return nil if denominator.zero?

    (numerator / denominator).round(3)
  end
end
