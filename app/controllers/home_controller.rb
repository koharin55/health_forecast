class HomeController < ApplicationController
  def index
    @recent_records = current_user.health_records.recent.limit(7)
    @latest_record = @recent_records.first
    @total_records = current_user.health_records.count
    @current_weather = fetch_current_weather
  end

  private

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
end
