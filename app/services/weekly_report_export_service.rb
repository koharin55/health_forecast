class WeeklyReportExportService
  class Error < StandardError; end

  EXPORT_FIELDS = %w[
    week_start week_end content summary_data predictions tokens_used created_at
  ].freeze

  def initialize(user)
    @user = user
  end

  def generate_json
    reports = @user.weekly_reports.recent.map do |report|
      EXPORT_FIELDS.index_with { |field| report.public_send(field) }
    end

    JSON.pretty_generate(
      exported_at: Time.current.iso8601,
      version: 1,
      reports: reports
    )
  end
end
