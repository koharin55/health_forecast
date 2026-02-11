class MypageController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @prefecture_options = User.prefecture_options
    @open_region = params[:open] == "region"
  end

  def update_profile
    @user = current_user

    if email_changed?
      if @user.update_with_password(profile_params_with_password)
        bypass_sign_in(@user)
        redirect_to mypage_path, notice: "プロフィールを更新しました"
      else
        @prefecture_options = User.prefecture_options
        @open_profile = true
        flash.now[:alert] = @user.errors.full_messages.join(", ")
        render :show, status: :unprocessable_entity
      end
    else
      if @user.update(profile_params)
        redirect_to mypage_path, notice: "プロフィールを更新しました"
      else
        @prefecture_options = User.prefecture_options
        @open_profile = true
        flash.now[:alert] = @user.errors.full_messages.join(", ")
        render :show, status: :unprocessable_entity
      end
    end
  end

  def update_password
    @user = current_user

    if @user.update_with_password(password_params)
      bypass_sign_in(@user)
      redirect_to mypage_path, notice: "パスワードを変更しました"
    else
      @prefecture_options = User.prefecture_options
      flash.now[:alert] = @user.errors.full_messages.join(", ")
      render :show, status: :unprocessable_entity
    end
  end

  def update_location
    @user = current_user

    case params[:location_type]
    when "prefecture"
      update_from_prefecture
    when "zipcode"
      update_from_zipcode
    else
      redirect_to mypage_path, alert: "地域の指定方法を選択してください"
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
      redirect_to mypage_path, alert: "先に地域を設定してください"
      return
    end

    result = current_user.backfill_weather_data

    if result[:empty]
      redirect_to mypage_path, notice: "取得対象の記録がありません"
      return
    end

    message = "#{result[:success_count]}件の記録に天候データを追加しました"
    message += "（#{result[:error_count]}件は取得できませんでした）" if result[:error_count] > 0

    redirect_to mypage_path, notice: message
  end

  def destroy_account
    current_user.destroy
    sign_out
    redirect_to new_user_session_path, notice: "アカウントを削除しました"
  end

  private

  def profile_params
    params.require(:user).permit(:nickname, :email)
  end

  def email_changed?
    params.dig(:user, :email).present? && params.dig(:user, :email) != current_user.email
  end

  def profile_params_with_password
    params.require(:user).permit(:nickname, :email, :current_password)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end

  def update_from_prefecture
    if @user.set_location_from_prefecture(params[:prefecture_code])
      if @user.save
        redirect_to mypage_path, notice: "地域設定を保存しました"
      else
        @prefecture_options = User.prefecture_options
        flash.now[:alert] = "地域設定の保存に失敗しました"
        render :show, status: :unprocessable_entity
      end
    else
      redirect_to mypage_path, alert: "都道府県が見つかりませんでした"
    end
  end

  def update_from_zipcode
    if @user.set_location_from_zipcode(params[:zipcode])
      if @user.save
        redirect_to mypage_path, notice: "地域設定を保存しました"
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
