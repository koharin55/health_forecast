class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :ensure_nickname_set

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:nickname])
    devise_parameter_sanitizer.permit(:account_update, keys: [:nickname])
  end

  def ensure_nickname_set
    return unless user_signed_in?
    return if devise_controller?
    return if controller_name == "mypage"
    return if current_user.nickname_set?

    redirect_to mypage_path, alert: "ニックネームを設定してください"
  end
end
