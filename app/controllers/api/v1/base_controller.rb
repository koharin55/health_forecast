module Api
  module V1
    class BaseController < ApplicationController
      skip_forgery_protection
      skip_before_action :ensure_nickname_set

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

      private

      def authenticate_user!
        return if user_signed_in?

        authenticate_with_token!
        render json: { error: '認証に失敗しました' }, status: :unauthorized unless @current_user
      end

      def current_user
        @current_user || super
      end

      def authenticate_with_token!
        token = request.headers['Authorization']&.match(/\ABearer (.+)\z/)&.captures&.first
        return unless token.present?

        user = User.find_by_api_token(token)
        @current_user = user if user
      end

      def not_found
        render json: { error: 'Not found' }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { error: exception.message }, status: :unprocessable_entity
      end
    end
  end
end
