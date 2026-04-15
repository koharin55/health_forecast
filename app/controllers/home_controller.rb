class HomeController < ApplicationController
  def index
    @recent_records = current_user.health_records.recent.limit(7)
    @latest_record = @recent_records.first
    @total_records = current_user.health_records.count
    assign_chart_records
    @current_weather = fetch_current_weather
    @prediction_service = HealthPredictionService.new(current_user)
    @predictions = fetch_predictions
    @latest_report = current_user.weekly_reports.recent.first
  end

  private

  def assign_chart_records
    periods = HealthRecord::CHART_PERIODS
    @period = periods.key?(params[:period]) ? params[:period] : HealthRecord::DEFAULT_CHART_PERIOD
    config = periods[@period]
    @period_label = config[:label]
    @chart_interval = config[:interval]
    @chart_records = fetch_chart_records(config[:days])
  end

  # 最新レコードの日付を起点に過去N日分を取得する
  # （カレンダー上の今日を起点にするとデータが古い場合に空になるため）
  def fetch_chart_records(days)
    scope = current_user.health_records
    latest = scope.maximum(:recorded_at)
    return scope.none unless latest

    scope.where(recorded_at: (latest - (days - 1))..latest).recent
  end

  def fetch_current_weather
    return nil unless current_user.location_configured?

    service = WeatherService.new(
      latitude: current_user.latitude,
      longitude: current_user.longitude
    )
    service.fetch_current_weather
  rescue WeatherService::Error => e
    Rails.logger.error("HomeController#fetch_current_weather error: #{e.message}")
    nil
  end

  def fetch_predictions
    return [] unless current_user.location_configured?

    @prediction_service.predict_next_days(days: 4)
  rescue StandardError => e
    Rails.logger.error("HomeController#fetch_predictions error: #{e.message}")
    []
  end
end
