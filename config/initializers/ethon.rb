# frozen_string_literal: true

# Ethon（Typhoeus経由で gemini-ai gem が使用）はデフォルトで Rails.logger に
# リクエストURLをdebugログ出力する。Gemini APIのURLにはAPIキーが含まれるため、
# info 以上のみ出力する専用ロガーに差し替える。
Ethon.logger = ActiveSupport::Logger.new($stdout, level: :info)
