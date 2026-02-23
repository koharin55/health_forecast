class WeeklyReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_weekly_report, only: [:show]

  # GET /weekly_reports/:id
  def show
  end

  # POST /weekly_reports
  def create
    service = AiReportService.new(current_user)

    result = service.check_sufficient_data
    unless result[:sufficient]
      redirect_to authenticated_root_path,
                  alert: "対象期間の記録が#{result[:count]}件しかありません。#{result[:required]}件以上必要です"
      return
    end

    @weekly_report = service.generate_weekly_report
    redirect_to @weekly_report, notice: "週次レポートを生成しました"
  rescue AiReportService::ConfigurationError => e
    Rails.logger.error("WeeklyReportsController: #{e.message}")
    redirect_to authenticated_root_path,
                alert: "AI機能が設定されていません。管理者にお問い合わせください。"
  rescue AiReportService::ApiError => e
    Rails.logger.error("WeeklyReportsController: #{e.message}")
    redirect_to authenticated_root_path,
                alert: "レポートの生成に失敗しました。しばらく経ってから再度お試しください。"
  rescue ActiveRecord::RecordNotUnique
    redirect_to_existing_report
  rescue ActiveRecord::RecordInvalid => e
    if e.record.errors.of_kind?(:week_start, :taken)
      redirect_to_existing_report
    else
      redirect_to authenticated_root_path,
                  alert: "レポートの生成に失敗しました: #{e.record.errors.full_messages.join(', ')}"
    end
  end

  # GET /weekly_reports
  def index
    @weekly_reports = current_user.weekly_reports.recent.limit(20)
  end

  private

  def set_weekly_report
    @weekly_report = current_user.weekly_reports.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to authenticated_root_path, alert: "レポートが見つかりません"
  end

  def redirect_to_existing_report
    week_start = Date.current - AiReportService::DEFAULT_PERIOD_DAYS
    week_end = Date.current - 1
    existing_report = WeeklyReport.find_for_period(current_user, week_start, week_end)
    if existing_report
      redirect_to existing_report, notice: "同じ期間のレポートは既に生成済みです"
    else
      redirect_to authenticated_root_path, notice: "同じ期間のレポートは既に生成済みです"
    end
  end
end
