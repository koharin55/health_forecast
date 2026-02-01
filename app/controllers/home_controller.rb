class HomeController < ApplicationController
  def index
    @recent_records = current_user.health_records.recent.limit(7)
    @latest_record = current_user.health_records.recent.first
    @total_records = current_user.health_records.count
  end
end
