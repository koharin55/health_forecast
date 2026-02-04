# frozen_string_literal: true

require "net/http"
require "json"

class WeatherService
  BASE_URL = "https://api.open-meteo.com/v1/forecast"
  TIMEZONE = "Asia/Tokyo"
  TIMEOUT = 10

  # WMO天気コードと日本語説明のマッピング
  WEATHER_CODES = {
    0 => "快晴",
    1 => "晴れ",
    2 => "一部曇り",
    3 => "曇り",
    45 => "霧",
    48 => "霧氷",
    51 => "弱い霧雨",
    53 => "霧雨",
    55 => "強い霧雨",
    56 => "弱い着氷性霧雨",
    57 => "着氷性霧雨",
    61 => "弱い雨",
    63 => "雨",
    65 => "強い雨",
    66 => "弱い着氷性の雨",
    67 => "着氷性の雨",
    71 => "弱い雪",
    73 => "雪",
    75 => "強い雪",
    77 => "霧雪",
    80 => "弱いにわか雨",
    81 => "にわか雨",
    82 => "激しいにわか雨",
    85 => "弱いにわか雪",
    86 => "にわか雪",
    95 => "雷雨",
    96 => "雷雨（弱い雹）",
    99 => "雷雨（強い雹）"
  }.freeze

  class Error < StandardError; end
  class ApiError < Error; end
  class TimeoutError < Error; end

  def initialize(latitude:, longitude:)
    @latitude = latitude
    @longitude = longitude
  end

  # 現在の天気を取得
  def fetch_current_weather
    params = {
      latitude: @latitude,
      longitude: @longitude,
      current: "temperature_2m,relative_humidity_2m,surface_pressure,weather_code",
      timezone: TIMEZONE
    }

    response = make_request(params)
    parse_current_weather(response)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("WeatherService timeout: #{e.message}")
    raise TimeoutError, "天気情報の取得がタイムアウトしました"
  rescue JSON::ParserError => e
    Rails.logger.error("WeatherService JSON parse error: #{e.message}")
    raise ApiError, "天気情報の解析に失敗しました"
  rescue StandardError => e
    Rails.logger.error("WeatherService error: #{e.message}")
    raise ApiError, "天気情報の取得に失敗しました: #{e.message}"
  end

  # 指定日の天気を取得（過去データ対応）
  def fetch_weather_for_date(date)
    if date == Date.current
      fetch_current_weather
    elsif date > Date.current
      # 未来の日付は予報データを取得
      fetch_forecast_weather(date)
    else
      # 過去の日付は過去データを取得
      fetch_historical_weather(date)
    end
  end

  # 天気コードから説明を取得
  def self.weather_description(code)
    WEATHER_CODES[code] || "不明"
  end

  # 天気コードからアイコン絵文字を取得
  def self.weather_icon(code)
    case code
    when 0 then "☀️"
    when 1, 2 then "🌤️"
    when 3 then "☁️"
    when 45, 48 then "🌫️"
    when 51, 53, 55, 56, 57 then "🌧️"
    when 61, 63, 65, 66, 67 then "🌧️"
    when 71, 73, 75, 77 then "❄️"
    when 80, 81, 82 then "🌦️"
    when 85, 86 then "🌨️"
    when 95, 96, 99 then "⛈️"
    else "🌡️"
    end
  end

  private

  def make_request(params)
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/json"

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise ApiError, "API returned status #{response.code}"
    end

    JSON.parse(response.body)
  end

  def parse_current_weather(response)
    current = response["current"]
    return nil unless current

    {
      temperature: current["temperature_2m"],
      humidity: current["relative_humidity_2m"],
      pressure: current["surface_pressure"],
      weather_code: current["weather_code"],
      weather_description: self.class.weather_description(current["weather_code"]),
      fetched_at: Time.current
    }
  end

  def fetch_forecast_weather(date)
    params = {
      latitude: @latitude,
      longitude: @longitude,
      daily: "temperature_2m_mean,relative_humidity_2m_mean,surface_pressure_mean,weather_code",
      start_date: date.to_s,
      end_date: date.to_s,
      timezone: TIMEZONE
    }

    response = make_request(params)
    parse_daily_weather(response)
  rescue StandardError => e
    Rails.logger.error("WeatherService forecast error: #{e.message}")
    nil
  end

  def fetch_historical_weather(date)
    # 92日前までのデータを取得可能
    days_ago = (Date.current - date).to_i
    if days_ago > 92
      Rails.logger.warn("WeatherService: Date #{date} is more than 92 days ago, skipping")
      return nil
    end

    params = {
      latitude: @latitude,
      longitude: @longitude,
      daily: "temperature_2m_mean,relative_humidity_2m_mean,surface_pressure_mean,weather_code",
      start_date: date.to_s,
      end_date: date.to_s,
      timezone: TIMEZONE
    }

    response = make_request(params)
    parse_daily_weather(response)
  rescue StandardError => e
    Rails.logger.error("WeatherService historical error: #{e.message}")
    nil
  end

  def parse_daily_weather(response)
    daily = response["daily"]
    return nil unless daily && daily["time"]&.any?

    {
      temperature: daily["temperature_2m_mean"]&.first,
      humidity: daily["relative_humidity_2m_mean"]&.first&.to_i,
      pressure: daily["surface_pressure_mean"]&.first,
      weather_code: daily["weather_code"]&.first,
      weather_description: self.class.weather_description(daily["weather_code"]&.first),
      fetched_at: Time.current
    }
  end
end
