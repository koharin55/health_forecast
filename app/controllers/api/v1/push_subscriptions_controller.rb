module Api
  module V1
    class PushSubscriptionsController < BaseController
      def create
        subscription = current_user.push_subscriptions.find_or_initialize_by(
          endpoint: subscription_params[:endpoint]
        )

        subscription.assign_attributes(
          p256dh_key: subscription_params[:p256dh_key],
          auth_key: subscription_params[:auth_key],
          user_agent: request.user_agent,
          active: true
        )

        if subscription.save
          render json: { id: subscription.id, active: subscription.active }, status: :created
        else
          render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        subscription = current_user.push_subscriptions.find_by(endpoint: params[:endpoint])

        if subscription&.destroy
          render json: { message: 'Subscription removed' }, status: :ok
        else
          render json: { error: 'Subscription not found' }, status: :not_found
        end
      end

      def vapid_public_key
        render json: {
          vapid_public_key: Rails.application.config.x.web_push[:vapid_public_key]
        }
      end

      private

      def subscription_params
        params.require(:push_subscription).permit(:endpoint, :p256dh_key, :auth_key)
      end
    end
  end
end
