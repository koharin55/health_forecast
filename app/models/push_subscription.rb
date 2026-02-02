class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true

  scope :active, -> { where(active: true) }

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def deactivate!
    update!(active: false)
  end

  def to_webpush_hash
    {
      endpoint: endpoint,
      keys: {
        p256dh: p256dh_key,
        auth: auth_key
      }
    }
  end
end
