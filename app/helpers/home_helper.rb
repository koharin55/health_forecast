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
end
