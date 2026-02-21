class WeeklyReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_weekly_report, only: [:show]

  # GET /weekly_reports/:id
  def show
  end

  # POST /weekly_reports
  def create
    service = AiReportService.new(current_user)

    unless service.sufficient_data?
      redirect_to authenticated_root_path,
                  alert: "レポート生成には#{AiReportService::MINIMUM_RECORDS}件以上の健康記録が必要です"
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
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # 同じ期間のレポートが既に存在する場合
    week_start = Date.current - AiReportService::DEFAULT_PERIOD_DAYS
    existing_report = current_user.weekly_reports.find_for_week(
      current_user,
      week_start
    )
    redirect_to existing_report, notice: "同じ期間のレポートは既に生成済みです"
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
end
