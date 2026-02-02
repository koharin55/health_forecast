module Api
  module V1
    class BaseController < ApplicationController
      protect_from_forgery with: :null_session
      before_action :authenticate_user!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

      private

      def not_found
        render json: { error: 'Not found' }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { error: exception.message }, status: :unprocessable_entity
      end
    end
  end
end
