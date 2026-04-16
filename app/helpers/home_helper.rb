module HomeHelper
  # 予測リスクレベルに応じた背景クラス
  def prediction_bg_class(risk_level)
    case risk_level
    when :critical then "from-red-50 to-rose-100"
    when :high then "from-amber-50 to-orange-100"
    when :moderate then "from-yellow-50 to-amber-100"
    else "from-emerald-50 to-green-100"
    end
  end

  # 予測リスクレベルに応じたテキストクラス
  def prediction_text_class(risk_level)
    case risk_level
    when :critical then "text-red-600"
    when :high then "text-amber-600"
    when :moderate then "text-yellow-600"
    else "text-emerald-600"
    end
  end

  # 予測リスクレベルに応じたアイコン（PNG画像）
  def prediction_risk_icon(risk_level)
    image_name = case risk_level
                 when :critical then "critical.png"
                 when :high then "high.png"
                 when :moderate then "moderate.png"
                 else "low.png"
                 end
    image_tag(image_name, class: "w-10 h-10 sm:w-12 sm:h-12 mx-auto", alt: risk_level.to_s)
  end

  # 予測日のラベル（日付付き）
  def prediction_date_label(index)
    date = Date.current + index + 1
    label = case index
            when 0 then "明日"
            when 1 then "明後日"
            else "#{index + 1}日後"
            end
    "#{label}：#{format_date_with_weekday(date)}"
  end

  # 日付を曜日付きでフォーマット（例：2/5(木)）
  def format_date_with_weekday(date)
    weekdays = %w[日 月 火 水 木 金 土]
    "#{date.month}/#{date.day}(#{weekdays[date.wday]})"
  end

  # 期間内レコードを集約間隔でバケット化して平均値を算出
  # field: シンボル（:weight など）、interval: :daily / :weekly / :monthly
  # 戻り値: [{ x: "2026-04-10", y: 60.5 }, ...]（日付昇順）
  def chart_series(records, field, interval:, &transform)
    filtered = records.reject { |r| r.public_send(field).nil? }
    bucketize(filtered, interval).map { |date, rows| chart_point(date, rows, field, &transform) }
  end

  # 血圧用：最高血圧・最低血圧の両方を平均化して返す
  def chart_blood_pressure_series(records, interval:)
    filtered = records.reject { |r| r.systolic_pressure.nil? || r.diastolic_pressure.nil? }
    bucketize(filtered, interval).map do |date, rows|
      {
        x: date.to_s,
        systolic: average_of(rows, :systolic_pressure).round(1),
        diastolic: average_of(rows, :diastolic_pressure).round(1)
      }
    end
  end

  private

  def chart_point(date, rows, field, &transform)
    avg = average_of(rows, field)
    y = transform ? transform.call(avg) : avg.round(2)
    { x: date.to_s, y: y }
  end

  def average_of(rows, field)
    rows.sum { |r| r.public_send(field).to_f } / rows.size
  end

  def bucketize(records, interval)
    records.group_by { |r| bucket_key(r.recorded_at.to_date, interval) }.sort_by(&:first)
  end

  def bucket_key(date, interval)
    case interval
    when :daily   then date
    when :weekly  then date.beginning_of_week
    when :monthly then date.beginning_of_month
    else raise ArgumentError, "unknown interval: #{interval}"
    end
  end
end
