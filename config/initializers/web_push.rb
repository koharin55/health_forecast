# Web Push configuration
# VAPID (Voluntary Application Server Identification) keys for push notifications

Rails.application.config.x.web_push = {
  # VAPID keys - generate new keys in production using:
  #   openssl ecparam -name prime256v1 -genkey -noout | openssl ec -text -noout
  # Then convert to Base64 URL-safe format
  vapid_public_key: ENV.fetch('VAPID_PUBLIC_KEY') {
    # Development default key (replace in production!)
    'BO3Nxf1BMg1m_nO6jlLK_r2KSQAajFj8_tTYj7tXMC4ESB3AhNBj32P0wSlEaZOKiBXQmZr2bqC67je8oXIJ-XQ'
  },
  vapid_private_key: ENV.fetch('VAPID_PRIVATE_KEY') {
    # Development default key (replace in production!)
    'EKLvrPk2c212hL33JO12P_HQ99rZKQ6YGRKuXh56-n8'
  },
  # Contact email for push service
  vapid_subject: ENV.fetch('VAPID_SUBJECT') { 'mailto:admin@healthforecast.local' }
}
