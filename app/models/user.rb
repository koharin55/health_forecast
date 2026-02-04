class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :health_records, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  validates :latitude, numericality: {
    greater_than_or_equal_to: -90,
    less_than_or_equal_to: 90,
    allow_nil: true
  }
  validates :longitude, numericality: {
    greater_than_or_equal_to: -180,
    less_than_or_equal_to: 180,
    allow_nil: true
  }

  def active_push_subscriptions
    push_subscriptions.active
  end

  # 位置情報が設定されているかどうか
  def location_configured?
    latitude.present? && longitude.present?
  end

  # 都道府県から位置情報を設定
  def set_location_from_prefecture(prefecture_code)
    prefecture = self.class.find_prefecture(prefecture_code)
    return false unless prefecture

    self.latitude = prefecture[:latitude]
    self.longitude = prefecture[:longitude]
    self.location_name = prefecture[:name]
    true
  end

  # 郵便番号から位置情報を設定
  def set_location_from_zipcode(zipcode)
    result = ZipcodeService.search(zipcode)
    self.latitude = result[:latitude]
    self.longitude = result[:longitude]
    self.location_name = result[:full_address]
    true
  rescue ZipcodeService::Error => e
    errors.add(:base, e.message)
    false
  end

  # 都道府県マスタから都道府県を検索
  def self.find_prefecture(code)
    prefectures = I18n.t("prefectures")
    prefectures.find { |p| p[:code] == code.to_s.rjust(2, "0") }
  end

  # 都道府県一覧を取得
  def self.prefecture_options
    I18n.t("prefectures").map { |p| [ p[:name], p[:code] ] }
  end
end
