class HealthRecordsController < ApplicationController
  before_action :set_health_record, only: %i[ show edit update destroy ]

  # GET /health_records or /health_records.json
  def index
    @health_records = current_user.health_records.recent
  end

  # GET /health_records/1 or /health_records/1.json
  def show
  end

  # GET /health_records/new
  def new
    @health_record = current_user.health_records.new(recorded_at: Date.current)
  end

  # GET /health_records/1/edit
  def edit
  end

  # POST /health_records or /health_records.json
  def create
    @health_record = current_user.health_records.new(health_record_params)
    fetch_weather_for_record(@health_record)

    respond_to do |format|
      if @health_record.save
        format.html { redirect_to @health_record, notice: "記録を保存しました。" }
        format.json { render :show, status: :created, location: @health_record }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @health_record.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /health_records/1 or /health_records/1.json
  def update
    @health_record.assign_attributes(health_record_params)
    fetch_weather_if_date_changed(@health_record)

    respond_to do |format|
      if @health_record.save
        format.html { redirect_to @health_record, notice: "記録を更新しました。", status: :see_other }
        format.json { render :show, status: :ok, location: @health_record }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @health_record.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /health_records/1 or /health_records/1.json
  def destroy
    @health_record.destroy!

    respond_to do |format|
      format.html { redirect_to health_records_path, notice: "記録を削除しました。", status: :see_other }
      format.json { head :no_content }
    end
  end

  def export
    service = HealthRecordExportService.new(current_user)
    csv_data = service.generate_csv
    filename = "health_records_#{Date.current.strftime('%Y%m%d')}.csv"
    send_data csv_data, filename: filename, type: 'text/csv; charset=utf-8'
  end

  def import_form
  end

  def import
    if params[:file].blank?
      redirect_to import_health_records_path, alert: "ファイルを選択してください"
      return
    end

    uploaded_file = params[:file]

    if uploaded_file.size > 5.megabytes
      redirect_to import_health_records_path, alert: "ファイルサイズが大きすぎます（上限: 5MB）"
      return
    end

    unless uploaded_file.content_type.in?(%w[text/csv application/csv text/plain])
      redirect_to import_health_records_path, alert: "CSVファイルを選択してください"
      return
    end

    strategy = params[:duplicate_strategy]
    strategy = 'skip' unless strategy.in?(%w[skip overwrite])

    file_content = uploaded_file.read
    service = HealthRecordImportService.new(
      current_user, file_content,
      duplicate_strategy: strategy
    )
    result = service.import

    messages = []
    messages << "#{result[:imported]}件インポートしました" if result[:imported] > 0
    messages << "#{result[:skipped]}件スキップしました" if result[:skipped] > 0
    messages << "#{result[:errors].size}件エラーがありました" if result[:errors].any?

    if result[:errors].any?
      flash[:alert] = result[:errors].first(5).join("\n")
    end

    redirect_to health_records_path, notice: messages.join("、")
  end

  private

  def set_health_record
    @health_record = current_user.health_records.find(params[:id])
  end

  def health_record_params
    params.require(:health_record).permit(:recorded_at, :weight, :sleep_hours, :exercise_minutes, :mood, :notes, :steps, :heart_rate, :systolic_pressure, :diastolic_pressure, :body_temperature)
  end

  def fetch_weather_for_record(record)
    return unless current_user.location_configured?
    record.fetch_and_set_weather!
  end

  def fetch_weather_if_date_changed(record)
    return unless current_user.location_configured?
    return unless record.recorded_at_changed?
    record.fetch_and_set_weather!
  end
end
