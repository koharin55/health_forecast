module HealthRecordsHelper
  # スコアから絵文字を返す
  def mood_emoji(score)
    case score
    when 1
      "😞"
    when 2
      "😕"
    when 3
      "😐"
    when 4
      "😊"
    when 5
      "😄"
    else
      "➖"
    end
  end

  # スコアから日本語テキストを返す
  def mood_text(score)
    case score
    when 1
      "とても悪い"
    when 2
      "悪い"
    when 3
      "普通"
    when 4
      "良い"
    when 5
      "とても良い"
    else
      "未記録"
    end
  end

  # スコアからバッジCSSクラスを返す
  def mood_badge_class(score)
    case score
    when 1
      "badge-mood-1"
    when 2
      "badge-mood-2"
    when 3
      "badge-mood-3"
    when 4
      "badge-mood-4"
    when 5
      "badge-mood-5"
    else
      "badge-mood-3"
    end
  end
end
