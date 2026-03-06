module Api
  module V1
    class HealthRecordsController < BaseController
      def create
        recorded_at = params[:recorded_at].present? ? Date.parse(params[:recorded_at]) : Date.current

        attrs = health_record_params
        if params[:sleep_seconds].present?
          attrs[:sleep_minutes] = (params[:sleep_seconds].to_f / 60).round
        end
        if params[:exercise_seconds].present?
          attrs[:exercise_minutes] = (params[:exercise_seconds].to_f / 60).round
        end

        result = HealthRecord.create_or_merge_for_date(
          user: current_user,
          recorded_at: recorded_at,
          attributes: attrs
        )

        record = result[:record]
        if !result[:merged] && current_user.location_configured?
          record.fetch_and_set_weather!
          record.save!
        end

        status = result[:merged] ? :ok : :created
        render json: record_json(record, result[:merged]), status: status
      rescue Date::Error
        render json: { error: 'recorded_atの日付形式が不正です' }, status: :unprocessable_entity
      end

      private

      def health_record_params
        raw = params.permit(
          :weight, :sleep_minutes, :exercise_minutes, :mood, :notes, :steps,
          :heart_rate, :systolic_pressure, :diastolic_pressure, :body_temperature
        )
        raw[:weight] = raw[:weight].to_f.round(1) if raw[:weight].present?
        raw
      end

      def record_json(record, merged)
        json = {
          id: record.id,
          recorded_at: record.recorded_at,
          merged: merged,
          weight: record.weight,
          mood: record.mood,
          sleep_minutes: record.sleep_minutes,
          sleep_duration: record.sleep_duration_text,
          exercise_minutes: record.exercise_minutes,
          steps: record.steps,
          heart_rate: record.heart_rate,
          systolic_pressure: record.systolic_pressure,
          diastolic_pressure: record.diastolic_pressure,
          body_temperature: record.body_temperature
        }

        if record.has_weather_data?
          json[:weather] = {
            temperature: record.weather_temperature,
            humidity: record.weather_humidity,
            pressure: record.weather_pressure,
            description: record.weather_description
          }
        end

        json
      end
    end
  end
end
