# frozen_string_literal: true

class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @prefecture_options = User.prefecture_options
  end

  def update
    @user = current_user

    case params[:location_type]
    when "prefecture"
      update_from_prefecture
    when "zipcode"
      update_from_zipcode
    else
      redirect_to settings_path, alert: "地域の指定方法を選択してください"
      return
    end
  end

  def search_zipcode
    zipcode = params[:zipcode]
    result = ZipcodeService.search(zipcode)
    render json: {
      success: true,
      address: result[:full_address],
      latitude: result[:latitude],
      longitude: result[:longitude]
    }
  rescue ZipcodeService::Error => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def backfill_weather
    unless current_user.location_configured?
      redirect_to settings_path, alert: "先に地域を設定してください"
      return
    end

    # 92日以内で天候データがない記録を取得
    cutoff_date = 92.days.ago.to_date
    records = current_user.health_records
      .where(weather_code: nil)
      .where("recorded_at >= ?", cutoff_date)
      .order(recorded_at: :desc)

    if records.empty?
      redirect_to settings_path, notice: "取得対象の記録がありません"
      return
    end

    success_count = 0
    error_count = 0

    records.find_each do |record|
      if record.fetch_and_set_weather! && record.save
        success_count += 1
      else
        error_count += 1
      end
    end

    message = "#{success_count}件の記録に天候データを追加しました"
    message += "（#{error_count}件は取得できませんでした）" if error_count > 0

    redirect_to settings_path, notice: message
  end

  private

  def update_from_prefecture
    if @user.set_location_from_prefecture(params[:prefecture_code])
      if @user.save
        redirect_to settings_path, notice: "地域設定を保存しました"
      else
        @prefecture_options = User.prefecture_options
        flash.now[:alert] = "地域設定の保存に失敗しました"
        render :show, status: :unprocessable_entity
      end
    else
      redirect_to settings_path, alert: "都道府県が見つかりませんでした"
    end
  end

  def update_from_zipcode
    if @user.set_location_from_zipcode(params[:zipcode])
      if @user.save
        redirect_to settings_path, notice: "地域設定を保存しました"
      else
        @prefecture_options = User.prefecture_options
        flash.now[:alert] = "地域設定の保存に失敗しました"
        render :show, status: :unprocessable_entity
      end
    else
      @prefecture_options = User.prefecture_options
      flash.now[:alert] = @user.errors.full_messages.join(", ")
      render :show, status: :unprocessable_entity
    end
  end
end
