# frozen_string_literal: true

require "net/http"
require "json"

class WeatherService
  OWM_BASE_URL     = "https://api.openweathermap.org/data/2.5"
  ARCHIVE_BASE_URL = "https://archive-api.open-meteo.com/v1/archive"
  TIMEZONE = "Asia/Tokyo"
  TIMEOUT  = 10

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

  # OWMコード → WMOコード変換テーブル
  OWM_TO_WMO = {
    200..232 => 95,
    300..321 => 51,
    500 => 61, 501 => 63, 502..504 => 65,
    511 => 66, 520 => 80, 521 => 81, 522..531 => 82,
    600 => 71, 601 => 73, 602 => 75,
    611..616 => 77, 620 => 71, 621 => 73, 622 => 75,
    701 => 45, 711 => 45, 721 => 45, 731..781 => 3, 741 => 45,
    800 => 0,
    801 => 1, 802 => 2, 803..804 => 3
  }.freeze

  CURRENT_WEATHER_TTL    = 1.hour
  DAILY_FALLBACK_TTL     = 2.hours
  FORECAST_TTL           = 6.hours
  HISTORICAL_TTL         = 24.hours
  ERROR_BACKOFF_TTL      = 5.minutes
  RATE_LIMIT_BACKOFF_TTL = 1.hour
  MAX_FORECAST_DAYS      = 5
  MAX_HISTORICAL_DAYS    = 92

  class Error < StandardError; end
  class ApiError < Error; end
  class TimeoutError < Error; end
  class RateLimitError < ApiError; end
  class ConfigurationError < Error; end

  def initialize(latitude:, longitude:)
    @latitude = latitude
    @longitude = longitude
  end

  # 現在の天気を取得（/weather 失敗時は /forecast でフォールバック）
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
      fetch_forecast_weather(date)
    else
      fetch_historical_weather(date)
    end
  end

  # 複数日の天気予報を取得（最大5日先まで）
  def fetch_forecast_days(days: 3)
    return [] if days < 1 || days > MAX_FORECAST_DAYS
    return [] if Rails.cache.exist?(cache_key("error/forecast_days"))

    Rails.cache.fetch(cache_key("forecast_days/#{days}/#{Date.current}"), expires_in: FORECAST_TTL) do
      response = make_owm_request("/forecast", { lat: @latitude, lon: @longitude })
      parse_owm_multi_day_forecasts(response, days)
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

    response = make_archive_request(params)
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
      response = make_owm_request("/weather", { lat: @latitude, lon: @longitude })
      parse_owm_current(response)
    end
  rescue RateLimitError => e
    Rails.logger.warn("WeatherService rate limited: #{e.message}")
    Rails.cache.write(cache_key("error/current"), true, expires_in: RATE_LIMIT_BACKOFF_TTL)
    nil
  rescue TimeoutError => e
    Rails.logger.error("WeatherService timeout: #{e.message}")
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
      response = make_owm_request("/forecast", { lat: @latitude, lon: @longitude })
      # 当日エントリを優先。夜間など当日エントリがない場合はリスト先頭（最近傍）エントリを代替使用
      parse_owm_forecast_for_date(response, Date.current) || parse_owm_first_entry(response)
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

  def fetch_forecast_weather(date)
    return nil if Rails.cache.exist?(cache_key("error/forecast"))

    Rails.cache.fetch(cache_key("forecast/#{date}"), expires_in: FORECAST_TTL) do
      response = make_owm_request("/forecast", { lat: @latitude, lon: @longitude })
      parse_owm_forecast_for_date(response, date)
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
      response = make_archive_request(params)
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

  def cache_key(suffix)
    "weather_service/#{suffix}/#{@latitude}/#{@longitude}"
  end

  def owm_api_key
    Rails.application.credentials.openweathermap_api_key || ENV["OPENWEATHERMAP_API_KEY"]
  end

  def make_owm_request(endpoint, params = {})
    raise ConfigurationError, "OpenWeatherMap APIキーが設定されていません" unless owm_api_key

    uri = URI("#{OWM_BASE_URL}#{endpoint}")
    uri.query = URI.encode_www_form(params.merge(appid: owm_api_key, units: "metric"))
    perform_get_request(uri)
  end

  def make_archive_request(params)
    uri = URI(ARCHIVE_BASE_URL)
    uri.query = URI.encode_www_form(params)
    perform_get_request(uri)
  end

  def perform_get_request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/json"

    response = http.request(request)

    raise RateLimitError, "API rate limit exceeded (429)" if response.code == "429"
    raise ApiError, "API returned status #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise TimeoutError, e.message
  rescue JSON::ParserError => e
    raise ApiError, "Invalid JSON response: #{e.message}"
  end

  # OWM /weather レスポンス → WeatherHash
  def parse_owm_current(response)
    main = response["main"]
    return nil unless main

    owm_code = response.dig("weather", 0, "id")
    wmo_code = owm_code_to_wmo(owm_code)
    {
      temperature: main["temp"]&.round(1),
      humidity: main["humidity"],
      pressure: main["pressure"]&.round(1),
      weather_code: wmo_code,
      weather_description: self.class.weather_description(wmo_code),
      fetched_at: Time.current
    }
  end

  # OWM /forecast レスポンス(3時間刻み) → 指定日の日次データに集約
  def parse_owm_forecast_for_date(response, target_date)
    entries = response["list"]&.select { |e|
      Time.at(e["dt"]).in_time_zone(TIMEZONE).to_date == target_date
    }
    return nil if entries.blank?

    aggregate_owm_entries(entries, target_date)
  end

  # OWM /forecast の先頭エントリを単体で変換（夜間フォールバック用）
  def parse_owm_first_entry(response)
    entry = response["list"]&.first
    return nil unless entry

    date = Time.at(entry["dt"]).in_time_zone(TIMEZONE).to_date
    aggregate_owm_entries([entry], date)
  end

  # OWM /forecast → 複数日の配列
  def parse_owm_multi_day_forecasts(response, days)
    (1..days).filter_map do |i|
      date = Date.current + i
      result = parse_owm_forecast_for_date(response, date)
      result&.merge(date: date)
    end
  end

  # 日次集約ロジック（数値は平均、weather_codeは正午に最も近いエントリを採用）
  def aggregate_owm_entries(entries, date)
    temps      = entries.map { |e| e.dig("main", "temp") }.compact
    humidities = entries.map { |e| e.dig("main", "humidity") }.compact
    pressures  = entries.map { |e| e.dig("main", "pressure") }.compact
    noon       = Time.zone.parse("#{date} 12:00:00")
    noon_entry = entries.min_by { |e| (Time.at(e["dt"]).in_time_zone(TIMEZONE) - noon).abs }
    owm_code   = noon_entry&.dig("weather", 0, "id")
    wmo_code   = owm_code_to_wmo(owm_code)
    {
      temperature: temps.any? ? (temps.sum / temps.size).round(1) : nil,
      humidity:    humidities.any? ? (humidities.sum / humidities.size).round : nil,
      pressure:    pressures.any? ? (pressures.sum / pressures.size).round(1) : nil,
      weather_code: wmo_code,
      weather_description: self.class.weather_description(wmo_code),
      fetched_at: Time.current
    }
  end

  # OWMコード → WMOコード変換
  # Integer キーを優先して検索し、次にRange キーを検索する。
  # これにより、731..781 の Range に含まれる 741（霧）等の個別マッピングが正しく機能する。
  def owm_code_to_wmo(owm_code)
    return nil unless owm_code

    OWM_TO_WMO[owm_code] ||
      OWM_TO_WMO.find { |k, _| k.is_a?(Range) && k.include?(owm_code) }&.last ||
      3
  end

  # Open-Meteo Archive APIレスポンス → 日次データ（historical用）
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
