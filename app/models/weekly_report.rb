class WeeklyReport < ApplicationRecord
  belongs_to :user

  validates :week_start, presence: true
  validates :week_end, presence: true
  validates :content, presence: true
  validates :week_start, uniqueness: { scope: [:user_id, :week_end], message: "の週次レポートは既に存在します" }

  validate :validate_week_end_after_week_start

  scope :recent, -> { order(week_start: :desc) }
  scope :for_user, ->(user) { where(user: user) }

  # 指定された週のレポートを取得（存在しない場合はnil）
  def self.find_for_week(user, week_start)
    find_by(user: user, week_start: week_start)
  end

  # 指定された期間のレポートを取得（存在しない場合はnil）
  def self.find_for_period(user, week_start, week_end)
    find_by(user: user, week_start: week_start, week_end: week_end)
  end

  # 最新のレポートを取得
  def self.latest_for_user(user)
    for_user(user).recent.first
  end

  # レポートの対象期間を表示用文字列で返す
  def period_display
    "#{week_start.strftime('%m/%d')}〜#{week_end.strftime('%m/%d')}"
  end

  # レポートの対象期間を日本語で返す
  def period_display_ja
    "#{week_start.strftime('%Y年%m月%d日')}〜#{week_end.strftime('%m月%d日')}"
  end

  private

  def validate_week_end_after_week_start
    return unless week_start.present? && week_end.present?

    if week_end < week_start
      errors.add(:week_end, "は開始日より後の日付を指定してください")
    end
  end
end
