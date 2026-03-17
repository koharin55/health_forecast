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

  CURRENT_WEATHER_TTL    = 1.hour
  DAILY_FALLBACK_TTL     = 2.hours
  FORECAST_TTL           = 6.hours
  HISTORICAL_TTL         = 24.hours
  ERROR_BACKOFF_TTL      = 5.minutes
  RATE_LIMIT_BACKOFF_TTL = 1.hour
  MAX_FORECAST_DAYS      = 7
  MAX_HISTORICAL_DAYS    = 92

  class Error < StandardError; end
  class ApiError < Error; end
  class TimeoutError < Error; end
  class RateLimitError < ApiError; end

  def initialize(latitude:, longitude:)
    @latitude = latitude
    @longitude = longitude
  end

  # 現在の天気を取得（current エンドポイント失敗時は daily でフォールバック）
  def fetch_current_weather
    result = try_fetch_current_weather
    return result if result

    fetch_daily_fallback_for_today
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

  # 複数日の天気予報を取得（最大7日先まで）
  def fetch_forecast_days(days: 3)
    return [] if days < 1 || days > MAX_FORECAST_DAYS
    return [] if Rails.cache.exist?(cache_key("error/forecast_days"))

    Rails.cache.fetch(cache_key("forecast_days/#{days}/#{Date.current}"), expires_in: FORECAST_TTL) do
      start_date = Date.current + 1
      end_date = Date.current + days

      params = {
        latitude: @latitude,
        longitude: @longitude,
        daily: "temperature_2m_mean,relative_humidity_2m_mean,surface_pressure_mean,weather_code",
        start_date: start_date.to_s,
        end_date: end_date.to_s,
        timezone: TIMEZONE
      }

      response = make_request(params)
      parse_multi_day_weather(response)
    end
  rescue RateLimitError => e
    Rails.logger.warn("WeatherService forecast_days rate limited: #{e.message}")
    Rails.cache.write(cache_key("error/forecast_days"), true, expires_in: RATE_LIMIT_BACKOFF_TTL)
    []
  rescue StandardError => e
    Rails.logger.error("WeatherService forecast_days error: #{e.message}")
    Rails.cache.write(cache_key("error/forecast_days"), true, expires_in: ERROR_BACKOFF_TTL)
    []
  end

  # 複数日の過去天気を一括プリフェッチしてキャッシュに保存（バックフィル用）
  def prefetch_historical_weather(dates)
    return if dates.empty?
    return if Rails.cache.exist?(cache_key("error/prefetch"))

    uncached_dates = dates.select { |d| d < Date.current }
                          .reject { |d| Rails.cache.exist?(cache_key("historical/#{d}")) }
    return if uncached_dates.empty?

    start_date = uncached_dates.min
    end_date   = uncached_dates.max

    params = {
      latitude: @latitude,
      longitude: @longitude,
      daily: "temperature_2m_mean,relative_humidity_2m_mean,surface_pressure_mean,weather_code",
      start_date: start_date.to_s,
      end_date: end_date.to_s,
      timezone: TIMEZONE
    }

    response = make_request(params)
    weather_map = parse_multi_day_weather_map(response)

    weather_map.each do |date, weather|
      Rails.cache.write(cache_key("historical/#{date}"), weather, expires_in: HISTORICAL_TTL)
    end
  rescue RateLimitError => e
    Rails.logger.warn("WeatherService prefetch rate limited: #{e.message}")
    Rails.cache.write(cache_key("error/prefetch"), true, expires_in: RATE_LIMIT_BACKOFF_TTL)
  rescue StandardError => e
    Rails.logger.error("WeatherService prefetch error: #{e.message}")
    Rails.cache.write(cache_key("error/prefetch"), true, expires_in: ERROR_BACKOFF_TTL)
  end

  # 天気コードから説明を取得
  def self.weather_description(code)
    WEATHER_CODES[code] || "不明"
  end

  # 天気の日本語説明からコードを逆引き
  def self.code_from_description(description)
    WEATHER_CODES.key(description)
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

  def try_fetch_current_weather
    return nil if Rails.cache.exist?(cache_key("error/current"))

    Rails.cache.fetch(cache_key("current"), expires_in: CURRENT_WEATHER_TTL, skip_nil: true) do
      params = {
        latitude: @latitude,
        longitude: @longitude,
        current: "temperature_2m,relative_humidity_2m,surface_pressure,weather_code",
        timezone: TIMEZONE
      }

      response = make_request(params)
      parse_current_weather(response)
    end
  rescue RateLimitError => e
    Rails.logger.warn("WeatherService rate limited: #{e.message}")
    Rails.cache.write(cache_key("error/current"), true, expires_in: RATE_LIMIT_BACKOFF_TTL)
    nil
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("WeatherService timeout: #{e.message}")
    Rails.cache.write(cache_key("error/current"), true, expires_in: ERROR_BACKOFF_TTL)
    nil
  rescue JSON::ParserError => e
    Rails.logger.error("WeatherService JSON parse error: #{e.message}")
    Rails.cache.write(cache_key("error/current"), true, expires_in: ERROR_BACKOFF_TTL)
    nil
  rescue StandardError => e
    Rails.logger.error("WeatherService error: #{e.message}")
    Rails.cache.write(cache_key("error/current"), true, expires_in: ERROR_BACKOFF_TTL)
    nil
  end

  def fetch_daily_fallback_for_today
    return nil if Rails.cache.exist?(cache_key("error/current_fallback"))

    Rails.logger.info("WeatherService: current endpoint unavailable, using daily fallback")
    Rails.cache.fetch(cache_key("current_fallback/#{Date.current}"), expires_in: DAILY_FALLBACK_TTL, skip_nil: true) do
      params = {
        latitude: @latitude,
        longitude: @longitude,
        daily: "temperature_2m_mean,relative_humidity_2m_mean,surface_pressure_mean,weather_code",
        start_date: Date.current.to_s,
        end_date: Date.current.to_s,
        timezone: TIMEZONE
      }

      response = make_request(params)
      parse_daily_weather(response)
    end
  rescue RateLimitError => e
    Rails.logger.warn("WeatherService daily fallback rate limited: #{e.message}")
    Rails.cache.write(cache_key("error/current_fallback"), true, expires_in: RATE_LIMIT_BACKOFF_TTL)
    nil
  rescue StandardError => e
    Rails.logger.error("WeatherService daily fallback error: #{e.message}")
    Rails.cache.write(cache_key("error/current_fallback"), true, expires_in: ERROR_BACKOFF_TTL)
    nil
  end

  def cache_key(suffix)
    "weather_service/#{suffix}/#{@latitude}/#{@longitude}"
  end

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

    if response.code == "429"
      raise RateLimitError, "API rate limit exceeded (429)"
    end

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
    return nil if Rails.cache.exist?(cache_key("error/forecast"))

    Rails.cache.fetch(cache_key("forecast/#{date}"), expires_in: FORECAST_TTL) do
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
    end
  rescue RateLimitError => e
    Rails.logger.warn("WeatherService forecast rate limited: #{e.message}")
    Rails.cache.write(cache_key("error/forecast"), true, expires_in: RATE_LIMIT_BACKOFF_TTL)
    nil
  rescue StandardError => e
    Rails.logger.error("WeatherService forecast error: #{e.message}")
    Rails.cache.write(cache_key("error/forecast"), true, expires_in: ERROR_BACKOFF_TTL)
    nil
  end

  def fetch_historical_weather(date)
    days_ago = (Date.current - date).to_i
    if days_ago > MAX_HISTORICAL_DAYS
      Rails.logger.warn("WeatherService: Date #{date} is more than #{MAX_HISTORICAL_DAYS} days ago, skipping")
      return nil
    end

    return nil if Rails.cache.exist?(cache_key("error/historical"))

    Rails.cache.fetch(cache_key("historical/#{date}"), expires_in: HISTORICAL_TTL) do
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
    end
  rescue RateLimitError => e
    Rails.logger.warn("WeatherService historical rate limited: #{e.message}")
    Rails.cache.write(cache_key("error/historical"), true, expires_in: RATE_LIMIT_BACKOFF_TTL)
    nil
  rescue StandardError => e
    Rails.logger.error("WeatherService historical error: #{e.message}")
    Rails.cache.write(cache_key("error/historical"), true, expires_in: ERROR_BACKOFF_TTL)
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

  def parse_multi_day_weather(response)
    daily = response["daily"]
    return [] unless daily && daily["time"]&.any?

    daily["time"].each_with_index.map do |date_str, i|
      {
        date: Date.parse(date_str),
        temperature: daily["temperature_2m_mean"]&.[](i),
        humidity: daily["relative_humidity_2m_mean"]&.[](i)&.to_i,
        pressure: daily["surface_pressure_mean"]&.[](i),
        weather_code: daily["weather_code"]&.[](i),
        weather_description: self.class.weather_description(daily["weather_code"]&.[](i)),
        fetched_at: Time.current
      }
    end
  end

  def parse_multi_day_weather_map(response)
    parse_multi_day_weather(response).index_by { |w| w[:date] }
  end
end
