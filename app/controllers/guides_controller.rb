class GuidesController < ApplicationController
  def ios_shortcut
    @api_endpoint = api_v1_health_records_url
    @shortcut_icloud_url = ios_shortcut_url
  end

  private

  def ios_shortcut_url
    Rails.application.credentials.dig(:ios_shortcut_url)
  end
end
