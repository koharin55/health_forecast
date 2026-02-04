# frozen_string_literal: true

require "net/http"
require "json"

class ZipcodeService
  BASE_URL = "https://zipcloud.ibsnet.co.jp/api/search"
  TIMEOUT = 10

  class Error < StandardError; end
  class NotFoundError < Error; end
  class ApiError < Error; end

  # 郵便番号から住所情報を取得
  # @param zipcode [String] 郵便番号（ハイフン有無どちらでも可）
  # @return [Hash] 住所情報
  def self.search(zipcode)
    new.search(zipcode)
  end

  def search(zipcode)
    normalized = normalize_zipcode(zipcode)
    validate_zipcode!(normalized)

    response = make_request(normalized)
    parse_response(response)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("ZipcodeService timeout: #{e.message}")
    raise ApiError, "郵便番号検索がタイムアウトしました"
  rescue JSON::ParserError => e
    Rails.logger.error("ZipcodeService JSON parse error: #{e.message}")
    raise ApiError, "郵便番号検索結果の解析に失敗しました"
  end

  private

  def normalize_zipcode(zipcode)
    zipcode.to_s.gsub(/[^\d]/, "")
  end

  def validate_zipcode!(zipcode)
    unless zipcode.match?(/\A\d{7}\z/)
      raise NotFoundError, "郵便番号は7桁の数字で入力してください"
    end
  end

  def make_request(zipcode)
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(zipcode: zipcode)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/json"

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise ApiError, "API returned status #{response.code}"
    end

    JSON.parse(response.body)
  end

  def parse_response(response)
    if response["status"] != 200
      raise ApiError, response["message"] || "郵便番号検索に失敗しました"
    end

    results = response["results"]
    if results.nil? || results.empty?
      raise NotFoundError, "該当する郵便番号が見つかりませんでした"
    end

    result = results.first
    prefecture_code = result["prefcode"]
    prefecture = find_prefecture_by_code(prefecture_code)

    {
      zipcode: result["zipcode"],
      prefecture_code: prefecture_code,
      prefecture_name: result["address1"],
      city: result["address2"],
      town: result["address3"],
      full_address: "#{result['address1']}#{result['address2']}#{result['address3']}",
      latitude: prefecture[:latitude],
      longitude: prefecture[:longitude]
    }
  end

  def find_prefecture_by_code(code)
    prefectures = I18n.t("prefectures")
    prefecture = prefectures.find { |p| p[:code] == code.to_s.rjust(2, "0") }

    if prefecture
      { latitude: prefecture[:latitude], longitude: prefecture[:longitude] }
    else
      # フォールバック: 東京都の座標
      { latitude: 35.6895, longitude: 139.6917 }
    end
  end
end
