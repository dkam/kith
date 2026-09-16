# Keys for Active Record encryption (Actor#private_key).
#
# Production reads credentials or the environment. Development and test use
# fixed, non-secret keys so that a fresh checkout and CI both work without
# provisioning anything — there are no real private keys there to protect.
DEVELOPMENT_ENCRYPTION_KEYS = {
  primary_key: "kith_development_primary_key_not_a_secret",
  deterministic_key: "kith_development_deterministic_key_not_a_secret",
  key_derivation_salt: "kith_development_key_derivation_salt_not_a_secret"
}.freeze

Rails.application.config.to_prepare do
  credentials = Rails.application.credentials.active_record_encryption || {}
  fallback = Rails.env.local? ? DEVELOPMENT_ENCRYPTION_KEYS : {}

  ActiveRecord::Encryption.configure(
    primary_key: ENV["AR_ENCRYPTION_PRIMARY_KEY"] || credentials[:primary_key] || fallback[:primary_key],
    deterministic_key: ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"] || credentials[:deterministic_key] || fallback[:deterministic_key],
    key_derivation_salt: ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"] || credentials[:key_derivation_salt] || fallback[:key_derivation_salt]
  )
end
