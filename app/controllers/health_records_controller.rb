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
    @health_record = current_user.health_records.new(recorded_at: Date.today)
  end

  # GET /health_records/1/edit
  def edit
  end

  # POST /health_records or /health_records.json
  def create
    @health_record = current_user.health_records.new(health_record_params)

    respond_to do |format|
      if @health_record.save
        format.html { redirect_to @health_record, notice: "Health record was successfully created." }
        format.json { render :show, status: :created, location: @health_record }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @health_record.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /health_records/1 or /health_records/1.json
  def update
    respond_to do |format|
      if @health_record.update(health_record_params)
        format.html { redirect_to @health_record, notice: "Health record was successfully updated.", status: :see_other }
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
      format.html { redirect_to health_records_path, notice: "Health record was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_health_record
      @health_record = current_user.health_records.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def health_record_params
      params.require(:health_record).permit(:recorded_at, :weight, :sleep_hours, :exercise_minutes, :mood, :notes, :steps, :heart_rate)
    end
end
